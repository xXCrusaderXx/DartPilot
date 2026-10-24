#include "dartpilot/geometry/board_state.hpp"

#include <filesystem>

#include <opencv2/imgcodecs.hpp>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

namespace dartpilot::geometry
{
namespace
{
// Without a reference: a board whose wire crossings are further than this from the calibration is partly hidden
// (unhidden boards check within about 1 mm under the light they were calibrated in, #92).
constexpr double kHiddenBoard_mm = 2.5;
}  // namespace

std::string_view toString (BoardState state)
{
    switch(state)
    {
        case BoardState::Empty:
            return "empty";
        case BoardState::Occupied:
            return "occupied";
        case BoardState::Unknown:
            return "unknown";
    }
    return "unknown";
}

BoardCheck checkBoard (const cv::Mat& image, const cv::Mat* reference, const RefinedCamera* calibration, const BoardModel& board)
{
    BoardCheck check;
    if(image.empty())
    {
        check.reason = "No image.";
        return check;
    }
    if(reference && !reference->empty() && reference->size() == image.size())
    {
        if(const auto observation = tip_candidates::observeDart(image, *reference))
        {
            cv::Point2d sum(0, 0);
            for(const auto& p : observation->axis_px)
            {
                sum += cv::Point2d(p.x, p.y);
            }
            check.state = BoardState::Occupied;
            check.image_point_px = sum / static_cast<double>(observation->axis_px.size());
            check.reason = "Something stands out from the empty board.";
        }
        else
        {
            check.state = BoardState::Empty;
        }
        return check;
    }
    if(!calibration)
    {
        check.reason = "No empty-board reference and no calibration.";
        return check;
    }
    cv::Mat image_8u;
    image.convertTo(image_8u, CV_8UC3);
    const auto detection = detectBoard(image_8u);
    const auto matched = detection ? checkCalibration(*detection, *calibration, board) : std::nullopt;
    if(!matched || matched->rms_mm > kHiddenBoard_mm)
    {
        check.state = BoardState::Occupied;
        check.reason = matched ? "The board's wires are partly hidden." : "The board cannot be found: something hides it.";
        return check;
    }
    check.reason = "No empty-board reference; the wires are all visible, but a dart in a field may not hide any.";
    return check;
}

std::string emptyReferenceFileName (std::string_view usb_port) { return "empty-usb-" + std::string(usb_port) + ".png"; }

bool saveEmptyReference (const std::string& path, const cv::Mat& image)
{
    if(image.empty())
    {
        return false;
    }
    cv::Mat image_8u;
    image.convertTo(image_8u, CV_8UC3);
    try
    {
        return cv::imwrite(path, image_8u);
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}

cv::Mat loadEmptyReference (const std::string& path)
{
    // A missing file is the normal case before the first reference; OpenCV would log a warning for it.
    if(!std::filesystem::exists(path))
    {
        return {};
    }
    return cv::imread(path, cv::IMREAD_COLOR);
}
}  // namespace dartpilot::geometry
