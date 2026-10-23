#include "dartpilot/geometry/intrinsics.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

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

namespace
{
constexpr std::string_view kFormat = "dartpilot-intrinsics-1";

int coefficientCount (DistortionModel model)
{
    switch(model)
    {
        case DistortionModel::Fisheye:
            return 4;
        case DistortionModel::Standard:
            return 5;
        case DistortionModel::Rational:
            return 8;
    }
    return 5;
}

// Projects a view with fixed intrinsics after estimating only its pose from the same points.
std::optional<std::vector<cv::Point2f>> reproject (const CalibrationView& view, const IntrinsicCalibration& calibration)
{
    std::vector<cv::Point2f> projected;
    cv::Vec3d rvec, tvec;
    if(calibration.model == DistortionModel::Fisheye)
    {
        // The pose is solved on undistorted, normalised points, then projected through the fisheye model.
        std::vector<cv::Point2f> normalised;
        cv::fisheye::undistortPoints(view.image_points_px, normalised, calibration.camera_matrix, calibration.dist_coeffs);
        if(!cv::solvePnP(view.object_points, normalised, cv::Matx33d::eye(), cv::noArray(), rvec, tvec, false, cv::SOLVEPNP_IPPE))
        {
            return std::nullopt;
        }
        cv::fisheye::projectPoints(view.object_points, projected, rvec, tvec, calibration.camera_matrix, calibration.dist_coeffs);
    }
    else
    {
        if(!cv::solvePnP(view.object_points, view.image_points_px, calibration.camera_matrix, calibration.dist_coeffs, rvec, tvec, false,
                         cv::SOLVEPNP_IPPE))
        {
            return std::nullopt;
        }
        cv::projectPoints(view.object_points, rvec, tvec, calibration.camera_matrix, calibration.dist_coeffs, projected);
    }
    return projected;
}
}  // namespace

std::optional<HeldOutValidation> validateIntrinsics (const std::vector<CalibrationView>& views, const cv::Size& image_size_px, DistortionModel model,
                                                     int folds)
{
    folds = std::min<int>(folds, static_cast<int>(views.size()));
    if(folds < 2 || static_cast<int>(views.size()) - (static_cast<int>(views.size()) + folds - 1) / folds < static_cast<int>(kMinViews) ||
       image_size_px.width <= 0 || image_size_px.height <= 0)
    {
        return std::nullopt;
    }
    constexpr int kGrid = HeldOutValidation::kRegionGrid;
    std::array<double, kGrid * kGrid> region_sum_sq{};
    HeldOutValidation result;
    result.folds = folds;
    double sum_sq = 0.0;
    int points = 0;
    try
    {
        for(int fold = 0; fold < folds; ++fold)
        {
            std::vector<CalibrationView> training;
            for(std::size_t i = 0; i < views.size(); ++i)
            {
                if(static_cast<int>(i % folds) != fold)
                {
                    training.push_back(views[i]);
                }
            }
            const auto calibration = calibrateIntrinsics(training, image_size_px, model);
            if(!calibration)
            {
                return std::nullopt;
            }
            for(std::size_t i = fold; i < views.size(); i += folds)
            {
                const auto projected = reproject(views[i], *calibration);
                if(!projected)
                {
                    return std::nullopt;
                }
                for(std::size_t k = 0; k < projected->size(); ++k)
                {
                    const cv::Point2f measured = views[i].image_points_px[k];
                    const cv::Point2f d = measured - (*projected)[k];
                    const double error_sq = d.x * d.x + d.y * d.y;
                    const int col = std::clamp(static_cast<int>(measured.x * kGrid / image_size_px.width), 0, kGrid - 1);
                    const int row = std::clamp(static_cast<int>(measured.y * kGrid / image_size_px.height), 0, kGrid - 1);
                    region_sum_sq[row * kGrid + col] += error_sq;
                    ++result.region_points[row * kGrid + col];
                    sum_sq += error_sq;
                    ++points;
                }
            }
        }
    }
    catch(const cv::Exception&)
    {
        return std::nullopt;
    }
    if(points == 0)
    {
        return std::nullopt;
    }
    result.rms_px = std::sqrt(sum_sq / points);
    for(std::size_t r = 0; r < region_sum_sq.size(); ++r)
    {
        result.region_rms_px[r] =
            result.region_points[r] > 0 ? std::sqrt(region_sum_sq[r] / result.region_points[r]) : std::numeric_limits<double>::quiet_NaN();
    }
    return result;
}

