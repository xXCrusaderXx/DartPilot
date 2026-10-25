#include <gtest/gtest.h>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <condition_variable>
#include <ctime>
#include <deque>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <optional>
#include <random>
#include <thread>

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXWebSocket.h>
#include <nlohmann/json.hpp>

#include "dartpilot/api/discovery.hpp"
#include "dartpilot/api/pairing.hpp"
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
    EXPECT_EQ(message["protocol"], "dartpilot/1.1");
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
    EXPECT_EQ(a.next("hello")["protocol"], "dartpilot/1.1");
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

TEST(Server, DiagnosisRequestsReachTheSourceAndItsStateReachesEveryClient)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Server server(port, "127.0.0.1", api::Hello{});
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    const auto parsed = api::parseRequest(R"({"type":"stop_diagnosis","request_id":"1"})");
    EXPECT_FALSE(std::get<api::SetDiagnosis>(std::get<api::Request>(parsed).body).running);

    TestClient client(port);
    client.next("hello");
    client.send({{"type", "start_diagnosis"}, {"request_id", "1"}});
    EXPECT_EQ(client.next("result")["error"]["code"], "not_available");

    std::vector<bool> requests;
    server.onDiagnosis([&] (bool running) { requests.push_back(running); });
    client.send({{"type", "start_diagnosis"}, {"request_id", "2"}});
    EXPECT_TRUE(client.next("result")["ok"]);
    client.send({{"type", "stop_diagnosis"}, {"request_id", "3"}});
    EXPECT_TRUE(client.next("result")["ok"]);
    EXPECT_EQ(requests, (std::vector<bool>{true, false}));

    server.publishDiagnosis(api::Simulator::exampleDiagnosis(true));
    const auto diagnosis = client.next("diagnosis");
    EXPECT_TRUE(diagnosis["running"]);
    EXPECT_EQ(diagnosis["step"], "insert_dart");
    ASSERT_FALSE(diagnosis["findings"].empty());
    for(const auto& finding : diagnosis["findings"])
    {
        EXPECT_FALSE(finding["code"].get<std::string>().empty());
        EXPECT_TRUE(finding["values"].is_object());
    }
    // A client that connects later gets the latest state after hello.
    TestClient late(port);
    late.next("hello");
    EXPECT_EQ(late.next("diagnosis")["step"], "insert_dart");
    server.stop();
}

TEST(Server, CalibrationRequestsReachTheSourceAndTheStatusIsPartOfHello)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Server server(port, "127.0.0.1", api::Hello{});
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    const auto parsed = api::parseRequest(R"({"type":"set_sector_20","request_id":"1","camera":"sim-1","point_px":[320,100]})");
    const auto& request = std::get<api::CalibrationRequest>(std::get<api::Request>(parsed).body);
    EXPECT_EQ(request.type, "set_sector_20");
    EXPECT_EQ(request.body["point_px"][0], 320);

    TestClient client(port);
    EXPECT_TRUE(client.next("hello")["calibration_status"].is_null());
    client.send({{"type", "detect_board"}, {"request_id", "1"}, {"camera", "sim-1"}});
    EXPECT_EQ(client.next("result")["error"]["code"], "not_available");

    // The simulator's answers: an event per request, and the status in hello and when it changes
    api::Simulator simulator(server);
    simulator.start();
    EXPECT_EQ(client.next("calibration_status")["cameras"].size(), 3u);
    client.send({{"type", "detect_board"}, {"request_id", "2"}, {"camera", "sim-2"}});
    const auto detection = client.next("board_detection");
    EXPECT_TRUE(detection["ok"]);
    EXPECT_EQ(detection["ellipses"].size(), 3u);
    EXPECT_EQ(detection["wires_px"].size(), 20u);
    EXPECT_TRUE(client.next("result")["ok"]);
    client.send({{"type", "set_sector_20"}, {"request_id", "3"}, {"camera", "nope"}, {"point_px", {1, 2}}});
    EXPECT_EQ(client.next("result")["error"]["code"], "unknown_camera");
    client.send({{"type", "tune_white_balance"}, {"request_id", "4"}});
    nlohmann::json balance;
    do
    {
        balance = client.next("white_balance");
    } while(!balance.is_null() && balance["state"] != "done");
    ASSERT_FALSE(balance.is_null());
    EXPECT_EQ(balance["cameras"][0]["chosen_kelvin"], 3000);

    client.send({{"type", "subscribe_calibration_check"}, {"request_id", "5"}});
    int moved = 0;
    for(int i = 0; i < 3; ++i)
    {
        const auto check = client.next("calibration_check");
        moved += check["state"] == "moved" ? 1 : 0;
        EXPECT_EQ(check["expected_px"].size(), check["found_px"].size());
    }
    EXPECT_EQ(moved, 1);

    TestClient late(port);
    const auto status = late.next("hello")["calibration_status"];
    EXPECT_EQ(status["cameras"][0]["white_balance_kelvin"], 3000);
    EXPECT_EQ(status["cameras"][1]["check"]["state"], "moved");
    simulator.stop();
    server.stop();
}

