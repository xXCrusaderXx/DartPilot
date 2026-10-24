#pragma once

#include <atomic>
#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/api/server.hpp"
#include "dartpilot/geometry/board_state.hpp"
#include "preview_sources.hpp"

// Whether darts are in the board, from the real cameras of `dartpilot serve --cameras` (#121).
namespace dartpilot::cli
{
// Averages each camera's frames while its image is still, checks the average against the camera's empty-board
// reference (geometry::checkBoard), and reports the result to the server. Stores new references on request.
class BoardWatch
{
   public:
    BoardWatch (api::Server& server, const CameraPreviews& previews, std::vector<capture::CameraDevice> devices,
                std::filesystem::path calibration_directory);
    ~BoardWatch ();

    void start ();
    void stop ();

   private:
    struct Camera
    {
        std::string usb_port;
        cv::Mat reference;
        std::optional<geometry::RefinedCamera> calibration;
        std::uint32_t last_sequence = 0;
        bool seen = false;
        cv::Mat previous_small;
        int still_samples = 0;
        cv::Mat sum;
        int summed = 0;
        // Latest still average and its check; empty until the image was still once
        cv::Mat mean;
        geometry::BoardCheck check;
    };

    void run ();
    // Takes a sample of the camera; true when a new average was checked
    bool sample (Camera& camera, std::size_t index);
    api::BoardStateInfo info () const;
    std::optional<std::string> storeReferences (bool force);

    api::Server& server_;
    const CameraPreviews& previews_;
    std::filesystem::path calibration_directory_;
    geometry::BoardModel board_;
    std::vector<Camera> cameras_;
    mutable std::mutex mutex_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
};
}  // namespace dartpilot::cli
