#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <optional>

namespace dartpilot::capture
{
// Maps a camera's 32-bit clock (UVC STC, wraps around) onto the host's CLOCK_MONOTONIC with a least-squares line
// over a sliding window of samples, so the drift between the two clocks is followed (docs/adr/0005).
class ClockMapper
{
   public:
    // Defaults for one sample per frame at 30 fps: a 30 s window, and no mapping before 1 s of samples, because
    // early fits move the mapped times by up to a tenth of a millisecond.
    explicit ClockMapper (std::size_t window = 900, std::size_t min_samples = 30);

    // Adds a sample: a camera clock value and the host time of the same moment.
    void addSample (std::uint32_t camera_ticks, std::int64_t host_ns);

    // Host time of a camera clock value near the latest samples, or nullopt while there are too few samples.
    std::optional<std::int64_t> toHost (std::uint32_t camera_ticks) const;

    // Fitted camera clock rate in Hz, or 0 without a fit.
    double clockHz () const;

    std::size_t sampleCount () const { return samples_.size(); }

   private:
    struct Sample
    {
        std::int64_t ticks;
        std::int64_t host_ns;
    };
    struct Line
    {
        double ns_per_tick = 0.0;
        std::int64_t ticks_origin = 0;
        double host_origin_ns = 0.0;
    };

    // Continues the latest unwrapped tick count with a 32-bit value, assuming less than half a wrap in between.
    std::int64_t unwrap (std::uint32_t camera_ticks) const;
    const std::optional<Line>& line () const;

    std::size_t window_;
    std::size_t min_samples_;
    std::deque<Sample> samples_;
    mutable std::optional<Line> line_;
    mutable bool line_valid_ = false;
};
}  // namespace dartpilot::capture
