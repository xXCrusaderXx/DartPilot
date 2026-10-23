#include <gtest/gtest.h>

#include <unistd.h>

#include <clocale>
#include <cmath>
#include <filesystem>
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

// A phone held closer than the focus distance: the pattern covers half the image width, slightly tilted, blurred
// (sigma 2 px) and MJPEG-compressed. The default ArUco parameters decode fewer than half of the markers here.
TEST(CharucoFinder, FindsMostCornersOfASoftCompressedPattern)
{
    if(!dartpilot::geometry::charucoAvailable())
    {
        GTEST_SKIP() << "built without ChArUco support (OpenCV < 4.7)";
    }
    const dartpilot::geometry::CharucoFinder finder;
    const cv::Mat pattern = finder.patternImage(cv::Size(1000, 700));
    const std::vector<cv::Point2f> source = {{0, 0}, {1000, 0}, {1000, 700}, {0, 700}};
    const std::vector<cv::Point2f> target = {{325, 140}, {955, 160}, {940, 581}, {335, 568}};
    cv::Mat frame;
    cv::warpPerspective(pattern, frame, cv::getPerspectiveTransform(source, target), cv::Size(1280, 720), cv::INTER_AREA, cv::BORDER_CONSTANT,
                        cv::Scalar(90));
    cv::GaussianBlur(frame, frame, cv::Size(), 2.0);
    std::vector<uchar> jpeg;
    cv::imencode(".jpg", frame, jpeg, {cv::IMWRITE_JPEG_QUALITY, 35});
    frame = cv::imdecode(jpeg, cv::IMREAD_GRAYSCALE);

    const auto view = finder.detect(frame);
    ASSERT_TRUE(view);
    EXPECT_GE(static_cast<int>(view->ids.size()), finder.target().cornerCount() * 2 / 3);
}

namespace
{
std::vector<CalibrationView> withNoise (std::vector<CalibrationView> views, double sigma_px)
{
    cv::RNG rng(1234);
    for(auto& view : views)
    {
        for(auto& point : view.image_points_px)
        {
            point.x += static_cast<float>(rng.gaussian(sigma_px));
            point.y += static_cast<float>(rng.gaussian(sigma_px));
        }
    }
    return views;
}
}  // namespace

TEST(ValidateIntrinsics, HeldOutErrorMatchesTheNoise)
{
    const cv::Mat dist(cv::Matx<double, 1, 5>(-0.25, 0.08, 0.0005, -0.0003, 0.0));
    const auto views = withNoise(syntheticViews(DistortionModel::Standard, dist), 0.2);
    const auto calibration = dartpilot::geometry::calibrateIntrinsics(views, kImageSize, DistortionModel::Standard);
    const auto validation = dartpilot::geometry::validateIntrinsics(views, kImageSize, DistortionModel::Standard);
    ASSERT_TRUE(calibration);
    ASSERT_TRUE(validation);
    EXPECT_EQ(validation->folds, 5);
    // Gaussian noise of 0.2 px per axis has an RMS of about 0.28 px in 2D; held-out views cannot do better than the fit.
    EXPECT_GT(validation->rms_px, 0.2);
    EXPECT_LT(validation->rms_px, 0.5);
    EXPECT_GE(validation->rms_px, calibration->rms_px * 0.95);
    int points = 0;
    for(const int n : validation->region_points)
    {
        points += n;
    }
    EXPECT_EQ(points, static_cast<int>(views.size() * views.front().ids.size()));
}

TEST(ValidateIntrinsics, NeedsEnoughViews)
{
    auto views = syntheticViews(DistortionModel::Standard, cv::Mat::zeros(1, 5, CV_64F));
    views.resize(3);
    EXPECT_FALSE(dartpilot::geometry::validateIntrinsics(views, kImageSize, DistortionModel::Standard));
}

TEST(RecommendModel, PicksTheModelTheDataNeeds)
{
    const auto recommend = [] (const std::vector<CalibrationView>& views)
    {
        std::vector<std::pair<DistortionModel, dartpilot::geometry::HeldOutValidation>> validations;
        for(const auto model : {DistortionModel::Standard, DistortionModel::Rational, DistortionModel::Fisheye})
        {
            if(const auto validation = dartpilot::geometry::validateIntrinsics(views, kImageSize, model))
            {
                validations.emplace_back(model, *validation);
            }
        }
        return dartpilot::geometry::recommendModel(validations);
    };
    const cv::Mat standard(cv::Matx<double, 1, 5>(-0.25, 0.08, 0.0005, -0.0003, 0.0));
    EXPECT_EQ(recommend(withNoise(syntheticViews(DistortionModel::Standard, standard), 0.1)), DistortionModel::Standard);
    // Strong fisheye distortion, as from a wide lens, which the polynomial models cannot follow at the image edges
    const cv::Mat fisheye(cv::Vec4d(0.3, 0.2, -0.1, 0.05));
    EXPECT_EQ(recommend(withNoise(syntheticViews(DistortionModel::Fisheye, fisheye), 0.1)), DistortionModel::Fisheye);
}

