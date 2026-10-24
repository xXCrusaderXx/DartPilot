#include "white_balance_command.hpp"

#include <linux/videodev2.h>

#include <chrono>
#include <cstdio>
#include <filesystem>
#include <memory>
#include <thread>
#include <vector>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/capture/v4l2_frame_source.hpp"
#include "dartpilot/capture/white_balance.hpp"
#include "dartpilot/geometry/board_detection.hpp"
#include "paths.hpp"

namespace dartpilot::cli
{
namespace
{
// The automatic exposure settles in about 25 s after the cameras start; a new white balance in about half a second.
constexpr auto kExposureSettle = std::chrono::seconds(25);
constexpr auto kWhiteBalanceSettle = std::chrono::milliseconds(1500);
// Frames averaged per temperature, so that image noise does not decide whether the board is found
constexpr int kFramesToAverage = 10;

struct Camera
{
    capture::CameraDevice device;
    std::unique_ptr<capture::CaptureThread> thread;
    std::vector<std::pair<int, bool>> found_at_K;
};

void drain (std::vector<Camera>& cameras, std::chrono::steady_clock::duration duration)
{
    const auto end = std::chrono::steady_clock::now() + duration;
    while(std::chrono::steady_clock::now() < end)
    {
        for(auto& camera : cameras)
        {
            while(camera.thread->frames().tryPop())
            {
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

cv::Mat averaged (Camera& camera)
{
    cv::Mat sum;
    int count = 0;
    while(count < kFramesToAverage)
    {
        auto frame = camera.thread->frames().tryPop();
        if(!frame)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            continue;
        }
        const cv::Mat image = cv::imdecode(frame->data, cv::IMREAD_COLOR);
        if(image.empty())
        {
            continue;
        }
        if(sum.empty())
        {
            sum = cv::Mat::zeros(image.size(), CV_32FC3);
        }
        cv::accumulate(image, sum);
        ++count;
    }
    cv::Mat mean;
    sum.convertTo(mean, CV_8UC3, 1.0 / count);
    return mean;
}
}  // namespace

int runWhiteBalance (int argc, char*[])
{
    if(argc > 0)
    {
        std::fprintf(stderr,
                     "Usage: dartpilot white-balance\n"
                     "  Tries the white balance of every camera from %d to %d K with the board empty and lit as for playing, and\n"
                     "  stores the middle of the range in which the board is found. Takes about a minute; the cameras must be free.\n",
                     capture::kMinWhiteBalance_K, capture::kMaxWhiteBalance_K);
        return 2;
    }
    const auto directory = dataHome() / "calibration";
    std::vector<Camera> cameras;
    for(const auto& device : capture::findCameras())
    {
        Camera camera{device, std::make_unique<capture::CaptureThread>(std::make_unique<capture::V4l2FrameSource>(device)), {}};
        if(!camera.thread->start())
        {
            std::fprintf(stderr, "%s: %s\n", device.usb_port.c_str(), camera.thread->stats().error.c_str());
            continue;
        }
        cameras.push_back(std::move(camera));
    }
    if(cameras.empty())
    {
        std::fprintf(stderr, "No camera could be started.\n");
        return 1;
    }
    std::printf("Waiting %lld s for the exposure to settle ...\n", static_cast<long long>(kExposureSettle.count()));
    std::fflush(stdout);
    drain(cameras, kExposureSettle);

    std::printf("%-8s", "K");
    for(const auto& camera : cameras)
    {
        std::printf(" %12s", camera.device.usb_port.c_str());
    }
    std::printf("\n");
    for(int kelvin = capture::kMinWhiteBalance_K; kelvin <= capture::kMaxWhiteBalance_K; kelvin += capture::kWhiteBalanceStep_K)
    {
        for(const auto& camera : cameras)
        {
            capture::CameraControls(camera.device.path).set(V4L2_CID_WHITE_BALANCE_TEMPERATURE, kelvin);
        }
        drain(cameras, kWhiteBalanceSettle);
        std::printf("%-8d", kelvin);
        for(auto& camera : cameras)
        {
            const bool found = geometry::detectBoard(averaged(camera)).has_value();
            camera.found_at_K.emplace_back(kelvin, found);
            std::printf(" %12s", found ? "board" : "-");
        }
        std::printf("\n");
        std::fflush(stdout);
    }

    int exit_code = 0;
    std::error_code error;
    std::filesystem::create_directories(directory, error);
    for(auto& camera : cameras)
    {
        const auto path = directory / capture::whiteBalanceFileName(camera.device.usb_port);
        const auto chosen = capture::chooseWhiteBalance(camera.found_at_K);
        camera.thread->stop();
        if(!chosen)
        {
            std::printf(
                "%s: the board was found at no white balance. Check the light and that the board is empty and in view; "
                "%d K stays.\n",
                camera.device.usb_port.c_str(), capture::storedWhiteBalance(path.string()));
            exit_code = 1;
            continue;
        }
        capture::CameraControls(camera.device.path).set(V4L2_CID_WHITE_BALANCE_TEMPERATURE, *chosen);
        if(!capture::saveWhiteBalance(path.string(), *chosen, camera.found_at_K))
        {
            std::fprintf(stderr, "Cannot write %s\n", path.c_str());
            exit_code = 1;
            continue;
        }
        std::printf("%s: %d K, stored in %s\n", camera.device.usb_port.c_str(), *chosen, path.c_str());
    }
    return exit_code;
}
}  // namespace dartpilot::cli
