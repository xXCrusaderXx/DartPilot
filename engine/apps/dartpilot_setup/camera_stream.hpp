#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>

#include <opencv2/core.hpp>

namespace dartpilot::setup
{
constexpr int kFocusGridSize = 3;
constexpr int kFocusCellCount = kFocusGridSize * kFocusGridSize;

// Latest state of one camera, copied out of the capture thread.
struct CameraSnapshot
{
    cv::Mat frame;
    // Counts delivered frames; 0 until the first one
    std::uint64_t frame_count = 0;
    double fps = 0.0;
    // Filled only while the focus measure is enabled
    std::array<double, kFocusCellCount> sharpness{};
    std::array<bool, kFocusCellCount> too_dark{};
    std::string error;
};

// Streams one camera in the reference mode (MJPG 1280x720, 30 fps) on its own thread and keeps only the latest frame.
class CameraStream
{
   public:
    explicit CameraStream (std::string path);
    ~CameraStream ();
    CameraStream (const CameraStream&) = delete;
    CameraStream& operator=(const CameraStream&) = delete;

    CameraSnapshot latest () const;
    void setFocusEnabled (bool enabled) { focus_enabled_ = enabled; }

   private:
    void run ();

    std::string path_;
    std::atomic<bool> stop_{false};
    std::atomic<bool> focus_enabled_{false};
    mutable std::mutex mutex_;
    CameraSnapshot snapshot_;
    std::thread thread_;
};
}  // namespace dartpilot::setup
