#pragma once

#include <optional>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

// Where a dart enters the board, from its axis as several cameras see it (#23, #48). Each camera's image of the axis
// spans a plane through the camera centre; the dart enters the board where these planes cross the playing surface.
// Unlike the visible end of the point, this does not depend on how much of the point a camera sees.
namespace dartpilot::geometry
{
struct DartView
{
    const RefinedCamera* camera = nullptr;
    tip_candidates::DartObservation observation;
};

struct DartLocation
{
    cv::Point2f board_mm;
    // From the directions of the planes and a spread of 0.5 mm of each plane on the board (provisional, #48)
    cv::Matx22d covariance_mm2;
    // Indices of the views that agree on the point, in increasing order
    std::vector<int> views;
    // Per used view: distance of the point from its axis plane on the board, and between the point's image and the
    // nearest visible end of the object
    std::vector<double> plane_distance_mm;
    std::vector<double> end_distance_px;
};

// The largest group of views whose axis planes meet in one point on the board, each with a visible end of the object
// where the point lies in its image; two views must cross at a usable angle. Views of a short, cut-off object are not
// used. Nothing if no two views agree: the engine abstains rather than guess.
std::optional<DartLocation> locateDart (const std::vector<DartView>& views);
}  // namespace dartpilot::geometry
