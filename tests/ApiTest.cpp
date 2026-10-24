#include <gtest/gtest.h>

#include <chrono>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <random>
#include <thread>

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXWebSocket.h>
#include <nlohmann/json.hpp>

#include "dartpilot/api/protocol.hpp"
#include "dartpilot/api/server.hpp"
#include "dartpilot/api/simulator.hpp"
#include "dartpilot/api/throw_log.hpp"

using namespace dartpilot;
using nlohmann::json;

TEST(Protocol, ThrowCarriesBoardPointAndDerivedScore)
{
    api::Throw dart;
    dart.throw_id = "s/1";
    dart.board_point = api::BoardPoint{0.0, 103.0, std::array<double, 3>{0.6, 0.1, 0.9}};
    dart.confidence = 0.9;
    dart.cameras = {{"usb-1", true, {12, 13}, ""}, {"usb-2", false, {}, "tip occluded"}};
    const json message = api::throwMessage(dart, {});
    EXPECT_EQ(message["type"], "throw");
    EXPECT_EQ(message["score"]["label"], "T20");
    EXPECT_EQ(message["score"]["ring"], "triple");
    EXPECT_EQ(message["board_point"]["covariance_mm2"]["xy"], 0.1);
    EXPECT_EQ(message["cameras"][0]["frames"], json({12, 13}));
    EXPECT_EQ(message["cameras"][1]["reason"], "tip occluded");
}

TEST(Protocol, AbstentionWithoutPointAndInfiniteDistancesAsNull)
{
    api::Throw dart;
    dart.accepted = false;
    dart.reason = "no tip";
    const json message = api::throwMessage(dart, {});
    EXPECT_TRUE(message["board_point"].is_null());
    EXPECT_TRUE(message["score"].is_null());
    EXPECT_EQ(message["reason"], "no tip");

    const json bull = api::toJson(scoring::score(0.0, 0.0));
    EXPECT_TRUE(bull["sector_boundary_distance_mm"].is_null());
    EXPECT_EQ(bull["ring"], "inner_bull");
}

TEST(Protocol, HelloNamesProtocolAndGeometry)
{
    api::Hello hello;
    hello.mode = "simulate";
    hello.board_geometry.outer_bull_radius_mm = 15.4;
    hello.board_geometry_source = "measured";
    const json message = api::helloMessage(hello);
    EXPECT_EQ(message["protocol"], "dartpilot/1.0");
    EXPECT_EQ(message["board_geometry"]["outer_bull_radius_mm"], 15.4);
    EXPECT_EQ(message["board_geometry"]["source"], "measured");
    EXPECT_TRUE(message["session_id"].is_null());
}

TEST(Protocol, ParsesRequestsAndReportsErrors)
{
    const auto correct = api::parseRequest(R"({"type":"correct_throw","request_id":"7","throw_id":"s/3","board_point":{"x_mm":1,"y_mm":2}})");
    ASSERT_TRUE(std::holds_alternative<api::Request>(correct));
    const auto& request = std::get<api::Request>(correct);
    EXPECT_EQ(request.request_id, "7");
    EXPECT_EQ(std::get<api::CorrectThrow>(request.body).board_point.y_mm, 2.0);

    const auto unknown = api::parseRequest(R"({"type":"launch","request_id":"8"})");
    EXPECT_EQ(std::get<api::ParseError>(unknown).code, "unknown_type");
    EXPECT_EQ(std::get<api::ParseError>(unknown).request_id, "8");
    EXPECT_EQ(std::get<api::ParseError>(api::parseRequest("not json")).code, "bad_request");
    EXPECT_EQ(std::get<api::ParseError>(api::parseRequest(R"({"type":"correct_throw","request_id":"9"})")).code, "bad_request");
}

TEST(ThrowLog, NumbersThrowsAndKeepsCorrections)
{
    api::ThrowLog log("20261024T190000Z-7c1e");
    const auto first = log.record({});
    EXPECT_EQ(first.throw_id, "20261024T190000Z-7c1e/1");
    EXPECT_FALSE(log.correct(first.throw_id, {5.0, 6.0, std::nullopt}, "tablet"));
    EXPECT_EQ(log.find(first.throw_id)->correction, "corrected");
    EXPECT_EQ(log.find(first.throw_id)->client, "tablet");
    EXPECT_EQ(*log.reject("nope", "", ""), "unknown_throw");
    EXPECT_EQ(log.add({0, 0, std::nullopt}, 5, "tablet"), "20261024T190000Z-7c1e/2");
}

