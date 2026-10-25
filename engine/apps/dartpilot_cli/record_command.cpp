#include "record_command.hpp"

#include <linux/videodev2.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>

#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/capture/v4l2_frame_source.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/intrinsics.hpp"
#include "dartpilot/session/session_writer.hpp"
#include "dartpilot/session/sha256.hpp"
#include "paths.hpp"

namespace dartpilot::cli
{
namespace
{
// Frames the writer may fall behind before capture drops the oldest: 3 s at 30 fps
constexpr std::size_t kRecordingRingCapacity = 90;
constexpr std::chrono::milliseconds kHealthInterval{1000};

std::atomic<bool> interrupted{false};

void onInterrupt (int) { interrupted = true; }

// Mean brightness of a JPEG at an eighth of its size, enough for the exposure trend of ADR 0002
double meanBrightness (const std::vector<std::uint8_t>& jpeg)
{
    const cv::Mat gray = cv::imdecode(jpeg, cv::IMREAD_REDUCED_GRAYSCALE_8);
    return gray.empty() ? -1.0 : cv::mean(gray)[0];
}

std::optional<session::FileReference> intrinsicsReference (const capture::CameraDevice& device, const capture::StreamSettings& stream)
{
    const std::filesystem::path path = dataHome() / "calibration" / ("intrinsics-usb-" + device.usb_port + ".yml");
    if(!std::filesystem::exists(path))
    {
        std::fprintf(stderr, "%s: no intrinsic calibration at %s\n", device.usb_port.c_str(), path.c_str());
        return std::nullopt;
    }
    const auto stored = geometry::loadIntrinsics(path.string());
    if(!stored)
    {
        std::fprintf(stderr, "%s: cannot read %s\n", device.usb_port.c_str(), path.c_str());
        return std::nullopt;
    }
    const std::string pixel_format =
        "MJPG " + std::to_string(stream.width) + "x" + std::to_string(stream.height) + " " + std::to_string(stream.fps) + "fps";
    const auto mismatches = geometry::settingsMismatches(*stored, {device.usb_port, cv::Size(stream.width, stream.height), pixel_format});
    if(!mismatches.empty())
    {
        // The recording is still useful, e.g. to recalibrate; it just does not claim this calibration.
        for(const auto& mismatch : mismatches)
        {
            std::fprintf(stderr, "%s: calibration not used: %s\n", device.usb_port.c_str(), mismatch.c_str());
        }
        return std::nullopt;
    }
    const auto digest = session::sha256File(path.string());
    if(!digest)
    {
        return std::nullopt;
    }
    return session::FileReference{path.filename().string(), *digest};
}

// The joint refinement (#13), if it covers this camera; replay reads the board model and pose from it
std::optional<session::FileReference> extrinsicsReference (const capture::CameraDevice& device)
{
    const std::filesystem::path path = dataHome() / "calibration" / "extrinsics.yml";
    const auto stored = geometry::loadExtrinsics(path.string());
    if(!stored || std::none_of(stored->refinement.cameras.begin(), stored->refinement.cameras.end(),
                               [&] (const auto& camera) { return camera.usb_port == device.usb_port; }))
    {
        std::fprintf(stderr, "%s: no board refinement in %s\n", device.usb_port.c_str(), path.c_str());
        return std::nullopt;
    }
    const auto digest = session::sha256File(path.string());
    if(!digest)
    {
        return std::nullopt;
    }
    return session::FileReference{path.filename().string(), *digest};
}

struct Recorder
{
    capture::CameraDevice device;
    std::unique_ptr<capture::CaptureThread> capture;
    std::thread writer;
    std::atomic<double> brightness{-1.0};
};
}  // namespace

session::CameraInfo recordedCamera (const capture::CameraDevice& device, const capture::StreamSettings& stream)
{
    session::CameraInfo camera{
        "usb-" + device.usb_port, device.usb_port, device.path, device.name, stream, !device.metadata_path.empty(), {}, {}, {}};
    const capture::CameraControls controls(device.path);
    for(const auto& [name, id] : {std::pair<const char*, std::uint32_t>{"auto_exposure", V4L2_CID_EXPOSURE_AUTO},
                                  {"exposure_dynamic_framerate", V4L2_CID_EXPOSURE_AUTO_PRIORITY},
                                  {"power_line_frequency", V4L2_CID_POWER_LINE_FREQUENCY},
                                  {"white_balance_automatic", V4L2_CID_AUTO_WHITE_BALANCE},
                                  {"white_balance_temperature", V4L2_CID_WHITE_BALANCE_TEMPERATURE}})
    {
        if(const auto value = controls.get(id))
        {
            camera.controls.emplace_back(name, *value);
        }
    }
    camera.intrinsics = intrinsicsReference(device, stream);
    camera.extrinsics = extrinsicsReference(device);
    return camera;
}

int runRecord (int argc, char* argv[])
{
    int seconds = 0;
    std::filesystem::path root = dataHome() / "sessions";
    std::string notes;
    for(int i = 0; i < argc; ++i)
    {
        const std::string arg = argv[i];
        if(arg == "--seconds" && i + 1 < argc)
        {
            seconds = std::atoi(argv[++i]);
        }
        else if(arg == "--root" && i + 1 < argc)
        {
            root = argv[++i];
        }
        else if(arg == "--notes" && i + 1 < argc)
        {
            notes = argv[++i];
        }
        else
        {
            std::fprintf(stderr, "Usage: dartpilot record [--seconds N] [--root DIR] [--notes TEXT]\n");
            return 2;
        }
    }

    session::SessionInfo info;
    info.session_id = session::newSessionId();
    info.created_utc = session::utcNow();
    info.notes = notes;
    std::vector<std::unique_ptr<Recorder>> recorders;
    for(const auto& device : capture::findCameras())
    {
        const capture::StreamSettings stream = streamSettings(device);
        auto recorder = std::make_unique<Recorder>();
        recorder->device = device;
        recorder->capture =
            std::make_unique<capture::CaptureThread>(std::make_unique<capture::V4l2FrameSource>(device, stream), kRecordingRingCapacity);
        if(!recorder->capture->start())
        {
            std::fprintf(stderr, "%s: %s\n", device.usb_port.c_str(), recorder->capture->stats().error.c_str());
            continue;
        }
        const session::CameraInfo camera = recordedCamera(device, stream);
        info.cameras.push_back(camera);
        recorders.push_back(std::move(recorder));
    }
    if(recorders.empty())
    {
        std::fprintf(stderr, "No camera could be started.\n");
        return 1;
    }

    std::string error;
    auto writer = session::SessionWriter::create(root, info, error);
    if(!writer)
    {
        std::fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    std::printf("Recording %zu camera(s) to %s%s\n", recorders.size(), writer->directory().c_str(), seconds > 0 ? "" : " (Ctrl+C to stop)");

    // One writer thread per camera; it drains its ring buffer after capture has stopped.
    std::atomic<bool> capture_stopped{false};
    for(std::size_t i = 0; i < recorders.size(); ++i)
    {
        Recorder& recorder = *recorders[i];
        recorder.writer = std::thread(
            [&, i]
            {
                auto next_brightness = std::chrono::steady_clock::now();
                while(true)
                {
                    auto frame = recorder.capture->frames().pop(std::chrono::milliseconds(100));
                    if(!frame)
                    {
                        if(capture_stopped)
                        {
                            break;
                        }
                        continue;
                    }
                    writer->writeFrame(i, *frame);
                    if(std::chrono::steady_clock::now() >= next_brightness)
                    {
                        recorder.brightness = meanBrightness(frame->data);
                        next_brightness += kHealthInterval;
                    }
                }
            });
    }

    std::signal(SIGINT, onInterrupt);
    std::signal(SIGTERM, onInterrupt);
    const auto start = std::chrono::steady_clock::now();
    auto next_health = start + kHealthInterval;
    while(!interrupted && (seconds <= 0 || std::chrono::steady_clock::now() - start < std::chrono::seconds(seconds)))
    {
        std::this_thread::sleep_until(next_health);
        next_health += kHealthInterval;
        const std::int64_t now_ns = capture::monotonicNowNs();
        for(std::size_t i = 0; i < recorders.size(); ++i)
        {
            writer->writeHealth(i, now_ns, recorders[i]->capture->stats(), recorders[i]->brightness);
        }
    }

    for(auto& recorder : recorders)
    {
        recorder->capture->stop();
    }
    capture_stopped = true;
    std::vector<capture::CaptureStats> stats;
    for(auto& recorder : recorders)
    {
        recorder->writer.join();
        stats.push_back(recorder->capture->stats());
    }
    const bool finished = writer->finish(session::utcNow(), stats);

    const double minutes = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count() / 60.0;
    std::printf("%-12s %8s %6s %7s %9s %10s\n", "camera", "frames", "lost", "drops", "written", "MB");
    double total_mb = 0;
    for(std::size_t i = 0; i < recorders.size(); ++i)
    {
        const auto totals = writer->totals(i);
        const double mb = static_cast<double>(totals.bytes_written) / 1e6;
        total_mb += mb;
        std::printf("%-12s %8llu %6llu %7llu %9llu %10.1f\n", recorders[i]->device.usb_port.c_str(), static_cast<unsigned long long>(stats[i].frames),
                    static_cast<unsigned long long>(stats[i].lost_frames), static_cast<unsigned long long>(stats[i].overflow_drops),
                    static_cast<unsigned long long>(totals.frames_written), mb);
    }
    std::printf("Total %.1f MB in %.2f min (%.0f MB/min)\n%s\n", total_mb, minutes, minutes > 0 ? total_mb / minutes : 0.0,
                writer->directory().c_str());
    return finished ? 0 : 1;
}
}  // namespace dartpilot::cli
