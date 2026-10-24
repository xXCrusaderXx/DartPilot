#pragma once

#include <array>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/intrinsics.hpp"

// Joint refinement of all cameras against one board model (#13, ADR 0006): per camera the pose, focal length,
// principal point and distortion, for all cameras together the radii of the board.
namespace dartpilot::geometry
{
// The board as measured. The double ring is the scale reference and keeps its nominal radius.
struct BoardModel
{
    std::array<double, kBoardCircleCount> radii_mm = kBoardCircleRadii_mm;
    // The detected points lie on the wires, which stand this high above the playing surface (docs/board-coordinates.md)
    double wire_height_mm = 1.2;
};

// What the intrinsics of a camera start from
enum class IntrinsicsSource
{
    // A ChArUco calibration of this camera
    OwnCalibration,
    // The calibration of another camera of the same model
    ModelPrior,
    // No calibration: focal length from the board, principal point at the image centre, no distortion to start with
    BoardOnly,
};

std::string_view toString (IntrinsicsSource source);
std::optional<IntrinsicsSource> parseIntrinsicsSource (std::string_view name);

// Starting intrinsics of a camera and how far the refinement may move them; a deviation of zero keeps a value fixed.
struct IntrinsicsPrior
{
    IntrinsicsSource source = IntrinsicsSource::BoardOnly;
    // Only the model, image size, camera matrix and distortion coefficients are used.
    IntrinsicCalibration intrinsics;
    // Of the focal length, relative (0.01 is 1 %)
    double focal_sigma = 0.0;
    double principal_sigma_px = 0.0;
    // One per distortion coefficient
    std::vector<double> distortion_sigma;
};

// The prior from a calibration of this camera or of another camera of the same model, with the spreads of ADR 0006.
IntrinsicsPrior priorFromCalibration (const IntrinsicCalibration& calibration, IntrinsicsSource source);
// For a camera without any calibration; the focal length is taken from the board plane when the refinement starts.
IntrinsicsPrior boardOnlyPrior (const cv::Size& image_size_px);

struct RefinementInput
{
    std::string usb_port;
    // Board points at their nominal positions, as orientBoard gives them
    std::vector<BoardCorrespondence> correspondences;
    IntrinsicsPrior prior;
    // Which stored calibrations the input comes from, for the record; set by the caller
    std::string board_plane_created;
    std::string intrinsics_created;
};

struct RefinedCamera
{
    std::string usb_port;
    IntrinsicsSource source = IntrinsicsSource::BoardOnly;
    // rms_px is the reprojection error of the board points; std_deviations holds fx, fy, cx, cy and the distortion
    // coefficients, zero where a value was fixed.
    IntrinsicCalibration intrinsics;
    // Board to camera: the board point X (mm) lies at R(rvec) X + tvec_mm in the camera frame.
    cv::Vec3d rvec;
    cv::Vec3d tvec_mm;
    // How far the detected wire edges lie beside the wire centre lines, alternately to either side of successive
    // wires: the bright wire shifts the light/dark transition towards the dark sector.
    double edge_offset_mm = 0.0;
    // Detected points back-projected onto the wire plane, against the board model
    double rms_mm = 0.0;
    double worst_mm = 0.0;
    // The same for points the refinement did not see: the wires are split into folds and each fold is held out once.
    // Unlike rms_mm, this does not shrink when the lens model bends to fit its own points.
    double held_out_rms_mm = 0.0;
    // 1-sigma position error of a board point caused by the uncertainty of this camera's parameters, RMS and maximum
    // over the scoring area
    double uncertainty_mm = 0.0;
    double worst_uncertainty_mm = 0.0;
    int points = 0;
    // Points far off the fit, down-weighted
    int outliers = 0;
};

struct BoardRefinement
{
    BoardModel board;
    // Zero for the double ring, the scale reference
    std::array<double, kBoardCircleCount> radius_sigma_mm{};
    // In the order of the inputs
    std::vector<RefinedCamera> cameras;
    int iterations = 0;
};

// Needs at least eight points per camera; returns nothing if a camera cannot be posed. Deterministic: the same inputs
// give the same result.
std::optional<BoardRefinement> refineBoardCameras (const std::vector<RefinementInput>& inputs, const BoardModel& start = {});

// Image point of a board point, and board point on the playing surface (z = 0) seen at an image point
cv::Point2f boardToImage (const RefinedCamera& camera, const cv::Point3f& board_mm);
cv::Point2f imageToBoard (const RefinedCamera& camera, const cv::Point2f& image_px);
// The camera's centre in board coordinates, and the unit direction of the ray through an image point
cv::Vec3d cameraCentre (const RefinedCamera& camera);
cv::Vec3d viewRay (const RefinedCamera& camera, const cv::Point2f& image_px);

// How well a camera's stored calibration still explains the board it sees now: every newly detected point is compared
// with where the calibration puts it. A camera that was moved, knocked or plugged into another port shows a large error.
struct CalibrationCheck
{
    // The image sector of the detection that is sector 20, found from the calibration: no click needed
    int twenty_sector = 0;
    int points = 0;
    // Detected against predicted image points
    double rms_px = 0.0;
    double worst_px = 0.0;
    // Detected points back-projected onto the wire plane, against the board model
    double rms_mm = 0.0;
    // The edge offset of the detection under the current light, measured again (see RefinedCamera::edge_offset_mm)
    double edge_offset_mm = 0.0;
    // Mean displacement of the detected points from the predicted ones; a camera that moved shifts them all alike
    cv::Point2f mean_shift_px;
    // Where the calibration puts each detected point, in the order of detection.points
    std::vector<cv::Point2f> predicted_px;
};

// Nothing for a detection without points. The board must be the one the refinement measured.
std::optional<CalibrationCheck> checkCalibration (const BoardDetection& detection, const RefinedCamera& camera, const BoardModel& board);

struct StoredExtrinsics
{
    // Set by the caller; the geometry module never reads the clock
    std::string created;
    BoardRefinement refinement;
    // Kept, so the refinement can be recomputed and checked against the board planes and intrinsics it used
    std::vector<RefinementInput> inputs;
};

bool saveExtrinsics (const std::string& path, const StoredExtrinsics& extrinsics);
std::optional<StoredExtrinsics> loadExtrinsics (const std::string& path);
}  // namespace dartpilot::geometry
