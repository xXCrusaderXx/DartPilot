#pragma once

#include <QQuickImageProvider>

namespace dartpilot::setup
{
// Serves the ChArUco calibration pattern to QML as image://charuco/pattern, rendered at the requested size,
// and a QR code of its download address as image://charuco/qr.
class PatternImageProvider : public QQuickImageProvider
{
   public:
    PatternImageProvider ();
    QImage requestImage (const QString& id, QSize* size, const QSize& requested_size) override;
};
}  // namespace dartpilot::setup
