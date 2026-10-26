#include <gtest/gtest.h>

#include <cmath>
#include <filesystem>
#include <fstream>
#include <map>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>

#include "SyntheticBoard.hpp"
#include "dartpilot/fusion/detection_params.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/board_state.hpp"
#include "dartpilot/geometry/dart_shape.hpp"
#include "dartpilot/geometry/dart_sheet.hpp"
#include "dartpilot/geometry/tip_triangulation.hpp"
#include "dartpilot/replay/replay.hpp"
#include "dartpilot/session/json.hpp"
#include "dartpilot/session/session_reader.hpp"
#include "dartpilot/session/session_writer.hpp"

using namespace dartpilot;

namespace
{
class TemporaryDirectory
{
   public:
    TemporaryDirectory ()
        : path_(std::filesystem::temp_directory_path() / ("dartpilot-replay-test-" + std::to_string(std::random_device{}())))
    {
        std::filesystem::create_directories(path_);
    }
    ~TemporaryDirectory () { std::filesystem::remove_all(path_); }
    const std::filesystem::path& path () const { return path_; }

   private:
    std::filesystem::path path_;
};

std::string readFile (const std::filesystem::path& path)
{
    std::ifstream in(path, std::ios::binary);
    std::ostringstream content;
    content << in.rdbuf();
    return content.str();
}

constexpr int kFramesPerCamera = 24;
constexpr std::int64_t kFramePeriod_ns = 33'333'333;

// Two cameras looking at the same synthetic board from different sides
const std::array<cv::Matx33d, 2> kViews = {synthetic_board::boardToImage(40.0, 600.0, 15.0), synthetic_board::boardToImage(45.0, 620.0, -20.0)};

std::vector<std::uint8_t> boardJpeg (const cv::Matx33d& h)
{
    std::vector<std::uint8_t> jpeg;
    cv::imencode(".jpg", synthetic_board::renderCameraImage(h, 1.0, 90), jpeg);
    return jpeg;
}

// A short recording of the empty board, written by the real session writer. Camera B is exposed 10 ms after camera
// A, except for one frame at the same time as A's, which replay orders by camera id.
std::filesystem::path writeFixtureSession (const std::filesystem::path& root)
{
    session::SessionInfo info;
    info.session_id = "20261024T120000Z-test";
    info.created_utc = "2026-10-24T12:00:00Z";
    info.cameras.push_back({"usb-1.2", "1.2", "/dev/null", "Cam A", {}, false, {}, std::nullopt, session::FileReference{"extrinsics.yml", "00"}});
    info.cameras.push_back({"usb-1.3", "1.3", "/dev/null", "Cam B", {}, false, {}, std::nullopt, std::nullopt});
    std::string error;
    auto writer = session::SessionWriter::create(root, info, error);
    EXPECT_TRUE(writer) << error;
    for(std::size_t c = 0; c < kViews.size(); ++c)
    {
        const auto jpeg = boardJpeg(kViews[c]);
        for(int i = 0; i < kFramesPerCamera; ++i)
        {
            capture::Frame frame;
            frame.sequence = static_cast<std::uint32_t>(100 * c + i + 1);
            frame.exposure_ns = 5'000'000'000 + i * kFramePeriod_ns + (c == 1 && i != 3 ? 10'000'000 : 0);
            frame.driver_ns = frame.exposure_ns + 20'000'000;
            frame.arrival_ns = frame.exposure_ns + 30'000'000;
            if(i % 2 == 0)
            {
                frame.pts = static_cast<std::uint32_t>(1000 + i);
            }
            frame.data = jpeg;
            writer->writeFrame(c, frame);
        }
    }
    writer->finish("2026-10-24T12:00:01Z", std::vector<capture::CaptureStats>(2));
    return writer->directory();
}

// The board refinement of the cameras usb-1.2, usb-1.3, … from their own images, as the setup GUI would make it
geometry::StoredExtrinsics fixtureExtrinsics (const std::vector<cv::Matx33d>& views = {kViews.begin(), kViews.end()})
{
    std::vector<geometry::RefinementInput> inputs;
    for(std::size_t c = 0; c < views.size(); ++c)
    {
        const auto detection = geometry::detectBoard(synthetic_board::renderCameraImage(views[c], 1.0, 90));
        EXPECT_TRUE(detection);
        const auto twenty = geometry::sectorAt(*detection, synthetic_board::project(views[c], 0.0, 60.0));
        EXPECT_TRUE(twenty);
        geometry::RefinementInput input;
        input.usb_port = "1." + std::to_string(c + 2);
        input.correspondences = geometry::orientBoard(*detection, twenty.value_or(0));
        input.prior = geometry::boardOnlyPrior(cv::Size(1280, 720));
        inputs.push_back(input);
    }
    const auto refinement = geometry::refineBoardCameras(inputs);
    EXPECT_TRUE(refinement);
    return {"2026-10-24T11:00:00Z", *refinement, inputs};
}

std::vector<std::string> lines (const std::string& text)
{
    std::vector<std::string> result;
    std::istringstream in(text);
    for(std::string line; std::getline(in, line);)
    {
        result.push_back(line);
    }
    return result;
}
}  // namespace

