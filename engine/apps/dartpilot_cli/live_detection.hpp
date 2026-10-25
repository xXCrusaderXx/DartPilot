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
#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/fusion/detection_params.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "preview_sources.hpp"

// Live darts for `dartpilot serve --cameras`: still moments of all cameras go to the dart tracker, whose darts and
// takeouts become throw and takeout messages.
namespace dartpilot::cli
{
class LiveDetection
{
   public:
    // stored_references: compare the start with the stored images of the empty board; off for a replayed session, whose
    // light and day differ from today's images, so that it learns its empty board from its own first still moment
    LiveDetection (api::Server& server, const FrameFeed& previews, const std::vector<capture::CameraDevice>& devices,
                   const std::filesystem::path& calibration_directory, bool stored_references = true);
    ~LiveDetection ();

    // Whether detection can run: the cameras are calibrated; otherwise why not
    std::optional<std::string> unavailableReason () const;
    void start ();
    void stop ();
    void setRunning (bool running) { running_ = running; }
    // While set, every update of the tracker goes to the handler instead of to the clients, with the mean images it
    // was made from, e.g. for a reference run. Called on the detection thread.
    using Interceptor = std::function<void(const fusion::TrackerUpdate&, const std::vector<cv::Mat>& means)>;
    void intercept (Interceptor handler);
    bool intercepted () const;
    bool ready () const { return ready_; }

    // Every value of the detection (fusion::detectionParams), changeable while running (get_detection_params and
    // set_detection_params): from the next sample on, not kept across restarts. The handler gets every change.
    nlohmann::json paramsMessage () const;
    void onParamsChanged (std::function<void(const nlohmann::json& params)> handler);

   private:
    struct Camera
    {
        std::string id;
        std::uint32_t last_sequence = 0;
        bool seen = false;
    };

    void run ();
    // The camera's latest frame, if it has a new one since the last sample
    std::optional<event_detection::StillSample> sample (Camera& camera, std::size_t index);
    void publish (const fusion::TrackerUpdate& update, const event_detection::StillMoment& moment, double latency_ms, double detection_latency_ms,
                  const fusion::ConfidenceSettings& confidence, int params_revision);

    api::Server& server_;
    const FrameFeed& previews_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<Camera> cameras_;
    std::optional<fusion::DartTracker> tracker_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
    std::atomic<bool> running_{true};
    std::atomic<bool> ready_{false};
    // Unknown names and values out of range are refused as a whole
    std::optional<std::string> setParams (const nlohmann::json& params);
    mutable std::mutex settings_mutex_;
    fusion::DetectionSettings settings_;
    bool settings_changed_ = false;
    // Counts the changes; every throw names the revision it was made with
    int params_revision_ = 0;
    std::function<void(const nlohmann::json&)> params_handler_;
    mutable std::mutex intercept_mutex_;
    Interceptor intercept_;
};
}  // namespace dartpilot::cli
