#pragma once

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "dartpilot/session/session_writer.hpp"

// Reads a recording in the session format of docs/replay-format.md.
namespace dartpilot::session
{
// One line of frames.csv
struct FrameIndex
{
    std::uint32_t sequence = 0;
    std::int64_t exposure_ns = 0;
    // "pts" or "driver"
    std::string timestamp_source;
    std::int64_t driver_ns = 0;
    std::int64_t arrival_ns = 0;
    std::optional<std::uint32_t> pts;
    std::uint64_t offset = 0;
    std::uint32_t size = 0;
};

struct RecordedCamera
{
    std::string id;
    std::string usb_port;
    std::string name;
    int width = 0;
    int height = 0;
    int fps = 0;
    std::optional<FileReference> intrinsics;
    std::optional<FileReference> extrinsics;
    // In the order they were written; a frame whose JPEG lies beyond the end of frames.mjpg is left out
    std::vector<FrameIndex> frames;
};

struct RecordedSession
{
    std::filesystem::path directory;
    std::string session_id;
    int version = 0;
    std::string software_version;
    std::string software_commit;
    std::vector<RecordedCamera> cameras;
};

// Reads the manifest and the frame indexes; nothing and an error message if the session cannot be read or has a
// newer format version.
std::optional<RecordedSession> openSession (const std::filesystem::path& directory, std::string& error);

// Reads the JPEGs of one camera of a session; keeps frames.mjpg open between frames.
class FrameReader
{
   public:
    FrameReader (const RecordedSession& session, std::size_t camera);

    // The JPEG of the camera's frame at this index, or empty if it cannot be read
    std::vector<std::uint8_t> read (std::size_t frame);

   private:
    const RecordedCamera& camera_;
    std::ifstream file_;
};
}  // namespace dartpilot::session
