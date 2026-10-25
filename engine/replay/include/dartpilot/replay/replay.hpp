#pragma once

#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "dartpilot/fusion/detection_params.hpp"
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
// offsets_ns, per camera in the session's order (or empty): added to its exposure times, for testing how a wrong time
// association between the cameras affects the results (#24)
std::vector<ReplayFrame> replayOrder (const session::RecordedSession& session, const std::vector<std::int64_t>& offsets_ns = {});

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
    // Throw detection (#18): "tracker" (the live detection), "baseline" (frame differencing) or "none". Both need the
    // board refinement and look at the board at the still moments live detection waits for.
    std::string pipeline = "none";
    // Every value of the detection (fusion::detectionParams), recorded in run.json
    fusion::DetectionSettings detection;
    // Shifts a camera's frames in time by this much, by camera id; for the association experiment of #24 only
    std::map<std::string, std::int64_t> camera_offset_ns;
};

struct ReplaySummary
{
    std::filesystem::path run_directory;
    std::size_t frames = 0;
    std::size_t undecodable_frames = 0;
    std::size_t calibration_checks = 0;
    std::size_t throws = 0;
    std::size_t abstained = 0;
    std::size_t takeouts = 0;
    // Throws that match none of the session's recorded throws
    std::size_t unmatched_throws = 0;
    // throws.csv was written, because the session had none
    bool wrote_session_throws = false;
};

// Writes run.json, throws.jsonl and calibration_checks.jsonl into a new results/<run id>/; nothing and an error
// message if the run directory exists already or a file cannot be written. A detected throw takes the throw id of the
// session's recorded throw whose event window holds it; a session without throws.csv gets one with the run's throws.
std::optional<ReplaySummary> replaySession (const session::RecordedSession& session, const ReplayConfig& config, std::string& error);
}  // namespace dartpilot::replay