TEST(SessionReader, ReadsWhatTheWriterWrote)
{
    TemporaryDirectory root;
    const auto directory = writeFixtureSession(root.path());
    std::string error;
    const auto recorded = session::openSession(directory, error);
    ASSERT_TRUE(recorded) << error;
    EXPECT_EQ(recorded->session_id, "20261024T120000Z-test");
    EXPECT_EQ(recorded->version, 1);
    ASSERT_EQ(recorded->cameras.size(), 2u);
    const auto& a = recorded->cameras[0];
    EXPECT_EQ(a.id, "usb-1.2");
    EXPECT_EQ(a.usb_port, "1.2");
    EXPECT_EQ(a.width, 1280);
    ASSERT_TRUE(a.extrinsics);
    EXPECT_EQ(a.extrinsics->file, "extrinsics.yml");
    EXPECT_FALSE(recorded->cameras[1].extrinsics);
    ASSERT_EQ(a.frames.size(), static_cast<std::size_t>(kFramesPerCamera));
    EXPECT_EQ(a.frames[1].sequence, 2u);
    EXPECT_EQ(a.frames[1].exposure_ns, 5'000'000'000 + kFramePeriod_ns);
    EXPECT_EQ(a.frames[1].arrival_ns, a.frames[1].exposure_ns + 30'000'000);
    EXPECT_EQ(a.frames[1].timestamp_source, "driver");
    EXPECT_FALSE(a.frames[1].pts);
    EXPECT_EQ(a.frames[2].pts, 1002u);
    session::FrameReader reader(*recorded, 1);
    EXPECT_EQ(reader.read(5), boardJpeg(kViews[1]));
}

TEST(SessionReader, IgnoresATruncatedLastFrame)
{
    TemporaryDirectory root;
    const auto directory = writeFixtureSession(root.path());
    const auto mjpg = directory / "cameras" / "usb-1.3" / "frames.mjpg";
    std::filesystem::resize_file(mjpg, std::filesystem::file_size(mjpg) - 100);
    std::string error;
    const auto recorded = session::openSession(directory, error);
    ASSERT_TRUE(recorded) << error;
    EXPECT_EQ(recorded->cameras[0].frames.size(), static_cast<std::size_t>(kFramesPerCamera));
    EXPECT_EQ(recorded->cameras[1].frames.size(), static_cast<std::size_t>(kFramesPerCamera - 1));
}

TEST(SessionReader, RefusesANewerFormatAndMissingSessions)
{
    TemporaryDirectory root;
    const auto directory = writeFixtureSession(root.path());
    std::string manifest = readFile(directory / "manifest.json");
    manifest.replace(manifest.find("\"version\": 1"), 12, "\"version\": 2");
    std::ofstream(directory / "manifest.json") << manifest;
    std::string error;
    EXPECT_FALSE(session::openSession(directory, error));
    EXPECT_NE(error.find("version 2"), std::string::npos) << error;
    EXPECT_FALSE(session::openSession(root.path() / "nothing", error));
}

TEST(Json, ParsesTheValuesTheFormatUses)
{
    std::string error;
    const auto value = session::parseJson(R"( {"a": [1, -2.5e3, true, false, null], "s": "q\"\\\né🎯", "n": {"t": 1700000000123456789}} )", error);
    ASSERT_TRUE(value) << error;
    const auto* a = value->find("a");
    ASSERT_TRUE(a);
    ASSERT_EQ(a->items.size(), 5u);
    EXPECT_EQ(a->items[1].text, "-2.5e3");
    EXPECT_TRUE(a->items[2].boolean);
    EXPECT_FALSE(a->items[3].boolean);
    EXPECT_TRUE(a->items[4].isNull());
    EXPECT_EQ(value->string("s"), "q\"\\\n\xc3\xa9\xf0\x9f\x8e\xaf");
    EXPECT_EQ(value->find("n")->integer("t"), 1700000000123456789LL);
    EXPECT_EQ(session::parseJson(session::jsonString("tab\there"), error)->text, "tab\there");
    for(const char* bad : {"", "{", "[1,]", "{\"a\" 1}", "\"open", "nul", "{} x"})
    {
        EXPECT_FALSE(session::parseJson(bad, error)) << bad;
    }
}

