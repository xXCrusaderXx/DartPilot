#pragma once

#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>

#include <QtQml/qqmlregistration.h>
#include <QImage>
#include <QQuickPaintedItem>
#include <QTimer>

#include "camera_stream.hpp"

namespace dartpilot::setup
{
// Text on a dark box, readable on any camera image.
void drawLabel (QPainter* painter, const QPointF& origin, const QString& text, int pixel_size, bool bold = false);

// Base of the live camera items: shows the latest frame of a shared stream and lets subclasses draw on it.
class StreamView : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ANONYMOUS
    // Empty stops the camera
    Q_PROPERTY(QString devicePath READ devicePath WRITE setDevicePath NOTIFY devicePathChanged)
    Q_PROPERTY(double fps READ fps NOTIFY statsChanged)
    // good at the camera's full rate, fair below it, poor on an error, empty while starting
    Q_PROPERTY(QString fpsQuality READ fpsQuality NOTIFY statsChanged)
    Q_PROPERTY(QString error READ error NOTIFY statsChanged)

   public:
    explicit StreamView (QQuickItem* parent = nullptr);
    ~StreamView () override;

    QString devicePath () const { return device_path_; }
    void setDevicePath (const QString& path);
    double fps () const { return fps_; }
    QString fpsQuality () const;
    QString error () const { return error_; }

    void paint (QPainter* painter) override;

   signals:
    void devicePathChanged ();
    void statsChanged ();

   protected:
    CameraStream* stream () const { return stream_.get(); }
    // Called when a stream is attached or about to be detached, to register the analyses the view needs
    virtual void attachStream (CameraStream&) {}
    virtual void detachStream (CameraStream&) {}
    virtual void onFrame (const CameraSnapshot&) {}
    // target is the image area in item coordinates; scale converts image pixels to item units
    virtual void paintOverlay (QPainter*, const QRectF& /*target*/, double /*scale*/) {}
    // Must be called from the subclass destructor, while its overrides still exist
    void releaseStream ();
    QRectF imageRect () const;
    cv::Size imageSize () const { return {image_.width(), image_.height()}; }
    // The latest frame as shown, in RGB
    const QImage& image () const { return image_; }

   private:
    void poll ();
    void reopenEndedStream ();

    QString device_path_;
    std::shared_ptr<CameraStream> stream_;
    QTimer timer_;
    QImage image_;
    std::uint64_t last_frame_count_ = 0;
    double fps_ = 0.0;
    QString error_;
    // When a stream that ended is opened again; unset while the stream runs
    std::optional<std::chrono::steady_clock::time_point> reopen_at_;
};
}  // namespace dartpilot::setup
