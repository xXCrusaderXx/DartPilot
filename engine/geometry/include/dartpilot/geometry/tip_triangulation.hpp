#pragma once

#include <optional>
#include <vector>

#include "dartpilot/geometry/dart_location.hpp"

// The tip as a point in 3D (#23, technical plan 5.3 approach B), next to the entry point locateDart finds from the
// axis planes: per camera, the visible end of the dart nearest to where the entry point lies in its image is the tip;
// the rays through these tips are crossed in a least-squares sense. Each camera's tip also gives the board point that
// camera alone sees (approach A, #22): its ray met with the board plane.
namespace dartpilot::geometry
{
struct TipTriangulation
{
    // Per view of the input: the tip pixel, the board point of that camera alone, and how far the triangulated point
    // lies from the tip in that camera's image; nothing where a camera shows no tip near the entry point
    std::vector<std::optional<cv::Point2f>> tip_px;
    std::vector<std::optional<cv::Point2f>> board_mm;
    std::vector<std::optional<double>> reprojection_px;
    // From the tips of the views that agree on the entry point; nothing with fewer than two of them
    std::optional<cv::Point3d> point_mm;
    int views_used = 0;
};

// A visible end farther than this from the entry point's image is not the tip.
inline constexpr double kMaxTipDistance_px = 40.0;

TipTriangulation triangulateTips (const std::vector<DartView>& views, const DartLocation& location);
}  // namespace dartpilot::geometry