TEST(Replay, OrdersFramesByExposureTimeThenCamera)
{
    TemporaryDirectory root;
    std::string error;
    const auto recorded = session::openSession(writeFixtureSession(root.path()), error);
    ASSERT_TRUE(recorded) << error;
    const auto order = replay::replayOrder(*recorded);
    ASSERT_EQ(order.size(), 2u * kFramesPerCamera);
    for(std::size_t i = 1; i < order.size(); ++i)
    {
        const auto& previous = recorded->cameras[order[i - 1].camera].frames[order[i - 1].frame];
        const auto& current = recorded->cameras[order[i].camera].frames[order[i].frame];
        ASSERT_LE(previous.exposure_ns, current.exposure_ns);
    }
    // Frame 3 of both cameras has the same time: camera usb-1.2 first.
    const auto tie = std::find_if(order.begin(), order.end(), [] (const auto& f) { return f.frame == 3; });
    EXPECT_EQ(tie->camera, 0u);
    EXPECT_EQ((tie + 1)->camera, 1u);
    EXPECT_EQ((tie + 1)->frame, 3u);
}

TEST(Replay, TwoRunsGiveByteIdenticalResults)
{
    TemporaryDirectory root;
    std::string error;
    const auto recorded = session::openSession(writeFixtureSession(root.path()), error);
    ASSERT_TRUE(recorded) << error;
    replay::ReplayConfig config;
    config.extrinsics = fixtureExtrinsics();
    config.extrinsics_sha256 = "ab";
    // Two checks per camera in the 0.8 s recording
    config.check_interval_ns = 400'000'000;

    config.run_id = "first";
    const auto first = replay::replaySession(*recorded, config, error);
    ASSERT_TRUE(first) << error;
    config.run_id = "second";
    const auto second = replay::replaySession(*recorded, config, error);
    ASSERT_TRUE(second) << error;

    EXPECT_EQ(first->frames, 2u * kFramesPerCamera);
    EXPECT_EQ(first->undecodable_frames, 0u);
    EXPECT_EQ(first->calibration_checks, 4u);
    for(const char* file : {"throws.jsonl", "calibration_checks.jsonl"})
    {
        EXPECT_EQ(readFile(first->run_directory / file), readFile(second->run_directory / file)) << file;
    }
    const auto checks = lines(readFile(first->run_directory / "calibration_checks.jsonl"));
    ASSERT_EQ(checks.size(), 4u);
    for(const auto& line : checks)
    {
        const auto value = session::parseJson(line, error);
        ASSERT_TRUE(value) << error << ": " << line;
        EXPECT_TRUE(value->find("board_found")->boolean) << line;
        EXPECT_LT(std::stod(value->find("rms_mm")->text), 0.5) << line;
        EXPECT_EQ(value->find("frames")->items.size(), 10u);
    }
    // The first check of camera usb-1.2 used its frames 1 to 10.
    EXPECT_EQ(session::parseJson(checks[0], error)->string("camera"), "usb-1.2");
    EXPECT_EQ(session::parseJson(checks[0], error)->find("frames")->items[0].text, "1");

    const auto run = session::parseJson(readFile(first->run_directory / "run.json"), error);
    ASSERT_TRUE(run) << error;
    EXPECT_EQ(run->string("run_id"), "first");
    EXPECT_EQ(run->find("calibration")->find("usb-1.3")->string("extrinsics_sha256"), "ab");
    EXPECT_EQ(run->string("config_sha256").size(), 64u);

    // A run never overwrites another.
    EXPECT_FALSE(replay::replaySession(*recorded, config, error));
}

TEST(Replay, AKnockedCameraAndATurnedBoardFailTheirChecks)
{
    TemporaryDirectory root;
    std::string error;
    const auto recorded = session::openSession(writeFixtureSession(root.path()), error);
    ASSERT_TRUE(recorded) << error;
    replay::ReplayConfig config;
    config.extrinsics = fixtureExtrinsics();
    config.check_interval_ns = 400'000'000;
    // Per camera the error of its first and its second check, the second after the move
    const auto checkErrors = [&] (const std::string& run_id)
    {
        config.run_id = run_id;
        const auto summary = replay::replaySession(*recorded, config, error);
        std::map<std::string, std::vector<double>> errors_mm;
        for(const auto& line : lines(readFile(summary->run_directory / "calibration_checks.jsonl")))
        {
            const auto value = session::parseJson(line, error);
            errors_mm[value->string("camera")].push_back(value->find("board_found")->boolean ? std::stod(value->find("rms_mm")->text) : 1e9);
        }
        return errors_mm;
    };

    config.moves = {{400'000'000, "usb-1.2", {6.0, -3.0}, 0.0}};
    auto knocked = checkErrors("knocked");
    ASSERT_EQ(knocked["usb-1.2"].size(), 2u);
    ASSERT_EQ(knocked["usb-1.3"].size(), 2u);
    EXPECT_LT(knocked["usb-1.2"][0], 1.0);
    EXPECT_GT(knocked["usb-1.2"][1], 2.5);
    EXPECT_LT(knocked["usb-1.3"][1], 1.0);

    config.moves = {{400'000'000, "", {}, 1.5}};
    auto turned = checkErrors("turned");
    for(const char* camera : {"usb-1.2", "usb-1.3"})
    {
        ASSERT_EQ(turned[camera].size(), 2u) << camera;
        EXPECT_LT(turned[camera][0], 1.0) << camera;
        EXPECT_GT(turned[camera][1], 2.5) << camera;
    }
}

