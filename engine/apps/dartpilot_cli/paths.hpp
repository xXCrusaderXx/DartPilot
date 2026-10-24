#pragma once

#include <cstdlib>
#include <filesystem>

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
}  // namespace dartpilot::cli
