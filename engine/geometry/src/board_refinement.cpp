#include "dartpilot/geometry/board_refinement.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <limits>

#include <opencv2/calib3d.hpp>

namespace dartpilot::geometry
{
namespace
{
constexpr std::string_view kFormat = "dartpilot-extrinsics-1";
constexpr double kSectorWidth_deg = 18.0;
// The double ring sets the scale; its radius is not refined.
constexpr int kScaleCircle = static_cast<int>(BoardCircle::DoubleCentre);
static_assert(kScaleCircle == kBoardCircleCount - 1, "the refined radii are the ones before the scale circle");
constexpr int kRefinedRadii = kBoardCircleCount - 1;
// How far the radii of a real board are from the nominal ones; boards differ by about a wire thickness
constexpr double kRadiusSigma_mm = 2.0;
// Below this, the deviation the detector reports for a point is not credible
constexpr double kMinPointSigma_px = 0.3;
// Points further off than this many robust standard deviations are down-weighted (Huber)
constexpr double kHuberThreshold = 3.0;
constexpr int kHeldOutFolds = 4;
constexpr int kMinPoints = 8;
constexpr int kMaxIterations = 100;
constexpr int kPoseParameters = 6;
// After the pose: how far the detected wire edges lie beside the wire centre lines, in mm on the board. The wires are
// bright, so the light/dark transition the detection finds is shifted towards the dark sector, alternately to either
// side of successive wires.
constexpr int kEdgeOffset = kPoseParameters;
constexpr int kCameraParameters = kPoseParameters + 1;
constexpr double kEdgeOffsetSigma_mm = 2.0;

double distortionSigma (DistortionModel model, std::size_t coefficient)
{
    // Tangential coefficients (p1, p2) of the standard and rational models are small for any real lens
    const bool tangential = model != DistortionModel::Fisheye && (coefficient == 2 || coefficient == 3);
    return tangential ? 0.002 : 0.05;
}

std::vector<double> toVector (const cv::Mat& coefficients)
{
    cv::Mat d;
    coefficients.convertTo(d, CV_64F);
    return d.empty() ? std::vector<double>{} : std::vector<double>(d.begin<double>(), d.end<double>());
}

// A column vector over the data; OpenCV 5 would make a one-dimensional Mat of the vector itself.
cv::Mat column (const std::vector<double>& values) { return cv::Mat(static_cast<int>(values.size()), 1, CV_64F, const_cast<double*>(values.data())); }

struct Camera
{
    DistortionModel model = DistortionModel::Standard;
    cv::Matx33d rotation;
    cv::Vec3d translation_mm;
    double fx = 0.0, fy = 0.0, cx = 0.0, cy = 0.0;
    std::vector<double> dist;
};

// Normalized image coordinates to distorted normalized coordinates, as OpenCV's models define them
cv::Point2d distort (const Camera& camera, double x, double y)
{
    const auto& d = camera.dist;
    const auto k = [&] (std::size_t i) { return i < d.size() ? d[i] : 0.0; };
    if(camera.model == DistortionModel::Fisheye)
    {
        const double r = std::hypot(x, y);
        if(r < 1e-12)
        {
            return {x, y};
        }
        const double theta = std::atan(r), t2 = theta * theta;
        const double theta_d = theta * (1 + k(0) * t2 + k(1) * t2 * t2 + k(2) * t2 * t2 * t2 + k(3) * t2 * t2 * t2 * t2);
        return {x * theta_d / r, y * theta_d / r};
    }
    const double r2 = x * x + y * y, r4 = r2 * r2, r6 = r4 * r2;
    const double radial = (1 + k(0) * r2 + k(1) * r4 + k(4) * r6) / (1 + k(5) * r2 + k(6) * r4 + k(7) * r6);
    return {x * radial + 2 * k(2) * x * y + k(3) * (r2 + 2 * x * x), y * radial + k(2) * (r2 + 2 * y * y) + 2 * k(3) * x * y};
}

cv::Point2d project (const Camera& camera, const cv::Vec3d& board_mm)
{
    const cv::Vec3d p = camera.rotation * board_mm + camera.translation_mm;
    const cv::Point2d d = distort(camera, p[0] / p[2], p[1] / p[2]);
    return {camera.fx * d.x + camera.cx, camera.fy * d.y + camera.cy};
}

// Inverse of distort by Gauss-Newton; converges within a few steps for any lens the calibration accepts.
cv::Point2d undistort (const Camera& camera, const cv::Point2d& image_px)
{
    const cv::Point2d target((image_px.x - camera.cx) / camera.fx, (image_px.y - camera.cy) / camera.fy);
    cv::Point2d p = target;
    constexpr double h = 1e-7;
    for(int i = 0; i < 30; ++i)
    {
        const cv::Point2d e = distort(camera, p.x, p.y) - target;
        const cv::Point2d dx = (distort(camera, p.x + h, p.y) - distort(camera, p.x - h, p.y)) / (2 * h);
        const cv::Point2d dy = (distort(camera, p.x, p.y + h) - distort(camera, p.x, p.y - h)) / (2 * h);
        const double det = dx.x * dy.y - dy.x * dx.y;
        if(std::abs(det) < 1e-15)
        {
            break;
        }
        const cv::Point2d step((dy.y * e.x - dy.x * e.y) / det, (-dx.y * e.x + dx.x * e.y) / det);
        p -= step;
        if(step.dot(step) < 1e-26)
        {
            break;
        }
    }
    return p;
}

// Where the ray through an image point meets the plane z = z_mm
cv::Point3d backProject (const Camera& camera, const cv::Point2d& image_px, double z_mm)
{
    const cv::Point2d n = undistort(camera, image_px);
    const cv::Matx33d rt = camera.rotation.t();
    const cv::Vec3d direction = rt * cv::Vec3d(n.x, n.y, 1.0);
    const cv::Vec3d centre = -(rt * camera.translation_mm);
    const double s = (z_mm - centre[2]) / direction[2];
    return {centre[0] + s * direction[0], centre[1] + s * direction[1], z_mm};
}

struct Observation
{
    int circle = 0;
    // Board wire whose nominal position the point lies on, counter-clockwise from the clockwise wire of sector 6
    int wire = 0;
    double angle_rad = 0.0;
    cv::Point2d image_px;
    double sigma_px = 0.0;
};

std::vector<Observation> observationsOf (const std::vector<BoardCorrespondence>& correspondences)
{
    std::vector<Observation> observations;
    for(const auto& c : correspondences)
    {
        Observation o;
        const double r_mm = std::hypot(c.board_mm.x, c.board_mm.y);
        for(int k = 1; k < kBoardCircleCount; ++k)
        {
            if(std::abs(r_mm - kBoardCircleRadii_mm[k]) < std::abs(r_mm - kBoardCircleRadii_mm[o.circle]))
            {
                o.circle = k;
            }
        }
        o.angle_rad = std::atan2(c.board_mm.y, c.board_mm.x);
        const double angle_deg = o.angle_rad * 180.0 / CV_PI;
        o.wire = ((static_cast<int>(std::lround((angle_deg - kSectorWidth_deg / 2) / kSectorWidth_deg)) % kRadialWireCount) + kRadialWireCount) %
                 kRadialWireCount;
        o.image_px = c.image_px;
        o.sigma_px = std::max(c.sigma_px, kMinPointSigma_px);
        observations.push_back(o);
    }
    return observations;
}

enum class Intrinsic
{
    FocalScale,
    PrincipalX,
    PrincipalY,
    Distortion,
};

// An intrinsic parameter the refinement moves, with its prior
struct FreeIntrinsic
{
    Intrinsic kind;
    int coefficient = 0;
    double start = 0.0;
    double sigma = 0.0;
    double step = 0.0;
};

// One camera in the parameter vector: rvec, tvec_mm, then its free intrinsics
struct CameraBlock
{
    DistortionModel model = DistortionModel::Standard;
    cv::Size image_size_px;
    double fx = 0.0, fy = 0.0, cx = 0.0, cy = 0.0;
    std::vector<double> dist;
    std::vector<FreeIntrinsic> free;
    std::vector<Observation> observations;
    int offset = 0;

