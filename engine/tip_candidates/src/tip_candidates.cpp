#include "dartpilot/tip_candidates/tip_candidates.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>

#include <opencv2/imgproc.hpp>

namespace dartpilot::tip_candidates
{
namespace
{
// One pass of the thinning of Zhang and Suen (1984) over a 0/1 image with a zero border; true if it removed a pixel
bool thinningPass (cv::Mat& image, int pass)
{
    cv::Mat remove = cv::Mat::zeros(image.size(), CV_8U);
    bool removed = false;
    for(int y = 1; y < image.rows - 1; ++y)
    {
        for(int x = 1; x < image.cols - 1; ++x)
        {
            if(image.at<std::uint8_t>(y, x) == 0)
            {
                continue;
            }
            // Neighbours clockwise from the top
            const std::uint8_t p[8] = {image.at<std::uint8_t>(y - 1, x), image.at<std::uint8_t>(y - 1, x + 1),
                                       image.at<std::uint8_t>(y, x + 1), image.at<std::uint8_t>(y + 1, x + 1),
                                       image.at<std::uint8_t>(y + 1, x), image.at<std::uint8_t>(y + 1, x - 1),
                                       image.at<std::uint8_t>(y, x - 1), image.at<std::uint8_t>(y - 1, x - 1)};
            int neighbours = 0;
            int transitions = 0;
            for(int i = 0; i < 8; ++i)
            {
                neighbours += p[i];
                transitions += p[i] == 0 && p[(i + 1) % 8] == 1 ? 1 : 0;
            }
            const bool first = pass == 0 ? p[0] * p[2] * p[4] == 0 && p[2] * p[4] * p[6] == 0 : p[0] * p[2] * p[6] == 0 && p[0] * p[4] * p[6] == 0;
            if(neighbours >= 2 && neighbours <= 6 && transitions == 1 && first)
            {
                remove.at<std::uint8_t>(y, x) = 1;
                removed = true;
            }
        }
    }
    image.setTo(0, remove);
    return removed;
}

// The skeleton of an 8-bit mask, as 0/1 in a copy padded by one pixel
cv::Mat skeleton (const cv::Mat& mask)
{
    cv::Mat image;
    cv::copyMakeBorder(mask, image, 1, 1, 1, 1, cv::BORDER_CONSTANT, 0);
    image = image != 0;
    image /= 255;
    while(thinningPass(image, 0) | thinningPass(image, 1))
    {
    }
    return image;
}

// Uncertainty and confidence of each candidate from the candidates at the same end of the dart: where the generators
// agree, the end is clear; where they spread along the axis, its fading point leaves the tip open. Across the axis,
// the scatter of the axis points adds, as the axis itself carries that much error.
void rateCandidates (std::vector<TipCandidate>& candidates, const DartObservation& observation)
{
    constexpr double kFloorPx = 0.5;
    // An uncertainty of this many pixels (square root of the trace, before the calibration below) halves the confidence.
    constexpr double kHalfConfidencePx = 4.0;
    // The spread of the candidates understates how far the tip may lie: against the located point of throws seen by
    // three cameras, errors fall within the stated ellipses as often as a normal error would only with twice the
    // variance (measured on the development sessions of the 2026-10-25 dataset, checked on its test session; #28).
    constexpr double kVarianceScale = 2.0;
    const cv::Point2f origin = observation.axis_px.front();
    cv::Point2f direction = observation.axis_px.back() - origin;
    direction *= static_cast<float>(1.0 / cv::norm(direction));
    const cv::Point2f middle = 0.5f * (observation.axis_px.front() + observation.axis_px.back());
    double across_sum = 0.0;
    for(const auto& p : observation.axis_px)
    {
        const double off = (p - origin).cross(direction);
        across_sum += off * off;
    }
    const double across_px2 = across_sum / static_cast<double>(observation.axis_px.size());
    for(int side = 0; side < 2; ++side)
    {
        std::vector<std::size_t> members;
        for(std::size_t i = 0; i < candidates.size(); ++i)
        {
            if(((candidates[i].pixel_px - middle).dot(direction) > 0.0f) == (side == 0))
            {
                members.push_back(i);
            }
        }
        if(members.empty())
        {
            continue;
        }
        cv::Point2d mean(0.0, 0.0);
        for(const auto i : members)
        {
            mean += cv::Point2d(candidates[i].pixel_px);
        }
        mean *= 1.0 / static_cast<double>(members.size());
        cv::Matx22d spread = cv::Matx22d::zeros();
        for(const auto i : members)
        {
            const cv::Vec2d d(candidates[i].pixel_px.x - mean.x, candidates[i].pixel_px.y - mean.y);
            spread += d * d.t();
        }
        spread *= 1.0 / static_cast<double>(members.size());
        const cv::Vec2d across(-direction.y, direction.x);
        cv::Matx22d covariance = spread + (across * across.t()) * across_px2 + cv::Matx22d::eye() * (kFloorPx * kFloorPx);
        const double size_px = std::sqrt(covariance(0, 0) + covariance(1, 1));
        const float confidence = static_cast<float>(1.0 / (1.0 + size_px / kHalfConfidencePx));
        for(const auto i : members)
        {
            candidates[i].covariance_px2 = cv::Matx22f(covariance * kVarianceScale);
            candidates[i].confidence = confidence;
        }
    }
}

bool nearBorder (const cv::Point2f& p, const cv::Size& size, int border_px)
{
    return p.x < border_px || p.y < border_px || p.x > size.width - 1 - border_px || p.y > size.height - 1 - border_px;
}
}  // namespace

std::string_view moduleName () { return "tip_candidates"; }

std::optional<cv::Point2f> extremePoint (const cv::Mat& mask, const cv::Point2f& direction)
{
    std::optional<cv::Point2f> best;
    double best_projection = 0.0;
    for(int y = 0; y < mask.rows; ++y)
    {
        const auto* row = mask.ptr<std::uint8_t>(y);
        for(int x = 0; x < mask.cols; ++x)
        {
            if(row[x] == 0)
            {
                continue;
            }
            const double projection = static_cast<double>(direction.x) * x + static_cast<double>(direction.y) * y;
            if(!best || projection > best_projection)
            {
                best = cv::Point2f(static_cast<float>(x), static_cast<float>(y));
                best_projection = projection;
            }
        }
    }
    return best;
}
const char* sourceName (CandidateSource source)
{
    switch(source)
    {
        case CandidateSource::AxisEnd:
            return "axis_end";
        case CandidateSource::ContourEnd:
            return "contour_end";
        case CandidateSource::SkeletonEnd:
            break;
    }
    return "skeleton_end";
}

std::vector<TipCandidate> tipCandidates (const DartObservation& observation, int border_px)
{
    std::vector<TipCandidate> candidates;
    if(observation.axis_px.size() < 2 || observation.mask.empty())
    {
        return candidates;
    }
    const cv::Size size = observation.mask.size();
    const cv::Point2f origin = observation.axis_px.front();
    cv::Point2f direction = observation.axis_px.back() - origin;
    const double length = std::hypot(direction.x, direction.y);
    if(length <= 0.0)
    {
        return candidates;
    }
    direction *= static_cast<float>(1.0 / length);
    const auto add = [&] (const cv::Point2f& p, CandidateSource source)
    {
        if(!nearBorder(p, size, border_px))
        {
            candidates.push_back({p, source});
        }
    };

    for(const auto& end : observation.ends_px)
    {
        add(end, CandidateSource::AxisEnd);
    }

    // The mask pixels furthest along the axis either way, and the skeleton's end points furthest either way
    std::vector<cv::Point> pixels;
    cv::findNonZero(observation.mask, pixels);
    if(pixels.empty())
    {
        return candidates;
    }
    cv::Point low = pixels.front(), high = pixels.front();
    for(const auto& p : pixels)
    {
        low = {std::min(low.x, p.x), std::min(low.y, p.y)};
        high = {std::max(high.x, p.x), std::max(high.y, p.y)};
    }
    const cv::Rect box(low, high + cv::Point(1, 1));
    const cv::Mat roi = observation.mask(box);
    std::optional<cv::Point2f> contour[2];
    double contour_t[2] = {0.0, 0.0};
    for(int y = 0; y < roi.rows; ++y)
    {
        const auto* row = roi.ptr<std::uint8_t>(y);
        for(int x = 0; x < roi.cols; ++x)
        {
            if(row[x] == 0)
            {
                continue;
            }
            const cv::Point2f p(static_cast<float>(x + box.x), static_cast<float>(y + box.y));
            const double t = (p - origin).dot(direction);
            for(int side = 0; side < 2; ++side)
            {
                const double along = side == 0 ? t : -t;
                if(!contour[side] || along > contour_t[side])
                {
                    contour[side] = p;
                    contour_t[side] = along;
                }
            }
        }
    }
    for(const auto& p : contour)
    {
        if(p)
        {
            add(*p, CandidateSource::ContourEnd);
        }
    }

    const cv::Mat bones = skeleton(roi);
    std::optional<cv::Point2f> bone_end[2];
    double bone_t[2] = {0.0, 0.0};
    for(int y = 1; y < bones.rows - 1; ++y)
    {
        for(int x = 1; x < bones.cols - 1; ++x)
        {
            if(bones.at<std::uint8_t>(y, x) == 0)
            {
                continue;
            }
            const int neighbours = cv::countNonZero(bones(cv::Rect(x - 1, y - 1, 3, 3))) - 1;
            if(neighbours != 1)
            {
                continue;
            }
            const cv::Point2f p(static_cast<float>(x - 1 + box.x), static_cast<float>(y - 1 + box.y));
            const double t = (p - origin).dot(direction);
            for(int side = 0; side < 2; ++side)
            {
                const double along = side == 0 ? t : -t;
                if(!bone_end[side] || along > bone_t[side])
                {
                    bone_end[side] = p;
                    bone_t[side] = along;
                }
            }
        }
    }
    for(const auto& p : bone_end)
    {
        if(p)
        {
            add(*p, CandidateSource::SkeletonEnd);
        }
    }
    rateCandidates(candidates, observation);
    return candidates;
}
}  // namespace dartpilot::tip_candidates
