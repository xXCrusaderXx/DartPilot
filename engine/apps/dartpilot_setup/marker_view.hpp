#pragma once

#include <QVariantList>

#include "stream_view.hpp"

namespace dartpilot::setup
{
// Live image of one camera with marks on it: a cross where the engine puts a dart, small rings on the visible ends of
// the object it found, and the axis it found as a line.
class MarkerView : public StreamView
{
    Q_OBJECT
    QML_ELEMENT
    // Each entry: x, y in image pixels and kind (dart, end, or axis with x2, y2 and an optional colour)
    Q_PROPERTY(QVariantList markers READ markers WRITE setMarkers NOTIFY markersChanged)

   public:
    explicit MarkerView (QQuickItem* parent = nullptr);
    ~MarkerView () override;

    QVariantList markers () const { return markers_; }
    void setMarkers (const QVariantList& markers);

   signals:
    void markersChanged ();

   protected:
    void paintOverlay (QPainter* painter, const QRectF& target, double scale) override;

   private:
    QVariantList markers_;
};
}  // namespace dartpilot::setup
