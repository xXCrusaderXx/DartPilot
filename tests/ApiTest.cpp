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
                    if(message->binary)
                    {
                        binary_.push_back(message->str);
                    }
                    else
                    {
                        messages_.push_back(json::parse(message->str));
                    }
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

    // Binary messages received so far, after waiting up to the timeout for at least `count`
    std::vector<std::string> binary (std::size_t count, std::chrono::milliseconds timeout = std::chrono::seconds(2))
    {
        std::unique_lock lock(mutex_);
        ready_.wait_for(lock, timeout, [&] { return binary_.size() >= count; });
        return binary_;
    }

   private:
    std::vector<std::string> binary_;
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

TEST(Protocol, PreviewMessageLayout)
{
    const std::vector<std::uint8_t> jpeg = {0xff, 0xd8, 0x01, 0x02};
    const std::string message = api::previewMessage({"usb-1", 7, 99, 640, 360}, jpeg);
    const std::uint32_t length = static_cast<std::uint8_t>(message[0]) | static_cast<std::uint8_t>(message[1]) << 8 |
                                 static_cast<std::uint8_t>(message[2]) << 16 |
                                 static_cast<std::uint32_t>(static_cast<std::uint8_t>(message[3])) << 24;
    const json header = json::parse(message.substr(4, length));
    EXPECT_EQ(header["camera"], "usb-1");
    EXPECT_EQ(header["sequence"], 7);
    EXPECT_EQ(header["width"], 640);
    EXPECT_EQ(message.substr(4 + length), std::string("\xff\xd8\x01\x02", 4));
}

TEST(Server, PreviewsGoOnlyToSubscribersWithinTheirRateAndWidth)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Hello hello;
    hello.mode = "simulate";
    api::Server server(port, "127.0.0.1", hello);
    server.setCameras({{"cam-a", "A", "ok"}});
    int scaled_to = 0;
    server.setPreviewScaler(
        [&] (const std::vector<std::uint8_t>&, int max_width, int& width, int& height)
        {
            scaled_to = max_width;
            width = max_width;
            height = max_width / 2;
            return std::vector<std::uint8_t>{0xff, 0xd8};
        });
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    TestClient watcher(port);
    TestClient other(port);
    ASSERT_FALSE(watcher.next("hello").is_null());
    ASSERT_FALSE(other.next("hello").is_null());
    EXPECT_FALSE(server.wantsPreview("cam-a"));

    watcher.send({{"type", "subscribe_preview"}, {"request_id", "1"}, {"camera", "nope"}});
    EXPECT_EQ(watcher.next("result")["error"]["code"], "unknown_camera");
    watcher.send({{"type", "subscribe_preview"}, {"request_id", "2"}, {"camera", "cam-a"}, {"max_fps", 2}, {"max_width", 320}});
    EXPECT_TRUE(watcher.next("result")["ok"]);
    EXPECT_TRUE(server.wantsPreview("cam-a"));

    const std::vector<std::uint8_t> jpeg(100, 0x42);
    for(int i = 0; i < 5; ++i)
    {
        server.publishPreview({"cam-a", static_cast<std::uint32_t>(i), i, 1280, 720}, jpeg);
    }
    const auto received = watcher.binary(1);
    // At most 2 fps: five frames within a few milliseconds give one.
    ASSERT_EQ(received.size(), 1u);
    EXPECT_EQ(scaled_to, 320);
    const std::uint32_t length = static_cast<std::uint8_t>(received[0][0]);
    EXPECT_EQ(json::parse(received[0].substr(4, length))["width"], 320);
    EXPECT_TRUE(other.binary(1, std::chrono::milliseconds(200)).empty());

    watcher.send({{"type", "unsubscribe_preview"}, {"request_id", "3"}, {"camera", "cam-a"}});
    EXPECT_TRUE(watcher.next("result")["ok"]);
    EXPECT_FALSE(server.wantsPreview("cam-a"));
    server.stop();
}

