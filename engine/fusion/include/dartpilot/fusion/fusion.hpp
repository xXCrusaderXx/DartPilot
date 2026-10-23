#pragma once

#include <string_view>

// Temporal association of candidates, robust uncertainty-weighted estimation and abstention.
namespace dartpilot::fusion
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::fusion
