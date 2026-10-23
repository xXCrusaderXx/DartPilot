#pragma once

#include <string_view>

// Reproducible offline evaluation of recorded throws.
namespace dartpilot::replay
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::replay
