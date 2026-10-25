#include "dartpilot/replay/replay.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <memory>
#include <sstream>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/scoring/score.hpp"
#include "dartpilot/session/json.hpp"
#include "dartpilot/session/sha256.hpp"
#include "dartpilot/version.hpp"
#include "pipelines.hpp"

namespace dartpilot::replay
{
namespace
{
using session::jsonString;

// Fixed precision, so the same numbers always give the same bytes
std::string number (double value, int decimals = 4)
{
    std::array<char, 64> text{};
    std::snprintf(text.data(), text.size(), "%.*f", decimals, value);
    return text.data();
}

// Frames of one camera being collected for a calibration check
struct PendingCheck
{
    cv::Mat sum;
    std::vector<std::uint32_t> sequences;
    std::int64_t first_exposure_ns = 0;
};

struct CameraState
{
    const geometry::RefinedCamera* calibration = nullptr;
    std::int64_t next_check_ns = 0;
    bool started = false;
    std::optional<PendingCheck> pending;
};

std::string checkLine (const std::string& camera, const PendingCheck& pending, const std::optional<geometry::CalibrationCheck>& check)
{
    std::ostringstream line;
    line << "{\"camera\": " << jsonString(camera) << ", \"exposure_ns\": " << pending.first_exposure_ns << ", \"frames\": [";
    for(std::size_t i = 0; i < pending.sequences.size(); ++i)
    {
        line << (i == 0 ? "" : ", ") << pending.sequences[i];
    }
    line << "], \"board_found\": " << (check ? "true" : "false");
    if(check)
    {
        line << ", \"rms_mm\": " << number(check->rms_mm) << ", \"rms_px\": " << number(check->rms_px)
             << ", \"worst_px\": " << number(check->worst_px) << ", \"shift_px\": [" << number(check->mean_shift_px.x) << ", "
             << number(check->mean_shift_px.y) << "], \"edge_offset_mm\": " << number(check->edge_offset_mm, 2)
             << ", \"twenty_sector\": " << check->twenty_sector;
    }
    line << "}\n";
    return line.str();
}

const char* ringName (scoring::Ring ring)
{
    switch(ring)
    {
        case scoring::Ring::InnerBull:
            return "inner_bull";
        case scoring::Ring::OuterBull:
            return "outer_bull";
        case scoring::Ring::InnerSingle:
            return "inner_single";
        case scoring::Ring::Triple:
            return "triple";
        case scoring::Ring::OuterSingle:
            return "outer_single";
        case scoring::Ring::Double:
            return "double";
        case scoring::Ring::Miss:
            break;
    }
    return "miss";
}

std::string distance (double value_mm) { return std::isfinite(value_mm) ? number(value_mm) : "null"; }

std::string boardPoint (const cv::Point2f& point_mm, const std::optional<cv::Matx22d>& covariance_mm2)
{
    std::string text = "{\"x_mm\": " + number(point_mm.x) + ", \"y_mm\": " + number(point_mm.y);
    if(covariance_mm2)
    {
        const auto& c = *covariance_mm2;
        text += ", \"covariance_mm2\": {\"xx\": " + number(c(0, 0)) + ", \"xy\": " + number(c(0, 1)) + ", \"yy\": " + number(c(1, 1)) + "}";
    }
    return text + "}";
}

std::string scoreJson (const cv::Point2f& point_mm)
{
    const auto s = scoring::score(point_mm.x, point_mm.y);
    return std::string("{\"ring\": \"") + ringName(s.ring) + "\", \"sector\": " + std::to_string(s.sector) +
           ", \"multiplier\": " + std::to_string(s.multiplier) + ", \"points\": " + std::to_string(s.points) +
           ", \"label\": " + jsonString(scoring::label(s)) + ", \"boundary_distance_mm\": " + distance(s.boundary_distance_mm) +
           ", \"ring_boundary_distance_mm\": " + distance(s.ring_boundary_distance_mm) +
           ", \"sector_boundary_distance_mm\": " + distance(s.sector_boundary_distance_mm) + ", \"board_geometry\": \"nominal\"}";
}

std::string sequences (const std::vector<std::uint32_t>& frames)
{
    std::string text = "[";
    for(std::size_t i = 0; i < frames.size(); ++i)
    {
        text += (i == 0 ? "" : ", ") + std::to_string(frames[i]);
    }
    return text + "]";
}

struct ThrowEvent
{
    std::string throw_id;
    std::int64_t event_ns = 0;
    std::int64_t window_start_ns = 0;
    std::int64_t window_end_ns = 0;
};

std::string throwLine (const session::RecordedSession& session, const ReplayConfig& config, const ThrowEvent& event, const DetectedDart& dart,
                       const std::vector<std::vector<std::uint32_t>>& baseline_frames, const std::vector<std::vector<std::uint32_t>>& after_frames)
{
    std::ostringstream line;
    const bool accepted = dart.board_mm.has_value();
    line << "{\"throw_id\": " << jsonString(event.throw_id) << ", \"accepted\": " << (accepted ? "true" : "false")
         << ", \"board_point\": " << (accepted ? boardPoint(*dart.board_mm, dart.covariance_mm2) : "null")
         << ", \"score\": " << (accepted ? scoreJson(*dart.board_mm) : "null") << ", \"confidence\": "
         << number(!accepted                    ? config.detection.confidence.abstained
                   : dart.cameras_agreeing >= 3 ? config.detection.confidence.three_cameras
                                                : config.detection.confidence.two_cameras,
                   2)
         << ", \"camera_measurements\": [";
    for(std::size_t c = 0; c < session.cameras.size() && c < dart.cameras.size(); ++c)
    {
        const auto& camera = dart.cameras[c];
        line << (c == 0 ? "" : ", ") << "{\"camera\": " << jsonString(session.cameras[c].id)
             << ", \"frames\": {\"baseline\": " << sequences(c < baseline_frames.size() ? baseline_frames[c] : std::vector<std::uint32_t>{})
             << ", \"after\": " << sequences(after_frames[c]) << "}, \"tip_candidates\": [";
        if(camera.tip_px)
        {
            line << "{\"pixel_xy\": [" << number(camera.tip_px->x, 1) << ", " << number(camera.tip_px->y, 1) << "]}";
        }
        line << "], \"selected_candidate\": " << (camera.tip_px ? "0" : "null")
             << ", \"board_point\": " << (camera.board_mm ? boardPoint(*camera.board_mm, std::nullopt) : "null")
             << ", \"state\": " << jsonString(camera.state) << ", \"used\": " << (camera.used ? "true" : "false") << "}";
    }
    line << "], \"diagnostics\": {\"pipeline\": " << jsonString(config.pipeline) << ", \"event_ns\": " << event.event_ns
         << ", \"window_start_ns\": " << event.window_start_ns << ", \"window_end_ns\": " << event.window_end_ns
         << ", \"cameras_agreeing\": " << dart.cameras_agreeing << ", \"reason\": " << (dart.reason.empty() ? "null" : jsonString(dart.reason))
         << "}, \"processing_latency_ms\": null}\n";
    return line.str();
}

std::string configJson (const ReplayConfig& config)
{
    std::string params;
    for(const auto& param : fusion::detectionParams())
    {
        params += (params.empty() ? "" : ", ") + jsonString(param.name) + ": " + number(param.get(config.detection), 6);
    }
    return "{\"calibration_check\": {\"interval_ns\": " + std::to_string(config.check_interval_ns) +
           ", \"frames\": " + std::to_string(config.check_frames) + "}, \"pipeline\": " + jsonString(config.pipeline) + ", \"params\": {" + params +
           "}}";
}
}  // namespace

std::string_view moduleName () { return "replay"; }

std::vector<ReplayFrame> replayOrder (const session::RecordedSession& session)
{
    std::vector<ReplayFrame> order;
    for(std::size_t c = 0; c < session.cameras.size(); ++c)
    {
        for(std::size_t f = 0; f < session.cameras[c].frames.size(); ++f)
        {
            order.push_back({c, f});
        }
    }
    // Stable, so frames of one camera with equal times keep their recorded order.
    std::stable_sort(order.begin(), order.end(),
                     [&] (const ReplayFrame& a, const ReplayFrame& b)
                     {
                         const auto ta = session.cameras[a.camera].frames[a.frame].exposure_ns;
                         const auto tb = session.cameras[b.camera].frames[b.frame].exposure_ns;
                         return ta != tb ? ta < tb : session.cameras[a.camera].id < session.cameras[b.camera].id;
                     });
    return order;
}

std::optional<ReplaySummary> replaySession (const session::RecordedSession& session, const ReplayConfig& config, std::string& error)
{
    if(config.run_id.empty() || config.run_id.find('/') != std::string::npos || config.run_id == "." || config.run_id == "..")
    {
        error = "Invalid run id \"" + config.run_id + "\"";
        return std::nullopt;
    }
    std::vector<const geometry::RefinedCamera*> calibrations(session.cameras.size(), nullptr);
    for(std::size_t c = 0; c < session.cameras.size() && config.extrinsics; ++c)
    {
        for(const auto& refined : config.extrinsics->refinement.cameras)
        {
            if(refined.usb_port == session.cameras[c].usb_port)
            {
                calibrations[c] = &refined;
            }
        }
    }
    std::unique_ptr<Pipeline> pipeline;
    if(config.pipeline != "none")
    {
        if(!config.extrinsics)
        {
            error = "Throw detection needs the board refinement";
            return std::nullopt;
        }
        pipeline = makePipeline(config.pipeline, calibrations, config.extrinsics->refinement.board, config.detection.tracker);
        if(!pipeline)
        {
            error = "Unknown pipeline \"" + config.pipeline + "\"; known are tracker, baseline and none";
            return std::nullopt;
        }
    }
    ReplaySummary summary;
    summary.run_directory = session.directory / "results" / config.run_id;
    std::error_code fs_error;
    if(std::filesystem::exists(summary.run_directory, fs_error))
    {
        error = summary.run_directory.string() + " exists already; choose another run id";
        return std::nullopt;
    }
    if(!std::filesystem::create_directories(summary.run_directory, fs_error))
    {
        error = "Cannot create " + summary.run_directory.string() + ": " + fs_error.message();
        return std::nullopt;
    }

    const std::string config_json = configJson(config);
    {
        std::ofstream run(summary.run_directory / "run.json");
        run << "{\n";
        run << "  \"run_id\": " << jsonString(config.run_id) << ",\n";
        run << "  \"session_id\": " << jsonString(session.session_id) << ",\n";
        run << "  \"software\": { \"version\": " << jsonString(std::string(kVersion)) << ", \"commit\": " << jsonString(std::string(kGitCommit))
            << " },\n";
        run << "  \"config\": " << config_json << ",\n";
        run << "  \"config_sha256\": "
            << jsonString(session::sha256Hex(std::span(reinterpret_cast<const std::uint8_t*>(config_json.data()), config_json.size()))) << ",\n";
        run << "  \"calibration\": {";
        for(std::size_t c = 0; c < session.cameras.size(); ++c)
        {
            const auto& camera = session.cameras[c];
            run << (c == 0 ? "\n" : ",\n") << "    " << jsonString(camera.id)
                << ": { \"intrinsics_sha256\": " << (camera.intrinsics ? jsonString(camera.intrinsics->sha256) : "null")
                << ", \"extrinsics_sha256\": " << (config.extrinsics ? jsonString(config.extrinsics_sha256) : "null") << " }";
        }
        run << "\n  }\n}\n";
        if(!run)
        {
            error = "Cannot write run.json";
            return std::nullopt;
        }
    }
    std::ofstream throws(summary.run_directory / "throws.jsonl");
    std::ofstream checks(summary.run_directory / "calibration_checks.jsonl");
    if(!throws || !checks)
    {
        error = "Cannot create the result files in " + summary.run_directory.string();
        return std::nullopt;
    }

    std::vector<CameraState> cameras(session.cameras.size());
    std::vector<session::FrameReader> readers;
    for(std::size_t c = 0; c < session.cameras.size(); ++c)
    {
        readers.emplace_back(session, c);
        if(config.check_interval_ns > 0)
        {
            cameras[c].calibration = calibrations[c];
        }
    }

    // Throw detection samples every camera's latest frame at fixed steps of recorded time, as live detection does.
    event_detection::StillDetector still(session.cameras.size(), config.detection.still);
    std::vector<std::optional<std::size_t>> latest(session.cameras.size()), sampled(session.cameras.size());
    std::optional<std::int64_t> next_sample_ns;
    std::optional<event_detection::StillMoment> previous_moment;
    std::vector<bool> matched(session.throws.size(), false);
    std::vector<ThrowEvent> new_session_throws;
    const auto throwId = [&] (std::int64_t event_ns)
    {
        if(session.throws.empty())
        {
            return session.session_id + "/" + std::to_string(summary.throws);
        }
        std::optional<std::size_t> best;
        for(std::size_t i = 0; i < session.throws.size(); ++i)
        {
            const auto& recorded = session.throws[i];
            if(!matched[i] && event_ns >= recorded.window_start_ns && event_ns <= recorded.window_end_ns &&
               (!best || std::llabs(event_ns - recorded.event_ns) < std::llabs(event_ns - session.throws[*best].event_ns)))
            {
                best = i;
            }
        }
        if(best)
        {
            matched[*best] = true;
            return session.throws[*best].throw_id;
        }
        ++summary.unmatched_throws;
        return session.session_id + "/unmatched-" + std::to_string(summary.unmatched_throws);
    };
    const auto sample = [&] (std::int64_t time_ns)
    {
        std::vector<std::optional<event_detection::StillSample>> samples(session.cameras.size());
        for(std::size_t c = 0; c < session.cameras.size(); ++c)
        {
            if(!latest[c] || latest[c] == sampled[c])
            {
                continue;
            }
            sampled[c] = latest[c];
            const auto& index = session.cameras[c].frames[*latest[c]];
            cv::Mat image = cv::imdecode(readers[c].read(*latest[c]), cv::IMREAD_COLOR);
            if(image.empty())
            {
                ++summary.undecodable_frames;
                continue;
            }
            samples[c] = event_detection::StillSample{std::move(image), index.sequence, index.exposure_ns};
        }
        const auto moment = still.addSample(time_ns, samples, !pipeline->ready());
        if(!moment)
        {
            return;
        }
        const auto result = pipeline->addStill(moment->means);
        summary.takeouts += result.takeout ? 1 : 0;
        if(result.dart)
        {
            ++summary.throws;
            summary.abstained += result.dart->board_mm ? 0 : 1;
            ThrowEvent event{"", moment->start_ns, previous_moment ? previous_moment->start_ns : moment->start_ns, moment->end_ns};
            event.throw_id = throwId(event.event_ns);
            if(session.throws.empty())
            {
                new_session_throws.push_back(event);
            }
            throws << throwLine(session, config, event, *result.dart,
                                previous_moment ? previous_moment->frames : std::vector<std::vector<std::uint32_t>>{}, moment->frames);
        }
        previous_moment = *moment;
    };

    for(const ReplayFrame& item : replayOrder(session))
    {
        ++summary.frames;
        const session::FrameIndex& index = session.cameras[item.camera].frames[item.frame];
        if(pipeline)
        {
            if(!next_sample_ns)
            {
                next_sample_ns = index.exposure_ns;
            }
            while(*next_sample_ns < index.exposure_ns)
            {
                sample(*next_sample_ns);
                *next_sample_ns += config.detection.still.sample_interval_ns;
            }
            latest[item.camera] = item.frame;
        }
        CameraState& state = cameras[item.camera];
        if(!state.calibration)
        {
            continue;
        }
        if(!state.pending && (!state.started || index.exposure_ns >= state.next_check_ns))
        {
            state.started = true;
            state.pending = PendingCheck{};
            state.pending->first_exposure_ns = index.exposure_ns;
            state.next_check_ns = index.exposure_ns + config.check_interval_ns;
        }
        if(!state.pending)
        {
            continue;
        }
        // Frames are decoded only where a stage needs them.
        const cv::Mat image = cv::imdecode(readers[item.camera].read(item.frame), cv::IMREAD_COLOR);
        if(image.empty())
        {
            ++summary.undecodable_frames;
            continue;
        }
        PendingCheck& pending = *state.pending;
        if(pending.sum.empty())
        {
            pending.sum = cv::Mat::zeros(image.size(), CV_32FC3);
        }
        if(image.size() != pending.sum.size())
        {
            continue;
        }
        cv::accumulate(image, pending.sum);
        pending.sequences.push_back(index.sequence);
        if(static_cast<int>(pending.sequences.size()) < config.check_frames)
        {
            continue;
        }
        cv::Mat mean;
        pending.sum.convertTo(mean, CV_8UC3, 1.0 / pending.sequences.size());
        std::optional<geometry::CalibrationCheck> check;
        if(const auto detection = geometry::detectBoard(mean))
        {
            check = geometry::checkCalibration(*detection, *state.calibration, config.extrinsics->refinement.board);
        }
        checks << checkLine(session.cameras[item.camera].id, pending, check);
        ++summary.calibration_checks;
        state.pending.reset();
    }
    if(pipeline && next_sample_ns)
    {
        sample(*next_sample_ns);
    }
    if(!checks || !throws)
    {
        error = "Cannot write the results in " + summary.run_directory.string();
        return std::nullopt;
    }
    // The session's throws, so annotations and later runs refer to the same throw ids (docs/replay-format.md)
    const auto throws_csv = session.directory / "throws.csv";
    if(!new_session_throws.empty() && !std::filesystem::exists(throws_csv, fs_error))
    {
        std::ofstream csv(throws_csv);
        csv << "throw_id,event_ns,window_start_ns,window_end_ns,source\n";
        for(const auto& event : new_session_throws)
        {
            csv << event.throw_id << ',' << event.event_ns << ',' << event.window_start_ns << ',' << event.window_end_ns
                << ",replay:" << config.run_id << '\n';
        }
        if(!csv)
        {
            error = "Cannot write " + throws_csv.string();
            return std::nullopt;
        }
        summary.wrote_session_throws = true;
    }
    return summary;
}
}  // namespace dartpilot::replay
