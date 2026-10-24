#include "dartpilot/api/server.hpp"

#include <chrono>
#include <ctime>

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXWebSocketServer.h>

namespace dartpilot::api
{
namespace
{
std::int64_t monotonicNowNs ()
{
    timespec now{};
    ::clock_gettime(CLOCK_MONOTONIC, &now);
    return static_cast<std::int64_t>(now.tv_sec) * 1'000'000'000 + now.tv_nsec;
}

template <typename... Ts>
struct Overloaded : Ts...
{
    using Ts::operator()...;
};
}  // namespace

Server::Server (int port, std::string host, Hello hello)
    : hello_(std::move(hello))
    , log_(hello_.session_id.empty() ? "live" : hello_.session_id)
{
    ix::initNetSystem();
    server_ = std::make_unique<ix::WebSocketServer>(port, host);
    server_->disablePerMessageDeflate();
    server_->setOnClientMessageCallback(
        [this] (std::shared_ptr<ix::ConnectionState> state, ix::WebSocket& socket, const ix::WebSocketMessagePtr& message)
        {
            const std::string connection = state->getId();
            switch(message->type)
            {
                case ix::WebSocketMessageType::Open:
                {
                    // hello first, then the client is registered for events, so it never sees an event before hello.
                    std::unique_lock lock(mutex_);
                    const Hello hello = hello_;
                    const nlohmann::json diagnosis = last_diagnosis_;
                    lock.unlock();
                    socket.sendText(helloMessage(hello).dump());
                    if(!diagnosis.is_null())
                    {
                        socket.sendText(diagnosis.dump());
                    }
                    lock.lock();
                    clients_[connection] = Client{&socket, {}, false};
                    break;
                }
                case ix::WebSocketMessageType::Close:
                {
                    std::lock_guard lock(mutex_);
                    clients_.erase(connection);
                    break;
                }
                case ix::WebSocketMessageType::Message:
                {
                    if(message->binary)
                    {
                        socket.sendText(resultMessage("", false, "bad_request", "Binary messages are only sent by the engine").dump());
                        break;
                    }
                    const auto parsed = parseRequest(message->str);
                    if(const auto* error = std::get_if<ParseError>(&parsed))
                    {
                        socket.sendText(resultMessage(error->request_id, false, error->code, error->message).dump());
                        break;
                    }
                    socket.sendText(handle(connection, std::get<Request>(parsed)).dump());
                    break;
                }
                default:
                    break;
            }
        });
}

Server::~Server () { stop(); }

void Server::setCameras (std::vector<CameraInfo> cameras)
{
    std::lock_guard lock(mutex_);
    hello_.cameras = std::move(cameras);
}

bool Server::start (std::string& error)
{
    if(!server_->listenAndStart())
    {
        error = "Cannot listen on the engine API port";
        return false;
    }
    return true;
}

void Server::stop ()
{
    if(server_)
    {
        server_->stop();
    }
}

void Server::broadcast (const nlohmann::json& message, bool status_only)
{
    const std::string text = message.dump();
    // Sent under the lock, so a connection cannot close and free its socket in between.
    std::lock_guard lock(mutex_);
    for(const auto& [id, client] : clients_)
    {
        if(client.socket && (!status_only || client.status))
        {
            client.socket->sendText(text);
        }
    }
}

Throw Server::publishThrow (Throw dart)
{
    Throw recorded = log_.record(std::move(dart));
    if(recorded.board_point)
    {
        std::lock_guard lock(mutex_);
        visit_points_.push_back(*recorded.board_point);
    }
    broadcast(throwMessage(recorded, hello_.board_geometry));
    return recorded;
}

void Server::publishTakeout (std::int64_t event_ns, int darts_removed)
{
    {
        std::lock_guard lock(mutex_);
        visit_points_.clear();
    }
    broadcast(takeoutMessage(event_ns, darts_removed));
}

void Server::setBoardState (BoardStateInfo board)
{
    {
        std::lock_guard lock(mutex_);
        if(hello_.board_state == board)
        {
            return;
        }
        hello_.board_state = board;
    }
    broadcast(boardStateMessage(board));
}

BoardStateInfo Server::boardState () const
{
    std::lock_guard lock(mutex_);
    return hello_.board_state;
}

void Server::onCheckBoard (std::function<void()> handler)
{
    std::lock_guard lock(mutex_);
    check_board_handler_ = std::move(handler);
}

void Server::onStoreEmptyReference (std::function<std::optional<std::string>(bool)> handler)
{
    std::lock_guard lock(mutex_);
    store_reference_handler_ = std::move(handler);
}

void Server::onDiagnosis (std::function<void(bool)> handler)
{
    std::lock_guard lock(mutex_);
    diagnosis_handler_ = std::move(handler);
}

void Server::onCalibration (std::function<std::optional<CalibrationError>(const CalibrationRequest&)> handler)
{
    std::lock_guard lock(mutex_);
    calibration_handler_ = std::move(handler);
}

void Server::setCalibrationStatus (const nlohmann::json& status)
{
    {
        std::lock_guard lock(mutex_);
        if(hello_.calibration_status == status)
        {
            return;
        }
        hello_.calibration_status = status;
    }
    broadcast(calibrationStatusMessage(status));
}

void Server::publishEvent (const nlohmann::json& message) { broadcast(message); }

void Server::publishDiagnosis (const nlohmann::json& message)
{
    {
        std::lock_guard lock(mutex_);
        last_diagnosis_ = message;
    }
    broadcast(message);
}

std::vector<BoardPoint> Server::visitPoints () const
{
    std::lock_guard lock(mutex_);
    return visit_points_;
}

bool Server::wantsPreview (const std::string& camera) const
{
    std::lock_guard lock(mutex_);
    for(const auto& [id, client] : clients_)
    {
        if(client.previews.count(camera) != 0)
        {
            return true;
        }
    }
    return false;
}

void Server::setPreviewScaler (PreviewScaler scaler)
{
    std::lock_guard lock(mutex_);
    preview_scaler_ = std::move(scaler);
}

void Server::publishPreview (const PreviewHeader& header, const std::vector<std::uint8_t>& jpeg)
{
    const std::int64_t now_ns = monotonicNowNs();
    // Which clients are due for a frame, and at which width; scaling happens outside the lock.
    std::map<int, std::vector<std::string>> due_by_width;
    PreviewScaler scaler;
    {
        std::lock_guard lock(mutex_);
        scaler = preview_scaler_;
        for(auto& [id, client] : clients_)
        {
            const auto it = client.previews.find(header.camera);
            if(it == client.previews.end())
            {
                continue;
            }
            const auto interval_ns = static_cast<std::int64_t>(1e9 / it->second.max_fps);
            // A slow client simply gets fewer frames; nothing is queued for it.
            if(now_ns - it->second.last_sent_ns < interval_ns)
            {
                continue;
            }
            const int width = it->second.max_width > 0 && it->second.max_width < header.width && scaler ? it->second.max_width : 0;
            due_by_width[width].push_back(id);
        }
    }
    for(const auto& [width, ids] : due_by_width)
    {
        PreviewHeader sized = header;
        std::vector<std::uint8_t> scaled;
        if(width > 0)
        {
            scaled = scaler(jpeg, width, sized.width, sized.height);
            if(scaled.empty())
            {
                continue;
            }
        }
        const std::string message = previewMessage(sized, width > 0 ? scaled : jpeg);
        std::lock_guard lock(mutex_);
        for(const auto& id : ids)
        {
            const auto client = clients_.find(id);
            if(client == clients_.end() || !client->second.socket || client->second.previews.count(header.camera) == 0)
            {
                continue;
            }
            client->second.previews[header.camera].last_sent_ns = now_ns;
            client->second.socket->sendBinary(message);
        }
    }
}

void Server::publishCameraStatus (const CameraStatus& status)
{
    bool changed = false;
    {
        std::lock_guard lock(mutex_);
        auto& state = camera_states_[status.camera];
        changed = state != status.state;
        state = status.state;
    }
    broadcast(cameraStatusMessage(status), !changed);
}

void Server::publishEngineStatus (const std::string& detection, const std::string& message)
{
    {
        std::lock_guard lock(mutex_);
        hello_.detection = detection;
        hello_.detection_reason = detection == "unavailable" ? message : std::string();
    }
    broadcast(engineStatusMessage(detection, message));
}

void Server::onDetectionChanged (std::function<void(bool)> handler)
{
    std::lock_guard lock(mutex_);
    detection_handler_ = std::move(handler);
}

std::size_t Server::clientCount () const
{
    std::lock_guard lock(mutex_);
    return clients_.size();
}

nlohmann::json Server::handle (const std::string& connection, const Request& request)
{
    std::string client;
    {
        std::lock_guard lock(mutex_);
        client = clients_[connection].name;
    }
    return std::visit(
        Overloaded{
            [&] (const ClientHello& hello)
            {
                std::lock_guard lock(mutex_);
                clients_[connection].name = hello.client;
                return resultMessage(request.request_id, true);
            },
            [&] (const CorrectThrow& correction)
            {
                if(const auto error = log_.correct(correction.throw_id, correction.board_point, client))
                {
                    return resultMessage(request.request_id, false, *error, "No throw " + correction.throw_id);
                }
                broadcast(throwCorrectedMessage(correction.throw_id, "corrected", correction.board_point, hello_.board_geometry, client));
                return resultMessage(request.request_id, true);
            },
            [&] (const RejectThrow& rejection)
            {
                if(const auto error = log_.reject(rejection.throw_id, rejection.reason, client))
                {
                    return resultMessage(request.request_id, false, *error, "No throw " + rejection.throw_id);
                }
                broadcast(throwCorrectedMessage(rejection.throw_id, "rejected", std::nullopt, hello_.board_geometry, client));
                return resultMessage(request.request_id, true);
            },
            [&] (const AddThrow& addition)
            {
                const std::string id = log_.add(addition.board_point, monotonicNowNs(), client);
                broadcast(throwCorrectedMessage(id, "added", addition.board_point, hello_.board_geometry, client));
                auto result = resultMessage(request.request_id, true);
                result["throw_id"] = id;
                return result;
            },
            [&] (const SetDetection& detection)
            {
                std::function<void(bool)> handler;
                {
                    std::lock_guard lock(mutex_);
                    handler = detection_handler_;
                }
                if(!handler)
                {
                    return resultMessage(request.request_id, false, "not_available", "Detection cannot be paused in this mode");
                }
                handler(detection.running);
                publishEngineStatus(detection.running ? "running" : "paused", client.empty() ? "" : "by " + client);
                return resultMessage(request.request_id, true);
            },
            [&] (const Subscription& subscription)
            {
                if(subscription.topic == "preview")
                {
                    std::lock_guard lock(mutex_);
                    bool known = false;
                    for(const auto& camera : hello_.cameras)
                    {
                        known = known || camera.id == subscription.camera;
                    }
                    if(!known)
                    {
                        return resultMessage(request.request_id, false, "unknown_camera", "No camera " + subscription.camera);
                    }
                    auto& previews = clients_[connection].previews;
                    if(subscription.subscribe)
                    {
                        Client::Preview preview;
                        preview.max_fps = subscription.max_fps > 0 ? subscription.max_fps : 10.0;
                        preview.max_width = subscription.max_width;
                        previews[subscription.camera] = preview;
                    }
                    else
                    {
                        previews.erase(subscription.camera);
                    }
                    return resultMessage(request.request_id, true);
                }
                std::lock_guard lock(mutex_);
                clients_[connection].status = subscription.subscribe;
                return resultMessage(request.request_id, true);
            },
            [&] (const CheckBoard&)
            {
                std::function<void()> handler;
                {
                    std::lock_guard lock(mutex_);
                    handler = check_board_handler_;
                }
                if(!handler)
                {
                    return resultMessage(request.request_id, false, "not_available", "No board check in this mode");
                }
                handler();
                return resultMessage(request.request_id, true);
            },
            [&] (const CalibrationRequest& calibration)
            {
                std::function<std::optional<CalibrationError>(const CalibrationRequest&)> handler;
                {
                    std::lock_guard lock(mutex_);
                    handler = calibration_handler_;
                }
                if(!handler)
                {
                    return resultMessage(request.request_id, false, "not_available", "No calibration in this mode");
                }
                if(const auto error = handler(calibration))
                {
                    return resultMessage(request.request_id, false, error->code, error->message);
                }
                return resultMessage(request.request_id, true);
            },
            [&] (const SetDiagnosis& diagnosis)
            {
                std::function<void(bool)> handler;
                {
                    std::lock_guard lock(mutex_);
                    handler = diagnosis_handler_;
                }
                if(!handler)
                {
                    return resultMessage(request.request_id, false, "not_available", "No setup diagnosis in this mode");
                }
                handler(diagnosis.running);
                return resultMessage(request.request_id, true);
            },
            [&] (const StoreEmptyReference& store)
            {
                std::function<std::optional<std::string>(bool)> handler;
                {
                    std::lock_guard lock(mutex_);
                    handler = store_reference_handler_;
                }
                if(!handler)
                {
                    return resultMessage(request.request_id, false, "not_available", "No board check in this mode");
                }
                if(const auto error = handler(store.force))
                {
                    return resultMessage(request.request_id, false, *error,
                                         *error == "board_not_empty" ? "Remove the darts first" : "Cannot store the empty board");
                }
                return resultMessage(request.request_id, true);
            },
        },
        request.body);
}
}  // namespace dartpilot::api
