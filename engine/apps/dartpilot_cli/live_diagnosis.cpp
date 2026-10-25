#include "live_diagnosis.hpp"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

namespace dartpilot::cli
{
namespace
{
constexpr auto kSampleInterval = std::chrono::milliseconds(100);
// As in the recorded diagnosis: mean brightness change at a quarter of the size; image noise gives about 1.
constexpr double kStillMotion = 2.5;
// Samples every camera must be still before averaging starts (1.5 s, the shortest still period of a recording), and
// samples per average
constexpr int kSettleSamples = 15;
constexpr int kSamplesToAverage = 10;
// A board that stays still is measured again after this long: an empty one, so that drift and light show over time
// without the user doing anything, and one with a dart, in case the moment measured was the hand pulling it.
constexpr auto kRepeat = std::chrono::seconds(20);

double seconds (std::chrono::steady_clock::duration duration) { return std::chrono::duration<double>(duration).count(); }
}  // namespace

LiveDiagnosis::LiveDiagnosis (api::Server& server, const FrameFeed& previews, const std::vector<capture::CameraDevice>& devices,
                              const std::filesystem::path& calibration_directory, std::chrono::steady_clock::time_point started)
    : server_(server)
    , previews_(previews)
    , cameras_started_(started)
    , extrinsics_(geometry::loadExtrinsics((calibration_directory / "extrinsics.yml").string()))
{
    for(const auto& device : devices)
    {
        replay::DiagnosisBuilder::Camera camera{
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
        setup_.push_back(camera);
        cameras_.push_back({});
        cameras_.back().id = camera.id;
    }
    server_.onDiagnosis([this] (bool running) { running ? start() : stop(); });
}

LiveDiagnosis::~LiveDiagnosis ()
{
    server_.onDiagnosis({});
    std::lock_guard lock(control_mutex_);
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
}

void LiveDiagnosis::start ()
{
    std::lock_guard lock(control_mutex_);
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
    builder_ = std::make_unique<replay::DiagnosisBuilder>(setup_, extrinsics_ ? std::optional(extrinsics_->refinement.board) : std::nullopt, true);
    for(std::size_t i = 0; i < cameras_.size(); ++i)
    {
        auto& camera = cameras_[i];
        camera = Camera{};
        camera.id = setup_[i].id;
        camera.at_start = previews_.stats(i);
    }
    diagnosis_started_ = std::chrono::steady_clock::now();
    step_ = "empty_board";
    state_ = "moving";
    publish(true);
    stop_ = false;
    thread_ = std::thread([this] { run(); });
}

void LiveDiagnosis::stop ()
{
    std::lock_guard lock(control_mutex_);
    if(!thread_.joinable())
    {
        return;
    }
    stop_ = true;
    thread_.join();
    publish(false);
}

void LiveDiagnosis::run ()
{
    int still_samples = 0;
    bool measured_since_motion = false;
    bool rejected = false;
    std::chrono::steady_clock::time_point measure_start, last_measured;
    while(!stop_)
    {
        const auto now = std::chrono::steady_clock::now();
        const auto next = now + kSampleInterval;
        bool still = true;
        for(std::size_t i = 0; i < cameras_.size(); ++i)
        {
            sample(cameras_[i], i);
            still = still && cameras_[i].seen && !cameras_[i].moving;
        }
        std::string state;
        bool measured = false;
        if(!still)
        {
            still_samples = 0;
            measured_since_motion = false;
            for(auto& camera : cameras_)
            {
                camera.sum.release();
                camera.summed = 0;
            }
            state = "moving";
        }
        else
        {
            ++still_samples;
            const bool repeat = now - last_measured >= kRepeat;
            if(measured_since_motion && !repeat)
            {
                state = "measured";
            }
            else if(still_samples < kSettleSamples)
            {
                state = "settling";
            }
            else
            {
                state = "measuring";
                bool complete = true;
                for(auto& camera : cameras_)
                {
                    if(camera.fresh && camera.summed < kSamplesToAverage)
                    {
                        if(camera.summed == 0)
                        {
                            camera.sum = cv::Mat::zeros(camera.latest.size(), CV_32FC3);
                            if(&camera == &cameras_.front())
                            {
                                measure_start = now;
                            }
                        }
                        if(camera.latest.size() == camera.sum.size())
                        {
                            cv::accumulate(camera.latest, camera.sum);
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
                        camera.sum.release();
                        camera.summed = 0;
                    }
                    rejected = !builder_->addPeriod(seconds(measure_start - cameras_started_), seconds(now - cameras_started_), means);
                    measured_since_motion = true;
                    last_measured = now;
                    measured = true;
                    state = "measured";
                }
            }
        }
        for(std::size_t i = 0; i < cameras_.size(); ++i)
        {
            const auto stats = previews_.stats(i);
            builder_->setCapture(i, stats.frames - cameras_[i].at_start.frames, stats.lost_frames - cameras_[i].at_start.lost_frames);
        }
        const std::string step = !builder_->hasReference()          ? (rejected ? "remove_darts" : "empty_board")
                                 : builder_->periods().back().empty ? "insert_dart"
                                                                    : "remove_dart";
        if(measured || step != step_ || state != state_)
        {
            step_ = step;
            state_ = state;
            publish(true);
        }
        std::this_thread::sleep_until(next);
    }
}

bool LiveDiagnosis::sample (Camera& camera, std::size_t index)
{
    std::vector<std::uint8_t> jpeg;
    std::uint32_t sequence = 0;
    if(!previews_.latest(index, jpeg, sequence) || (camera.seen && sequence == camera.last_sequence))
    {
        return false;
    }
    const cv::Mat frame = cv::imdecode(jpeg, cv::IMREAD_COLOR);
    if(frame.empty())
    {
        return false;
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
    return true;
}

void LiveDiagnosis::publish (bool running)
{
    auto diagnosis = builder_->diagnosis();
    const double elapsed_s = seconds(std::chrono::steady_clock::now() - diagnosis_started_);
    diagnosis.duration_s = elapsed_s;
    auto message = nlohmann::json::parse(replay::toJson(diagnosis));
    message["type"] = "diagnosis";
    message["running"] = running;
    message["step"] = step_;
    message["state"] = running ? state_ : "stopped";
    message["elapsed_s"] = elapsed_s;
    server_.publishDiagnosis(message);
}
}  // namespace dartpilot::cli
