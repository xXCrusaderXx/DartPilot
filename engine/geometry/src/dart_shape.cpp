#include "dartpilot/geometry/dart_shape.hpp"

#include <algorithm>
#include <cmath>

namespace dartpilot::geometry
{
namespace
{
// The axis planes of two views must differ at least by this angle to fix the axis in 3D
constexpr double kMinPlaneAngle_deg = 10.0;
// The width is followed across the axis at most this far to either side
constexpr double kMaxHalfWidth_mm = 30.0;
// The flight is where the width is at least this share of its largest; the barrel where it is at least this share of
// the barrel's diameter
constexpr double kFlightShare = 0.75;
constexpr double kBarrelShare = 0.75;

cv::Vec3d toVec (const cv::Point3f& p) { return {p.x, p.y, p.z}; }
cv::Point3f toPoint (const cv::Vec3d& v) { return {static_cast<float>(v[0]), static_cast<float>(v[1]), static_cast<float>(v[2])}; }

// Normal of the plane through the camera centre that holds the view's axis
std::optional<cv::Vec3d> axisPlaneNormal (const DartView& view)
{
    const auto& axis = view.observation.axis_px;
    if(!view.camera || axis.size() < 2)
    {
        return std::nullopt;
    }
    const cv::Vec3d normal = viewRay(*view.camera, axis.front()).cross(viewRay(*view.camera, axis.back()));
    const double length = cv::norm(normal);
    return length > 1e-9 ? std::optional<cv::Vec3d>(normal / length) : std::nullopt;
}

// Distance along the axis line (point + t direction) of the point closest to the ray from centre through image_px
double alongAxis (const RefinedCamera& camera, const cv::Point2f& image_px, const cv::Vec3d& point, const cv::Vec3d& direction)
{
    const cv::Vec3d centre = cameraCentre(camera), ray = viewRay(camera, image_px);
    // Closest points of two lines: point + t d and centre + s r
    const cv::Vec3d w = point - centre;
    const double b = direction.dot(ray), d = direction.dot(w), e = ray.dot(w);
    const double denominator = 1.0 - b * b;
    return denominator > 1e-9 ? (b * e - d) / denominator : 0.0;
}

// Width of the object in the camera's mask at distance t along the axis, in mm; nothing where the camera does not
// see that part of the axis
std::optional<double> widthAt (const DartView& view, const cv::Vec3d& point, const cv::Vec3d& direction, double t)
{
    const cv::Mat& mask = view.observation.mask;
    if(mask.empty())
    {
        return std::nullopt;
    }
    const cv::Vec3d x = point + direction * t;
    cv::Vec3d across = direction.cross(cameraCentre(*view.camera) - x);
    across /= cv::norm(across);
    const cv::Point2f q = boardToImage(*view.camera, toPoint(x));
    const cv::Point2f q1 = boardToImage(*view.camera, toPoint(x + across));
    const double px_per_mm = cv::norm(q1 - q);
    const cv::Rect image(0, 0, mask.cols, mask.rows);
    if(px_per_mm < 1e-3 || !image.contains(cv::Point(cvRound(q.x), cvRound(q.y))) || !mask.at<uchar>(cvRound(q.y), cvRound(q.x)))
    {
        return std::nullopt;
    }
    const cv::Point2f step = (q1 - q) * static_cast<float>(1.0 / px_per_mm);
    int width_px = 1;
    for(const float side : {-1.0f, 1.0f})
    {
        for(int k = 1; k < kMaxHalfWidth_mm * px_per_mm; ++k)
        {
            const cv::Point p(cvRound(q.x + side * step.x * k), cvRound(q.y + side * step.y * k));
            if(!image.contains(p) || !mask.at<uchar>(p.y, p.x))
            {
                break;
            }
            ++width_px;
        }
    }
    return width_px / px_per_mm;
}
}  // namespace

std::optional<DartShape> measureDart (const std::vector<DartView>& views, const DartLocation& location)
{
    // The axis: the line where the planes of the two used views that differ most cross, through the entry point
    std::vector<int> used;
    std::vector<cv::Vec3d> normals;
    for(const int v : location.views)
    {
        if(const auto normal = axisPlaneNormal(views[static_cast<std::size_t>(v)]))
        {
            used.push_back(v);
            normals.push_back(*normal);
        }
    }
    cv::Vec3d direction;
    double best = std::sin(kMinPlaneAngle_deg * CV_PI / 180.0);
    for(std::size_t i = 0; i < normals.size(); ++i)
    {
        for(std::size_t j = i + 1; j < normals.size(); ++j)
        {
            const cv::Vec3d cross = normals[i].cross(normals[j]);
            if(cv::norm(cross) > best)
            {
                best = cv::norm(cross);
                direction = cross / cv::norm(cross);
            }
        }
    }
    if(cv::norm(direction) < 0.5)
    {
        return std::nullopt;
    }
    const cv::Vec3d point(location.board_mm.x, location.board_mm.y, 0.0);
    // Outwards: towards the cameras, which all look at the board from the same side
    if(direction.dot(cameraCentre(*views[static_cast<std::size_t>(used.front())].camera) - point) < 0.0)
    {
        direction = -direction;
    }

    DartShape shape;
    shape.direction = direction;
    shape.cameras = static_cast<int>(used.size());
    // Length: the farthest end a camera that sees the whole dart finds along the axis
    for(const int v : used)
    {
        const auto& view = views[static_cast<std::size_t>(v)];
        if(view.observation.cut)
        {
            continue;
        }
        for(const auto& end : view.observation.ends_px)
        {
            shape.total_mm = std::max(shape.total_mm, alongAxis(*view.camera, end, point, direction));
        }
    }
    if(shape.total_mm <= 0.0)
    {
        return std::nullopt;
    }

    // Width along the axis: the largest any camera sees (a flight seen edge-on is thin in one camera only)
    for(int t = 0; t <= static_cast<int>(shape.total_mm); ++t)
    {
        double width = 0.0;
        for(const int v : used)
        {
            width = std::max(width, widthAt(views[static_cast<std::size_t>(v)], point, direction, t).value_or(0.0));
        }
        shape.width_mm.push_back(width);
    }
    // Medians of 5 mm, so that a single wide pixel row (a wire, a crossing shadow) does not cut a part in two
    std::vector<double> w(shape.width_mm.size());
    for(std::size_t i = 0; i < w.size(); ++i)
    {
        std::vector<double> window;
        for(std::size_t j = i >= 2 ? i - 2 : 0; j <= i + 2 && j < w.size(); ++j)
        {
            window.push_back(shape.width_mm[j]);
        }
        std::nth_element(window.begin(), window.begin() + window.size() / 2, window.end());
        w[i] = window[window.size() / 2];
    }
    const int n = static_cast<int>(w.size());
    // Flight: the run of wide values nearest the far end; the very end may fade where the flight's edge meets the board
    std::vector<double> sorted_all(w);
    std::sort(sorted_all.begin(), sorted_all.end());
    const double widest = sorted_all[sorted_all.size() * 19 / 20];
    int flight_end = n - 1;
    while(flight_end > 0 && w[static_cast<std::size_t>(flight_end)] < kFlightShare * widest)
    {
        --flight_end;
    }
    int flight_start = flight_end;
    while(flight_start > 0 && w[static_cast<std::size_t>(flight_start - 1)] >= kFlightShare * widest)
    {
        --flight_start;
    }
    if(flight_start > 0)
    {
        shape.flight_mm = n - flight_start;
    }
    // Barrel: the widest part before the flight; its diameter the upper fifth of the widths there
    std::vector<double> front(w.begin(), w.begin() + std::max(0, flight_start));
    std::vector<double> sorted;
    std::copy_if(front.begin(), front.end(), std::back_inserter(sorted), [] (double v) { return v > 0.0; });
    if(!sorted.empty())
    {
        std::sort(sorted.begin(), sorted.end());
        shape.barrel_diameter_mm = sorted[sorted.size() * 4 / 5];
        const auto widest_front = std::max_element(front.begin(), front.end()) - front.begin();
        int begin = static_cast<int>(widest_front), end = begin;
        while(begin > 0 && front[static_cast<std::size_t>(begin - 1)] >= kBarrelShare * shape.barrel_diameter_mm)
        {
            --begin;
        }
        while(end + 1 < static_cast<int>(front.size()) && front[static_cast<std::size_t>(end + 1)] >= kBarrelShare * shape.barrel_diameter_mm)
        {
            ++end;
        }
        shape.barrel_mm = end - begin + 1;
        shape.point_mm = begin;
    }
    return shape;
}
}  // namespace dartpilot::geometry
