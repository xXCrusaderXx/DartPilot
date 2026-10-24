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

// A lens with barrel distortion, as on the reference cameras, around the camera of boardToImage
const cv::Matx33d kLensMatrix(700, 0, 640, 0, 700, 360, 0, 0, 1);
const cv::Matx<double, 5, 1> kLensDistortion(-0.30, 0.10, 0.0, 0.0, 0.0);

cv::Point2f distort (const cv::Point2f& undistorted_px)
{
    const std::vector<cv::Point3f> ray{
        {static_cast<float>((undistorted_px.x - 640) / 700), static_cast<float>((undistorted_px.y - 360) / 700), 1.0f}};
    std::vector<cv::Point2f> image;
    cv::projectPoints(ray, cv::Vec3d(0, 0, 0), cv::Vec3d(0, 0, 0), kLensMatrix, kLensDistortion, image);
    return image.front();
}

// The image the lens makes of an undistorted image: straight wires become slightly bent.
cv::Mat distortImage (const cv::Mat& undistorted)
{
    std::vector<cv::Point2f> pixels, sources;
    for(int y = 0; y < undistorted.rows; ++y)
    {
        for(int x = 0; x < undistorted.cols; ++x)
        {
            pixels.emplace_back(static_cast<float>(x), static_cast<float>(y));
        }
    }
    cv::undistortPoints(pixels, sources, kLensMatrix, kLensDistortion, cv::noArray(), kLensMatrix);
    cv::Mat map(undistorted.size(), CV_32FC2, sources.data());
    cv::Mat image;
    cv::remap(undistorted, image, map, cv::noArray(), cv::INTER_LINEAR, cv::BORDER_CONSTANT, cv::Scalar(15, 15, 15));
    return image;
}

struct PointErrors
{
    double rms_px = 0.0;
    double worst_px = 0.0;
};

// Distance between each detected point and the nearest true intersection on the same circle
PointErrors pointErrors (const dartpilot::geometry::BoardDetection& detection, const cv::Matx33d& h, bool lens = false)
{
    PointErrors errors;
    double sum_sq = 0.0;
    for(const auto& point : detection.points)
    {
        const double r = dartpilot::geometry::kBoardCircleRadii_mm[static_cast<int>(point.circle)];
        double nearest = std::numeric_limits<double>::infinity();
        for(int k = 0; k < 20; ++k)
        {
            const double phi = (9.0 + 18.0 * k) * CV_PI / 180.0;
            const cv::Point2f truth = project(h, r * std::cos(phi), r * std::sin(phi));
            nearest = std::min(nearest, cv::norm(point.image_px - (lens ? distort(truth) : truth)));
        }
        sum_sq += nearest * nearest;
        errors.worst_px = std::max(errors.worst_px, nearest);
    }
    errors.rms_px = std::sqrt(sum_sq / detection.points.size());
    return errors;
}

double worstError (const dartpilot::geometry::BoardDetection& detection, const cv::Matx33d& h) { return pointErrors(detection, h).worst_px; }
}  // namespace

TEST(DetectBoard, FindsAllWireIntersectionsOfAnObliqueBoard)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85));
    ASSERT_TRUE(detection);
    EXPECT_EQ(detection->points.size(), 60u);
    EXPECT_LT(cv::norm(detection->bull_px - project(h, 0.0, 0.0)), 1.5);
    EXPECT_LT(worstError(*detection, h), 1.0);
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
    EXPECT_LT(worstError(*detection, h), 1.0);
}

// Closer to the board the lens bends the radial wires; their crossings with the double ring must still be found where
// the bent wire meets it, not where a straight line through the inner board would.
TEST(DetectBoard, FollowsWiresBentByTheLens)
{
    const cv::Matx33d h = boardToImage(45.0, 420.0, 10.0);
    const auto detection = dartpilot::geometry::detectBoard(distortImage(renderCameraImage(h, 1.0, 85)));
    ASSERT_TRUE(detection);
    EXPECT_EQ(detection->points.size(), 60u);
    const PointErrors errors = pointErrors(*detection, h, true);
    EXPECT_LT(errors.rms_px, 0.5);
    EXPECT_LT(errors.worst_px, 1.2);
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

// A dart hides a wire on every track but one, so that wire keeps only two points, its transition on the reference
// track and the bull; the detection must not fail on that (OpenCV 5 refuses under-determined systems).
TEST(DetectBoard, CopesWithAWireSeenOnlyOnce)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    cv::Mat image = renderCameraImage(h, 1.0, 85);
    // Dark patches across the wire at 9 degrees on every track through the singles except the middle of the outer
    // singles, each wide enough that the sector changes at its edges lie outside the matching window.
    const double angle = 9.0 * CV_PI / 180.0;
    for(const double r_mm : {46.0, 68.0, 90.0, 116.0, 141.0, 154.0})
    {
        std::vector<cv::Point> patch;
        for(const double a : {angle - 0.13, angle + 0.13})
        {
            for(const double rr : {r_mm - 4.0, r_mm + 4.0})
            {
                const cv::Point2f p = project(h, rr * std::cos(a), rr * std::sin(a));
                patch.emplace_back(cvRound(p.x), cvRound(p.y));
            }
        }
        std::swap(patch[2], patch[3]);
        cv::fillConvexPoly(image, patch, cv::Scalar(40, 40, 40), cv::LINE_AA);
    }
    EXPECT_NO_THROW(dartpilot::geometry::detectBoard(image));
}
