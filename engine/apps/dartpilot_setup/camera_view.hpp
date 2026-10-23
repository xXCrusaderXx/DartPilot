#pragma once

#include <array>
#include <cstdint>
#include <memory>

#include <QtQml/qqmlregistration.h>
#include <QImage>
#include <QQuickPaintedItem>
#include <QTimer>
#include <QVariantMap>

#include "camera_stream.hpp"
#include "dartpilot/capture/v4l2_device.hpp"

namespace dartpilot::setup
{
// Live image of one camera with an optional focus grid, plus access to its V4L2 controls.
class CameraView : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    // Empty stops the camera
    Q_PROPERTY(QString devicePath READ devicePath WRITE setDevicePath NOTIFY devicePathChanged)
    Q_PROPERTY(bool focusEnabled READ focusEnabled WRITE setFocusEnabled NOTIFY focusEnabledChanged)
    Q_PROPERTY(double fps READ fps NOTIFY statsChanged)
    Q_PROPERTY(QString error READ error NOTIFY statsChanged)

   public:
    explicit CameraView (QQuickItem* parent = nullptr);
    ~CameraView () override;

    QString devicePath () const { return device_path_; }
    void setDevicePath (const QString& path);
    bool focusEnabled () const { return focus_enabled_; }
    void setFocusEnabled (bool enabled);
    double fps () const { return fps_; }
    QString error () const { return error_; }

    // Control names: autoExposure, exposure, dynamicFramerate, autoWhiteBalance, whiteBalance.
    // Returns available, value, minimum, maximum, step and inactive.
    Q_INVOKABLE QVariantMap controlState (const QString& name) const;
    Q_INVOKABLE bool setControl (const QString& name, int value);
    Q_INVOKABLE void resetPeaks ();

    void paint (QPainter* painter) override;

   signals:
    void devicePathChanged ();
    void focusEnabledChanged ();
    void statsChanged ();
    // A control changed, so dependent controls may have become active or inactive
    void controlsChanged ();

   protected:
    void mousePressEvent (QMouseEvent* event) override;

   private:
    void poll ();
    QRectF imageRect () const;

    QString device_path_;
    bool focus_enabled_ = false;
    std::unique_ptr<CameraStream> stream_;
    std::unique_ptr<capture::CameraControls> controls_;
    QTimer timer_;
    QImage image_;
    std::uint64_t last_frame_count_ = 0;
    double fps_ = 0.0;
    QString error_;
    std::array<double, kFocusCellCount> current_{};
    std::array<double, kFocusCellCount> peak_{};
    std::array<bool, kFocusCellCount> too_dark_{};
    int selected_cell_ = kFocusCellCount / 2;
};
}  // namespace dartpilot::setup
