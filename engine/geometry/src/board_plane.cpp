#include "dartpilot/geometry/board_plane.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>

#include <opencv2/calib3d.hpp>

namespace dartpilot::geometry
{
namespace
{
constexpr std::string_view kFormat = "dartpilot-board-plane-1";
constexpr double kSectorWidth_deg = 18.0;
// Sector 20 is centred on the +y axis, so its clockwise wire lies at 81 degrees.
constexpr double kTwentyClockwiseWire_deg = 90.0 - kSectorWidth_deg / 2.0;

double imageAngle (const cv::Point2f& from, const cv::Point2f& to) { return std::atan2(-(to.y - from.y), to.x - from.x); }

double wireAngle (const cv::Vec4f& wire) { return std::atan2(-wire[3], wire[2]); }

// Within [0, 2 pi)
double positiveAngle (double angle)
{
    const double wrapped = std::fmod(angle, 2 * CV_PI);
    return wrapped < 0 ? wrapped + 2 * CV_PI : wrapped;
}

std::vector<cv::Point2f> undistortedPoints (const std::vector<cv::Point2f>& points, const IntrinsicCalibration* intrinsics)
{
    if(!intrinsics || points.empty())
    {
        return points;
    }
    std::vector<cv::Point2f> out;
    const cv::Mat k(intrinsics->camera_matrix);
    if(intrinsics->model == DistortionModel::Fisheye)
    {
        cv::fisheye::undistortPoints(points, out, k, intrinsics->dist_coeffs, cv::noArray(), k);
    }
    else
    {
        cv::undistortPoints(points, out, k, intrinsics->dist_coeffs, cv::noArray(), k);
    }
    return out;
}

cv::Point2f apply (const cv::Matx33d& h, const cv::Point2f& p)
{
    const cv::Vec3d q = h * cv::Vec3d(p.x, p.y, 1.0);
    return {static_cast<float>(q[0] / q[2]), static_cast<float>(q[1] / q[2])};
}
}  // namespace

std::optional<int> sectorAt (const BoardDetection& detection, const cv::Point2f& image_px)
{
    const auto& outer = detection.circles[static_cast<int>(BoardCircle::DoubleCentre)];
    const auto& inner = detection.circles[static_cast<int>(BoardCircle::OuterBull)];
    const auto inside = [&] (const cv::RotatedRect& e)
    {
        const double a = e.angle * CV_PI / 180.0, dx = image_px.x - e.center.x, dy = image_px.y - e.center.y;
        const double u = (dx * std::cos(a) + dy * std::sin(a)) / (e.size.width / 2), v = (-dx * std::sin(a) + dy * std::cos(a)) / (e.size.height / 2);
        return u * u + v * v < 1.0;
    };
    if(!inside(outer) || inside(inner))
    {
        return std::nullopt;
    }
    const double point = imageAngle(detection.bull_px, image_px);
    for(int s = 0; s < kRadialWireCount; ++s)
    {
        const double start = wireAngle(detection.wires[s]);
        const double span = positiveAngle(wireAngle(detection.wires[(s + 1) % kRadialWireCount]) - start);
        if(positiveAngle(point - start) < span)
        {
            return s;
        }
    }
    return std::nullopt;
}

std::vector<BoardCorrespondence> orientBoard (const BoardDetection& detection, int twenty_sector)
{
    std::vector<BoardCorrespondence> correspondences;
    for(const auto& point : detection.points)
    {
        // Wires count counter-clockwise in the image, which is counter-clockwise on the board seen from the front.
        const int steps = ((point.wire - twenty_sector) % kRadialWireCount + kRadialWireCount) % kRadialWireCount;
        const double angle = (kTwentyClockwiseWire_deg + kSectorWidth_deg * steps) * CV_PI / 180.0;
        const double r_mm = kBoardCircleRadii_mm[static_cast<int>(point.circle)];
        correspondences.push_back(
            {point.image_px, cv::Point2f(static_cast<float>(r_mm * std::cos(angle)), static_cast<float>(r_mm * std::sin(angle))), point.sigma_px});
    }
    return correspondences;
}

std::optional<BoardPlaneFit> fitBoardPlane (const std::vector<BoardCorrespondence>& correspondences, const IntrinsicCalibration* intrinsics)
{
    if(correspondences.size() < 8)
    {
        return std::nullopt;
    }
    std::vector<cv::Point2f> image, board;
    for(const auto& c : correspondences)
    {
        image.push_back(c.image_px);
        board.push_back(c.board_mm);
    }
    image = undistortedPoints(image, intrinsics);
    const cv::Mat h = cv::findHomography(board, image, 0);
    if(h.empty())
    {
        return std::nullopt;
    }
    BoardPlaneFit fit;
    fit.board_to_image = cv::Matx33d(h);
    fit.undistorted = intrinsics != nullptr;
    const cv::Matx33d image_to_board = fit.board_to_image.inv();
    double sum_sq_px = 0.0, sum_sq_mm = 0.0;
    for(std::size_t k = 0; k < image.size(); ++k)
    {
        const double error_px = cv::norm(apply(fit.board_to_image, board[k]) - image[k]);
        const double error_mm = cv::norm(apply(image_to_board, image[k]) - board[k]);
        sum_sq_px += error_px * error_px;
        sum_sq_mm += error_mm * error_mm;
        fit.worst_mm = std::max(fit.worst_mm, error_mm);
    }
    fit.rms_px = std::sqrt(sum_sq_px / image.size());
    fit.rms_mm = std::sqrt(sum_sq_mm / image.size());
    return fit;
}

cv::Point2f imageToBoard (const BoardPlaneFit& fit, const cv::Point2f& image_px, const IntrinsicCalibration* intrinsics)
{
    const cv::Point2f p = fit.undistorted ? undistortedPoints({image_px}, intrinsics).front() : image_px;
    return apply(fit.board_to_image.inv(), p);
}

bool saveBoardPlane (const std::string& path, const StoredBoardPlane& plane)
{
    try
    {
        cv::FileStorage file(path, cv::FileStorage::WRITE);
        if(!file.isOpened())
        {
            return false;
        }
        file << "format" << std::string(kFormat);
        file << "created" << plane.created;
        file << "usb_port" << plane.usb_port;
        file << "twenty_sector" << plane.twenty_sector;
        file << "undistorted" << static_cast<int>(plane.fit.undistorted);
        file << "board_to_image" << cv::Mat(plane.fit.board_to_image);
        file << "rms_px" << plane.fit.rms_px;
        file << "rms_mm" << plane.fit.rms_mm;
        file << "worst_mm" << plane.fit.worst_mm;
        file << "correspondences" << "[";
        for(const auto& c : plane.correspondences)
        {
            file << "{" << "image_px" << c.image_px << "board_mm" << c.board_mm << "sigma_px" << c.sigma_px << "}";
        }
        file << "]";
        return true;
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}

std::optional<StoredBoardPlane> loadBoardPlane (const std::string& path)
{
    // A missing file is the normal case before the first calibration; OpenCV would log an error for it.
    if(!std::filesystem::exists(path))
    {
        return std::nullopt;
    }
    try
    {
        cv::FileStorage file(path, cv::FileStorage::READ);
        if(!file.isOpened() || static_cast<std::string>(file["format"]) != kFormat)
        {
            return std::nullopt;
        }
        StoredBoardPlane plane;
        plane.created = static_cast<std::string>(file["created"]);
        plane.usb_port = static_cast<std::string>(file["usb_port"]);
        plane.twenty_sector = static_cast<int>(file["twenty_sector"]);
        plane.fit.undistorted = static_cast<int>(file["undistorted"]) != 0;
        cv::Mat h;
        file["board_to_image"] >> h;
        if(h.rows != 3 || h.cols != 3)
        {
            return std::nullopt;
        }
        plane.fit.board_to_image = cv::Matx33d(h);
        plane.fit.rms_px = static_cast<double>(file["rms_px"]);
        plane.fit.rms_mm = static_cast<double>(file["rms_mm"]);
        plane.fit.worst_mm = static_cast<double>(file["worst_mm"]);
        for(const auto& node : file["correspondences"])
        {
            BoardCorrespondence c;
            node["image_px"] >> c.image_px;
            node["board_mm"] >> c.board_mm;
            c.sigma_px = static_cast<double>(node["sigma_px"]);
            plane.correspondences.push_back(c);
        }
        return plane;
    }
    catch(const cv::Exception&)
    {
        return std::nullopt;
    }
}
}  // namespace dartpilot::geometry
