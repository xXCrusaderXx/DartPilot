#pragma once

#include <atomic>
#include <chrono>
#include <filesystem>
#include <functional>
#include <mutex>
#include <optional>
#include <thread>
#include <vector>

#include <nlohmann/json.hpp>
#include <opencv2/core.hpp>

#include "dartpilot/api/server.hpp"
#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/geometry/calibration_store.hpp"
#include "preview_sources.hpp"

// The calibration wizard of the app on the cameras of `dartpilot serve --cameras` (docs/engine-api.md, "Calibration"):
// white balance, board measurement with the sector 20 picked by the user, the joint refinement, and the status of all.
namespace dartpilot::cli
{
class CalibrationService
{
   public:
    // started: when the cameras started, so the white balance tuning waits for their exposure to settle
    CalibrationService (api::Server& server, const CameraPreviews& previews, std::vector<capture::CameraDevice> devices,
                        std::filesystem::path calibration_directory, std::chrono::steady_clock::time_point started);
    ~CalibrationService ();

   private:
    std::optional<api::Server::CalibrationError> handle (const api::CalibrationRequest& request);
    std::optional<std::size_t> cameraIndex (const nlohmann::json& body) const;
    // Runs a long job on the worker thread; false if one is running. The job returns its last event, which is sent once
    // the next job may start, so a client can go on as soon as it has it.
    bool startJob (std::function<nlohmann::json()> job);

    nlohmann::json detectBoard (std::size_t camera);
    std::optional<api::Server::CalibrationError> setSectorTwenty (std::size_t camera, const cv::Point2f& point_px);
    nlohmann::json refine ();
    nlohmann::json tuneWhiteBalance ();
    nlohmann::json boardImage (int size_px, double radius_mm);

    // Mean of `count` new frames of a camera; empty if stopped or the camera delivers none
    cv::Mat averageFrames (std::size_t camera, int count);
    void waitInterruptibly (std::chrono::steady_clock::duration duration);
    std::vector<geometry::SetupCamera> setupCameras () const;
    // Calibration monitoring: every camera's board against its calibration, often while a client subscribed to the
    // details, else now and then while the board is empty, for calibration_status
    struct CameraCheck
    {
        std::string state;
        std::optional<double> mm;
        std::string checked_at;
    };
    void runChecks ();
    nlohmann::json checkCamera (std::size_t camera, const geometry::StoredExtrinsics* extrinsics, CameraCheck& summary);

    nlohmann::json status () const;
    void publishStatus ();

    api::Server& server_;
    const CameraPreviews& previews_;
    std::vector<capture::CameraDevice> devices_;
    std::filesystem::path directory_;
    std::chrono::steady_clock::time_point cameras_started_;
    geometry::ReferenceMode mode_;

    std::mutex mutex_;
    // The latest detection per camera, which set_sector_20 orients
    std::vector<std::optional<geometry::BoardDetection>> detections_;
    std::thread worker_;
    std::atomic<bool> busy_{false};
    std::atomic<bool> stop_{false};
    std::thread checker_;
    std::atomic<int> subscribers_{0};
    mutable std::mutex checks_mutex_;
    std::vector<CameraCheck> checks_;
};
}  // namespace dartpilot::cli
