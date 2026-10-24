#pragma once

#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/session/session_reader.hpp"

// Setup diagnosis (#137): analyses a test recording (empty board, then darts one at a time, the hand taken away each
// time) and tells the user what to fix, each finding with a hint. The checks are the ones that found camera drift,
// changes of the board and darts cut by the image border while the dart detection was developed.
namespace dartpilot::replay
{
enum class Severity
{
    Info,
    Warning,
    Problem,
};

std::string_view toString (Severity severity);

struct Finding
{
    Severity severity = Severity::Info;
    // capture, still, drift, calibration, light, board, darts, consistency
    std::string check;
    // Camera id, or empty for all cameras
    std::string camera;
    std::string message;
    std::string hint;
};

// One camera in one still period
struct PeriodCamera
{
    // Calibration check on an empty board: distance of the board points from the calibration, and their common shift
    std::optional<double> calibration_mm;
    std::optional<cv::Point2d> shift_px;
    double brightness = 0.0;
    // Dart observation on a period with a dart: none, cut (by the image border) or seen
    std::string dart;
    double axis_length_px = 0.0;
};

struct Period
{
    double start_s = 0.0;
    double end_s = 0.0;
    // Empty board, or a dart (or other object) in it
    bool empty = true;
    std::vector<PeriodCamera> cameras;
    // For a dart: where the cameras put it, which of them agreed, and how far their axis planes are apart
    std::optional<cv::Point2d> board_mm;
    std::vector<int> agreeing_cameras;
    double worst_plane_mm = 0.0;
};

struct Diagnosis
{
    std::string session_id;
    std::vector<std::string> cameras;
    double duration_s = 0.0;
    std::vector<Period> periods;
    std::vector<Finding> findings;
};

// Nothing and an error message if the session cannot be read. Without a refinement, the calibration and dart checks
// are skipped and say so. Deterministic: the same session and refinement give the same diagnosis.
std::optional<Diagnosis> diagnoseSession (const session::RecordedSession& session, const geometry::StoredExtrinsics* extrinsics, std::string& error);

std::string toJson (const Diagnosis& diagnosis);
std::string toMarkdown (const Diagnosis& diagnosis);
}  // namespace dartpilot::replay
