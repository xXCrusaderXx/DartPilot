#pragma once

#include <array>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include <opencv2/core.hpp>

// Intrinsic camera calibration from views of a planar target.
namespace dartpilot::geometry
{
enum class DistortionModel
{
    // k1, k2, p1, p2, k3
    Standard,
    // Standard plus k4, k5, k6, for wide lenses
    Rational,
    // OpenCV fisheye model, k1..k4
    Fisheye,
};

std::string_view toString (DistortionModel model);
std::optional<DistortionModel> parseDistortionModel (std::string_view name);

// Target corners seen in one image. Object points are in target units (square lengths for ChArUco):
// the scale of the target does not affect the intrinsics.
struct CalibrationView
{
    std::vector<int> ids;
    std::vector<cv::Point3f> object_points;
    std::vector<cv::Point2f> image_points_px;
};

struct IntrinsicCalibration
{
    DistortionModel model = DistortionModel::Standard;
    cv::Size image_size_px;
    cv::Matx33d camera_matrix;
    cv::Mat dist_coeffs;
    double rms_px = 0.0;
    std::vector<double> per_view_rms_px;
    // Standard deviations of fx, fy, cx, cy and the distortion coefficients; empty for the fisheye model
    std::vector<double> std_deviations;
};

// Needs at least three views with six or more points each. Returns nothing if OpenCV rejects the data.
std::optional<IntrinsicCalibration> calibrateIntrinsics (const std::vector<CalibrationView>& views, const cv::Size& image_size_px,
                                                         DistortionModel model);

// Reprojection error on views that the calibration did not see: the views are split into folds, each fold is held out
// once, the camera is calibrated on the others, and the held-out views are projected with the result. Unlike the RMS
// of the calibration itself, this does not shrink when a model overfits its own views.
struct HeldOutValidation
{
    static constexpr int kRegionGrid = 3;
    double rms_px = 0.0;
    // RMS per region of a 3x3 grid over the image, row by row; NaN where a region has no held-out points
    std::array<double, kRegionGrid * kRegionGrid> region_rms_px{};
    std::array<int, kRegionGrid * kRegionGrid> region_points{};
    int folds = 0;
};

// Deterministic: view i belongs to fold i % folds. Needs at least three views per training set; returns nothing
// if there are too few views or a fold cannot be calibrated.
std::optional<HeldOutValidation> validateIntrinsics (const std::vector<CalibrationView>& views, const cv::Size& image_size_px, DistortionModel model,
                                                     int folds = 5);

// The model to use from held-out errors: the one with the fewest coefficients whose error is within tolerance of the
// best (fisheye 4, standard 5, rational 8), so a model with more parameters has to earn them.
std::optional<DistortionModel> recommendModel (const std::vector<std::pair<DistortionModel, HeldOutValidation>>& validations,
                                               double tolerance = 0.05);

// Identifies the camera and capture settings a calibration is valid for.
struct CalibrationInfo
{
    std::string usb_port;
    std::string camera_name;
    std::string pixel_format;
    std::string target;
    // Set by the caller; the geometry module never reads the clock
    std::string created;
};

// Writes calibration, info, views and, if given, the held-out validation as OpenCV YAML, so the calibration can be
// recomputed from the stored views.
bool saveIntrinsics (const std::string& path, const IntrinsicCalibration& calibration, const CalibrationInfo& info,
                     const std::vector<CalibrationView>& views, const std::optional<HeldOutValidation>& validation = std::nullopt);

struct StoredIntrinsics
{
    IntrinsicCalibration calibration;
    CalibrationInfo info;
    std::vector<CalibrationView> views;
    std::optional<HeldOutValidation> validation;
};

// Reads a file written by saveIntrinsics; nothing if it is missing, unreadable or of another format.
std::optional<StoredIntrinsics> loadIntrinsics (const std::string& path);
}  // namespace dartpilot::geometry
