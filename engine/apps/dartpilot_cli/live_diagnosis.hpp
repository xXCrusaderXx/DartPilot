#pragma once

#include <atomic>
#include <chrono>
#include <filesystem>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/api/server.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/replay/diagnosis.hpp"
#include "preview_sources.hpp"

// The setup diagnosis (#137) live on the cameras of `dartpilot serve --cameras`, as a tool of the app: the user follows
// the steps the engine sends (empty board, a dart, pull it, ...), and the findings update with every still moment.
namespace dartpilot::cli
{
class LiveDiagnosis
{
   public:
    // started: when the cameras started, for the exposure check
    LiveDiagnosis (api::Server& server, const CameraPreviews& previews, const std::vector<capture::CameraDevice>& devices,
                   const std::filesystem::path& calibration_directory, std::chrono::steady_clock::time_point started);
    ~LiveDiagnosis ();

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
        capture::CaptureStats at_start;
    };

    void start ();
    void stop ();
    void run ();
    // Takes the newest frame of the camera; false if there is none since the last call
    bool sample (Camera& camera, std::size_t index);
    void publish (bool running);

    api::Server& server_;
    const CameraPreviews& previews_;
    std::chrono::steady_clock::time_point cameras_started_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<replay::DiagnosisBuilder::Camera> setup_;
    std::vector<Camera> cameras_;

    // Owned by the diagnosis thread while it runs
    std::unique_ptr<replay::DiagnosisBuilder> builder_;
    std::chrono::steady_clock::time_point diagnosis_started_;
    std::string step_;
    std::string state_;

    std::mutex control_mutex_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
};
}  // namespace dartpilot::cli
