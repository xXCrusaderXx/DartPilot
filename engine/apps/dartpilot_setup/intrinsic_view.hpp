#pragma once

#include <array>
#include <optional>
#include <set>
#include <string>
#include <vector>

#include <QFutureWatcher>
#include <QVariantList>

#include "dartpilot/geometry/charuco.hpp"
#include "dartpilot/geometry/intrinsics.hpp"
#include "stream_view.hpp"

namespace dartpilot::setup
{
// Intrinsic calibration of one camera from views of the ChArUco target: live detection, coverage map,
// manual and automatic capture, calibration in the background, and saving.
class IntrinsicView : public StreamView
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool charucoAvailable READ charucoAvailable CONSTANT)
    Q_PROPERTY(QString usbPort MEMBER usb_port_)
    Q_PROPERTY(QString cameraName MEMBER camera_name_)
    // standard, rational or fisheye
    Q_PROPERTY(QString model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(bool autoCapture MEMBER auto_capture_ NOTIFY autoCaptureChanged)
    Q_PROPERTY(int cornersInFrame READ cornersInFrame NOTIFY detectionChanged)
    // tablet (10x7, also for prints and second displays) or phone (8x4); views of both can be mixed
    Q_PROPERTY(QString target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(int totalCorners READ totalCorners NOTIFY targetChanged)
    Q_PROPERTY(int viewCount READ viewCount NOTIFY viewsChanged)
    Q_PROPERTY(double coverage READ coverage NOTIFY viewsChanged)
    Q_PROPERTY(QString hint READ hint NOTIFY detectionChanged)
    Q_PROPERTY(bool calibrating READ calibrating NOTIFY resultChanged)
    Q_PROPERTY(bool calibrated READ calibrated NOTIFY resultChanged)
    Q_PROPERTY(QString resultText READ resultText NOTIFY resultChanged)
    // Per view: index, corners and, after a calibration, rmsPx and outlier
    Q_PROPERTY(QVariantList views READ views NOTIFY viewsChanged)
    // Per distortion model: model, ok, rmsPx, heldOutRmsPx, recommended
    Q_PROPERTY(QVariantList modelResults READ modelResults NOTIFY resultChanged)
    Q_PROPERTY(QString recommendedModel READ recommendedModel NOTIFY resultChanged)
    // good, fair, poor, or empty before a calibration
    Q_PROPERTY(QString quality READ quality NOTIFY resultChanged)
    Q_PROPERTY(QString qualityText READ qualityText NOTIFY resultChanged)
    Q_PROPERTY(QString savedPath READ savedPath NOTIFY resultChanged)

   public:
    explicit IntrinsicView (QQuickItem* parent = nullptr);
    ~IntrinsicView () override;

    bool charucoAvailable () const;
    QString model () const;
    void setModel (const QString& model);
    int cornersInFrame () const { return detection_ ? static_cast<int>(detection_->ids.size()) : 0; }
    QString target () const;
    void setTarget (const QString& target);
    int totalCorners () const { return target_.cornerCount(); }
    int viewCount () const { return static_cast<int>(views_.size()); }
    double coverage () const;
    QString hint () const { return hint_; }
    bool calibrating () const { return watcher_.isRunning(); }
    bool calibrated () const { return selected() && selected()->calibration.has_value(); }
    QString resultText () const { return result_text_; }
    QVariantList views () const;
    QString savedPath () const { return saved_path_; }
    QVariantList modelResults () const;
    QString recommendedModel () const;
    QString quality () const;
    QString qualityText () const;

    Q_INVOKABLE bool capture ();
    Q_INVOKABLE void removeView (int index);
    Q_INVOKABLE void clearViews ();
    // Removes the views whose error is more than twice the median of the selected model
    Q_INVOKABLE void removeOutlierViews ();
    // Summary of the calibration stored for this camera, or an empty string if there is none
    Q_INVOKABLE QString savedSummary () const;
    // Replaces the views with those of the stored calibration and calibrates again
    Q_INVOKABLE bool loadSaved ();
    Q_INVOKABLE void calibrate ();
    // Returns the written file, or an empty string on failure
    Q_INVOKABLE QString save ();
    Q_INVOKABLE QString savePattern ();
    Q_INVOKABLE QString calibrationDirectory () const;
    Q_INVOKABLE QString patternDownloadUrl () const;

   signals:
    void modelChanged ();
    void targetChanged ();
    void autoCaptureChanged ();
    void detectionChanged ();
    void viewsChanged ();
    void resultChanged ();
    void captured ();

   protected:
    void attachStream (CameraStream& stream) override;
    void detachStream (CameraStream& stream) override;
    void onFrame (const CameraSnapshot& snapshot) override;
    void paintOverlay (QPainter* painter, const QRectF& target, double scale) override;

   private:
    static constexpr int kCoverageCols = 16;
    static constexpr int kCoverageRows = 9;

    // Calibration and held-out validation of one distortion model
    struct ModelResult
    {
        geometry::DistortionModel model = geometry::DistortionModel::Standard;
        std::optional<geometry::IntrinsicCalibration> calibration;
        std::optional<geometry::HeldOutValidation> validation;
    };

    const ModelResult* selected () const;
    std::vector<int> outlierViews () const;
    void updateResultText ();
    void addView (const geometry::CalibrationView& view);
    void invalidateResult ();
    bool isNovel (const geometry::CalibrationView& view) const;
    void updateHint ();
    void onCalibrated ();

    QString usb_port_;
    QString camera_name_;
    geometry::DistortionModel model_ = geometry::DistortionModel::Standard;
    geometry::CharucoTarget target_;
    // Descriptions of the targets the current views were taken with, written into the saved calibration
    std::set<std::string> targets_used_;
    bool auto_capture_ = true;
    std::optional<geometry::CalibrationView> detection_;
    std::optional<geometry::CalibrationView> previous_detection_;
    int still_frames_ = 0;
    int frames_since_capture_ = 0;
    cv::Size image_size_px_;
    std::vector<geometry::CalibrationView> views_;
    std::array<int, kCoverageCols * kCoverageRows> coverage_{};
    QString hint_;
    QFutureWatcher<std::vector<ModelResult>> watcher_;
    std::vector<ModelResult> results_;
    std::optional<geometry::DistortionModel> recommended_;
    QString result_text_;
    QString saved_path_;
};
}  // namespace dartpilot::setup
