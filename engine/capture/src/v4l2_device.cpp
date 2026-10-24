#include "dartpilot/capture/v4l2_device.hpp"

#include <fcntl.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <filesystem>
#include <set>
#include <system_error>

namespace dartpilot::capture
{
namespace
{
constexpr std::string_view kByPathDir = "/dev/v4l/by-path";
constexpr std::string_view kImageNodeSuffix = "-video-index0";
constexpr std::string_view kMetadataNodeSuffix = "-video-index1";

int retryIoctl (int fd, unsigned long request, void* arg)
{
    int result = 0;
    do
    {
        result = ::ioctl(fd, request, arg);
    } while(result < 0 && errno == EINTR);
    return result;
}

std::string driverName (const std::string& path)
{
    const int fd = ::open(path.c_str(), O_RDWR | O_NONBLOCK | O_CLOEXEC);
    if(fd < 0)
    {
        return {};
    }
    v4l2_capability capability{};
    std::string name;
    if(retryIoctl(fd, VIDIOC_QUERYCAP, &capability) == 0)
    {
        name = reinterpret_cast<const char*>(capability.card);
    }
    ::close(fd);
    return name;
}
}  // namespace

std::string usbPortFromPath (std::string_view path)
{
    // by-path names look like "pci-0000:0e:00.4-usb-0:2.4.3.1.2:1.0-video-index0"
    for(const std::string_view marker : {std::string_view("-usb-"), std::string_view("-usbv2-"), std::string_view("-usbv3-")})
    {
        const auto marker_pos = path.find(marker);
        if(marker_pos == std::string_view::npos)
        {
            continue;
        }
        const auto port_begin = path.find(':', marker_pos);
        if(port_begin == std::string_view::npos)
        {
            return {};
        }
        const auto port_end = path.find(':', port_begin + 1);
        if(port_end == std::string_view::npos)
        {
            return {};
        }
        return std::string(path.substr(port_begin + 1, port_end - port_begin - 1));
    }
    return {};
}

std::string metadataPathFor (std::string_view image_path)
{
    if(image_path.size() < kImageNodeSuffix.size() || image_path.substr(image_path.size() - kImageNodeSuffix.size()) != kImageNodeSuffix)
    {
        return {};
    }
    return std::string(image_path.substr(0, image_path.size() - kImageNodeSuffix.size())) + std::string(kMetadataNodeSuffix);
}

std::vector<CameraDevice> findCameras ()
{
    std::vector<CameraDevice> cameras;
    std::error_code error;
    std::filesystem::directory_iterator it(kByPathDir, error);
    if(error)
    {
        return cameras;
    }
    // udev creates a "usb-" and a "usbv2-" link for the same node; each node is listed once.
    std::set<std::filesystem::path> seen_nodes;
    std::vector<std::filesystem::path> links;
    for(const auto& entry : it)
    {
        const std::string name = entry.path().filename().string();
        if(name.size() >= kImageNodeSuffix.size() &&
           name.compare(name.size() - kImageNodeSuffix.size(), kImageNodeSuffix.size(), kImageNodeSuffix) == 0)
        {
            links.push_back(entry.path());
        }
    }
    // "usb-0:" sorts before "usbv2-0:", so the plain name wins.
    std::sort(links.begin(), links.end());
    for(const auto& link : links)
    {
        const auto node = std::filesystem::canonical(link, error);
        if(error || !seen_nodes.insert(node).second)
        {
            continue;
        }
        std::string metadata_path = metadataPathFor(link.string());
        if(!std::filesystem::exists(metadata_path, error))
        {
            metadata_path.clear();
        }
        cameras.push_back({link.string(), usbPortFromPath(link.filename().string()), driverName(link.string()), metadata_path});
    }
    std::sort(cameras.begin(), cameras.end(), [] (const CameraDevice& a, const CameraDevice& b) { return a.usb_port < b.usb_port; });
    return cameras;
}

CameraControls::CameraControls (const std::string& path)
    : fd_(::open(path.c_str(), O_RDWR | O_NONBLOCK | O_CLOEXEC))
{
}

CameraControls::~CameraControls ()
{
    if(fd_ >= 0)
    {
        ::close(fd_);
    }
}

std::optional<ControlRange> CameraControls::range (std::uint32_t id) const
{
    v4l2_queryctrl query{};
    query.id = id;
    if(fd_ < 0 || retryIoctl(fd_, VIDIOC_QUERYCTRL, &query) != 0 || (query.flags & V4L2_CTRL_FLAG_DISABLED) != 0)
    {
        return std::nullopt;
    }
    return ControlRange{query.minimum, query.maximum, query.step, query.default_value, (query.flags & V4L2_CTRL_FLAG_INACTIVE) != 0};
}

std::optional<std::int32_t> CameraControls::get (std::uint32_t id) const
{
    v4l2_control control{};
    control.id = id;
    if(fd_ < 0 || retryIoctl(fd_, VIDIOC_G_CTRL, &control) != 0)
    {
        return std::nullopt;
    }
    return control.value;
}

bool CameraControls::set (std::uint32_t id, std::int32_t value) const
{
    v4l2_control control{};
    control.id = id;
    control.value = value;
    return fd_ >= 0 && retryIoctl(fd_, VIDIOC_S_CTRL, &control) == 0;
}
void applyReferenceControls (const std::string& path, const StreamSettings& settings)
{
    const CameraControls controls(path);
    controls.set(V4L2_CID_EXPOSURE_AUTO, V4L2_EXPOSURE_APERTURE_PRIORITY);
    controls.set(V4L2_CID_EXPOSURE_AUTO_PRIORITY, 0);
    controls.set(V4L2_CID_POWER_LINE_FREQUENCY, V4L2_CID_POWER_LINE_FREQUENCY_50HZ);
    // The temperature is only accepted while the automatic white balance is off.
    controls.set(V4L2_CID_AUTO_WHITE_BALANCE, settings.white_balance_K > 0 ? 0 : 1);
    if(settings.white_balance_K > 0)
    {
        controls.set(V4L2_CID_WHITE_BALANCE_TEMPERATURE, settings.white_balance_K);
    }
}
}  // namespace dartpilot::capture
