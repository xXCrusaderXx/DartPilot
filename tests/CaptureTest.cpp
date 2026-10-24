#include <gtest/gtest.h>

#include <chrono>
#include <cstring>
#include <deque>
#include <filesystem>
#include <random>
#include <string>
#include <thread>
#include <vector>

#include "dartpilot/capture/capture_thread.hpp"
#include "dartpilot/capture/clock_mapper.hpp"
#include "dartpilot/capture/ring_buffer.hpp"
#include "dartpilot/capture/uvc_metadata.hpp"
#include "dartpilot/capture/white_balance.hpp"

using namespace dartpilot::capture;
using namespace std::chrono_literals;

namespace
{
// One block of the uvcvideo metadata format: u64 host ns, u16 SOF, header (length, flags, PTS, SCR).
void appendBlock (std::vector<std::uint8_t>& buffer, std::uint64_t host_ns, std::uint32_t pts, std::uint32_t stc, std::uint16_t sof)
{
    const std::size_t at = buffer.size();
    buffer.resize(at + 10 + 12);
    std::memcpy(buffer.data() + at, &host_ns, 8);
    std::memcpy(buffer.data() + at + 8, &sof, 2);
    buffer[at + 10] = 12;
    buffer[at + 11] = 0x8c;
    std::memcpy(buffer.data() + at + 12, &pts, 4);
    std::memcpy(buffer.data() + at + 16, &stc, 4);
    std::memcpy(buffer.data() + at + 20, &sof, 2);
}

class FakeSource final : public FrameSource
{
   public:
    explicit FakeSource (std::vector<std::uint32_t> sequences)
        : sequences_(sequences.begin(), sequences.end())
    {
    }
    bool start () override { return true; }
    void stop () override {}
    std::optional<Frame> next (std::chrono::milliseconds) override
    {
        if(sequences_.empty())
        {
            std::this_thread::sleep_for(1ms);
            return std::nullopt;
        }
        Frame frame;
        frame.sequence = sequences_.front();
        sequences_.pop_front();
        frame.exposure_ns = static_cast<std::int64_t>(frame.sequence) * 33'333'333;
        frame.arrival_ns = frame.exposure_ns + 35'000'000;
        frame.timestamp_source = frame.sequence % 2 == 0 ? TimestampSource::UvcPts : TimestampSource::Driver;
        return frame;
    }
    std::string error () const override { return {}; }

   private:
    std::deque<std::uint32_t> sequences_;
};

CaptureStats waitForFrames (const CaptureThread& thread, std::uint64_t frames)
{
    for(int i = 0; i < 1000 && thread.stats().frames < frames; ++i)
    {
        std::this_thread::sleep_for(1ms);
    }
    return thread.stats();
}
}  // namespace

TEST(UvcMetadata, ParsesPtsAndScr)
{
    std::vector<std::uint8_t> buffer;
    appendBlock(buffer, 1000, 0, 4039, 768);
    appendBlock(buffer, 2000, 3'200'005, 5914, 769);
    const auto samples = parseUvcMetadata(buffer);
    ASSERT_EQ(samples.size(), 2u);
    EXPECT_EQ(samples[1].host_ns, 2000);
    EXPECT_EQ(samples[1].usb_sof, 769);
    EXPECT_EQ(*samples[1].pts, 3'200'005u);
    EXPECT_EQ(*samples[1].scr_stc, 5914u);
    EXPECT_EQ(samples[1].scr_sof, 769);
    EXPECT_EQ(*framePts(samples), 3'200'005u);
}

TEST(UvcMetadata, IgnoresTruncatedBlock)
{
    std::vector<std::uint8_t> buffer;
    appendBlock(buffer, 1000, 7, 8, 9);
    buffer.resize(buffer.size() + 5, 0x0c);
    EXPECT_EQ(parseUvcMetadata(buffer).size(), 1u);
}

