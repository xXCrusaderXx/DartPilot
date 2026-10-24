#include "dartpilot/tip_candidates/dart_observation.hpp"

#include <algorithm>
#include <cmath>
#include <map>

#include <opencv2/imgproc.hpp>

namespace dartpilot::tip_candidates
{
namespace
{
// An object needs this many clearly changed pixels; a dart at the far side of the board still has several hundred.
constexpr int kMinStrongPixels = 150;
// Separate parts of one dart: how far apart they may be, and how clearly a part must stand out to be added
constexpr int kMergeDistance_px = 20;
constexpr int kMinMergedStrongPixels = 15;
constexpr int kMergePasses = 3;
// Thresholds in robust standard deviations of the difference image, with floors for very clean images
constexpr double kStrongSigmas = 8.0;
constexpr double kWeakSigmas = 4.0;
constexpr double kMinStrong = 12.0;
constexpr double kMinWeak = 6.0;
constexpr float kBin_px = 2.0f;
// A cross-section belongs to the axis up to this multiple of the median width: point, barrel and shaft are in, the
// flight, several times wider, is out.
constexpr float kNarrowFactor = 1.6f;
constexpr float kMinNarrow_px = 4.0f;
constexpr std::size_t kMinAxisPoints = 8;
// Pixels this close to an end fix the direction of the line the end is refined along
constexpr float kEndLine_px = 50.0f;
constexpr int kBorder_px = 5;

float median (const cv::Mat& channel)
{
    std::vector<float> values(channel.begin<float>(), channel.end<float>());
    std::nth_element(values.begin(), values.begin() + values.size() / 2, values.end());
    return values[values.size() / 2];
}

float sample (const cv::Mat& image, const cv::Point2f& p)
{
    cv::Mat patch;
    cv::getRectSubPix(image, cv::Size(1, 1), p, patch, CV_32F);
    return patch.at<float>(0, 0);
}

// Least-squares line through the points: centroid and unit direction
std::pair<cv::Point2f, cv::Point2f> fitLine (const std::vector<cv::Point2f>& points)
{
    cv::Point2f mean(0, 0);
    for(const auto& p : points)
    {
        mean += p;
    }
    mean *= 1.0f / static_cast<float>(points.size());
    double sxx = 0, sxy = 0, syy = 0;
    for(const auto& p : points)
    {
        const cv::Point2f q = p - mean;
        sxx += q.x * q.x;
        sxy += q.x * q.y;
        syy += q.y * q.y;
    }
    const double angle = 0.5 * std::atan2(2 * sxy, sxx - syy);
    return {mean, cv::Point2f(static_cast<float>(std::cos(angle)), static_cast<float>(std::sin(angle)))};
}

// Where the difference along a line fades out: the line is followed outwards while the signal stays above the noise,
// bridging gaps of up to a pixel; the end is where the signal falls to half of its level just inside.
cv::Point2f refineEnd (const cv::Mat& difference, const cv::Point2f& end, const cv::Point2f& dir, float noise)
{
    constexpr float kStep = 0.25f;
    const auto at = [&] (float k) { return sample(difference, end + dir * k); };
    std::vector<float> tail;
    for(float k = 5.0f; k <= 40.0f; k += kStep)
    {
        tail.push_back(at(k));
    }
    std::sort(tail.begin(), tail.end());
    const float background = tail[tail.size() / 5];
    const float low = background + std::max(6.0f, 4.0f * noise);
    float run_end = -5.0f, gap = 0.0f;
    for(float k = -5.0f; k <= 40.0f; k += kStep)
    {
        if(at(k) > low)
        {
            run_end = k;
            gap = 0.0f;
        }
        else if((gap += kStep) > 1.0f)
        {
            break;
        }
    }
    std::vector<float> inside;
    for(float k = run_end - 4.0f; k < run_end; k += kStep)
    {
        inside.push_back(at(k));
    }
    std::sort(inside.begin(), inside.end());
    const float half = background + 0.5f * (inside[inside.size() / 2] - background);
    for(float k = run_end; k >= run_end - 6.0f; k -= kStep)
    {
        const float a = at(k);
        if(a >= half)
        {
            const float b = at(k + kStep);
            return end + dir * (k + kStep * (a - half) / std::max(1e-3f, a - b));
        }
    }
    return end + dir * run_end;
}
}  // namespace

std::optional<DartObservation> observeDart (const cv::Mat& image, const cv::Mat& empty_board)
{
    if(image.empty() || image.size() != empty_board.size() || image.channels() != 3 || empty_board.channels() != 3)
    {
        return std::nullopt;
    }
    cv::Mat a, b, diff;
    image.convertTo(a, CV_32FC3);
    empty_board.convertTo(b, CV_32FC3);
    // The automatic exposure may still settle after a hand has left the view, which brightens or darkens the whole
    // image: each channel is scaled to the empty board by the ratio of their medians, which a dart barely moves.
    std::vector<cv::Mat> a_channels, b_channels;
    cv::split(a, a_channels);
    cv::split(b, b_channels);
    for(int c = 0; c < 3; ++c)
    {
        const float a_median = median(a_channels[c]), b_median = median(b_channels[c]);
        if(a_median > 1.0f)
        {
            a_channels[c] *= b_median / a_median;
        }
    }
    cv::merge(a_channels, a);
    cv::absdiff(a, b, diff);
    std::vector<cv::Mat> channels;
    cv::split(diff, channels);
    // The largest change of any colour channel: a red barrel on a green ring changes hue more than brightness.
    cv::Mat d = cv::max(cv::max(channels[0], channels[1]), channels[2]);
    cv::GaussianBlur(d, d, cv::Size(), 0.7);
    // Robust noise level: the median of the difference, as nearly all of the image is unchanged board
    const float noise = 1.4826f * median(d);

    // Hysteresis: the clearly changed part seeds the object, weakly changed parts connected to it (a dark barrel on a
    // dark sector, a steel point on a light one) belong to it as well.
    const cv::Mat strong = d > std::max(kMinStrong, kStrongSigmas * noise);
    const cv::Mat weak = d > std::max(kMinWeak, kWeakSigmas * noise);
    cv::Mat labels;
    const int count = cv::connectedComponents(weak, labels, 8, CV_32S);
    std::vector<int> strong_pixels(count, 0);
    for(int y = 0; y < labels.rows; ++y)
    {
        for(int x = 0; x < labels.cols; ++x)
        {
            if(strong.at<uchar>(y, x))
            {
                ++strong_pixels[labels.at<int>(y, x)];
            }
        }
    }
    if(count < 2)
    {
        return std::nullopt;
    }
    const int object = static_cast<int>(std::max_element(strong_pixels.begin() + 1, strong_pixels.end()) - strong_pixels.begin());
    if(strong_pixels[object] < kMinStrongPixels)
    {
        return std::nullopt;
    }

    // Parts of a dart can be separated by a part that hardly differs from the board behind it, such as a shaft of the
    // board's colour: clearly changed parts close to the object belong to it.
    std::vector<bool> member(count, false);
    member[object] = true;
    for(int pass = 0; pass < kMergePasses; ++pass)
    {
        cv::Mat current(labels.size(), CV_8U, cv::Scalar(0));
        for(int y = 0; y < labels.rows; ++y)
        {
            for(int x = 0; x < labels.cols; ++x)
            {
                current.at<uchar>(y, x) = member[labels.at<int>(y, x)] ? 255 : 0;
            }
        }
        cv::dilate(current, current, cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(2 * kMergeDistance_px + 1, 2 * kMergeDistance_px + 1)));
        bool grew = false;
        for(int y = 0; y < labels.rows; ++y)
        {
            for(int x = 0; x < labels.cols; ++x)
            {
                const int label = labels.at<int>(y, x);
                if(label > 0 && !member[label] && current.at<uchar>(y, x) && strong_pixels[label] >= kMinMergedStrongPixels)
                {
                    member[label] = true;
                    grew = true;
                }
            }
        }
        if(!grew)
        {
            break;
        }
    }