namespace
{
// Sends a datagram to 127.0.0.1:port and returns the answer, or nothing within the wait
std::optional<std::string> askDiscovery (int port, const std::string& request, int wait_ms)
{
    const int s = ::socket(AF_INET, SOCK_DGRAM, 0);
    sockaddr_in to{};
    to.sin_family = AF_INET;
    to.sin_port = htons(static_cast<uint16_t>(port));
    to.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    ::sendto(s, request.data(), request.size(), 0, reinterpret_cast<sockaddr*>(&to), sizeof(to));
    pollfd waiting{s, POLLIN, 0};
    std::optional<std::string> answer;
    if(::poll(&waiting, 1, wait_ms) > 0)
    {
        std::array<char, 1024> buffer{};
        const auto size = ::recv(s, buffer.data(), buffer.size(), 0);
        if(size > 0)
        {
            answer = std::string(buffer.data(), static_cast<std::size_t>(size));
        }
    }
    ::close(s);
    return answer;
}
}  // namespace

TEST(Discovery, AnswersASearchOncePerSecondWithTheEngineFields)
{
    const int port = 30000 + static_cast<int>(std::random_device{}() % 20000);
    api::Discovery discovery({"board-pc", 8484, "live", "abcdefghijklmnopqrstuvwxyz", "0.2.0"}, port);
    std::string error;
    ASSERT_TRUE(discovery.start(error)) << error;

    EXPECT_FALSE(askDiscovery(port, R"({"type":"hello"})", 300));
    const auto answer = askDiscovery(port, R"({"type":"discover","protocol":"dartpilot/1.1"})", 1000);
    ASSERT_TRUE(answer);
    const auto engine = nlohmann::json::parse(*answer);
    EXPECT_EQ(engine["type"], "engine");
    EXPECT_EQ(engine["name"], "board-pc");
    EXPECT_EQ(engine["port"], 8484);
    EXPECT_EQ(engine["protocol"], api::kProtocol);
    EXPECT_EQ(engine["id"], "abcdefghijklmnopqrstuvwxyz");
    // The same asker again within a second gets no answer; an app of another protocol major gets one later.
    EXPECT_FALSE(askDiscovery(port, R"({"type":"discover","protocol":"dartpilot/1.1"})", 300));
    std::this_thread::sleep_for(std::chrono::milliseconds(1100));
    EXPECT_TRUE(askDiscovery(port, R"({"type":"discover","protocol":"dartpilot/2.0"})", 1000));
    discovery.stop();
}

TEST(Server, ThrowsAndCorrectionsAreLoggedAsSessionRecords)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Hello hello;
    hello.session_id = "20261025T080000Z-test";
    api::Server server(port, "127.0.0.1", hello);
    std::vector<nlohmann::json> records;
    std::mutex records_mutex;
    server.onLogged(
        [&] (const nlohmann::json& record)
        {
            std::lock_guard lock(records_mutex);
            records.push_back(record);
        });
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    api::Throw dart;
    dart.event_ns = 5'000'000'000;
    dart.board_point = api::BoardPoint{0.0, 103.0, std::array<double, 3>{0.5, 0.0, 0.5}};
    dart.confidence = 0.9;
    dart.cameras.push_back({"usb-1.2", true, {41, 42}, ""});
    const auto recorded = server.publishThrow(dart);
    EXPECT_EQ(recorded.throw_id, "20261025T080000Z-test/1");

    TestClient client(port);
    client.next("hello");
    client.send({{"type", "hello"}, {"request_id", "0"}, {"client", "app"}});
    client.next("result");
    client.send({{"type", "correct_throw"}, {"request_id", "1"}, {"throw_id", recorded.throw_id}, {"board_point", {{"x_mm", 1.0}, {"y_mm", 60.0}}}});
    client.next("result");
    client.send({{"type", "add_throw"}, {"request_id", "2"}, {"board_point", {{"x_mm", -30.0}, {"y_mm", 0.0}}}});
    client.next("result");
    server.stop();

    std::lock_guard lock(records_mutex);
    ASSERT_EQ(records.size(), 3u);
    EXPECT_EQ(records[0]["throw_id"], "20261025T080000Z-test/1");
    EXPECT_EQ(records[0]["score"]["label"], "T20");
    EXPECT_EQ(records[0]["camera_measurements"][0]["frames"]["after"], nlohmann::json({41, 42}));
    EXPECT_EQ(records[0]["diagnostics"]["event_ns"], 5'000'000'000);
    EXPECT_EQ(records[1]["correction"]["action"], "corrected");
    EXPECT_EQ(records[1]["correction"]["client"], "app");
    EXPECT_EQ(records[1]["correction"]["board_point"]["y_mm"], 60.0);
    EXPECT_EQ(records[2]["correction"]["action"], "added");
    EXPECT_TRUE(records[2]["correction"].contains("event_ns"));
}

