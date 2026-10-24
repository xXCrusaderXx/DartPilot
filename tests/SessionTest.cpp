#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <random>
#include <sstream>
#include <string>
#include <vector>

#include "dartpilot/session/session_writer.hpp"
#include "dartpilot/session/sha256.hpp"

using namespace dartpilot;

namespace
{
std::string sha (const std::string& text) { return session::sha256Hex(std::span(reinterpret_cast<const std::uint8_t*>(text.data()), text.size())); }

std::string readFile (const std::filesystem::path& path)
{
    std::ifstream in(path, std::ios::binary);
    std::ostringstream content;
    content << in.rdbuf();
    return content.str();
}

std::vector<std::string> lines (const std::filesystem::path& path)
{
    std::ifstream in(path);
    std::vector<std::string> result;
    for(std::string line; std::getline(in, line);)
    {
        result.push_back(line);
    }
    return result;
}

class TemporaryDirectory
{
   public:
    TemporaryDirectory ()
        : path_(std::filesystem::temp_directory_path() / ("dartpilot-session-test-" + std::to_string(std::random_device{}())))
    {
        std::filesystem::create_directories(path_);
    }
    ~TemporaryDirectory () { std::filesystem::remove_all(path_); }
    const std::filesystem::path& path () const { return path_; }

   private:
    std::filesystem::path path_;
};

session::SessionInfo twoCameras ()
{
    session::SessionInfo info;
    info.session_id = "20261024T080000Z-abcd";
    info.created_utc = "2026-10-24T08:00:00Z";
    info.notes = "test \"quoted\"";
    info.cameras.push_back({"usb-1.2",
                            "1.2",
                            "/dev/v4l/by-path/x",
                            "Cam A",
                            {},
                            true,
                            {{"auto_exposure", 3}},
                            session::FileReference{"intrinsics-usb-1.2.yml", "ab12"},
                            session::FileReference{"extrinsics.yml", "cd34"}});
    info.cameras.push_back({"usb-1.3", "1.3", "/dev/v4l/by-path/y", "Cam B", {}, false, {}, std::nullopt, std::nullopt});
    return info;
}

capture::Frame frame (std::uint32_t sequence, std::size_t size, std::uint8_t fill)
{
    capture::Frame f;
    f.sequence = sequence;
    f.exposure_ns = 1'000'000'000 + static_cast<std::int64_t>(sequence) * 33'328'000;
    f.timestamp_source = capture::TimestampSource::UvcPts;
    f.driver_ns = f.exposure_ns + 1'200'000;
    f.arrival_ns = f.exposure_ns + 31'000'000;
    f.pts = 500'000 * sequence;
    f.clock_sample = capture::ClockSample{500'000 * sequence + 100, f.exposure_ns + 900'000};
    f.data.assign(size, fill);
    return f;
}
}  // namespace