TEST(Replay, WithoutARefinementThereAreNoChecks)
{
    TemporaryDirectory root;
    std::string error;
    const auto recorded = session::openSession(writeFixtureSession(root.path()), error);
    ASSERT_TRUE(recorded) << error;
    const auto summary = replay::replaySession(*recorded, {}, error);
    ASSERT_TRUE(summary) << error;
    EXPECT_EQ(summary->frames, 2u * kFramesPerCamera);
    EXPECT_EQ(summary->calibration_checks, 0u);
    EXPECT_TRUE(readFile(summary->run_directory / "calibration_checks.jsonl").empty());
    EXPECT_TRUE(std::filesystem::exists(summary->run_directory / "throws.jsonl"));
}

// The fixture session that tools/tests/test_session.py reads as well, so both readers agree on the format
TEST(SessionReader, ReadsTheSharedFixture)
{
    const std::filesystem::path fixture = std::filesystem::path(DARTPILOT_SOURCE_DIR) / "tests/fixtures/session-v1";
    std::string error;
    const auto recorded = session::openSession(fixture, error);
    ASSERT_TRUE(recorded) << error;
    EXPECT_EQ(recorded->session_id, "20261024T120000Z-fixt");
    ASSERT_EQ(recorded->cameras.size(), 2u);
    EXPECT_EQ(recorded->cameras[1].name, "Cam B \"quoted\" \xc3\xa9");
    ASSERT_TRUE(recorded->cameras[0].extrinsics);
    EXPECT_EQ(recorded->cameras[0].extrinsics->sha256, "22bb");
    EXPECT_EQ(recorded->cameras[0].frames.size(), 4u);
    EXPECT_FALSE(recorded->cameras[0].frames[2].pts);
    // The last JPEG of usb-1.3 never reached frames.mjpg completely.
    EXPECT_EQ(recorded->cameras[1].frames.size(), 2u);
    session::FrameReader reader(*recorded, 0);
    const auto bytes = reader.read(3);
    EXPECT_EQ(std::string(bytes.begin(), bytes.end()), "placeholder usb-1.2 frame 5\n");

    std::vector<std::pair<std::string, std::uint32_t>> order;
    for(const auto& f : replay::replayOrder(*recorded))
    {
        order.emplace_back(recorded->cameras[f.camera].id, recorded->cameras[f.camera].frames[f.frame].sequence);
    }
    const std::vector<std::pair<std::string, std::uint32_t>> expected = {{"usb-1.2", 1},  {"usb-1.3", 11}, {"usb-1.2", 2},
                                                                         {"usb-1.3", 12}, {"usb-1.2", 3},  {"usb-1.2", 5}};
    EXPECT_EQ(order, expected);

    for(const auto& line : lines(readFile(fixture / "results/replay/throws.jsonl")))
    {
        EXPECT_TRUE(session::parseJson(line, error)) << error;
    }
    const auto check = session::parseJson(lines(readFile(fixture / "results/replay/calibration_checks.jsonl")).front(), error);
    ASSERT_TRUE(check) << error;
    EXPECT_EQ(check->find("rms_mm")->text, "0.4321");
}