TEST(Protocol, BoardStateCombinesCamerasAndIsPartOfHello)
{
    api::CameraBoardState empty{"a", "empty", std::nullopt, ""};
    api::CameraBoardState occupied{"b", "occupied", std::array<double, 2>{640.0, 300.0}, "object", {1280, 720}};
    api::CameraBoardState unknown{"c", "unknown", std::nullopt, "no reference"};
    EXPECT_EQ(api::combineBoardState({empty, empty}), "empty");
    EXPECT_EQ(api::combineBoardState({empty, unknown, occupied}), "occupied");
    EXPECT_EQ(api::combineBoardState({empty, unknown}), "unknown");
    EXPECT_EQ(api::combineBoardState({}), "unknown");

    api::Hello hello;
    hello.board_state = {"occupied", {empty, occupied}, true};
    const json board = api::helloMessage(hello)["board_state"];
    EXPECT_EQ(board["state"], "occupied");
    EXPECT_EQ(board["reference"], "stored");
    EXPECT_TRUE(board["cameras"][0]["image_point_px"].is_null());
    EXPECT_EQ(board["cameras"][1]["image_point_px"], json({640.0, 300.0}));
    EXPECT_EQ(board["cameras"][1]["image_size_px"], json({1280, 720}));
    EXPECT_EQ(api::boardStateMessage(hello.board_state)["type"], "board_state");
    EXPECT_EQ(api::helloMessage(api::Hello{})["board_state"]["reference"], "missing");

    const auto check = api::parseRequest(R"({"type":"check_board","request_id":"1"})");
    EXPECT_TRUE(std::holds_alternative<api::CheckBoard>(std::get<api::Request>(check).body));
    const auto store = api::parseRequest(R"({"type":"store_empty_reference","request_id":"2"})");
    EXPECT_FALSE(std::get<api::StoreEmptyReference>(std::get<api::Request>(store).body).force);
    const auto forced = api::parseRequest(R"({"type":"store_empty_reference","request_id":"3","force":true})");
    EXPECT_TRUE(std::get<api::StoreEmptyReference>(std::get<api::Request>(forced).body).force);
}

TEST(Server, BoardStateGoesToEveryoneAndRequestsReachTheSource)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Server server(port, "127.0.0.1", api::Hello{});
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    TestClient client(port);
    EXPECT_EQ(client.next("hello")["board_state"]["state"], "unknown");
    client.send({{"type", "check_board"}, {"request_id", "1"}});
    EXPECT_EQ(client.next("result")["error"]["code"], "not_available");

    api::BoardStateInfo occupied{"occupied", {{"cam", "occupied", std::array<double, 2>{10.0, 20.0}, "object"}}, true};
    server.setBoardState(occupied);
    EXPECT_EQ(client.next("board_state")["cameras"][0]["image_point_px"], json({10.0, 20.0}));
    // An unchanged state is not sent again.
    server.setBoardState(occupied);
    EXPECT_TRUE(client.next("board_state").is_null());

    int checks = 0;
    server.onCheckBoard([&] { ++checks; });
    server.onStoreEmptyReference([&] (bool force) -> std::optional<std::string>
                                 { return force ? std::nullopt : std::optional<std::string>("board_not_empty"); });
    client.send({{"type", "check_board"}, {"request_id", "2"}});
    EXPECT_TRUE(client.next("result")["ok"]);
    EXPECT_EQ(checks, 1);
    client.send({{"type", "store_empty_reference"}, {"request_id", "3"}});
    EXPECT_EQ(client.next("result")["error"]["code"], "board_not_empty");
    client.send({{"type", "store_empty_reference"}, {"request_id", "4"}, {"force", true}});
    EXPECT_TRUE(client.next("result")["ok"]);

    TestClient late(port);
    EXPECT_EQ(late.next("hello")["board_state"]["state"], "occupied");
    server.stop();
}

TEST(Simulator, BoardStateMarksTheObjectWhenOccupied)
{
    const auto occupied = api::Simulator::boardState(true);
    EXPECT_EQ(occupied.state, "occupied");
    ASSERT_EQ(occupied.cameras.size(), 3u);
    EXPECT_TRUE(occupied.cameras[0].image_point_px.has_value());
    const auto empty = api::Simulator::boardState(false);
    EXPECT_EQ(empty.state, "empty");
    EXPECT_TRUE(empty.reference_stored);
    EXPECT_FALSE(empty.cameras[2].image_point_px.has_value());
}
