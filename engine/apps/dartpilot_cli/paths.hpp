#pragma once

#include <array>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

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

// A random id of this engine installation, made once and kept in the data directory, so that apps recognise the engine
// when it is found again (#109): 26 characters of base32 from 128 random bits
inline std::string engineId ()
{
    const auto path = dataHome() / "engine-id";
    if(std::ifstream file(path); file)
    {
        std::string id;
        if(std::getline(file, id) && id.size() == 26)
        {
            return id;
        }
    }
    std::array<unsigned char, 16> bits{};
    std::ifstream("/dev/urandom", std::ios::binary).read(reinterpret_cast<char*>(bits.data()), bits.size());
    static constexpr char kAlphabet[] = "abcdefghijklmnopqrstuvwxyz234567";
    std::string id;
    unsigned buffer = 0;
    int held = 0;
    for(const unsigned char byte : bits)
    {
        buffer = (buffer << 8) | byte;
        held += 8;
        while(held >= 5)
        {
            id += kAlphabet[(buffer >> (held - 5)) & 31];
            held -= 5;
        }
    }
    id += kAlphabet[(buffer << (5 - held)) & 31];
    std::error_code error;
    std::filesystem::create_directories(dataHome(), error);
    std::ofstream(path) << id << "\n";
    return id;
}

// The reference mode with the white balance the setup tuned for this camera
inline capture::StreamSettings streamSettings (const capture::CameraDevice& device)
{
    capture::StreamSettings settings;
    settings.white_balance_K = capture::storedWhiteBalance((dataHome() / "calibration" / capture::whiteBalanceFileName(device.usb_port)).string());
    return settings;
}
}  // namespace dartpilot::cli
