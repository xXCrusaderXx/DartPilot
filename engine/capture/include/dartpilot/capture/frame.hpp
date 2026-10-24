#pragma once

#include <chrono>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace dartpilot::capture
{
// Where Frame::exposure_ns comes from (docs/adr/0005)
enum class TimestampSource
{
    // The camera's UVC PTS, mapped onto CLOCK_MONOTONIC through the SCR samples
    UvcPts,
    // The driver's buffer timestamp, used while no clock mapping is available; it follows the USB delivery
    Driver,
};

// A camera-clock sample with the host time of the same moment, one per frame (docs/adr/0005)
struct ClockSample
{
    std::uint32_t camera_ticks = 0;
    std::int64_t host_ns = 0;
};

struct Frame
{
    // V4L2 sequence number; a gap means the driver lost frames
    std::uint32_t sequence = 0;
    // Best estimate of the start of exposure on CLOCK_MONOTONIC
    std::int64_t exposure_ns = 0;
    TimestampSource timestamp_source = TimestampSource::Driver;
    // Driver buffer timestamp on CLOCK_MONOTONIC
    std::int64_t driver_ns = 0;
    // CLOCK_MONOTONIC right after the frame was dequeued
    std::int64_t arrival_ns = 0;
    // Raw UVC PTS in camera clock ticks, if the camera sent one
    std::optional<std::uint32_t> pts;
    // The frame's sample for the PTS mapping, kept so a recording can refit it (docs/replay-format.md)
    std::optional<ClockSample> clock_sample;
    // Compressed image as delivered by the camera (MJPG)
    std::vector<std::uint8_t> data;
};

// Settings a frame source opens a camera with; the defaults are the reference mode of docs/adr/0002.
struct StreamSettings
{
    int width = 1280;
    int height = 720;
    int fps = 30;
    // Driver buffers; the ring buffer of the capture thread sits behind them
    int buffers = 4;
    // Fixed white balance, 0 for automatic. With the reference LED ring the board is found between 2800 and 3200 K on
    // all three cameras, and the automatic white balance drifts out of that range (measured 2026-10-24, ADR 0002).
    int white_balance_K = 3000;
};

// Produces frames of one camera. Implemented by the V4L2 source and by test doubles.
class FrameSource
{
   public:
    virtual ~FrameSource () = default;
    // Opens the camera and starts streaming; on failure, error() says why.
    virtual bool start () = 0;
    virtual void stop () = 0;
    // Next frame, or nullopt if none arrived within the timeout or the stream failed.
    virtual std::optional<Frame> next (std::chrono::milliseconds timeout) = 0;
    virtual std::string error () const = 0;
};

// CLOCK_MONOTONIC in nanoseconds, the time base of all frame timestamps
std::int64_t monotonicNowNs ();
}  // namespace dartpilot::capture
