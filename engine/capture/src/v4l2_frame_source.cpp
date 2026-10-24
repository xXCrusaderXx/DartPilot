#include "dartpilot/capture/v4l2_frame_source.hpp"

#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <ctime>
#include <map>
#include <span>
#include <vector>

#include "dartpilot/capture/uvc_metadata.hpp"

#ifndef V4L2_META_FMT_UVC
#define V4L2_META_FMT_UVC v4l2_fourcc('U', 'V', 'C', 'H')
#endif

namespace dartpilot::capture
{
namespace
{
// Metadata of frames whose image has not been dequeued yet; more than a few means the image node fell behind.
constexpr std::size_t kMaxPendingMetadata = 16;
// How long a dequeued image waits for its metadata before it falls back to the driver timestamp
constexpr std::int64_t kMetadataWaitNs = 10'000'000;

int retryIoctl (int fd, unsigned long request, void* arg)
{
    int result = 0;
    do
    {
        result = ::ioctl(fd, request, arg);
    } while(result < 0 && errno == EINTR);
    return result;
}

std::int64_t timevalNs (const timeval& tv) { return static_cast<std::int64_t>(tv.tv_sec) * 1'000'000'000 + tv.tv_usec * 1'000; }

// Per-frame summary of the UVC headers: the PTS and the mean of the frame's SCR samples, which lies on the
// camera-to-host clock line and is less noisy than a single sample.
struct FrameMetadata
{
    std::optional<std::uint32_t> pts;
    std::optional<std::uint32_t> scr_ticks;
    std::int64_t scr_host_ns = 0;
};

FrameMetadata summarise (const std::vector<UvcHeaderSample>& samples)
{
    FrameMetadata summary;
    summary.pts = framePts(samples);
    std::optional<std::uint32_t> first_ticks;
    double sum_ticks = 0, sum_host = 0;
    int count = 0;
    for(const auto& sample : samples)
    {
        if(!sample.scr_stc)
        {
            continue;
        }
        if(!first_ticks)
        {
            first_ticks = sample.scr_stc;
        }
        sum_ticks += static_cast<std::int32_t>(*sample.scr_stc - *first_ticks);
        sum_host += static_cast<double>(sample.host_ns - samples.front().host_ns);
        ++count;
    }
    if(count > 0)
    {
        summary.scr_ticks = *first_ticks + static_cast<std::uint32_t>(static_cast<std::int64_t>(sum_ticks / count));
        summary.scr_host_ns = samples.front().host_ns + static_cast<std::int64_t>(sum_host / count);
    }
    return summary;
}
}  // namespace

std::int64_t monotonicNowNs ()
{
    timespec now{};
    ::clock_gettime(CLOCK_MONOTONIC, &now);
    return static_cast<std::int64_t>(now.tv_sec) * 1'000'000'000 + now.tv_nsec;
}

struct V4l2FrameSource::Node
{
    int fd = -1;
    std::uint32_t type = 0;
    std::vector<std::span<std::uint8_t>> buffers;
    bool streaming = false;
    std::map<std::uint32_t, FrameMetadata> pending;

    ~Node () { close(); }

    void close ()
    {
        if(streaming)
        {
            int buffer_type = static_cast<int>(type);
            retryIoctl(fd, VIDIOC_STREAMOFF, &buffer_type);
            streaming = false;
        }
        for(auto& buffer : buffers)
        {
            ::munmap(buffer.data(), buffer.size());
        }
        buffers.clear();
        if(fd >= 0)
        {
            ::close(fd);
            fd = -1;
        }
    }

    bool open (const std::string& path, std::uint32_t buffer_type)
    {
        type = buffer_type;
        fd = ::open(path.c_str(), O_RDWR | O_NONBLOCK | O_CLOEXEC);
        return fd >= 0;
    }

