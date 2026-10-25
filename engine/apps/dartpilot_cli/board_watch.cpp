#include "board_watch.hpp"

#include <chrono>
#include <cmath>
#include <cstdio>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

namespace dartpilot::cli
{
namespace
{
// Sampling rate of the check; the board state need not follow faster
constexpr auto kSampleInterval = std::chrono::milliseconds(100);
// Samples without motion before averaging starts, and samples per average (one second each)
constexpr int kStillSamples = 10;
constexpr int kSamplesToAverage = 10;
// How long an object must stay before it is reported; a knocked camera sways for about three seconds
constexpr auto kOccupiedConfirm = std::chrono::seconds(4);
}  // namespace

BoardWatch::BoardWatch (api::Server& server, const FrameFeed& previews, std::vector<capture::CameraDevice> devices,
                        std::filesystem::path calibration_directory, bool stored_references)
    : server_(server)
    , previews_(previews)
    , calibration_directory_(std::move(calibration_directory))
    , stored_references_(stored_references)
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
        if(stored_references)
        {
            camera.reference = geometry::loadEmptyReference((calibration_directory_ / geometry::emptyReferenceFileName(device.usb_port)).string());
        }
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
        camera.reported = camera.check;
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
    server_.onStoreEmptyReference([this] (bool force) { return storeReferences(force); });
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
    const bool moving = event_detection::moved(camera.previous_small, small);
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
    const cv::Mat previous = camera.mean;
    camera.mean = camera.sum / camera.summed;
    camera.sum.release();
    camera.summed = 0;
    // A knocked camera that sways changes its whole view for a moment; that is no object in the board. The state stays
    // until a still view without such a change; the calibration check tells whether the camera moved for good.
    if(!previous.empty() && tip_candidates::viewChange(previous, camera.mean))
    {
        return false;
    }
    camera.check = geometry::checkBoard(camera.mean, camera.reference.empty() ? nullptr : &camera.reference,
                                        camera.calibration ? &*camera.calibration : nullptr, board_);
    if(camera.check.state != geometry::BoardState::Occupied || camera.reported.state == geometry::BoardState::Occupied)
    {
        camera.occupied_since.reset();
        camera.reported = camera.check;
        return true;
    }
    const auto now = std::chrono::steady_clock::now();
    if(!camera.occupied_since)
    {
        camera.occupied_since = now;
    }
    if(now - *camera.occupied_since >= kOccupiedConfirm)
    {
        camera.reported = camera.check;
    }
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
        state.state = std::string(geometry::toString(camera.reported.state));
        state.reason = camera.reported.reason;
        if(camera.reported.image_point_px)
        {
            // Whole pixels, so a still object does not send a new state with every average
            state.image_point_px =
                std::array<double, 2>{std::round(camera.reported.image_point_px->x), std::round(camera.reported.image_point_px->y)};
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

std::optional<std::string> BoardWatch::storeReferences (bool force)
{
    if(!stored_references_)
    {
        return "not_available";
    }
    std::lock_guard lock(mutex_);
    for(const auto& camera : cameras_)
    {
        if(camera.check.state == geometry::BoardState::Occupied && !force)
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
        camera.reported = camera.check;
        camera.occupied_since.reset();
    }
    server_.setBoardState(info());
    return std::nullopt;
}
}  // namespace dartpilot::cli
