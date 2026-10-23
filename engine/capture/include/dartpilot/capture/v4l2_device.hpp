#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

// Linux V4L2 cameras: discovery by USB port and access to camera controls.
namespace dartpilot::capture
{
struct CameraDevice
{
    // Stable path below /dev/v4l/by-path that stays the same as long as the camera keeps its USB port
    std::string path;
    // USB port chain, e.g. "2.4.3.1.2"
    std::string usb_port;
    // Name reported by the driver, e.g. "USB Camera: USB Camera"
    std::string name;
    // UVC metadata node of the same camera (video-index1), which carries the camera's PTS and SCR timestamps
    // (docs/adr/0005); empty if the camera has none
    std::string metadata_path;
};

// USB port chain from a /dev/v4l/by-path name, or an empty string if the name has none.
std::string usbPortFromPath (std::string_view path);

// Metadata node path that belongs to an image node path: "...-video-index0" becomes "...-video-index1".
// Empty if the path is not an image node. Does not check that the node exists.
std::string metadataPathFor (std::string_view image_path);

// Image nodes (video-index0) of all V4L2 cameras, sorted by USB port. Metadata nodes are left out.
std::vector<CameraDevice> findCameras ();

struct ControlRange
{
    std::int32_t minimum = 0;
    std::int32_t maximum = 0;
    std::int32_t step = 1;
    std::int32_t default_value = 0;
    // Set while another control overrides it, e.g. the exposure time under automatic exposure
    bool inactive = false;
};

// Reads and writes camera controls through their own file descriptor, so it works while another handle streams.
class CameraControls
{
   public:
    explicit CameraControls (const std::string& path);
    ~CameraControls ();
    CameraControls (const CameraControls&) = delete;
    CameraControls& operator=(const CameraControls&) = delete;

    bool isOpen () const { return fd_ >= 0; }
    // Control IDs are the V4L2_CID_* constants from <linux/videodev2.h>.
    std::optional<ControlRange> range (std::uint32_t id) const;
    std::optional<std::int32_t> get (std::uint32_t id) const;
    bool set (std::uint32_t id, std::int32_t value) const;

   private:
    int fd_ = -1;
};
}  // namespace dartpilot::capture
