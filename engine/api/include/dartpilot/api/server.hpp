#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

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

    // The cameras announced in hello; set before start()
    void setCameras (std::vector<CameraInfo> cameras);

    bool start (std::string& error);
    void stop ();

    // Assigns the throw ID, sends the throw to every client and returns it with its ID
    Throw publishThrow (Throw dart);
    void publishTakeout (std::int64_t event_ns, int darts_removed);
    // Sent to clients that subscribed to status; a changed state goes to every client
    void publishCameraStatus (const CameraStatus& status);
    void publishEngineStatus (const std::string& detection, const std::string& message);

    // Whether any client watches this camera, so sources can skip preview work otherwise
    bool wantsPreview (const std::string& camera) const;
    // Sends a camera frame to the clients watching it, within each client's frame rate and width
    void publishPreview (const PreviewHeader& header, const std::vector<std::uint8_t>& jpeg);
    // Makes a JPEG of at most max_width pixels and reports its size; the server itself does no image processing.
    using PreviewScaler = std::function<std::vector<std::uint8_t>(const std::vector<std::uint8_t>& jpeg, int max_width, int& width, int& height)>;
    void setPreviewScaler (PreviewScaler scaler);

    // Whether the board is empty (#121); sent to every client when it changes and part of hello
    void setBoardState (BoardStateInfo board);
    BoardStateInfo boardState () const;
    // check_board: re-check now; the source answers with setBoardState()
    void onCheckBoard (std::function<void()> handler);
    // store_empty_reference: returns an error code (e.g. board_not_empty) or nothing on success
    void onStoreEmptyReference (std::function<std::optional<std::string>(bool force)> handler);

    // Live setup diagnosis (#137): start_diagnosis and stop_diagnosis reach the handler; the source sends its state
    // with publishDiagnosis(), to every client and, the latest one, to clients that connect later.
    void onDiagnosis (std::function<void(bool running)> handler);
    void publishDiagnosis (const nlohmann::json& message);

    // Calibration wizard: requests go to the handler, which answers with an error or nothing (ok); its results come as
    // events through publishEvent(). The status is part of hello and sent to every client when it changes.
    struct CalibrationError
    {
        std::string code;
        std::string message;
    };
    void onCalibration (std::function<std::optional<CalibrationError>(const CalibrationRequest&)> handler);
    // A handler for one request type, ahead of the general one (e.g. start_reference_run)
    void onCalibrationRequest (const std::string& type, std::function<std::optional<CalibrationError>(const CalibrationRequest&)> handler);
    void setCalibrationStatus (const nlohmann::json& status);
    // Sends an event message to every client
    void publishEvent (const nlohmann::json& message);
    // Sends an event to every client and keeps the latest one of its type for clients that connect later, after hello:
    // the state of a run that a client may join in the middle (diagnosis, reference_run)
    void publishState (const nlohmann::json& message);

    // Board points of the darts since the last takeout, e.g. for a simulated camera image
    std::vector<BoardPoint> visitPoints () const;

    // Every throw and every correction as a record of a session's throws.jsonl, e.g. to write it into the recording
    void onLogged (std::function<void(const nlohmann::json& record)> handler);

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
        struct Preview
        {
            double max_fps = 10.0;
            int max_width = 0;
            std::int64_t last_sent_ns = 0;
        };
        std::map<std::string, Preview> previews;
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
    std::function<void(const nlohmann::json&)> logged_handler_;
    void logged (const nlohmann::json& record);
    PreviewScaler preview_scaler_;
    std::function<void()> check_board_handler_;
    std::function<std::optional<std::string>(bool)> store_reference_handler_;
    std::vector<BoardPoint> visit_points_;
    std::function<void(bool)> diagnosis_handler_;
    std::function<std::optional<CalibrationError>(const CalibrationRequest&)> calibration_handler_;
    std::map<std::string, std::function<std::optional<CalibrationError>(const CalibrationRequest&)>> calibration_handlers_;
    std::map<std::string, nlohmann::json> last_states_;
};
}  // namespace dartpilot::api
