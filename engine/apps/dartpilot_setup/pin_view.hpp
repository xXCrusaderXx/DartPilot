#pragma once

#include <optional>

#include <QPointF>

#include "stream_view.hpp"

namespace dartpilot::setup
{
// Live image of one camera for the pin check: the user clicks where the pin enters the board. A magnifier follows the
// pointer, because one pixel is about a millimetre on the board.
class PinView : public StreamView
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString usbPort MEMBER usb_port_)
    Q_PROPERTY(bool picked READ picked NOTIFY pickedChanged)

   public:
    explicit PinView (QQuickItem* parent = nullptr);
    ~PinView () override;

    bool picked () const { return picked_px_.has_value(); }
    Q_INVOKABLE void clearPick ();

   signals:
    void pickedChanged ();
    // Image point of the click, in pixels of the camera image
    void pointPicked (const QString& usbPort, double x_px, double y_px);

   protected:
    void paintOverlay (QPainter* painter, const QRectF& target, double scale) override;
    void mousePressEvent (QMouseEvent* event) override;
    void hoverMoveEvent (QHoverEvent* event) override;
    void hoverLeaveEvent (QHoverEvent* event) override;

   private:
    std::optional<QPointF> toImage (const QPointF& item) const;

    QString usb_port_;
    std::optional<QPointF> picked_px_;
    std::optional<QPointF> hover_px_;
};
}  // namespace dartpilot::setup
