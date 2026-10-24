#pragma once

#include <filesystem>
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
    int cameras_used = 0;
    std::string reason;
};

// The reference_run message for targets and the results so far (docs/engine-api.md)
nlohmann::json referenceRunMessage (bool running, const std::string& step, const std::vector<fusion::ReferenceTarget>& targets,
                                    const std::vector<ReferenceResult>& results);

// The messages of a whole run on the nominal board with made-up results, for `serve --simulate`
std::vector<nlohmann::json> exampleReferenceRun ();

class ReferenceRun
{
   public:
    ReferenceRun (api::Server& server, LiveDetection& detection, const std::filesystem::path& calibration_directory);
    ~ReferenceRun ();

   private:
    std::optional<api::Server::CalibrationError> start ();
    void stop ();
    // On the detection thread
    void onUpdate (const fusion::TrackerUpdate& update);
    void publish ();

    api::Server& server_;
    LiveDetection& detection_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    std::vector<fusion::ReferenceTarget> targets_;

    std::mutex mutex_;
    bool running_ = false;
    std::string step_;
    std::vector<ReferenceResult> results_;
};
}  // namespace dartpilot::cli