    bool mapAndStream (int count)
    {
        v4l2_requestbuffers request{};
        request.count = static_cast<std::uint32_t>(count);
        request.type = type;
        request.memory = V4L2_MEMORY_MMAP;
        if(retryIoctl(fd, VIDIOC_REQBUFS, &request) != 0 || request.count == 0)
        {
            return false;
        }
        for(std::uint32_t index = 0; index < request.count; ++index)
        {
            v4l2_buffer buffer{};
            buffer.type = type;
            buffer.memory = V4L2_MEMORY_MMAP;
            buffer.index = index;
            if(retryIoctl(fd, VIDIOC_QUERYBUF, &buffer) != 0)
            {
                return false;
            }
            void* mapped = ::mmap(nullptr, buffer.length, PROT_READ, MAP_SHARED, fd, buffer.m.offset);
            if(mapped == MAP_FAILED)
            {
                return false;
            }
            buffers.emplace_back(static_cast<std::uint8_t*>(mapped), buffer.length);
            if(retryIoctl(fd, VIDIOC_QBUF, &buffer) != 0)
            {
                return false;
            }
        }
        int buffer_type = static_cast<int>(type);
        streaming = retryIoctl(fd, VIDIOC_STREAMON, &buffer_type) == 0;
        return streaming;
    }

    // Dequeues one buffer if one is ready; the caller hands it back with requeue().
    std::optional<v4l2_buffer> dequeue ()
    {
        v4l2_buffer buffer{};
        buffer.type = type;
        buffer.memory = V4L2_MEMORY_MMAP;
        if(retryIoctl(fd, VIDIOC_DQBUF, &buffer) != 0)
        {
            return std::nullopt;
        }
        return buffer;
    }

