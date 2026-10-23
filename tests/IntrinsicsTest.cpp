#include <gtest/gtest.h>

#include <clocale>
#include <cmath>
#include <string>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/charuco.hpp"
#include "dartpilot/geometry/intrinsics.hpp"

namespace
{
using dartpilot::geometry::CalibrationView;
using dartpilot::geometry::DistortionModel;

const cv::Size kImageSize(1280, 720);
const cv::Matx33d kCameraMatrix(700.0, 0.0, 645.0, 0.0, 705.0, 355.0, 0.0, 0.0, 1.0);

// Corners of a 9x6 target in squares, seen from fixed poses that tilt it up to 35 degrees.
std::vector<CalibrationView> syntheticViews (DistortionModel model, const cv::Mat& dist_coeffs)
{
    std::vector<cv::Point3f> target;
    std::vector<int> ids;
    for(int y = 0; y < 6; ++y)
    {
        for(int x = 0; x < 9; ++x)
        {
            ids.push_back(static_cast<int>(target.size()));
            target.emplace_back(static_cast<float>(x), static_cast<float>(y), 0.0f);
        }
    }
    std::vector<CalibrationView> views;
    for(int i = 0; i < 15; ++i)
    {
        const double angle = (i % 5 - 2) * 0.3;
        const cv::Vec3d rvec(angle * ((i / 5) % 2 == 0 ? 1.0 : 0.4), angle * ((i / 5) == 1 ? 1.0 : 0.5), 0.1 * (i % 3));
        const cv::Vec3d tvec(-4.0 + (i % 3) * 1.0, -2.5 + (i % 2) * 0.8, 9.0 + (i % 4) * 2.0);
        std::vector<cv::Point2f> projected;
        if(model == DistortionModel::Fisheye)
        {
            cv::fisheye::projectPoints(target, projected, rvec, tvec, kCameraMatrix, dist_coeffs);
        }
        else
        {
            cv::projectPoints(target, rvec, tvec, kCameraMatrix, dist_coeffs, projected);
        }
        views.push_back({ids, target, projected});
    }
    return views;
}

void expectCameraMatrix (const dartpilot::geometry::IntrinsicCalibration& result)
{
    EXPECT_NEAR(result.camera_matrix(0, 0), kCameraMatrix(0, 0), 0.5);
    EXPECT_NEAR(result.camera_matrix(1, 1), kCameraMatrix(1, 1), 0.5);
    EXPECT_NEAR(result.camera_matrix(0, 2), kCameraMatrix(0, 2), 0.5);
    EXPECT_NEAR(result.camera_matrix(1, 2), kCameraMatrix(1, 2), 0.5);
    EXPECT_LT(result.rms_px, 0.01);
}
}  // namespace

TEST(CalibrateIntrinsics, RecoversStandardModel)
{
    const cv::Mat dist(cv::Matx<double, 1, 5>(-0.25, 0.08, 0.0005, -0.0003, 0.0));
    const auto result =
        dartpilot::geometry::calibrateIntrinsics(syntheticViews(DistortionModel::Standard, dist), kImageSize, DistortionModel::Standard);
    ASSERT_TRUE(result);
    expectCameraMatrix(*result);
    EXPECT_NEAR(result->dist_coeffs.at<double>(0), -0.25, 0.01);
    EXPECT_EQ(result->per_view_rms_px.size(), 15u);
    EXPECT_EQ(result->std_deviations.size(), 9u);
}

TEST(CalibrateIntrinsics, RecoversRationalModel)
{
    const cv::Mat dist(cv::Matx<double, 1, 8>(-0.2, 0.05, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0));
    const auto result =
        dartpilot::geometry::calibrateIntrinsics(syntheticViews(DistortionModel::Rational, dist), kImageSize, DistortionModel::Rational);
    ASSERT_TRUE(result);
    expectCameraMatrix(*result);
    EXPECT_EQ(result->dist_coeffs.total(), 8u);
}

