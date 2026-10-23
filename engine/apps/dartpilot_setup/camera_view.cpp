#include "camera_view.hpp"

#include <linux/videodev2.h>

#include <algorithm>
#include <optional>

#include <QMouseEvent>
#include <QPainter>
#include <opencv2/imgproc.hpp>

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

void drawLabel (QPainter* painter, const QPointF& origin, const QString& text, int pixel_size, bool bold = false)
{
    QFont font = painter->font();
    font.setPixelSize(pixel_size);
    font.setBold(bold);
    painter->setFont(font);
    const QRectF box = QFontMetricsF(font).boundingRect(text).translated(origin).adjusted(-4, -2, 4, 2);
    painter->fillRect(box, QColor(0, 0, 0, 170));
    painter->setPen(Qt::white);
    painter->drawText(origin, text);
}
}  // namespace

CameraView::CameraView (QQuickItem* parent)
    : QQuickPaintedItem(parent)
{
    setAcceptedMouseButtons(Qt::LeftButton);
    timer_.setInterval(15);
    connect(&timer_, &QTimer::timeout, this, &CameraView::poll);
}

CameraView::~CameraView () = default;

void CameraView::setDevicePath (const QString& path)
{
    if(path == device_path_)
    {
        return;
    }
    device_path_ = path;
    timer_.stop();
    stream_.reset();
    controls_.reset();
    image_ = QImage();
    last_frame_count_ = 0;
    fps_ = 0.0;
    error_.clear();
    resetPeaks();
    if(!path.isEmpty())
    {
        controls_ = std::make_unique<capture::CameraControls>(path.toStdString());
        stream_ = std::make_unique<CameraStream>(path.toStdString());
        stream_->setFocusEnabled(focus_enabled_);
        timer_.start();
    }
    emit devicePathChanged();
    emit statsChanged();
    emit controlsChanged();
    update();
}

void CameraView::setFocusEnabled (bool enabled)
{
    if(enabled == focus_enabled_)
    {
        return;
    }
    focus_enabled_ = enabled;
    if(stream_)
    {
        stream_->setFocusEnabled(enabled);
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

void CameraView::poll ()
{
    if(!stream_)
    {
        return;
    }
    const CameraSnapshot snapshot = stream_->latest();
    const QString error = QString::fromStdString(snapshot.error);
    if(error != error_)
    {
        error_ = error;
        emit statsChanged();
    }
    if(snapshot.frame_count == last_frame_count_ || snapshot.frame.empty())
    {
        return;
    }
    last_frame_count_ = snapshot.frame_count;

    cv::Mat rgb;
    cv::cvtColor(snapshot.frame, rgb, cv::COLOR_BGR2RGB);
    image_ = QImage(rgb.data, rgb.cols, rgb.rows, static_cast<qsizetype>(rgb.step), QImage::Format_RGB888).copy();

    if(focus_enabled_)
    {
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
    if(snapshot.fps != fps_)
    {
        fps_ = snapshot.fps;
        emit statsChanged();
    }
    update();
}

QRectF CameraView::imageRect () const
{
    if(image_.isNull())
    {
        return {};
    }
    const QSizeF scaled = QSizeF(image_.size()).scaled(QSizeF(width(), height()), Qt::KeepAspectRatio);
    return {(width() - scaled.width()) / 2.0, (height() - scaled.height()) / 2.0, scaled.width(), scaled.height()};
}

void CameraView::paint (QPainter* painter)
{
    painter->fillRect(QRectF(0, 0, width(), height()), QColor(20, 20, 20));
    if(image_.isNull())
    {
        drawLabel(painter, QPointF(12, 28), error_.isEmpty() ? (device_path_.isEmpty() ? "Camera off" : "Waiting for frames") : error_, 16);
        return;
    }
    const QRectF target = imageRect();
    painter->setRenderHint(QPainter::SmoothPixmapTransform);
    painter->drawImage(target, image_);
    if(!focus_enabled_)
    {
        return;
    }

    const cv::Size image_size(image_.width(), image_.height());
    const int label_px = std::max(11, static_cast<int>(target.height() / 40));
    for(int cell = 0; cell < kFocusCellCount; ++cell)
    {
        const QRectF rect = scaledCell(target, image_size, cell);
        const bool selected = cell == selected_cell_;
        painter->setPen(QPen(selected ? QColor(255, 200, 0) : QColor(220, 220, 220, 160), selected ? 3 : 1));
        painter->drawRect(rect);
        const QString label =
            too_dark_[cell] ? QStringLiteral("too dark")
                            : QString::number(current_[cell] * kDisplayScale, 'f', 2) + " / " + QString::number(peak_[cell] * kDisplayScale, 'f', 2);
        drawLabel(painter, rect.topLeft() + QPointF(8, label_px + 6), label, label_px);
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
