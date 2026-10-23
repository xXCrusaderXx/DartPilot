#include "dartpilot/geometry/intrinsics.hpp"

#include <algorithm>
#include <cmath>

#include <opencv2/calib3d.hpp>

namespace dartpilot::geometry
{
namespace
{
constexpr std::size_t kMinViews = 3;
constexpr std::size_t kMinPointsPerView = 6;

double rms (const std::vector<cv::Point2f>& measured, const std::vector<cv::Point2f>& projected)
{
    double sum_sq = 0.0;
    for(std::size_t i = 0; i < measured.size(); ++i)
    {
        const cv::Point2f d = measured[i] - projected[i];
        sum_sq += d.x * d.x + d.y * d.y;
    }
    return measured.empty() ? 0.0 : std::sqrt(sum_sq / measured.size());
}

std::optional<IntrinsicCalibration> calibratePinhole (const std::vector<std::vector<cv::Point3f>>& object_points,
                                                      const std::vector<std::vector<cv::Point2f>>& image_points, const cv::Size& image_size_px,
                                                      DistortionModel model)
{
    IntrinsicCalibration result;
    result.model = model;
    result.image_size_px = image_size_px;
    cv::Mat camera_matrix, dist_coeffs, std_intrinsics, std_extrinsics, per_view;
    std::vector<cv::Mat> rvecs, tvecs;
    const int flags = model == DistortionModel::Rational ? cv::CALIB_RATIONAL_MODEL : 0;
    result.rms_px = cv::calibrateCamera(object_points, image_points, image_size_px, camera_matrix, dist_coeffs, rvecs, tvecs, std_intrinsics,
                                        std_extrinsics, per_view, flags);
    result.camera_matrix = cv::Matx33d(camera_matrix);
    // OpenCV may return up to 14 coefficients; the ones beyond the model are fixed at zero.
    const int coefficient_count = std::min(model == DistortionModel::Rational ? 8 : 5, static_cast<int>(dist_coeffs.total()));
    result.dist_coeffs = dist_coeffs.reshape(1, 1).colRange(0, coefficient_count).clone();
    result.per_view_rms_px.assign(per_view.begin<double>(), per_view.end<double>());
    // calibrateCamera reports 18 intrinsic deviations: fx, fy, cx, cy, then the coefficients in order
    const std::size_t estimated = 4 + static_cast<std::size_t>(coefficient_count);
    for(std::size_t i = 0; i < estimated && i < std_intrinsics.total(); ++i)
    {
        result.std_deviations.push_back(std_intrinsics.at<double>(static_cast<int>(i)));
    }
    return result;
}

std::optional<IntrinsicCalibration> calibrateFisheye (const std::vector<std::vector<cv::Point3f>>& object_points,
                                                      const std::vector<std::vector<cv::Point2f>>& image_points, const cv::Size& image_size_px)
{
    IntrinsicCalibration result;
    result.model = DistortionModel::Fisheye;
    result.image_size_px = image_size_px;
    cv::Matx33d camera_matrix;
    cv::Vec4d dist_coeffs;
    std::vector<cv::Vec3d> rvecs, tvecs;
    const int flags = cv::fisheye::CALIB_RECOMPUTE_EXTRINSIC | cv::fisheye::CALIB_FIX_SKEW;
    result.rms_px = cv::fisheye::calibrate(object_points, image_points, image_size_px, camera_matrix, dist_coeffs, rvecs, tvecs, flags,
                                           cv::TermCriteria(cv::TermCriteria::COUNT + cv::TermCriteria::EPS, 100, 1e-10));
    result.camera_matrix = camera_matrix;
    result.dist_coeffs = cv::Mat(dist_coeffs, true);
    for(std::size_t v = 0; v < object_points.size(); ++v)
    {
        std::vector<cv::Point2f> projected;
        cv::fisheye::projectPoints(object_points[v], projected, rvecs[v], tvecs[v], camera_matrix, dist_coeffs);
        result.per_view_rms_px.push_back(rms(image_points[v], projected));
    }
    return result;
}
}  // namespace

std::string_view toString (DistortionModel model)
{
    switch(model)
    {
        case DistortionModel::Standard:
            return "standard";
        case DistortionModel::Rational:
            return "rational";
        case DistortionModel::Fisheye:
            return "fisheye";
    }
    return "standard";
}

std::optional<DistortionModel> parseDistortionModel (std::string_view name)
{
    for(const auto model : {DistortionModel::Standard, DistortionModel::Rational, DistortionModel::Fisheye})
    {
        if(toString(model) == name)
        {
            return model;
        }
    }
    return std::nullopt;
}

std::optional<IntrinsicCalibration> calibrateIntrinsics (const std::vector<CalibrationView>& views, const cv::Size& image_size_px,
                                                         DistortionModel model)
{
    std::vector<std::vector<cv::Point3f>> object_points;
    std::vector<std::vector<cv::Point2f>> image_points;
    for(const auto& view : views)
    {
        if(view.object_points.size() >= kMinPointsPerView && view.object_points.size() == view.image_points_px.size())
        {
            object_points.push_back(view.object_points);
            image_points.push_back(view.image_points_px);
        }
    }
    if(object_points.size() < kMinViews || object_points.size() != views.size())
    {
        return std::nullopt;
    }
    try
    {
        return model == DistortionModel::Fisheye ? calibrateFisheye(object_points, image_points, image_size_px)
                                                 : calibratePinhole(object_points, image_points, image_size_px, model);
    }
    catch(const cv::Exception&)
    {
        return std::nullopt;
    }
}

bool saveIntrinsics (const std::string& path, const IntrinsicCalibration& calibration, const CalibrationInfo& info,
                     const std::vector<CalibrationView>& views)
{
    try
    {
        cv::FileStorage file(path, cv::FileStorage::WRITE);
        if(!file.isOpened())
        {
            return false;
        }
        file << "format" << "dartpilot-intrinsics-1";
        file << "created" << info.created;
        file << "usb_port" << info.usb_port;
        file << "camera_name" << info.camera_name;
        file << "pixel_format" << info.pixel_format;
        file << "target" << info.target;
        file << "image_width_px" << calibration.image_size_px.width;
        file << "image_height_px" << calibration.image_size_px.height;
        file << "model" << std::string(toString(calibration.model));
        file << "camera_matrix" << cv::Mat(calibration.camera_matrix);
        file << "dist_coeffs" << calibration.dist_coeffs;
        file << "rms_px" << calibration.rms_px;
        file << "per_view_rms_px" << calibration.per_view_rms_px;
        file << "std_deviations" << calibration.std_deviations;
        file << "views" << "[";
        for(const auto& view : views)
        {
            file << "{" << "ids" << view.ids << "object_points" << view.object_points << "image_points_px" << view.image_points_px << "}";
        }
        file << "]";
        return true;
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}
}  // namespace dartpilot::geometry
