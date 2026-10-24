#include "dartpilot/replay/replay.hpp"

#include <algorithm>
#include <array>
#include <cstdio>
#include <fstream>
#include <sstream>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/session/json.hpp"
#include "dartpilot/session/sha256.hpp"
#include "dartpilot/version.hpp"

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

std::string configJson (const ReplayConfig& config)
{
    return "{\"calibration_check\": {\"interval_ns\": " + std::to_string(config.check_interval_ns) +
           ", \"frames\": " + std::to_string(config.check_frames) + "}}";
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
    // No throw detection exists yet (#18); the file is there so readers find every run complete.
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
        if(config.extrinsics && config.check_interval_ns > 0)
        {
            for(const auto& refined : config.extrinsics->refinement.cameras)
            {
                if(refined.usb_port == session.cameras[c].usb_port)
                {
                    cameras[c].calibration = &refined;
                }
            }
        }
    }

    for(const ReplayFrame& item : replayOrder(session))
    {
        ++summary.frames;
        const session::FrameIndex& index = session.cameras[item.camera].frames[item.frame];
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
    if(!checks || !throws)
    {
        error = "Cannot write the results in " + summary.run_directory.string();
        return std::nullopt;
    }
    return summary;
}
}  // namespace dartpilot::replay
