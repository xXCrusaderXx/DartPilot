#include "replay_command.hpp"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <optional>
#include <string>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/replay/replay.hpp"
#include "dartpilot/session/session_reader.hpp"
#include "dartpilot/session/sha256.hpp"
#include "paths.hpp"

namespace dartpilot::cli
{
namespace
{
// The board refinement the session was recorded with, if the file in the calibration directory is still the same
std::optional<std::filesystem::path> recordedExtrinsics (const session::RecordedSession& recorded, std::string& problem)
{
    for(const auto& camera : recorded.cameras)
    {
        if(!camera.extrinsics)
        {
            continue;
        }
        const std::filesystem::path path = dataHome() / "calibration" / camera.extrinsics->file;
        const auto digest = session::sha256File(path.string());
        if(!digest)
        {
            problem = "the session refers to " + path.string() + ", which cannot be read";
            return std::nullopt;
        }
        if(*digest != camera.extrinsics->sha256)
        {
            problem = path.string() + " changed after the recording";
            return std::nullopt;
        }
        return path;
    }
    problem = "the session refers to no board refinement";
    return std::nullopt;
}

int usage ()
{
    std::fprintf(stderr,
                 "Usage: dartpilot replay <session directory> [--pipeline tracker|baseline|none] [--run-id ID] [--extrinsics FILE]\n"
                 "                        [--check-every SECONDS] [--no-checks]\n"
                 "  --pipeline     throw detection: tracker (the live detection, default), baseline (frame differencing) or none\n");
    return 2;
}
}  // namespace

int runReplay (int argc, char* argv[])
{
    std::optional<std::filesystem::path> session_dir, extrinsics_path;
    replay::ReplayConfig config;
    config.pipeline = "tracker";
    bool checks = true;
    for(int i = 0; i < argc; ++i)
    {
        const std::string arg = argv[i];
        if(arg == "--run-id" && i + 1 < argc)
        {
            config.run_id = argv[++i];
        }
        else if(arg == "--extrinsics" && i + 1 < argc)
        {
            extrinsics_path = argv[++i];
        }
        else if(arg == "--check-every" && i + 1 < argc)
        {
            config.check_interval_ns = static_cast<std::int64_t>(std::atof(argv[++i]) * 1e9);
        }
        else if(arg == "--pipeline" && i + 1 < argc)
        {
            config.pipeline = argv[++i];
        }
        else if(arg == "--no-checks")
        {
            checks = false;
        }
        else if(!arg.starts_with("--") && !session_dir)
        {
            session_dir = arg;
        }
        else
        {
            return usage();
        }
    }
    if(!session_dir)
    {
        return usage();
    }
    std::string error;
    const auto recorded = session::openSession(*session_dir, error);
    if(!recorded)
    {
        std::fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }

    if(!checks)
    {
        config.check_interval_ns = 0;
    }
    // Throw detection and the calibration checks both need the board refinement.
    if(config.pipeline != "none" || config.check_interval_ns > 0)
    {
        std::string problem;
        if(!extrinsics_path)
        {
            extrinsics_path = recordedExtrinsics(*recorded, problem);
        }
        if(extrinsics_path)
        {
            config.extrinsics = geometry::loadExtrinsics(extrinsics_path->string());
            const auto digest = session::sha256File(extrinsics_path->string());
            if(!config.extrinsics || !digest)
            {
                std::fprintf(stderr, "Cannot read the board refinement %s\n", extrinsics_path->c_str());
                return 1;
            }
            config.extrinsics_sha256 = *digest;
        }
        else if(config.pipeline != "none")
        {
            std::fprintf(stderr, "No throw detection: %s. Pass --extrinsics FILE, or --pipeline none.\n", problem.c_str());
            return 1;
        }
        else
        {
            std::fprintf(stderr, "No calibration checks: %s. Pass --extrinsics FILE to check against a refinement.\n", problem.c_str());
        }
    }

    const auto summary = replay::replaySession(*recorded, config, error);
    if(!summary)
    {
        std::fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    std::printf("%zu frames of %zu cameras replayed, %zu calibration checks, %zu undecodable frames\n", summary->frames, recorded->cameras.size(),
                summary->calibration_checks, summary->undecodable_frames);
    if(config.pipeline != "none")
    {
        std::printf("%s: %zu throws (%zu abstained, %zu matching no recorded throw), %zu takeouts%s\n", config.pipeline.c_str(), summary->throws,
                    summary->abstained, summary->unmatched_throws, summary->takeouts,
                    summary->wrote_session_throws ? "; wrote the session's throws.csv" : "");
    }
    std::printf("%s\n", summary->run_directory.c_str());
    return 0;
}
}  // namespace dartpilot::cli
