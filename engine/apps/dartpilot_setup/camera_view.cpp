#include "camera_view.hpp"

#include <linux/videodev2.h>

#include <algorithm>
#include <optional>

#include <QMouseEvent>
#include <QPainter>

#include "dartpilot/capture/focus.hpp"

namespace dartpilot::setup
{
namespace
{
// Smooths sensor noise so the value can be read while turning the lens.
constexpr double kSmoothing = 0.3;
// The raw measure is a small ratio; scaled for display only.
constexpr double kDisplayScale = 100.0;

std::optional<std::uint32_t> controlId (const QString& name)
{
    if(name == QLatin1String("autoExposure"))
    {
        return V4L2_CID_EXPOSURE_AUTO;
    }
    if(name == QLatin1String("exposure"))
    {
        return V4L2_CID_EXPOSURE_ABSOLUTE;
    }
    if(name == QLatin1String("dynamicFramerate"))
    {
        return V4L2_CID_EXPOSURE_AUTO_PRIORITY;
    }
    if(name == QLatin1String("autoWhiteBalance"))
    {
        return V4L2_CID_AUTO_WHITE_BALANCE;
    }
    if(name == QLatin1String("whiteBalance"))
    {
        return V4L2_CID_WHITE_BALANCE_TEMPERATURE;
    }
    return std::nullopt;
}

QRectF scaledCell (const QRectF& image_rect, const cv::Size& image_size, int cell)
{
    const cv::Rect rect = capture::gridCell(image_size, kFocusGridSize, cell);
    const double scale = image_rect.width() / image_size.width;
    return {image_rect.x() + rect.x * scale, image_rect.y() + rect.y * scale, rect.width * scale, rect.height * scale};
}

}  // namespace

CameraView::CameraView (QQuickItem* parent)
    : StreamView(parent)
{
    setAcceptedMouseButtons(Qt::LeftButton);
}

CameraView::~CameraView () { releaseStream(); }

void CameraView::attachStream (CameraStream& stream)
{
    controls_ = std::make_unique<capture::CameraControls>(devicePath().toStdString());
    if(focus_enabled_)
    {
        stream.addFocusUser(1);
    }
    resetPeaks();
    emit controlsChanged();
}

void CameraView::detachStream (CameraStream& stream)
{
    if(focus_enabled_)
    {
        stream.addFocusUser(-1);
    }
    controls_.reset();
    emit controlsChanged();
}

void CameraView::setFocusEnabled (bool enabled)
{
    if(enabled == focus_enabled_)
    {
        return;
    }
    focus_enabled_ = enabled;
    if(stream())
    {
        stream()->addFocusUser(enabled ? 1 : -1);
    }
    resetPeaks();
    emit focusEnabledChanged();
    update();
}

QVariantMap CameraView::controlState (const QString& name) const
{
    QVariantMap state{{"available", false}};
    const auto id = controlId(name);
    if(!controls_ || !id)
    {
        return state;
    }
    const auto range = controls_->range(*id);
    const auto value = controls_->get(*id);
    if(!range || !value)
    {
        return state;
    }
    state["available"] = true;
    state["value"] = *value;
    state["minimum"] = range->minimum;
    state["maximum"] = range->maximum;
    state["step"] = range->step;
    state["inactive"] = range->inactive;
    return state;
}

bool CameraView::setControl (const QString& name, int value)
{
    const auto id = controlId(name);
    const bool ok = controls_ && id && controls_->set(*id, value);
    emit controlsChanged();
    return ok;
}

void CameraView::resetPeaks ()
{
    current_.fill(0.0);
    peak_.fill(0.0);
    too_dark_.fill(false);
}

void CameraView::onFrame (const CameraSnapshot& snapshot)
{
    if(!focus_enabled_)
    {
        return;
    }
    for(int cell = 0; cell < kFocusCellCount; ++cell)
    {
        too_dark_[cell] = snapshot.too_dark[cell];
        if(too_dark_[cell])
        {
            continue;
        }
        const double value = snapshot.sharpness[cell];
        current_[cell] = current_[cell] > 0.0 ? (1.0 - kSmoothing) * current_[cell] + kSmoothing * value : value;
        peak_[cell] = std::max(peak_[cell], current_[cell]);
    }
}

void CameraView::paintOverlay (QPainter* painter, const QRectF& target, double)
{
    if(!focus_enabled_)
    {
        return;
    }

    const cv::Size image_size = imageSize();
    const int label_px = std::max(11, static_cast<int>(target.height() / 40));
    for(int cell = 0; cell < kFocusCellCount; ++cell)
    {
        const QRectF rect = scaledCell(target, image_size, cell);
        const bool selected = cell == selected_cell_;
        painter->setPen(QPen(selected ? QColor(56, 189, 248) : QColor(230, 233, 239, 90), selected ? 3 : 1));
        painter->drawRect(rect);
        const QString label =
            too_dark_[cell] ? QStringLiteral("too dark")
                            : QString::number(current_[cell] * kDisplayScale, 'f', 2) + " / " + QString::number(peak_[cell] * kDisplayScale, 'f', 2);
        drawLabel(painter, rect.topLeft() + QPointF(14, label_px + 12), label, label_px);
    }
    if(!too_dark_[selected_cell_])
    {
        const QRectF rect = scaledCell(target, image_size, selected_cell_);
        const double ratio = peak_[selected_cell_] > 0.0 ? current_[selected_cell_] / peak_[selected_cell_] : 0.0;
        drawLabel(painter, rect.topLeft() + QPointF(8, rect.height() / 2 + label_px),
                  QString::number(current_[selected_cell_] * kDisplayScale, 'f', 2), label_px * 3, true);
        drawLabel(painter, rect.topLeft() + QPointF(8, rect.height() / 2 + label_px * 3), QString::number(qRound(ratio * 100.0)) + "% of peak",
                  label_px * 3 / 2, true);
    }
}

void CameraView::mousePressEvent (QMouseEvent* event)
{
    const QRectF target = imageRect();
    if(!focus_enabled_ || !target.contains(event->position()))
    {
        event->ignore();
        return;
    }
    const int col = std::clamp(static_cast<int>((event->position().x() - target.x()) * kFocusGridSize / target.width()), 0, kFocusGridSize - 1);
    const int row = std::clamp(static_cast<int>((event->position().y() - target.y()) * kFocusGridSize / target.height()), 0, kFocusGridSize - 1);
    selected_cell_ = row * kFocusGridSize + col;
    update();
}
}  // namespace dartpilot::setup
