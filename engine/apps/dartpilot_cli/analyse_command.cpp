#include "analyse_command.hpp"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <optional>
#include <string>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/replay/diagnosis.hpp"
#include "dartpilot/session/session_reader.hpp"
#include "paths.hpp"

namespace dartpilot::cli
{
int runAnalyse (int argc, char* argv[])
{
    std::optional<std::filesystem::path> session_dir;
    std::filesystem::path extrinsics_path = dataHome() / "calibration" / "extrinsics.yml";
    std::string run_id = "diagnosis";
    for(int i = 0; i < argc; ++i)
    {
        const std::string arg = argv[i];
        if(arg == "--extrinsics" && i + 1 < argc)
        {
            extrinsics_path = argv[++i];
        }
        else if(arg == "--run-id" && i + 1 < argc)
        {
            run_id = argv[++i];
        }
        else if(!arg.starts_with("--") && !session_dir)
        {
            session_dir = arg;
        }
        else
        {
            session_dir.reset();
            break;
        }
    }
    if(!session_dir)
    {
        std::fprintf(stderr, "Usage: dartpilot analyse <session directory> [--extrinsics FILE] [--run-id ID]\n");
        return 2;
    }
    std::string error;
    const auto recorded = session::openSession(*session_dir, error);
    if(!recorded)
    {
        std::fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    const auto extrinsics = geometry::loadExtrinsics(extrinsics_path.string());
    if(!extrinsics)
    {
        std::fprintf(stderr, "No board refinement at %s: calibration and darts are not checked.\n", extrinsics_path.c_str());
    }
    const auto diagnosis = replay::diagnoseSession(*recorded, extrinsics ? &*extrinsics : nullptr, error);
    if(!diagnosis)
    {
        std::fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    const std::filesystem::path directory = recorded->directory / "results" / run_id;
    std::error_code fs_error;
    std::filesystem::create_directories(directory, fs_error);
    std::ofstream(directory / "diagnosis.json") << replay::toJson(*diagnosis);
    const std::string markdown = replay::toMarkdown(*diagnosis);
    std::ofstream(directory / "diagnosis.md") << markdown;
    std::printf("%s\nWritten to %s\n", markdown.c_str(), directory.c_str());
    return 0;
}
}  // namespace dartpilot::cli