std::optional<DistortionModel> recommendModel (const std::vector<std::pair<DistortionModel, HeldOutValidation>>& validations, double tolerance)
{
    if(validations.empty())
    {
        return std::nullopt;
    }
    double best_rms_px = std::numeric_limits<double>::infinity();
    for(const auto& [model, validation] : validations)
    {
        best_rms_px = std::min(best_rms_px, validation.rms_px);
    }
    std::optional<DistortionModel> choice;
    for(const auto& [model, validation] : validations)
    {
        if(validation.rms_px <= best_rms_px * (1.0 + tolerance) && (!choice || coefficientCount(model) < coefficientCount(*choice)))
        {
            choice = model;
        }
    }
    return choice;
}

bool saveIntrinsics (const std::string& path, const IntrinsicCalibration& calibration, const CalibrationInfo& info,
                     const std::vector<CalibrationView>& views, const std::optional<HeldOutValidation>& validation)
{
    try
    {
        cv::FileStorage file(path, cv::FileStorage::WRITE);
        if(!file.isOpened())
        {
            return false;
        }
        file << "format" << std::string(kFormat);
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
        if(validation)
        {
            file << "held_out_folds" << validation->folds;
            file << "held_out_rms_px" << validation->rms_px;
            file << "held_out_region_rms_px" << std::vector<double>(validation->region_rms_px.begin(), validation->region_rms_px.end());
            file << "held_out_region_points" << std::vector<int>(validation->region_points.begin(), validation->region_points.end());
        }
        return true;
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}
std::optional<StoredIntrinsics> loadIntrinsics (const std::string& path)
{
    try
    {
        cv::FileStorage file(path, cv::FileStorage::READ);
        if(!file.isOpened() || static_cast<std::string>(file["format"]) != kFormat)
        {
            return std::nullopt;
        }
        StoredIntrinsics stored;
        const auto model = parseDistortionModel(static_cast<std::string>(file["model"]));
        if(!model)
        {
            return std::nullopt;
        }
        auto& calibration = stored.calibration;
        calibration.model = *model;
        calibration.image_size_px = cv::Size(static_cast<int>(file["image_width_px"]), static_cast<int>(file["image_height_px"]));
        cv::Mat camera_matrix;
        file["camera_matrix"] >> camera_matrix;
        if(camera_matrix.rows != 3 || camera_matrix.cols != 3)
        {
            return std::nullopt;
        }
        calibration.camera_matrix = cv::Matx33d(camera_matrix);
        file["dist_coeffs"] >> calibration.dist_coeffs;
        calibration.rms_px = static_cast<double>(file["rms_px"]);
        file["per_view_rms_px"] >> calibration.per_view_rms_px;
        file["std_deviations"] >> calibration.std_deviations;

        stored.info.created = static_cast<std::string>(file["created"]);
        stored.info.usb_port = static_cast<std::string>(file["usb_port"]);
        stored.info.camera_name = static_cast<std::string>(file["camera_name"]);
        stored.info.pixel_format = static_cast<std::string>(file["pixel_format"]);
        stored.info.target = static_cast<std::string>(file["target"]);

        for(const auto& node : file["views"])
        {
            CalibrationView view;
            node["ids"] >> view.ids;
            node["object_points"] >> view.object_points;
            node["image_points_px"] >> view.image_points_px;
            stored.views.push_back(std::move(view));
        }

        if(!file["held_out_rms_px"].empty())
        {
            HeldOutValidation validation;
            validation.folds = static_cast<int>(file["held_out_folds"]);
            validation.rms_px = static_cast<double>(file["held_out_rms_px"]);
            std::vector<double> region_rms_px;
            std::vector<int> region_points;
            file["held_out_region_rms_px"] >> region_rms_px;
            file["held_out_region_points"] >> region_points;
            if(region_rms_px.size() != validation.region_rms_px.size() || region_points.size() != validation.region_points.size())
            {
                return std::nullopt;
            }
            std::copy(region_rms_px.begin(), region_rms_px.end(), validation.region_rms_px.begin());
            std::copy(region_points.begin(), region_points.end(), validation.region_points.begin());
            stored.validation = validation;
        }
        return stored;
    }
    catch(const cv::Exception&)
    {
        return std::nullopt;
    }
}
}  // namespace dartpilot::geometry
