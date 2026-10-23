#include "dartpilot/capture/focus.hpp"

#include <opencv2/imgproc.hpp>

namespace dartpilot::capture
{
double sharpness (const cv::Mat& gray)
{
    CV_Assert(gray.empty() || gray.type() == CV_8UC1);
    if(gray.empty())
    {
        return 0.0;
    }
    const double mean_intensity = cv::mean(gray)[0];
    if(mean_intensity <= 0.0)
    {
        return 0.0;
    }
    cv::Mat gx, gy;
    cv::Sobel(gray, gx, CV_32F, 1, 0);
    cv::Sobel(gray, gy, CV_32F, 0, 1);
    const double gradient_energy = (cv::mean(gx.mul(gx))[0] + cv::mean(gy.mul(gy))[0]);
    return gradient_energy / (mean_intensity * mean_intensity);
}

cv::Rect gridCell (const cv::Size& size, int grid_size, int cell)
{
    const int col = cell % grid_size;
    const int row = cell / grid_size;
    const int x0 = col * size.width / grid_size;
    const int y0 = row * size.height / grid_size;
    const int x1 = (col + 1) * size.width / grid_size;
    const int y1 = (row + 1) * size.height / grid_size;
    return {x0, y0, x1 - x0, y1 - y0};
}
}  // namespace dartpilot::capture
