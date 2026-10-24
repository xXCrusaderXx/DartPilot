#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#include "dartpilot/capture/frame.hpp"
#include "dartpilot/capture/ring_buffer.hpp"

namespace dartpilot::capture
{
struct CaptureStats
{
    std::uint64_t frames = 0;
    // Frames the driver lost, from gaps in the sequence numbers
    std::uint64_t lost_frames = 0;
    // Frames dropped because the consumer did not keep up with the ring buffer
    std::uint64_t overflow_drops = 0;
    // Frames whose exposure time comes from the camera's UVC PTS
    std::uint64_t pts_frames = 0;
    // From the exposure times of the latest frames
    double effective_fps = 0.0;
    // Arrival minus exposure of the latest frame
    double latency_ms = 0.0;
    std::size_t queued = 0;
    bool running = false;
    std::string error;
};

// Reads one camera on its own thread into a bounded ring buffer (issue #4). The consumer pops frames from frames();
// when it falls behind, the oldest frames are dropped and counted instead of queueing up latency.
class CaptureThread
{
   public:
    CaptureThread (std::unique_ptr<FrameSource> source, std::size_t ring_capacity = 8);
    ~CaptureThread ();
    CaptureThread (const CaptureThread&) = delete;
    CaptureThread& operator=(const CaptureThread&) = delete;

    // Starts the source and the thread; false if the source cannot start (see stats().error).
    bool start ();
    void stop ();

    RingBuffer<Frame>& frames () { return frames_; }
    CaptureStats stats () const;

   private:
    void run ();
    void count (const Frame& frame);

    std::unique_ptr<FrameSource> source_;
    RingBuffer<Frame> frames_;
    std::thread thread_;
    std::atomic<bool> stop_requested_{false};

    mutable std::mutex mutex_;
    CaptureStats stats_;
    std::optional<std::uint32_t> last_sequence_;
    // Start and frame count of the current window for the effective frame rate
    std::int64_t rate_window_begin_ns_ = 0;
    std::uint64_t rate_window_frames_ = 0;
};
}  // namespace dartpilot::capture
