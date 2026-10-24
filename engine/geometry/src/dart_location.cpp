#include "dartpilot/geometry/dart_location.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace dartpilot::geometry
{
namespace
{
// A cut-off object shorter than this shows too little of its axis to fix its direction.
constexpr double kMinCutAxis_px = 120.0;
// The planes of agreeing views pass within this distance of their common point on the board.
constexpr double kMaxPlaneDistance_mm = 1.5;
// Two views alone must cross at least at this angle on the board, or their crossing slides along both lines.
constexpr double kMinCrossing_deg = 15.0;
// The point's image lies at most this far from a visible end; the entry may hide a few pixels behind the visible end.
constexpr double kMaxEndDistance_px = 12.0;
constexpr double kPlaneSigma_mm = 0.5;

// The axis plane of a view as a line on the board, a x + b y = c with a^2 + b^2 = 1
std::optional<cv::Vec3d> boardLine (const DartView& view)
{
    const auto& observation = view.observation;
    if(!view.camera || observation.axis_px.size() < 2 || (observation.cut && observation.axis_length_px < kMinCutAxis_px))
    {
        return std::nullopt;
    }
    cv::Mat rays(static_cast<int>(observation.axis_px.size()), 3, CV_64F);
    for(std::size_t i = 0; i < observation.axis_px.size(); ++i)
    {
        const cv::Vec3d ray = viewRay(*view.camera, observation.axis_px[i]);
        for(int j = 0; j < 3; ++j)
        {
            rays.at<double>(static_cast<int>(i), j) = ray[j];
        }
    }
    // The plane through the camera centre that contains all rays: its normal is orthogonal to every ray.
    cv::Mat w, u, vt;
    cv::SVD::compute(rays, w, u, vt);
    const cv::Vec3d normal(vt.at<double>(2, 0), vt.at<double>(2, 1), vt.at<double>(2, 2));
    const double length = std::hypot(normal[0], normal[1]);
    if(length < 1e-9)
    {
        return std::nullopt;
    }
    return cv::Vec3d(normal[0] / length, normal[1] / length, normal.dot(cameraCentre(*view.camera)) / length);
}
}  // namespace

std::optional<DartLocation> locateDart (const std::vector<DartView>& views)
{
    std::vector<int> usable;
    std::vector<cv::Vec3d> lines;
    for(std::size_t i = 0; i < views.size(); ++i)
    {
        if(const auto line = boardLine(views[i]))
        {
            usable.push_back(static_cast<int>(i));
            lines.push_back(*line);
        }
    }
    const int n = static_cast<int>(usable.size());
    if(n < 2 || n > 16)
    {
        return std::nullopt;
    }

    std::optional<DartLocation> best;
    double best_worst_mm = 0.0;
    for(unsigned subset = 1; subset < (1u << n); ++subset)
    {
        std::vector<int> members;
        for(int i = 0; i < n; ++i)
        {
            if(subset >> i & 1u)
            {
                members.push_back(i);
            }
        }
        if(members.size() < 2 || (best && members.size() < best->views.size()))
        {
            continue;
        }
        cv::Matx22d information = cv::Matx22d::zeros();
        cv::Vec2d weighted(0, 0);
        double min_crossing_deg = 90.0;
        for(std::size_t a = 0; a < members.size(); ++a)
        {
            const cv::Vec2d direction(lines[members[a]][0], lines[members[a]][1]);
            information += direction * direction.t();
            weighted += direction * lines[members[a]][2];
            for(std::size_t b = a + 1; b < members.size(); ++b)
            {
                const double sine = std::abs(lines[members[a]][0] * lines[members[b]][1] - lines[members[a]][1] * lines[members[b]][0]);
                min_crossing_deg = std::min(min_crossing_deg, std::asin(std::min(1.0, sine)) * 180.0 / CV_PI);
            }
        }
        if(members.size() == 2 && min_crossing_deg < kMinCrossing_deg)
        {
            continue;
        }
        if(cv::determinant(information) < 1e-9)
        {
            continue;
        }
        const cv::Vec2d point = information.inv() * weighted;

        DartLocation location;
        location.board_mm = cv::Point2f(static_cast<float>(point[0]), static_cast<float>(point[1]));
        location.covariance_mm2 = information.inv() * (kPlaneSigma_mm * kPlaneSigma_mm);
        double worst_mm = 0.0;
        bool agree = true;
        for(const int m : members)
        {
            const double distance_mm = lines[m][0] * point[0] + lines[m][1] * point[1] - lines[m][2];
            worst_mm = std::max(worst_mm, std::abs(distance_mm));
            const DartView& view = views[usable[m]];
            const cv::Point2f image = boardToImage(*view.camera, cv::Point3f(location.board_mm.x, location.board_mm.y, 0.0f));
            double nearest_px = std::numeric_limits<double>::infinity();
            for(const auto& end : view.observation.ends_px)
            {
                nearest_px = std::min(nearest_px, static_cast<double>(cv::norm(end - image)));
            }
            agree = agree && std::abs(distance_mm) <= kMaxPlaneDistance_mm && nearest_px <= kMaxEndDistance_px;
            location.views.push_back(usable[m]);
            location.plane_distance_mm.push_back(distance_mm);
            location.end_distance_px.push_back(nearest_px);
        }
        if(!agree)
        {
            continue;
        }
        if(!best || location.views.size() > best->views.size() || worst_mm < best_worst_mm)
        {
            best = std::move(location);
            best_worst_mm = worst_mm;
        }
    }
    return best;
}
}  // namespace dartpilot::geometry
