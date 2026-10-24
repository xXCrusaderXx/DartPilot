#include "dartpilot/tip_candidates/dart_observation.hpp"

#include <algorithm>
#include <cmath>
#include <map>
#include <tuple>

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
// The largest shift between image and empty board that is taken for a drifting camera and compensated
constexpr double kMaxDrift_px = 5.0;
// The alignment measures the shift in a grid of tiles and fits an affine motion to them, as a camera warming up after
// its start zooms a little (about 0.15 %, a pixel at the image border) besides shifting. Tiles that disagree with the
// fit by more than kTileOutlier_px (a dart) are dropped, and plain tiles, whose shift is undetermined, are not measured; with fewer than kMinTiles
// left, or a zoom or rotation beyond kMaxLinear, only the shift of the whole image is compensated. So is a zoom or rotation that moves no image
// corner by more than kMinLinear_px, which would only fit the noise of the tiles.
constexpr int kTilesX = 8;
constexpr int kTilesY = 5;
constexpr int kMinTiles = 12;
constexpr double kMinTileResponse = 0.1;
constexpr double kMinTileContrast = 5.0;
constexpr double kTileOutlier_px = 0.4;
constexpr double kMaxLinear = 0.01;
constexpr double kMinLinear_px = 0.3;
// A level counts for the tone curve with this many pixels; the curve needs the middle 96 % of the pixels to span this
// many levels (a scene of one colour with a small dart does not, so the dart cannot bend the curve onto the
// background), and drops levels further than kToneOutlier from it.
constexpr int kMinTonePixels = 50;
constexpr int kMinToneRange = 60;
constexpr double kToneOutlier = 12.0;
// Closing bridges gaps up to about this size inside the object, such as between the edges of a plain barrel.
constexpr int kClose_px = 9;
// Middles within this distance of a line are on the axis; the axis spans at least this length.
constexpr float kAxisTolerance_px = 1.5f;
constexpr float kMinAxisSpan_px = 30.0f;
// Provisional, from the reference setup (cameras about 45 cm from the board): whole darts measured 146 px or more, the
// changes of the board that looked like objects 90 px or less (#121).
constexpr double kMinWholeDart_px = 100.0;
// Half width of the band in which an end is followed, and how far beyond the last axis point
constexpr float kBand_px = 2.0f;
constexpr float kMaxReach_px = 120.0f;
constexpr std::size_t kMinAxisPoints = 8;
constexpr int kBorder_px = 5;

// cv::phaseCorrelate multiplies its inputs by the window in place, so it gets copies.
cv::Point2d shiftBetween (const cv::Mat& from, const cv::Mat& to, const cv::Mat& window, double* response = nullptr)
{
    return cv::phaseCorrelate(from.clone(), to.clone(), window, response);
}

