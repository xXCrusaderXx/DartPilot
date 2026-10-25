#pragma once

#include <string>
#include <vector>

// The Android spike (#104): streams the cameras behind the given USB file descriptors as MJPG 1280x720 at 30 fps for a
// while and measures them. The descriptors come from UsbManager.openDevice(...).getFileDescriptor() and stay open.
namespace dartpilot::android_spike
{
// Blocks for `seconds`; returns the measurements as JSON (see the spike app and docs/android.md)
std::string run (const std::vector<int>& fds, int seconds);
}  // namespace dartpilot::android_spike