    void requeue (v4l2_buffer& buffer) { retryIoctl(fd, VIDIOC_QBUF, &buffer); }
};

V4l2FrameSource::V4l2FrameSource (CameraDevice camera, StreamSettings settings)
    : camera_(std::move(camera))
    , settings_(settings)
{
}

V4l2FrameSource::~V4l2FrameSource () { stop(); }

bool V4l2FrameSource::fail (const std::string& message)
{
    error_ = message + " (" + camera_.path + "): " + std::strerror(errno);
    stop();
    return false;
}

bool V4l2FrameSource::start ()
{
    stop();
    error_.clear();
    clock_ = ClockMapper();

    applyReferenceControls(camera_.path, settings_);

    image_ = std::make_unique<Node>();
    if(!image_->open(camera_.path, V4L2_BUF_TYPE_VIDEO_CAPTURE))
    {
        return fail("Cannot open image node");
    }
    v4l2_format format{};
    format.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    format.fmt.pix.width = static_cast<std::uint32_t>(settings_.width);
    format.fmt.pix.height = static_cast<std::uint32_t>(settings_.height);
    format.fmt.pix.pixelformat = V4L2_PIX_FMT_MJPEG;
    if(retryIoctl(image_->fd, VIDIOC_S_FMT, &format) != 0)
    {
        return fail("Cannot set MJPG format");
    }
    if(format.fmt.pix.pixelformat != V4L2_PIX_FMT_MJPEG || format.fmt.pix.width != static_cast<std::uint32_t>(settings_.width) ||
       format.fmt.pix.height != static_cast<std::uint32_t>(settings_.height))
    {
        errno = EINVAL;
        return fail("Camera does not offer MJPG " + std::to_string(settings_.width) + "x" + std::to_string(settings_.height));
    }
    v4l2_streamparm parameters{};
    parameters.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    parameters.parm.capture.timeperframe = {1, static_cast<std::uint32_t>(settings_.fps)};
    retryIoctl(image_->fd, VIDIOC_S_PARM, &parameters);

    // Without metadata the source still works, on driver timestamps only.
    if(!camera_.metadata_path.empty())
    {
        metadata_ = std::make_unique<Node>();
        v4l2_format metadata_format{};
        metadata_format.type = V4L2_BUF_TYPE_META_CAPTURE;
        metadata_format.fmt.meta.dataformat = V4L2_META_FMT_UVC;
        if(!metadata_->open(camera_.metadata_path, V4L2_BUF_TYPE_META_CAPTURE) || retryIoctl(metadata_->fd, VIDIOC_S_FMT, &metadata_format) != 0 ||
           !metadata_->mapAndStream(8))
        {
            metadata_.reset();
        }
    }
    if(!image_->mapAndStream(settings_.buffers))
    {
        return fail("Cannot start streaming");
    }
    return true;
}

void V4l2FrameSource::stop ()
{
    image_.reset();
    metadata_.reset();
}

void V4l2FrameSource::readMetadata ()
{
    if(!metadata_)
    {
        return;
    }
    while(auto buffer = metadata_->dequeue())
    {
        const auto& mapped = metadata_->buffers[buffer->index];
        const FrameMetadata summary = summarise(parseUvcMetadata(mapped.first(std::min<std::size_t>(buffer->bytesused, mapped.size()))));
        // QBUF rewrites the buffer struct, so the sequence is read before it.
        const std::uint32_t sequence = buffer->sequence;
        metadata_->requeue(*buffer);
        if(summary.scr_ticks)
        {
            clock_.addSample(*summary.scr_ticks, summary.scr_host_ns);
        }
        metadata_->pending[sequence] = summary;
        while(metadata_->pending.size() > kMaxPendingMetadata)
        {
            metadata_->pending.erase(metadata_->pending.begin());
        }
    }
}

std::optional<Frame> V4l2FrameSource::next (std::chrono::milliseconds timeout)
{
    if(!image_)
    {
        return std::nullopt;
    }
    const std::int64_t deadline_ns = monotonicNowNs() + std::chrono::nanoseconds(timeout).count();
    while(true)
    {
        readMetadata();
        if(auto buffer = image_->dequeue())
        {
            Frame frame;
            frame.arrival_ns = monotonicNowNs();
            frame.sequence = buffer->sequence;
            frame.driver_ns = timevalNs(buffer->timestamp);
            const auto& mapped = image_->buffers[buffer->index];
            frame.data.assign(mapped.data(), mapped.data() + std::min<std::size_t>(buffer->bytesused, mapped.size()));
            image_->requeue(*buffer);

            frame.exposure_ns = frame.driver_ns;
            if(metadata_)
            {
                // The metadata buffer of a frame often completes just after its image.
                const std::int64_t metadata_deadline_ns = monotonicNowNs() + kMetadataWaitNs;
                readMetadata();
                while(!metadata_->pending.contains(frame.sequence) && monotonicNowNs() < metadata_deadline_ns)
                {
                    pollfd metadata_fd{metadata_->fd, POLLIN, 0};
                    ::poll(&metadata_fd, 1, 1);
                    readMetadata();
                }
                const auto it = metadata_->pending.find(frame.sequence);
                if(it != metadata_->pending.end())
                {
                    frame.pts = it->second.pts;
                    if(it->second.scr_ticks)
                    {
                        frame.clock_sample = ClockSample{*it->second.scr_ticks, it->second.scr_host_ns};
                    }
                    metadata_->pending.erase(metadata_->pending.begin(), std::next(it));
                }
                if(frame.pts)
                {
                    if(const auto mapped_ns = clock_.toHost(*frame.pts))
                    {
                        frame.exposure_ns = *mapped_ns;
                        frame.timestamp_source = TimestampSource::UvcPts;
                    }
                }
            }
            return frame;
        }
        if(errno != EAGAIN)
        {
            fail("Lost the camera");
            return std::nullopt;
        }
        const std::int64_t remaining_ns = deadline_ns - monotonicNowNs();
        if(remaining_ns <= 0)
        {
            return std::nullopt;
        }
        pollfd fds[2] = {{image_->fd, POLLIN, 0}, {metadata_ ? metadata_->fd : -1, POLLIN, 0}};
        ::poll(fds, 2, static_cast<int>(remaining_ns / 1'000'000) + 1);
    }
}
}  // namespace dartpilot::capture
