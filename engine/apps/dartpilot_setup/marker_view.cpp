#include "marker_view.hpp"

#include <QPainter>

namespace dartpilot::setup
{
MarkerView::MarkerView (QQuickItem* parent)
    : StreamView(parent)
{
}

MarkerView::~MarkerView () { releaseStream(); }

void MarkerView::setMarkers (const QVariantList& markers)
{
    markers_ = markers;
    emit markersChanged();
    update();
}

void MarkerView::paintOverlay (QPainter* painter, const QRectF& target, double scale)
{
    painter->setRenderHint(QPainter::Antialiasing);
    for(const auto& item : markers_)
    {
        const QVariantMap marker = item.toMap();
        const QPointF p(target.x() + marker.value("x").toDouble() * scale, target.y() + marker.value("y").toDouble() * scale);
        if(marker.value("kind").toString() == "dart")
        {
            painter->setPen(QPen(QColor(248, 113, 113), 2.0));
            for(const QPointF& d : {QPointF(1, 0), QPointF(-1, 0), QPointF(0, 1), QPointF(0, -1)})
            {
                painter->drawLine(p + d * 4.0, p + d * 14.0);
            }
        }
        else
        {
            painter->setPen(QPen(QColor(52, 211, 153), 1.5));
            painter->setBrush(Qt::NoBrush);
            painter->drawEllipse(p, 4.0, 4.0);
        }
    }
}
}  // namespace dartpilot::setup
