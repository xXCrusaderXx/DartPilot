#pragma once

// dartpilot focus: live sharpness display for turning a manually focused lens.
namespace dartpilot::cli
{
// argc and argv hold the arguments after "focus". Returns the process exit code.
int runFocus (int argc, char* argv[]);
}  // namespace dartpilot::cli
