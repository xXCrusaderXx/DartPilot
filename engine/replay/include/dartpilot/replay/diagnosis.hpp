#pragma once

#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/session/session_reader.hpp"

// Setup diagnosis (#137): analyses a test (empty board, then darts one at a time, the hand taken away each time), from a
// recording or live from the cameras, and tells the user what to fix, each finding with a hint. The checks are the ones that found camera drift,
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
    // Stable name of the finding and the numbers in its message, so that a client can word it in its own language
    std::string code;
    std::map<std::string, double> values;
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

// The checks, fed one still period at a time: from a recording by diagnoseSession, and live by `dartpilot serve`.
// Each empty period becomes the reference for the next dart, as after a takeout in a game.
class DiagnosisBuilder
{
   public:
    struct Camera
    {
        std::string id;
        // Nothing if the camera has no refinement; its calibration and dart checks are then skipped.
        const geometry::RefinedCamera* calibration = nullptr;
    };

    // board: from the refinement, nothing without one. wait_for_empty_board: periods are ignored until a still board
    // shows all its wires to every camera, instead of reporting a board that is not empty at the start.
    DiagnosisBuilder (std::vector<Camera> cameras, std::optional<geometry::BoardModel> board, bool wait_for_empty_board);

    // Adds a still period with each camera's mean image (empty if the camera had none). False, without adding it, while
    // waiting for an empty board.
    bool addPeriod (double start_s, double end_s, const std::vector<cv::Mat>& means);
    // Frames received and lost by a camera so far
    void setCapture (std::size_t camera, std::uint64_t frames, std::uint64_t lost_frames);
    // A finding of the caller's own, e.g. on the still moments of a recording
    void addFinding (Finding finding);

    const std::vector<Period>& periods () const { return periods_; }
    // Whether an empty board was seen, so that darts can be compared with it
    bool hasReference () const;
    // The periods so far and their findings, most severe first
    Diagnosis diagnosis () const;

   private:
    std::vector<Camera> cameras_;
    std::optional<geometry::BoardModel> board_;
    bool wait_for_empty_board_ = false;
    std::vector<Period> periods_;
    std::vector<cv::Mat> reference_;
    std::vector<int> board_changes_;
    std::vector<std::pair<std::uint64_t, std::uint64_t>> capture_;
    std::vector<Finding> findings_;
};

// Nothing and an error message if the session cannot be read. Without a refinement, the calibration and dart checks
// are skipped and say so. Deterministic: the same session and refinement give the same diagnosis.
std::optional<Diagnosis> diagnoseSession (const session::RecordedSession& session, const geometry::StoredExtrinsics* extrinsics, std::string& error);

std::string toJson (const Diagnosis& diagnosis);
std::string toMarkdown (const Diagnosis& diagnosis);
}  // namespace dartpilot::replay
