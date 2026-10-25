#pragma once

#include <optional>
#include <string>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/board_state.hpp"
#include "dartpilot/geometry/dart_location.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

// Live detection from still moments of the board (#121, #128): every time all cameras are still, the board is compared
// with its last still state. A new dart gives a throw, located from the cameras that agree or marked uncertain; an
// empty board after darts gives a takeout. Deterministic: the same still images give the same events.
namespace dartpilot::fusion
{
struct TrackerCamera
{
    std::string id;
    const geometry::RefinedCamera* calibration = nullptr;
    // The stored image of the empty board, if any, to tell whether the board is empty at the start
    cv::Mat stored_empty;
};

// What a camera contributed to a dart
struct DartView
{
    // seen, cut (by the image border), not_seen, disagrees (seen, but its axis does not meet the others')
    std::string state;
    bool used = false;
    // What the camera found, for showing it in its image
    std::optional<tip_candidates::DartObservation> observation;
};

struct TrackedDart
{
    // Nothing if the engine abstains
    std::optional<geometry::DartLocation> location;
    std::vector<DartView> cameras;
    // Why it abstained: cameras_disagree, seen_by_one_camera
    std::string reason;
};

struct TrackerUpdate
{
    std::optional<TrackedDart> dart;
    // With a dart: the board at the still moment before it, per camera, as the dart was found against it
    std::vector<cv::Mat> before;
    // Darts that were in the board when it was found empty again
    std::optional<int> takeout;
    // The tracker has an empty board to compare with and detects darts from now on
    bool became_ready = false;
    // Cameras whose whole image moved since the last still moment (knocked or loosened): their change is not a dart,
    // and their calibration needs checking. Index of the camera and the image shift.
    std::vector<std::pair<int, cv::Point2d>> moved_cameras;
};

struct TrackerSettings
{
    tip_candidates::ObservationSettings observation;
    tip_candidates::ViewChangeSettings view_change;
    geometry::LocateSettings locate;
    geometry::BoardCheckSettings board_check;
    // Half size of the patch around each axis point in which a change is compared with the empty board and the last state
    int patch_px = 2;
    // A still moment holds at most this many changes: a pulled dart and the one put in, and one more for safety
    int max_changes = 3;
    // How far around the axis of a pulled dart the board is taken as it is now, so that its flight is covered as well
    int pulled_reach_px = 45;
    // All darts are pulled when at most this many cameras still see something against the empty board: a dart in the
    // board stands out to at least two cameras, while a single camera may keep a trace of a pushed-out fibre.
    int takeout_max_cameras = 1;
};

class DartTracker
{
   public:
    DartTracker (std::vector<TrackerCamera> cameras, geometry::BoardModel board, TrackerSettings settings = {});

    // From the next still moment on
    void setSettings (const TrackerSettings& settings) { settings_ = settings; }

    // The mean images of all cameras at a still moment, in the order of the cameras
    TrackerUpdate addStill (const std::vector<cv::Mat>& images);

    bool ready () const { return !reference_.empty(); }
    int dartsInBoard () const { return darts_in_board_; }

   private:
    std::vector<TrackerCamera> cameras_;
    geometry::BoardModel board_;
    TrackerSettings settings_;
    // The empty board, refreshed after every takeout, and the board at the last still moment
    std::vector<cv::Mat> reference_;
    std::vector<cv::Mat> last_;
    int darts_in_board_ = 0;
    // Per camera the image outside the board that viewChange compares, for the radius it was made for
    std::vector<cv::Mat> view_regions_;
    double view_regions_radius_mm_ = -1.0;
    const cv::Mat& viewRegion (std::size_t camera, const cv::Size& size);
};
}  // namespace dartpilot::fusion
