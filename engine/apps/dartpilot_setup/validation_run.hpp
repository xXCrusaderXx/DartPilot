#pragma once

#include <memory>
#include <optional>
#include <vector>

#include <QtQml/qqmlregistration.h>
#include <QFutureWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include "camera_stream.hpp"
#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/dart_location.hpp"

namespace dartpilot::setup
{
// Guided validation of the calibration (#48): the user empties the board, puts a dart into the bull centre and then
// darts anywhere, and takes the hand away each time. The run notices by itself when the image is still, averages the
// frames of every camera and measures: first each camera against its calibration on the empty board, then where the
// cameras together put each dart. Every result is appended to validation.jsonl in the calibration directory.
class ValidationRun : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Cameras as CameraFinder lists them
    Q_PROPERTY(QVariantList cameras READ cameras WRITE setCameras NOTIFY camerasChanged)
    // False while the page is hidden: the cameras are released and nothing is measured.
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    // empty, bull or darts
    Q_PROPERTY(QString step READ step NOTIFY stateChanged)
    // moving (waiting for the image to be still), measuring, or waiting (for the next change)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QString instruction READ instruction NOTIFY stateChanged)
    Q_PROPERTY(bool calibrated READ calibrated NOTIFY camerasChanged)
    // Per camera on the empty board: usbPort, number, found, rmsMm, quality (good, fair, poor)
    Q_PROPERTY(QVariantList calibrationChecks READ calibrationChecks NOTIFY resultsChanged)
    // The dart in the bull centre: located, xMm, yMm, errorMm, cameras, worstPlaneMm; empty before
    Q_PROPERTY(QVariantMap bull READ bull NOTIFY resultsChanged)
    // Every further dart, newest first: located, xMm, yMm, label, cameras, worstPlaneMm, sdMm
    Q_PROPERTY(QVariantList darts READ darts NOTIFY resultsChanged)
    // Per USB port the image points to mark in that camera: x, y and kind (dart, or end for a visible end)
    Q_PROPERTY(QVariantMap markers READ markers NOTIFY resultsChanged)
    Q_PROPERTY(QString summary READ summary NOTIFY resultsChanged)

   public:
    explicit ValidationRun (QObject* parent = nullptr);
    ~ValidationRun () override;

    QVariantList cameras () const { return cameras_; }
    void setCameras (const QVariantList& cameras);
    bool active () const { return active_; }
    void setActive (bool active);
    QString step () const { return step_; }
    QString status () const { return status_; }
    QString instruction () const;
    bool calibrated () const { return extrinsics_.has_value(); }
    QVariantList calibrationChecks () const { return calibration_checks_; }
    QVariantMap bull () const { return bull_; }
    QVariantList darts () const { return darts_; }
    QVariantMap markers () const { return markers_; }
    QString summary () const;

    // Starts over with the empty board
    Q_INVOKABLE void restart ();
    // Goes on to darts anywhere without the dart in the bull
    Q_INVOKABLE void skipBull ();

   signals:
    void camerasChanged ();
    void activeChanged ();
    void stateChanged ();
    void resultsChanged ();

   private:
    struct Camera
    {
        QString usb_port;
        QString path;
        int number = 0;
        std::shared_ptr<CameraStream> stream;
        const geometry::RefinedCamera* calibration = nullptr;
        std::uint64_t last_frame = 0;
        cv::Mat previous_small;
        double motion = 0.0;
        cv::Mat sum;
        int summed = 0;
        cv::Mat empty_board;
    };

    struct Measurement
    {
        std::vector<std::optional<geometry::CalibrationCheck>> checks;
        std::vector<std::optional<tip_candidates::DartObservation>> observations;
        std::optional<geometry::DartLocation> location;
        std::vector<cv::Mat> means;
    };

    void openStreams ();
    void closeStreams ();
    void poll ();
    void setStatus (const QString& status);
    void startMeasurement ();
    void onMeasured ();
    void record (const QJsonObject& entry) const;

    QVariantList cameras_;
    bool active_ = false;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<Camera> streams_;
    QTimer timer_;
    QString step_ = "empty";
    QString status_ = "moving";
    // Frames in a row in which no camera moved
    int still_frames_ = 0;
    // After a measurement the scene has to change before the next one.
    bool need_change_ = false;
    QFutureWatcher<Measurement> watcher_;
    QString run_started_;
    QVariantList calibration_checks_;
    QVariantMap bull_;
    QVariantList darts_;
    QVariantMap markers_;
    std::optional<cv::Point2f> last_dart_mm_;
    // Measurements of the run so far, numbering the saved images
    int image_count_ = 0;
};
}  // namespace dartpilot::setup
