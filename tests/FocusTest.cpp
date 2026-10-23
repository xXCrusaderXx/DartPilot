#include <gtest/gtest.h>

#include <opencv2/imgproc.hpp>

#include "dartpilot/capture/focus.hpp"

namespace
{
cv::Mat checkerboard (int square_px, uchar dark, uchar bright)
{
    cv::Mat image(240, 320, CV_8UC1);
    for(int y = 0; y < image.rows; ++y)
    {
        for(int x = 0; x < image.cols; ++x)
        {
            image.at<uchar>(y, x) = ((x / square_px + y / square_px) % 2 == 0) ? dark : bright;
        }
    }
    return image;
}
}  // namespace

TEST(Sharpness, BlurLowersIt)
{
    const cv::Mat sharp = checkerboard(16, 40, 200);
    cv::Mat slightly_blurred, blurred;
    cv::GaussianBlur(sharp, slightly_blurred, cv::Size(), 1.0);
    cv::GaussianBlur(sharp, blurred, cv::Size(), 3.0);
    EXPECT_GT(dartpilot::capture::sharpness(sharp), dartpilot::capture::sharpness(slightly_blurred));
    EXPECT_GT(dartpilot::capture::sharpness(slightly_blurred), dartpilot::capture::sharpness(blurred));
}

TEST(Sharpness, IndependentOfBrightness)
{
    const cv::Mat image = checkerboard(16, 40, 200);
    cv::Mat darker;
    image.convertTo(darker, CV_8UC1, 0.5);
    EXPECT_NEAR(dartpilot::capture::sharpness(darker), dartpilot::capture::sharpness(image), 0.01 * dartpilot::capture::sharpness(image));
}

TEST(Sharpness, ZeroForUniformEmptyAndBlack)
{
    EXPECT_EQ(dartpilot::capture::sharpness(cv::Mat(64, 64, CV_8UC1, cv::Scalar(128))), 0.0);
    EXPECT_EQ(dartpilot::capture::sharpness(cv::Mat()), 0.0);
    EXPECT_EQ(dartpilot::capture::sharpness(cv::Mat(64, 64, CV_8UC1, cv::Scalar(0))), 0.0);
}
