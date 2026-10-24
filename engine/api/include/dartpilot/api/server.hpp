#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>

#include <nlohmann/json.hpp>

#include "dartpilot/api/protocol.hpp"
#include "dartpilot/api/throw_log.hpp"

namespace ix
{
class WebSocket;
class WebSocketServer;
}  // namespace ix

namespace dartpilot::api
{
// WebSocket server of the engine API (docs/engine-api.md). Event sources publish through it; every client gets
// `hello` on connect and every event afterwards. Requests are answered with `result`.
class Server
{
   public:
    Server (int port, std::string host, Hello hello);
    ~Server ();
    Server (const Server&) = delete;
    Server& operator=(const Server&) = delete;

    bool start (std::string& error);
    void stop ();

    // Assigns the throw ID, sends the throw to every client and returns it with its ID
    Throw publishThrow (Throw dart);
    void publishTakeout (std::int64_t event_ns, int darts_removed);
    // Sent to clients that subscribed to status; a changed state goes to every client
    void publishCameraStatus (const CameraStatus& status);
    void publishEngineStatus (const std::string& detection, const std::string& message);

    // Called when a client pauses or resumes detection
    void onDetectionChanged (std::function<void(bool running)> handler);

    const ThrowLog& throws () const { return log_; }
    std::size_t clientCount () const;
    const Hello& hello () const { return hello_; }

   private:
    struct Client
    {
        // Valid from the open to the close callback of its connection; only used under mutex_
        ix::WebSocket* socket = nullptr;
        std::string name;
        bool status = false;
    };

    void broadcast (const nlohmann::json& message, bool status_only = false);
    nlohmann::json handle (const std::string& connection, const Request& request);

    Hello hello_;
    ThrowLog log_;
    std::unique_ptr<ix::WebSocketServer> server_;
    mutable std::mutex mutex_;
    std::map<std::string, Client> clients_;
    std::map<std::string, std::string> camera_states_;
    std::function<void(bool)> detection_handler_;
};
}  // namespace dartpilot::api
