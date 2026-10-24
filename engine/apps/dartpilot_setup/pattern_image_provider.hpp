#pragma once

#include <QQuickImageProvider>

namespace dartpilot::setup
{
// Serves the ChArUco calibration patterns to QML as image://charuco/pattern/<tablet|phone>, rendered at the requested
// size, and QR codes of their download addresses as image://charuco/qr/<tablet|phone>.
class PatternImageProvider : public QQuickImageProvider
{
   public:
    PatternImageProvider ();
    QImage requestImage (const QString& id, QSize* size, const QSize& requested_size) override;
};
}  // namespace dartpilot::setup