TEST(ClockMapper, MapsCameraTicksAcrossWrap)
{
    // 15 MHz camera clock that wraps during the window, host clock with an offset
    ClockMapper clock(100, 10);
    const std::uint64_t start_ticks = (1ull << 32) - 1'000'000;
    for(int i = 0; i < 50; ++i)
    {
        const std::uint64_t ticks = start_ticks + static_cast<std::uint64_t>(i) * 500'000;
        clock.addSample(static_cast<std::uint32_t>(ticks), 7'000'000'000 + static_cast<std::int64_t>(i) * 33'333'333);
    }
    EXPECT_NEAR(clock.clockHz(), 15e6, 1.0);
    const std::uint64_t probe = start_ticks + 49ull * 500'000 + 250'000;
    EXPECT_NEAR(static_cast<double>(*clock.toHost(static_cast<std::uint32_t>(probe))), 7'000'000'000 + 49 * 33'333'333 + 16'666'667, 2.0);
}

TEST(ClockMapper, NoMappingWithTooFewSamples)
{
    ClockMapper clock(100, 10);
    clock.addSample(1000, 1000);
    EXPECT_FALSE(clock.toHost(2000));
    EXPECT_EQ(clock.clockHz(), 0.0);
}

TEST(RingBuffer, DropsOldestWhenFull)
{
    RingBuffer<int> buffer(2);
    EXPECT_FALSE(buffer.push(1));
    EXPECT_FALSE(buffer.push(2));
    EXPECT_TRUE(buffer.push(3));
    EXPECT_EQ(buffer.dropped(), 1u);
    EXPECT_EQ(*buffer.tryPop(), 2);
    EXPECT_EQ(*buffer.pop(10ms), 3);
    EXPECT_FALSE(buffer.pop(1ms));
}

TEST(CaptureThread, CountsLostFramesFromSequenceGaps)
{
    CaptureThread thread(std::make_unique<FakeSource>(std::vector<std::uint32_t>{1, 2, 3, 6, 7, 10}), 16);
    ASSERT_TRUE(thread.start());
    const CaptureStats stats = waitForFrames(thread, 6);
    thread.stop();
    EXPECT_EQ(stats.frames, 6u);
    EXPECT_EQ(stats.lost_frames, 4u);
    EXPECT_EQ(stats.pts_frames, 3u);
    EXPECT_NEAR(stats.latency_ms, 35.0, 1e-9);
    EXPECT_EQ(thread.frames().size(), 6u);
}

TEST(CaptureThread, RingBufferOverflowIsCounted)
{
    std::vector<std::uint32_t> sequences;
    for(std::uint32_t i = 1; i <= 100; ++i)
    {
        sequences.push_back(i);
    }
    CaptureThread thread(std::make_unique<FakeSource>(sequences), 4);
    ASSERT_TRUE(thread.start());
    const CaptureStats stats = waitForFrames(thread, 100);
    thread.stop();
    EXPECT_EQ(stats.frames, 100u);
    EXPECT_EQ(stats.overflow_drops, 96u);
    EXPECT_EQ(stats.lost_frames, 0u);
    // The newest frames survive.
    EXPECT_EQ(thread.frames().tryPop()->sequence, 97u);
    // 2 s of exposure times at 30 fps give the effective rate.
    EXPECT_NEAR(stats.effective_fps, 30.0, 0.01);
}

TEST(WhiteBalance, ChoosesTheMiddleOfTheLongestRunWithTheBoard)
{
    EXPECT_FALSE(chooseWhiteBalance({{2800, false}, {3000, false}}));
    // Found from 2800 to 3200 K, as with the reference LED ring, and once by chance further up
    EXPECT_EQ(chooseWhiteBalance({{2800, true}, {3000, true}, {3200, true}, {3400, false}, {4400, true}, {4600, false}}), 3000);
    // An even run is rounded down to a temperature that was tried
    EXPECT_EQ(chooseWhiteBalance({{3600, true}, {3800, true}, {4000, true}, {4200, true}}), 3800);
}

TEST(WhiteBalance, StoresTheChoiceAndFallsBackToTheDefault)
{
    const auto path = (std::filesystem::temp_directory_path() / ("dartpilot-wb-" + std::to_string(std::random_device{}()) + ".yml")).string();
    EXPECT_EQ(storedWhiteBalance(path), kDefaultWhiteBalance_K);
    ASSERT_TRUE(saveWhiteBalance(path, 4200, {{4000, true}, {4200, true}, {4400, true}}));
    EXPECT_EQ(storedWhiteBalance(path), 4200);
    std::filesystem::remove(path);
}
