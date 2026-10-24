#pragma once

#include <atomic>
#include <chrono>
#include <functional>
#include <string>
#include <utility>
#include <vector>

#include <opencv2/core.hpp>

// The white balance tuning of the setup (ADR 0002), shared by `dartpilot white-balance` and the engine API.
namespace dartpilot::cli
{
// A new white balance shows after about half a second.
inline constexpr auto kWhiteBalanceSettle = std::chrono::milliseconds(1500);
// Frames averaged per temperature, so that image noise does not decide whether the board is found
inline constexpr int kWhiteBalanceFrames = 10;

struct SweepCamera
{
    std::string device_path;
    // Whether the board was found at each temperature tried, in rising order
    std::vector<std::pair<int, bool>> found_at_K;
};

// Sets each temperature from kMinWhiteBalance_K to kMaxWhiteBalance_K on all cameras at once, waits for it with wait(),
// and looks for the board in the mean of `kWhiteBalanceFrames` frames from grab(camera). progress() is called after
// each temperature. False if stopped.
bool sweepWhiteBalance (std::vector<SweepCamera>& cameras, const std::function<void(std::chrono::steady_clock::duration)>& wait,
                        const std::function<cv::Mat(std::size_t camera)>& grab, const std::function<void(int kelvin)>& progress,
                        const std::atomic<bool>& stop);
}  // namespace dartpilot::cli
