#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace dartpilot::cli
{
// Standard base64 with padding, for images sent inside JSON messages
inline std::string base64 (const std::vector<std::uint8_t>& data)
{
    static constexpr char kAlphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve((data.size() + 2) / 3 * 4);
    for(std::size_t i = 0; i < data.size(); i += 3)
    {
        const std::uint32_t chunk =
            (static_cast<std::uint32_t>(data[i]) << 16) | (i + 1 < data.size() ? data[i + 1] << 8 : 0) | (i + 2 < data.size() ? data[i + 2] : 0);
        out += kAlphabet[(chunk >> 18) & 63];
        out += kAlphabet[(chunk >> 12) & 63];
        out += i + 1 < data.size() ? kAlphabet[(chunk >> 6) & 63] : '=';
        out += i + 2 < data.size() ? kAlphabet[chunk & 63] : '=';
    }
    return out;
}
}  // namespace dartpilot::cli
