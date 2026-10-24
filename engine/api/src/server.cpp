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
                    lock.unlock();
                    socket.sendText(helloMessage(hello).dump());
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
    broadcast(throwMessage(recorded, hello_.board_geometry));
    return recorded;
}

void Server::publishTakeout (std::int64_t event_ns, int darts_removed) { broadcast(takeoutMessage(event_ns, darts_removed)); }

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
                    return resultMessage(request.request_id, false, "not_available", "Previews are not available yet");
                }
                std::lock_guard lock(mutex_);
                clients_[connection].status = subscription.subscribe;
                return resultMessage(request.request_id, true);
            },
        },
        request.body);
}
}  // namespace dartpilot::api