    int parameterCount () const { return kCameraParameters + static_cast<int>(free.size()); }

    Camera at (const std::vector<double>& x) const
    {
        Camera camera{model, {}, cv::Vec3d(x[offset + 3], x[offset + 4], x[offset + 5]), fx, fy, cx, cy, dist};
        cv::Rodrigues(cv::Vec3d(x[offset], x[offset + 1], x[offset + 2]), camera.rotation);
        for(std::size_t k = 0; k < free.size(); ++k)
        {
            const double v = x[offset + kCameraParameters + k];
            switch(free[k].kind)
            {
                case Intrinsic::FocalScale:
                    camera.fx = fx * v;
                    camera.fy = fy * v;
                    break;
                case Intrinsic::PrincipalX:
                    camera.cx = v;
                    break;
                case Intrinsic::PrincipalY:
                    camera.cy = v;
                    break;
                case Intrinsic::Distortion:
                    camera.dist[free[k].coefficient] = v;
                    break;
            }
        }
        return camera;
    }
};

struct Problem
{
    std::vector<CameraBlock> cameras;
    double wire_height_mm = 0.0;
    std::array<double, kBoardCircleCount> start_radii_mm{};
    int radius_offset = 0;
    std::vector<double> steps;
    // Huber threshold per camera, in units of the point deviation; infinite for plain least squares
    std::vector<double> huber;

    double radius (const std::vector<double>& x, int circle) const
    {
        return circle == kScaleCircle ? start_radii_mm[circle] : x[radius_offset + circle];
    }

    // Where the detection should find a point: on its circle, where the wire edge shifted by the camera's edge offset
    // crosses it
    cv::Vec3d modelPoint (const std::vector<double>& x, const CameraBlock& block, const Observation& o) const
    {
        const double r_mm = radius(x, o.circle);
        const double side_mm = (o.wire % 2 == 0 ? 1.0 : -1.0) * x[block.offset + kEdgeOffset];
        const double angle = o.angle_rad + std::asin(std::clamp(side_mm / r_mm, -1.0, 1.0));
        return {r_mm * std::cos(angle), r_mm * std::sin(angle), wire_height_mm};
    }

