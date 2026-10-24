#pragma once

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/frame.hpp"

// Writes a recording in the session format of docs/replay-format.md.
namespace dartpilot::session
{
inline constexpr int kFormatVersion = 1;

struct FileReference
{
    std::string file;
    std::string sha256;
};

struct CameraInfo
{
    // "usb-<port>", the key calibration files use as well
    std::string id;
    std::string usb_port;
    std::string device_path;
    std::string name;
    capture::StreamSettings stream;
    bool metadata = false;
    // Control values read back from the camera after they were applied
    std::vector<std::pair<std::string, int>> controls;
    std::optional<FileReference> intrinsics;
    // The joint refinement of all cameras (extrinsics.yml), if it covers this camera
    std::optional<FileReference> extrinsics;
};

struct SessionInfo
{
    std::string session_id;
    // Informational only; the wall clock is never used for timing
    std::string created_utc;
    std::string notes;
    std::vector<CameraInfo> cameras;
};

struct CameraTotals
{
    std::uint64_t frames_written = 0;
    std::uint64_t bytes_written = 0;
};

// One writer per session. writeFrame() for a camera must always be called from the same thread; different cameras
// may be written from different threads at the same time.
class SessionWriter
{
   public:
    // Creates <root>/<session id>/ with its manifest and camera directories; nullptr and an error message on failure.
    static std::unique_ptr<SessionWriter> create (const std::filesystem::path& root, SessionInfo info, std::string& error);
    ~SessionWriter ();

    // Appends a frame of camera `camera` (index into SessionInfo::cameras): JPEG first, then its index line, so a
    // crash leaves at most an unindexed tail in frames.mjpg.
    bool writeFrame (std::size_t camera, const capture::Frame& frame);

    // Appends a line to capture.csv; brightness is the mean of the latest frame, 0–255, or negative if unknown.
    void writeHealth (std::size_t camera, std::int64_t time_ns, const capture::CaptureStats& stats, double brightness);

    // Rewrites the manifest with the end time and the counters of each camera; the files stay readable afterwards.
    bool finish (const std::string& ended_utc, const std::vector<capture::CaptureStats>& stats);

    const std::filesystem::path& directory () const { return directory_; }
    CameraTotals totals (std::size_t camera) const;

   private:
    struct CameraFiles;

    SessionWriter (std::filesystem::path directory, SessionInfo info);
    bool writeManifest (const std::string& ended_utc, const std::vector<capture::CaptureStats>* stats) const;

    std::filesystem::path directory_;
    SessionInfo info_;
    std::vector<std::unique_ptr<CameraFiles>> cameras_;
    std::mutex health_mutex_;
    std::ofstream health_;
};

// "20261023T201500Z-3f9a": UTC start time plus a random suffix, unique and sorted by time
std::string newSessionId ();
// ISO 8601 UTC time of now, e.g. "2026-10-23T20:15:00Z"
std::string utcNow ();
}  // namespace dartpilot::session
