#pragma once

#include <string_view>

// Throw events: time window, baseline frames before the throw and difference masks.
namespace dartpilot::event_detection
{
// Module name, used by the CLI and the smoke test until the module has real entry points
std::string_view moduleName ();
}  // namespace dartpilot::event_detection