    // Data residuals in units of the point deviation, robustified so that their squares sum to the Huber cost, then
    // the priors
    std::vector<double> residuals (const std::vector<double>& x) const
    {
        std::vector<double> r;
        for(std::size_t c = 0; c < cameras.size(); ++c)
        {
            const auto& block = cameras[c];
            const Camera camera = block.at(x);
            for(const auto& o : block.observations)
            {
                const cv::Point2d e = (project(camera, modelPoint(x, block, o)) - o.image_px) / o.sigma_px;
                const double norm = std::hypot(e.x, e.y), k = huber[c];
                const double factor = norm > k ? std::sqrt(2 * k * norm - k * k) / norm : 1.0;
                r.push_back(e.x * factor);
                r.push_back(e.y * factor);
            }
            r.push_back(x[block.offset + kEdgeOffset] / kEdgeOffsetSigma_mm);
            for(std::size_t k = 0; k < block.free.size(); ++k)
            {
                r.push_back((x[block.offset + kCameraParameters + k] - block.free[k].start) / block.free[k].sigma);
            }
        }
        for(int circle = 0; circle < kRefinedRadii; ++circle)
        {
            r.push_back((x[radius_offset + circle] - start_radii_mm[circle]) / kRadiusSigma_mm);
        }
        return r;
    }

