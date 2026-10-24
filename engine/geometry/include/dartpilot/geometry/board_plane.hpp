#pragma once

#include <optional>
#include <string>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/geometry/intrinsics.hpp"

// From detected board features to board coordinates (docs/board-coordinates.md): orientation and the board plane.
namespace dartpilot::geometry
{
// The image sector a point lies in: sector i lies between wire i and wire i + 1, counter-clockwise in the image.
// Nothing outside the double ring or inside the outer bull.
std::optional<int> sectorAt (const BoardDetection& detection, const cv::Point2f& image_px);

struct BoardCorrespondence
{
    cv::Point2f image_px;
    cv::Point2f board_mm;
    double sigma_px = 0.0;
};

// Board coordinates for every detected point, given the image sector that is sector 20. The colour pattern repeats
// every second sector, so this has to come from the user (or later from the number ring).
std::vector<BoardCorrespondence> orientBoard (const BoardDetection& detection, int twenty_sector);

// The mapping between the board plane and the image of one camera, as a homography. With intrinsics the image points
// are undistorted first, so the homography then works in undistorted pixels.
struct BoardPlaneFit
{
    cv::Matx33d board_to_image;
    bool undistorted = false;
    // Reprojection error of the points in pixels
    double rms_px = 0.0;
    // Distance between each point mapped back onto the board and its nominal position
    double rms_mm = 0.0;
    double worst_mm = 0.0;
};

// Needs at least eight correspondences; intrinsics may be null.
std::optional<BoardPlaneFit> fitBoardPlane (const std::vector<BoardCorrespondence>& correspondences, const IntrinsicCalibration* intrinsics);

// Board point of an image point; pass the same intrinsics as to fitBoardPlane.
cv::Point2f imageToBoard (const BoardPlaneFit& fit, const cv::Point2f& image_px, const IntrinsicCalibration* intrinsics);

struct StoredBoardPlane
{
    BoardPlaneFit fit;
    int twenty_sector = 0;
    std::string usb_port;
    // Set by the caller; the geometry module never reads the clock
    std::string created;
    std::vector<BoardCorrespondence> correspondences;
};

bool saveBoardPlane (const std::string& path, const StoredBoardPlane& plane);
std::optional<StoredBoardPlane> loadBoardPlane (const std::string& path);
}  // namespace dartpilot::geometry
