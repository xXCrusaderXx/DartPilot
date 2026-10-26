#pragma once

#include <cmath>
#include <optional>

#include <QFutureWatcher>
#include <QTimer>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "stream_view.hpp"

namespace dartpilot::setup
{
// Live calibration check of one camera: detects the board every few seconds and compares the points with where the
// stored refinement puts them, also against the other cameras' calibrations to notice cameras swapped between ports.
class CheckView : public StreamView
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString usbPort READ usbPort WRITE setUsbPort NOTIFY resultChanged)
    // nocalibration, measuring, noboard or checked
    Q_PROPERTY(QString checkState READ checkState NOTIFY resultChanged)
    Q_PROPERTY(double rmsMm READ rmsMm NOTIFY resultChanged)
    Q_PROPERTY(double rmsPx READ rmsPx NOTIFY resultChanged)
    Q_PROPERTY(double shiftPx READ shiftPx NOTIFY resultChanged)
    // good, fair or poor once checked
    Q_PROPERTY(QString quality READ quality NOTIFY resultChanged)
    Q_PROPERTY(QString qualityText READ qualityText NOTIFY resultChanged)
    // The USB port whose calibration fits this image clearly better, if any
    Q_PROPERTY(QString swappedWith READ swappedWith NOTIFY resultChanged)
    // Completed checks, so the user sees that it keeps running
    Q_PROPERTY(int checks READ checks NOTIFY resultChanged)

   public:
    explicit CheckView (QQuickItem* parent = nullptr);
    ~CheckView () override;

    QString usbPort () const { return usb_port_; }
    void setUsbPort (const QString& usb_port);
    QString checkState () const { return check_state_; }
    double rmsMm () const { return check_ ? check_->rms_mm : 0.0; }
    double rmsPx () const { return check_ ? check_->rms_px : 0.0; }
    double shiftPx () const { return check_ ? std::hypot(check_->mean_shift_px.x, check_->mean_shift_px.y) : 0.0; }
    QString quality () const;
    QString qualityText () const;
    QString swappedWith () const { return swapped_with_; }
    int checks () const { return checks_; }

   signals:
    void resultChanged ();

   protected:
    void onFrame (const CameraSnapshot& snapshot) override;
    void paintOverlay (QPainter* painter, const QRectF& target, double scale) override;

   private:
    struct Result
    {
        std::optional<geometry::BoardDetection> detection;
        std::optional<geometry::CalibrationCheck> check;
        QString swapped_with;
    };

    void onChecked ();
    void startMeasuring ();

    QString usb_port_;
    QString check_state_ = "nocalibration";
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    cv::Mat frame_sum_;
    int frames_summed_ = 0;
    bool measuring_ = false;
    QTimer pause_;
    QFutureWatcher<Result> watcher_;
    QString checking_port_;
    std::optional<geometry::BoardDetection> detection_;
    std::optional<geometry::CalibrationCheck> check_;
    QString swapped_with_;
    int checks_ = 0;
};
}  // namespace dartpilot::setup
