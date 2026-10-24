#include "dartpilot/geometry/board_view.hpp"

#include <algorithm>
#include <cmath>

#include <opencv2/imgproc.hpp>

namespace dartpilot::geometry
{
namespace
{
// The projection is computed on a grid of this spacing and interpolated in between; the lens bends it smoothly.
constexpr int kGridStep_px = 4;
// Weight of a camera at a pixel: its pixels per millimetre to this power, so the sharpest camera dominates and the
// others only take over gradually where they are nearly as sharp
constexpr double kSharpnessPower = 8.0;
// Outside the sharp radius: blur, the width of the transition, and how much darker the surround gets
constexpr double kSurroundBlur_mm = 4.0;
constexpr double kTransition_mm = 12.0;
constexpr double kSurroundDarkening = 0.35;
}  // namespace

BoardView renderBoardView (const std::vector<const RefinedCamera*>& cameras, const std::vector<cv::Mat>& images, int size_px, double radius_mm,
                           double sharp_radius_mm)
{
    BoardView view;
    view.radius_mm = radius_mm;
    view.mm_per_px = 2.0 * radius_mm / size_px;
    const int grid = size_px / kGridStep_px + 2;
    const auto boardAt = [&] (double column_px, double row_px)
    {
        return cv::Point3f(static_cast<float>(-radius_mm + column_px * view.mm_per_px), static_cast<float>(radius_mm - row_px * view.mm_per_px),
                           0.0f);
    };
    std::vector<cv::Mat> warped_images, weights;
    for(std::size_t c = 0; c < cameras.size() && c < images.size(); ++c)
    {
        if(!cameras[c] || images[c].empty())
        {
            continue;
        }
        cv::Mat coarse_x(grid, grid, CV_32F), coarse_y(grid, grid, CV_32F);
        for(int r = 0; r < grid; ++r)
        {
            for(int k = 0; k < grid; ++k)
            {
                const cv::Point2f p = boardToImage(*cameras[c], boardAt(k * kGridStep_px, r * kGridStep_px));
                coarse_x.at<float>(r, k) = p.x;
                coarse_y.at<float>(r, k) = p.y;
            }
        }
        // Image pixels per output pixel, from the spread of neighbouring grid points: how sharply this camera sees there
        cv::Mat dx, dy, scale;
        cv::Sobel(coarse_x, dx, CV_32F, 1, 0, 1);
        cv::Sobel(coarse_y, dy, CV_32F, 1, 0, 1);
        cv::magnitude(dx, dy, scale);
        cv::Mat map_x, map_y;
        const cv::Size full(grid * kGridStep_px, grid * kGridStep_px);
        cv::resize(coarse_x, map_x, full, 0, 0, cv::INTER_LINEAR);
        cv::resize(coarse_y, map_y, full, 0, 0, cv::INTER_LINEAR);
        cv::resize(scale, scale, full, 0, 0, cv::INTER_LINEAR);
        const cv::Rect inside(0, 0, size_px, size_px);
        map_x = map_x(inside);
        map_y = map_y(inside);
        scale = scale(inside);
        cv::Mat warped;
        cv::remap(images[c], warped, map_x, map_y, cv::INTER_LINEAR, cv::BORDER_CONSTANT, cv::Scalar(0, 0, 0));
        warped.convertTo(warped, CV_32FC3);
        cv::Mat in_image = (map_x >= 0) & (map_y >= 0) & (map_x < images[c].cols - 1) & (map_y < images[c].rows - 1);
        cv::Mat weight;
        cv::pow(scale / static_cast<float>(view.mm_per_px), kSharpnessPower, weight);
        weight.setTo(0.0f, ~in_image);
        warped_images.push_back(warped);
        weights.push_back(weight);
    }
    cv::Mat sum(size_px, size_px, CV_32FC3, cv::Scalar::all(0.0)), total(size_px, size_px, CV_32F, cv::Scalar(0.0f));
    for(std::size_t i = 0; i < warped_images.size(); ++i)
    {
        // Brightness matched to the first camera where both see the board, so the transitions do not show
        if(i > 0)
        {
            const cv::Mat both = (weights[0] > 0) & (weights[i] > 0);
            if(cv::countNonZero(both) > 0)
            {
                const cv::Scalar first = cv::mean(warped_images[0], both), here = cv::mean(warped_images[i], both);
                std::vector<cv::Mat> channels;
                cv::split(warped_images[i], channels);
                for(int k = 0; k < 3; ++k)
                {
                    channels[k] *= first[k] / std::max(1.0, here[k]);
                }
                cv::merge(channels, warped_images[i]);
            }
        }
        cv::Mat weight3;
        cv::merge(std::vector<cv::Mat>{weights[i], weights[i], weights[i]}, weight3);
        sum += warped_images[i].mul(weight3);
        total += weights[i];
    }
    cv::Mat total3;
    cv::merge(std::vector<cv::Mat>{total, total, total}, total3);
    cv::Mat image = sum / cv::max(total3, 1e-12);
    if(sharp_radius_mm > 0.0)
    {
        cv::Mat blurred;
        cv::GaussianBlur(image, blurred, cv::Size(), kSurroundBlur_mm / view.mm_per_px);
        blurred *= 1.0 - kSurroundDarkening;
        // 0 inside the sharp radius, rising smoothly to 1 over the transition
        cv::Mat surround(size_px, size_px, CV_32F);
        for(int r = 0; r < size_px; ++r)
        {
            for(int k = 0; k < size_px; ++k)
            {
                const double distance_mm = std::hypot(-radius_mm + (k + 0.5) * view.mm_per_px, radius_mm - (r + 0.5) * view.mm_per_px);
                const double t = std::clamp((distance_mm - sharp_radius_mm) / kTransition_mm, 0.0, 1.0);
                surround.at<float>(r, k) = static_cast<float>(t * t * (3.0 - 2.0 * t));
            }
        }
        cv::Mat surround3;
        cv::merge(std::vector<cv::Mat>{surround, surround, surround}, surround3);
        image = image.mul(cv::Scalar::all(1.0) - surround3) + blurred.mul(surround3);
    }
    image.convertTo(view.image, CV_8UC3);
    return view;
}
}  // namespace dartpilot::geometry
