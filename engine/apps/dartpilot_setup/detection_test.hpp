#pragma once

#include <memory>
#include <optional>
#include <vector>

#include <QtQml/qqmlregistration.h>
#include <QFile>
#include <QFutureWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include "camera_stream.hpp"
#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/fusion/detection_params.hpp"
#include "dartpilot/geometry/board_refinement.hpp"

namespace dartpilot::setup
{
// The detection test (#195): throw, see what the live detection made of it, rate it, pull, again. The same detection
// as `dartpilot serve` (StillDetector and DartTracker) runs on the cameras, with every value of the registry
// changeable while it runs. Each camera's image shows the axis it found, so a camera that sees the wrong object is
// visible at once. Throws, ratings, takeouts and every change of the values go to a log in
// ~/.local/share/dartpilot/detection-tests, next to the averaged images of every still moment the tracker was given.
class DetectionTest : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Cameras as CameraFinder lists them
    Q_PROPERTY(QVariantList cameras READ cameras WRITE setCameras NOTIFY camerasChanged)
    // False while the page is hidden: the cameras are released and nothing is detected.
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool calibrated READ calibrated NOTIFY camerasChanged)
    // not_calibrated, waiting_for_empty_board (until the first still empty board), ready
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    // Every dart, newest first: id, round, position (1st, 2nd … dart of its round), detected, accepted, label, xMm,
    // yMm, reason, confidence, latencyMs, processingMs, revision, cameras [{number, usbPort, state, used}], outcome
    // (right, wrong, abstained, missed, falseAlarm), truthLabel, errorMm
    Q_PROPERTY(QVariantList darts READ darts NOTIFY resultsChanged)
    // Counts of the outcomes, placedRight, latency medians, takeouts, moved cameras, and byPosition [{position, darts,
    // right, wrong, abstained, missed, falseAlarm}]
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY resultsChanged)
    // Per USB port the marks of the latest dart: its axis per camera, coloured by the camera's state, its ends, the point
    Q_PROPERTY(QVariantMap markers READ markers NOTIFY resultsChanged)
    // Every detection value: name, group, description, unit, min, max, step, value, defaultValue
    Q_PROPERTY(QVariantList params READ params NOTIFY paramsChanged)
    Q_PROPERTY(int revision READ revision NOTIFY paramsChanged)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QString logPath READ logPath NOTIFY stateChanged)

   public:
    explicit DetectionTest (QObject* parent = nullptr);
    ~DetectionTest () override;

    QVariantList cameras () const { return cameras_; }
    void setCameras (const QVariantList& cameras);
    bool active () const { return active_; }
    void setActive (bool active);
    bool calibrated () const { return extrinsics_.has_value(); }
    QString status () const;
    QVariantList darts () const;
    QVariantMap stats () const;
    QVariantMap markers () const { return markers_; }
    QVariantList params () const;
    int revision () const { return revision_; }
    QStringList profiles () const;
    QString logPath () const { return log_.fileName(); }

    // A new test: the tracker waits for the empty board again, the list and counts start empty
    Q_INVOKABLE void restart ();
    // The dart at index (of darts) really is at x, y mm: right if the engine put it in the same field, else wrong
    Q_INVOKABLE void correct (int index, double x_mm, double y_mm);
    // No dart landed where the engine reported one
    Q_INVOKABLE void reject (int index);
    // A dart the engine did not report, in the current round
    Q_INVOKABLE void addMissed (double x_mm, double y_mm);
    // Removes a dart added by mistake
    Q_INVOKABLE void remove (int index);
    // The field of a board point, e.g. T20
    Q_INVOKABLE QString label (double x_mm, double y_mm) const;

    Q_INVOKABLE void setParam (const QString& name, double value);
    Q_INVOKABLE void resetParam (const QString& name);
    Q_INVOKABLE void resetAllParams ();
    Q_INVOKABLE void saveProfile (const QString& name);
    Q_INVOKABLE void loadProfile (const QString& name);

   signals:
    void camerasChanged ();
    void activeChanged ();
    void stateChanged ();
    void resultsChanged ();
    void paramsChanged ();
    void profilesChanged ();
    // A value could not be set or a profile not loaded
    void problem (const QString& message);

   private:
    struct Camera
    {
        QString usb_port;
        QString path;
        int number = 0;
        std::shared_ptr<CameraStream> stream;
        const geometry::RefinedCamera* calibration = nullptr;
        std::uint64_t last_frame = 0;
    };

    struct Dart
    {
        QString id;
        int round = 0;
        int position = 0;
        bool detected = false;
        bool accepted = false;
        std::optional<cv::Point2d> point_mm;
        QString reason;
        double confidence = 0.0;
        double latency_ms = 0.0;
        double processing_ms = 0.0;
        int revision = 0;
        QVariantList cameras;
        QString outcome;
        std::optional<cv::Point2d> truth_mm;
    };

    struct Processed
    {
        fusion::TrackerUpdate update;
        event_detection::StillMoment moment;
        double processing_ms = 0.0;
    };

    void openStreams ();
    void closeStreams ();
    void poll ();
    void process (event_detection::StillMoment moment);
    void onProcessed ();
    void applyParams (const fusion::DetectionSettings& settings);
    void openLog ();
    void log (QJsonObject entry);
    void logRating (const Dart& dart);
    QVariantMap dartMap (const Dart& dart) const;
    int positionInRound () const;

    QVariantList cameras_;
    bool active_ = false;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<Camera> streams_;
    QTimer timer_;
    fusion::DetectionSettings settings_;
    int revision_ = 0;
    // Applied to the still detector and the tracker when no still moment is being processed
    bool settings_changed_ = false;
    std::optional<event_detection::StillDetector> still_;
    std::optional<fusion::DartTracker> tracker_;
    bool ready_ = false;
    std::int64_t next_sample_ns_ = 0;
    QFutureWatcher<Processed> watcher_;
    // A still moment that came while the last one was being processed
    std::optional<event_detection::StillMoment> pending_;
    std::vector<Dart> darts_;
    int round_ = 1;
    int takeouts_ = 0;
    int moved_cameras_ = 0;
    std::vector<double> takeout_latencies_ms_;
    QVariantMap markers_;
    QFile log_;
    QString image_directory_;
    int moment_count_ = 0;
    int added_count_ = 0;
};
}  // namespace dartpilot::setup
