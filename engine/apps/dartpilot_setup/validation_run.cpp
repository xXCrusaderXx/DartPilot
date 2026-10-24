#include "validation_run.hpp"

#include <algorithm>
#include <cmath>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QtConcurrent/QtConcurrentRun>
#include <opencv2/imgproc.hpp>

#include "calibration_paths.hpp"
#include "dartpilot/scoring/score.hpp"

namespace dartpilot::setup
{
namespace
{
constexpr int kPoll_ms = 15;
// Mean brightness change between frames at a quarter of the size; the noise of a still image is about 1, a hand or
// a dart moving in the view gives several.
constexpr double kStillMotion = 2.5;
// Frames in a row without motion before the frames are averaged
constexpr int kStillFrames = 20;
constexpr int kFramesToAverage = 30;
// A dart found within this distance of the previous one is the same dart, not a new measurement.
constexpr double kSameDart_mm = 3.0;
// Provisional, as on the calibration check page
constexpr double kGoodCheck_mm = 1.0;
constexpr double kFairCheck_mm = 2.5;

QString validationPath () { return calibrationDirectory() + "/validation.jsonl"; }

QString checkQuality (double rms_mm) { return rms_mm <= kGoodCheck_mm ? "good" : rms_mm <= kFairCheck_mm ? "fair" : "poor"; }
}  // namespace

ValidationRun::ValidationRun (QObject* parent)
    : QObject(parent)
{
    timer_.setInterval(kPoll_ms);
    connect(&timer_, &QTimer::timeout, this, &ValidationRun::poll);
    connect(&watcher_, &QFutureWatcherBase::finished, this, &ValidationRun::onMeasured);
}

ValidationRun::~ValidationRun ()
{
    timer_.stop();
    watcher_.waitForFinished();
}

void ValidationRun::setCameras (const QVariantList& cameras)
{
    cameras_ = cameras;
    emit camerasChanged();
    restart();
}

void ValidationRun::setActive (bool active)
{
    if(active == active_)
    {
        return;
    }
    active_ = active;
    emit activeChanged();
    if(active_)
    {
        openStreams();
    }
    else
    {
        closeStreams();
    }
}

void ValidationRun::openStreams ()
{
    for(auto& camera : streams_)
    {
        if(!camera.stream && !camera.path.isEmpty())
        {
            camera.stream = CameraStream::acquire(camera.path.toStdString());
        }
    }
    still_frames_ = 0;
    timer_.start();
}

void ValidationRun::closeStreams ()
{
    timer_.stop();
    for(auto& camera : streams_)
    {
        camera.stream.reset();
        camera.previous_small.release();
        camera.sum.release();
        camera.summed = 0;
    }
}

void ValidationRun::restart ()
{
    watcher_.waitForFinished();
    closeStreams();
    extrinsics_ = geometry::loadExtrinsics(extrinsicsPath().toStdString());
    streams_.clear();
    for(int i = 0; i < cameras_.size(); ++i)
    {
        const QVariantMap map = cameras_[i].toMap();
        Camera camera;
        camera.usb_port = map.value("usbPort").toString();
        camera.path = map.value("path").toString();
        camera.number = i + 1;
        if(extrinsics_)
        {
            for(const auto& refined : extrinsics_->refinement.cameras)
            {
                if(refined.usb_port == camera.usb_port.toStdString())
                {
                    camera.calibration = &refined;
                }
            }
        }
        streams_.push_back(std::move(camera));
    }
    step_ = "empty";
    status_ = "moving";
    need_change_ = false;
    run_started_ = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    calibration_checks_.clear();
    bull_.clear();
    darts_.clear();
    markers_.clear();
    last_dart_mm_.reset();
    emit stateChanged();
    emit resultsChanged();
    if(active_)
    {
        openStreams();
    }
}

void ValidationRun::skipBull ()
{
    if(step_ == "bull")
    {
        step_ = "darts";
        emit stateChanged();
    }
}

void ValidationRun::setStatus (const QString& status)
{
    if(status != status_)
    {
        status_ = status;
        emit stateChanged();
    }
}

void ValidationRun::poll ()
{
    if(watcher_.isRunning() || streams_.empty() || !extrinsics_)
    {
        return;
    }
    bool new_frame = false;
    double motion = 0.0;
    for(auto& camera : streams_)
    {
        if(!camera.stream)
        {
            continue;
        }
        const CameraSnapshot snapshot = camera.stream->latest();
        if(snapshot.frame.empty() || snapshot.frame_count == camera.last_frame)
        {
            motion = std::max(motion, camera.motion);
            continue;
        }
        camera.last_frame = snapshot.frame_count;
        new_frame = true;
        cv::Mat small;
        cv::resize(snapshot.frame, small, cv::Size(), 0.25, 0.25, cv::INTER_AREA);
        cv::cvtColor(small, small, cv::COLOR_BGR2GRAY);
        small.convertTo(small, CV_32F);
        camera.motion = camera.previous_small.empty() ? 1e9 : cv::mean(cv::abs(small - camera.previous_small))[0];
        camera.previous_small = small;
        motion = std::max(motion, camera.motion);
        if(camera.summed > 0 || still_frames_ >= kStillFrames)
        {
            if(camera.sum.empty())
            {
                camera.sum = cv::Mat::zeros(snapshot.frame.size(), CV_32FC3);
            }
            cv::accumulate(snapshot.frame, camera.sum);
            ++camera.summed;
        }
    }
    if(!new_frame)
    {
        return;
    }
    if(motion > kStillMotion)
    {
        // Something moves: whatever was being averaged is no longer one scene.
        still_frames_ = 0;
        need_change_ = false;
        for(auto& camera : streams_)
        {
            camera.sum.release();
            camera.summed = 0;
        }
        setStatus("moving");
        return;
    }
    if(need_change_)
    {
        still_frames_ = 0;
        return;
    }
    if(still_frames_ < kStillFrames)
    {
        ++still_frames_;
        return;
    }
    setStatus("measuring");
    const bool complete = std::all_of(streams_.begin(), streams_.end(), [] (const Camera& c) { return !c.stream || c.summed >= kFramesToAverage; });
    if(complete)
    {
        startMeasurement();
    }
}

void ValidationRun::startMeasurement ()
{
    std::vector<cv::Mat> means, empty_boards;
    std::vector<const geometry::RefinedCamera*> calibrations;
    for(auto& camera : streams_)
    {
        cv::Mat mean;
        if(camera.summed > 0)
        {
            mean = camera.sum / camera.summed;
        }
        means.push_back(mean);
        empty_boards.push_back(camera.empty_board);
        calibrations.push_back(camera.calibration);
        camera.sum.release();
        camera.summed = 0;
    }
    still_frames_ = 0;
    need_change_ = true;
    const bool empty_step = step_ == "empty";
    const geometry::BoardModel board = extrinsics_->refinement.board;
    watcher_.setFuture(QtConcurrent::run(
        [means, empty_boards, calibrations, empty_step, board]
        {
            Measurement measurement;
            measurement.means = means;
            std::vector<geometry::DartView> views;
            for(std::size_t i = 0; i < means.size(); ++i)
            {
                std::optional<geometry::CalibrationCheck> check;
                std::optional<tip_candidates::DartObservation> observation;
                if(!means[i].empty() && calibrations[i])
                {
                    if(empty_step)
                    {
                        cv::Mat image;
                        means[i].convertTo(image, CV_8UC3);
                        if(const auto detection = geometry::detectBoard(image))
                        {
                            check = geometry::checkCalibration(*detection, *calibrations[i], board);
                        }
                    }
                    else if(!empty_boards[i].empty())
                    {
                        observation = tip_candidates::observeDart(means[i], empty_boards[i]);
                        if(observation)
                        {
                            views.push_back({calibrations[i], *observation});
                        }
                    }
                }
                measurement.checks.push_back(check);
                measurement.observations.push_back(observation);
            }
            if(views.size() >= 2)
            {
                measurement.location = geometry::locateDart(views);
                // locateDart counts views among those given; map them back to the cameras.
                if(measurement.location)
                {
                    std::vector<int> cameras;
                    for(const int v : measurement.location->views)
                    {
                        int seen = -1;
                        for(std::size_t i = 0; i < measurement.observations.size(); ++i)
                        {
                            if(measurement.observations[i] && ++seen == v)
                            {
                                cameras.push_back(static_cast<int>(i));
                            }
                        }
                    }
                    measurement.location->views = cameras;
                }
            }
            return measurement;
        }));
}

void ValidationRun::onMeasured ()
{
    const Measurement measurement = watcher_.result();
    if(measurement.means.size() != streams_.size())
    {
        return;
    }
    QJsonObject entry{{"run_started", run_started_},
                      {"created", QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                      {"extrinsics_created", QString::fromStdString(extrinsics_->created)},
                      {"step", step_}};
    if(step_ == "empty")
    {
        calibration_checks_.clear();
        QJsonArray checks;
        for(std::size_t i = 0; i < streams_.size(); ++i)
        {
            auto& camera = streams_[i];
            camera.empty_board = measurement.means[i];
            const auto& check = measurement.checks[i];
            calibration_checks_.append(QVariantMap{{"usbPort", camera.usb_port},
                                                   {"number", camera.number},
                                                   {"found", check.has_value()},
                                                   {"rmsMm", check ? check->rms_mm : 0.0},
                                                   {"quality", check ? checkQuality(check->rms_mm) : QString("poor")}});
            checks.append(QJsonObject{{"camera", "usb-" + camera.usb_port},
                                      {"board_found", check.has_value()},
                                      {"rms_mm", check ? QJsonValue(check->rms_mm) : QJsonValue()},
                                      {"shift_px", check ? QJsonValue(std::hypot(check->mean_shift_px.x, check->mean_shift_px.y)) : QJsonValue()}});
        }
        entry.insert("calibration_checks", checks);
        record(entry);
        step_ = "bull";
        emit stateChanged();
        emit resultsChanged();
        setStatus("waiting");
        return;
    }

    // The image points to show: the located point in every camera, and the visible ends each camera found
    markers_.clear();
    for(std::size_t i = 0; i < streams_.size(); ++i)
    {
        QVariantList points;
        if(measurement.observations[i])
        {
            for(const auto& end : measurement.observations[i]->ends_px)
            {
                points.append(QVariantMap{{"x", end.x}, {"y", end.y}, {"kind", "end"}});
            }
        }
        if(measurement.location && streams_[i].calibration)
        {
            const cv::Point2f p = geometry::boardToImage(*streams_[i].calibration,
                                                         cv::Point3f(measurement.location->board_mm.x, measurement.location->board_mm.y, 0.0f));
            points.append(QVariantMap{{"x", p.x}, {"y", p.y}, {"kind", "dart"}});
        }
        markers_.insert(streams_[i].usb_port, points);
    }

    const bool any_object =
        std::any_of(measurement.observations.begin(), measurement.observations.end(), [] (const auto& o) { return o.has_value(); });
    if(!any_object)
    {
        // The board is empty again: nothing to record, the next dart can come.
        last_dart_mm_.reset();
        emit resultsChanged();
        setStatus("waiting");
        return;
    }
    const auto& location = measurement.location;
    if(location && last_dart_mm_ && cv::norm(location->board_mm - *last_dart_mm_) < kSameDart_mm)
    {
        emit resultsChanged();
        setStatus("waiting");
        return;
    }

    QVariantMap result{{"located", location.has_value()}};
    QJsonArray used;
    double worst_plane_mm = 0.0;
    if(location)
    {
        last_dart_mm_ = location->board_mm;
        QStringList numbers;
        for(std::size_t k = 0; k < location->views.size(); ++k)
        {
            numbers.append(QString::number(streams_[location->views[k]].number));
            worst_plane_mm = std::max(worst_plane_mm, std::abs(location->plane_distance_mm[k]));
            used.append(QJsonObject{{"camera", "usb-" + streams_[location->views[k]].usb_port},
                                    {"plane_distance_mm", location->plane_distance_mm[k]},
                                    {"end_distance_px", location->end_distance_px[k]}});
        }
        const double sd_mm = std::sqrt(0.5 * (location->covariance_mm2(0, 0) + location->covariance_mm2(1, 1)));
        result.insert("xMm", location->board_mm.x);
        result.insert("yMm", location->board_mm.y);
        result.insert("label", QString::fromStdString(scoring::label(scoring::score(location->board_mm.x, location->board_mm.y))));
        result.insert("cameras", numbers.join(", "));
        result.insert("worstPlaneMm", worst_plane_mm);
        result.insert("sdMm", sd_mm);
        entry.insert("board_mm", QJsonArray{location->board_mm.x, location->board_mm.y});
        entry.insert(
            "covariance_mm2",
            QJsonObject{{"xx", location->covariance_mm2(0, 0)}, {"xy", location->covariance_mm2(0, 1)}, {"yy", location->covariance_mm2(1, 1)}});
        entry.insert("views", used);
    }
    entry.insert("located", location.has_value());
    QJsonArray seen;
    for(std::size_t i = 0; i < streams_.size(); ++i)
    {
        if(measurement.observations[i])
        {
            seen.append("usb-" + streams_[i].usb_port);
        }
    }
    entry.insert("cameras_seeing_object", seen);
    if(step_ == "bull")
    {
        if(location)
        {
            result.insert("errorMm", std::hypot(location->board_mm.x, location->board_mm.y));
        }
        entry.insert("reference", "bull");
        bull_ = result;
        step_ = "darts";
    }
    else
    {
        darts_.prepend(result);
    }
    record(entry);
    emit stateChanged();
    emit resultsChanged();
    setStatus("waiting");
}

void ValidationRun::record (const QJsonObject& entry) const
{
    if(!QDir().mkpath(calibrationDirectory()))
    {
        return;
    }
    QFile file(validationPath());
    if(file.open(QIODevice::Append | QIODevice::Text))
    {
        file.write(QJsonDocument(entry).toJson(QJsonDocument::Compact) + "\n");
    }
}

QString ValidationRun::instruction () const
{
    if(!extrinsics_)
    {
        return "No refinement yet: calibrate the cameras on the extrinsic page first (step 5).";
    }
    if(status_ == "measuring")
    {
        return "Hold still: measuring …";
    }
    if(step_ == "empty")
    {
        return status_ == "moving" ? "Remove all darts and take your hand out of view."
                                   : "Empty the board; the reference is taken when the image is still.";
    }
    if(step_ == "bull")
    {
        return "Put a dart exactly into the centre of the bull, then take your hand away.";
    }
    return status_ == "moving" ? "Take your hand away; the dart is measured when the image is still."
                               : "Put a dart anywhere on the board, or move it, then take your hand away. Pull it out before the next one.";
}

QString ValidationRun::summary () const
{
    int located = 0, abstained = 0;
    std::vector<double> planes;
    for(const auto& item : darts_)
    {
        const QVariantMap dart = item.toMap();
        if(dart.value("located").toBool())
        {
            ++located;
            planes.push_back(dart.value("worstPlaneMm").toDouble());
        }
        else
        {
            ++abstained;
        }
    }
    if(located + abstained == 0)
    {
        return {};
    }
    QString text = QString("%1 darts located, %2 abstained.").arg(located).arg(abstained);
    if(!planes.empty())
    {
        std::sort(planes.begin(), planes.end());
        text += QString(" The cameras agree within %1 mm (median of the worst camera per dart).").arg(planes[planes.size() / 2], 0, 'f', 2);
    }
    return text;
}
}  // namespace dartpilot::setup
