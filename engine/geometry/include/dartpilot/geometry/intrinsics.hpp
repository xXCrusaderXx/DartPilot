#pragma once

#include <optional>
#include <string>
#include <string_view>
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

// Writes calibration, info and views as OpenCV YAML, so the calibration can be recomputed from the stored views.
bool saveIntrinsics (const std::string& path, const IntrinsicCalibration& calibration, const CalibrationInfo& info,
                     const std::vector<CalibrationView>& views);
}  // namespace dartpilot::geometry