TEST(Server, ASharedGameReachesEveryDisplayAndLaterOnes)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Server server(port, "127.0.0.1", api::Hello{});
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;

    std::optional<TestClient> leader(std::in_place, port);
    TestClient watcher(port);
    leader->next("hello");
    watcher.next("hello");
    leader->send({{"type", "hello"}, {"client", "kitchen-tablet"}, {"request_id", "1"}});
    EXPECT_TRUE(leader->next("result")["ok"]);
    const json game = {{"mode", "x01"}, {"current_player", 1}, {"throws", {{{"x_mm", 1.5}, {"y_mm", 99.0}}}}};
    leader->send({{"type", "share_game"}, {"game", game}, {"request_id", "2"}});
    EXPECT_TRUE(leader->next("result")["ok"]);
    const auto shared = watcher.next("shared_game");
    EXPECT_EQ(shared["client"], "kitchen-tablet");
    EXPECT_EQ(shared["game"], game);
    EXPECT_EQ(leader->next("shared_game")["game"], game);

    leader->send({{"type", "share_game"}, {"game", {{"padding", std::string(300 * 1024, 'x')}}}, {"request_id", "3"}});
    EXPECT_EQ(leader->next("result")["error"]["code"], "too_large");
    leader->send({{"type", "share_game"}, {"game", 5}, {"request_id", "4"}});
    EXPECT_EQ(leader->next("result")["error"]["code"], "bad_request");
    // Kept when the leader goes, for a display that comes later
    leader.reset();
    {
        TestClient late(port);
        late.next("hello");
        EXPECT_EQ(late.next("shared_game")["game"], game);
        late.send({{"type", "end_shared_game"}, {"request_id", "5"}});
        EXPECT_TRUE(late.next("result")["ok"]);
    }
    EXPECT_TRUE(watcher.next("shared_game")["game"].is_null());
    TestClient after(port);
    after.next("hello");
    EXPECT_TRUE(after.next("shared_game").is_null());
    server.stop();
}

