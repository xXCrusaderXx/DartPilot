#include "camera_stream.hpp"

#include <chrono>
#include <deque>
#include <map>

#include <opencv2/imgproc.hpp>
#include <opencv2/videoio.hpp>

#include "dartpilot/capture/focus.hpp"

namespace dartpilot::setup
{
namespace
{
// Below this mean gray value sensor noise dominates the gradient energy and the measure no longer follows the focus.
constexpr double kMinMeanIntensity = 40.0;
}  // namespace

std::shared_ptr<CameraStream> CameraStream::acquire (const std::string& path)
{
    // Views are created and destroyed on the GUI thread only.
    static std::map<std::string, std::weak_ptr<CameraStream>> streams;
    if(auto stream = streams[path].lock())
    {
        return stream;
    }
    auto stream = std::make_shared<CameraStream>(path);
    streams[path] = stream;
    return stream;
}

CameraStream::CameraStream (std::string path)
    : path_(std::move(path))
    , thread_([this] { run(); })
{
}

CameraStream::~CameraStream ()
{
    stop_ = true;
    thread_.join();
}

CameraSnapshot CameraStream::latest () const
{
    std::lock_guard lock(mutex_);
    return snapshot_;
}

void CameraStream::run ()
{
    cv::VideoCapture camera(path_, cv::CAP_V4L2);
    if(!camera.isOpened())
    {
        std::lock_guard lock(mutex_);
        snapshot_.error = "Cannot open " + path_;
        return;
    }
    // Reference mode, see docs/hardware.md. The FOURCC must be set before the size.
    camera.set(cv::CAP_PROP_FOURCC, cv::VideoWriter::fourcc('M', 'J', 'P', 'G'));
    camera.set(cv::CAP_PROP_FRAME_WIDTH, 1280);
    camera.set(cv::CAP_PROP_FRAME_HEIGHT, 720);
    camera.set(cv::CAP_PROP_FPS, 30);

    // Display statistics only; nothing here is part of a recording or replay.
    std::deque<std::chrono::steady_clock::time_point> arrivals;
    cv::Mat frame, gray;
    std::uint64_t frame_count = 0;
    while(!stop_)
    {
        if(!camera.read(frame) || frame.empty())
        {
            std::lock_guard lock(mutex_);
            snapshot_.error = "No frame from " + path_;
            return;
        }
        ++frame_count;
        const auto now = std::chrono::steady_clock::now();
        arrivals.push_back(now);
        while(now - arrivals.front() > std::chrono::seconds(1))
        {
            arrivals.pop_front();
        }
        const double span_s = std::chrono::duration<double>(arrivals.back() - arrivals.front()).count();
        const double fps = arrivals.size() > 1 && span_s > 0.0 ? (arrivals.size() - 1) / span_s : 0.0;

        std::array<double, kFocusCellCount> sharpness{};
        std::array<bool, kFocusCellCount> too_dark{};
        std::optional<geometry::CalibrationView> charuco;
        if(focus_users_ > 0 || charuco_users_ > 0)
        {
            cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
        }
        if(charuco_users_ > 0)
        {
            charuco = charuco_finder_.detect(gray);
        }
        if(focus_users_ > 0)
        {
            for(int cell = 0; cell < kFocusCellCount; ++cell)
            {
                const cv::Mat region = gray(capture::gridCell(gray.size(), kFocusGridSize, cell));
                too_dark[cell] = cv::mean(region)[0] < kMinMeanIntensity;
                sharpness[cell] = too_dark[cell] ? 0.0 : capture::sharpness(region);
            }
        }

        // A new buffer per frame: readers share the previous one, and VideoCapture reuses its own.
        cv::Mat copy = frame.clone();
        std::lock_guard lock(mutex_);
        snapshot_.frame = std::move(copy);
        snapshot_.frame_count = frame_count;
        snapshot_.fps = fps;
        snapshot_.sharpness = sharpness;
        snapshot_.too_dark = too_dark;
        snapshot_.charuco = std::move(charuco);
    }
}
}  // namespace dartpilot::setup
