#include "dartpilot/capture/clock_mapper.hpp"

#include <cmath>

namespace dartpilot::capture
{
ClockMapper::ClockMapper (std::size_t window, std::size_t min_samples)
    : window_(window)
    , min_samples_(min_samples < 2 ? 2 : min_samples)
{
}

std::int64_t ClockMapper::unwrap (std::uint32_t camera_ticks) const
{
    if(samples_.empty())
    {
        return camera_ticks;
    }
    const std::int64_t latest = samples_.back().ticks;
    const auto step = static_cast<std::int32_t>(camera_ticks - static_cast<std::uint32_t>(latest));
    return latest + step;
}

void ClockMapper::addSample (std::uint32_t camera_ticks, std::int64_t host_ns)
{
    samples_.push_back({unwrap(camera_ticks), host_ns});
    while(samples_.size() > window_)
    {
        samples_.pop_front();
    }
    line_valid_ = false;
}

const std::optional<ClockMapper::Line>& ClockMapper::line () const
{
    if(line_valid_)
    {
        return line_;
    }
    line_valid_ = true;
    line_.reset();
    if(samples_.size() < min_samples_)
    {
        return line_;
    }
    // Relative to the first sample, so the sums stay small enough for double precision.
    const std::int64_t ticks_origin = samples_.front().ticks;
    const std::int64_t host_origin = samples_.front().host_ns;
    double sum_x = 0, sum_y = 0, sum_xx = 0, sum_xy = 0;
    for(const auto& sample : samples_)
    {
        const double x = static_cast<double>(sample.ticks - ticks_origin);
        const double y = static_cast<double>(sample.host_ns - host_origin);
        sum_x += x;
        sum_y += y;
        sum_xx += x * x;
        sum_xy += x * y;
    }
    const double n = static_cast<double>(samples_.size());
    const double denominator = n * sum_xx - sum_x * sum_x;
    if(std::abs(denominator) < 1e-9)
    {
        return line_;
    }
    const double slope = (n * sum_xy - sum_x * sum_y) / denominator;
    if(slope <= 0)
    {
        return line_;
    }
    const double intercept = (sum_y - slope * sum_x) / n;
    line_ = Line{slope, ticks_origin, static_cast<double>(host_origin) + intercept};
    return line_;
}

std::optional<std::int64_t> ClockMapper::toHost (std::uint32_t camera_ticks) const
{
    const auto& fitted = line();
    if(!fitted)
    {
        return std::nullopt;
    }
    const double x = static_cast<double>(unwrap(camera_ticks) - fitted->ticks_origin);
    return static_cast<std::int64_t>(std::llround(fitted->host_origin_ns + fitted->ns_per_tick * x));
}

double ClockMapper::clockHz () const
{
    const auto& fitted = line();
    return fitted ? 1e9 / fitted->ns_per_tick : 0.0;
}
}  // namespace dartpilot::capture
