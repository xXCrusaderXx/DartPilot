#include "detection_test.hpp"

#include <algorithm>
#include <cmath>

#include <QDateTime>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QtConcurrent/QtConcurrentRun>
#include <opencv2/imgcodecs.hpp>

#include "calibration_paths.hpp"
#include "dartpilot/capture/frame.hpp"
#include "dartpilot/geometry/board_state.hpp"
#include "dartpilot/scoring/score.hpp"

namespace dartpilot::setup
{
namespace
{
constexpr int kPoll_ms = 5;

QString testDirectory () { return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/dartpilot/detection-tests"; }
QString profileDirectory () { return calibrationDirectory() + "/detection-profiles"; }

QString colourOf (const QString& state)
{
    return state == "seen" ? "#34d399" : state == "cut" ? "#fbbf24" : state == "disagrees" ? "#f87171" : "#94a3b8";
}

double median (std::vector<double> values)
{
    if(values.empty())
    {
        return -1.0;
    }
    std::nth_element(values.begin(), values.begin() + values.size() / 2, values.end());
    return values[values.size() / 2];
}

QJsonObject paramsJson (const fusion::DetectionSettings& settings)
{
    QJsonObject params;
    for(const auto& param : fusion::detectionParams())
    {
        params.insert(QString::fromStdString(param.name), param.get(settings));
    }
    return params;
}

QJsonValue pointJson (const std::optional<cv::Point2d>& point)
{
    return point ? QJsonValue(QJsonObject{{"x_mm", point->x}, {"y_mm", point->y}}) : QJsonValue(QJsonValue::Null);
}
}  // namespace

DetectionTest::DetectionTest (QObject* parent)
    : QObject(parent)
{
    timer_.setInterval(kPoll_ms);
    timer_.setTimerType(Qt::PreciseTimer);
    connect(&timer_, &QTimer::timeout, this, &DetectionTest::poll);
    connect(&watcher_, &QFutureWatcherBase::finished, this, &DetectionTest::onProcessed);
}

DetectionTest::~DetectionTest ()
{
    timer_.stop();
    watcher_.waitForFinished();
}

void DetectionTest::setCameras (const QVariantList& cameras)
{
    cameras_ = cameras;
    emit camerasChanged();
    restart();
}

void DetectionTest::setActive (bool active)
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

QString DetectionTest::status () const
{
    if(!extrinsics_)
    {
        return "not_calibrated";
    }
    return ready_ ? "ready" : "waiting_for_empty_board";
}

void DetectionTest::openStreams ()
{
    for(auto& camera : streams_)
    {
        if(!camera.stream && !camera.path.isEmpty())
        {
            camera.stream = CameraStream::acquire(camera.path.toStdString());
        }
    }
    // The stillness starts afresh: the board may have changed while the page was hidden.
    still_.emplace(streams_.size(), settings_.still);
    next_sample_ns_ = 0;
    timer_.start();
}

void DetectionTest::closeStreams ()
{
    timer_.stop();
    for(auto& camera : streams_)
    {
        camera.stream.reset();
    }
}

void DetectionTest::restart ()
{
    watcher_.waitForFinished();
    closeStreams();
    extrinsics_ = geometry::loadExtrinsics(extrinsicsPath().toStdString());
    streams_.clear();
    std::vector<fusion::TrackerCamera> tracker_cameras;
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
        const auto reference = calibrationDirectory().toStdString() + "/" + geometry::emptyReferenceFileName(camera.usb_port.toStdString());
        tracker_cameras.push_back({"usb-" + camera.usb_port.toStdString(), camera.calibration, geometry::loadEmptyReference(reference)});
        streams_.push_back(std::move(camera));
    }
    tracker_.reset();
    if(extrinsics_)
    {
        tracker_.emplace(tracker_cameras, extrinsics_->refinement.board, settings_.tracker);
    }
    ready_ = false;
    pending_.reset();
    darts_.clear();
    round_ = 1;
    takeouts_ = 0;
    moved_cameras_ = 0;
    takeout_latencies_ms_.clear();
    markers_.clear();
    moment_count_ = 0;
    added_count_ = 0;
    openLog();
    emit stateChanged();
    emit resultsChanged();
    if(active_)
    {
        openStreams();
    }
}

void DetectionTest::openLog ()
{
    log_.close();
    const QString started = QDateTime::currentDateTimeUtc().toString("yyyyMMddTHHmmssZ");
    log_.setFileName(testDirectory() + "/" + started + ".jsonl");
    image_directory_ = testDirectory() + "/" + started;
}

void DetectionTest::log (QJsonObject entry)
{
    // Created with the first still moment, so that opening the page leaves no empty test behind
    if(!log_.isOpen())
    {
        if(entry.value("type").toString() == "params")
        {
            return;
        }
        QDir().mkpath(testDirectory());
        if(!log_.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
        {
            return;
        }
        QJsonArray cameras;
        for(const auto& camera : streams_)
        {
            cameras.append(QJsonObject{{"number", camera.number}, {"usb_port", camera.usb_port}, {"calibrated", camera.calibration != nullptr}});
        }
        log(QJsonObject{{"type", "start"}, {"started_utc", QDateTime::currentDateTimeUtc().toString(Qt::ISODate)}, {"cameras", cameras}});
        log(QJsonObject{{"type", "params"}, {"revision", revision_}, {"params", paramsJson(settings_)}});
    }
    entry.insert("t_ns", static_cast<qint64>(capture::monotonicNowNs()));
    log_.write(QJsonDocument(entry).toJson(QJsonDocument::Compact) + "\n");
    log_.flush();
}

void DetectionTest::poll ()
{
    if(!tracker_ || !still_ || streams_.empty())
    {
        return;
    }
    const std::int64_t now_ns = capture::monotonicNowNs();
    if(next_sample_ns_ != 0 && now_ns < next_sample_ns_)
    {
        return;
    }
    // Fixed steps, as in serve; after a stall the next sample is one step from now.
    next_sample_ns_ = std::max(next_sample_ns_ + settings_.still.sample_interval_ns, now_ns);
    std::vector<std::optional<event_detection::StillSample>> samples(streams_.size());
    for(std::size_t c = 0; c < streams_.size(); ++c)
    {
        auto& camera = streams_[c];
        if(!camera.stream)
        {
            continue;
        }
        const CameraSnapshot snapshot = camera.stream->latest();
        if(snapshot.frame.empty() || snapshot.frame_count == camera.last_frame)
        {
            continue;
        }
        camera.last_frame = snapshot.frame_count;
        samples[c] = event_detection::StillSample{snapshot.frame, static_cast<std::uint32_t>(snapshot.frame_count), now_ns};
    }
    if(auto moment = still_->addSample(now_ns, samples, !ready_))
    {
        if(watcher_.isRunning())
        {
            pending_ = std::move(*moment);
        }
        else
        {
            process(std::move(*moment));
        }
    }
}

void DetectionTest::process (event_detection::StillMoment moment)
{
    if(settings_changed_)
    {
        tracker_->setSettings(settings_.tracker);
        settings_changed_ = false;
    }
    // Every still moment is kept, so that the tracker can be run over the test again with other values.
    const QString moment_directory = image_directory_ + QString("/%1").arg(++moment_count_, 5, 10, QChar('0'));
    QDir().mkpath(moment_directory);
    QJsonArray frames;
    for(std::size_t c = 0; c < moment.means.size(); ++c)
    {
        frames.append(QJsonArray::fromVariantList(
            [&]
            {
                QVariantList list;
                for(const auto f : moment.frames[c])
                {
                    list.append(static_cast<qint64>(f));
                }
                return list;
            }()));
    }
    log(QJsonObject{{"type", "still"},
                    {"moment", moment_count_},
                    {"start_ns", static_cast<qint64>(moment.start_ns)},
                    {"last_motion_ns", static_cast<qint64>(moment.last_motion_ns)},
                    {"revision", revision_},
                    {"frames", frames}});
    fusion::DartTracker* tracker = &*tracker_;
    watcher_.setFuture(QtConcurrent::run(
        [tracker, moment = std::move(moment), moment_directory,
         ports =
             [&]
         {
             std::vector<std::string> list;
             for(const auto& camera : streams_)
             {
                 list.push_back(camera.usb_port.toStdString());
             }
             return list;
         }()] () mutable
        {
            Processed processed;
            const auto started = std::chrono::steady_clock::now();
            processed.update = tracker->addStill(moment.means);
            processed.processing_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count();
            for(std::size_t c = 0; c < moment.means.size() && c < ports.size(); ++c)
            {
                cv::Mat image;
                moment.means[c].convertTo(image, CV_8UC3);
                cv::imwrite(moment_directory.toStdString() + "/usb-" + ports[c] + ".png", image);
            }
            processed.moment = std::move(moment);
            return processed;
        }));
}

int DetectionTest::positionInRound () const
{
    return static_cast<int>(
               std::count_if(darts_.begin(), darts_.end(), [&] (const Dart& d) { return d.round == round_ && d.outcome != "falseAlarm"; })) +
           1;
}

void DetectionTest::onProcessed ()
{
    const Processed processed = watcher_.result();
    const auto& update = processed.update;
    const double latency_ms = (capture::monotonicNowNs() - processed.moment.last_motion_ns) / 1e6;
    if(update.became_ready)
    {
        ready_ = true;
        log(QJsonObject{{"type", "ready"}});
        emit stateChanged();
    }
    for(const auto& [camera, shift] : update.moved_cameras)
    {
        ++moved_cameras_;
        log(QJsonObject{
            {"type", "camera_moved"}, {"camera", streams_[static_cast<std::size_t>(camera)].number}, {"shift_px", QJsonArray{shift.x, shift.y}}});
    }
    if(update.takeout)
    {
        ++takeouts_;
        takeout_latencies_ms_.push_back(latency_ms);
        log(QJsonObject{{"type", "takeout"}, {"round", round_}, {"darts_removed", *update.takeout}, {"latency_ms", latency_ms}});
        ++round_;
        markers_.clear();
    }
    if(update.dart)
    {
        const auto& tracked = *update.dart;
        Dart dart;
        dart.id = QString::number(moment_count_);
        dart.round = round_;
        dart.position = positionInRound();
        dart.detected = true;
        dart.accepted = tracked.location.has_value();
        if(tracked.location)
        {
            dart.point_mm = cv::Point2d(tracked.location->board_mm.x, tracked.location->board_mm.y);
            dart.confidence = tracked.location->views.size() >= 3 ? settings_.confidence.three_cameras : settings_.confidence.two_cameras;
            dart.outcome = "right";
        }
        else
        {
            dart.reason = QString::fromStdString(tracked.reason);
            dart.confidence = settings_.confidence.abstained;
            dart.outcome = "abstained";
        }
        dart.latency_ms = latency_ms;
        dart.processing_ms = processed.processing_ms;
        dart.revision = revision_;
        markers_.clear();
        QJsonArray cameras_json;
        for(std::size_t c = 0; c < tracked.cameras.size() && c < streams_.size(); ++c)
        {
            const auto& view = tracked.cameras[c];
            const auto& camera = streams_[c];
            const QString state = QString::fromStdString(view.state);
            dart.cameras.append(QVariantMap{{"number", camera.number}, {"usbPort", camera.usb_port}, {"state", state}, {"used", view.used}});
            cameras_json.append(QJsonObject{{"camera", camera.number}, {"state", state}, {"used", view.used}});
            QVariantList marks;
            if(view.observation && view.observation->axis_px.size() >= 2)
            {
                const auto& axis = view.observation->axis_px;
                marks.append(QVariantMap{{"kind", "axis"},
                                         {"x", axis.front().x},
                                         {"y", axis.front().y},
                                         {"x2", axis.back().x},
                                         {"y2", axis.back().y},
                                         {"colour", colourOf(state)}});
                for(const auto& end : view.observation->ends_px)
                {
                    marks.append(QVariantMap{{"kind", "end"}, {"x", end.x}, {"y", end.y}});
                }
            }
            if(tracked.location && camera.calibration)
            {
                const auto p =
                    geometry::boardToImage(*camera.calibration, cv::Point3f(tracked.location->board_mm.x, tracked.location->board_mm.y, 0.0f));
                marks.append(QVariantMap{{"kind", "dart"}, {"x", p.x}, {"y", p.y}});
            }
            markers_.insert(camera.usb_port, marks);
        }
        log(QJsonObject{{"type", "throw"},
                        {"id", dart.id},
                        {"round", dart.round},
                        {"position", dart.position},
                        {"accepted", dart.accepted},
                        {"board_point", pointJson(dart.point_mm)},
                        {"label", dart.point_mm ? label(dart.point_mm->x, dart.point_mm->y) : QString()},
                        {"reason", dart.reason},
                        {"confidence", dart.confidence},
                        {"latency_ms", dart.latency_ms},
                        {"processing_ms", dart.processing_ms},
                        {"revision", dart.revision},
                        {"moment", moment_count_},
                        {"cameras", cameras_json}});
        darts_.push_back(std::move(dart));
    }
    emit resultsChanged();
    if(pending_)
    {
        auto moment = std::move(*pending_);
        pending_.reset();
        process(std::move(moment));
    }
}

QString DetectionTest::label (double x_mm, double y_mm) const { return QString::fromStdString(scoring::label(scoring::score(x_mm, y_mm))); }

void DetectionTest::logRating (const Dart& dart)
{
    log(QJsonObject{{"type", "rating"}, {"id", dart.id}, {"outcome", dart.outcome}, {"truth", pointJson(dart.truth_mm)}});
}

void DetectionTest::correct (int index, double x_mm, double y_mm)
{
    // darts as shown: newest first
    const int i = static_cast<int>(darts_.size()) - 1 - index;
    if(i < 0 || i >= static_cast<int>(darts_.size()))
    {
        return;
    }
    Dart& dart = darts_[static_cast<std::size_t>(i)];
    dart.truth_mm = cv::Point2d(x_mm, y_mm);
    if(dart.accepted)
    {
        // The test rates fields; the replay benchmark measures millimetres.
        dart.outcome = label(dart.point_mm->x, dart.point_mm->y) == label(x_mm, y_mm) ? "right" : "wrong";
    }
    else if(dart.outcome == "falseAlarm")
    {
        dart.outcome = dart.detected ? (dart.accepted ? "right" : "abstained") : "missed";
    }
    logRating(dart);
    emit resultsChanged();
}

void DetectionTest::reject (int index)
{
    const int i = static_cast<int>(darts_.size()) - 1 - index;
    if(i < 0 || i >= static_cast<int>(darts_.size()) || !darts_[static_cast<std::size_t>(i)].detected)
    {
        return;
    }
    Dart& dart = darts_[static_cast<std::size_t>(i)];
    dart.outcome = "falseAlarm";
    dart.truth_mm.reset();
    logRating(dart);
    emit resultsChanged();
}

void DetectionTest::addMissed (double x_mm, double y_mm)
{
    Dart dart;
    dart.id = "added-" + QString::number(++added_count_);
    dart.round = round_;
    dart.position = positionInRound();
    dart.outcome = "missed";
    dart.truth_mm = cv::Point2d(x_mm, y_mm);
    dart.revision = revision_;
    log(QJsonObject{{"type", "missed"}, {"id", dart.id}, {"round", dart.round}, {"position", dart.position}, {"truth", pointJson(dart.truth_mm)}});
    darts_.push_back(std::move(dart));
    emit resultsChanged();
}

void DetectionTest::remove (int index)
{
    const int i = static_cast<int>(darts_.size()) - 1 - index;
    if(i < 0 || i >= static_cast<int>(darts_.size()) || darts_[static_cast<std::size_t>(i)].detected)
    {
        return;
    }
    log(QJsonObject{{"type", "removed"}, {"id", darts_[static_cast<std::size_t>(i)].id}});
    darts_.erase(darts_.begin() + i);
    emit resultsChanged();
}

QVariantMap DetectionTest::dartMap (const Dart& dart) const
{
    QVariantMap map{{"id", dart.id},
                    {"round", dart.round},
                    {"position", dart.position},
                    {"detected", dart.detected},
                    {"accepted", dart.accepted},
                    {"reason", dart.reason},
                    {"confidence", dart.confidence},
                    {"latencyMs", dart.latency_ms},
                    {"processingMs", dart.processing_ms},
                    {"revision", dart.revision},
                    {"cameras", dart.cameras},
                    {"outcome", dart.outcome}};
    if(dart.point_mm)
    {
        map.insert("xMm", dart.point_mm->x);
        map.insert("yMm", dart.point_mm->y);
        map.insert("label", label(dart.point_mm->x, dart.point_mm->y));
    }
    if(dart.truth_mm)
    {
        map.insert("truthLabel", label(dart.truth_mm->x, dart.truth_mm->y));
        if(dart.point_mm)
        {
            map.insert("errorMm", cv::norm(*dart.point_mm - *dart.truth_mm));
        }
    }
    return map;
}

QVariantList DetectionTest::darts () const
{
    QVariantList list;
    for(auto it = darts_.rbegin(); it != darts_.rend(); ++it)
    {
        list.append(dartMap(*it));
    }
    return list;
}

QVariantMap DetectionTest::stats () const
{
    QVariantMap counts{{"right", 0}, {"wrong", 0}, {"abstained", 0}, {"missed", 0}, {"falseAlarm", 0}};
    std::map<int, QVariantMap> by_position;
    std::vector<double> latencies, processing, errors;
    for(const auto& dart : darts_)
    {
        counts[dart.outcome] = counts[dart.outcome].toInt() + 1;
        auto& position = by_position[dart.position];
        position["position"] = dart.position;
        position["darts"] = position.value("darts").toInt() + (dart.outcome == "falseAlarm" ? 0 : 1);
        position[dart.outcome] = position.value(dart.outcome).toInt() + 1;
        if(dart.detected)
        {
            latencies.push_back(dart.latency_ms);
            processing.push_back(dart.processing_ms);
        }
        if(dart.outcome == "wrong" && dart.point_mm && dart.truth_mm)
        {
            errors.push_back(cv::norm(*dart.point_mm - *dart.truth_mm));
        }
    }
    const int placed = counts["right"].toInt() + counts["wrong"].toInt();
    QVariantList positions;
    for(const auto& [number, position] : by_position)
    {
        positions.append(position);
    }
    return {{"counts", counts},
            {"placedRight", placed > 0 ? QVariant(counts["right"].toDouble() / placed) : QVariant()},
            {"latencyMedianMs", median(latencies)},
            {"processingMedianMs", median(processing)},
            {"takeoutLatencyMedianMs", median(takeout_latencies_ms_)},
            {"wrongErrorMedianMm", median(errors)},
            {"takeouts", takeouts_},
            {"rounds", round_},
            {"movedCameras", moved_cameras_},
            {"byPosition", positions}};
}

QVariantList DetectionTest::params () const
{
    QVariantList list;
    for(const auto& param : fusion::detectionParams())
    {
        list.append(paramMap(param));
    }
    return list;
}

QVariantMap DetectionTest::paramMap (const fusion::DetectionParam& param) const
{
    return QVariantMap{{"name", QString::fromStdString(param.name)},
                       {"group", QString::fromStdString(param.group)},
                       {"description", QString::fromStdString(param.description)},
                       {"unit", QString::fromStdString(param.unit)},
                       {"min", param.min},
                       {"max", param.max},
                       {"step", param.step},
                       {"value", param.get(settings_)},
                       {"defaultValue", param.defaultValue()}};
}

QStringList DetectionTest::paramNames (const QString& group) const
{
    QStringList names;
    for(const auto& param : fusion::detectionParams())
    {
        if(QString::fromStdString(param.group) == group)
        {
            names.append(QString::fromStdString(param.name));
        }
    }
    return names;
}

QVariantMap DetectionTest::param (const QString& name, int /*revision*/) const
{
    for(const auto& param : fusion::detectionParams())
    {
        if(QString::fromStdString(param.name) == name)
        {
            return paramMap(param);
        }
    }
    return {};
}

void DetectionTest::applyParams (const fusion::DetectionSettings& settings)
{
    settings_ = settings;
    ++revision_;
    settings_changed_ = true;
    // The stillness starts afresh with the new values; the tracker takes them with the next still moment.
    if(still_)
    {
        still_.emplace(streams_.size(), settings_.still);
    }
    if(!watcher_.isRunning() && tracker_)
    {
        tracker_->setSettings(settings_.tracker);
        settings_changed_ = false;
    }
    log(QJsonObject{{"type", "params"}, {"revision", revision_}, {"params", paramsJson(settings_)}});
    emit paramsChanged();
}

void DetectionTest::setParam (const QString& name, double value)
{
    auto settings = settings_;
    if(const auto error = fusion::setDetectionParam(settings, name.toStdString(), value))
    {
        emit problem(QString::fromStdString(*error));
        return;
    }
    applyParams(settings);
}

void DetectionTest::resetParam (const QString& name)
{
    if(const auto* param = fusion::findDetectionParam(name.toStdString()))
    {
        setParam(name, param->defaultValue());
    }
}

void DetectionTest::resetAllParams () { applyParams(fusion::DetectionSettings{}); }

QStringList DetectionTest::profiles () const
{
    QStringList names;
    for(const auto& file : QDir(profileDirectory()).entryList({"*.json"}, QDir::Files, QDir::Name))
    {
        names.append(file.chopped(5));
    }
    return names;
}

void DetectionTest::saveProfile (const QString& name)
{
    const QString clean = name.trimmed();
    if(clean.isEmpty() || clean.contains('/'))
    {
        emit problem("A profile needs a name without slashes.");
        return;
    }
    QDir().mkpath(profileDirectory());
    QFile file(profileDirectory() + "/" + clean + ".json");
    // Only the values that differ from their defaults, so that a profile follows later changes of the others
    QJsonObject changed;
    const fusion::DetectionSettings defaults;
    for(const auto& param : fusion::detectionParams())
    {
        if(param.get(settings_) != param.get(defaults))
        {
            changed.insert(QString::fromStdString(param.name), param.get(settings_));
        }
    }
    if(!file.open(QIODevice::WriteOnly | QIODevice::Truncate) || file.write(QJsonDocument(QJsonObject{{"params", changed}}).toJson()) < 0)
    {
        emit problem("Cannot write " + file.fileName());
        return;
    }
    emit profilesChanged();
}

void DetectionTest::loadProfile (const QString& name)
{
    QFile file(profileDirectory() + "/" + name + ".json");
    if(!file.open(QIODevice::ReadOnly))
    {
        emit problem("Cannot read " + file.fileName());
        return;
    }
    const QJsonObject params = QJsonDocument::fromJson(file.readAll()).object().value("params").toObject();
    fusion::DetectionSettings settings;
    for(auto it = params.begin(); it != params.end(); ++it)
    {
        if(const auto error = fusion::setDetectionParam(settings, it.key().toStdString(), it.value().toDouble()))
        {
            emit problem(QString::fromStdString(*error));
            return;
        }
    }
    applyParams(settings);
}
}  // namespace dartpilot::setup
