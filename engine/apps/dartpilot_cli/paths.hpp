#pragma once

#include <cstdlib>
#include <filesystem>

#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/capture/white_balance.hpp"

namespace dartpilot::cli
{
// ~/.local/share/dartpilot, or $XDG_DATA_HOME/dartpilot: sessions and calibrations live here.
inline std::filesystem::path dataHome ()
{
    if(const char* xdg = std::getenv("XDG_DATA_HOME"); xdg && *xdg)
    {
        return std::filesystem::path(xdg) / "dartpilot";
    }
    const char* home = std::getenv("HOME");
    return std::filesystem::path(home ? home : ".") / ".local/share/dartpilot";
}

// The reference mode with the white balance the setup tuned for this camera
inline capture::StreamSettings streamSettings (const capture::CameraDevice& device)
{
    capture::StreamSettings settings;
    settings.white_balance_K = capture::storedWhiteBalance((dataHome() / "calibration" / capture::whiteBalanceFileName(device.usb_port)).string());
    return settings;
}
}  // namespace dartpilot::cli
