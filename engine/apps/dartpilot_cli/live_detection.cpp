#include "live_detection.hpp"

#include <chrono>
#include <cstdio>
#include <cstdlib>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/capture/frame.hpp"
#include "dartpilot/geometry/board_state.hpp"

namespace dartpilot::cli
{
namespace
{
constexpr auto kSampleInterval = std::chrono::milliseconds(100);
// As the board check and the diagnosis: mean brightness change at a quarter of the size; image noise gives about 1.
constexpr double kStillMotion = 2.5;
// Samples every camera must be still before averaging starts, and samples averaged
constexpr int kSettleSamples = 15;
constexpr int kSamplesToAverage = 10;
// While it waits for an empty board, a still board is checked again this often: the first check may have come while
// the exposure was still settling after the cameras started.
constexpr auto kRetryWhileWaiting = std::chrono::seconds(3);
// Confidence of a located dart by the number of cameras that agree, and of an abstention (provisional, #48)
constexpr double kConfidenceTwoCameras = 0.8;
constexpr double kConfidenceThreeCameras = 0.95;
constexpr double kConfidenceAbstained = 0.3;
}  // namespace

LiveDetection::LiveDetection (api::Server& server, const CameraPreviews& previews, const std::vector<capture::CameraDevice>& devices,
                              const std::filesystem::path& calibration_directory)
    : server_(server)
    , previews_(previews)
    , extrinsics_(geometry::loadExtrinsics((calibration_directory / "extrinsics.yml").string()))
{
    std::vector<fusion::TrackerCamera> cameras;
    for(const auto& device : devices)
    {
        fusion::TrackerCamera camera{
            "usb-" + device.usb_port, nullptr,
            geometry::loadEmptyReference((calibration_directory / geometry::emptyReferenceFileName(device.usb_port)).string())};
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

void LiveDetection::sample (Camera& camera, std::size_t index)
{
    std::vector<std::uint8_t> jpeg;
    std::uint32_t sequence = 0;
    if(!previews_.latest(index, jpeg, sequence) || (camera.seen && sequence == camera.last_sequence))
    {
        return;
    }
    const cv::Mat frame = cv::imdecode(jpeg, cv::IMREAD_COLOR);
    if(frame.empty())
    {
        return;
    }
    camera.seen = true;
    camera.last_sequence = sequence;
    cv::Mat small;
    cv::resize(frame, small, cv::Size(), 0.25, 0.25, cv::INTER_AREA);
    cv::cvtColor(small, small, cv::COLOR_BGR2GRAY);
    small.convertTo(small, CV_32F);
    camera.moving = camera.previous_small.empty() || camera.previous_small.size() != small.size() ||
                    cv::mean(cv::abs(small - camera.previous_small))[0] > kStillMotion;
    camera.previous_small = small;
    camera.latest = frame;
    camera.fresh = true;
}

void LiveDetection::run ()
{
    int still_samples = 0;
    bool measured_since_motion = false;
    std::int64_t still_since_ns = 0;
    auto last_measured = std::chrono::steady_clock::now();
    while(!stop_)
    {
        const auto next = std::chrono::steady_clock::now() + kSampleInterval;
        bool still = true;
        for(std::size_t i = 0; i < cameras_.size(); ++i)
        {
            sample(cameras_[i], i);
            still = still && cameras_[i].seen && !cameras_[i].moving;
        }
        if(!still || !running_)
        {
            still_samples = 0;
            measured_since_motion = false;
            for(auto& camera : cameras_)
            {
                camera.sum.release();
                camera.summed = 0;
                camera.frames.clear();
            }
        }
        else if((!measured_since_motion || (!tracker_->ready() && std::chrono::steady_clock::now() - last_measured >= kRetryWhileWaiting)) &&
                ++still_samples >= kSettleSamples)
        {
            if(still_samples == kSettleSamples)
            {
                still_since_ns = capture::monotonicNowNs();
            }
            bool complete = true;
            for(auto& camera : cameras_)
            {
                if(camera.fresh && camera.summed < kSamplesToAverage)
                {
                    if(camera.sum.empty())
                    {
                        camera.sum = cv::Mat::zeros(camera.latest.size(), CV_32FC3);
                    }
                    if(camera.latest.size() == camera.sum.size())
                    {
                        cv::accumulate(camera.latest, camera.sum);
                        camera.frames.push_back(camera.last_sequence);
                        ++camera.summed;
                    }
                    camera.fresh = false;
                }
                complete = complete && camera.summed >= kSamplesToAverage;
            }
            if(complete)
            {
                std::vector<cv::Mat> means;
                for(auto& camera : cameras_)
                {
                    means.push_back(camera.sum / camera.summed);
                }
                const auto started = std::chrono::steady_clock::now();
                const auto update = tracker_->addStill(means);
                if(std::getenv("DARTPILOT_TRACE"))
                {
                    std::fprintf(stderr, "still: ready %d darts %d dart %s takeout %d\n", tracker_->ready(), tracker_->dartsInBoard(),
                                 update.dart ? (update.dart->location ? "located" : update.dart->reason.c_str()) : "-", update.takeout.value_or(-1));
                }
                const double latency_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - started).count();
                publish(update, still_since_ns, latency_ms);
                measured_since_motion = true;
                last_measured = std::chrono::steady_clock::now();
                for(auto& camera : cameras_)
                {
                    camera.sum.release();
                    camera.summed = 0;
                    camera.frames.clear();
                }
            }
        }
        std::this_thread::sleep_until(next);
    }
}

void LiveDetection::intercept (std::function<void(const fusion::TrackerUpdate&)> handler)
{
    std::lock_guard lock(intercept_mutex_);
    intercept_ = std::move(handler);
}

void LiveDetection::publish (const fusion::TrackerUpdate& update, std::int64_t event_ns, double latency_ms)
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
        server_.publishTakeout(event_ns, *update.takeout);
    }
    if(!update.dart)
    {
        return;
    }
    const auto& dart = *update.dart;
    api::Throw thrown;
    thrown.event_ns = event_ns;
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
            {cameras_[c].id, view.used, view.used ? cameras_[c].frames : std::vector<std::uint32_t>{}, view.used ? std::string() : view.state});
    }
    server_.publishThrow(std::move(thrown));
}
}  // namespace dartpilot::cli
