#include "session_recording.hpp"

#include "dartpilot/version.hpp"
#include "paths.hpp"
#include "record_command.hpp"

namespace dartpilot::cli
{
namespace
{
// The event window of a live throw: the still moment the dart was found in follows the throw by up to a few seconds.
constexpr std::int64_t kWindowBefore_ns = 3'000'000'000;
constexpr std::int64_t kWindowAfter_ns = 2'000'000'000;
}  // namespace

std::unique_ptr<SessionRecording> SessionRecording::start (const std::filesystem::path& sessions_directory, const std::string& session_id,
                                                           const std::vector<capture::CameraDevice>& devices, CameraPreviews& previews,
                                                           std::string& error)
{
    session::SessionInfo info;
    info.session_id = session_id;
    info.created_utc = session::utcNow();
    info.notes = "Recorded by dartpilot serve while playing";
    for(const auto& device : devices)
    {
        info.cameras.push_back(recordedCamera(device, streamSettings(device)));
    }
    auto writer = session::SessionWriter::create(sessions_directory, info, error);
    if(!writer)
    {
        return nullptr;
    }
    std::unique_ptr<SessionRecording> recording(new SessionRecording());
    recording->previews_ = &previews;
    recording->cameras_ = devices.size();
    const auto results = writer->directory() / "results" / "live";
    std::filesystem::create_directories(results);
    std::ofstream(results / "run.json") << nlohmann::json{{"run_id", "live"},
                                                          {"software", {{"version", std::string(kVersion)}, {"commit", std::string(kGitCommit)}}},
                                                          {"config", nlohmann::json::object()}}
                                               .dump(2)
                                        << "\n";
    recording->throws_jsonl_.open(results / "throws.jsonl");
    recording->throws_csv_.open(writer->directory() / "throws.csv");
    recording->throws_csv_ << "throw_id,event_ns,window_start_ns,window_end_ns,source\n";
    recording->writer_ = std::move(writer);
    previews.record(recording->writer_.get());
    return recording;
}

SessionRecording::~SessionRecording ()
{
    previews_->record(nullptr);
    std::vector<capture::CaptureStats> stats;
    for(std::size_t c = 0; c < cameras_; ++c)
    {
        stats.push_back(previews_->stats(c));
    }
    writer_->finish(session::utcNow(), stats);
}

void SessionRecording::log (const nlohmann::json& record)
{
    std::lock_guard lock(mutex_);
    throws_jsonl_ << record.dump() << "\n" << std::flush;
    // Throws and added darts get their event window, so their frames can be found again (docs/replay-format.md).
    std::int64_t event_ns = 0;
    std::string source;
    if(record.contains("diagnostics") && record["diagnostics"].contains("event_ns"))
    {
        event_ns = record["diagnostics"]["event_ns"].get<std::int64_t>();
        source = "live";
    }
    else if(record.contains("correction") && record["correction"].value("action", std::string()) == "added")
    {
        event_ns = record["correction"]["event_ns"].get<std::int64_t>();
        source = "manual";
    }
    if(!source.empty())
    {
        throws_csv_ << record["throw_id"].get<std::string>() << ',' << event_ns << ',' << event_ns - kWindowBefore_ns << ','
                    << event_ns + kWindowAfter_ns << ',' << source << "\n"
                    << std::flush;
    }
}
}  // namespace dartpilot::cli
