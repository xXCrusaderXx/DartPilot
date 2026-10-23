#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/charuco.hpp"

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
    // Filled only while a view uses the focus measure
    std::array<double, kFocusCellCount> sharpness{};
    std::array<bool, kFocusCellCount> too_dark{};
    // Filled only while a view uses the ChArUco detection
    std::optional<geometry::CalibrationView> charuco;
    std::string error;
};

// Streams one camera in the reference mode (MJPG 1280x720, 30 fps) on its own thread and keeps only the latest frame.
// A device can be opened only once, so all views of a camera share one stream through acquire().
class CameraStream
{
   public:
    static std::shared_ptr<CameraStream> acquire (const std::string& path);

    explicit CameraStream (std::string path);
    ~CameraStream ();
    CameraStream (const CameraStream&) = delete;
    CameraStream& operator=(const CameraStream&) = delete;

    CameraSnapshot latest () const;
    const geometry::CharucoTarget& charucoTarget () const { return charuco_finder_.target(); }
    // Each view adds itself while it needs an analysis; the analysis runs while the count is positive.
    void addFocusUser (int delta) { focus_users_ += delta; }
    void addCharucoUser (int delta) { charuco_users_ += delta; }

   private:
    void run ();

    std::string path_;
    geometry::CharucoFinder charuco_finder_;
    std::atomic<bool> stop_{false};
    std::atomic<int> focus_users_{0};
    std::atomic<int> charuco_users_{0};
    mutable std::mutex mutex_;
    CameraSnapshot snapshot_;
    std::thread thread_;
};
}  // namespace dartpilot::setup
