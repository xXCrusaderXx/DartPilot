#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <random>
#include <sstream>
#include <string>
#include <vector>

#include "SyntheticBoard.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
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

// The board refinement of both cameras, from their own images, as the setup GUI would make it
geometry::StoredExtrinsics fixtureExtrinsics ()
{
    std::vector<geometry::RefinementInput> inputs;
    for(std::size_t c = 0; c < kViews.size(); ++c)
    {
        const auto detection = geometry::detectBoard(synthetic_board::renderCameraImage(kViews[c], 1.0, 90));
        EXPECT_TRUE(detection);
        const auto twenty = geometry::sectorAt(*detection, synthetic_board::project(kViews[c], 0.0, 60.0));
        EXPECT_TRUE(twenty);
        geometry::RefinementInput input;
        input.usb_port = c == 0 ? "1.2" : "1.3";
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
