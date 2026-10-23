#pragma once

#include <string_view>

// Deterministic mapping from a board point in mm to sector and ring. No image processing and no dependency on other modules.
namespace dartpilot::scoring
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::scoring
