#include "live_detection.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/capture/frame.hpp"
#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/detection_params.hpp"
#include "dartpilot/geometry/board_state.hpp"

namespace dartpilot::cli
{
namespace
{
}  // namespace

LiveDetection::LiveDetection (api::Server& server, const FrameFeed& previews, const std::vector<capture::CameraDevice>& devices,
                              const std::filesystem::path& calibration_directory, bool stored_references)
    : server_(server)
    , previews_(previews)
    , extrinsics_(geometry::loadExtrinsics((calibration_directory / "extrinsics.yml").string()))
{
    std::vector<fusion::TrackerCamera> cameras;
    for(const auto& device : devices)
    {
        fusion::TrackerCamera camera{
            "usb-" + device.usb_port, nullptr,
            stored_references ? geometry::loadEmptyReference((calibration_directory / geometry::emptyReferenceFileName(device.usb_port)).string())
                              : cv::Mat()};
        if(extrinsics_)
        {
            for(const auto& refined : extrinsics_->refinement.cameras)
            {
                if(refined.usb_port == device.usb_port)
                {
                    camera.calibration = &refined;
                }
            }
        }
        cameras.push_back(camera);
        cameras_.push_back({});
        cameras_.back().id = camera.id;
    }
    if(extrinsics_)
    {
        tracker_.emplace(cameras, extrinsics_->refinement.board, settings_.tracker);
    }
    server_.onCalibrationRequest("get_detection_params",
                                 [this] (const api::CalibrationRequest&) -> std::optional<api::Server::CalibrationError>
                                 {
                                     server_.publishState(paramsMessage());
                                     return std::nullopt;
                                 });
    server_.onCalibrationRequest("set_detection_params",
                                 [this] (const api::CalibrationRequest& request) -> std::optional<api::Server::CalibrationError>
                                 {
                                     if(const auto error = setParams(request.body.value("params", nlohmann::json::object())))
                                     {
                                         return api::Server::CalibrationError{"bad_request", *error};
                                     }
                                     return std::nullopt;
                                 });
}

LiveDetection::~LiveDetection ()
{
    stop();
    server_.onCalibrationRequest("get_detection_params", {});
    server_.onCalibrationRequest("set_detection_params", {});
}

nlohmann::json LiveDetection::paramsMessage () const
{
    nlohmann::json params = nlohmann::json::object(), ranges = nlohmann::json::object(), info = nlohmann::json::object();
    std::lock_guard lock(settings_mutex_);
    for(const auto& param : fusion::detectionParams())
    {
        params[param.name] = param.get(settings_);
        ranges[param.name] = {{"min", param.min}, {"max", param.max}, {"step", param.step}, {"unit", param.unit}};
        info[param.name] = {{"group", param.group}, {"description", param.description}, {"default", param.defaultValue()}};
    }
    return {{"type", "detection_params"}, {"revision", params_revision_}, {"params", params}, {"ranges", ranges}, {"info", info}};
}

void LiveDetection::onParamsChanged (std::function<void(const nlohmann::json&)> handler)
{
    std::lock_guard lock(settings_mutex_);
    params_handler_ = std::move(handler);
}

std::optional<std::string> LiveDetection::setParams (const nlohmann::json& params)
{
    if(!params.is_object())
    {
        return "params must be an object";
    }
    std::function<void(const nlohmann::json&)> handler;
    {
        std::lock_guard lock(settings_mutex_);
        auto settings = settings_;
        for(const auto& [name, value] : params.items())
        {
            const auto* param = fusion::findDetectionParam(name);
            if(!param)
            {
                return "Unknown detection value " + name;
            }
            // null returns a value to its default
            if(!value.is_null() && !value.is_number())
            {
                return name + " must be a number or null";
            }
            if(const auto error = fusion::setDetectionParam(settings, name, value.is_null() ? param->defaultValue() : value.get<double>()))
            {
                return error;
            }
        }
        settings_ = settings;
        settings_changed_ = true;
        ++params_revision_;
        handler = params_handler_;
    }
    const auto message = paramsMessage();
    server_.publishState(message);
    if(handler)
    {
        handler(message);
    }
    return std::nullopt;
}

std::optional<std::string> LiveDetection::unavailableReason () const
{
    if(!tracker_)
    {
        return "not_calibrated";
    }
    return std::nullopt;
}

void LiveDetection::start ()
{
    if(!tracker_ || thread_.joinable())
    {
        return;
    }
    stop_ = false;
    server_.publishState(paramsMessage());
    thread_ = std::thread([this] { run(); });
}

void LiveDetection::stop ()
{
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
}

std::optional<event_detection::StillSample> LiveDetection::sample (Camera& camera, std::size_t index)
{
    std::vector<std::uint8_t> jpeg;
    std::uint32_t sequence = 0;
    if(!previews_.latest(index, jpeg, sequence) || (camera.seen && sequence == camera.last_sequence))
    {
        return std::nullopt;
    }
    event_detection::StillSample sample;
    sample.image = cv::imdecode(jpeg, cv::IMREAD_COLOR);
    if(sample.image.empty())
    {
        return std::nullopt;
    }
    camera.seen = true;
    camera.last_sequence = sequence;
    sample.sequence = sequence;
    sample.exposure_ns = capture::monotonicNowNs();
    return sample;
}

void LiveDetection::run ()
{
    // The same still moments as a replay of the recording (event_detection::StillSettings); while it waits for an empty
    // board, a still board is checked again, as the first check may have come while the exposure was still settling.
    std::optional<event_detection::StillDetector> still;
    fusion::ConfidenceSettings confidence;
    int revision = 0;
    while(!stop_)
    {
        {
            std::lock_guard lock(settings_mutex_);
            if(!still || settings_changed_)
            {
                still.emplace(cameras_.size(), settings_.still);
                tracker_->setSettings(settings_.tracker);
                confidence = settings_.confidence;
                revision = params_revision_;
                settings_changed_ = false;
            }
        }
        const auto next = std::chrono::steady_clock::now() + std::chrono::nanoseconds(still->settings().sample_interval_ns);
        std::vector<std::optional<event_detection::StillSample>> samples;
        for(std::size_t i = 0; i < cameras_.size(); ++i)
        {
            samples.push_back(sample(cameras_[i], i));
        }
        if(!running_)
        {
            // Paused: a person may move in front of the board, so the next still moment is measured afresh.
            samples.assign(cameras_.size(), std::nullopt);
            still.emplace(cameras_.size(), still->settings());
        }
        else if(const auto moment = still->addSample(capture::monotonicNowNs(), samples, !tracker_->ready()))
        {
            const auto started = std::chrono::steady_clock::now();
            const auto update = tracker_->addStill(moment->means);
            if(std::getenv("DARTPILOT_TRACE"))
            {
                std::fprintf(stderr, "still: ready %d darts %d dart %s takeout %d\n", tracker_->ready(), tracker_->dartsInBoard(),
                             update.dart ? (update.dart->location ? "located" : update.dart->reason.c_str()) : "-", update.takeout.value_or(-1));
            }
            const double latency_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count();
            publish(update, *moment, latency_ms, (capture::monotonicNowNs() - moment->last_motion_ns) / 1e6, confidence, revision);
        }
        std::this_thread::sleep_until(next);
    }
}

void LiveDetection::intercept (Interceptor handler)
{
    std::lock_guard lock(intercept_mutex_);
    intercept_ = std::move(handler);
}

bool LiveDetection::intercepted () const
{
    std::lock_guard lock(intercept_mutex_);
    return static_cast<bool>(intercept_);
}

void LiveDetection::publish (const fusion::TrackerUpdate& update, const event_detection::StillMoment& moment, double latency_ms,
                             double detection_latency_ms, const fusion::ConfidenceSettings& confidence, int params_revision)
{
    ready_ = tracker_ && tracker_->ready();
    Interceptor intercept;
    {
        std::lock_guard lock(intercept_mutex_);
        intercept = intercept_;
    }
    if(intercept)
    {
        intercept(update, moment.means);
        return;
    }
    if(update.became_ready && running_)
    {
        server_.publishEngineStatus("running", "");
    }
    if(update.takeout)
    {
        server_.publishTakeout(moment.start_ns, *update.takeout, detection_latency_ms);
    }
    for(const auto& [camera, shift] : update.moved_cameras)
    {
        server_.publishEvent({{"type", "camera_moved"}, {"camera", cameras_[static_cast<std::size_t>(camera)].id}, {"shift_px", {shift.x, shift.y}}});
    }
    if(!update.dart)
    {
        return;
    }
    const auto& dart = *update.dart;
    api::Throw thrown;
    thrown.event_ns = moment.start_ns;
    thrown.accepted = dart.location.has_value();
    thrown.processing_latency_ms = latency_ms;
    thrown.detection_latency_ms = detection_latency_ms;
    thrown.params_revision = params_revision;
    if(dart.location)
    {
        const auto& p = dart.location->board_mm;
        const auto& c = dart.location->covariance_mm2;
        thrown.board_point = api::BoardPoint{p.x, p.y, std::array<double, 3>{c(0, 0), c(0, 1), c(1, 1)}};
        thrown.confidence = dart.location->views.size() >= 3 ? confidence.three_cameras : confidence.two_cameras;
        // Its point is kept, so the throw message offers the fields it may be in.
        if(fusion::uncertainField(p.x, p.y, c, server_.hello().board_geometry, confidence))
        {
            thrown.accepted = false;
            thrown.confidence = confidence.abstained;
            thrown.reason = "near_wire";
        }
    }
    else
    {
        thrown.confidence = confidence.abstained;
        thrown.reason = dart.reason;
    }
    for(std::size_t c = 0; c < cameras_.size(); ++c)
    {
        const auto& view = dart.cameras[c];
        thrown.cameras.push_back(
            {cameras_[c].id, view.used, view.used ? moment.frames[c] : std::vector<std::uint32_t>{}, view.used ? std::string() : view.state});
    }
    server_.publishThrow(std::move(thrown));
}
}  // namespace dartpilot::cli
