#pragma once

#include <string_view>

// Board plane, ray-plane projection, triangulation and reprojection error.
namespace dartpilot::geometry
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::geometry
