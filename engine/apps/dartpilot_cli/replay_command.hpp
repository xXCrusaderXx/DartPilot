#pragma once

// dartpilot replay: processes a recorded session offline (docs/replay-format.md, issue #9).
namespace dartpilot::cli
{
// argc and argv hold the arguments after "replay". Returns the process exit code.
int runReplay (int argc, char* argv[]);
}  // namespace dartpilot::cli
