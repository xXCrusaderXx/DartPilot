#include "dartpilot/geometry/tip_triangulation.hpp"

#include <algorithm>

namespace dartpilot::geometry
{
TipTriangulation triangulateTips (const std::vector<DartView>& views, const DartLocation& location)
{
    TipTriangulation result;
    result.tip_px.resize(views.size());
    result.board_mm.resize(views.size());
    result.reprojection_px.resize(views.size());
    const cv::Point3f entry(location.board_mm.x, location.board_mm.y, 0.0f);
    for(std::size_t v = 0; v < views.size(); ++v)
    {
        if(!views[v].camera)
        {
            continue;
        }
        const cv::Point2f expected = boardToImage(*views[v].camera, entry);
        std::optional<cv::Point2f> tip;
        double nearest = kMaxTipDistance_px;
        for(const auto& end : views[v].observation.ends_px)
        {
            const double distance = cv::norm(end - expected);
            if(distance <= nearest)
            {
                nearest = distance;
                tip = end;
            }
        }
        if(tip)
        {
            result.tip_px[v] = tip;
            result.board_mm[v] = imageToBoard(*views[v].camera, *tip);
        }
    }

    // Least squares over the rays of the agreeing views: the point nearest to all of them
    cv::Matx33d a = cv::Matx33d::zeros();
    cv::Vec3d b(0, 0, 0);
    for(const int v : location.views)
    {
        const auto& tip = result.tip_px[static_cast<std::size_t>(v)];
        if(!tip)
        {
            continue;
        }
        const RefinedCamera& camera = *views[static_cast<std::size_t>(v)].camera;
        const cv::Vec3d d = viewRay(camera, *tip);
        const cv::Matx33d across = cv::Matx33d::eye() - d * d.t();
        a += across;
        b += across * cameraCentre(camera);
        ++result.views_used;
    }
    if(result.views_used < 2 || std::abs(cv::determinant(a)) < 1e-12)
    {
        return result;
    }
    const cv::Vec3d x = a.inv() * b;
    result.point_mm = cv::Point3d(x[0], x[1], x[2]);
    for(std::size_t v = 0; v < views.size(); ++v)
    {
        if(result.tip_px[v] && views[v].camera)
        {
            const cv::Point2f projected =
                boardToImage(*views[v].camera, cv::Point3f(static_cast<float>(x[0]), static_cast<float>(x[1]), static_cast<float>(x[2])));
            result.reprojection_px[v] = cv::norm(projected - *result.tip_px[v]);
        }
    }
    return result;
}
}  // namespace dartpilot::geometry