namespace
{
// A dart entering the synthetic board at tip_mm, as camera sees it: a thin point, a thicker barrel and a flight, in a
// colour that stands out on every field, so frame differencing sees the whole dart
void drawDart (cv::Mat& image, const geometry::RefinedCamera& camera, const cv::Point2f& tip_mm, double lean_deg)
{
    const float out = geometry::cameraCentre(camera)[2] >= 0.0 ? 1.0f : -1.0f;
    const double tilt = 15.0 * CV_PI / 180.0, lean = lean_deg * CV_PI / 180.0;
    const cv::Point3f axis(static_cast<float>(std::sin(tilt) * std::cos(lean)), static_cast<float>(std::sin(tilt) * std::sin(lean)),
                           out * static_cast<float>(std::cos(tilt)));
    const cv::Point3f tip(tip_mm.x, tip_mm.y, 0.0f);
    const auto line = [&] (float from_mm, float to_mm, int thickness, const cv::Scalar& colour)
    {
        for(float s = from_mm; s < to_mm; s += 1.0f)
        {
            cv::line(image, geometry::boardToImage(camera, tip + axis * s), geometry::boardToImage(camera, tip + axis * (s + 1.0f)), colour,
                     thickness, cv::LINE_AA);
        }
    };
    line(0.0f, 28.0f, 2, cv::Scalar(230, 120, 30));
    line(28.0f, 75.0f, 6, cv::Scalar(230, 120, 30));
    line(80.0f, 115.0f, 18, cv::Scalar(200, 200, 200));
}

// Three cameras around the board, so the dart's axis crosses their views at a wide angle
std::vector<cv::Matx33d> aroundTheBoard ()
{
    std::vector<cv::Matx33d> views;
    for(const double azimuth_deg : {0.0, 120.0, 240.0})
    {
        const double a = azimuth_deg * CV_PI / 180.0;
        views.push_back(synthetic_board::boardToImage(45.0, 600.0, 0.0) *
                        cv::Matx33d(std::cos(a), -std::sin(a), 0, std::sin(a), std::cos(a), 0, 0, 0, 1));
    }
    return views;
}

// A game on the three cameras at 10 frames per second: the empty board, a dart, a second dart, the empty board
// again, with a hand passing in front of the board between them
std::filesystem::path writeGameSession (const std::filesystem::path& root, const std::vector<cv::Matx33d>& views,
                                        const geometry::StoredExtrinsics& extrinsics, const std::vector<cv::Point2f>& darts_mm)
{
    session::SessionInfo info;
    info.session_id = "20261024T130000Z-game";
    info.created_utc = "2026-10-24T13:00:00Z";
    for(std::size_t c = 0; c < views.size(); ++c)
    {
        const std::string port = "1." + std::to_string(c + 2);
        info.cameras.push_back({"usb-" + port, port, "/dev/null", "Cam", {}, false, {}, std::nullopt, std::nullopt});
    }
    std::string error;
    auto writer = session::SessionWriter::create(root, info, error);
    EXPECT_TRUE(writer) << error;
    constexpr std::int64_t kPeriod_ns = 100'000'000;
    const std::vector<std::vector<std::size_t>> states = {{}, {0}, {0, 1}, {}};
    for(std::size_t c = 0; c < views.size(); ++c)
    {
        const cv::Mat board = synthetic_board::renderCameraImage(views[c], 1.0, 90);
        std::uint32_t sequence = 0;
        for(std::size_t s = 0; s < states.size(); ++s)
        {
            cv::Mat still = board.clone();
            for(const std::size_t d : states[s])
            {
                drawDart(still, extrinsics.refinement.cameras[c], darts_mm[d], 30.0 + 120.0 * static_cast<double>(d));
            }
            std::vector<std::uint8_t> still_jpeg;
            cv::imencode(".jpg", still, still_jpeg);
            // A hand moving in front of the board, then the board still for 3 s
            for(int i = 0; i < 35; ++i)
            {
                std::vector<std::uint8_t> jpeg = still_jpeg;
                if(s > 0 && i < 5)
                {
                    cv::Mat hand = still.clone();
                    cv::rectangle(hand, cv::Rect(200 + 150 * i, 200, 300, 250), cv::Scalar(90, 120, 170), cv::FILLED);
                    cv::imencode(".jpg", hand, jpeg);
                }
                capture::Frame frame;
                frame.sequence = ++sequence;
                frame.exposure_ns = 1'000'000'000 + static_cast<std::int64_t>(sequence) * kPeriod_ns;
                frame.driver_ns = frame.exposure_ns;
                frame.arrival_ns = frame.exposure_ns;
                frame.data = jpeg;
                writer->writeFrame(c, frame);
            }
        }
    }
    writer->finish("2026-10-24T13:00:15Z", std::vector<capture::CaptureStats>(views.size()));
    return writer->directory();
}
}  // namespace