TEST(Simulator, TargetsHitTheirFieldsAndDartsAreReproducible)
{
    const char* expected[] = {"T20", "T19", "D16", "50", "S20"};
    for(int visit = 0; visit < 5; ++visit)
    {
        const auto target = api::Simulator::target(visit * 3);
        EXPECT_EQ(scoring::label(scoring::score(target[0], target[1])), expected[visit]);
    }
    const api::SimulatorSettings settings;
    const auto a = api::Simulator::makeDart(42, 7, settings);
    const auto b = api::Simulator::makeDart(42, 7, settings);
    EXPECT_EQ(a.board_point->x_mm, b.board_point->x_mm);
    EXPECT_EQ(a.accepted, b.accepted);
    int abstained = 0;
    for(int i = 0; i < 1000; ++i)
    {
        abstained += api::Simulator::makeDart(1, i, settings).accepted ? 0 : 1;
    }
    EXPECT_GT(abstained, 50);
    EXPECT_LT(abstained, 150);
}

namespace
{
// Minimal WebSocket client that queues the text messages it receives
class TestClient
{
   public:
    explicit TestClient (int port)
    {
        socket_.setUrl("ws://127.0.0.1:" + std::to_string(port) + "/");
        socket_.disableAutomaticReconnection();
        socket_.setOnMessageCallback(
            [this] (const ix::WebSocketMessagePtr& message)
            {
                if(message->type == ix::WebSocketMessageType::Message)
                {
                    std::lock_guard lock(mutex_);
                    messages_.push_back(json::parse(message->str));
                    ready_.notify_all();
                }
            });
        socket_.start();
    }
    ~TestClient () { socket_.stop(); }

    void send (const json& message) { socket_.sendText(message.dump()); }

    // Next message of the given type within two seconds
    json next (const std::string& type)
    {
        std::unique_lock lock(mutex_);
        const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
        while(true)
        {
            for(auto it = messages_.begin(); it != messages_.end(); ++it)
            {
                if((*it)["type"] == type)
                {
                    json found = *it;
                    messages_.erase(it);
                    return found;
                }
            }
            if(ready_.wait_until(lock, deadline) == std::cv_status::timeout)
            {
                return json();
            }
        }
    }

   private:
    ix::WebSocket socket_;
    std::mutex mutex_;
    std::condition_variable ready_;
    std::deque<json> messages_;
};
}  // namespace

TEST(Server, HelloThrowsAndCorrectionsOverWebSocket)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Hello hello;
    hello.mode = "simulate";
    api::Server server(port, "127.0.0.1", hello);
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    TestClient a(port);
    TestClient b(port);
    EXPECT_EQ(a.next("hello")["protocol"], "dartpilot/1.0");
    EXPECT_EQ(b.next("hello")["mode"], "simulate");

    api::Throw dart;
    dart.board_point = api::BoardPoint{0.0, 166.0, std::nullopt};
    const auto published = server.publishThrow(dart);
    EXPECT_EQ(a.next("throw")["score"]["label"], "D20");
    EXPECT_EQ(b.next("throw")["throw_id"], published.throw_id);

    a.send({{"type", "hello"}, {"request_id", "1"}, {"client", "tablet"}});
    EXPECT_TRUE(a.next("result")["ok"]);
    a.send({{"type", "correct_throw"}, {"request_id", "2"}, {"throw_id", published.throw_id}, {"board_point", {{"x_mm", 0.0}, {"y_mm", 103.0}}}});
    EXPECT_TRUE(a.next("result")["ok"]);
    const json corrected = b.next("throw_corrected");
    EXPECT_EQ(corrected["score"]["label"], "T20");
    EXPECT_EQ(corrected["client"], "tablet");
    EXPECT_EQ(server.throws().find(published.throw_id)->correction, "corrected");

    a.send({{"type", "reject_throw"}, {"request_id", "3"}, {"throw_id", "missing/9"}});
    const json rejected = a.next("result");
    EXPECT_FALSE(rejected["ok"]);
    EXPECT_EQ(rejected["error"]["code"], "unknown_throw");

    // Camera status: a changed state goes to everyone, the periodic one only to subscribers.
    server.publishCameraStatus({"cam", "lost", 0.0, 0, 0, -1.0});
    EXPECT_EQ(a.next("camera_status")["state"], "lost");
    EXPECT_EQ(b.next("camera_status")["state"], "lost");
    b.send({{"type", "subscribe_status"}, {"request_id", "4"}});
    EXPECT_TRUE(b.next("result")["ok"]);
    server.publishCameraStatus({"cam", "lost", 0.0, 0, 0, -1.0});
    EXPECT_FALSE(b.next("camera_status").is_null());
    EXPECT_TRUE(a.next("camera_status").is_null());
    server.stop();
}
