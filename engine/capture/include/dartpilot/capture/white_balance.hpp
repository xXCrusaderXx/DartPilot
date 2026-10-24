#pragma once

#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

// White balance per camera (ADR 0002): fixed, so that colours do not drift, and tuned to the user's light during setup,
// because every setup lights its board differently.
namespace dartpilot::capture
{
// Before the setup tuned a camera: the value measured with the reference LED ring
inline constexpr int kDefaultWhiteBalance_K = 3000;
// The range the reference cameras offer, in the steps the setup tries
inline constexpr int kMinWhiteBalance_K = 2800;
inline constexpr int kMaxWhiteBalance_K = 6400;
inline constexpr int kWhiteBalanceStep_K = 200;

// File in the calibration directory: white-balance-usb-<port>.yml
std::string whiteBalanceFileName (std::string_view usb_port);

// The temperature the setup chose, or the default if the camera was not tuned (or the file cannot be read)
int storedWhiteBalance (const std::string& path);

// Whether the board was found at each temperature tried, in rising order. The chosen temperature is the middle of the
// longest run of temperatures at which it was found, the one furthest from a colour that loses the board; nothing if
// it was found at none.
std::optional<int> chooseWhiteBalance (const std::vector<std::pair<int, bool>>& found_at_K);

bool saveWhiteBalance (const std::string& path, int white_balance_K, const std::vector<std::pair<int, bool>>& found_at_K);
}  // namespace dartpilot::capture
