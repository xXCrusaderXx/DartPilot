#include <iostream>
#include <string_view>

#include <opencv2/imgcodecs.hpp>

#include "analyse_command.hpp"
#include "capture_check_command.hpp"
#include "dartpilot/capture/capture.hpp"
#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/fusion.hpp"
#include "dartpilot/geometry/charuco.hpp"
#include "dartpilot/geometry/geometry.hpp"
#include "dartpilot/replay/replay.hpp"
#include "dartpilot/scoring/scoring.hpp"
#include "dartpilot/tip_candidates/tip_candidates.hpp"
#include "dartpilot/version.hpp"
#include "focus_command.hpp"
#include "record_command.hpp"
#include "replay_command.hpp"
#include "serve_command.hpp"
#include "white_balance_command.hpp"

int main (int argc, char* argv[])
{
    const std::string_view arg = argc > 1 ? argv[1] : "";
    if(arg == "--version")
    {
        std::cout << "dartpilot " << dartpilot::kVersion << '\n';
        return 0;
    }
    if(arg == "--modules")
    {
        for(const auto name :
            {dartpilot::capture::moduleName(), dartpilot::event_detection::moduleName(), dartpilot::tip_candidates::moduleName(),
             dartpilot::geometry::moduleName(), dartpilot::fusion::moduleName(), dartpilot::scoring::moduleName(), dartpilot::replay::moduleName()})
        {
            std::cout << name << '\n';
        }
        return 0;
    }
    if(arg == "serve")
    {
        return dartpilot::cli::runServe(argc - 2, argv + 2);
    }
    if(arg == "record")
    {
        return dartpilot::cli::runRecord(argc - 2, argv + 2);
    }
    if(arg == "analyse")
    {
        return dartpilot::cli::runAnalyse(argc - 2, argv + 2);
    }
    if(arg == "replay")
    {
        return dartpilot::cli::runReplay(argc - 2, argv + 2);
    }
    if(arg == "capture-check")
    {
        return dartpilot::cli::runCaptureCheck(argc - 2, argv + 2);
    }
    if(arg == "white-balance")
    {
        return dartpilot::cli::runWhiteBalance(argc - 2, argv + 2);
    }
    if(arg == "focus")
    {
        return dartpilot::cli::runFocus(argc - 2, argv + 2);
    }
    const bool phone_pattern = argc == 4 && std::string_view(argv[2]) == "--phone";
    if(arg == "pattern" && (argc == 3 || phone_pattern))
    {
        // Writes a calibration pattern image, e.g. docs/calibration/charuco-10x7-DICT_4X4_50-marker-0.70.png
        const char* path = argv[argc - 1];
        const dartpilot::geometry::CharucoFinder finder(phone_pattern ? dartpilot::geometry::CharucoTarget::phone()
                                                                      : dartpilot::geometry::CharucoTarget::tablet());
        const cv::Mat image = finder.patternImage(finder.target().imageSize_px());
        if(image.empty() || !cv::imwrite(path, image))
        {
            std::cerr << "Cannot write the pattern to " << path << (image.empty() ? " (built without ChArUco support)" : "") << '\n';
            return 1;
        }
        return 0;
    }
    std::cerr << "Usage: dartpilot --version | --modules | serve --simulate [--listen ADDRESS] [--port N] | record [--seconds N] "
                 "[--root DIR] [--notes TEXT] | replay <session> [--run-id ID] [--extrinsics FILE] [--check-every SECONDS] "
                 "[--no-checks] | capture-check [seconds] | white-balance | focus "
                 "--camera <device> [--exposure <value>] | pattern "
                 "[--phone] <file.png>\n";
    return arg.empty() || arg == "--help" ? 0 : 2;
}
