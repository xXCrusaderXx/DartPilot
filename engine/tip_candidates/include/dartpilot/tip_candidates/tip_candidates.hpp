#pragma once

#include <string_view>

// Tip candidates per camera: pixel position, 2x2 covariance, confidence and shaft line.
namespace dartpilot::tip_candidates
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::tip_candidates
