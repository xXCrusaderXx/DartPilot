#pragma once

#include <optional>
#include <vector>

#include <opencv2/core.hpp>

// What one camera sees of a dart or a pin: the object against an image of the empty board, the centre line of its
// narrow part and its visible ends. Where it enters the board follows from several cameras (geometry::locateDart).
namespace dartpilot::tip_candidates
{
struct DartObservation
{
    // Centre line of the narrow part of the object (point, barrel, shaft), one point per 2 px along its axis. The flight
    // is left out: it is wide, and in perspective its middle is not on the axis.
    std::vector<cv::Point2f> axis_px;
    // The two ends of the object along its axis, each refined to where the difference to the empty board fades. The
    // tip is one of them; an end at the image border is left out, because there the image cuts the object.
    std::vector<cv::Point2f> ends_px;
    // Distance between the first and the last axis point
    double axis_length_px = 0.0;
    // The object touches the image border, so the camera sees only part of it
    bool cut = false;
    int area_px = 0;
};

// image and empty_board are images of the same camera, ideally means of several frames, 8-bit or float BGR. Nothing if
// no object large enough stands out from the empty board.
std::optional<DartObservation> observeDart (const cv::Mat& image, const cv::Mat& empty_board);
// The shift of the whole image if a camera's view changed as a whole from one still image to the next: it was knocked,
// tilted or sways. A dart changes one place of the image, a knocked camera the edges all over it. Nothing otherwise.
std::optional<cv::Point2d> viewChange (const cv::Mat& before, const cv::Mat& after);
}  // namespace dartpilot::tip_candidates
