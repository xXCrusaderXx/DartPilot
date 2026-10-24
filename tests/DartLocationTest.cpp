#include <gtest/gtest.h>

#include <cmath>
#include <cstdint>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/dart_location.hpp"

namespace
{
using dartpilot::geometry::DartView;
using dartpilot::geometry::RefinedCamera;

// A camera beside the board at about 45 cm, tilted 60 degrees off the board normal, with a standard lens
RefinedCamera camera (double azimuth_deg)
{
    RefinedCamera camera;
    camera.intrinsics.model = dartpilot::geometry::DistortionModel::Standard;
    camera.intrinsics.image_size_px = cv::Size(1280, 720);
    camera.intrinsics.camera_matrix = cv::Matx33d(735, 0, 640, 0, 735, 360, 0, 0, 1);
    camera.intrinsics.dist_coeffs = cv::Mat(cv::Matx<double, 5, 1>(-0.30, 0.10, 0, 0, -0.01));
    const double azimuth = azimuth_deg * CV_PI / 180.0, tilt = 60.0 * CV_PI / 180.0, distance_mm = 450.0;
    const cv::Vec3d centre(distance_mm * std::sin(tilt) * std::cos(azimuth), distance_mm * std::sin(tilt) * std::sin(azimuth),
                           distance_mm * std::cos(tilt));
    const cv::Vec3d forward = -centre / cv::norm(centre);
    const cv::Vec3d right = cv::normalize(forward.cross(cv::Vec3d(0, 0, 1)));
    const cv::Vec3d down = forward.cross(right);
    const cv::Matx33d rotation(right[0], right[1], right[2], down[0], down[1], down[2], forward[0], forward[1], forward[2]);
    cv::Rodrigues(rotation, camera.rvec);
    camera.tvec_mm = -(rotation * centre);
    return camera;
}

const std::array<RefinedCamera, 3> kCameras = {camera(-90.0), camera(30.0), camera(150.0)};

std::vector<cv::Point2f> project (const RefinedCamera& camera, const std::vector<cv::Point3f>& points)
{
    std::vector<cv::Point2f> image;
    cv::projectPoints(points, camera.rvec, camera.tvec_mm, camera.intrinsics.camera_matrix, camera.intrinsics.dist_coeffs, image);
    return image;
}

// A grey scene with seeded noise, so the empty board and the image with the dart differ only by noise elsewhere
cv::Mat scene (int seed)
{
    cv::Mat noise(720, 1280, CV_32FC3);
    cv::theRNG().state = static_cast<std::uint64_t>(seed);
    cv::randn(noise, cv::Scalar::all(128.0), cv::Scalar::all(2.0));
    cv::Mat image;
    noise.convertTo(image, CV_8UC3);
    return image;
}

// A dart entering the board at tip_mm (z = 0), leaning by tilt_deg towards lean_deg: a thin point, a thicker
// barrel and shaft, and a flight across its axis
cv::Mat withDart (const RefinedCamera& camera, const cv::Point2f& tip_mm, double tilt_deg, double lean_deg, int seed)
{
    cv::Mat image = scene(seed);
    const double tilt = tilt_deg * CV_PI / 180.0, lean = lean_deg * CV_PI / 180.0;
    const cv::Point3f axis(static_cast<float>(std::sin(tilt) * std::cos(lean)), static_cast<float>(std::sin(tilt) * std::sin(lean)),
                           static_cast<float>(std::cos(tilt)));
    const cv::Point3f tip(tip_mm.x, tip_mm.y, 0.0f);
    const auto along = [&] (float from_mm, float to_mm)
    {
        std::vector<cv::Point3f> points;
        for(float s = from_mm; s <= to_mm; s += 1.0f)
        {
            points.push_back(tip + axis * s);
        }
        return project(camera, points);
    };
    const auto draw = [&] (const std::vector<cv::Point2f>& points, int thickness, int grey)
    {
        for(std::size_t i = 1; i < points.size(); ++i)
        {
            cv::line(image, points[i - 1], points[i], cv::Scalar(grey, grey, grey), thickness, cv::LINE_AA);
        }
    };
    draw(along(0.0f, 28.0f), 2, 60);
    draw(along(28.0f, 75.0f), 6, 40);
    const cv::Point3f side = cv::normalize(cv::Vec3f(axis.cross(cv::Point3f(0, 0, 1)) + cv::Point3f(1e-3f, 0, 0)));
    const std::vector<cv::Point3f> flight = {tip + axis * 80.0f, tip + axis * 95.0f + side * 16.0f, tip + axis * 115.0f + side * 16.0f,
                                             tip + axis * 115.0f - side * 16.0f, tip + axis * 95.0f - side * 16.0f};
    std::vector<cv::Point> polygon;
    for(const auto& p : project(camera, flight))
    {
        polygon.emplace_back(cvRound(p.x), cvRound(p.y));
    }
    cv::fillConvexPoly(image, polygon, cv::Scalar(200, 60, 60), cv::LINE_AA);
    return image;
}

std::vector<DartView> views (const cv::Point2f& tip_mm, double tilt_deg, double lean_deg)
{
    std::vector<DartView> result;
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        const auto observation = dartpilot::tip_candidates::observeDart(withDart(kCameras[c], tip_mm, tilt_deg, lean_deg, static_cast<int>(c) + 1),
                                                                        scene(100 + static_cast<int>(c)));
        EXPECT_TRUE(observation) << "camera " << c;
        if(observation)
        {
            result.push_back({&kCameras[c], *observation});
        }
    }
    return result;
}
}  // namespace

