#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <variant>
#include <vector>

#include <nlohmann/json.hpp>

#include "dartpilot/scoring/score.hpp"

// Messages of the engine API, protocol dartpilot/1.0 (docs/engine-api.md). Pure functions, no network.
namespace dartpilot::api
{
inline constexpr const char* kProtocol = "dartpilot/1.0";

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

struct Hello
{
    std::string mode;  // live, replay, simulate
    std::string session_id;
    scoring::BoardGeometry board_geometry;
    std::string board_geometry_source = "nominal";
    std::vector<CameraInfo> cameras;
    std::string detection = "running";
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
};

struct CameraStatus
{
    std::string camera;
    std::string state = "ok";
    double effective_fps = 0.0;
    std::uint64_t lost_frames = 0;
    std::uint64_t overflow_drops = 0;
    double brightness = -1.0;
};

nlohmann::json toJson (const BoardPoint& point);
nlohmann::json toJson (const scoring::Score& score);
nlohmann::json toJson (const scoring::BoardGeometry& geometry, const std::string& source);

nlohmann::json helloMessage (const Hello& hello);
// The score is derived from the board point with the geometry, as the engine's scorer does it.
nlohmann::json throwMessage (const Throw& dart, const scoring::BoardGeometry& geometry);
// action: corrected, rejected or added
nlohmann::json throwCorrectedMessage (const std::string& throw_id, const std::string& action, const std::optional<BoardPoint>& point,
                                      const scoring::BoardGeometry& geometry, const std::string& client);
nlohmann::json takeoutMessage (std::int64_t event_ns, int darts_removed);
nlohmann::json cameraStatusMessage (const CameraStatus& status);
nlohmann::json engineStatusMessage (const std::string& detection, const std::string& message);
nlohmann::json resultMessage (const std::string& request_id, bool ok, const std::string& error_code = {}, const std::string& error_message = {});

// Requests from clients
struct ClientHello
{
    std::string client;
};
struct CorrectThrow
{
    std::string throw_id;
    BoardPoint board_point;
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
struct Subscription
{
    std::string topic;  // status or preview
    bool subscribe = true;
    std::string camera;
};
using RequestBody = std::variant<ClientHello, CorrectThrow, RejectThrow, AddThrow, SetDetection, Subscription>;

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
}  // namespace dartpilot::api