// The motion of the empty board onto the image: for a point of the board, where it is in the image
cv::Matx23d alignment (const cv::Mat& board_gray, const cv::Mat& image_gray)
{
    cv::Mat window;
    cv::createHanningWindow(window, image_gray.size(), CV_32F);
    const cv::Point2d whole = shiftBetween(board_gray, image_gray, window);
    cv::Matx23d motion(1, 0, whole.x, 0, 1, whole.y);
    if(std::hypot(whole.x, whole.y) > kMaxDrift_px)
    {
        return cv::Matx23d(1, 0, 0, 0, 1, 0);
    }
    const int tile_w = image_gray.cols / kTilesX, tile_h = image_gray.rows / kTilesY;
    cv::Mat tile_window;
    cv::createHanningWindow(tile_window, cv::Size(tile_w, tile_h), CV_32F);
    std::vector<cv::Point2d> centres, shifts;
    for(int ty = 0; ty < kTilesY; ++ty)
    {
        for(int tx = 0; tx < kTilesX; ++tx)
        {
            const cv::Rect tile(tx * tile_w, ty * tile_h, tile_w, tile_h);
            cv::Scalar mean, deviation;
            cv::meanStdDev(board_gray(tile), mean, deviation);
            if(deviation[0] < kMinTileContrast)
            {
                continue;
            }
            double response = 0.0;
            const cv::Point2d shift = shiftBetween(board_gray(tile), image_gray(tile), tile_window, &response);
            if(response >= kMinTileResponse && std::hypot(shift.x - whole.x, shift.y - whole.y) <= kMaxDrift_px)
            {
                centres.emplace_back(tile.x + 0.5 * tile_w, tile.y + 0.5 * tile_h);
                shifts.push_back(shift);
            }
        }
    }
    // Shift = offset + linear part times the centre, fitted by least squares; the worst tile off the fit is dropped
    // until all agree.
    std::vector<bool> used(centres.size(), true);
    while(true)
    {
        const auto count = static_cast<int>(std::count(used.begin(), used.end(), true));
        if(count < kMinTiles)
        {
            return motion;
        }
        cv::Mat a(count, 3, CV_64F), bx(count, 1, CV_64F), by(count, 1, CV_64F);
        for(std::size_t i = 0, row = 0; i < centres.size(); ++i)
        {
            if(used[i])
            {
                a.at<double>(row, 0) = 1.0;
                a.at<double>(row, 1) = centres[i].x;
                a.at<double>(row, 2) = centres[i].y;
                bx.at<double>(row) = shifts[i].x;
                by.at<double>(row) = shifts[i].y;
                ++row;
            }
        }
        cv::Mat px, py;
        if(!cv::solve(a, bx, px, cv::DECOMP_SVD) || !cv::solve(a, by, py, cv::DECOMP_SVD))
        {
            return motion;
        }
        double worst = 0.0;
        std::size_t worst_index = 0;
        for(std::size_t i = 0; i < centres.size(); ++i)
        {
            if(!used[i])
            {
                continue;
            }
            const double fx = px.at<double>(0) + px.at<double>(1) * centres[i].x + px.at<double>(2) * centres[i].y;
            const double fy = py.at<double>(0) + py.at<double>(1) * centres[i].x + py.at<double>(2) * centres[i].y;
            const double off = std::hypot(shifts[i].x - fx, shifts[i].y - fy);
            if(off > worst)
            {
                worst = off;
                worst_index = i;
            }
        }
        if(worst > kTileOutlier_px)
        {
            used[worst_index] = false;
            continue;
        }
        const cv::Matx22d linear(px.at<double>(1), px.at<double>(2), py.at<double>(1), py.at<double>(2));
        const cv::Vec2d half(0.5 * image_gray.cols, 0.5 * image_gray.rows);
        const double corner_px = std::max(cv::norm(linear * half), cv::norm(linear * cv::Vec2d(half[0], -half[1])));
        if(std::max({std::abs(linear(0, 0)), std::abs(linear(0, 1)), std::abs(linear(1, 0)), std::abs(linear(1, 1))}) > kMaxLinear ||
           corner_px <= kMinLinear_px)
        {
            return motion;
        }
        return cv::Matx23d(1.0 + px.at<double>(1), px.at<double>(2), px.at<double>(0), py.at<double>(1), 1.0 + py.at<double>(2), py.at<double>(0));
    }
}

float median (const cv::Mat& channel)
{
    std::vector<float> values(channel.begin<float>(), channel.end<float>());
    std::nth_element(values.begin(), values.begin() + values.size() / 2, values.end());
    return values[values.size() / 2];
}

