// Measurement probe for ADR 0005: streams a camera's video node (MJPG 1280x720) and its
// UVC metadata node together and prints CSV rows:
//   video,<seq>,<driver timestamp ns>
//   meta,<seq>,<host ns>,<USB SOF>,<header flags>,<PTS>,<SCR STC>,<SCR SOF>
// Build: g++ -O2 -std=c++20 -o uvc_timestamps tools/probes/uvc_timestamps.cpp
// Run:   ./uvc_timestamps /dev/v4l/by-path/...-video-index0 /dev/v4l/by-path/...-video-index1 300 > cam.csv
// Evaluate with: python -m dartpilot_tools.probes.uvc_timestamps cam.csv
#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#ifndef V4L2_META_FMT_UVC
#define V4L2_META_FMT_UVC v4l2_fourcc('U', 'V', 'C', 'H')
#endif

struct Stream
{
    int fd;
    unsigned type;
    void* map[8];
};

static int xioctl (int fd, unsigned long req, void* arg)
{
    int r;
    do r = ioctl(fd, req, arg);
    while(r == -1 && errno == EINTR);
    return r;
}

static void start (Stream& s, int nbuf)
{
    v4l2_requestbuffers rb{};
    rb.count = nbuf;
    rb.type = s.type;
    rb.memory = V4L2_MEMORY_MMAP;
    if(xioctl(s.fd, VIDIOC_REQBUFS, &rb))
    {
        std::perror("REQBUFS");
        std::exit(1);
    }
    for(unsigned i = 0; i < rb.count; ++i)
    {
        v4l2_buffer b{};
        b.type = s.type;
        b.memory = V4L2_MEMORY_MMAP;
        b.index = i;
        xioctl(s.fd, VIDIOC_QUERYBUF, &b);
        s.map[i] = mmap(nullptr, b.length, PROT_READ, MAP_SHARED, s.fd, b.m.offset);
        xioctl(s.fd, VIDIOC_QBUF, &b);
    }
    int t = s.type;
    xioctl(s.fd, VIDIOC_STREAMON, &t);
}

int main (int argc, char** argv)
{
    if(argc < 4)
    {
        std::fprintf(stderr, "usage: %s /dev/videoN /dev/videoM frames\n", argv[0]);
        return 2;
    }
    Stream v{open(argv[1], O_RDWR), V4L2_BUF_TYPE_VIDEO_CAPTURE, {}};
    Stream m{open(argv[2], O_RDWR), V4L2_BUF_TYPE_META_CAPTURE, {}};
    v4l2_format f{};
    f.type = v.type;
    f.fmt.pix.width = 1280;
    f.fmt.pix.height = 720;
    f.fmt.pix.pixelformat = V4L2_PIX_FMT_MJPEG;
    xioctl(v.fd, VIDIOC_S_FMT, &f);
    v4l2_format mf{};
    mf.type = m.type;
    mf.fmt.meta.dataformat = V4L2_META_FMT_UVC;
    if(xioctl(m.fd, VIDIOC_S_FMT, &mf))
    {
        std::perror("meta S_FMT");
        return 1;
    }
    start(m, 8);
    start(v, 4);
    std::printf("kind,seq,ts_or_host_ns,sof,hflags,pts,scr_stc,scr_sof\n");
    int frames = std::atoi(argv[3]), got = 0;
    while(got < frames)
    {
        pollfd p[2] = {{v.fd, POLLIN, 0}, {m.fd, POLLIN, 0}};
        poll(p, 2, 1000);
        if(p[1].revents & POLLIN)
        {
            v4l2_buffer b{};
            b.type = m.type;
            b.memory = V4L2_MEMORY_MMAP;
            if(!xioctl(m.fd, VIDIOC_DQBUF, &b))
            {
                const uint8_t* d = (const uint8_t*) m.map[b.index];
                size_t off = 0;
                while(off + 12 <= b.bytesused)
                {
                    uint64_t ns;
                    uint16_t sof;
                    std::memcpy(&ns, d + off, 8);
                    std::memcpy(&sof, d + off + 8, 2);
                    uint8_t len = d[off + 10], hf = d[off + 11];
                    const uint8_t* h = d + off + 12;
                    uint32_t pts = 0, stc = 0;
                    uint16_t ssof = 0;
                    size_t p2 = 0;
                    if(hf & 0x04)
                    {
                        std::memcpy(&pts, h, 4);
                        p2 = 4;
                    }
                    if(hf & 0x08)
                    {
                        std::memcpy(&stc, h + p2, 4);
                        std::memcpy(&ssof, h + p2 + 4, 2);
                    }
                    std::printf("meta,%u,%llu,%u,0x%02x,%u,%u,%u\n", b.sequence, (unsigned long long) ns, sof, hf, pts, stc, ssof & 0x7ff);
                    off += 10 + (len ? len : 2);
                }
                xioctl(m.fd, VIDIOC_QBUF, &b);
            }
        }
        if(p[0].revents & POLLIN)
        {
            v4l2_buffer b{};
            b.type = v.type;
            b.memory = V4L2_MEMORY_MMAP;
            if(!xioctl(v.fd, VIDIOC_DQBUF, &b))
            {
                long long ts = (long long) b.timestamp.tv_sec * 1000000000LL + b.timestamp.tv_usec * 1000LL;
                std::printf("video,%u,%lld,,,,,\n", b.sequence, ts);
                xioctl(v.fd, VIDIOC_QBUF, &b);
                ++got;
            }
        }
    }
}
