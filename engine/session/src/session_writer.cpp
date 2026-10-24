#include "dartpilot/session/session_writer.hpp"

#include <array>
#include <cmath>
#include <cstdio>
#include <ctime>
#include <random>
#include <sstream>

#include "dartpilot/session/json.hpp"
#include "dartpilot/version.hpp"

namespace dartpilot::session
{
namespace
{
std::string utcTime (const char* format)
{
    const std::time_t now = std::time(nullptr);
    std::tm utc{};
    ::gmtime_r(&now, &utc);
    std::array<char, 32> text{};
    std::strftime(text.data(), text.size(), format, &utc);
    return text.data();
}
}  // namespace

std::string newSessionId ()
{
    std::random_device random;
    std::array<char, 8> suffix{};
    std::snprintf(suffix.data(), suffix.size(), "%04x", static_cast<unsigned>(random() & 0xffff));
    return utcTime("%Y%m%dT%H%M%SZ") + "-" + suffix.data();
}

std::string utcNow () { return utcTime("%Y-%m-%dT%H:%M:%SZ"); }

struct SessionWriter::CameraFiles
{
    std::ofstream frames;
    std::ofstream index;
    std::ofstream clock;
    std::uint64_t offset = 0;
    CameraTotals totals;
    mutable std::mutex mutex;
};

SessionWriter::SessionWriter (std::filesystem::path directory, SessionInfo info)
    : directory_(std::move(directory))
    , info_(std::move(info))
{
}

SessionWriter::~SessionWriter () = default;

std::unique_ptr<SessionWriter> SessionWriter::create (const std::filesystem::path& root, SessionInfo info, std::string& error)
{
    const std::filesystem::path directory = root / info.session_id;
    std::error_code fs_error;
    if(std::filesystem::exists(directory, fs_error))
    {
        error = directory.string() + " already exists";
        return nullptr;
    }
    std::unique_ptr<SessionWriter> writer(new SessionWriter(directory, std::move(info)));
    for(const auto& camera : writer->info_.cameras)
    {
        const std::filesystem::path camera_dir = directory / "cameras" / camera.id;
        if(!std::filesystem::create_directories(camera_dir, fs_error))
        {
            error = "Cannot create " + camera_dir.string() + ": " + fs_error.message();
            return nullptr;
        }
        auto files = std::make_unique<CameraFiles>();
        files->frames.open(camera_dir / "frames.mjpg", std::ios::binary);
        files->index.open(camera_dir / "frames.csv");
        files->clock.open(camera_dir / "clock.csv");
        if(!files->frames || !files->index || !files->clock)
        {
            error = "Cannot create the files in " + camera_dir.string();
            return nullptr;
        }
        files->index << "sequence,exposure_ns,timestamp_source,driver_ns,arrival_ns,pts,offset,size\n" << std::flush;
        files->clock << "sequence,camera_ticks,host_ns\n" << std::flush;
        writer->cameras_.push_back(std::move(files));
    }
    std::filesystem::create_directories(directory, fs_error);
    writer->health_.open(directory / "capture.csv");
    writer->health_ << "time_ns,camera,frames,lost_frames,overflow_drops,pts_frames,effective_fps,latency_ms,queued,brightness\n" << std::flush;
    if(!writer->health_ || !writer->writeManifest({}, nullptr))
    {
        error = "Cannot write the manifest in " + directory.string();
        return nullptr;
    }
    return writer;
}

bool SessionWriter::writeFrame (std::size_t camera, const capture::Frame& frame)
{
    CameraFiles& files = *cameras_.at(camera);
    std::lock_guard lock(files.mutex);
    files.frames.write(reinterpret_cast<const char*>(frame.data.data()), static_cast<std::streamsize>(frame.data.size()));
    files.frames.flush();
    files.index << frame.sequence << ',' << frame.exposure_ns << ','
                << (frame.timestamp_source == capture::TimestampSource::UvcPts ? "pts" : "driver") << ',' << frame.driver_ns << ','
                << frame.arrival_ns << ',';
    if(frame.pts)
    {
        files.index << *frame.pts;
    }
    files.index << ',' << files.offset << ',' << frame.data.size() << '\n' << std::flush;
    if(frame.clock_sample)
    {
        files.clock << frame.sequence << ',' << frame.clock_sample->camera_ticks << ',' << frame.clock_sample->host_ns << '\n' << std::flush;
    }
    files.offset += frame.data.size();
    ++files.totals.frames_written;
    files.totals.bytes_written += frame.data.size();
    return files.frames.good() && files.index.good();
}

void SessionWriter::writeHealth (std::size_t camera, std::int64_t time_ns, const capture::CaptureStats& stats, double brightness)
{
    std::lock_guard lock(health_mutex_);
    health_ << time_ns << ',' << info_.cameras.at(camera).id << ',' << stats.frames << ',' << stats.lost_frames << ',' << stats.overflow_drops << ','
            << stats.pts_frames << ',' << stats.effective_fps << ',' << stats.latency_ms << ',' << stats.queued << ',';
    if(brightness >= 0)
    {
        health_ << std::lround(brightness * 10) / 10.0;
    }
    health_ << '\n' << std::flush;
}

CameraTotals SessionWriter::totals (std::size_t camera) const
{
    const CameraFiles& files = *cameras_.at(camera);
    std::lock_guard lock(files.mutex);
    return files.totals;
}

bool SessionWriter::writeManifest (const std::string& ended_utc, const std::vector<capture::CaptureStats>* stats) const
{
    std::ostringstream json;
    json << "{\n";
    json << "  \"format\": \"dartpilot-session\",\n";
    json << "  \"version\": " << kFormatVersion << ",\n";
    json << "  \"session_id\": " << jsonString(info_.session_id) << ",\n";
    json << "  \"created_utc\": " << jsonString(info_.created_utc) << ",\n";
    if(!ended_utc.empty())
    {
        json << "  \"ended_utc\": " << jsonString(ended_utc) << ",\n";
    }
    json << "  \"software\": { \"version\": " << jsonString(std::string(kVersion)) << ", \"commit\": " << jsonString(std::string(kGitCommit))
         << " },\n";
    json << "  \"time_base\": \"CLOCK_MONOTONIC\",\n";
    json << "  \"cameras\": [";
    for(std::size_t i = 0; i < info_.cameras.size(); ++i)
    {
        const CameraInfo& camera = info_.cameras[i];
        json << (i == 0 ? "\n" : ",\n") << "    {\n";
        json << "      \"id\": " << jsonString(camera.id) << ",\n";
        json << "      \"usb_port\": " << jsonString(camera.usb_port) << ",\n";
        json << "      \"device_path\": " << jsonString(camera.device_path) << ",\n";
        json << "      \"name\": " << jsonString(camera.name) << ",\n";
        json << "      \"stream\": { \"pixel_format\": \"MJPG\", \"width\": " << camera.stream.width << ", \"height\": " << camera.stream.height
             << ", \"fps\": " << camera.stream.fps << " },\n";
        json << "      \"controls\": {";
        for(std::size_t c = 0; c < camera.controls.size(); ++c)
        {
            json << (c == 0 ? " " : ", ") << jsonString(camera.controls[c].first) << ": " << camera.controls[c].second;
        }
        json << " },\n";
        json << "      \"metadata\": " << (camera.metadata ? "true" : "false") << ",\n";
        json << "      \"calibration\": { \"intrinsics\": ";
        if(camera.intrinsics)
        {
            json << "{ \"file\": " << jsonString(camera.intrinsics->file) << ", \"sha256\": " << jsonString(camera.intrinsics->sha256) << " }";
        }
        else
        {
            json << "null";
        }
        json << ", \"extrinsics\": ";
        if(camera.extrinsics)
        {
            json << "{ \"file\": " << jsonString(camera.extrinsics->file) << ", \"sha256\": " << jsonString(camera.extrinsics->sha256) << " }";
        }
        else
        {
            json << "null";
        }
        json << " }";
        if(stats && i < stats->size())
        {
            const capture::CaptureStats& s = (*stats)[i];
            const CameraTotals written = totals(i);
            json << ",\n      \"summary\": { \"frames\": " << s.frames << ", \"lost_frames\": " << s.lost_frames
                 << ", \"overflow_drops\": " << s.overflow_drops << ", \"pts_frames\": " << s.pts_frames
                 << ", \"frames_written\": " << written.frames_written << ", \"bytes_written\": " << written.bytes_written << " }";
        }
        json << "\n    }";
    }
    json << "\n  ],\n";
    json << "  \"notes\": " << jsonString(info_.notes) << "\n";
    json << "}\n";

    // Written to a temporary file and renamed, so a reader never sees half a manifest.
    const std::filesystem::path target = directory_ / "manifest.json";
    const std::filesystem::path temporary = directory_ / "manifest.json.tmp";
    {
        std::ofstream out(temporary);
        out << json.str();
        if(!out.good())
        {
            return false;
        }
    }
    std::error_code error;
    std::filesystem::rename(temporary, target, error);
    return !error;
}

bool SessionWriter::finish (const std::string& ended_utc, const std::vector<capture::CaptureStats>& stats)
{
    for(auto& files : cameras_)
    {
        std::lock_guard lock(files->mutex);
        files->frames.flush();
        files->index.flush();
        files->clock.flush();
    }
    return writeManifest(ended_utc, &stats);
}
}  // namespace dartpilot::session
