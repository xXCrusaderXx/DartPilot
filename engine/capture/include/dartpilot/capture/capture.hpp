#pragma once

#include <string_view>

// Camera capture: one thread and a bounded ring buffer per camera, frame IDs, capture and arrival timestamps, drop counters.
namespace dartpilot::capture
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::capture
