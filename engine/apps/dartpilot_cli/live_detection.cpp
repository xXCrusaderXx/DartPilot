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
#include "dartpilot/geometry/board_state.hpp"

namespace dartpilot::cli
{
namespace
{
// Confidence of a located dart by the number of cameras that agree, and of an abstention (provisional, #48)
constexpr double kConfidenceTwoCameras = 0.8;
constexpr double kConfidenceThreeCameras = 0.95;
constexpr double kConfidenceAbstained = 0.3;

// A value of event_detection::StillSettings as the app's slider shows it
struct Param
{
    const char* name;
    const char* unit;
    double min;
    double max;
    double step;
    double (*get)(const event_detection::StillSettings&);
    void (*set)(event_detection::StillSettings&, double);
};
const Param kParams[] = {
    {"sample_ms", "ms", 10, 200, 1, [] (const auto& s) { return s.sample_interval_ns / 1e6; },
     [] (auto& s, double v) { s.sample_interval_ns = static_cast<std::int64_t>(v * 1e6); }},
    {"settle_samples", "", 1, 30, 1, [] (const auto& s) { return double(s.settle_samples); }, [] (auto& s, double v) { s.settle_samples = int(v); }},
    {"average_frames", "", 1, 20, 1, [] (const auto& s) { return double(s.frames_to_average); },
     [] (auto& s, double v) { s.frames_to_average = int(v); }},
    {"motion_span_ms", "ms", 0, 500, 10, [] (const auto& s) { return s.motion_span_ns / 1e6; },
     [] (auto& s, double v) { s.motion_span_ns = static_cast<std::int64_t>(v * 1e6); }},
    {"still_motion", "grey", 0.5, 10, 0.1, [] (const auto& s) { return s.still_motion; }, [] (auto& s, double v) { s.still_motion = v; }},
    {"local_change", "grey", 5, 100, 1, [] (const auto& s) { return s.local_change; }, [] (auto& s, double v) { s.local_change = v; }},
    {"local_change_px", "px", 1, 500, 1, [] (const auto& s) { return double(s.local_change_px); },
     [] (auto& s, double v) { s.local_change_px = int(v); }},
};
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
        tracker_.emplace(cameras, extrinsics_->refinement.board);
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
    nlohmann::json params = nlohmann::json::object(), ranges = nlohmann::json::object();
    std::lock_guard lock(settings_mutex_);
    for(const auto& param : kParams)
    {
        params[param.name] = param.get(settings_);
        ranges[param.name] = {{"min", param.min}, {"max", param.max}, {"step", param.step}, {"unit", param.unit}};
    }
    return {{"type", "detection_params"}, {"params", params}, {"ranges", ranges}};
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
            const auto* param = std::find_if(std::begin(kParams), std::end(kParams), [&] (const Param& p) { return name == p.name; });
            if(param == std::end(kParams))
            {
                return "Unknown detection value " + name;
            }
            if(!value.is_number() || value.get<double>() < param->min || value.get<double>() > param->max)
            {
                return name + " must be a number from " + std::to_string(param->min) + " to " + std::to_string(param->max);
            }
            // Sliders send whole steps as doubles, e.g. 6.0
            param->set(settings, param->step >= 1.0 ? std::round(value.get<double>()) : value.get<double>());
        }
        settings_ = settings;
        settings_changed_ = true;
        handler = params_handler_;
    }
    const auto message = paramsMessage();
    server_.publishState(message);
    if(handler)
    {
        handler(message["params"]);
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
    while(!stop_)
    {
        {
            std::lock_guard lock(settings_mutex_);
            if(!still || settings_changed_)
            {
                still.emplace(cameras_.size(), settings_);
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
            publish(update, *moment, latency_ms, (capture::monotonicNowNs() - moment->last_motion_ns) / 1e6);
        }
        std::this_thread::sleep_until(next);
    }
}

void LiveDetection::intercept (std::function<void(const fusion::TrackerUpdate&)> handler)
{
    std::lock_guard lock(intercept_mutex_);
    intercept_ = std::move(handler);
}

void LiveDetection::publish (const fusion::TrackerUpdate& update, const event_detection::StillMoment& moment, double latency_ms,
                             double detection_latency_ms)
{
    ready_ = tracker_ && tracker_->ready();
    std::function<void(const fusion::TrackerUpdate&)> intercept;
    {
        std::lock_guard lock(intercept_mutex_);
        intercept = intercept_;
    }
    if(intercept)
    {
        intercept(update);
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
    if(dart.location)
    {
        const auto& p = dart.location->board_mm;
        const auto& c = dart.location->covariance_mm2;
        thrown.board_point = api::BoardPoint{p.x, p.y, std::array<double, 3>{c(0, 0), c(0, 1), c(1, 1)}};
        thrown.confidence = dart.location->views.size() >= 3 ? kConfidenceThreeCameras : kConfidenceTwoCameras;
    }
    else
    {
        thrown.confidence = kConfidenceAbstained;
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
