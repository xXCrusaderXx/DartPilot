#include "dartpilot/api/protocol.hpp"

#include <cmath>

#include "dartpilot/version.hpp"

namespace dartpilot::api
{
namespace
{
using nlohmann::json;

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

// JSON has no infinity; distances without a boundary (no radial wire in the bulls) are null.
json distance (double mm) { return std::isfinite(mm) ? json(mm) : json(nullptr); }

BoardPoint parseBoardPoint (const json& value)
{
    BoardPoint point;
    point.x_mm = value.at("x_mm").get<double>();
    point.y_mm = value.at("y_mm").get<double>();
    if(const auto it = value.find("covariance_mm2"); it != value.end() && it->is_object())
    {
        point.covariance_mm2 = std::array<double, 3>{it->at("xx").get<double>(), it->at("xy").get<double>(), it->at("yy").get<double>()};
    }
    return point;
}
}  // namespace

json toJson (const BoardPoint& point)
{
    json out = {{"x_mm", point.x_mm}, {"y_mm", point.y_mm}, {"covariance_mm2", nullptr}};
    if(point.covariance_mm2)
    {
        out["covariance_mm2"] = {{"xx", (*point.covariance_mm2)[0]}, {"xy", (*point.covariance_mm2)[1]}, {"yy", (*point.covariance_mm2)[2]}};
    }
    return out;
}

json toJson (const scoring::Score& score)
{
    return {{"ring", ringName(score.ring)},
            {"sector", score.sector},
            {"multiplier", score.multiplier},
            {"points", score.points},
            {"label", scoring::label(score)},
            {"boundary_distance_mm", distance(score.boundary_distance_mm)},
            {"ring_boundary_distance_mm", distance(score.ring_boundary_distance_mm)},
            {"sector_boundary_distance_mm", distance(score.sector_boundary_distance_mm)}};
}

json toJson (const scoring::BoardGeometry& geometry, const std::string& source)
{
    return {{"bull_radius_mm", geometry.bull_radius_mm},
            {"outer_bull_radius_mm", geometry.outer_bull_radius_mm},
            {"triple_inner_radius_mm", geometry.triple_inner_radius_mm},
            {"triple_outer_radius_mm", geometry.triple_outer_radius_mm},
            {"double_inner_radius_mm", geometry.double_inner_radius_mm},
            {"double_outer_radius_mm", geometry.double_outer_radius_mm},
            {"wire_rotation_deg", geometry.wire_rotation_deg},
            {"source", source}};
}

std::string combineBoardState (const std::vector<CameraBoardState>& cameras)
{
    if(cameras.empty())
    {
        return "unknown";
    }
    bool all_empty = true;
    for(const auto& camera : cameras)
    {
        if(camera.state == "occupied")
        {
            return "occupied";
        }
        all_empty = all_empty && camera.state == "empty";
    }
    return all_empty ? "empty" : "unknown";
}

json toJson (const BoardStateInfo& board)
{
    json cameras = json::array();
    for(const auto& camera : board.cameras)
    {
        json entry = {{"camera", camera.camera},
                      {"state", camera.state},
                      {"image_point_px", nullptr},
                      {"reason", camera.reason},
                      {"image_size_px", {camera.image_size_px[0], camera.image_size_px[1]}}};
        if(camera.image_point_px)
        {
            entry["image_point_px"] = {(*camera.image_point_px)[0], (*camera.image_point_px)[1]};
        }
        cameras.push_back(entry);
    }
    return {{"state", board.state}, {"cameras", cameras}, {"reference", board.reference_stored ? "stored" : "missing"}};
}

json boardStateMessage (const BoardStateInfo& board)
{
    json out = toJson(board);
    out["type"] = "board_state";
    return out;
}

json helloMessage (const Hello& hello)
{
    json cameras = json::array();
    for(const auto& camera : hello.cameras)
    {
        cameras.push_back({{"id", camera.id}, {"name", camera.name}, {"state", camera.state}});
    }
    return {{"type", "hello"},
            {"protocol", kProtocol},
            {"engine", {{"version", std::string(kVersion)}, {"commit", std::string(kGitCommit)}, {"id", hello.engine_id}}},
            {"mode", hello.mode},
            {"session_id", hello.session_id.empty() ? json(nullptr) : json(hello.session_id)},
            {"board_geometry", toJson(hello.board_geometry, hello.board_geometry_source)},
            {"cameras", cameras},
            {"detection", hello.detection},
            {"detection_reason", hello.detection_reason.empty() ? json(nullptr) : json(hello.detection_reason)},
            {"board_state", toJson(hello.board_state)},
            {"calibration_status", hello.calibration_status},
            {"pairing", hello.pairing},
            {"pairing_pin_digits", 6}};
}

json sharedGameMessage (const std::string& client, const json& game) { return {{"type", "shared_game"}, {"client", client}, {"game", game}}; }

json calibrationStatusMessage (const json& status)
{
    json message = status;
    message["type"] = "calibration_status";
    return message;
}

json throwMessage (const Throw& dart, const scoring::BoardGeometry& geometry)
{
    json cameras = json::array();
    for(const auto& camera : dart.cameras)
    {
        json entry = {{"camera", camera.camera}, {"used", camera.used}, {"frames", camera.frames}};
        if(!camera.reason.empty())
        {
            entry["reason"] = camera.reason;
        }
        cameras.push_back(entry);
    }
    json out = {{"type", "throw"},
                {"throw_id", dart.throw_id},
                {"event_ns", dart.event_ns},
                {"accepted", dart.accepted},
                {"board_point", nullptr},
                {"score", nullptr},
                {"confidence", dart.confidence},
                {"cameras", cameras},
                {"processing_latency_ms", dart.processing_latency_ms}};
    if(dart.detection_latency_ms)
    {
        out["detection_latency_ms"] = *dart.detection_latency_ms;
    }
    if(dart.params_revision)
    {
        out["params_revision"] = *dart.params_revision;
    }
    if(dart.board_point)
    {
        out["board_point"] = toJson(*dart.board_point);
        out["score"] = toJson(scoring::score(dart.board_point->x_mm, dart.board_point->y_mm, geometry));
    }
    if(!dart.reason.empty())
    {
        out["reason"] = dart.reason;
    }
    return out;
}

json throwRecord (const Throw& dart, const scoring::BoardGeometry& geometry)
{
    json cameras = json::array();
    for(const auto& camera : dart.cameras)
    {
        json measurement = {{"camera", camera.camera}, {"frames", {{"after", camera.frames}}}, {"used", camera.used}};
        if(!camera.reason.empty())
        {
            measurement["reason"] = camera.reason;
        }
        cameras.push_back(measurement);
    }
    json out = {{"throw_id", dart.throw_id},
                {"accepted", dart.accepted},
                {"board_point", nullptr},
                {"score", nullptr},
                {"confidence", dart.confidence},
                {"camera_measurements", cameras},
                {"diagnostics", {{"event_ns", dart.event_ns}}},
                {"processing_latency_ms", dart.processing_latency_ms}};
    if(dart.detection_latency_ms)
    {
        out["diagnostics"]["detection_latency_ms"] = *dart.detection_latency_ms;
    }
    if(dart.params_revision)
    {
        out["diagnostics"]["params_revision"] = *dart.params_revision;
    }
    if(dart.board_point)
    {
        out["board_point"] = toJson(*dart.board_point);
        out["score"] = toJson(scoring::score(dart.board_point->x_mm, dart.board_point->y_mm, geometry));
    }
    if(!dart.reason.empty())
    {
        out["diagnostics"]["reason"] = dart.reason;
    }
    return out;
}

json correctionRecord (const std::string& throw_id, const std::string& action, const std::optional<BoardPoint>& point, const std::string& client,
                       const std::string& reason, std::int64_t event_ns)
{
    json correction = {{"action", action}, {"board_point", point ? toJson(*point) : json(nullptr)}, {"client", client}};
    if(!reason.empty())
    {
        correction["reason"] = reason;
    }
    if(action == "added")
    {
        correction["event_ns"] = event_ns;
    }
    return {{"throw_id", throw_id}, {"correction", correction}};
}

json throwCorrectedMessage (const std::string& throw_id, const std::string& action, const std::optional<BoardPoint>& point,
                            const scoring::BoardGeometry& geometry, const std::string& client)
{
    json out = {{"type", "throw_corrected"}, {"throw_id", throw_id}, {"action", action},
                {"board_point", nullptr},    {"score", nullptr},     {"client", client}};
    if(point)
    {
        out["board_point"] = toJson(*point);
        out["score"] = toJson(scoring::score(point->x_mm, point->y_mm, geometry));
    }
    return out;
}

json takeoutMessage (std::int64_t event_ns, int darts_removed, std::optional<double> detection_latency_ms)
{
    json out = {{"type", "takeout"}, {"event_ns", event_ns}, {"darts_removed", darts_removed}};
    if(detection_latency_ms)
    {
        out["detection_latency_ms"] = *detection_latency_ms;
    }
    return out;
}

json cameraStatusMessage (const CameraStatus& status)
{
    return {{"type", "camera_status"},
            {"camera", status.camera},
            {"state", status.state},
            {"effective_fps", status.effective_fps},
            {"lost_frames", status.lost_frames},
            {"overflow_drops", status.overflow_drops},
            {"brightness", status.brightness >= 0 ? json(status.brightness) : json(nullptr)},
            {"latency_ms", status.latency_ms >= 0 ? json(status.latency_ms) : json(nullptr)}};
}

json engineStatusMessage (const std::string& detection, const std::string& message)
{
    return {{"type", "engine_status"}, {"detection", detection}, {"message", message}};
}

json resultMessage (const std::string& request_id, bool ok, const std::string& error_code, const std::string& error_message)
{
    json out = {{"type", "result"}, {"request_id", request_id}, {"ok", ok}};
    if(!ok)
    {
        out["error"] = {{"code", error_code}, {"message", error_message}};
    }
    return out;
}

std::string previewMessage (const PreviewHeader& header, const std::vector<std::uint8_t>& jpeg)
{
    const std::string json_header = json{
        {"camera", header.camera},
        {"sequence", header.sequence},
        {"exposure_ns", header.exposure_ns},
        {"width", header.width},
        {"height", header.height}}.dump();
    std::string message;
    message.reserve(4 + json_header.size() + jpeg.size());
    const auto length = static_cast<std::uint32_t>(json_header.size());
    for(int i = 0; i < 4; ++i)
    {
        message.push_back(static_cast<char>((length >> (8 * i)) & 0xff));
    }
    message += json_header;
    message.append(reinterpret_cast<const char*>(jpeg.data()), jpeg.size());
    return message;
}

std::variant<Request, ParseError> parseRequest (const std::string& text)
{
    json message;
    try
    {
        message = json::parse(text);
    }
    catch(const json::parse_error& error)
    {
        return ParseError{"", "bad_request", std::string("Not JSON: ") + error.what()};
    }
    if(!message.is_object())
    {
        return ParseError{"", "bad_request", "A request is a JSON object"};
    }
    std::string request_id;
    if(const auto it = message.find("request_id"); it != message.end())
    {
        request_id = it->is_string() ? it->get<std::string>() : it->dump();
    }
    try
    {
        const std::string type = message.at("type").get<std::string>();
        Request request{request_id, ClientHello{}};
        if(type == "hello")
        {
            request.body = ClientHello{message.value("client", std::string())};
        }
        else if(type == "pair")
        {
            request.body = Pair{message.value("pin", std::string()), message.value("token", std::string())};
        }
        else if(type == "get_pairing_pin" || type == "list_paired_clients" || type == "unpair")
        {
            request.body = PairingAdmin{type, message.value("id", std::string())};
        }
        else if(type == "correct_throw")
        {
            request.body = CorrectThrow{message.at("throw_id").get<std::string>(), parseBoardPoint(message.at("board_point"))};
        }
        else if(type == "reject_throw")
        {
            request.body = RejectThrow{message.at("throw_id").get<std::string>(), message.value("reason", std::string())};
        }
        else if(type == "add_throw")
        {
            request.body = AddThrow{parseBoardPoint(message.at("board_point"))};
        }
        else if(type == "pause_detection" || type == "resume_detection")
        {
            request.body = SetDetection{type == "resume_detection"};
        }
        else if(type == "check_board")
        {
            request.body = CheckBoard{};
        }
        else if(type == "detect_board" || type == "set_sector_20" || type == "refine_cameras" || type == "tune_white_balance" ||
                type == "subscribe_calibration_check" || type == "unsubscribe_calibration_check" || type == "get_board_image" ||
                type == "start_reference_run" || type == "stop_reference_run" || type == "get_detection_params" || type == "set_detection_params" ||
                type == "list_dart_sets" || type == "start_dart_set" || type == "cancel_dart_set" || type == "get_dart_set_image" ||
                type == "rename_dart_set" || type == "delete_dart_set" || type == "set_active_darts")
        {
            request.body = CalibrationRequest{type, message};
        }
        else if(type == "start_diagnosis" || type == "stop_diagnosis")
        {
            request.body = SetDiagnosis{type == "start_diagnosis"};
        }
        else if(type == "store_empty_reference")
        {
            request.body = StoreEmptyReference{message.value("force", false)};
        }
        else if(type == "share_game")
        {
            const auto& game = message.at("game");
            if(!game.is_object())
            {
                return ParseError{request_id, "bad_request", "share_game needs the game as an object"};
            }
            request.body = ShareGame{game};
        }
        else if(type == "end_shared_game")
        {
            request.body = ShareGame{nullptr};
        }
        else if(type == "subscribe_status" || type == "unsubscribe_status")
        {
            request.body = Subscription{"status", type == "subscribe_status", ""};
        }
        else if(type == "subscribe_preview" || type == "unsubscribe_preview")
        {
            request.body = Subscription{"preview", type == "subscribe_preview", message.at("camera").get<std::string>(),
                                        message.value("max_fps", 0.0), message.value("max_width", 0)};
        }
        else
        {
            return ParseError{request_id, "unknown_type", "Unknown request type " + type};
        }
        return request;
    }
    catch(const json::exception& error)
    {
        return ParseError{request_id, "bad_request", error.what()};
    }
}
}  // namespace dartpilot::api
