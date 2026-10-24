#include <gtest/gtest.h>

#include <cmath>
#include <limits>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "SyntheticBoard.hpp"
#include "dartpilot/geometry/board_detection.hpp"

namespace
{
using dartpilot::geometry::BoardCircle;
using synthetic_board::boardToImage;
using synthetic_board::project;
using synthetic_board::renderCameraImage;

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

// Daylight on the reference board: pale red (saturation about 85), bright teal green, and red plates on the number ring
// that must not be taken for the double ring.
TEST(DetectBoard, CopesWithDaylightColoursAndPlates)
{
    synthetic_board::Look daylight;
    daylight.red = cv::Vec3b(125, 125, 190);
    daylight.green = cv::Vec3b(150, 180, 60);
    daylight.dark = cv::Vec3b(60, 55, 55);
    daylight.light = cv::Vec3b(235, 240, 245);
    daylight.plates = true;
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85, daylight));
    ASSERT_TRUE(detection);
    EXPECT_EQ(detection->points.size(), 60u);
    EXPECT_LT(worstError(*detection, h), 1.5);
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
