#pragma once

#include <array>
#include <memory>

#include <QVariantMap>

#include "dartpilot/capture/v4l2_device.hpp"
#include "stream_view.hpp"

namespace dartpilot::setup
{
// Live image of one camera with an optional focus grid, plus access to its V4L2 controls.
class CameraView : public StreamView
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool focusEnabled READ focusEnabled WRITE setFocusEnabled NOTIFY focusEnabledChanged)
    // Every control by name, as controlState gives it; bindings follow controlsChanged without a revision counter
    Q_PROPERTY(QVariantMap controls READ controls NOTIFY controlsChanged)

   public:
    explicit CameraView (QQuickItem* parent = nullptr);
    ~CameraView () override;

    bool focusEnabled () const { return focus_enabled_; }
    void setFocusEnabled (bool enabled);

    // Control names: autoExposure, exposure, dynamicFramerate, autoWhiteBalance, whiteBalance.
    // Returns available, value, minimum, maximum, step and inactive.
    Q_INVOKABLE QVariantMap controlState (const QString& name) const;
    QVariantMap controls () const;
    Q_INVOKABLE bool setControl (const QString& name, int value);
    Q_INVOKABLE void resetPeaks ();

   signals:
    void focusEnabledChanged ();
    // A control changed, so dependent controls may have become active or inactive
    void controlsChanged ();

   protected:
    void attachStream (CameraStream& stream) override;
    void detachStream (CameraStream& stream) override;
    void onFrame (const CameraSnapshot& snapshot) override;
    void paintOverlay (QPainter* painter, const QRectF& target, double scale) override;
    void mousePressEvent (QMouseEvent* event) override;

   private:
    bool focus_enabled_ = false;
    std::unique_ptr<capture::CameraControls> controls_;
    std::array<double, kFocusCellCount> current_{};
    std::array<double, kFocusCellCount> peak_{};
    std::array<bool, kFocusCellCount> too_dark_{};
    int selected_cell_ = kFocusCellCount / 2;
};
}  // namespace dartpilot::setup
