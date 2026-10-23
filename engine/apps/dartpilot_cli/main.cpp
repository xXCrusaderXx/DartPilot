#include <iostream>
#include <string_view>

#include "dartpilot/capture/capture.hpp"
#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/fusion.hpp"
#include "dartpilot/geometry/geometry.hpp"
#include "dartpilot/replay/replay.hpp"
#include "dartpilot/scoring/scoring.hpp"
#include "dartpilot/tip_candidates/tip_candidates.hpp"
#include "dartpilot/version.hpp"
#include "focus_command.hpp"

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
    if(arg == "focus")
    {
        return dartpilot::cli::runFocus(argc - 2, argv + 2);
    }
    std::cerr << "Usage: dartpilot --version | --modules | focus --camera <device> [--exposure <value>]\n";
    return arg.empty() || arg == "--help" ? 0 : 2;
}
