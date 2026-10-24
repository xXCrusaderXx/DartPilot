#pragma once

#include <optional>
#include <string>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/dart_location.hpp"

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
    // Darts that were in the board when it was found empty again
    std::optional<int> takeout;
    // The tracker has an empty board to compare with and detects darts from now on
    bool became_ready = false;
    // Cameras whose whole image moved since the last still moment (knocked or loosened): their change is not a dart,
    // and their calibration needs checking. Index of the camera and the image shift.
    std::vector<std::pair<int, cv::Point2d>> moved_cameras;
};

class DartTracker
{
   public:
    DartTracker (std::vector<TrackerCamera> cameras, geometry::BoardModel board);

    // The mean images of all cameras at a still moment, in the order of the cameras
    TrackerUpdate addStill (const std::vector<cv::Mat>& images);

    bool ready () const { return !reference_.empty(); }
    int dartsInBoard () const { return darts_in_board_; }

   private:
    std::vector<TrackerCamera> cameras_;
    geometry::BoardModel board_;
    // The empty board, refreshed after every takeout, and the board at the last still moment
    std::vector<cv::Mat> reference_;
    std::vector<cv::Mat> last_;
    int darts_in_board_ = 0;
};
}  // namespace dartpilot::fusion
