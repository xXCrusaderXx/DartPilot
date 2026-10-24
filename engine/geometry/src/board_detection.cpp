#include "dartpilot/geometry/board_detection.hpp"

#include <algorithm>
#include <cmath>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>

namespace dartpilot::geometry
{
namespace
{
// Midpoint of each edge pair relative to the outer double edge, from the nominal radii (docs/board-coordinates.md)
constexpr double kTripleToDouble = 103.0 / 166.0;
constexpr double kBullLimitToDouble = 0.2;
constexpr int kRays = 720;
constexpr int kTrackSamples = 4000;
// A coloured run shorter than this along a ray is noise, not a ring
constexpr double kMinRun_px = 2.0;
constexpr double kMinSigma_px = 0.3;

struct Masks
{
    cv::Mat red;
    cv::Mat green;
    cv::Mat colour;
    cv::Mat hsv;
    // Colour strength saturation x value, 0..1: high on the red and green rings, low on black, white and the background
    cv::Mat chroma;
};

Masks colourMasks (const cv::Mat& bgr)
{
    Masks masks;
    cv::cvtColor(bgr, masks.hsv, cv::COLOR_BGR2HSV);
    cv::Mat low_red, high_red;
    // OpenCV hue runs from 0 to 180; red wraps around 0. The green of real boards can be very dark, hence the low value.
    cv::inRange(masks.hsv, cv::Scalar(0, 90, 50), cv::Scalar(10, 255, 255), low_red);
    cv::inRange(masks.hsv, cv::Scalar(165, 90, 50), cv::Scalar(180, 255, 255), high_red);
    masks.red = low_red | high_red;
    cv::inRange(masks.hsv, cv::Scalar(45, 80, 14), cv::Scalar(95, 255, 255), masks.green);
    masks.colour = masks.red | masks.green;
    cv::morphologyEx(masks.colour, masks.colour, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_ELLIPSE, {3, 3}));
    std::vector<cv::Mat> channels;
    cv::split(masks.hsv, channels);
    cv::Mat saturation, value;
    channels[1].convertTo(saturation, CV_32F, 1.0 / 255.0);
    channels[2].convertTo(value, CV_32F, 1.0 / 255.0);
    masks.chroma = saturation.mul(value);
    return masks;
}

// The bull is the small red blob ringed by green, the outer bull.
std::optional<cv::Point2f> findBull (const Masks& masks)
{
    std::vector<std::vector<cv::Point>> blobs;
    cv::findContours(masks.red.clone(), blobs, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    std::optional<cv::Point2f> bull;
    double best_share = 0.25;
    for(const auto& blob : blobs)
    {
        const double area = cv::contourArea(blob);
        if(area < 15 || area > 1500)
        {
            continue;
        }
        cv::Mat filled = cv::Mat::zeros(masks.red.size(), CV_8U);
        cv::drawContours(filled, std::vector<std::vector<cv::Point>>{blob}, 0, 255, cv::FILLED);
        const int radius = std::max(3, cvRound(std::sqrt(area / CV_PI)));
        cv::Mat grown;
        cv::dilate(filled, grown, cv::getStructuringElement(cv::MORPH_ELLIPSE, {2 * radius + 1, 2 * radius + 1}));
        const cv::Mat band = grown & ~filled;
        const double share = static_cast<double>(cv::countNonZero(band & masks.green)) / std::max(1, cv::countNonZero(band));
        if(share > best_share)
        {
            const cv::Moments m = cv::moments(blob);
            best_share = share;
            bull = cv::Point2f(static_cast<float>(m.m10 / m.m00), static_cast<float>(m.m01 / m.m00));
        }
    }
    return bull;
}

float sampleBilinear (const cv::Mat& image, const cv::Point2f& p)
{
    const int x0 = static_cast<int>(std::floor(p.x)), y0 = static_cast<int>(std::floor(p.y));
    if(x0 < 0 || y0 < 0 || x0 + 1 >= image.cols || y0 + 1 >= image.rows)
    {
        return 0.0f;
    }
    const float fx = p.x - x0, fy = p.y - y0;
    const float a = image.at<float>(y0, x0), b = image.at<float>(y0, x0 + 1), c = image.at<float>(y0 + 1, x0), d = image.at<float>(y0 + 1, x0 + 1);
    return (1 - fy) * ((1 - fx) * a + fx * b) + fy * ((1 - fx) * c + fx * d);
}

// The colour masks need a low threshold for the dark green of real boards, which widens the rings at blurred edges.
// The edge is refined to where the colour strength crosses half way between the ring and its neighbour.
// inward_is_ring: the ring lies towards the bull from this edge.
double refineEdge (const cv::Mat& chroma, const cv::Point2f& origin, double dx, double dy, double t_coarse, bool inward_is_ring)
{
    const auto at = [&] (double t)
    { return sampleBilinear(chroma, cv::Point2f(static_cast<float>(origin.x + dx * t), static_cast<float>(origin.y + dy * t))); };
    const double ring_side = inward_is_ring ? -1.0 : 1.0;
    float ring_level = 0.0f, other_level = 0.0f;
    for(double o = 2.0; o <= 3.0; o += 0.5)
    {
        ring_level += at(t_coarse + ring_side * o) / 3.0f;
        other_level += at(t_coarse - ring_side * o) / 3.0f;
    }
    if(ring_level - other_level < 0.03f)
    {
        return t_coarse;
    }
    const float middle = 0.5f * (ring_level + other_level);
    // Walk from inside the ring outwards over the edge and interpolate the crossing
    double best = t_coarse;
    double best_distance = 1e9;
    for(double o = -3.0; o < 3.0; o += 0.25)
    {
        const double t0 = t_coarse + ring_side * o, t1 = t_coarse + ring_side * (o + 0.25);
        const float v0 = at(t0), v1 = at(t1);
        if((v0 - middle) * (v1 - middle) <= 0 && v0 != v1)
        {
            const double crossing = t0 + (t1 - t0) * (v0 - middle) / (v0 - v1);
            if(std::abs(crossing - t_coarse) < best_distance)
            {
                best_distance = std::abs(crossing - t_coarse);
                best = crossing;
            }
        }
    }
    return best;
}

// Normalised distance of a point from an ellipse: 0 on it, about (distance / semi-axis) near it
double ellipseOffset (const cv::RotatedRect& e, const cv::Point2f& p)
{
    const double a = e.angle * CV_PI / 180.0, dx = p.x - e.center.x, dy = p.y - e.center.y;
    const double u = (dx * std::cos(a) + dy * std::sin(a)) / (e.size.width / 2);
    const double v = (-dx * std::sin(a) + dy * std::cos(a)) / (e.size.height / 2);
    return std::sqrt(u * u + v * v) - 1.0;
}

// Fits an ellipse, drops points far from it and refits; returns the RMS distance of the kept points in pixels.
std::optional<double> robustEllipse (std::vector<cv::Point2f> points, cv::RotatedRect& ellipse)
{
    for(int pass = 0; pass < 6; ++pass)
    {
        if(points.size() < 20)
        {
            return std::nullopt;
        }
        ellipse = cv::fitEllipse(points);
        std::vector<double> offsets;
        for(const auto& p : points)
        {
            offsets.push_back(std::abs(ellipseOffset(ellipse, p)));
        }
        std::vector<double> sorted = offsets;
        std::nth_element(sorted.begin(), sorted.begin() + sorted.size() / 2, sorted.end());
        const double limit = std::max(0.004, 3.0 * sorted[sorted.size() / 2]);
        std::vector<cv::Point2f> kept;
        for(std::size_t k = 0; k < points.size(); ++k)
        {
            if(offsets[k] < limit)
            {
                kept.push_back(points[k]);
            }
        }
        if(kept.size() == points.size())
        {
            break;
        }
        points.swap(kept);
    }
    const double mean_semi_axis_px = 0.25 * (ellipse.size.width + ellipse.size.height);
    double sum_sq = 0.0;
    for(const auto& p : points)
    {
        const double d_px = ellipseOffset(ellipse, p) * mean_semi_axis_px;
        sum_sq += d_px * d_px;
    }
    return std::sqrt(sum_sq / points.size());
}

cv::Point2f pointOnEllipse (const cv::RotatedRect& e, double t)
{
    const double a = e.angle * CV_PI / 180.0;
    const double x = e.size.width / 2 * std::cos(t), y = e.size.height / 2 * std::sin(t);
    return {static_cast<float>(e.center.x + x * std::cos(a) - y * std::sin(a)), static_cast<float>(e.center.y + x * std::sin(a) + y * std::cos(a))};
}

cv::RotatedRect blend (const cv::RotatedRect& a, const cv::RotatedRect& b, double w)
{
    return cv::RotatedRect(
        (1 - w) * a.center + w * b.center,
        cv::Size2f(static_cast<float>((1 - w) * a.size.width + w * b.size.width), static_cast<float>((1 - w) * a.size.height + w * b.size.height)),
        static_cast<float>((1 - w) * a.angle + w * b.angle));
}

// Points where the colour changes along a closed track: red/green on the ring tracks, bright/dark on the single tracks.
std::vector<cv::Point2f> transitionsAlong (const cv::RotatedRect& track, bool ring, const Masks& masks, const cv::Mat& gray)
{
    std::vector<double> score(kTrackSamples, 0.0);
    for(int k = 0; k < kTrackSamples; ++k)
    {
        const cv::Point2f p = pointOnEllipse(track, 2 * CV_PI * k / kTrackSamples);
        const int x = cvRound(p.x), y = cvRound(p.y);
        if(x < 0 || y < 0 || x >= gray.cols || y >= gray.rows)
        {
            continue;
        }
        if(ring)
        {
            score[k] = masks.red.at<uchar>(y, x) ? 1.0 : masks.green.at<uchar>(y, x) ? -1.0 : 0.0;
        }
        else
        {
            score[k] = gray.at<uchar>(y, x);
        }
    }
    if(!ring)
    {
        // Half way between the dark and the bright sectors
        std::vector<double> sorted = score;
        std::sort(sorted.begin(), sorted.end());
        const double middle = 0.5 * (sorted[kTrackSamples / 10] + sorted[kTrackSamples * 9 / 10]);
        for(auto& value : score)
        {
            value = value > middle ? 1.0 : -1.0;
        }
    }
    // A transition is where the majority of the eight samples before and after flips.
    constexpr int kWindow = 8;
    std::vector<cv::Point2f> found;
    for(int k = 0; k < kTrackSamples; ++k)
    {
        double before = 0.0, after = 0.0;
        for(int j = 1; j <= kWindow; ++j)
        {
            before += score[(k - j + kTrackSamples) % kTrackSamples];
            after += score[(k + j) % kTrackSamples];
        }
        if(before * after < 0 && std::abs(before) > kWindow / 2 && std::abs(after) > kWindow / 2)
        {
            const cv::Point2f p = pointOnEllipse(track, 2 * CV_PI * k / kTrackSamples);
            if(found.empty() || cv::norm(p - found.back()) > 6.0)
            {
                found.push_back(p);
            }
        }
    }
    if(found.size() > 1 && cv::norm(found.front() - found.back()) < 6.0)
    {
        found.pop_back();
    }
    return found;
}

// Where a line from its base point along its direction meets an ellipse, outwards from the base
std::optional<cv::Point2f> lineEllipseIntersection (const cv::Point2f& base, const cv::Point2f& dir, const cv::RotatedRect& e)
{
    const double a = e.angle * CV_PI / 180.0, ca = std::cos(a), sa = std::sin(a);
    const double rx = e.size.width / 2, ry = e.size.height / 2;
    const double px = ((base.x - e.center.x) * ca + (base.y - e.center.y) * sa) / rx;
    const double py = (-(base.x - e.center.x) * sa + (base.y - e.center.y) * ca) / ry;
    const double qx = (dir.x * ca + dir.y * sa) / rx;
    const double qy = (-dir.x * sa + dir.y * ca) / ry;
    const double A = qx * qx + qy * qy, B = 2 * (px * qx + py * qy), C = px * px + py * py - 1;
    const double disc = B * B - 4 * A * C;
    if(disc < 0 || A <= 0)
    {
        return std::nullopt;
    }
    const double t = (-B + std::sqrt(disc)) / (2 * A);
    return base + dir * static_cast<float>(t);
}

double imageAngle (const cv::Point2f& from, const cv::Point2f& to)
{
    // Counter-clockwise as seen on screen, where y points down
    return std::atan2(-(to.y - from.y), to.x - from.x);
}
}  // namespace

std::optional<BoardDetection> detectBoard (const cv::Mat& bgr)
{
    if(bgr.empty() || bgr.type() != CV_8UC3)
    {
        return std::nullopt;
    }
    const Masks masks = colourMasks(bgr);
    const auto bull = findBull(masks);
    if(!bull)
    {
        return std::nullopt;
    }

    // Coloured runs along rays from the bull, assigned to the rings by their radius relative to the outermost run.
    std::array<std::vector<cv::Point2f>, kBoardCircleCount> circle_points;
    for(int r = 0; r < kRays; ++r)
    {
        const double angle = 2 * CV_PI * r / kRays, dx = std::cos(angle), dy = std::sin(angle);
        std::vector<std::pair<double, double>> runs;
        bool inside = false;
        double start = 0.0;
        int gap = 0;
        for(double t = 0; t < 2.0 * std::max(bgr.cols, bgr.rows); t += 0.5)
        {
            const int x = cvRound(bull->x + dx * t), y = cvRound(bull->y + dy * t);
            if(x < 0 || y < 0 || x >= bgr.cols || y >= bgr.rows)
            {
                break;
            }
            const bool coloured = masks.colour.at<uchar>(y, x) != 0;
            if(coloured && !inside)
            {
                inside = true;
                start = t;
                gap = 0;
            }
            else if(!coloured && inside && ++gap > 3)
            {
                inside = false;
                runs.emplace_back(start, t - gap * 0.5);
            }
            else if(coloured)
            {
                gap = 0;
            }
        }
        std::vector<std::pair<double, double>> long_runs;
        for(const auto& run : runs)
        {
            if(run.second - run.first >= kMinRun_px)
            {
                long_runs.push_back(run);
            }
        }
        if(long_runs.size() < 3 || long_runs.front().first > 3.0)
        {
            continue;
        }
        const auto& double_run = long_runs.back();
        const double double_middle = 0.5 * (double_run.first + double_run.second);
        const std::pair<double, double>* triple_run = nullptr;
        double bull_end = -1.0;
        for(const auto& run : long_runs)
        {
            if(&run != &double_run && std::abs(0.5 * (run.first + run.second) / double_middle - kTripleToDouble) < 0.15)
            {
                triple_run = &run;
            }
            if(run.second / double_middle < kBullLimitToDouble)
            {
                bull_end = run.second;
            }
        }
        if(!triple_run || bull_end < 0)
        {
            continue;
        }
        const auto at = [&] (double t) { return cv::Point2f(static_cast<float>(bull->x + dx * t), static_cast<float>(bull->y + dy * t)); };
        const auto refined = [&] (double t, bool inward_is_ring) { return refineEdge(masks.chroma, *bull, dx, dy, t, inward_is_ring); };
        circle_points[0].push_back(at(refined(bull_end, true)));
        // The midpoint of both edges cancels the widening by blur
        circle_points[1].push_back(at(0.5 * (refined(triple_run->first, false) + refined(triple_run->second, true))));
        circle_points[2].push_back(at(0.5 * (refined(double_run.first, false) + refined(double_run.second, true))));
    }

    BoardDetection detection;
    detection.bull_px = *bull;
    std::array<double, kBoardCircleCount> circle_rms_px{};
    for(int k = 0; k < kBoardCircleCount; ++k)
    {
        const auto rms_px = robustEllipse(circle_points[k], detection.circles[k]);
        if(!rms_px)
        {
            return std::nullopt;
        }
        circle_rms_px[k] = *rms_px;
    }

    // Radial wires from the colour changes on four tracks: the inner and outer singles and the two rings. The outer single
    // track finds all 20 most reliably and serves as reference. Every radial wire also runs through the board centre,
    // which the bull marks.
    cv::Mat gray;
    cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(), 1.0);
    const auto& c = detection.circles;
    const std::array<std::vector<cv::Point2f>, 4> transitions = {
        transitionsAlong(blend(c[0], c[1], 0.5), false, masks, gray), transitionsAlong(c[1], true, masks, gray),
        transitionsAlong(blend(c[1], c[2], 0.5), false, masks, gray), transitionsAlong(c[2], true, masks, gray)};
    if(transitions[2].size() != kRadialWireCount)
    {
        return std::nullopt;
    }
    std::vector<std::vector<cv::Point2f>> wire_points;
    for(const auto& reference : transitions[2])
    {
        std::vector<cv::Point2f> points{reference};
        const double reference_angle = imageAngle(*bull, reference);
        for(const int track : {0, 1, 3})
        {
            double best = 0.08;
            std::optional<cv::Point2f> match;
            for(const auto& q : transitions[track])
            {
                const double d = std::abs(std::remainder(imageAngle(*bull, q) - reference_angle, 2 * CV_PI));
                if(d < best)
                {
                    best = d;
                    match = q;
                }
            }
            if(match)
            {
                points.push_back(*match);
            }
        }
        points.push_back(*bull);
        wire_points.push_back(points);
    }
    std::sort(wire_points.begin(), wire_points.end(),
              [&] (const auto& a, const auto& b) { return imageAngle(*bull, a.front()) < imageAngle(*bull, b.front()); });

