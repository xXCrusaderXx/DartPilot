#pragma once

// dartpilot capture-check: streams all cameras for a while and reports frame rate, losses and timestamp quality.
namespace dartpilot::cli
{
// argc and argv hold the arguments after "capture-check". Returns the process exit code.
int runCaptureCheck (int argc, char* argv[]);
}  // namespace dartpilot::cli