TEST(RecommendModel, PrefersFewerCoefficientsWithinTolerance)
{
    dartpilot::geometry::HeldOutValidation good, slightly_better;
    good.rms_px = 0.30;
    slightly_better.rms_px = 0.29;
    EXPECT_EQ(dartpilot::geometry::recommendModel({{DistortionModel::Standard, good}, {DistortionModel::Rational, slightly_better}}),
              DistortionModel::Standard);
    slightly_better.rms_px = 0.20;
    EXPECT_EQ(dartpilot::geometry::recommendModel({{DistortionModel::Standard, good}, {DistortionModel::Rational, slightly_better}}),
              DistortionModel::Rational);
    EXPECT_FALSE(dartpilot::geometry::recommendModel({}));
}

TEST(LoadIntrinsics, RoundTrip)
{
    const cv::Mat dist(cv::Matx<double, 1, 5>(-0.25, 0.08, 0.0005, -0.0003, 0.0));
    const auto views = withNoise(syntheticViews(DistortionModel::Standard, dist), 0.2);
    const auto calibration = dartpilot::geometry::calibrateIntrinsics(views, kImageSize, DistortionModel::Standard);
    const auto validation = dartpilot::geometry::validateIntrinsics(views, kImageSize, DistortionModel::Standard);
    ASSERT_TRUE(calibration && validation);
    dartpilot::geometry::CalibrationInfo info{"2.4.3.1.2", "USB Camera", "MJPG 1280x720 30fps", "charuco 10x7 DICT_4X4_50 marker 0.70",
                                              "2026-10-23T20:00:00Z"};
    const std::string path = (std::filesystem::temp_directory_path() / ("dartpilot-intrinsics-test-" + std::to_string(::getpid()) + ".yml")).string();
    ASSERT_TRUE(dartpilot::geometry::saveIntrinsics(path, *calibration, info, views, validation));
    const auto stored = dartpilot::geometry::loadIntrinsics(path);
    std::filesystem::remove(path);
    ASSERT_TRUE(stored);
    EXPECT_EQ(stored->calibration.model, DistortionModel::Standard);
    EXPECT_EQ(stored->calibration.image_size_px, kImageSize);
    EXPECT_NEAR(stored->calibration.camera_matrix(0, 0), calibration->camera_matrix(0, 0), 1e-9);
    EXPECT_EQ(stored->calibration.dist_coeffs.total(), 5u);
    EXPECT_NEAR(stored->calibration.rms_px, calibration->rms_px, 1e-12);
    EXPECT_EQ(stored->info.usb_port, "2.4.3.1.2");
    EXPECT_EQ(stored->info.created, "2026-10-23T20:00:00Z");
    ASSERT_EQ(stored->views.size(), views.size());
    EXPECT_EQ(stored->views[3].ids, views[3].ids);
    ASSERT_TRUE(stored->validation);
    EXPECT_NEAR(stored->validation->rms_px, validation->rms_px, 1e-12);
    EXPECT_EQ(stored->validation->region_points, validation->region_points);
}

TEST(LoadIntrinsics, RejectsMissingAndForeignFiles)
{
    EXPECT_FALSE(dartpilot::geometry::loadIntrinsics("/nonexistent/intrinsics.yml"));
    const std::string path = (std::filesystem::temp_directory_path() / ("dartpilot-foreign-test-" + std::to_string(::getpid()) + ".yml")).string();
    {
        cv::FileStorage file(path, cv::FileStorage::WRITE);
        file << "format" << "something-else";
    }
    EXPECT_FALSE(dartpilot::geometry::loadIntrinsics(path));
    std::filesystem::remove(path);
}

TEST(SettingsMismatches, AppliesOnlyToItsCameraAndMode)
{
    dartpilot::geometry::StoredIntrinsics stored;
    stored.calibration.image_size_px = cv::Size(1280, 720);
    stored.info.usb_port = "2.4.3.1.2";
    stored.info.pixel_format = "MJPG 1280x720 30fps";

    EXPECT_TRUE(dartpilot::geometry::settingsMismatches(stored, {"2.4.3.1.2", cv::Size(1280, 720), "MJPG 1280x720 30fps"}).empty());

    const auto other_port = dartpilot::geometry::settingsMismatches(stored, {"2.4.3.1.3", cv::Size(1280, 720), "MJPG 1280x720 30fps"});
    ASSERT_EQ(other_port.size(), 1u);
    EXPECT_NE(other_port.front().find("2.4.3.1.3"), std::string::npos);

    const auto other_mode = dartpilot::geometry::settingsMismatches(stored, {"2.4.3.1.2", cv::Size(640, 480), "MJPG 640x480 30fps"});
    ASSERT_EQ(other_mode.size(), 2u);
    EXPECT_NE(other_mode.front().find("640x480"), std::string::npos);

    // Unknown fields are not held against the calibration; the image size always is.
    EXPECT_TRUE(dartpilot::geometry::settingsMismatches(stored, {"", cv::Size(1280, 720), ""}).empty());
}