    for(int w = 0; w < kRadialWireCount; ++w)
    {
        cv::Vec4f line;
        cv::fitLine(wire_points[w], line, cv::DIST_L2, 0, 0.01, 0.01);
        cv::Point2f dir(line[0], line[1]);
        const cv::Point2f base(line[2], line[3]);
        if((wire_points[w].front() - *bull).dot(dir) < 0)
        {
            dir = -dir;
        }
        double sum_sq = 0.0;
        for(const auto& q : wire_points[w])
        {
            const double d = std::abs((q - base).cross(dir));
            sum_sq += d * d;
            detection.worst_wire_residual_px = std::max(detection.worst_wire_residual_px, d);
        }
        const double line_rms_px = std::sqrt(sum_sq / wire_points[w].size());
        // Start on the line at the bull's foot point, so intersections are found outwards from the centre
        const cv::Point2f foot = base + dir * static_cast<float>((*bull - base).dot(dir));
        detection.wires[w] = cv::Vec4f(foot.x, foot.y, dir.x, dir.y);
        for(int k = 0; k < kBoardCircleCount; ++k)
        {
            const auto point = lineEllipseIntersection(foot, dir, detection.circles[k]);
            if(!point)
            {
                return std::nullopt;
            }
            const double sigma_px = std::max(kMinSigma_px, std::hypot(line_rms_px, circle_rms_px[k]));
            detection.points.push_back({w, static_cast<BoardCircle>(k), *point, sigma_px});
        }
    }
    return detection;
}
}  // namespace dartpilot::geometry
