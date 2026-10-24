#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/session/session_reader.hpp"

// Reproducible offline evaluation of recorded sessions (#9): the frames of all cameras go through the pipeline in the
// order of their exposure times, and the results are written to results/<run id>/ of the session
// (docs/replay-format.md). Nothing here reads the wall clock, uses unseeded randomness or depends on thread timing.
namespace dartpilot::replay
{
// Module name, used by the CLI and the smoke test
std::string_view moduleName ();

struct ReplayFrame
{
    std::size_t camera = 0;
    // Index into the camera's frames
    std::size_t frame = 0;
};

// The order of docs/replay-format.md: by exposure_ns, frames with the same time by camera id
std::vector<ReplayFrame> replayOrder (const session::RecordedSession& session);

struct ReplayConfig
{
    // Names the results directory; the files in it do not contain it, so runs can be compared byte by byte
    std::string run_id = "replay";
    // The board refinement (#13) the cameras are checked against; without it there are no calibration checks
    std::optional<geometry::StoredExtrinsics> extrinsics;
    std::string extrinsics_sha256;
    // A calibration check (#49) of every calibrated camera at the start and then every this much recorded time;
    // zero switches the checks off
    std::int64_t check_interval_ns = 10'000'000'000;
    // Frames averaged for one check, as in the setup GUI
    int check_frames = 10;
};

struct ReplaySummary
{
    std::filesystem::path run_directory;
    std::size_t frames = 0;
    std::size_t undecodable_frames = 0;
    std::size_t calibration_checks = 0;
};

// Writes run.json, throws.jsonl and calibration_checks.jsonl into a new results/<run id>/; nothing and an error
// message if the run directory exists already or a file cannot be written.
std::optional<ReplaySummary> replaySession (const session::RecordedSession& session, const ReplayConfig& config, std::string& error);
}  // namespace dartpilot::replay
