#pragma once

#include <atomic>
#include <filesystem>
#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/api/server.hpp"
#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "preview_sources.hpp"

// Live darts for `dartpilot serve --cameras`: still moments of all cameras go to the dart tracker, whose darts and
// takeouts become throw and takeout messages.
namespace dartpilot::cli
{
class LiveDetection
{
   public:
    LiveDetection (api::Server& server, const CameraPreviews& previews, const std::vector<capture::CameraDevice>& devices,
                   const std::filesystem::path& calibration_directory);
    ~LiveDetection ();

    // Whether detection can run: the cameras are calibrated; otherwise why not
    std::optional<std::string> unavailableReason () const;
    void start ();
    void stop ();
    void setRunning (bool running) { running_ = running; }
    // While set, every update of the tracker goes to the handler instead of to the clients, e.g. for a reference run.
    // Called on the detection thread.
    void intercept (std::function<void(const fusion::TrackerUpdate&)> handler);
    bool ready () const { return ready_; }

   private:
    struct Camera
    {
        std::string id;
        std::uint32_t last_sequence = 0;
        bool seen = false;
        bool moving = true;
        cv::Mat previous_small;
        cv::Mat latest;
        bool fresh = false;
        cv::Mat sum;
        int summed = 0;
        std::vector<std::uint32_t> frames;
    };

    void run ();
    void sample (Camera& camera, std::size_t index);
    void publish (const fusion::TrackerUpdate& update, std::int64_t event_ns, double latency_ms);

    api::Server& server_;
    const CameraPreviews& previews_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<Camera> cameras_;
    std::optional<fusion::DartTracker> tracker_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
    std::atomic<bool> running_{true};
    std::atomic<bool> ready_{false};
    std::mutex intercept_mutex_;
    std::function<void(const fusion::TrackerUpdate&)> intercept_;
};
}  // namespace dartpilot::cli
