#pragma once

#include <atomic>
#include <memory>
#include <thread>
#include <vector>

#include "dartpilot/api/server.hpp"
#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/v4l2_device.hpp"

// Camera previews for `dartpilot serve`: real cameras, or drawn images of the simulated board.
namespace dartpilot::cli
{
// Scales a JPEG to at most max_width pixels with OpenCV, for the server's per-client preview width
std::vector<std::uint8_t> scaleJpeg (const std::vector<std::uint8_t>& jpeg, int max_width, int& width, int& height);

// Streams the real cameras: previews to watching clients and camera status every second.
class CameraPreviews
{
   public:
    explicit CameraPreviews (api::Server& server);
    ~CameraPreviews ();

    // Starts every camera found; returns the cameras that started
    std::vector<capture::CameraDevice> start ();
    void stop ();

   private:
    void run ();

    api::Server& server_;
    std::vector<capture::CameraDevice> devices_;
    std::vector<std::unique_ptr<capture::CaptureThread>> captures_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
};

// Draws a simple view of the board with the darts of the current visit for each simulated camera.
class SimulatedPreviews
{
   public:
    SimulatedPreviews (api::Server& server, std::vector<std::string> cameras);
    ~SimulatedPreviews ();

    void start ();
    void stop ();

   private:
    void run ();

    api::Server& server_;
    std::vector<std::string> cameras_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
};
}  // namespace dartpilot::cli