    DartObservation observation;
    std::vector<cv::Point2f> pixels;
    for(int y = 0; y < labels.rows; ++y)
    {
        for(int x = 0; x < labels.cols; ++x)
        {
            if(member[labels.at<int>(y, x)])
            {
                pixels.emplace_back(static_cast<float>(x), static_cast<float>(y));
                observation.cut = observation.cut || x <= 1 || y <= 1 || x >= labels.cols - 2 || y >= labels.rows - 2;
            }
        }
    }
    observation.area_px = static_cast<int>(pixels.size());

    // Cross-sections along the main axis: their middles are the centre line, their widths tell the flight apart.
    const auto [centre, axis] = fitLine(pixels);
    const cv::Point2f normal(-axis.y, axis.x);
    std::map<int, std::pair<float, float>> sections;
    float s_min = 1e9f, s_max = -1e9f;
    for(const auto& p : pixels)
    {
        const cv::Point2f q = p - centre;
        const float s = q.dot(axis), t = q.dot(normal);
        s_min = std::min(s_min, s);
        s_max = std::max(s_max, s);
        const int bin = static_cast<int>(std::floor(s / kBin_px));
        const auto it = sections.find(bin);
        if(it == sections.end())
        {
            sections[bin] = {t, t};
        }
        else
        {
            it->second.first = std::min(it->second.first, t);
            it->second.second = std::max(it->second.second, t);
        }
    }
    std::vector<float> widths;
    for(const auto& [bin, range] : sections)
    {
        widths.push_back(range.second - range.first + 1.0f);
    }
    std::nth_element(widths.begin(), widths.begin() + widths.size() / 2, widths.end());
    const float narrow = std::max(kMinNarrow_px, kNarrowFactor * widths[widths.size() / 2]);
    for(const auto& [bin, range] : sections)
    {
        if(range.second - range.first + 1.0f <= narrow)
        {
            observation.axis_px.push_back(centre + axis * (kBin_px * bin + 0.5f * kBin_px) + normal * (0.5f * (range.first + range.second)));
        }
    }
    if(observation.axis_px.size() < kMinAxisPoints)
    {
        return std::nullopt;
    }
    observation.axis_length_px = cv::norm(observation.axis_px.front() - observation.axis_px.back());

    for(const float side : {-1.0f, 1.0f})
    {
        const float end_s = side < 0 ? s_min : s_max;
        std::vector<cv::Point2f> near_end;
        for(const auto& p : pixels)
        {
            if(std::abs((p - centre).dot(axis) - end_s) < kEndLine_px)
            {
                near_end.push_back(p);
            }
        }
        if(near_end.size() < 5)
        {
            continue;
        }
        auto [base, dir] = fitLine(near_end);
        if(dir.dot(axis * side) < 0)
        {
            dir = -dir;
        }
        float reach = -1e9f;
        for(const auto& p : near_end)
        {
            reach = std::max(reach, (p - base).dot(dir));
        }
        const cv::Point2f end = base + dir * reach;
        if(end.x < kBorder_px || end.y < kBorder_px || end.x > d.cols - 1 - kBorder_px || end.y > d.rows - 1 - kBorder_px)
        {
            continue;
        }
        observation.ends_px.push_back(refineEnd(d, end, dir, noise));
    }
    return observation;
}
}  // namespace dartpilot::tip_candidates
