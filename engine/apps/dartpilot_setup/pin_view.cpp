#include "pin_view.hpp"

#include <QHoverEvent>
#include <QMouseEvent>
#include <QPainter>

namespace dartpilot::setup
{
namespace
{
// Image pixels around the pointer shown in the magnifier, and its size on screen
constexpr int kMagnifiedSide_px = 40;
constexpr double kMagnifierSide = 200.0;
}  // namespace

PinView::PinView (QQuickItem* parent)
    : StreamView(parent)
{
    setAcceptedMouseButtons(Qt::LeftButton);
    setAcceptHoverEvents(true);
}

PinView::~PinView () { releaseStream(); }

void PinView::clearPick ()
{
    picked_px_.reset();
    emit pickedChanged();
    update();
}

std::optional<QPointF> PinView::toImage (const QPointF& item) const
{
    const QRectF target = imageRect();
    if(target.isEmpty() || !target.contains(item))
    {
        return std::nullopt;
    }
    const double scale = target.width() / imageSize().width;
    return QPointF((item.x() - target.x()) / scale, (item.y() - target.y()) / scale);
}

void PinView::mousePressEvent (QMouseEvent* event)
{
    const auto image_px = toImage(event->position());
    if(!image_px)
    {
        event->ignore();
        return;
    }
    picked_px_ = image_px;
    emit pickedChanged();
    emit pointPicked(usb_port_, image_px->x(), image_px->y());
    update();
}

void PinView::hoverMoveEvent (QHoverEvent* event)
{
    hover_px_ = toImage(event->position());
    update();
}

void PinView::hoverLeaveEvent (QHoverEvent*)
{
    hover_px_.reset();
    update();
}

void PinView::paintOverlay (QPainter* painter, const QRectF& target, double scale)
{
    painter->setRenderHint(QPainter::Antialiasing);
    const auto toItem = [&] (const QPointF& p) { return QPointF(target.x() + p.x() * scale, target.y() + p.y() * scale); };
    if(picked_px_)
    {
        const QPointF p = toItem(*picked_px_);
        painter->setPen(QPen(QColor(251, 191, 36), 2.0));
        painter->setBrush(Qt::NoBrush);
        painter->drawEllipse(p, 7.0, 7.0);
        painter->drawLine(p - QPointF(12, 0), p - QPointF(4, 0));
        painter->drawLine(p + QPointF(4, 0), p + QPointF(12, 0));
        painter->drawLine(p - QPointF(0, 12), p - QPointF(0, 4));
        painter->drawLine(p + QPointF(0, 4), p + QPointF(0, 12));
    }
    if(!hover_px_ || image().isNull())
    {
        return;
    }
    // Magnifier in the corner away from the pointer, with a cross on the pixel under it
    const QRectF source(hover_px_->x() - kMagnifiedSide_px / 2.0, hover_px_->y() - kMagnifiedSide_px / 2.0, kMagnifiedSide_px, kMagnifiedSide_px);
    const bool left = toItem(*hover_px_).x() > target.center().x();
    const QRectF box(left ? target.left() + 8 : target.right() - kMagnifierSide - 8, target.top() + 8, kMagnifierSide, kMagnifierSide);
    painter->save();
    painter->setRenderHint(QPainter::SmoothPixmapTransform, false);
    painter->drawImage(box, image(), source);
    painter->restore();
    painter->setPen(QPen(QColor(56, 189, 248), 2.0));
    painter->setBrush(Qt::NoBrush);
    painter->drawRect(box);
    painter->setPen(QPen(QColor(251, 191, 36), 1.0));
    painter->drawLine(QPointF(box.center().x(), box.top()), QPointF(box.center().x(), box.bottom()));
    painter->drawLine(QPointF(box.left(), box.center().y()), QPointF(box.right(), box.center().y()));
}
}  // namespace dartpilot::setup