TEST(Sha256, MatchesTheStandardTestVectors)
{
    EXPECT_EQ(sha(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    EXPECT_EQ(sha("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    EXPECT_EQ(sha("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
    EXPECT_EQ(sha(std::string(1000, 'a')), "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3");
}

TEST(SessionWriter, WritesFramesIndexAndClockSamples)
{
    TemporaryDirectory root;
    std::string error;
    auto writer = session::SessionWriter::create(root.path(), twoCameras(), error);
    ASSERT_TRUE(writer) << error;
    ASSERT_TRUE(writer->writeFrame(0, frame(1, 10, 0xaa)));
    ASSERT_TRUE(writer->writeFrame(0, frame(2, 7, 0xbb)));
    ASSERT_TRUE(writer->writeFrame(1, frame(5, 3, 0xcc)));

    const auto camera_dir = writer->directory() / "cameras" / "usb-1.2";
    EXPECT_EQ(readFile(camera_dir / "frames.mjpg"), std::string(10, '\xaa') + std::string(7, '\xbb'));
    const auto index = lines(camera_dir / "frames.csv");
    ASSERT_EQ(index.size(), 3u);
    EXPECT_EQ(index[0], "sequence,exposure_ns,timestamp_source,driver_ns,arrival_ns,pts,offset,size");
    EXPECT_EQ(index[1], "1,1033328000,pts,1034528000,1064328000,500000,0,10");
    EXPECT_EQ(index[2], "2,1066656000,pts,1067856000,1097656000,1000000,10,7");
    const auto clock = lines(camera_dir / "clock.csv");
    ASSERT_EQ(clock.size(), 3u);
    EXPECT_EQ(clock[1], "1,500100,1034228000");
    EXPECT_EQ(writer->totals(0).bytes_written, 17u);
    EXPECT_EQ(writer->totals(1).frames_written, 1u);
}

TEST(SessionWriter, ManifestCarriesCamerasAndFinalSummary)
{
    TemporaryDirectory root;
    std::string error;
    auto writer = session::SessionWriter::create(root.path(), twoCameras(), error);
    ASSERT_TRUE(writer) << error;
    const std::string initial = readFile(writer->directory() / "manifest.json");
    EXPECT_NE(initial.find("\"format\": \"dartpilot-session\""), std::string::npos);
    EXPECT_NE(initial.find("\"version\": 1"), std::string::npos);
    EXPECT_NE(initial.find("\"intrinsics\": { \"file\": \"intrinsics-usb-1.2.yml\", \"sha256\": \"ab12\" }"), std::string::npos);
    EXPECT_NE(initial.find("\"notes\": \"test \\\"quoted\\\"\""), std::string::npos);
    EXPECT_EQ(initial.find("summary"), std::string::npos);

    writer->writeFrame(0, frame(1, 4, 1));
    capture::CaptureStats stats;
    stats.frames = 1;
    stats.lost_frames = 2;
    ASSERT_TRUE(writer->finish("2026-10-24T08:10:00Z", {stats, {}}));
    const std::string final_manifest = readFile(writer->directory() / "manifest.json");
    EXPECT_NE(final_manifest.find("\"ended_utc\": \"2026-10-24T08:10:00Z\""), std::string::npos);
    EXPECT_NE(final_manifest.find("\"summary\": { \"frames\": 1, \"lost_frames\": 2"), std::string::npos);
    EXPECT_FALSE(std::filesystem::exists(writer->directory() / "manifest.json.tmp"));
}

TEST(SessionWriter, RefusesAnExistingSession)
{
    TemporaryDirectory root;
    std::string error;
    ASSERT_TRUE(session::SessionWriter::create(root.path(), twoCameras(), error));
    EXPECT_FALSE(session::SessionWriter::create(root.path(), twoCameras(), error));
    EXPECT_NE(error.find("already exists"), std::string::npos);
}

TEST(SessionWriter, HealthLinesPerCamera)
{
    TemporaryDirectory root;
    std::string error;
    auto writer = session::SessionWriter::create(root.path(), twoCameras(), error);
    ASSERT_TRUE(writer) << error;
    capture::CaptureStats stats;
    stats.frames = 30;
    stats.effective_fps = 30.01;
    writer->writeHealth(1, 5'000'000'000, stats, 123.45);
    writer->writeHealth(0, 5'000'000'001, stats, -1);
    const auto health = lines(writer->directory() / "capture.csv");
    ASSERT_EQ(health.size(), 3u);
    EXPECT_EQ(health[1], "5000000000,usb-1.3,30,0,0,0,30.01,0,0,123.5");
    EXPECT_EQ(health[2], "5000000001,usb-1.2,30,0,0,0,30.01,0,0,");
}

TEST(SessionId, SortsByTimeAndHasASuffix)
{
    const std::string id = session::newSessionId();
    ASSERT_EQ(id.size(), 21u);
    EXPECT_EQ(id[8], 'T');
    EXPECT_EQ(id[15], 'Z');
    EXPECT_EQ(id[16], '-');
}
