#pragma once

// dartpilot record: records all cameras into a session directory (docs/replay-format.md, issue #6).
namespace dartpilot::cli
{
// argc and argv hold the arguments after "record". Returns the process exit code.
int runRecord (int argc, char* argv[]);
}  // namespace dartpilot::cli