TEST(CalibrateIntrinsics, RecoversFisheyeModel)
{
    const cv::Mat dist(cv::Vec4d(0.05, -0.02, 0.01, -0.002));
    const auto result =
        dartpilot::geometry::calibrateIntrinsics(syntheticViews(DistortionModel::Fisheye, dist), kImageSize, DistortionModel::Fisheye);
    ASSERT_TRUE(result);
    expectCameraMatrix(*result);
    EXPECT_EQ(result->per_view_rms_px.size(), 15u);
}

TEST(CalibrateIntrinsics, RejectsTooFewViews)
{
    auto views = syntheticViews(DistortionModel::Standard, cv::Mat::zeros(1, 5, CV_64F));
    views.resize(2);
    EXPECT_FALSE(dartpilot::geometry::calibrateIntrinsics(views, kImageSize, DistortionModel::Standard));
}

TEST(DistortionModel, NamesRoundTrip)
{
    for(const auto model : {DistortionModel::Standard, DistortionModel::Rational, DistortionModel::Fisheye})
    {
        EXPECT_EQ(dartpilot::geometry::parseDistortionModel(dartpilot::geometry::toString(model)), model);
    }
    EXPECT_FALSE(dartpilot::geometry::parseDistortionModel("pinhole"));
}

TEST(CharucoFinder, FindsEveryCornerOfItsOwnPattern)
{
    if(!dartpilot::geometry::charucoAvailable())
    {
        GTEST_SKIP() << "built without ChArUco support (OpenCV < 4.7)";
    }
    const dartpilot::geometry::CharucoFinder finder;
    const cv::Mat pattern = finder.patternImage(cv::Size(1200, 840));
    ASSERT_FALSE(pattern.empty());
    const auto view = finder.detect(pattern);
    ASSERT_TRUE(view);
    EXPECT_EQ(static_cast<int>(view->ids.size()), finder.target().cornerCount());
    EXPECT_EQ(view->object_points.size(), view->image_points_px.size());
}

TEST(CharucoTarget, Describes) { EXPECT_EQ(dartpilot::geometry::CharucoTarget{}.describe(), "charuco 10x7 DICT_4X4_50 marker 0.70"); }

TEST(CharucoTarget, DescriptionIgnoresTheLocale)
{
    // A desktop with a German locale uses a decimal comma in printf-style formatting.
    const char* previous = std::setlocale(LC_NUMERIC, nullptr);
    const std::string saved = previous ? previous : "C";
    if(!std::setlocale(LC_NUMERIC, "de_DE.UTF-8"))
    {
        GTEST_SKIP() << "de_DE.UTF-8 locale not installed";
    }
    const std::string description = dartpilot::geometry::CharucoTarget{}.describe();
    std::setlocale(LC_NUMERIC, saved.c_str());
    EXPECT_EQ(description, "charuco 10x7 DICT_4X4_50 marker 0.70");
}

// The pattern in docs/calibration is what users open on a phone; it must be exactly the one the detector expects.
// Regenerate it with: dartpilot pattern docs/calibration/<file name>
TEST(CharucoTarget, ShippedPatternMatchesTheTarget)
{
    if(!dartpilot::geometry::charucoAvailable())
    {
        GTEST_SKIP() << "built without ChArUco support (OpenCV < 4.7)";
    }
    const dartpilot::geometry::CharucoTarget target;
    const std::string path = std::string(DARTPILOT_SOURCE_DIR) + "/docs/calibration/" + target.imageFileName();
    const cv::Mat shipped = cv::imread(path, cv::IMREAD_GRAYSCALE);
    ASSERT_FALSE(shipped.empty()) << "missing " << path;
    const cv::Mat generated = dartpilot::geometry::CharucoFinder(target).patternImage(
        cv::Size(dartpilot::geometry::kPatternImageWidth_px, dartpilot::geometry::kPatternImageHeight_px));
    ASSERT_EQ(shipped.size(), generated.size());
    EXPECT_EQ(cv::norm(shipped, generated, cv::NORM_INF), 0.0);
}
