#pragma once

#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/tip_candidates/tip_candidates.hpp"

// The throw detections a replay can run (#18) on the still moments of the board: "tracker", the live detection
// (fusion::DartTracker), and "baseline", the plain frame differencing it is measured against.
namespace dartpilot::replay
{
struct CameraResult
{
    // seen, cut, not_seen, disagrees, not_calibrated
    std::string state;
    bool used = false;
    // Only where the pipeline locates the dart per camera
    std::optional<cv::Point2f> tip_px;
    std::optional<cv::Point2f> board_mm;
    // How far the triangulated tip lies from tip_px in this camera's image (#23)
    std::optional<double> reprojection_px;
    // Every place this camera's view may have its tip (#26), for measuring candidate recall
    std::vector<tip_candidates::TipCandidate> candidates;
};

struct DetectedDart
{
    // Nothing if the pipeline abstains
    std::optional<cv::Point2f> board_mm;
    cv::Matx22d covariance_mm2 = cv::Matx22d::zeros();
    int cameras_agreeing = 0;
    // The tip in 3D from the tips of the agreeing cameras (#23); z is its distance from the board plane
    std::optional<cv::Point3d> tip_mm;
    int tip_views = 0;
    std::vector<CameraResult> cameras;
    std::string reason;
};

struct StillResult
{
    std::optional<DetectedDart> dart;
    std::optional<int> takeout;
    bool became_ready = false;
    std::vector<int> moved_cameras;
};

class Pipeline
{
   public:
    virtual ~Pipeline () = default;
    // The mean images of all cameras at a still moment, in the order of the cameras
    virtual StillResult addStill (const std::vector<cv::Mat>& means) = 0;
    // Has an empty board to compare with
    virtual bool ready () const = 0;
};

// cameras holds the calibration of each camera, null where there is none. Nothing for an unknown name.
std::unique_ptr<Pipeline> makePipeline (std::string_view name, const std::vector<const geometry::RefinedCamera*>& cameras,
                                        const geometry::BoardModel& board, const fusion::TrackerSettings& settings = {});
}  // namespace dartpilot::replay
