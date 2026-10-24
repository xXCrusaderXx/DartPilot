#include "board_watch.hpp"

#include <chrono>
#include <cmath>
#include <cstdio>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

namespace dartpilot::cli
{
namespace
{
// Sampling rate of the check; the board state need not follow faster
constexpr auto kSampleInterval = std::chrono::milliseconds(100);
// As on the validation page: mean brightness change at a quarter of the size; image noise gives about 1.
constexpr double kStillMotion = 2.5;
// Samples without motion before averaging starts, and samples per average (one second each)
constexpr int kStillSamples = 10;
constexpr int kSamplesToAverage = 10;
}  // namespace

BoardWatch::BoardWatch (api::Server& server, const CameraPreviews& previews, std::vector<capture::CameraDevice> devices,
                        std::filesystem::path calibration_directory)
    : server_(server)
    , previews_(previews)
    , calibration_directory_(std::move(calibration_directory))
{
    const auto extrinsics = geometry::loadExtrinsics((calibration_directory_ / "extrinsics.yml").string());
    if(extrinsics)
    {
        board_ = extrinsics->refinement.board;
    }
    for(const auto& device : devices)
    {
        Camera camera;
        camera.usb_port = device.usb_port;
        camera.reference = geometry::loadEmptyReference((calibration_directory_ / geometry::emptyReferenceFileName(device.usb_port)).string());
        if(extrinsics)
        {
            for(const auto& refined : extrinsics->refinement.cameras)
            {
                if(refined.usb_port == device.usb_port)
                {
                    camera.calibration = refined;
                }
            }
        }
        camera.check.reason = "Waiting for a still image.";
        cameras_.push_back(std::move(camera));
    }
}

BoardWatch::~BoardWatch ()
{
    stop();
    server_.onCheckBoard({});
    server_.onStoreEmptyReference({});
}

void BoardWatch::start ()
{
    stop();
    server_.onCheckBoard(
        [this]
        {
            std::lock_guard lock(mutex_);
            server_.setBoardState(info());
        });
    server_.onStoreEmptyReference([this] { return storeReferences(); });
    {
        std::lock_guard lock(mutex_);
        server_.setBoardState(info());
    }
    stop_ = false;
    thread_ = std::thread([this] { run(); });
}

void BoardWatch::stop ()
{
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
}

void BoardWatch::run ()
{
    while(!stop_)
    {
        const auto next = std::chrono::steady_clock::now() + kSampleInterval;
        bool checked = false;
        for(std::size_t i = 0; i < cameras_.size(); ++i)
        {
            std::lock_guard lock(mutex_);
            checked = sample(cameras_[i], i) || checked;
        }
        if(checked)
        {
            std::lock_guard lock(mutex_);
            server_.setBoardState(info());
        }
        std::this_thread::sleep_until(next);
    }
}

bool BoardWatch::sample (Camera& camera, std::size_t index)
{
    std::vector<std::uint8_t> jpeg;
    std::uint32_t sequence = 0;
    if(!previews_.latest(index, jpeg, sequence) || (camera.seen && sequence == camera.last_sequence))
    {
        return false;
    }
    camera.seen = true;
    camera.last_sequence = sequence;
    const cv::Mat frame = cv::imdecode(jpeg, cv::IMREAD_COLOR);
    if(frame.empty())
    {
        return false;
    }
    cv::Mat small;
    cv::resize(frame, small, cv::Size(), 0.25, 0.25, cv::INTER_AREA);
    cv::cvtColor(small, small, cv::COLOR_BGR2GRAY);
    small.convertTo(small, CV_32F);
    const bool moving = camera.previous_small.empty() || camera.previous_small.size() != small.size() ||
                        cv::mean(cv::abs(small - camera.previous_small))[0] > kStillMotion;
    camera.previous_small = small;
    if(moving)
    {
        // A hand or a dart in flight: keep the last decision until the image is still again.
        camera.still_samples = 0;
        camera.sum.release();
        camera.summed = 0;
        return false;
    }
    if(camera.still_samples < kStillSamples)
    {
        ++camera.still_samples;
        return false;
    }
    if(camera.sum.empty())
    {
        camera.sum = cv::Mat::zeros(frame.size(), CV_32FC3);
    }
    cv::accumulate(frame, camera.sum);
    if(++camera.summed < kSamplesToAverage)
    {
        return false;
    }
    camera.mean = camera.sum / camera.summed;
    camera.sum.release();
    camera.summed = 0;
    camera.check = geometry::checkBoard(camera.mean, camera.reference.empty() ? nullptr : &camera.reference,
                                        camera.calibration ? &*camera.calibration : nullptr, board_);
    return true;
}

api::BoardStateInfo BoardWatch::info () const
{
    api::BoardStateInfo board;
    board.reference_stored = !cameras_.empty();
    for(const auto& camera : cameras_)
    {
        api::CameraBoardState state;
        state.camera = "usb-" + camera.usb_port;
        state.state = std::string(geometry::toString(camera.check.state));
        state.reason = camera.check.reason;
        if(camera.check.image_point_px)
        {
            // Whole pixels, so a still object does not send a new state with every average
            state.image_point_px = std::array<double, 2>{std::round(camera.check.image_point_px->x), std::round(camera.check.image_point_px->y)};
        }
        if(!camera.mean.empty())
        {
            state.image_size_px = {camera.mean.cols, camera.mean.rows};
        }
        board.cameras.push_back(state);
        board.reference_stored = board.reference_stored && !camera.reference.empty();
    }
    board.state = api::combineBoardState(board.cameras);
    return board;
}

std::optional<std::string> BoardWatch::storeReferences ()
{
    std::lock_guard lock(mutex_);
    for(const auto& camera : cameras_)
    {
        if(camera.check.state == geometry::BoardState::Occupied)
        {
            return "board_not_empty";
        }
        if(camera.mean.empty())
        {
            return "not_still";
        }
    }
    std::error_code error;
    std::filesystem::create_directories(calibration_directory_, error);
    for(auto& camera : cameras_)
    {
        const auto path = calibration_directory_ / geometry::emptyReferenceFileName(camera.usb_port);
        if(!geometry::saveEmptyReference(path.string(), camera.mean))
        {
            std::fprintf(stderr, "Cannot write %s\n", path.c_str());
            return "save_failed";
        }
        camera.reference = geometry::loadEmptyReference(path.string());
        camera.check = geometry::checkBoard(camera.mean, &camera.reference, camera.calibration ? &*camera.calibration : nullptr, board_);
    }
    server_.setBoardState(info());
    return std::nullopt;
}
}  // namespace dartpilot::cli
