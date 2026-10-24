#pragma once

#include <cstdint>
#include <optional>
#include <span>
#include <string>

// SHA-256 (FIPS 180-4), used to pin the calibration files a session refers to (docs/replay-format.md).
namespace dartpilot::session
{
// Lowercase hex digest of the bytes
std::string sha256Hex (std::span<const std::uint8_t> data);

// Lowercase hex digest of a file's contents, or nothing if it cannot be read
std::optional<std::string> sha256File (const std::string& path);
}  // namespace dartpilot::session