TEST(Replay, BothPipelinesFindTheDartsOfARecordedGame)
{
    TemporaryDirectory root;
    std::string error;
    replay::ReplayConfig config;
    const auto views = aroundTheBoard();
    config.extrinsics = fixtureExtrinsics(views);
    config.extrinsics_sha256 = "ab";
    config.check_interval_ns = 0;
    const std::vector<cv::Point2f> darts_mm = {{30.0f, 60.0f}, {-50.0f, -20.0f}};
    const auto directory = writeGameSession(root.path(), views, *config.extrinsics, darts_mm);

    for(const char* pipeline : {"tracker", "baseline"})
    {
        // Opened again for every run: the first one writes the session's throws.csv, the second keeps its throw ids.
        const auto recorded = session::openSession(directory, error);
        ASSERT_TRUE(recorded) << error;
        config.pipeline = pipeline;
        config.run_id = pipeline;
        const auto summary = replay::replaySession(*recorded, config, error);
        ASSERT_TRUE(summary) << error;
        EXPECT_EQ(summary->throws, 2u) << pipeline;
        EXPECT_EQ(summary->takeouts, 1u) << pipeline;
        EXPECT_EQ(summary->unmatched_throws, 0u) << pipeline;
        EXPECT_EQ(summary->wrote_session_throws, std::string(pipeline) == "tracker");
        const auto results = lines(readFile(summary->run_directory / "throws.jsonl"));
        ASSERT_EQ(results.size(), 2u) << pipeline;
        for(std::size_t i = 0; i < results.size(); ++i)
        {
            const auto line = session::parseJson(results[i], error);
            ASSERT_TRUE(line) << error;
            EXPECT_EQ(line->string("throw_id"), "20261024T130000Z-game/" + std::to_string(i + 1));
            const auto* point = line->find("board_point");
            ASSERT_TRUE(point && !point->isNull()) << pipeline << " throw " << i + 1;
            const auto at = [] (const session::JsonValue& p)
            { return cv::Point2f(std::stof(p.find("x_mm")->text), std::stof(p.find("y_mm")->text)); };
            if(std::string(pipeline) == "tracker")
            {
                EXPECT_LT(cv::norm(at(*point) - darts_mm[i]), 3.0) << "throw " << i + 1 << ": " << results[i];
                continue;
            }
            // The baseline averages every camera that saw a change: one that looks along the dart sees only the flight and
            // pulls the mean away, while those that see the whole dart find its point.
            int right = 0;
            for(const auto& camera : line->find("camera_measurements")->items)
            {
                const auto* camera_point = camera.find("board_point");
                right += camera_point && !camera_point->isNull() && cv::norm(at(*camera_point) - darts_mm[i]) < 3.0 ? 1 : 0;
            }
            EXPECT_GE(right, 2) << "throw " << i + 1 << ": " << results[i];
        }
    }
    const auto recorded = session::openSession(directory, error);
    ASSERT_TRUE(recorded) << error;
    ASSERT_EQ(recorded->throws.size(), 2u);
    EXPECT_EQ(recorded->throws[1].throw_id, "20261024T130000Z-game/2");
    EXPECT_EQ(recorded->throws[1].source, "replay:tracker");
    EXPECT_LT(recorded->throws[0].window_start_ns, recorded->throws[0].event_ns);

    config.pipeline = "tracker";
    config.run_id = "tracker-again";
    const auto again = replay::replaySession(*recorded, config, error);
    ASSERT_TRUE(again) << error;
    EXPECT_EQ(readFile(again->run_directory / "throws.jsonl"), readFile(directory / "results/tracker/throws.jsonl"));
}

TEST(StillDetector, ADartLandingIsMotionButImageNoiseIsNot)
{
    cv::Mat before(180, 320, CV_32F, cv::Scalar(120.0f));
    cv::Mat noisy = before.clone();
    cv::randn(noisy, cv::Scalar(120.0), cv::Scalar(1.5));
    EXPECT_FALSE(event_detection::moved(before, noisy));
    // A dart a quarter of the size: a few hundred pixels change, the mean of the image hardly at all
    cv::Mat dart = before.clone();
    cv::line(dart, {100, 40}, {160, 90}, cv::Scalar(30.0f), 3);
    EXPECT_LT(cv::mean(cv::abs(dart - before))[0], 2.5);
    EXPECT_TRUE(event_detection::moved(before, dart));
    // A person passing changes everything a little
    EXPECT_TRUE(event_detection::moved(before, before + 10.0f));
}

TEST(DetectionParams, AnUncertainFieldOnlyWhenSwitchedOn)
{
    fusion::ConfidenceSettings settings;
    const cv::Matx22d covariance(1.0, 0.0, 0.0, 1.0);
    // On the wire between T20 and T1, and in the middle of T20
    EXPECT_FALSE(fusion::uncertainField(16.1, 102.9, covariance, {}, settings));
    settings.uncertain_field_probability = 0.9;
    EXPECT_TRUE(fusion::uncertainField(16.1, 102.9, covariance, {}, settings));
    EXPECT_FALSE(fusion::uncertainField(0.0, 103.0, cv::Matx22d(0.2, 0.0, 0.0, 0.2), {}, settings));
    fusion::DetectionSettings detection;
    EXPECT_FALSE(fusion::setDetectionParam(detection, "uncertain_field_probability", 0.8));
    EXPECT_EQ(detection.confidence.uncertain_field_probability, 0.8);
}

TEST(DetectionParams, DocumentedAsInTheRegistry)
{
    const std::string doc = readFile(std::filesystem::path(DARTPILOT_SOURCE_DIR) / "docs/detection-params.md");
    const std::string begin = "<!-- detection-params:begin -->\n", end = "<!-- detection-params:end -->";
    const auto from = doc.find(begin), to = doc.find(end);
    ASSERT_NE(from, std::string::npos);
    ASSERT_NE(to, std::string::npos);
    EXPECT_EQ(doc.substr(from + begin.size(), to - from - begin.size()), fusion::detectionParamsMarkdown())
        << "docs/detection-params.md is out of date: regenerate its table with `dartpilot detection-params`.";
}