// The tone curve from one channel onto another of the same scene, applied to the first. For every level of the first,
// the median of the other channel's values at the same pixels; a parabola is fitted to these medians, weighted by how
// many pixels each level has, and levels far off it are dropped and the parabola fitted again. Levels that only a dart
// has are few pixels and lie off the curve of the board, so they cannot pull the dart onto the board's colour. Without
// enough contrast in the scene the curve is undetermined, and the channel is left as it is.
cv::Mat matchTones (const cv::Mat& from, const cv::Mat& to)
{
    constexpr int kLevels = 256;
    std::vector<std::vector<int>> histogram(kLevels, std::vector<int>(kLevels, 0));
    std::vector<int> counts(kLevels, 0);
    for(int y = 0; y < from.rows; ++y)
    {
        const float* f = from.ptr<float>(y);
        const float* t = to.ptr<float>(y);
        for(int x = 0; x < from.cols; ++x)
        {
            const int level = std::clamp(static_cast<int>(std::lround(f[x])), 0, kLevels - 1);
            ++histogram[level][std::clamp(static_cast<int>(std::lround(t[x])), 0, kLevels - 1)];
            ++counts[level];
        }
    }
    const int total = from.rows * from.cols;
    int seen = 0, low = -1, high = -1;
    for(int level = 0; level < kLevels; ++level)
    {
        seen += counts[level];
        if(low < 0 && seen >= total / 50)
        {
            low = level;
        }
        if(high < 0 && seen >= total - total / 50)
        {
            high = level;
        }
    }
    if(high - low < kMinToneRange)
    {
        return from.clone();
    }

    std::vector<double> levels, medians, weights;
    for(int level = 0; level < kLevels; ++level)
    {
        if(counts[level] < kMinTonePixels)
        {
            continue;
        }
        int below = 0;
        for(int value = 0; value < kLevels; ++value)
        {
            below += histogram[level][value];
            if(2 * below >= counts[level])
            {
                levels.push_back(level);
                medians.push_back(value);
                weights.push_back(counts[level]);
                break;
            }
        }
    }
    cv::Vec3d curve(0.0, 1.0, 0.0);
    std::vector<bool> used(levels.size(), true);
    for(int pass = 0; pass < 2; ++pass)
    {
        cv::Matx33d normal = cv::Matx33d::zeros();
        cv::Vec3d right(0, 0, 0);
        for(std::size_t i = 0; i < levels.size(); ++i)
        {
            if(!used[i])
            {
                continue;
            }
            const cv::Vec3d row(1.0, levels[i], levels[i] * levels[i]);
            normal += weights[i] * row * row.t();
            right += weights[i] * medians[i] * row;
        }
        if(cv::determinant(normal) <= 0.0)
        {
            return from.clone();
        }
        curve = normal.inv() * right;
        for(std::size_t i = 0; i < levels.size(); ++i)
        {
            used[i] = std::abs(curve[0] + curve[1] * levels[i] + curve[2] * levels[i] * levels[i] - medians[i]) <= kToneOutlier;
        }
    }
    cv::Mat mapped(from.size(), CV_32F);
    for(int y = 0; y < from.rows; ++y)
    {
        const float* f = from.ptr<float>(y);
        float* m = mapped.ptr<float>(y);
        for(int x = 0; x < from.cols; ++x)
        {
            m[x] = static_cast<float>(curve[0] + curve[1] * f[x] + curve[2] * f[x] * f[x]);
        }
    }
    return mapped;
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

// Where the object ends along a line: the line is followed outwards while the difference stays above the noise,
// bridging gaps of up to a pixel; the end is where it falls to half of its level just inside. The difference is taken
// as the largest within a narrow band across the line, so a point slightly off the fitted axis is still followed.
cv::Point2f refineEnd (const cv::Mat& difference, const cv::Point2f& start, const cv::Point2f& dir, const cv::Point2f& normal, float noise)
{
    constexpr float kStep = 0.25f;
    const auto at = [&] (float k)
    {
        float strongest = 0.0f;
        for(float t = -kBand_px; t <= kBand_px; t += 0.5f)
        {
            strongest = std::max(strongest, sample(difference, start + dir * k + normal * t));
        }
        return strongest;
    };
    // The object is followed for at most kMaxReach_px beyond the last axis point; the background is measured past it.
    std::vector<float> profile;
    for(float k = 0.0f; k <= kMaxReach_px + 30.0f; k += kStep)
    {
        profile.push_back(at(k));
    }
    const auto value = [&] (float k) { return profile[std::min(profile.size() - 1, static_cast<std::size_t>(std::max(0.0f, k) / kStep))]; };
    float run_end = 0.0f, gap = 0.0f;
    for(float k = 0.0f; k <= kMaxReach_px; k += kStep)
    {
        // The background just beyond: the low end of the next 30 px
        std::vector<float> ahead;
        for(float a = k + 5.0f; a <= k + 30.0f; a += 1.0f)
        {
            ahead.push_back(value(a));
        }
        std::nth_element(ahead.begin(), ahead.begin() + ahead.size() / 5, ahead.end());
        const float low = ahead[ahead.size() / 5] + std::max(6.0f, 4.0f * noise);
        if(value(k) > low)
        {
            run_end = k;
            gap = 0.0f;
        }
        else if((gap += kStep) > 1.0f)
        {
            break;
        }
    }
    std::vector<float> ahead;
    for(float a = run_end + 5.0f; a <= run_end + 30.0f; a += 1.0f)
    {
        ahead.push_back(value(a));
    }
    std::nth_element(ahead.begin(), ahead.begin() + ahead.size() / 5, ahead.end());
    const float background = ahead[ahead.size() / 5];
    std::vector<float> inside;
    for(float k = std::max(0.0f, run_end - 4.0f); k <= run_end; k += kStep)
    {
        inside.push_back(value(k));
    }
    std::nth_element(inside.begin(), inside.begin() + inside.size() / 2, inside.end());
    const float half = background + 0.5f * (inside[inside.size() / 2] - background);
    for(float k = run_end; k >= std::max(0.0f, run_end - 6.0f); k -= kStep)
    {
        const float a = value(k), b = value(k + kStep);
        if(a >= half)
        {
            return start + dir * (k + kStep * (a - half) / std::max(1e-3f, a - b));
        }
    }
    return start + dir * run_end;
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
    // A camera that warms up after starting or whose mount gives a little shifts and zooms its image by a fraction of a
    // pixel to a pixel; against an older reference every edge of the board would then stand out. The reference is moved
    // onto the image by the motion measured between the two, if it is small enough to be such a drift.
    cv::Mat a_gray, b_gray;
    cv::cvtColor(a, a_gray, cv::COLOR_BGR2GRAY);
    cv::cvtColor(b, b_gray, cv::COLOR_BGR2GRAY);
    cv::warpAffine(b, b, alignment(b_gray, a_gray), b.size(), cv::INTER_LINEAR, cv::BORDER_REPLICATE);
    // The automatic exposure may still settle after a hand has left the view. It does not scale the image evenly: light
    // and dark sectors change by different amounts. Each channel is therefore mapped onto the empty board by a tone
    // curve: for every level of the image, the median level the same pixels have on the empty board. A dart covers too
    // little of the image to move these medians.
    std::vector<cv::Mat> a_channels, b_channels;
    cv::split(a, a_channels);
    cv::split(b, b_channels);
    for(int c = 0; c < 3; ++c)
    {
        a_channels[c] = matchTones(a_channels[c], b_channels[c]);
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

    // The object as one area: closing bridges the gap between the two edges of a barrel that matches the board behind
    // it, so that its cross-sections are whole and their middles lie on the axis.
    cv::Mat area(labels.size(), CV_8U, cv::Scalar(0));
    for(int y = 0; y < labels.rows; ++y)
    {
        for(int x = 0; x < labels.cols; ++x)
        {
            area.at<uchar>(y, x) = member[labels.at<int>(y, x)] ? 255 : 0;
        }
    }
    cv::morphologyEx(area, area, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(kClose_px, kClose_px)));

    DartObservation observation;
    std::vector<cv::Point2f> pixels;
    for(int y = 0; y < area.rows; ++y)
    {
        for(int x = 0; x < area.cols; ++x)
        {
            if(area.at<uchar>(y, x))
            {
                pixels.emplace_back(static_cast<float>(x), static_cast<float>(y));
                observation.cut = observation.cut || x <= 1 || y <= 1 || x >= area.cols - 2 || y >= area.rows - 2;
            }
        }
    }
    observation.area_px = static_cast<int>(pixels.size());

    // Middles of the cross-sections along the main direction of the object
    const auto [centre, main] = fitLine(pixels);
    const cv::Point2f across(-main.y, main.x);
    std::map<int, std::pair<float, float>> sections;
    for(const auto& p : pixels)
    {
        const cv::Point2f q = p - centre;
        const int bin = static_cast<int>(std::floor(q.dot(main) / kBin_px));
        const float t = q.dot(across);
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
    std::vector<cv::Point2f> middles;
    for(const auto& [bin, range] : sections)
    {
        middles.push_back(centre + main * (kBin_px * bin + 0.5f * kBin_px) + across * (0.5f * (range.first + range.second)));
    }
    if(middles.size() < kMinAxisPoints)
    {
        return std::nullopt;
    }

    // The axis is the straight line through most middles: point, barrel and shaft lie on it, while the middles of a
    // flight seen at an angle, of a ragged outline or of a stray piece do not. Every pair of middles is tried, so the
    // result does not depend on chance.
    const auto inliersOf = [&] (const cv::Point2f& base, const cv::Point2f& dir)
    {
        std::vector<cv::Point2f> inliers;
        for(const auto& m : middles)
        {
            if(std::abs((m - base).cross(dir)) <= kAxisTolerance_px)
            {
                inliers.push_back(m);
            }
        }
        return inliers;
    };
    std::vector<cv::Point2f> best;
    const std::size_t stride = std::max<std::size_t>(1, middles.size() / 80);
    for(std::size_t i = 0; i < middles.size(); i += stride)
    {
        for(std::size_t j = i + stride; j < middles.size(); j += stride)
        {
            const cv::Point2f span = middles[j] - middles[i];
            const float length = std::hypot(span.x, span.y);
            if(length < kMinAxisSpan_px)
            {
                continue;
            }
            auto inliers = inliersOf(middles[i], span / length);
            if(inliers.size() > best.size())
            {
                best = std::move(inliers);
            }
        }
    }
    if(best.size() < kMinAxisPoints)
    {
        return std::nullopt;
    }
    auto [base, dir] = fitLine(best);
    best = inliersOf(base, dir);
    std::tie(base, dir) = fitLine(best);
    std::sort(best.begin(), best.end(), [&] (const cv::Point2f& a, const cv::Point2f& b) { return (a - base).dot(dir) < (b - base).dot(dir); });
    observation.axis_px = best;
    observation.axis_length_px = cv::norm(best.front() - best.back());
    // A dart seen whole is long; short changes of the board itself (a fibre pushed out by a dart, a slight change of
    // focus) are not taken for one. A dart cut off by the image border may show only part of its length.
    if(observation.axis_length_px < kMinAxisSpan_px || (!observation.cut && observation.axis_length_px < kMinWholeDart_px))
    {
        return std::nullopt;
    }

    // Both ends along the axis itself: from the outermost middle on the axis outwards, in a narrow band around the line,
    // as long as the object goes on. The point continues the axis even where it is too thin or too faint for the mask.
    const cv::Point2f normal(-dir.y, dir.x);
    for(const float side : {-1.0f, 1.0f})
    {
        const cv::Point2f outward = dir * side;
        const cv::Point2f start = side < 0 ? best.front() : best.back();
        const cv::Point2f end = refineEnd(d, start, outward, normal, noise);
        if(end.x < kBorder_px || end.y < kBorder_px || end.x > d.cols - 1 - kBorder_px || end.y > d.rows - 1 - kBorder_px)
        {
            continue;
        }
        observation.ends_px.push_back(end);
    }
    return observation;
}
namespace
{
// A knocked camera changes its whole view: it shifts, tilts a little or sways and comes back. Measured on the reference
// setup, a dart changed at most 10 of the 8x8 cells of the image (after aligning the shift of the whole image), a
// knocked camera 23 to 59; and a shift beyond kMovedCamera_px that explains most of the difference is a moved camera
// as well.
constexpr int kCells = 8;
constexpr double kChangedLevel = 25.0;
constexpr double kChangedCellShare = 0.002;
constexpr int kMaxCellsForADart = 16;
constexpr double kMovedCamera_px = 3.0;
constexpr double kExplainedShare = 0.5;

}  // namespace

std::optional<cv::Point2d> viewChange (const cv::Mat& before, const cv::Mat& after)
{
    cv::Mat a, b;
    cv::cvtColor(before, a, cv::COLOR_BGR2GRAY);
    cv::cvtColor(after, b, cv::COLOR_BGR2GRAY);
    a.convertTo(a, CV_32F);
    b.convertTo(b, CV_32F);
    cv::Mat window;
    cv::createHanningWindow(window, a.size(), CV_32F);
    // phaseCorrelate multiplies its inputs by the window in place.
    const cv::Point2d shift = cv::phaseCorrelate(a.clone(), b.clone(), window);
    cv::Mat moved;
    cv::warpAffine(a, moved, cv::Matx23d(1, 0, shift.x, 0, 1, shift.y), a.size(), cv::INTER_LINEAR, cv::BORDER_REPLICATE);
    const cv::Mat changed = cv::abs(b - moved) > kChangedLevel;
    int cells = 0;
    for(int y = 0; y < kCells; ++y)
    {
        for(int x = 0; x < kCells; ++x)
        {
            const cv::Rect cell(x * changed.cols / kCells, y * changed.rows / kCells, changed.cols / kCells, changed.rows / kCells);
            cells += cv::countNonZero(changed(cell)) > kChangedCellShare * cell.area() ? 1 : 0;
        }
    }
    if(cells > kMaxCellsForADart)
    {
        return shift;
    }
    if(std::hypot(shift.x, shift.y) > kMovedCamera_px && cv::mean(cv::abs(b - moved))[0] <= kExplainedShare * cv::mean(cv::abs(b - a))[0])
    {
        return shift;
    }
    return std::nullopt;
}

}  // namespace dartpilot::tip_candidates
