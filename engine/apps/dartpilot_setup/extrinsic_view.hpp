#pragma once

#include <optional>

#include <QFutureWatcher>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "stream_view.hpp"

namespace dartpilot::setup
{
// Live image of one camera for the extrinsic calibration: detects the empty board on request, lets the user click
// the sector 20, and fits and saves the board plane of that camera.
class ExtrinsicView : public StreamView
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString usbPort READ usbPort WRITE setUsbPort NOTIFY resultChanged)
    // idle, detecting, failed, pick (board found, waiting for the click on 20) or done
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString message READ message NOTIFY stateChanged)
    // The last fitted plane could not be written; it is shown but not stored
    Q_PROPERTY(bool saveFailed READ saveFailed NOTIFY stateChanged)
    Q_PROPERTY(bool hasPlane READ hasPlane NOTIFY resultChanged)
    Q_PROPERTY(double rmsMm READ rmsMm NOTIFY resultChanged)
    Q_PROPERTY(double worstMm READ worstMm NOTIFY resultChanged)
    Q_PROPERTY(double rmsPx READ rmsPx NOTIFY resultChanged)
    // Whether the stored intrinsics of this camera were used to remove the lens distortion first
    Q_PROPERTY(bool undistorted READ undistorted NOTIFY resultChanged)

   public:
    explicit ExtrinsicView (QQuickItem* parent = nullptr);
    ~ExtrinsicView () override;

    QString usbPort () const { return usb_port_; }
    void setUsbPort (const QString& usb_port);
    QString state () const { return state_; }
    QString message () const { return message_; }
    bool saveFailed () const { return save_failed_; }
    bool hasPlane () const { return plane_.has_value(); }
    double rmsMm () const { return plane_ ? plane_->fit.rms_mm : 0.0; }
    double worstMm () const { return plane_ ? plane_->fit.worst_mm : 0.0; }
    double rmsPx () const { return plane_ ? plane_->fit.rms_px : 0.0; }
    bool undistorted () const { return plane_ && plane_->fit.undistorted; }

    // Averages the next frames and looks for the board in them
    Q_INVOKABLE void detect ();

   signals:
    void stateChanged ();
    void resultChanged ();
    // A board plane was written to the calibration directory
    void saved ();

   protected:
    void onFrame (const CameraSnapshot& snapshot) override;
    void paintOverlay (QPainter* painter, const QRectF& target, double scale) override;
    void mousePressEvent (QMouseEvent* event) override;

   private:
    void setState (const QString& state, const QString& message);
    void onDetected ();
    void orient (int twenty_sector);

    QString usb_port_;
    QString state_ = "idle";
    QString message_;
    bool save_failed_ = false;
    // Frames summed for the detection; averaging lowers the noise of the colour edges
    cv::Mat frame_sum_;
    int frames_summed_ = 0;
    QFutureWatcher<std::optional<geometry::BoardDetection>> watcher_;
    // The camera the running detection was started on
    QString detecting_port_;
    std::optional<geometry::BoardDetection> detection_;
    std::optional<int> twenty_sector_;
    std::optional<geometry::StoredBoardPlane> plane_;
};
}  // namespace dartpilot::setup
