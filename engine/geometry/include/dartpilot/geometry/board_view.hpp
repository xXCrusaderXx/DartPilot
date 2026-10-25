#pragma once

#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"

// The real board seen from the front, put together from the cameras, for clients to draw hits on instead of a drawn
// board (docs/engine-api.md, "board_image").
namespace dartpilot::geometry
{
struct BoardView
{
    // Square, the board centre in the middle, x to the right and y up as in board coordinates
    cv::Mat image;
    double mm_per_px = 0.0;
    double radius_mm = 0.0;
};

// Each pixel comes mostly from the camera that sees that part of the board with the most pixels per millimetre, with
// soft transitions between cameras whose brightness is matched first. Outside sharp_radius_mm (the number ring) the
// image is blurred and darkened, so the eye stays on the board; 0 keeps it all sharp. cameras and images in the same
// order; a camera without an image is left out.
BoardView renderBoardView (const std::vector<const RefinedCamera*>& cameras, const std::vector<cv::Mat>& images, int size_px, double radius_mm,
                           double sharp_radius_mm = 0.0);
}  // namespace dartpilot::geometry
