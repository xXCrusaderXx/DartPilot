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
}  // namespace dartpilot::capture
