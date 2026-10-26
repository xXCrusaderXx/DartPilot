#include "project_command.hpp"

#include <iostream>
#include <string>

#include <nlohmann/json.hpp>

#include "dartpilot/geometry/board_refinement.hpp"

namespace dartpilot::cli
{
int runProject (int argc, char* argv[])
{
    if(argc != 2 || std::string(argv[0]) != "--extrinsics")
    {
        std::cerr << "Usage: dartpilot project --extrinsics FILE < points.jsonl\n"
                     "  Reads one board point per line, {\"x_mm\": …, \"y_mm\": …}, and writes per line where it lies on the\n"
                     "  playing surface in each camera's image: {\"usb-<port>\": [x_px, y_px], …}\n";
        return 2;
    }
    const auto stored = geometry::loadExtrinsics(argv[1]);
    if(!stored)
    {
        std::cerr << "Cannot read the board refinement " << argv[1] << '\n';
        return 1;
    }
    std::string line;
    while(std::getline(std::cin, line))
    {
        const auto point = nlohmann::json::parse(line, nullptr, false);
        if(point.is_discarded() || !point.contains("x_mm") || !point.contains("y_mm"))
        {
            std::cerr << "Not a board point: " << line << '\n';
            return 1;
        }
        const cv::Point3f board_mm(point["x_mm"].get<float>(), point["y_mm"].get<float>(), 0.0f);
        nlohmann::json out = nlohmann::json::object();
        for(const auto& camera : stored->refinement.cameras)
        {
            const cv::Point2f image_px = geometry::boardToImage(camera, board_mm);
            out["usb-" + camera.usb_port] = {image_px.x, image_px.y};
        }
        std::cout << out.dump() << '\n';
    }
    return 0;
}
}  // namespace dartpilot::cli
