#pragma once

#include <cstdint>
#include <optional>
#include <span>
#include <vector>

// UVC payload header metadata as delivered by the uvcvideo metadata node (format "UVCH", docs/adr/0005).
namespace dartpilot::capture
{
struct UvcHeaderSample
{
    // Host CLOCK_MONOTONIC time when the payload with this header arrived
    std::int64_t host_ns = 0;
    // USB frame number at that moment
    std::uint16_t usb_sof = 0;
    std::uint8_t header_flags = 0;
    // Camera clock (STC) at the start of exposure, if the header carries a PTS
    std::optional<std::uint32_t> pts;
    // Camera clock sample, if the header carries an SCR, and the USB frame number it was taken in
    std::optional<std::uint32_t> scr_stc;
    std::uint16_t scr_sof = 0;
};

// Splits one metadata buffer into its header samples. A truncated block at the end is ignored.
std::vector<UvcHeaderSample> parseUvcMetadata (std::span<const std::uint8_t> buffer);

// First non-zero PTS among the header samples of one frame.
std::optional<std::uint32_t> framePts (const std::vector<UvcHeaderSample>& samples);
}  // namespace dartpilot::capture