TEST(Protocol, DetectionParamsAndLatencies)
{
    for(const char* type : {"get_detection_params", "set_detection_params"})
    {
        const auto parsed = api::parseRequest(std::string(R"({"type":")") + type + R"(","request_id":"1","params":{"settle_samples":6.0}})");
        const auto& request = std::get<api::CalibrationRequest>(std::get<api::Request>(parsed).body);
        EXPECT_EQ(request.type, type);
    }
    EXPECT_FALSE(api::takeoutMessage(1, 3).contains("detection_latency_ms"));
    EXPECT_EQ(api::takeoutMessage(1, 3, 412.5)["detection_latency_ms"], 412.5);
    api::Throw dart;
    dart.detection_latency_ms = 480.0;
    EXPECT_EQ(api::throwMessage(dart, scoring::BoardGeometry{})["detection_latency_ms"], 480.0);
    EXPECT_EQ(api::throwRecord(dart, scoring::BoardGeometry{})["diagnostics"]["detection_latency_ms"], 480.0);
}

TEST(Pairing, PinTokenLimitsAndStore)
{
    const auto store = std::filesystem::temp_directory_path() / ("dartpilot-pairing-" + std::to_string(std::random_device{}()) + ".json");
    std::int64_t now = 1'800'000'000;
    std::vector<std::string> shown;
    std::string token;
    {
        api::Pairing pairing(store);
        pairing.onNewPin([&] (const api::Pairing::Pin& pin) { shown.push_back(pin.pin); });
        const auto pin = pairing.pin(now);
        ASSERT_EQ(pin.pin.size(), 6u);
        EXPECT_EQ(shown.back(), pin.pin);
        EXPECT_EQ(pairing.pin(now + 599).pin, pin.pin);
        EXPECT_EQ(pairing.pairWithPin("000000" == pin.pin ? "111111" : "000000", "phone", "10.0.0.5", now).error, "wrong_pin");
        const auto paired = pairing.pairWithPin(pin.pin, "phone", "10.0.0.5", now);
        ASSERT_TRUE(paired.token);
        token = *paired.token;
        EXPECT_GE(token.size(), 32u);
        // One PIN pairs one client.
        EXPECT_NE(pairing.pin(now).pin, pin.pin);
        EXPECT_EQ(pairing.pairWithPin(pin.pin, "tablet", "10.0.0.6", now).error, "wrong_pin");
        // Five failures a minute per address, then nothing, even the right PIN
        for(int i = 0; i < 4; ++i)
        {
            pairing.pairWithToken("nope", "", "10.0.0.7", now);
        }
        EXPECT_EQ(pairing.pairWithToken("nope", "", "10.0.0.7", now).error, "unknown_token");
        EXPECT_EQ(pairing.pairWithPin(pairing.pin(now).pin, "x", "10.0.0.7", now).error, "too_many_attempts");
        EXPECT_TRUE(pairing.pairWithPin(pairing.pin(now).pin, "x", "10.0.0.8", now).token);
        EXPECT_NE(pairing.pin(now + 600).pin, "");
    }
    // The token survives a restart, stored only as its hash.
    const std::string stored = [&]
    {
        std::ifstream in(store);
        return std::string(std::istreambuf_iterator<char>(in), {});
    }();
    EXPECT_EQ(stored.find(token), std::string::npos);
    api::Pairing again(store);
    EXPECT_TRUE(again.pairWithToken(token, "phone", "10.0.0.5", now + 3600).token);
    ASSERT_EQ(again.paired().size(), 2u);
    EXPECT_TRUE(again.unpair(again.paired().front().id));
    EXPECT_FALSE(again.pairWithToken(token, "phone", "10.0.0.5", now + 3600).token);
    std::filesystem::remove(store);
    EXPECT_TRUE(api::isLocalAddress("127.0.0.1"));
    EXPECT_TRUE(api::isLocalAddress("::1"));
    EXPECT_FALSE(api::isLocalAddress("192.168.178.20"));
}

TEST(Server, AnUnpairedClientSeesNothingUntilItPairs)
{
    ix::initNetSystem();
    const int port = 20000 + static_cast<int>(std::random_device{}() % 20000);
    api::Server server(port, "127.0.0.1", api::Hello{});
    auto pairing = std::make_shared<api::Pairing>(std::filesystem::path());
    server.requirePairing(pairing, false);
    std::string error;
    ASSERT_TRUE(server.start(error)) << error;
    server.publishState({{"type", "diagnosis"}, {"step", "x"}});

    TestClient stranger(port);
    EXPECT_EQ(stranger.next("hello")["pairing"], "required");
    stranger.send({{"type", "check_board"}, {"request_id", "1"}});
    EXPECT_EQ(stranger.next("result")["error"]["code"], "not_paired");
    stranger.send({{"type", "get_pairing_pin"}, {"request_id", "2"}});
    EXPECT_EQ(stranger.next("result")["error"]["code"], "not_paired");
    server.publishTakeout(1, 3);
    stranger.send({{"type", "pair"}, {"pin", "999999" == pairing->pin(0).pin ? "000000" : "999999"}, {"request_id", "3"}});
    EXPECT_EQ(stranger.next("result")["error"]["code"], "wrong_pin");
    EXPECT_TRUE(stranger.next("takeout").is_null());
    EXPECT_TRUE(stranger.next("diagnosis").is_null());

    stranger.send({{"type", "pair"}, {"pin", pairing->pin(std::time(nullptr)).pin}, {"request_id", "4"}});
    EXPECT_TRUE(stranger.next("result")["ok"]);
    const auto paired = stranger.next("paired");
    ASSERT_TRUE(paired["token"].is_string());
    EXPECT_EQ(stranger.next("diagnosis")["step"], "x");
    server.publishTakeout(2, 1);
    EXPECT_EQ(stranger.next("takeout")["darts_removed"], 1);
    // An admin request needs a client on the engine's computer.
    stranger.send({{"type", "list_paired_clients"}, {"request_id", "5"}});
    EXPECT_EQ(stranger.next("result")["error"]["code"], "not_allowed");

    TestClient returning(port);
    returning.next("hello");
    returning.send({{"type", "pair"}, {"token", paired["token"]}, {"request_id", "6"}});
    EXPECT_TRUE(returning.next("result")["ok"]);
    EXPECT_EQ(returning.next("paired")["token"], paired["token"]);
    server.stop();
}
