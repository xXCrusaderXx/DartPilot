#include <gtest/gtest.h>

#include <unistd.h>

#include <cmath>
#include <filesystem>
#include <string>

#include <opencv2/calib3d.hpp>

#include "dartpilot/geometry/board_refinement.hpp"

namespace
{
using dartpilot::geometry::BoardCorrespondence;
using dartpilot::geometry::DistortionModel;
using dartpilot::geometry::IntrinsicCalibration;
using dartpilot::geometry::IntrinsicsSource;
using dartpilot::geometry::RefinementInput;

// A board that differs from the nominal one the way real boards and the detection do
constexpr double kOuterBull_mm = 15.5;
constexpr double kTreble_mm = 102.2;
constexpr double kDouble_mm = 166.0;
constexpr double kEdgeOffset_mm = 0.5;
constexpr double kWireHeight_mm = 1.2;

struct TrueCamera
{
    IntrinsicCalibration intrinsics;
    cv::Vec3d rvec;
    cv::Vec3d tvec_mm;
};

// A camera beside the board at about 45 cm, looking at the bull from the given direction
TrueCamera trueCamera (DistortionModel model, double azimuth_deg, double cx_px)
{
    TrueCamera camera;
    camera.intrinsics.model = model;
    camera.intrinsics.image_size_px = cv::Size(1280, 720);
    camera.intrinsics.camera_matrix = cv::Matx33d(735, 0, cx_px, 0, 735, 352, 0, 0, 1);
    camera.intrinsics.dist_coeffs = model == DistortionModel::Fisheye ? cv::Mat(cv::Matx41d(0.45, 0.25, -0.23, -0.54))
                                                                      : cv::Mat(cv::Matx<double, 5, 1>(-0.30, 0.10, 0, 0, -0.01));
    // Look along -z of the board from a point above and in front, tilted 60 degrees off the board normal
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

std::vector<cv::Point2f> projectWithOpenCv (const TrueCamera& camera, const std::vector<cv::Point3f>& points)
{
    std::vector<cv::Point2f> image;
    const cv::Mat k(camera.intrinsics.camera_matrix);
    if(camera.intrinsics.model == DistortionModel::Fisheye)
    {
        std::vector<cv::Point3d> points_d(points.begin(), points.end());
        std::vector<cv::Point2d> image_d;
        cv::fisheye::projectPoints(points_d, image_d, cv::Mat(camera.rvec), cv::Mat(camera.tvec_mm), k, camera.intrinsics.dist_coeffs);
        image.assign(image_d.begin(), image_d.end());
    }
    else
    {
        cv::projectPoints(points, camera.rvec, camera.tvec_mm, k, camera.intrinsics.dist_coeffs, image);
    }
    return image;
}

// The 60 board points as the detection and orientBoard deliver them: image points of the real board, board points at
// the nominal positions. A little noise, seeded, so the test is repeatable.
std::vector<BoardCorrespondence> observe (const TrueCamera& camera, int seed, double edge_offset_mm = kEdgeOffset_mm)
{
    const std::array<double, 3> nominal = {15.9, 103.0, 166.0}, real = {kOuterBull_mm, kTreble_mm, kDouble_mm};
    std::vector<cv::Point3f> seen;
    std::vector<cv::Point2f> board;
    for(int wire = 0; wire < 20; ++wire)
    {
        const double angle = (9.0 + 18.0 * wire) * CV_PI / 180.0;
        for(int circle = 0; circle < 3; ++circle)
        {
            // The detected edge lies beside the wire, alternately to either side
            const double side_mm = (wire % 2 == 0 ? 1.0 : -1.0) * edge_offset_mm;
            const double shifted = angle + std::asin(side_mm / real[circle]);
            seen.emplace_back(real[circle] * std::cos(shifted), real[circle] * std::sin(shifted), kWireHeight_mm);
            board.emplace_back(nominal[circle] * std::cos(angle), nominal[circle] * std::sin(angle));
        }
    }
    const auto image = projectWithOpenCv(camera, seen);
    cv::RNG rng(seed);
    std::vector<BoardCorrespondence> correspondences;
    for(std::size_t i = 0; i < image.size(); ++i)
    {
        const cv::Point2f noise(static_cast<float>(rng.gaussian(0.2)), static_cast<float>(rng.gaussian(0.2)));
        correspondences.push_back({image[i] + noise, board[i], 0.3});
    }
    return correspondences;
}

// The model prior: the lens of another unit, off by the spreads of ADR 0006
dartpilot::geometry::IntrinsicsPrior otherUnitPrior (const TrueCamera& camera)
{
    IntrinsicCalibration other = camera.intrinsics;
    other.camera_matrix(0, 0) *= 1.015;
    other.camera_matrix(1, 1) *= 1.015;
    other.camera_matrix(0, 2) += 15.0;
    other.camera_matrix(1, 2) -= 10.0;
    return dartpilot::geometry::priorFromCalibration(other, IntrinsicsSource::ModelPrior);
}

struct Rig
{
    std::vector<TrueCamera> cameras;
    std::vector<RefinementInput> inputs;
};

Rig threeCameras (DistortionModel model)
{
    Rig rig;
    const std::array<double, 3> azimuths_deg = {-90.0, 30.0, 150.0};
    for(int c = 0; c < 3; ++c)
    {
        rig.cameras.push_back(trueCamera(model, azimuths_deg[c], 620.0 + 20.0 * c));
        RefinementInput input;
        input.usb_port = "1." + std::to_string(c + 2);
        input.correspondences = observe(rig.cameras.back(), c + 1);
        input.prior = otherUnitPrior(rig.cameras.back());
        rig.inputs.push_back(input);
    }
    return rig;
}

// Board points on the playing surface over the scoring area, where darts land
std::vector<cv::Point3f> scoringArea ()
{
    std::vector<cv::Point3f> points;
    for(const double r_mm : {0.0, 30.0, 80.0, 120.0, 165.0})
    {
        for(int i = 0; i < 8; ++i)
        {
            const double angle = (22.5 + 45.0 * i) * CV_PI / 180.0;
            points.emplace_back(r_mm * std::cos(angle), r_mm * std::sin(angle), 0.0f);
        }
    }
    return points;
}

void expectAccurate (DistortionModel model)
{
    const Rig rig = threeCameras(model);
    const auto refinement = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(refinement);
    EXPECT_NEAR(refinement->board.radii_mm[0], kOuterBull_mm, 0.15);
    EXPECT_NEAR(refinement->board.radii_mm[1], kTreble_mm, 0.15);
    EXPECT_DOUBLE_EQ(refinement->board.radii_mm[2], kDouble_mm);
    ASSERT_EQ(refinement->cameras.size(), 3u);
    for(std::size_t c = 0; c < 3; ++c)
    {
        const auto& camera = refinement->cameras[c];
        EXPECT_NEAR(camera.edge_offset_mm, kEdgeOffset_mm, 0.1);
        // Includes the noise of the held-out points themselves, about 0.3 mm at this viewing angle
        EXPECT_LT(camera.held_out_rms_mm, 0.45);
        EXPECT_LT(camera.uncertainty_mm, 0.3);
        EXPECT_GT(camera.uncertainty_mm, 0.0);
        // A dart tip seen by this camera lands where it really is.
        const auto area = scoringArea();
        const auto image = projectWithOpenCv(rig.cameras[c], area);
        for(std::size_t i = 0; i < area.size(); ++i)
        {
            const cv::Point2f board = dartpilot::geometry::imageToBoard(camera, image[i]);
            EXPECT_LT(cv::norm(board - cv::Point2f(area[i].x, area[i].y)), 0.3) << "camera " << c << " point " << area[i];
        }
    }
}
}  // namespace

TEST(BoardRefinement, RecoversCamerasAndBoardWithFisheyeLenses) { expectAccurate(DistortionModel::Fisheye); }

TEST(BoardRefinement, RecoversCamerasAndBoardWithStandardLenses) { expectAccurate(DistortionModel::Standard); }

TEST(BoardRefinement, WorksWithoutAnyLensCalibration)
{
    Rig rig = threeCameras(DistortionModel::Standard);
    for(auto& input : rig.inputs)
    {
        input.prior = dartpilot::geometry::boardOnlyPrior(cv::Size(1280, 720));
    }
    const auto refinement = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(refinement);
    for(const auto& camera : refinement->cameras)
    {
        EXPECT_EQ(camera.source, IntrinsicsSource::BoardOnly);
        EXPECT_LT(camera.held_out_rms_mm, 0.5);
    }
}

TEST(BoardRefinement, IsDeterministic)
{
    const Rig rig = threeCameras(DistortionModel::Fisheye);
    const auto a = dartpilot::geometry::refineBoardCameras(rig.inputs);
    const auto b = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(a && b);
    EXPECT_EQ(a->board.radii_mm, b->board.radii_mm);
    for(std::size_t c = 0; c < a->cameras.size(); ++c)
    {
        EXPECT_EQ(a->cameras[c].rvec, b->cameras[c].rvec);
        EXPECT_EQ(a->cameras[c].tvec_mm, b->cameras[c].tvec_mm);
        EXPECT_EQ(a->cameras[c].held_out_rms_mm, b->cameras[c].held_out_rms_mm);
    }
}

TEST(BoardRefinement, NeedsEightPointsPerCamera)
{
    Rig rig = threeCameras(DistortionModel::Fisheye);
    rig.inputs[1].correspondences.resize(7);
    EXPECT_FALSE(dartpilot::geometry::refineBoardCameras(rig.inputs));
    EXPECT_FALSE(dartpilot::geometry::refineBoardCameras({}));
}

TEST(BoardRefinement, SavesAndLoads)
{
    const Rig rig = threeCameras(DistortionModel::Fisheye);
    const auto refinement = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(refinement);
    dartpilot::geometry::StoredExtrinsics stored{"2026-10-24T12:00:00Z", *refinement, rig.inputs};
    stored.inputs[0].board_plane_created = "2026-10-24T11:00:00Z";
    const std::string path = (std::filesystem::temp_directory_path() / ("dartpilot-extrinsics-" + std::to_string(::getpid()) + ".yml")).string();
    ASSERT_TRUE(dartpilot::geometry::saveExtrinsics(path, stored));
    const auto loaded = dartpilot::geometry::loadExtrinsics(path);
    std::filesystem::remove(path);
    ASSERT_TRUE(loaded);
    EXPECT_EQ(loaded->created, stored.created);
    EXPECT_EQ(loaded->refinement.board.radii_mm, refinement->board.radii_mm);
    ASSERT_EQ(loaded->refinement.cameras.size(), 3u);
    ASSERT_EQ(loaded->inputs.size(), 3u);
    EXPECT_EQ(loaded->inputs[0].board_plane_created, "2026-10-24T11:00:00Z");
    EXPECT_EQ(loaded->inputs[2].correspondences.size(), 60u);
    EXPECT_EQ(loaded->inputs[1].prior.source, IntrinsicsSource::ModelPrior);
    for(std::size_t c = 0; c < 3; ++c)
    {
        const auto& a = refinement->cameras[c];
        const auto& b = loaded->refinement.cameras[c];
        EXPECT_EQ(b.usb_port, a.usb_port);
        EXPECT_EQ(b.intrinsics.model, DistortionModel::Fisheye);
        EXPECT_DOUBLE_EQ(b.held_out_rms_mm, a.held_out_rms_mm);
        EXPECT_DOUBLE_EQ(b.edge_offset_mm, a.edge_offset_mm);
        // The loaded camera maps image points exactly like the refined one.
        const cv::Point2f p = dartpilot::geometry::imageToBoard(a, cv::Point2f(640, 360));
        const cv::Point2f q = dartpilot::geometry::imageToBoard(b, cv::Point2f(640, 360));
        EXPECT_LT(cv::norm(p - q), 1e-6);
    }
    EXPECT_FALSE(dartpilot::geometry::loadExtrinsics(path));
}

namespace
{
// The detection the setup GUI would make of this camera: the observed points, wires counted from board wire 0
dartpilot::geometry::BoardDetection detectionOf (const std::vector<BoardCorrespondence>& correspondences)
{
    dartpilot::geometry::BoardDetection detection;
    for(std::size_t i = 0; i < correspondences.size(); ++i)
    {
        detection.points.push_back({static_cast<int>(i / 3), static_cast<dartpilot::geometry::BoardCircle>(i % 3), correspondences[i].image_px, 0.3});
    }
    return detection;
}
}  // namespace

TEST(CalibrationCheck, AnUnmovedCameraMatchesAndFindsSectorTwentyByItself)
{
    const Rig rig = threeCameras(DistortionModel::Fisheye);
    const auto refinement = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(refinement);
    const auto check = dartpilot::geometry::checkCalibration(detectionOf(observe(rig.cameras[1], 7)), refinement->cameras[1], refinement->board);
    ASSERT_TRUE(check);
    // Board wire k borders sector 20 for k = 4 (docs/board-coordinates.md), and the wires were counted from wire 0.
    EXPECT_EQ(check->twenty_sector, 4);
    EXPECT_EQ(check->points, 60);
    EXPECT_LT(check->rms_mm, 0.5);
    EXPECT_EQ(check->predicted_px.size(), 60u);
}

TEST(CalibrationCheck, OtherLightIsNotTakenForAMovedCamera)
{
    const Rig rig = threeCameras(DistortionModel::Fisheye);
    const auto refinement = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(refinement);
    const auto check =
        dartpilot::geometry::checkCalibration(detectionOf(observe(rig.cameras[0], 7, -0.2)), refinement->cameras[0], refinement->board);
    ASSERT_TRUE(check);
    EXPECT_NEAR(check->edge_offset_mm, -0.2, 0.1);
    EXPECT_LT(check->rms_mm, 0.5);
}

TEST(CalibrationCheck, NoticesAMovedOrSwappedCamera)
{
    const Rig rig = threeCameras(DistortionModel::Fisheye);
    const auto refinement = dartpilot::geometry::refineBoardCameras(rig.inputs);
    ASSERT_TRUE(refinement);
    // Knocked: the camera tilts by 1 degree about its own centre.
    TrueCamera knocked = rig.cameras[2];
    cv::Matx33d tilt, rotation;
    cv::Rodrigues(cv::Vec3d(1.0 * CV_PI / 180.0, 0.0, 0.0), tilt);
    cv::Rodrigues(knocked.rvec, rotation);
    cv::Rodrigues(tilt * rotation, knocked.rvec);
    knocked.tvec_mm = tilt * knocked.tvec_mm;
    const auto moved = dartpilot::geometry::checkCalibration(detectionOf(observe(knocked, 7)), refinement->cameras[2], refinement->board);
    ASSERT_TRUE(moved);
    EXPECT_GT(moved->rms_mm, 3.0);
    EXPECT_GT(cv::norm(moved->mean_shift_px), 5.0);
    // The image of camera 3 against the calibration of camera 1
    const auto swapped = dartpilot::geometry::checkCalibration(detectionOf(observe(rig.cameras[2], 7)), refinement->cameras[0], refinement->board);
    ASSERT_TRUE(swapped);
    EXPECT_GT(swapped->rms_mm, 10.0);
    EXPECT_FALSE(dartpilot::geometry::checkCalibration({}, refinement->cameras[0], refinement->board));
}