TEST(DetectionParams, EveryValueHasItsDefaultWithinRangeAndCanBeSet)
{
    std::set<std::string> names;
    for(const auto& param : fusion::detectionParams())
    {
        EXPECT_TRUE(names.insert(param.name).second) << param.name;
        EXPECT_FALSE(param.description.empty()) << param.name;
        EXPECT_TRUE(param.group == "event_detection" || param.group == "tip_candidates" || param.group == "geometry" || param.group == "fusion")
            << param.name;
        EXPECT_GE(param.defaultValue(), param.min) << param.name;
        EXPECT_LE(param.defaultValue(), param.max) << param.name;
        fusion::DetectionSettings settings;
        ASSERT_FALSE(fusion::setDetectionParam(settings, param.name, param.max)) << param.name;
        EXPECT_NEAR(param.get(settings), param.step >= 1.0 ? std::round(param.max) : param.max, 1e-6) << param.name;
    }
    fusion::DetectionSettings settings;
    EXPECT_TRUE(fusion::setDetectionParam(settings, "nope", 1.0));
    EXPECT_TRUE(fusion::setDetectionParam(settings, "settle_samples", 1000.0));
    ASSERT_FALSE(fusion::setDetectionParam(settings, "settle_samples", 6.4));
    EXPECT_EQ(settings.still.settle_samples, 6);
}

TEST(DartShape, MeasuresLengthFlightAndBarrelOfASyntheticDart)
{
    const auto views = aroundTheBoard();
    const auto extrinsics = fixtureExtrinsics(views);
    const cv::Point2f tip_mm(30.0f, 60.0f);
    std::vector<geometry::DartView> dart_views;
    for(std::size_t c = 0; c < views.size(); ++c)
    {
        const cv::Mat board = synthetic_board::renderCameraImage(views[c], 1.0, 90);
        cv::Mat with_dart = board.clone();
        drawDart(with_dart, extrinsics.refinement.cameras[c], tip_mm, 30.0);
        // Through JPEG, as the cameras deliver it
        std::vector<std::uint8_t> jpeg;
        cv::imencode(".jpg", with_dart, jpeg);
        with_dart = cv::imdecode(jpeg, cv::IMREAD_COLOR);
        if(const auto observation = tip_candidates::observeDart(with_dart, board))
        {
            dart_views.push_back({&extrinsics.refinement.cameras[c], *observation});
        }
    }
    ASSERT_GE(dart_views.size(), 2u);
    const auto location = geometry::locateDart(dart_views);
    ASSERT_TRUE(location);
    const auto shape = geometry::measureDart(dart_views, *location);
    ASSERT_TRUE(shape);
    // drawDart: point 0–28 mm, barrel 28–75 mm, flight 80–115 mm, 15° off the board's normal. Its lines are drawn with
    // round ends a few pixels wide, so the drawn dart is longer than 115 mm.
    EXPECT_NEAR(shape->total_mm, 120.0, 8.0);
    EXPECT_NEAR(shape->flight_mm, 45.0, 10.0);
    EXPECT_GT(shape->barrel_mm, 20.0);
    EXPECT_LT(shape->point_mm, 40.0);
    EXPECT_NEAR(std::acos(std::abs(shape->direction[2])) * 180.0 / CV_PI, 15.0, 3.0);
    EXPECT_GE(shape->cameras, 2);
}

TEST(TipTriangulation, TheTipsOfAllCamerasMeetAtTheEntryPoint)
{
    const auto views = aroundTheBoard();
    const auto extrinsics = fixtureExtrinsics(views);
    const cv::Point2f tip_mm(-40.0f, 25.0f);
    std::vector<geometry::DartView> dart_views;
    for(std::size_t c = 0; c < views.size(); ++c)
    {
        const cv::Mat board = synthetic_board::renderCameraImage(views[c], 1.0, 90);
        cv::Mat with_dart = board.clone();
        drawDart(with_dart, extrinsics.refinement.cameras[c], tip_mm, 60.0);
        if(const auto observation = tip_candidates::observeDart(with_dart, board))
        {
            dart_views.push_back({&extrinsics.refinement.cameras[c], *observation});
        }
    }
    ASSERT_GE(dart_views.size(), 2u);
    const auto location = geometry::locateDart(dart_views);
    ASSERT_TRUE(location);
    const auto tips = geometry::triangulateTips(dart_views, *location);
    ASSERT_TRUE(tips.point_mm);
    EXPECT_GE(tips.views_used, 2);
    EXPECT_LT(cv::norm(cv::Point2d(tips.point_mm->x, tips.point_mm->y) - cv::Point2d(tip_mm)), 2.0);
    // The drawn point ends in a rounded cap a pixel or two beyond its tip, which the axis carries out of the board a little.
    EXPECT_LT(std::abs(tips.point_mm->z), 4.0);
    for(std::size_t v = 0; v < dart_views.size(); ++v)
    {
        if(tips.tip_px[v])
        {
            ASSERT_TRUE(tips.board_mm[v]);
            EXPECT_LT(cv::norm(*tips.board_mm[v] - tip_mm), 4.0) << "view " << v;
            EXPECT_LT(*tips.reprojection_px[v], 3.0) << "view " << v;
        }
    }
}

