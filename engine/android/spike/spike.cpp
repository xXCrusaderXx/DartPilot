#include "spike.hpp"

#include <sys/resource.h>
#include <time.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <memory>
#include <mutex>
#include <thread>

#include <libusb.h>
#include <libuvc/libuvc.h>
// For the PTS and SCR of the payload headers, which libuvc keeps in its stream handle
#include <libuvc/libuvc_internal.h>

namespace dartpilot::android_spike
{
namespace
{
constexpr int kWidth = 1280;
constexpr int kHeight = 720;
constexpr int kFps = 30;

double seconds (const timespec& t) { return static_cast<double>(t.tv_sec) + static_cast<double>(t.tv_nsec) * 1e-9; }

double monotonic ()
{
    timespec t{};
    clock_gettime(CLOCK_MONOTONIC, &t);
    return seconds(t);
}

double cpuSeconds ()
{
    rusage usage{};
    getrusage(RUSAGE_SELF, &usage);
    return static_cast<double>(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) +
           static_cast<double>(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) * 1e-6;
}

struct Camera
{
    int index = 0;
    int fd = -1;
    uvc_device_handle_t* handle = nullptr;
    bool opened = false;
    bool streaming = false;
    std::string error;

    std::mutex mutex;
    int frames = 0;
    double first_s = 0.0, last_s = 0.0;
    std::vector<double> intervals_ms;
    uint32_t last_sequence = 0;
    int sequence_gaps = 0;
    int broken_jpeg = 0;
    double bytes = 0.0;
    int pts_frames = 0;
    int scr_frames = 0;
    // Per frame, to check the device clock against the host clock afterwards
    std::vector<double> host_s;
    std::vector<uint32_t> pts_ticks;
    std::vector<uint32_t> scr_ticks;
    uint32_t clock_frequency_hz = 0;
};

void onFrame (uvc_frame_t* frame, void* user)
{
    auto& camera = *static_cast<Camera*>(user);
    const double now_s = monotonic();
    const auto* data = static_cast<const unsigned char*>(frame->data);
    // A complete JPEG starts with SOI (FFD8) and ends with EOI (FFD9); padding after EOI is allowed.
    bool complete = frame->data_bytes >= 4 && data[0] == 0xFF && data[1] == 0xD8;
    if(complete)
    {
        complete = false;
        for(size_t i = frame->data_bytes; i >= 2 && i + 64 > frame->data_bytes; --i)
        {
            if(data[i - 2] == 0xFF && data[i - 1] == 0xD9)
            {
                complete = true;
                break;
            }
        }
    }
    // The stream handle of this device holds the PTS and SCR of the frame just completed; libuvc does not set
    // frame->source, so it is reached through the camera's own handle.
    uint32_t pts = 0, scr = 0;
    if(camera.handle && camera.handle->streams)
    {
        pts = camera.handle->streams->hold_pts;
        scr = camera.handle->streams->hold_last_scr;
    }
    std::lock_guard lock(camera.mutex);
    if(camera.frames == 0)
    {
        camera.first_s = now_s;
    }
    else
    {
        camera.intervals_ms.push_back((now_s - camera.last_s) * 1000.0);
        if(frame->sequence > camera.last_sequence + 1)
        {
            camera.sequence_gaps += static_cast<int>(frame->sequence - camera.last_sequence - 1);
        }
    }
    camera.last_s = now_s;
    camera.last_sequence = frame->sequence;
    ++camera.frames;
    camera.bytes += static_cast<double>(frame->data_bytes);
    camera.broken_jpeg += complete ? 0 : 1;
    camera.pts_frames += pts != 0 ? 1 : 0;
    camera.scr_frames += scr != 0 ? 1 : 0;
    camera.host_s.push_back(now_s);
    camera.pts_ticks.push_back(pts);
    camera.scr_ticks.push_back(scr);
}

double quantile (std::vector<double> values, double q)
{
    if(values.empty())
    {
        return 0.0;
    }
    std::sort(values.begin(), values.end());
    return values[static_cast<size_t>(q * static_cast<double>(values.size() - 1) + 0.5)];
}

// PTS and SCR are 32-bit counters of the device clock; differences wrap around, so a step back shows as a huge step.
struct ClockCheck
{
    int unchanged = 0;
    int backwards = 0;
    std::vector<double> steps;
    double clock_hz = 0.0;
};

ClockCheck checkClock (const std::vector<uint32_t>& ticks, const std::vector<double>& host_s)
{
    ClockCheck check;
    double sum_ticks = 0.0;
    for(size_t i = 1; i < ticks.size(); ++i)
    {
        const uint32_t step = ticks[i] - ticks[i - 1];
        if(step == 0)
        {
            ++check.unchanged;
        }
        else if(step > 0x80000000u)
        {
            ++check.backwards;
        }
        else
        {
            check.steps.push_back(static_cast<double>(step));
            sum_ticks += static_cast<double>(step);
        }
    }
    const double span_s = host_s.size() > 1 ? host_s.back() - host_s.front() : 0.0;
    check.clock_hz = span_s > 0 ? sum_ticks / span_s : 0.0;
    return check;
}

std::string clockJson (const char* name, const ClockCheck& check)
{
    char text[256];
    std::snprintf(text, sizeof(text),
                  ",\"%s\":{\"unchanged\":%d,\"backwards\":%d,\"step_ticks\":{\"p50\":%.0f,\"p95\":%.0f,\"min\":%.0f},\"clock_hz\":%.0f}", name,
                  check.unchanged, check.backwards, quantile(check.steps, 0.5), quantile(check.steps, 0.95),
                  check.steps.empty() ? 0.0 : *std::min_element(check.steps.begin(), check.steps.end()), check.clock_hz);
    return text;
}

std::string escaped (const std::string& text)
{
    std::string out;
    for(const char c : text)
    {
        if(c == '"' || c == '\\')
        {
            out += '\\';
        }
        out += c;
    }
    return out;
}
}  // namespace

std::string run (const std::vector<int>& fds, int seconds_to_run)
{
    // Without root the app may not scan /dev/bus/usb; it only uses the descriptors it was granted.
    libusb_set_option(nullptr, LIBUSB_OPTION_NO_DEVICE_DISCOVERY, nullptr);
    uvc_context_t* context = nullptr;
    if(const auto error = uvc_init(&context, nullptr); error != UVC_SUCCESS)
    {
        return std::string(R"({"error":")") + uvc_strerror(error) + "\"}";
    }
    std::vector<std::unique_ptr<Camera>> cameras;
    for(size_t i = 0; i < fds.size(); ++i)
    {
        auto camera = std::make_unique<Camera>();
        camera->index = static_cast<int>(i);
        camera->fd = fds[i];
        if(const auto error = uvc_wrap(camera->fd, context, &camera->handle); error != UVC_SUCCESS)
        {
            camera->error = std::string("open: ") + uvc_strerror(error);
        }
        else
        {
            camera->opened = true;
        }
        cameras.push_back(std::move(camera));
    }
    const double cpu_start = cpuSeconds(), wall_start = monotonic();
    for(auto& camera : cameras)
    {
        if(!camera->opened)
        {
            continue;
        }
        uvc_stream_ctrl_t control{};
        if(const auto error = uvc_get_stream_ctrl_format_size(camera->handle, &control, UVC_FRAME_FORMAT_MJPEG, kWidth, kHeight, kFps);
           error != UVC_SUCCESS)
        {
            camera->error = std::string("format: ") + uvc_strerror(error);
            continue;
        }
        if(const auto error = uvc_start_streaming(camera->handle, &control, onFrame, camera.get(), 0); error != UVC_SUCCESS)
        {
            // With several cameras behind one hub this is where the isochronous bandwidth runs out.
            camera->error = std::string("stream: ") + uvc_strerror(error);
            continue;
        }
        camera->streaming = true;
        camera->clock_frequency_hz = control.dwClockFrequency;
    }
    std::this_thread::sleep_for(std::chrono::seconds(seconds_to_run));
    for(auto& camera : cameras)
    {
        if(camera->streaming)
        {
            uvc_stop_streaming(camera->handle);
        }
    }
    const double wall_s = monotonic() - wall_start, cpu_s = cpuSeconds() - cpu_start;

    std::string json = "{\"duration_s\":" + std::to_string(wall_s) + ",\"cpu_percent\":" + std::to_string(100.0 * cpu_s / wall_s) + ",\"cameras\":[";
    for(size_t i = 0; i < cameras.size(); ++i)
    {
        auto& c = *cameras[i];
        std::lock_guard lock(c.mutex);
        const double span_s = c.last_s - c.first_s;
        char text[512];
        std::snprintf(text, sizeof(text),
                      "%s{\"index\":%d,\"opened\":%s,\"streaming\":%s,\"format\":\"MJPEG %dx%d@%d\",\"frames\":%d,\"fps\":%.2f,"
                      "\"interval_ms\":{\"p50\":%.2f,\"p95\":%.2f,\"max\":%.2f},\"sequence_gaps\":%d,\"broken_jpeg\":%d,"
                      "\"bytes_per_frame\":%.0f,\"pts_frames\":%d,\"scr_frames\":%d",
                      i == 0 ? "" : ",", c.index, c.opened ? "true" : "false", c.streaming ? "true" : "false", kWidth, kHeight, kFps, c.frames,
                      span_s > 0 ? (c.frames - 1) / span_s : 0.0, quantile(c.intervals_ms, 0.5), quantile(c.intervals_ms, 0.95),
                      c.intervals_ms.empty() ? 0.0 : *std::max_element(c.intervals_ms.begin(), c.intervals_ms.end()), c.sequence_gaps, c.broken_jpeg,
                      c.frames > 0 ? c.bytes / c.frames : 0.0, c.pts_frames, c.scr_frames);
        json += text;
        json += ",\"clock_frequency_hz\":" + std::to_string(c.clock_frequency_hz);
        json += clockJson("pts", checkClock(c.pts_ticks, c.host_s));
        json += clockJson("scr", checkClock(c.scr_ticks, c.host_s));
        if(!c.error.empty())
        {
            json += ",\"error\":\"" + escaped(c.error) + "\"";
        }
        json += "}";
    }
    json += "]}";
    for(auto& camera : cameras)
    {
        if(camera->opened)
        {
            uvc_close(camera->handle);
        }
    }
    uvc_exit(context);
    return json;
}
}  // namespace dartpilot::android_spike
