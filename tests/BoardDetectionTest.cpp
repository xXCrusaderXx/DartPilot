#include <gtest/gtest.h>

#include <cmath>
#include <limits>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/board_detection.hpp"

namespace
{
using dartpilot::geometry::BoardCircle;

constexpr std::array<double, 6> kRadii_mm = {6.35, 15.9, 99.0, 107.0, 162.0, 170.0};
constexpr double kTopScale_px_per_mm = 4.0;
constexpr int kTopSize_px = 1600;  // 400 mm around the bull

// Top view of a dartboard in board coordinates (docs/board-coordinates.md): sectors alternate dark single with red
// rings and light single with green rings, the bull is red inside the green outer bull.
cv::Mat renderTopView ()
{
    cv::Mat top(kTopSize_px, kTopSize_px, CV_8UC3, cv::Scalar(20, 20, 20));
    const double c = kTopSize_px / 2.0;
    for(int v = 0; v < kTopSize_px; ++v)
    {
        for(int u = 0; u < kTopSize_px; ++u)
        {
            const double x = (u - c) / kTopScale_px_per_mm, y = (c - v) / kTopScale_px_per_mm;
            const double r = std::hypot(x, y);
            if(r >= kRadii_mm[5])
            {
                continue;
            }
            const double phi = std::fmod(std::atan2(y, x) * 180.0 / CV_PI + 360.0 + 9.0, 360.0);
            const bool even = static_cast<int>(phi / 18.0) % 2 == 0;
            const cv::Vec3b red(40, 40, 190), green(30, 110, 30), dark(25, 25, 25), light(200, 215, 225);
            cv::Vec3b colour;
            if(r < kRadii_mm[0])
            {
                colour = red;
            }
            else if(r < kRadii_mm[1])
            {
                colour = green;
            }
            else if((r >= kRadii_mm[2] && r < kRadii_mm[3]) || r >= kRadii_mm[4])
            {
                colour = even ? red : green;
            }
            else
            {
                colour = even ? dark : light;
            }
            top.at<cv::Vec3b>(v, u) = colour;
        }
    }
    return top;
}

// Homography from board millimetres to image pixels for a camera above the board, tilted towards it
cv::Matx33d boardToImage (double tilt_deg, double distance_mm, double yaw_deg)
{
    const cv::Matx33d k(700, 0, 640, 0, 700, 360, 0, 0, 1);
    const cv::Vec3d rvec(-tilt_deg * CV_PI / 180.0, 0.0, yaw_deg * CV_PI / 180.0);
    cv::Matx33d rotation;
    cv::Rodrigues(rvec, rotation);
    const cv::Vec3d t(0.0, 0.0, distance_mm);
    const cv::Matx33d rt(rotation(0, 0), rotation(0, 1), t[0], rotation(1, 0), rotation(1, 1), t[1], rotation(2, 0), rotation(2, 1), t[2]);
    // Board y points up, image y down
    const cv::Matx33d flip(1, 0, 0, 0, -1, 0, 0, 0, 1);
    return k * rt * flip;
}

cv::Point2f project (const cv::Matx33d& h, double x_mm, double y_mm)
{
    const cv::Vec3d p = h * cv::Vec3d(x_mm, y_mm, 1.0);
    return {static_cast<float>(p[0] / p[2]), static_cast<float>(p[1] / p[2])};
}

cv::Mat renderCameraImage (const cv::Matx33d& board_to_image, double blur_sigma_px, int jpeg_quality)
{
    const double c = kTopSize_px / 2.0;
    // Top-view pixels to board millimetres
    const cv::Matx33d top_to_board(1 / kTopScale_px_per_mm, 0, -c / kTopScale_px_per_mm, 0, -1 / kTopScale_px_per_mm, c / kTopScale_px_per_mm, 0, 0,
                                   1);
    cv::Mat image;
    cv::warpPerspective(renderTopView(), image, cv::Mat(board_to_image * top_to_board), cv::Size(1280, 720), cv::INTER_AREA, cv::BORDER_CONSTANT,
                        cv::Scalar(15, 15, 15));
    cv::GaussianBlur(image, image, cv::Size(), blur_sigma_px);
    std::vector<uchar> jpeg;
    cv::imencode(".jpg", image, jpeg, {cv::IMWRITE_JPEG_QUALITY, jpeg_quality});
    return cv::imdecode(jpeg, cv::IMREAD_COLOR);
}

// Largest distance between a detected point and the nearest true intersection on the same circle
double worstError (const dartpilot::geometry::BoardDetection& detection, const cv::Matx33d& h)
{
    double worst = 0.0;
    for(const auto& point : detection.points)
    {
        const double r = dartpilot::geometry::kBoardCircleRadii_mm[static_cast<int>(point.circle)];
        double nearest = std::numeric_limits<double>::infinity();
        for(int k = 0; k < 20; ++k)
        {
            const double phi = (9.0 + 18.0 * k) * CV_PI / 180.0;
            nearest = std::min(nearest, cv::norm(point.image_px - project(h, r * std::cos(phi), r * std::sin(phi))));
        }
        worst = std::max(worst, nearest);
    }
    return worst;
}
}  // namespace

TEST(DetectBoard, FindsAllWireIntersectionsOfAnObliqueBoard)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85));
    ASSERT_TRUE(detection);
    EXPECT_EQ(detection->points.size(), 60u);
    EXPECT_LT(cv::norm(detection->bull_px - project(h, 0.0, 0.0)), 1.5);
    EXPECT_LT(worstError(*detection, h), 1.5);
    for(const auto& point : detection->points)
    {
        EXPECT_GT(point.sigma_px, 0.0);
    }
}

TEST(DetectBoard, CopesWithBlurAndCompressionAtAStrongerTilt)
{
    const cv::Matx33d h = boardToImage(55.0, 650.0, -30.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.8, 50));
    ASSERT_TRUE(detection);
    EXPECT_EQ(detection->points.size(), 60u);
    EXPECT_LT(worstError(*detection, h), 2.5);
}

TEST(DetectBoard, WiresAreCounterClockwiseAndCirclesNested)
{
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(boardToImage(40.0, 600.0, 15.0), 1.0, 85));
    ASSERT_TRUE(detection);
    for(int w = 0; w + 1 < 20; ++w)
    {
        const double a0 = std::atan2(-detection->wires[w][3], detection->wires[w][2]);
        const double a1 = std::atan2(-detection->wires[w + 1][3], detection->wires[w + 1][2]);
        EXPECT_GT(std::remainder(a1 - a0, 2 * CV_PI), 0.0) << "wire " << w;
    }
    for(int k = 0; k + 1 < 3; ++k)
    {
        EXPECT_LT(detection->circles[k].size.area(), detection->circles[k + 1].size.area());
    }
}

TEST(DetectBoard, NothingWithoutABoard)
{
    cv::Mat empty(720, 1280, CV_8UC3, cv::Scalar(30, 30, 30));
    cv::randu(empty, cv::Scalar(0, 0, 0), cv::Scalar(60, 60, 60));
    EXPECT_FALSE(dartpilot::geometry::detectBoard(empty));
    EXPECT_FALSE(dartpilot::geometry::detectBoard(cv::Mat()));
}