TEST(ObserveDart, FindsTheAxisAndTheVisibleEndOfThePoint)
{
    const cv::Point2f tip_mm(40.0f, 70.0f);
    const auto observation = dartpilot::tip_candidates::observeDart(withDart(kCameras[0], tip_mm, 15.0, 30.0, 1), scene(2));
    ASSERT_TRUE(observation);
    EXPECT_FALSE(observation->cut);
    EXPECT_GE(observation->axis_px.size(), 20u);
    const cv::Point2f truth = project(kCameras[0], {cv::Point3f(tip_mm.x, tip_mm.y, 0.0f)}).front();
    double nearest = 1e9;
    for(const auto& end : observation->ends_px)
    {
        nearest = std::min(nearest, static_cast<double>(cv::norm(end - truth)));
    }
    // The point is drawn 2 px thick with a round cap, which reaches about a pixel beyond its end and fades there.
    EXPECT_LT(nearest, 2.5);
}

TEST(ObserveDart, NothingOnAnEmptyBoard) { EXPECT_FALSE(dartpilot::tip_candidates::observeDart(scene(1), scene(2))); }

TEST(LocateDart, AllCamerasAgreeOnWhereTheDartEntersTheBoard)
{
    for(const auto& [tip_mm, lean_deg] : {std::pair{cv::Point2f(0.0f, 0.0f), 0.0}, std::pair{cv::Point2f(40.0f, 70.0f), 30.0},
                                          std::pair{cv::Point2f(-120.0f, -60.0f), 200.0}, std::pair{cv::Point2f(150.0f, -40.0f), 100.0}})
    {
        const auto location = dartpilot::geometry::locateDart(views(tip_mm, 15.0, lean_deg));
        ASSERT_TRUE(location) << tip_mm;
        EXPECT_EQ(location->views.size(), 3u) << tip_mm;
        // Single frames with noise of 2 grey levels and a dart drawn from short anti-aliased strokes are harder than the
        // averaged frames of the setup GUI, where the reference cameras agree within 0.5 mm; a wrong end or a wrong
        // plane would be off by many millimetres.
        EXPECT_LT(cv::norm(location->board_mm - tip_mm), 1.5) << tip_mm << " found " << location->board_mm;
        for(std::size_t i = 0; i < location->views.size(); ++i)
        {
            EXPECT_LT(std::abs(location->plane_distance_mm[i]), 1.0);
            EXPECT_LT(location->end_distance_px[i], 3.0);
        }
        EXPECT_GT(location->covariance_mm2(0, 0), 0.0);
    }
}

TEST(LocateDart, LeavesOutACameraThatSeesSomethingElse)
{
    auto seen = views(cv::Point2f(40.0f, 70.0f), 15.0, 30.0);
    ASSERT_EQ(seen.size(), 3u);
    // Camera 2 sees a dart 30 mm away, as if it had picked up another dart in the board.
    seen[1].observation = *dartpilot::tip_candidates::observeDart(withDart(kCameras[1], cv::Point2f(70.0f, 70.0f), 15.0, 30.0, 7), scene(8));
    const auto location = dartpilot::geometry::locateDart(seen);
    ASSERT_TRUE(location);
    EXPECT_EQ(location->views, (std::vector<int>{0, 2}));
    EXPECT_LT(cv::norm(location->board_mm - cv::Point2f(40.0f, 70.0f)), 1.5);
}

TEST(LocateDart, AbstainsWithoutTwoAgreeingCameras)
{
    auto seen = views(cv::Point2f(40.0f, 70.0f), 15.0, 30.0);
    ASSERT_EQ(seen.size(), 3u);
    seen[1].observation = *dartpilot::tip_candidates::observeDart(withDart(kCameras[1], cv::Point2f(70.0f, 70.0f), 15.0, 30.0, 7), scene(8));
    seen[2].observation = *dartpilot::tip_candidates::observeDart(withDart(kCameras[2], cv::Point2f(-50.0f, 20.0f), 15.0, 30.0, 9), scene(10));
    EXPECT_FALSE(dartpilot::geometry::locateDart(seen));
    seen.resize(1);
    EXPECT_FALSE(dartpilot::geometry::locateDart(seen));
}
