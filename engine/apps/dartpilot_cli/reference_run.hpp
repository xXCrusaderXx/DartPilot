#pragma once

#include <filesystem>
#include <functional>
#include <mutex>
#include <optional>
#include <vector>

#include <nlohmann/json.hpp>

#include "dartpilot/api/server.hpp"
#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/fusion/reference_targets.hpp"
#include "live_detection.hpp"

// The guided reference measurement of #14: the user pushes a dart into one known wire corner after the other, and the
// live detection locates it; the distance from the corner is the error of the whole chain from calibration to tip.
namespace dartpilot::cli
{
struct ReferenceResult
{
    std::optional<cv::Point2d> located_mm;
    cv::Matx22d covariance_mm2 = cv::Matx22d::zeros();
    int cameras_used = 0;
    std::string reason;
};

// The reference_run message for targets and the results so far (docs/engine-api.md)
nlohmann::json referenceRunMessage (bool running, const std::string& step, const std::vector<fusion::ReferenceTarget>& targets,
                                    const std::vector<ReferenceResult>& results);

// Stores a finished run as a small session in the format of docs/replay-format.md, so the benchmark (#17) can score it:
// the targets as the annotation set reference_corners, the located darts as the run "reference". Returns the session
// id, or nothing if it cannot be written.
std::optional<std::string> saveReferenceRun (const std::filesystem::path& sessions_directory, const std::vector<fusion::ReferenceTarget>& targets,
                                             const std::vector<ReferenceResult>& results);

// The messages of a whole run on the nominal board with made-up results, for `serve --simulate`
std::vector<nlohmann::json> exampleReferenceRun ();

class ReferenceRun
{
   public:
    ReferenceRun (api::Server& server, LiveDetection& detection, const std::filesystem::path& calibration_directory,
                  std::filesystem::path sessions_directory);
    ~ReferenceRun ();

    // While serve records a session: every placed dart also goes into it, as a throw (through log) and with its target
    // in the annotation set reference_corners, so a replay of the recording can measure each camera against the
    // targets (#22, #205).
    void recordInto (std::filesystem::path session_directory, std::string session_id, std::function<void(const nlohmann::json&)> log);

   private:
    std::optional<api::Server::CalibrationError> start ();
    void stop ();
    // On the detection thread
    void onUpdate (const fusion::TrackerUpdate& update);
    void publish ();
    // Under mutex_
    void record (std::size_t index, const fusion::TrackedDart& dart);

    api::Server& server_;
    LiveDetection& detection_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<fusion::ReferenceTarget> targets_;

    std::mutex mutex_;
    bool running_ = false;
    std::string step_;
    std::vector<ReferenceResult> results_;
    std::filesystem::path sessions_directory_;
    std::string saved_session_;
    std::filesystem::path recording_directory_;
    std::string recording_id_;
    std::function<void(const nlohmann::json&)> recording_log_;
    // Counts the runs within one recording, so their throw ids stay apart
    int recorded_runs_ = 0;
};
}  // namespace dartpilot::cli
