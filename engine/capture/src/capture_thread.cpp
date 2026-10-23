#include "dartpilot/capture/capture_thread.hpp"

namespace dartpilot::capture
{
namespace
{
constexpr std::chrono::milliseconds kPollTimeout{100};
// Frame-rate window: long enough to average the frame interval, short enough to show a drop quickly
constexpr std::int64_t kRateWindowNs = 2'000'000'000;
}  // namespace

CaptureThread::CaptureThread (std::unique_ptr<FrameSource> source, std::size_t ring_capacity)
    : source_(std::move(source))
    , frames_(ring_capacity)
{
}

CaptureThread::~CaptureThread () { stop(); }

bool CaptureThread::start ()
{
    stop();
    if(!source_->start())
    {
        std::lock_guard lock(mutex_);
        stats_.error = source_->error();
        return false;
    }
    {
        std::lock_guard lock(mutex_);
        stats_ = {};
        stats_.running = true;
        last_sequence_.reset();
        rate_window_frames_ = 0;
    }
    stop_requested_ = false;
    thread_ = std::thread([this] { run(); });
    return true;
}

void CaptureThread::stop ()
{
    stop_requested_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
    source_->stop();
    std::lock_guard lock(mutex_);
    stats_.running = false;
}

void CaptureThread::run ()
{
    while(!stop_requested_)
    {
        auto frame = source_->next(kPollTimeout);
        if(!frame)
        {
            const std::string error = source_->error();
            if(!error.empty())
            {
                std::lock_guard lock(mutex_);
                stats_.error = error;
                stats_.running = false;
                return;
            }
            continue;
        }
        count(*frame);
        frames_.push(std::move(*frame));
    }
}

void CaptureThread::count (const Frame& frame)
{
    std::lock_guard lock(mutex_);
    ++stats_.frames;
    if(last_sequence_ && frame.sequence > *last_sequence_ + 1)
    {
        stats_.lost_frames += frame.sequence - *last_sequence_ - 1;
    }
    last_sequence_ = frame.sequence;
    if(frame.timestamp_source == TimestampSource::UvcPts)
    {
        ++stats_.pts_frames;
    }
    stats_.latency_ms = static_cast<double>(frame.arrival_ns - frame.exposure_ns) / 1e6;

    if(rate_window_frames_ == 0)
    {
        rate_window_begin_ns_ = frame.exposure_ns;
    }
    ++rate_window_frames_;
    const std::int64_t span_ns = frame.exposure_ns - rate_window_begin_ns_;
    if(span_ns >= kRateWindowNs)
    {
        stats_.effective_fps = static_cast<double>(rate_window_frames_ - 1) * 1e9 / static_cast<double>(span_ns);
        rate_window_begin_ns_ = frame.exposure_ns;
        rate_window_frames_ = 1;
    }
}

CaptureStats CaptureThread::stats () const
{
    std::lock_guard lock(mutex_);
    CaptureStats copy = stats_;
    copy.overflow_drops = frames_.dropped();
    copy.queued = frames_.size();
    return copy;
}
}  // namespace dartpilot::capture
