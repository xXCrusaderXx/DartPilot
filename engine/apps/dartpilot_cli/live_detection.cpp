#include "live_detection.hpp"

#include <chrono>
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
}

LiveDetection::~LiveDetection () { stop(); }

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
    event_detection::StillDetector still(cameras_.size(), event_detection::StillSettings{});
    const auto interval = std::chrono::nanoseconds(still.settings().sample_interval_ns);
    while(!stop_)
    {
        const auto next = std::chrono::steady_clock::now() + interval;
        std::vector<std::optional<event_detection::StillSample>> samples;
        for(std::size_t i = 0; i < cameras_.size(); ++i)
        {
            samples.push_back(sample(cameras_[i], i));
        }
        if(!running_)
        {
            // Paused: a person may move in front of the board, so the next still moment is measured afresh.
            samples.assign(cameras_.size(), std::nullopt);
            still = event_detection::StillDetector(cameras_.size(), still.settings());
        }
        else if(const auto moment = still.addSample(capture::monotonicNowNs(), samples, !tracker_->ready()))
        {
            const auto started = std::chrono::steady_clock::now();
            const auto update = tracker_->addStill(moment->means);
            if(std::getenv("DARTPILOT_TRACE"))
            {
                std::fprintf(stderr, "still: ready %d darts %d dart %s takeout %d\n", tracker_->ready(), tracker_->dartsInBoard(),
                             update.dart ? (update.dart->location ? "located" : update.dart->reason.c_str()) : "-", update.takeout.value_or(-1));
            }
            const double latency_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count();
            publish(update, *moment, latency_ms);
        }
        std::this_thread::sleep_until(next);
    }
}

void LiveDetection::intercept (std::function<void(const fusion::TrackerUpdate&)> handler)
{
    std::lock_guard lock(intercept_mutex_);
    intercept_ = std::move(handler);
}

void LiveDetection::publish (const fusion::TrackerUpdate& update, const event_detection::StillMoment& moment, double latency_ms)
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
        server_.publishTakeout(moment.start_ns, *update.takeout);
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
