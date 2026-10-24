#include "capture_check_command.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/capture/v4l2_frame_source.hpp"
#include "paths.hpp"

namespace dartpilot::cli
{
namespace
{
double percentile (std::vector<double> values, double p)
{
    if(values.empty())
    {
        return 0.0;
    }
    std::sort(values.begin(), values.end());
    return values[static_cast<std::size_t>(p * static_cast<double>(values.size() - 1))];
}

struct CameraRun
{
    capture::CameraDevice device;
    std::unique_ptr<capture::CaptureThread> thread;
    std::vector<double> intervals_ms;
    std::vector<double> latencies_ms;
    std::int64_t last_exposure_ns = 0;
    capture::TimestampSource last_source = capture::TimestampSource::Driver;
};
}  // namespace

int runCaptureCheck (int argc, char* argv[])
{
    const int seconds = argc > 0 ? std::atoi(argv[0]) : 10;
    if(seconds <= 0)
    {
        std::fprintf(stderr, "Usage: dartpilot capture-check [seconds]\n");
        return 2;
    }
    std::vector<CameraRun> runs;
    for(const auto& device : capture::findCameras())
    {
        CameraRun run{device, std::make_unique<capture::CaptureThread>(std::make_unique<capture::V4l2FrameSource>(device, streamSettings(device))),
                      {},     {},
                      0,      {}};
        if(!run.thread->start())
        {
            std::fprintf(stderr, "%s: %s\n", device.usb_port.c_str(), run.thread->stats().error.c_str());
            continue;
        }
        runs.push_back(std::move(run));
    }
    if(runs.empty())
    {
        std::fprintf(stderr, "No camera could be started.\n");
        return 1;
    }

    // The consumer keeps up here, so overflow drops would point at a stalled host.
    const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(seconds);
    while(std::chrono::steady_clock::now() < end)
    {
        for(auto& run : runs)
        {
            while(auto frame = run.thread->frames().tryPop())
            {
                // Intervals only between frames on the same time base; the switch from driver to PTS timestamps is a jump.
                if(run.last_exposure_ns != 0 && frame->timestamp_source == run.last_source)
                {
                    run.intervals_ms.push_back(static_cast<double>(frame->exposure_ns - run.last_exposure_ns) / 1e6);
                }
                run.last_exposure_ns = frame->exposure_ns;
                run.last_source = frame->timestamp_source;
                run.latencies_ms.push_back(static_cast<double>(frame->arrival_ns - frame->exposure_ns) / 1e6);
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }

    int exit_code = 0;
    std::printf("%-12s %7s %6s %6s %6s %8s %10s %10s %11s %11s\n", "camera", "frames", "lost", "drops", "pts%", "fps", "interval", "jitter",
                "latency50", "latency95");
    for(auto& run : runs)
    {
        const capture::CaptureStats stats = run.thread->stats();
        run.thread->stop();
        // Jitter over the second half of the run, after the clock mapping has settled
        run.intervals_ms.erase(run.intervals_ms.begin(), run.intervals_ms.begin() + static_cast<std::ptrdiff_t>(run.intervals_ms.size() / 2));
        double mean = 0;
        for(const double v : run.intervals_ms)
        {
            mean += v;
        }
        mean = run.intervals_ms.empty() ? 0.0 : mean / static_cast<double>(run.intervals_ms.size());
        double variance = 0;
        for(const double v : run.intervals_ms)
        {
            variance += (v - mean) * (v - mean);
        }
        const double jitter = run.intervals_ms.empty() ? 0.0 : std::sqrt(variance / static_cast<double>(run.intervals_ms.size()));
        const double pts_share = stats.frames == 0 ? 0.0 : 100.0 * static_cast<double>(stats.pts_frames) / static_cast<double>(stats.frames);
        std::printf("%-12s %7llu %6llu %6llu %5.0f%% %8.2f %7.3f ms %7.3f ms %8.2f ms %8.2f ms\n", run.device.usb_port.c_str(),
                    static_cast<unsigned long long>(stats.frames), static_cast<unsigned long long>(stats.lost_frames),
                    static_cast<unsigned long long>(stats.overflow_drops), pts_share, stats.effective_fps, mean, jitter,
                    percentile(run.latencies_ms, 0.5), percentile(run.latencies_ms, 0.95));
        if(!stats.error.empty())
        {
            std::fprintf(stderr, "%s: %s\n", run.device.usb_port.c_str(), stats.error.c_str());
            exit_code = 1;
        }
    }
    return exit_code;
}
}  // namespace dartpilot::cli
