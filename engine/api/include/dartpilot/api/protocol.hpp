#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <variant>
#include <vector>

#include <nlohmann/json.hpp>

#include "dartpilot/scoring/score.hpp"

// Messages of the engine API, protocol dartpilot/1.1 (docs/engine-api.md). Pure functions, no network.
namespace dartpilot::api
{
inline constexpr const char* kProtocol = "dartpilot/1.1";

struct BoardPoint
{
    double x_mm = 0.0;
    double y_mm = 0.0;
    // xx, xy, yy in mm²; absent for points set by hand
    std::optional<std::array<double, 3>> covariance_mm2;
};

struct CameraInfo
{
    std::string id;
    std::string name;
    std::string state = "ok";
};

// Whether darts or other objects are in the board (issue #121): empty, occupied or unknown
struct CameraBoardState
{
    std::string camera;
    std::string state = "unknown";
    // Where the object is in the camera's full image
    std::optional<std::array<double, 2>> image_point_px;
    std::string reason;
    // Size of the image the point refers to, so a client can place it in a scaled preview
    std::array<int, 2> image_size_px{0, 0};

    bool operator==(const CameraBoardState&) const = default;
};

struct BoardStateInfo
{
    std::string state = "unknown";
    std::vector<CameraBoardState> cameras;
    // Whether an image of the empty board is stored for every camera
    bool reference_stored = false;