TEST(DartSheet, MeasuresTheDartOnAPhotoOfTheSheet)
{
    constexpr double kPx_per_mm = 8.0;
    cv::Mat sheet = geometry::dartSheetImage(kPx_per_mm);
    if(sheet.empty())
    {
        GTEST_SKIP() << "built without ArUco support";
    }
    // A dart lying at an angle: point 25 mm × 2.2, barrel 45 × 7, shaft 35 × 4.5, flight 38 × 30
    const cv::Point2d start_mm(40.0, 110.0), direction(std::cos(0.5), std::sin(0.5));
    const cv::Point2d normal(-direction.y, direction.x);
    double along = 0.0;
    for(const auto& [length, width, grey] : std::vector<std::tuple<double, double, int>>{{25, 2.2, 150}, {45, 7.0, 60}, {35, 4.5, 30}, {38, 30.0, 0}})
    {
        const cv::Point2d a = start_mm + direction * along, b = start_mm + direction * (along + length);
        std::vector<cv::Point> quad;
        for(const auto& p : {a + normal * (width / 2), b + normal * (width / 2), b - normal * (width / 2), a - normal * (width / 2)})
        {
            quad.emplace_back(cvRound(p.x * kPx_per_mm), cvRound(p.y * kPx_per_mm));
        }
        cv::fillConvexPoly(sheet, quad, grey == 0 ? cv::Scalar(40, 200, 60) : cv::Scalar(grey, grey, grey));
        along += length;
    }
    // A phone photo: tilted, smaller, a little blurred, through JPEG
    const std::vector<cv::Point2f> from{{0, 0},
                                        {static_cast<float>(sheet.cols), 0},
                                        {static_cast<float>(sheet.cols), static_cast<float>(sheet.rows)},
                                        {0, static_cast<float>(sheet.rows)}};
    const std::vector<cv::Point2f> to{{120, 80}, {1480, 140}, {1540, 2080}, {60, 2010}};
    cv::Mat photo;
    cv::warpPerspective(sheet, photo, cv::getPerspectiveTransform(from, to), cv::Size(1600, 2160), cv::INTER_AREA, cv::BORDER_CONSTANT,
                        cv::Scalar(70, 70, 70));
    cv::GaussianBlur(photo, photo, cv::Size(), 0.8);
    std::vector<std::uint8_t> jpeg;
    cv::imencode(".jpg", photo, jpeg, {cv::IMWRITE_JPEG_QUALITY, 90});
    photo = cv::imdecode(jpeg, cv::IMREAD_COLOR);

    std::string why;
    const auto measure = geometry::measureDartPhoto(photo, &why);
    ASSERT_TRUE(measure) << why;
    EXPECT_NEAR(measure->total_mm, 143.0, 2.0);
    EXPECT_NEAR(measure->point_mm, 25.0, 2.5);
    EXPECT_NEAR(measure->barrel_mm, 45.0, 3.0);
    EXPECT_NEAR(measure->barrel_diameter_mm, 7.0, 1.0);
    EXPECT_NEAR(measure->shaft_mm, 35.0, 3.0);
    EXPECT_NEAR(measure->flight_mm, 38.0, 3.0);
    EXPECT_FALSE(measure->image.empty());

    const cv::Mat blank(2000, 1500, CV_8UC3, cv::Scalar(255, 255, 255));
    EXPECT_FALSE(geometry::measureDartPhoto(blank, &why));
    EXPECT_EQ(why, "sheet_not_found");
}

TEST(BoardCheck, OnlyWhatLiesOnTheBoardMakesItOccupied)
{
    const auto views = aroundTheBoard();
    const auto extrinsics = fixtureExtrinsics(views);
    const auto& camera = extrinsics.refinement.cameras[0];
    const cv::Mat empty = synthetic_board::renderCameraImage(views[0], 1.0, 90);

    // A hand on the number ring and the surround, outside the double ring: not on the board
    cv::Mat hand = empty.clone();
    const cv::Point2f outside = geometry::boardToImage(camera, cv::Point3f(0.0f, -205.0f, 0.0f));
    cv::ellipse(hand, cv::RotatedRect(outside, cv::Size2f(140, 70), 0), cv::Scalar(90, 120, 170), cv::FILLED);
    EXPECT_EQ(geometry::checkBoard(hand, &empty, &camera, extrinsics.refinement.board).state, geometry::BoardState::Empty);
    // Without a calibration the whole image counts, as before.
    EXPECT_EQ(geometry::checkBoard(hand, &empty, nullptr, extrinsics.refinement.board).state, geometry::BoardState::Occupied);

    // A dart in the board, also near the double ring, whose flight reaches beyond it in the image
    for(const cv::Point2f tip_mm : {cv::Point2f(30.0f, 60.0f), cv::Point2f(0.0f, -160.0f)})
    {
        cv::Mat dart = empty.clone();
        drawDart(dart, camera, tip_mm, 30.0);
        const auto check = geometry::checkBoard(dart, &empty, &camera, extrinsics.refinement.board);
        EXPECT_EQ(check.state, geometry::BoardState::Occupied) << tip_mm;
    }
}
