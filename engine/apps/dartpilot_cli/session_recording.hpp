#pragma once

#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/session/session_writer.hpp"
#include "preview_sources.hpp"

// `dartpilot serve --cameras --record` (#115): a game is recorded as a session, with the engine's throws and the
// players' corrections in results/live/, so that a played session becomes labelled data and can be replayed.
namespace dartpilot::cli
{
class SessionRecording
{
   public:
    // Starts writing the cameras' frames; nothing and an error message if the session cannot be created
    static std::unique_ptr<SessionRecording> start (const std::filesystem::path& sessions_directory, const std::string& session_id,
                                                    const std::vector<capture::CameraDevice>& devices, CameraPreviews& previews, std::string& error);
    ~SessionRecording ();

    // A record of throws.jsonl from the server (api::Server::onLogged)
    void log (const nlohmann::json& record);
    const std::filesystem::path& directory () const { return writer_->directory(); }

   private:
    SessionRecording () = default;

    CameraPreviews* previews_ = nullptr;
    std::size_t cameras_ = 0;
    std::unique_ptr<session::SessionWriter> writer_;
    std::mutex mutex_;
    std::ofstream throws_jsonl_;
    std::ofstream throws_csv_;
};
}  // namespace dartpilot::cli
