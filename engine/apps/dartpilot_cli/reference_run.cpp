#include "reference_run.hpp"

#include <algorithm>
#include <cmath>
#include <fstream>

#include "dartpilot/session/session_writer.hpp"
#include "dartpilot/version.hpp"

namespace dartpilot::cli
{
namespace
{
using json = nlohmann::json;

double quantile (std::vector<double> values, double q)
{
    if(values.empty())
    {
        return 0.0;
    }
    std::sort(values.begin(), values.end());
    return values[static_cast<std::size_t>(std::lround(q * static_cast<double>(values.size() - 1)))];
}
}  // namespace

json referenceRunMessage (bool running, const std::string& step, const std::vector<fusion::ReferenceTarget>& targets,
                          const std::vector<ReferenceResult>& results)
{
    json message = {{"type", "reference_run"}, {"running", running}, {"step", step}, {"target", nullptr}, {"results", json::array()}};
    // While a dart waits to be pulled, its target is still the current one.
    const std::size_t current = step == "remove_dart" && !results.empty() ? results.size() - 1 : results.size();
    if(current < targets.size() && step != "done")
    {
        const auto& t = targets[current];
        message["target"] = {{"index", current}, {"total", targets.size()}, {"board_mm", {t.board_mm.x, t.board_mm.y}},
                             {"label", t.label}, {"field", t.field},        {"hint_code", t.kind},
                             {"wires", t.wires}};
    }
    std::vector<double> errors;
    int abstained = 0;
    for(std::size_t i = 0; i < results.size() && i < targets.size(); ++i)
    {
        const auto& r = results[i];
        json entry = {{"index", i},
                      {"board_mm", {targets[i].board_mm.x, targets[i].board_mm.y}},
                      {"located_mm", nullptr},
                      {"error_mm", nullptr},
                      {"cameras_used", r.cameras_used}};
        if(r.located_mm)
        {
            const double error_mm = cv::norm(*r.located_mm - targets[i].board_mm);
            entry["located_mm"] = {r.located_mm->x, r.located_mm->y};
            entry["error_mm"] = error_mm;
            errors.push_back(error_mm);
        }
        else
        {
            entry["reason"] = r.reason;
            ++abstained;
        }
        message["results"].push_back(entry);
    }
    message["summary"] = {{"located", errors.size()},
                          {"abstained", abstained},
                          {"median_error_mm", errors.empty() ? json(nullptr) : json(quantile(errors, 0.5))},
                          {"p90_error_mm", errors.empty() ? json(nullptr) : json(quantile(errors, 0.9))},
                          {"max_error_mm", errors.empty() ? json(nullptr) : json(*std::max_element(errors.begin(), errors.end()))}};
    return message;
}

std::optional<std::string> saveReferenceRun (const std::filesystem::path& sessions_directory, const std::vector<fusion::ReferenceTarget>& targets,
                                             const std::vector<ReferenceResult>& results)
{
    const std::string id = session::newSessionId();
    const auto directory = sessions_directory / id;
    std::error_code error;
    std::filesystem::create_directories(directory / "annotations", error);
    std::filesystem::create_directories(directory / "results" / "reference", error);
    if(error)
    {
        return std::nullopt;
    }
    const json manifest = {{"format", "dartpilot-session"},
                           {"version", 1},
                           {"session_id", id},
                           {"created_utc", session::utcNow()},
                           {"notes", "Reference measurement (#14): darts pushed into known wire corners; no frames"},
                           {"cameras", json::array()}};
    std::ofstream(directory / "manifest.json") << manifest.dump(2) << "\n";
    std::ofstream annotations(directory / "annotations" / "reference_corners.jsonl");
    std::ofstream throws(directory / "results" / "reference" / "throws.jsonl");
    // The target's uncertainty: the spread of wire and point thickness and how the point sits, about 0.5 mm
    constexpr double kTargetVariance_mm2 = 0.25;
    for(std::size_t i = 0; i < results.size() && i < targets.size(); ++i)
    {
        const std::string throw_id = id + "/" + std::to_string(i + 1);
        annotations << json{{"throw_id", throw_id},
                            {"x_mm", targets[i].board_mm.x},
                            {"y_mm", targets[i].board_mm.y},
                            {"covariance_mm2", {{"xx", kTargetVariance_mm2}, {"xy", 0.0}, {"yy", kTargetVariance_mm2}}},
                            {"source", "reference_corner"},
                            {"label", targets[i].label}}
                           .dump()
                    << "\n";
        const auto& r = results[i];
        json point = nullptr;
        if(r.located_mm)
        {
            point = {{"x_mm", r.located_mm->x},
                     {"y_mm", r.located_mm->y},
                     {"covariance_mm2", {{"xx", r.covariance_mm2(0, 0)}, {"xy", r.covariance_mm2(0, 1)}, {"yy", r.covariance_mm2(1, 1)}}}};
        }
        throws << json{{"throw_id", throw_id},
                       {"accepted", r.located_mm.has_value()},
                       {"board_point", point},
                       {"score", nullptr},
                       {"camera_measurements", json::array()},
                       {"diagnostics", {{"cameras_used", r.cameras_used}, {"reason", r.reason}}},
                       {"processing_latency_ms", nullptr}}
                      .dump()
               << "\n";
    }
    std::ofstream(directory / "results" / "reference" / "run.json")
        << json{{"run_id", "reference"}, {"software", {{"version", std::string(kVersion)}}}, {"config", json::object()}}.dump(2) << "\n";
    return id;
}

std::vector<json> exampleReferenceRun ()
{
    const auto targets = fusion::referenceTargets({});
    std::vector<ReferenceResult> results;
    std::vector<json> messages = {referenceRunMessage(true, "insert_dart", targets, results)};
    for(std::size_t i = 0; i < targets.size(); ++i)
    {
        ReferenceResult result;
        if(i == 7)
        {
            result.reason = "cameras_disagree";
        }
        else
        {
            // A few tenths of a millimetre off, in a fixed pattern
            const double angle = static_cast<double>(i) * 2.4;
            const double error_mm = 0.3 + 0.12 * static_cast<double>(i % 5);
            result.located_mm = targets[i].board_mm + cv::Point2d(error_mm * std::cos(angle), error_mm * std::sin(angle));
            result.cameras_used = i % 3 == 0 ? 2 : 3;
        }
        results.push_back(result);
        messages.push_back(referenceRunMessage(true, "remove_dart", targets, results));
        const bool last = i + 1 == targets.size();
        messages.push_back(referenceRunMessage(!last, last ? "done" : "insert_dart", targets, results));
    }
    return messages;
}

ReferenceRun::ReferenceRun (api::Server& server, LiveDetection& detection, const std::filesystem::path& calibration_directory,
                            std::filesystem::path sessions_directory)
    : server_(server)
    , detection_(detection)
    , extrinsics_(geometry::loadExtrinsics((calibration_directory / "extrinsics.yml").string()))
    , sessions_directory_(std::move(sessions_directory))
{
    if(extrinsics_)
    {
        targets_ = fusion::referenceTargets(extrinsics_->refinement.board);
    }
    server_.onCalibrationRequest("start_reference_run", [this] (const api::CalibrationRequest&) { return start(); });
    server_.onCalibrationRequest("stop_reference_run",
                                 [this] (const api::CalibrationRequest&) -> std::optional<api::Server::CalibrationError>
                                 {
                                     stop();
                                     return std::nullopt;
                                 });
}

ReferenceRun::~ReferenceRun ()
{
    server_.onCalibrationRequest("start_reference_run", {});
    server_.onCalibrationRequest("stop_reference_run", {});
    detection_.intercept({});
}

std::optional<api::Server::CalibrationError> ReferenceRun::start ()
{
    if(targets_.empty() || detection_.unavailableReason())
    {
        return api::Server::CalibrationError{"not_calibrated", "The cameras are not refined yet"};
    }
    {
        std::lock_guard lock(mutex_);
        running_ = true;
        results_.clear();
        step_ = detection_.ready() ? "insert_dart" : "empty_board";
    }
    detection_.intercept([this] (const fusion::TrackerUpdate& update, const std::vector<cv::Mat>&) { onUpdate(update); });
    publish();
    return std::nullopt;
}

void ReferenceRun::stop ()
{
    detection_.intercept({});
    {
        std::lock_guard lock(mutex_);
        running_ = false;
    }
    publish();
}

void ReferenceRun::onUpdate (const fusion::TrackerUpdate& update)
{
    bool finished = false;
    {
        std::lock_guard lock(mutex_);
        if(update.became_ready && step_ == "empty_board")
        {
            step_ = "insert_dart";
        }
        if(update.dart && step_ == "insert_dart")
        {
            ReferenceResult result;
            if(update.dart->location)
            {
                result.located_mm = cv::Point2d(update.dart->location->board_mm.x, update.dart->location->board_mm.y);
                result.cameras_used = static_cast<int>(update.dart->location->views.size());
                result.covariance_mm2 = update.dart->location->covariance_mm2;
            }
            else
            {
                result.reason = update.dart->reason;
            }
            results_.push_back(result);
            step_ = "remove_dart";
        }
        // The next target once the board is empty again; done only after the last dart is pulled
        if(update.takeout && step_ == "remove_dart")
        {
            step_ = results_.size() < targets_.size() ? "insert_dart" : "done";
            finished = step_ == "done";
            running_ = !finished;
        }
    }
    if(finished)
    {
        detection_.intercept({});
        std::lock_guard lock(mutex_);
        saved_session_ = saveReferenceRun(sessions_directory_, targets_, results_).value_or("");
    }
    publish();
}

void ReferenceRun::publish ()
{
    std::lock_guard lock(mutex_);
    auto message = referenceRunMessage(running_, step_, targets_, results_);
    message["saved_session"] = saved_session_.empty() ? json(nullptr) : json(saved_session_);
    server_.publishState(message);
}
}  // namespace dartpilot::cli