    bool operator==(const BoardStateInfo&) const = default;
};

// Overall state from the cameras: occupied if any camera sees an object, empty if all see none, unknown otherwise
std::string combineBoardState (const std::vector<CameraBoardState>& cameras);

struct Hello
{
    std::string mode;  // live, replay, simulate
    // Stable per engine installation, as in discovery (#109)
    std::string engine_id;
    std::string session_id;
    scoring::BoardGeometry board_geometry;
    std::string board_geometry_source = "nominal";
    std::vector<CameraInfo> cameras;
    // running, paused or unavailable; for unavailable, detection_reason says why (not_calibrated, no_empty_reference)
    std::string detection = "running";
    std::string detection_reason;
    BoardStateInfo board_state;
    // What is calibrated per camera (calibration_status), for the calibration wizard; null without real cameras
    nlohmann::json calibration_status;
    // Per client (#110): local (on this computer, or the engine listens only there), paired, or required (only pair
    // is allowed until the client paired)
    std::string pairing = "local";
};

struct CameraContribution
{
    std::string camera;
    bool used = false;
    std::vector<std::uint32_t> frames;
    std::string reason;
};

struct Throw
{
    std::string throw_id;
    std::int64_t event_ns = 0;
    bool accepted = true;
    std::optional<BoardPoint> board_point;
    double confidence = 0.0;
    std::string reason;
    std::vector<CameraContribution> cameras;
    double processing_latency_ms = 0.0;
    // From the last motion the engine saw (the dart landed, the hand left) to sending; live only
    std::optional<double> detection_latency_ms;
    // The revision of the detection values it was made with (detection_params, params.jsonl); live only
    std::optional<int> params_revision;
};

struct CameraStatus
{
    std::string camera;
    std::string state = "ok";
    double effective_fps = 0.0;
    std::uint64_t lost_frames = 0;
    std::uint64_t overflow_drops = 0;
    double brightness = -1.0;
    // Arrival minus exposure of the latest frame; negative if unknown
    double latency_ms = -1.0;
};

nlohmann::json toJson (const BoardPoint& point);
nlohmann::json toJson (const scoring::Score& score);
nlohmann::json toJson (const scoring::BoardGeometry& geometry, const std::string& source);

nlohmann::json toJson (const BoardStateInfo& board);
nlohmann::json helloMessage (const Hello& hello);
nlohmann::json boardStateMessage (const BoardStateInfo& board);
// The score is derived from the board point with the geometry, as the engine's scorer does it, and so are the candidate
// fields of an uncertain dart with a covariance (#126).
nlohmann::json throwMessage (const Throw& dart, const scoring::BoardGeometry& geometry);
// action: corrected, rejected or added
nlohmann::json throwCorrectedMessage (const std::string& throw_id, const std::string& action, const std::optional<BoardPoint>& point,
                                      const scoring::BoardGeometry& geometry, const std::string& client);
// The records of a recorded session's results/<run>/throws.jsonl (docs/replay-format.md): a throw as the engine sent it,
// and a client's correction of it (action corrected, rejected or added) as a line of its own
nlohmann::json throwRecord (const Throw& dart, const scoring::BoardGeometry& geometry);
nlohmann::json correctionRecord (const std::string& throw_id, const std::string& action, const std::optional<BoardPoint>& point,
                                 const std::string& client, const std::string& reason, std::int64_t event_ns,
                                 std::optional<int> candidate = std::nullopt);
nlohmann::json takeoutMessage (std::int64_t event_ns, int darts_removed, std::optional<double> detection_latency_ms = std::nullopt);
nlohmann::json cameraStatusMessage (const CameraStatus& status);
nlohmann::json engineStatusMessage (const std::string& detection, const std::string& message);
// calibration_status with the status's fields
nlohmann::json calibrationStatusMessage (const nlohmann::json& status);
// The shared game (#116) and the client that shared it; a null game ends sharing
nlohmann::json sharedGameMessage (const std::string& client, const nlohmann::json& game);
nlohmann::json resultMessage (const std::string& request_id, bool ok, const std::string& error_code = {}, const std::string& error_message = {});

// Requests from clients
struct ClientHello
{
    std::string client;
};
// pair (#110): with the engine's PIN, or with the token of an earlier pairing
struct Pair
{
    std::string pin;
    std::string token;
};
// get_pairing_pin, list_paired_clients, unpair: only for clients on this computer
struct PairingAdmin
{
    std::string type;
    std::string id;
};
struct CorrectThrow
{
    std::string throw_id;
    BoardPoint board_point;
    // The index of the throw's candidate field the player picked (#126), a labelled example
    std::optional<int> candidate;
};
struct RejectThrow
{
    std::string throw_id;
    std::string reason;
};
struct AddThrow
{
    BoardPoint board_point;
};
struct SetDetection
{
    bool running = true;
};
struct CheckBoard
{
};
// Requests of the calibration wizard (detect_board, set_sector_20, refine_cameras, tune_white_balance) and for the
// calibrated board's image (get_board_image): passed on with their fields to the source behind Server::onCalibration
struct CalibrationRequest
{
    std::string type;
    nlohmann::json body;
};
// start_diagnosis and stop_diagnosis: the live setup diagnosis (#137)
struct SetDiagnosis
{
    bool running = true;
};
struct StoreEmptyReference
{
    // Store even while a camera sees an object, after the user confirmed that the board is empty
    bool force = false;
};
// share_game and end_shared_game (#116): the game the leading app shares with the other displays, opaque to the engine;
// null to end sharing
struct ShareGame
{
    nlohmann::json game;
};
struct Subscription
{
    std::string topic;  // status or preview
    bool subscribe = true;
    std::string camera;
    // Preview limits; 0 means the engine's default
    double max_fps = 0.0;
    int max_width = 0;
};
using RequestBody = std::variant<ClientHello, CorrectThrow, RejectThrow, AddThrow, SetDetection, Subscription, CheckBoard, StoreEmptyReference,
                                 SetDiagnosis, CalibrationRequest, ShareGame, Pair, PairingAdmin>;

struct Request
{
    std::string request_id;
    RequestBody body;
};

// A parsed request, or the error code and message to answer with (bad_request, unknown_type)
struct ParseError
{
    std::string request_id;
    std::string code;
    std::string message;
};
std::variant<Request, ParseError> parseRequest (const std::string& text);

// Header of a preview frame (docs/engine-api.md, "Previews")
struct PreviewHeader
{
    std::string camera;
    std::uint32_t sequence = 0;
    std::int64_t exposure_ns = 0;
    int width = 0;
    int height = 0;
};

// Binary preview message: header length as u32 little-endian, the header as JSON, then the JPEG
std::string previewMessage (const PreviewHeader& header, const std::vector<std::uint8_t>& jpeg);
}  // namespace dartpilot::api
