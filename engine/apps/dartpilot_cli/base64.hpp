#pragma once

#include <cstdint>
#include <optional>
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

// Decodes standard base64; nothing for a character outside the alphabet. Whitespace is skipped.
inline std::optional<std::vector<std::uint8_t>> fromBase64 (const std::string& text)
{
    std::vector<std::uint8_t> out;
    out.reserve(text.size() / 4 * 3);
    std::uint32_t chunk = 0;
    int bits = 0;
    for(const char c : text)
    {
        int value;
        if(c >= 'A' && c <= 'Z')
        {
            value = c - 'A';
        }
        else if(c >= 'a' && c <= 'z')
        {
            value = c - 'a' + 26;
        }
        else if(c >= '0' && c <= '9')
        {
            value = c - '0' + 52;
        }
        else if(c == '+' || c == '-')
        {
            value = 62;
        }
        else if(c == '/' || c == '_')
        {
            value = 63;
        }
        else if(c == '=' || c == ' ' || c == '\n' || c == '\r')
        {
            continue;
        }
        else
        {
            return std::nullopt;
        }
        chunk = (chunk << 6) | static_cast<std::uint32_t>(value);
        bits += 6;
        if(bits >= 8)
        {
            bits -= 8;
            out.push_back(static_cast<std::uint8_t>((chunk >> bits) & 0xff));
        }
    }
    return out;
}
}  // namespace dartpilot::cli
