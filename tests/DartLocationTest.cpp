#include <gtest/gtest.h>

#include <cmath>
#include <cstdint>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/fusion/reference_targets.hpp"
#include "dartpilot/geometry/dart_location.hpp"
#include "dartpilot/tip_candidates/tip_candidates.hpp"

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
void drawDart (cv::Mat& image, const RefinedCamera& camera, const cv::Point2f& tip_mm, double tilt_deg, double lean_deg)
{
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
}

cv::Mat withDart (const RefinedCamera& camera, const cv::Point2f& tip_mm, double tilt_deg, double lean_deg, int seed)
{
    cv::Mat image = scene(seed);
    drawDart(image, camera, tip_mm, tilt_deg, lean_deg);
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

TEST(TipCandidates, EveryGeneratorOffersACandidateAtTheTip)
{
    const cv::Point2f tip_mm(40.0f, 70.0f);
    const auto observation = dartpilot::tip_candidates::observeDart(withDart(kCameras[0], tip_mm, 15.0, 30.0, 1), scene(2));
    ASSERT_TRUE(observation);
    const cv::Point2f truth = project(kCameras[0], {cv::Point3f(tip_mm.x, tip_mm.y, 0.0f)}).front();
    const auto candidates = dartpilot::tip_candidates::tipCandidates(*observation);
    using dartpilot::tip_candidates::CandidateSource;
    for(const auto source : {CandidateSource::AxisEnd, CandidateSource::ContourEnd, CandidateSource::SkeletonEnd})
    {
        double nearest = 1e9;
        int count = 0;
        for(const auto& c : candidates)
        {
            if(c.source == source)
            {
                nearest = std::min(nearest, static_cast<double>(cv::norm(c.pixel_px - truth)));
                ++count;
            }
        }
        // One at each end; the skeleton stops short of the faded end of the point by about its half width.
        EXPECT_EQ(count, 2) << dartpilot::tip_candidates::sourceName(source);
        EXPECT_LT(nearest, 4.0) << dartpilot::tip_candidates::sourceName(source);
    }
    EXPECT_EQ(candidates, dartpilot::tip_candidates::tipCandidates(*observation));
}

TEST(TipCandidates, NoneAtTheImageBorderAndNoneWithoutAnAxis)
{
    dartpilot::tip_candidates::DartObservation observation;
    EXPECT_TRUE(dartpilot::tip_candidates::tipCandidates(observation).empty());
    // A bar from the left image border to x = 60: only its inner end is a candidate.
    observation.mask = cv::Mat::zeros(100, 200, CV_8U);
    cv::rectangle(observation.mask, cv::Point(0, 48), cv::Point(60, 52), cv::Scalar(255), cv::FILLED);
    for(int x = 0; x <= 60; x += 2)
    {
        observation.axis_px.emplace_back(static_cast<float>(x), 50.0f);
    }
    observation.ends_px = {cv::Point2f(60.0f, 50.0f)};
    const auto candidates = dartpilot::tip_candidates::tipCandidates(observation);
    ASSERT_FALSE(candidates.empty());
    for(const auto& c : candidates)
    {
        EXPECT_GT(c.pixel_px.x, 50.0f) << dartpilot::tip_candidates::sourceName(c.source);
    }
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

TEST(DartTracker, ThrowsForEachDartAndATakeoutWhenTheBoardIsEmptyAgain)
{
    std::vector<dartpilot::fusion::TrackerCamera> cameras;
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        cameras.push_back({"cam" + std::to_string(c), &kCameras[c], scene(100 + static_cast<int>(c))});
    }
    dartpilot::fusion::DartTracker tracker(cameras, {});
    const auto still = [&] (const std::vector<std::pair<cv::Point2f, double>>& darts)
    {
        std::vector<cv::Mat> images;
        for(std::size_t c = 0; c < kCameras.size(); ++c)
        {
            // The same scene every time, as a still camera sees it; only the darts change
            cv::Mat image = scene(200 + static_cast<int>(c));
            for(const auto& [tip_mm, lean_deg] : darts)
            {
                drawDart(image, kCameras[c], tip_mm, 15.0, lean_deg);
            }
            images.push_back(image);
        }
        return tracker.addStill(images);
    };
    const cv::Point2f first(40.0f, 70.0f), second(-60.0f, -20.0f);

    EXPECT_TRUE(still({}).became_ready);
    const auto one = still({{first, 30.0}});
    ASSERT_TRUE(one.dart);
    ASSERT_TRUE(one.dart->location);
    EXPECT_LT(cv::norm(one.dart->location->board_mm - first), 2.0);
    // The same board again: nothing new
    EXPECT_FALSE(still({{first, 30.0}}).dart);
    const auto two = still({{first, 30.0}, {second, 200.0}});
    ASSERT_TRUE(two.dart);
    ASSERT_TRUE(two.dart->location);
    EXPECT_LT(cv::norm(two.dart->location->board_mm - second), 2.0);
    EXPECT_EQ(tracker.dartsInBoard(), 2);
    const auto pulled = still({});
    EXPECT_FALSE(pulled.dart);
    ASSERT_TRUE(pulled.takeout);
    EXPECT_EQ(*pulled.takeout, 2);
}

TEST(ReferenceTargets, CornersLieBesideBothWiresInsideTheirField)
{
    const auto targets = dartpilot::fusion::referenceTargets({});
    ASSERT_EQ(targets.size(), 10u);
    EXPECT_EQ(targets[0].kind, "bull_centre");
    EXPECT_LT(cv::norm(targets[0].board_mm), 1e-9);
    // D20 at the 20/1 wire: just inside the outer double wire (170 mm), just on the 20 side of the wire at 9 degrees
    const auto& d20 = targets[1];
    EXPECT_EQ(d20.field, "D20");
    EXPECT_EQ(d20.wires, (std::vector<int>{20, 1}));
    EXPECT_NEAR(cv::norm(d20.board_mm), 170.0 - dartpilot::fusion::kCornerOffset_mm, 1e-6);
    const double wire_x_mm = cv::norm(d20.board_mm) * std::sin(9.0 * CV_PI / 180.0);
    EXPECT_NEAR(wire_x_mm - d20.board_mm.x, dartpilot::fusion::kCornerOffset_mm, 0.05);
    // S6 inside the treble, at the 13/6 wire on the 6 side, to the right of the bull
    EXPECT_EQ(targets[6].field, "S6");
    EXPECT_GT(targets[6].board_mm.x, 90.0);
    EXPECT_NEAR(cv::norm(targets[6].board_mm), 99.0 - dartpilot::fusion::kCornerOffset_mm, 1e-6);
    // The last corner lies outside the outer bull
    EXPECT_NEAR(cv::norm(targets[9].board_mm), 15.9 + dartpilot::fusion::kCornerOffset_mm, 1e-6);
}

TEST(DartTracker, AKnockedCameraIsNoDart)
{
    std::vector<dartpilot::fusion::TrackerCamera> cameras;
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        cameras.push_back({"cam" + std::to_string(c), &kCameras[c], scene(100 + static_cast<int>(c))});
    }
    dartpilot::fusion::DartTracker tracker(cameras, {});
    std::vector<cv::Mat> images;
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        cv::Mat image = scene(200 + static_cast<int>(c));
        // Some structure for the phase correlation to follow, as the board gives a real camera
        cv::rectangle(image, cv::Rect(400, 200, 300, 200), cv::Scalar(30, 30, 30), cv::FILLED);
        images.push_back(image);
    }
    ASSERT_TRUE(tracker.addStill(images).became_ready);
    cv::warpAffine(images[1], images[1], cv::Matx23d(1, 0, 12, 0, 1, -7), images[1].size(), cv::INTER_LINEAR, cv::BORDER_REPLICATE);
    const auto knocked = tracker.addStill(images);
    EXPECT_FALSE(knocked.dart);
    ASSERT_EQ(knocked.moved_cameras.size(), 1u);
    EXPECT_EQ(knocked.moved_cameras[0].first, 1);
    EXPECT_NEAR(knocked.moved_cameras[0].second.x, 12.0, 1.0);
    // Afterwards the knocked view is the new still state: nothing more happens.
    EXPECT_FALSE(tracker.addStill(images).dart);
}