    cv::Mat jacobian (const std::vector<double>& x, std::size_t rows) const
    {
        cv::Mat j(static_cast<int>(rows), static_cast<int>(x.size()), CV_64F);
        std::vector<double> probe = x;
        for(std::size_t p = 0; p < x.size(); ++p)
        {
            probe[p] = x[p] + steps[p];
            const auto plus = residuals(probe);
            probe[p] = x[p] - steps[p];
            const auto minus = residuals(probe);
            probe[p] = x[p];
            for(std::size_t i = 0; i < rows; ++i)
            {
                j.at<double>(static_cast<int>(i), static_cast<int>(p)) = (plus[i] - minus[i]) / (2 * steps[p]);
            }
        }
        return j;
    }
};

double sumOfSquares (const std::vector<double>& r)
{
    double sum = 0.0;
    for(const double v : r)
    {
        sum += v * v;
    }
    return sum;
}

// Levenberg-Marquardt; returns the number of iterations
int solve (const Problem& problem, std::vector<double>& x)
{
    auto r = problem.residuals(x);
    double cost = sumOfSquares(r);
    double lambda = 1e-3;
    int iteration = 0;
    for(; iteration < kMaxIterations; ++iteration)
    {
        const cv::Mat j = problem.jacobian(x, r.size());
        const cv::Mat a = j.t() * j;
        const cv::Mat g = j.t() * column(r);
        bool improved = false;
        double previous = cost;
        while(lambda < 1e12)
        {
            cv::Mat damped = a.clone();
            for(int i = 0; i < damped.rows; ++i)
            {
                damped.at<double>(i, i) += lambda * std::max(a.at<double>(i, i), 1e-9);
            }
            cv::Mat delta;
            if(!cv::solve(damped, -g, delta, cv::DECOMP_CHOLESKY))
            {
                cv::solve(damped, -g, delta, cv::DECOMP_SVD);
            }
            std::vector<double> trial = x;
            for(std::size_t i = 0; i < trial.size(); ++i)
            {
                trial[i] += delta.at<double>(static_cast<int>(i));
            }
            auto trial_r = problem.residuals(trial);
            const double trial_cost = sumOfSquares(trial_r);
            if(std::isfinite(trial_cost) && trial_cost < cost)
            {
                x = std::move(trial);
                r = std::move(trial_r);
                cost = trial_cost;
                lambda = std::max(lambda / 3, 1e-12);
                improved = true;
                break;
            }
            lambda *= 4;
        }
        if(!improved || previous - cost < 1e-10 * previous)
        {
            break;
        }
    }
    return iteration + 1;
}

// Point errors of one camera in units of the point deviation
std::vector<double> normalizedErrors (const Problem& problem, const std::vector<double>& x, std::size_t c)
{
    const Camera camera = problem.cameras[c].at(x);
    std::vector<double> errors;
    for(const auto& o : problem.cameras[c].observations)
    {
        errors.push_back(cv::norm(project(camera, problem.modelPoint(x, problem.cameras[c], o)) - o.image_px) / o.sigma_px);
    }
    return errors;
}

// Least squares first, then again with Huber weights above a threshold set from each camera's own spread, so that
// a point far off does not bend the lens model; the detector's deviations are often too optimistic as a whole.
int solveRobust (Problem& problem, std::vector<double>& x)
{
    problem.huber.assign(problem.cameras.size(), std::numeric_limits<double>::infinity());
    int iterations = solve(problem, x);
    for(std::size_t c = 0; c < problem.cameras.size(); ++c)
    {
        auto errors = normalizedErrors(problem, x, c);
        std::nth_element(errors.begin(), errors.begin() + errors.size() / 2, errors.end());
        // The median of a 2D error norm is about 1.18 standard deviations
        const double spread = std::max(1.0, errors[errors.size() / 2] / 1.1774);
        problem.huber[c] = kHuberThreshold * spread;
    }
    iterations += solve(problem, x);
    return iterations;
}

// Focal length of a camera with square pixels and the principal point in the image centre, from the homography of
// the board (Zhang's two constraints on the image of the absolute conic, solved together in least squares)
std::optional<double> focalFromBoard (const std::vector<BoardCorrespondence>& correspondences, const cv::Size& image_size_px)
{
    std::vector<cv::Point2f> image, board;
    for(const auto& c : correspondences)
    {
        image.push_back(c.image_px - cv::Point2f(image_size_px.width / 2.0f, image_size_px.height / 2.0f));
        board.push_back(c.board_mm);
    }
    const cv::Mat hm = cv::findHomography(board, image, 0);
    if(hm.empty())
    {
        return std::nullopt;
    }
    const cv::Matx33d h(hm);
    const double a1 = h(0, 0) * h(0, 1) + h(1, 0) * h(1, 1), b1 = h(2, 0) * h(2, 1);
    const double a2 = h(0, 0) * h(0, 0) + h(1, 0) * h(1, 0) - h(0, 1) * h(0, 1) - h(1, 1) * h(1, 1);
    const double b2 = h(2, 0) * h(2, 0) - h(2, 1) * h(2, 1);
    // a / f^2 + b = 0 for both constraints
    const double inverse_f2 = -(a1 * b1 + a2 * b2) / (a1 * a1 + a2 * a2);
    if(!(inverse_f2 > 0))
    {
        return std::nullopt;
    }
    return 1.0 / std::sqrt(inverse_f2);
}

std::optional<CameraBlock> makeBlock (const RefinementInput& input)
{
    const auto& prior = input.prior;
    CameraBlock block;
    block.model = prior.intrinsics.model;
    block.image_size_px = prior.intrinsics.image_size_px;
    block.fx = prior.intrinsics.camera_matrix(0, 0);
    block.fy = prior.intrinsics.camera_matrix(1, 1);
    block.cx = prior.intrinsics.camera_matrix(0, 2);
    block.cy = prior.intrinsics.camera_matrix(1, 2);
    block.dist = toVector(prior.intrinsics.dist_coeffs);
    if(block.fx <= 0 || block.fy <= 0)
    {
        const auto f = focalFromBoard(input.correspondences, block.image_size_px);
        if(!f)
        {
            return std::nullopt;
        }
        block.fx = block.fy = *f;
    }
    block.observations = observationsOf(input.correspondences);
    if(prior.focal_sigma > 0)
    {
        block.free.push_back({Intrinsic::FocalScale, 0, 1.0, prior.focal_sigma, 1e-6});
    }
    if(prior.principal_sigma_px > 0)
    {
        block.free.push_back({Intrinsic::PrincipalX, 0, block.cx, prior.principal_sigma_px, 1e-3});
        block.free.push_back({Intrinsic::PrincipalY, 0, block.cy, prior.principal_sigma_px, 1e-3});
    }
    for(std::size_t k = 0; k < block.dist.size() && k < prior.distortion_sigma.size(); ++k)
    {
        if(prior.distortion_sigma[k] > 0)
        {
            block.free.push_back({Intrinsic::Distortion, static_cast<int>(k), block.dist[k], prior.distortion_sigma[k], 1e-6});
        }
    }
    return block;
}

// Pose from the board with the starting intrinsics: the points are undistorted, then posed as a plane.
bool initialPose (const CameraBlock& block, double wire_height_mm, std::vector<double>& x)
{
    Camera camera{block.model, cv::Matx33d::eye(), cv::Vec3d(0, 0, 1), block.fx, block.fy, block.cx, block.cy, block.dist};
    std::vector<cv::Point3f> object;
    std::vector<cv::Point2f> normalized;
    for(const auto& o : block.observations)
    {
        const double r_mm = kBoardCircleRadii_mm[o.circle];
        object.emplace_back(static_cast<float>(r_mm * std::cos(o.angle_rad)), static_cast<float>(r_mm * std::sin(o.angle_rad)), 0.0f);
        const cv::Point2d n = undistort(camera, o.image_px);
        normalized.emplace_back(static_cast<float>(n.x), static_cast<float>(n.y));
    }
    cv::Vec3d rvec, tvec;
    if(!cv::solvePnP(object, normalized, cv::Matx33d::eye(), cv::noArray(), rvec, tvec, false, cv::SOLVEPNP_IPPE))
    {
        return false;
    }
    // The points stand on the wires: shift the plane from z = 0 up to the wire height.
    cv::Matx33d rotation;
    cv::Rodrigues(rvec, rotation);
    tvec -= wire_height_mm * cv::Vec3d(rotation(0, 2), rotation(1, 2), rotation(2, 2));
    for(int i = 0; i < 3; ++i)
    {
        x[block.offset + i] = rvec[i];
        x[block.offset + 3 + i] = tvec[i];
    }
    return true;
}

// Lays out the parameter vector of the blocks and fills it with the starting values
std::vector<double> layout (Problem& problem)
{
    int offset = 0;
    for(auto& block : problem.cameras)
    {
        block.offset = offset;
        offset += block.parameterCount();
    }
    problem.radius_offset = offset;
    std::vector<double> x(offset + kRefinedRadii, 0.0);
    problem.steps.assign(x.size(), 0.0);
    for(const auto& block : problem.cameras)
    {
        for(int i = 0; i < kPoseParameters; ++i)
        {
            problem.steps[block.offset + i] = i < 3 ? 1e-6 : 1e-4;
        }
        problem.steps[block.offset + kEdgeOffset] = 1e-4;
        for(std::size_t k = 0; k < block.free.size(); ++k)
        {
            x[block.offset + kCameraParameters + k] = block.free[k].start;
            problem.steps[block.offset + kCameraParameters + k] = block.free[k].step;
        }
    }
    for(int circle = 0; circle < kRefinedRadii; ++circle)
    {
        x[problem.radius_offset + circle] = problem.start_radii_mm[circle];
        problem.steps[problem.radius_offset + circle] = 1e-4;
    }
    return x;
}

// 1-sigma position error on the playing surface for a camera with this parameter covariance, at sample points over
// the scoring area: the image point stays, the camera parameters vary.
std::pair<double, double> positionUncertainty (const CameraBlock& block, const std::vector<double>& x, const std::vector<double>& steps,
                                               const cv::Mat& covariance)
{
    const Camera camera = block.at(x);
    const int n = block.parameterCount();
    double sum_sq = 0.0, worst = 0.0;
    int samples = 0;
    std::vector<double> probe = x;
    for(const double r_mm : {20.0, 60.0, 100.0, 140.0, 170.0})
    {
        for(int i = 0; i < kRadialWireCount; ++i)
        {
            const double angle = (90.0 - kSectorWidth_deg * i) * CV_PI / 180.0;
            const cv::Point2d image_px = project(camera, cv::Vec3d(r_mm * std::cos(angle), r_mm * std::sin(angle), 0.0));
            cv::Mat j(2, n, CV_64F);
            for(int p = 0; p < n; ++p)
            {
                const int index = block.offset + p;
                probe[index] = x[index] + steps[index];
                const cv::Point3d plus = backProject(block.at(probe), image_px, 0.0);
                probe[index] = x[index] - steps[index];
                const cv::Point3d minus = backProject(block.at(probe), image_px, 0.0);
                probe[index] = x[index];
                j.at<double>(0, p) = (plus.x - minus.x) / (2 * steps[index]);
                j.at<double>(1, p) = (plus.y - minus.y) / (2 * steps[index]);
            }
            const cv::Mat c = j * covariance * j.t();
            const double variance = c.at<double>(0, 0) + c.at<double>(1, 1);
            sum_sq += variance;
            worst = std::max(worst, std::sqrt(variance));
            ++samples;
        }
    }
    return {std::sqrt(sum_sq / samples), worst};
}

// Back-projection error of observations in board mm
std::vector<double> boardErrors (const Problem& problem, const std::vector<double>& x, const CameraBlock& block,
                                 const std::vector<Observation>& observations)
{
    const Camera camera = block.at(x);
    std::vector<double> errors;
    for(const auto& o : observations)
    {
        const cv::Vec3d model = problem.modelPoint(x, block, o);
        const cv::Point3d seen = backProject(camera, o.image_px, problem.wire_height_mm);
        errors.push_back(std::hypot(seen.x - model[0], seen.y - model[1]));
    }
    return errors;
}

double rms (const std::vector<double>& values) { return values.empty() ? 0.0 : std::sqrt(sumOfSquares(values) / values.size()); }
}  // namespace

std::string_view toString (IntrinsicsSource source)
{
    switch(source)
    {
        case IntrinsicsSource::OwnCalibration:
            return "own-calibration";
        case IntrinsicsSource::ModelPrior:
            return "model-prior";
        case IntrinsicsSource::BoardOnly:
            return "board-only";
    }
    return "board-only";
}

std::optional<IntrinsicsSource> parseIntrinsicsSource (std::string_view name)
{
    for(const auto source : {IntrinsicsSource::OwnCalibration, IntrinsicsSource::ModelPrior, IntrinsicsSource::BoardOnly})
    {
        if(toString(source) == name)
        {
            return source;
        }
    }
    return std::nullopt;
}

IntrinsicsPrior priorFromCalibration (const IntrinsicCalibration& calibration, IntrinsicsSource source)
{
    IntrinsicsPrior prior;
    prior.source = source;
    prior.intrinsics = calibration;
    // ADR 0006: between units of a model the principal point differs by 10 to 30 px and the focal length by 1 to 2 %.
    const bool other_unit = source == IntrinsicsSource::ModelPrior;
    prior.focal_sigma = other_unit ? 0.02 : 0.01;
    prior.principal_sigma_px = other_unit ? 30.0 : 10.0;
    const std::size_t n = calibration.dist_coeffs.total();
    for(std::size_t k = 0; k < n; ++k)
    {
        prior.distortion_sigma.push_back(distortionSigma(calibration.model, k) * (other_unit ? 2.0 : 1.0));
    }
    // A calibration of this camera with its own deviations is trusted as far as they go, down to a floor: its views
    // may not have covered the board region.
    const auto& sd = calibration.std_deviations;
    if(!other_unit && sd.size() >= 4 + n && calibration.camera_matrix(0, 0) > 0)
    {
        prior.focal_sigma = std::max(sd[0] / calibration.camera_matrix(0, 0), 0.002);
        prior.principal_sigma_px = std::max(std::max(sd[2], sd[3]), 2.0);
        for(std::size_t k = 0; k < n; ++k)
        {
            prior.distortion_sigma[k] = std::max(sd[4 + k], prior.distortion_sigma[k] / 5);
        }
    }
    return prior;
}

IntrinsicsPrior boardOnlyPrior (const cv::Size& image_size_px)
{
    IntrinsicsPrior prior;
    prior.source = IntrinsicsSource::BoardOnly;
    prior.intrinsics.model = DistortionModel::Standard;
    prior.intrinsics.image_size_px = image_size_px;
    prior.intrinsics.camera_matrix = cv::Matx33d(0, 0, image_size_px.width / 2.0, 0, 0, image_size_px.height / 2.0, 0, 0, 1);
    prior.intrinsics.dist_coeffs = cv::Mat::zeros(5, 1, CV_64F);
    prior.focal_sigma = 0.15;
    prior.principal_sigma_px = 30.0;
    // Radial distortion only: one view of a plane does not carry the tangential terms.
    prior.distortion_sigma = {0.3, 0.3, 0.0, 0.0, 0.0};
    return prior;
}

std::optional<BoardRefinement> refineBoardCameras (const std::vector<RefinementInput>& inputs, const BoardModel& start)
{
    if(inputs.empty())
    {
        return std::nullopt;
    }
    Problem problem;
    problem.wire_height_mm = start.wire_height_mm;
    problem.start_radii_mm = start.radii_mm;
    for(const auto& input : inputs)
    {
        auto block = makeBlock(input);
        if(!block || static_cast<int>(block->observations.size()) < kMinPoints)
        {
            return std::nullopt;
        }
        problem.cameras.push_back(std::move(*block));
    }
    std::vector<double> x = layout(problem);
    for(const auto& block : problem.cameras)
    {
        if(!initialPose(block, problem.wire_height_mm, x))
        {
            return std::nullopt;
        }
    }

    BoardRefinement result;
    result.iterations = solveRobust(problem, x);
    result.board = start;
    for(int circle = 0; circle < kRefinedRadii; ++circle)
    {
        result.board.radii_mm[circle] = x[problem.radius_offset + circle];
    }

    // Covariance of the parameters, each camera's block scaled by how much its residuals exceed the point deviations
    const auto r = problem.residuals(x);
    const cv::Mat j = problem.jacobian(x, r.size());
    const cv::Mat covariance = (j.t() * j).inv(cv::DECOMP_SVD);
    double total_chi2 = 0.0;
    int total_dof = 0;

    for(std::size_t c = 0; c < problem.cameras.size(); ++c)
    {
        const auto& block = problem.cameras[c];
        const Camera camera = block.at(x);
        RefinedCamera refined;
        refined.usb_port = inputs[c].usb_port;
        refined.source = inputs[c].prior.source;
        refined.points = static_cast<int>(block.observations.size());
        for(int i = 0; i < 3; ++i)
        {
            refined.rvec[i] = x[block.offset + i];
            refined.tvec_mm[i] = x[block.offset + 3 + i];
        }
        refined.edge_offset_mm = x[block.offset + kEdgeOffset];

        double chi2 = 0.0, sum_sq_px = 0.0;
        for(const double e : normalizedErrors(problem, x, c))
        {
            const double k = problem.huber[c];
            chi2 += e > k ? 2 * k * e - k * k : e * e;
            refined.outliers += e > k ? 1 : 0;
        }
        for(const auto& o : block.observations)
        {
            const double e_px = cv::norm(project(camera, problem.modelPoint(x, block, o)) - o.image_px);
            sum_sq_px += e_px * e_px;
        }
        const int dof = std::max(1, 2 * refined.points - block.parameterCount());
        total_chi2 += chi2;
        total_dof += dof;
        const double scale = std::max(1.0, chi2 / dof);
        const cv::Mat block_covariance =
            covariance(cv::Rect(block.offset, block.offset, block.parameterCount(), block.parameterCount())).clone() * scale;

        auto& intrinsics = refined.intrinsics;
        intrinsics.model = block.model;
        intrinsics.image_size_px = block.image_size_px;
        intrinsics.camera_matrix = cv::Matx33d(camera.fx, 0, camera.cx, 0, camera.fy, camera.cy, 0, 0, 1);
        intrinsics.dist_coeffs = column(camera.dist).clone();
        intrinsics.rms_px = std::sqrt(sum_sq_px / refined.points);
        intrinsics.std_deviations.assign(4 + camera.dist.size(), 0.0);
        for(std::size_t k = 0; k < block.free.size(); ++k)
        {
            const int index = kCameraParameters + static_cast<int>(k);
            const double sd = std::sqrt(block_covariance.at<double>(index, index));
            switch(block.free[k].kind)
            {
                case Intrinsic::FocalScale:
                    intrinsics.std_deviations[0] = sd * block.fx;
                    intrinsics.std_deviations[1] = sd * block.fy;
                    break;
                case Intrinsic::PrincipalX:
                    intrinsics.std_deviations[2] = sd;
                    break;
                case Intrinsic::PrincipalY:
                    intrinsics.std_deviations[3] = sd;
                    break;
                case Intrinsic::Distortion:
                    intrinsics.std_deviations[4 + block.free[k].coefficient] = sd;
                    break;
            }
        }

        const auto errors_mm = boardErrors(problem, x, block, block.observations);
        refined.rms_mm = rms(errors_mm);
        refined.worst_mm = *std::max_element(errors_mm.begin(), errors_mm.end());
        std::tie(refined.uncertainty_mm, refined.worst_uncertainty_mm) = positionUncertainty(block, x, problem.steps, block_covariance);
        result.cameras.push_back(refined);
    }
    const double global_scale = std::max(1.0, total_chi2 / std::max(1, total_dof));
    for(int circle = 0; circle < kRefinedRadii; ++circle)
    {
        const int index = problem.radius_offset + circle;
        result.radius_sigma_mm[circle] = std::sqrt(covariance.at<double>(index, index) * global_scale);
    }

    // Held-out wires: every fourth wire of every camera is left out once.
    std::vector<double> held_out_sq(problem.cameras.size(), 0.0);
    std::vector<int> held_out_n(problem.cameras.size(), 0);
    for(int fold = 0; fold < kHeldOutFolds; ++fold)
    {
        Problem training = problem;
        std::vector<std::vector<Observation>> held_out(problem.cameras.size());
        bool enough = true;
        for(std::size_t c = 0; c < training.cameras.size(); ++c)
        {
            auto& observations = training.cameras[c].observations;
            std::vector<Observation> kept;
            for(const auto& o : observations)
            {
                (o.wire % kHeldOutFolds == fold ? held_out[c] : kept).push_back(o);
            }
            observations = std::move(kept);
            enough = enough && static_cast<int>(observations.size()) >= kMinPoints;
        }
        if(!enough)
        {
            continue;
        }
        std::vector<double> x_fold = x;
        solveRobust(training, x_fold);
        for(std::size_t c = 0; c < training.cameras.size(); ++c)
        {
            for(const double e : boardErrors(training, x_fold, training.cameras[c], held_out[c]))
            {
                held_out_sq[c] += e * e;
                ++held_out_n[c];
            }
        }
    }
    for(std::size_t c = 0; c < result.cameras.size(); ++c)
    {
        result.cameras[c].held_out_rms_mm = held_out_n[c] > 0 ? std::sqrt(held_out_sq[c] / held_out_n[c]) : 0.0;
    }
    return result;
}

namespace
{
Camera cameraOf (const RefinedCamera& refined)
{
    const auto& k = refined.intrinsics.camera_matrix;
    Camera camera{refined.intrinsics.model, {}, refined.tvec_mm, k(0, 0), k(1, 1), k(0, 2), k(1, 2), toVector(refined.intrinsics.dist_coeffs)};
    cv::Rodrigues(refined.rvec, camera.rotation);
    return camera;
}
}  // namespace

cv::Point2f boardToImage (const RefinedCamera& camera, const cv::Point3f& board_mm)
{
    const cv::Point2d p = project(cameraOf(camera), cv::Vec3d(board_mm.x, board_mm.y, board_mm.z));
    return {static_cast<float>(p.x), static_cast<float>(p.y)};
}

cv::Point2f imageToBoard (const RefinedCamera& camera, const cv::Point2f& image_px)
{
    const cv::Point3d p = backProject(cameraOf(camera), cv::Point2d(image_px.x, image_px.y), 0.0);
    return {static_cast<float>(p.x), static_cast<float>(p.y)};
}

bool saveExtrinsics (const std::string& path, const StoredExtrinsics& extrinsics)
{
    if(extrinsics.inputs.size() != extrinsics.refinement.cameras.size())
    {
        return false;
    }
    try
    {
        cv::FileStorage file(path, cv::FileStorage::WRITE);
        if(!file.isOpened())
        {
            return false;
        }
        const auto& refinement = extrinsics.refinement;
        file << "format" << std::string(kFormat);
        file << "created" << extrinsics.created;
        file << "board_radii_mm" << std::vector<double>(refinement.board.radii_mm.begin(), refinement.board.radii_mm.end());
        file << "board_radius_sigma_mm" << std::vector<double>(refinement.radius_sigma_mm.begin(), refinement.radius_sigma_mm.end());
        file << "wire_height_mm" << refinement.board.wire_height_mm;
        file << "iterations" << refinement.iterations;
        file << "cameras" << "[";
        for(std::size_t c = 0; c < refinement.cameras.size(); ++c)
        {
            const auto& camera = refinement.cameras[c];
            const auto& input = extrinsics.inputs[c];
            const auto& prior = input.prior;
            file << "{";
            file << "usb_port" << camera.usb_port;
            file << "source" << std::string(toString(camera.source));
            file << "board_plane_created" << input.board_plane_created;
            file << "intrinsics_created" << input.intrinsics_created;
            file << "model" << std::string(toString(camera.intrinsics.model));
            file << "image_width_px" << camera.intrinsics.image_size_px.width;
            file << "image_height_px" << camera.intrinsics.image_size_px.height;
            file << "camera_matrix" << cv::Mat(camera.intrinsics.camera_matrix);
            file << "dist_coeffs" << camera.intrinsics.dist_coeffs;
            file << "std_deviations" << camera.intrinsics.std_deviations;
            file << "rvec" << camera.rvec;
            file << "tvec_mm" << camera.tvec_mm;
            file << "edge_offset_mm" << camera.edge_offset_mm;
            file << "rms_px" << camera.intrinsics.rms_px;
            file << "rms_mm" << camera.rms_mm;
            file << "worst_mm" << camera.worst_mm;
            file << "held_out_rms_mm" << camera.held_out_rms_mm;
            file << "uncertainty_mm" << camera.uncertainty_mm;
            file << "worst_uncertainty_mm" << camera.worst_uncertainty_mm;
            file << "points" << camera.points;
            file << "outliers" << camera.outliers;
            file << "prior" << "{";
            file << "model" << std::string(toString(prior.intrinsics.model));
            file << "camera_matrix" << cv::Mat(prior.intrinsics.camera_matrix);
            file << "dist_coeffs" << prior.intrinsics.dist_coeffs;
            file << "focal_sigma" << prior.focal_sigma;
            file << "principal_sigma_px" << prior.principal_sigma_px;
            file << "distortion_sigma" << prior.distortion_sigma;
            file << "}";
            file << "correspondences" << "[";
            for(const auto& p : input.correspondences)
            {
                file << "{" << "image_px" << p.image_px << "board_mm" << p.board_mm << "sigma_px" << p.sigma_px << "}";
            }
            file << "]";
            file << "}";
        }
        file << "]";
        return true;
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}

std::optional<StoredExtrinsics> loadExtrinsics (const std::string& path)
{
    // A missing file is the normal case before the first refinement; OpenCV would log an error for it.
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
        StoredExtrinsics stored;
        auto& refinement = stored.refinement;
        stored.created = static_cast<std::string>(file["created"]);
        std::vector<double> radii, radius_sigma;
        file["board_radii_mm"] >> radii;
        file["board_radius_sigma_mm"] >> radius_sigma;
        if(radii.size() != kBoardCircleCount || radius_sigma.size() != kBoardCircleCount)
        {
            return std::nullopt;
        }
        std::copy(radii.begin(), radii.end(), refinement.board.radii_mm.begin());
        std::copy(radius_sigma.begin(), radius_sigma.end(), refinement.radius_sigma_mm.begin());
        refinement.board.wire_height_mm = static_cast<double>(file["wire_height_mm"]);
        refinement.iterations = static_cast<int>(file["iterations"]);
        for(const auto& node : file["cameras"])
        {
            RefinedCamera camera;
            RefinementInput input;
            camera.usb_port = input.usb_port = static_cast<std::string>(node["usb_port"]);
            const auto source = parseIntrinsicsSource(static_cast<std::string>(node["source"]));
            const auto model = parseDistortionModel(static_cast<std::string>(node["model"]));
            const auto prior_model = parseDistortionModel(static_cast<std::string>(node["prior"]["model"]));
            if(!source || !model || !prior_model)
            {
                return std::nullopt;
            }
            camera.source = input.prior.source = *source;
            input.board_plane_created = static_cast<std::string>(node["board_plane_created"]);
            input.intrinsics_created = static_cast<std::string>(node["intrinsics_created"]);
            camera.intrinsics.model = *model;
            camera.intrinsics.image_size_px = cv::Size(static_cast<int>(node["image_width_px"]), static_cast<int>(node["image_height_px"]));
            cv::Mat k;
            node["camera_matrix"] >> k;
            node["dist_coeffs"] >> camera.intrinsics.dist_coeffs;
            if(k.rows != 3 || k.cols != 3)
            {
                return std::nullopt;
            }
            camera.intrinsics.camera_matrix = cv::Matx33d(k);
            node["std_deviations"] >> camera.intrinsics.std_deviations;
            node["rvec"] >> camera.rvec;
            node["tvec_mm"] >> camera.tvec_mm;
            camera.edge_offset_mm = static_cast<double>(node["edge_offset_mm"]);
            camera.intrinsics.rms_px = static_cast<double>(node["rms_px"]);
            camera.rms_mm = static_cast<double>(node["rms_mm"]);
            camera.worst_mm = static_cast<double>(node["worst_mm"]);
            camera.held_out_rms_mm = static_cast<double>(node["held_out_rms_mm"]);
            camera.uncertainty_mm = static_cast<double>(node["uncertainty_mm"]);
            camera.worst_uncertainty_mm = static_cast<double>(node["worst_uncertainty_mm"]);
            camera.points = static_cast<int>(node["points"]);
            camera.outliers = static_cast<int>(node["outliers"]);

            const auto prior = node["prior"];
            input.prior.intrinsics.model = *prior_model;
            input.prior.intrinsics.image_size_px = camera.intrinsics.image_size_px;
            prior["camera_matrix"] >> k;
            if(k.rows != 3 || k.cols != 3)
            {
                return std::nullopt;
            }
            input.prior.intrinsics.camera_matrix = cv::Matx33d(k);
            prior["dist_coeffs"] >> input.prior.intrinsics.dist_coeffs;
            input.prior.focal_sigma = static_cast<double>(prior["focal_sigma"]);
            input.prior.principal_sigma_px = static_cast<double>(prior["principal_sigma_px"]);
            prior["distortion_sigma"] >> input.prior.distortion_sigma;
            for(const auto& point : node["correspondences"])
            {
                BoardCorrespondence c;
                point["image_px"] >> c.image_px;
                point["board_mm"] >> c.board_mm;
                c.sigma_px = static_cast<double>(point["sigma_px"]);
                input.correspondences.push_back(c);
            }
            refinement.cameras.push_back(std::move(camera));
            stored.inputs.push_back(std::move(input));
        }
        return stored;
    }
    catch(const cv::Exception&)
    {
        return std::nullopt;
    }
}
}  // namespace dartpilot::geometry
