#pragma once

#include <atomic>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include "dartpilot/api/server.hpp"
#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/session/session_reader.hpp"
#include "dartpilot/session/session_writer.hpp"

// Camera previews for `dartpilot serve`: real cameras, or drawn images of the simulated board.
namespace dartpilot::cli
{
// Scales a JPEG to at most max_width pixels with OpenCV, for the server's per-client preview width
std::vector<std::uint8_t> scaleJpeg (const std::vector<std::uint8_t>& jpeg, int max_width, int& width, int& height);

// The newest frame of each camera, from the real cameras or from a recorded session played back
class FrameFeed
{
   public:
    virtual ~FrameFeed () = default;
    // Newest JPEG of a camera and its frame sequence; false before the first frame
    virtual bool latest (std::size_t camera, std::vector<std::uint8_t>& jpeg, std::uint32_t& sequence) const = 0;
    // Frame counters of a camera since it started
    virtual capture::CaptureStats stats (std::size_t camera) const = 0;
};

// Streams the real cameras: previews to watching clients and camera status every second; records every frame into a
// session when asked to.
class CameraPreviews : public FrameFeed
{
   public:
    explicit CameraPreviews (api::Server& server);
    ~CameraPreviews () override;

    // Starts every camera found; returns the cameras that started
    std::vector<capture::CameraDevice> start ();
    void stop ();

    // Newest JPEG of a camera (in the order start() returned) and its frame sequence; false before the first frame
    bool latest (std::size_t camera, std::vector<std::uint8_t>& jpeg, std::uint32_t& sequence) const override;
    capture::CaptureStats stats (std::size_t camera) const override;
    // Writes every frame and the capture health into the session from now on, or no more with null
    void record (session::SessionWriter* writer) { writer_ = writer; }

   private:
    void run ();

    api::Server& server_;
    std::vector<capture::CameraDevice> devices_;
    std::vector<std::unique_ptr<capture::CaptureThread>> captures_;
    std::atomic<session::SessionWriter*> writer_{nullptr};
    // Newest JPEG per camera, for the brightness in the status
    std::vector<std::vector<std::uint8_t>> latest_;
    std::vector<std::uint32_t> latest_sequence_;
    mutable std::mutex latest_mutex_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
};

// Plays a recorded session's frames in real time as if they came from its cameras (`serve --replay`, #115): previews,
// detection, board check and diagnosis work on them as on live frames.
class SessionPlayback : public FrameFeed
{
   public:
    SessionPlayback (api::Server& server, session::RecordedSession session);
    ~SessionPlayback () override;

    // The session's cameras as devices, in its order; they have no device path
    std::vector<capture::CameraDevice> devices () const;
    void start ();
    void stop ();
    // All frames played
    bool finished () const { return finished_; }

    bool latest (std::size_t camera, std::vector<std::uint8_t>& jpeg, std::uint32_t& sequence) const override;
    capture::CaptureStats stats (std::size_t camera) const override;

   private:
    void run ();

    api::Server& server_;
    session::RecordedSession session_;
    std::vector<std::vector<std::uint8_t>> latest_;
    std::vector<std::uint32_t> latest_sequence_;
    std::vector<std::uint64_t> played_;
    mutable std::mutex mutex_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
    std::atomic<bool> finished_{false};
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
