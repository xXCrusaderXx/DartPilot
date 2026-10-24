#pragma once

// dartpilot serve: the engine API over WebSocket (docs/engine-api.md, ADR 0007).
namespace dartpilot::cli
{
// argc and argv hold the arguments after "serve". Returns the process exit code.
int runServe (int argc, char* argv[]);
}  // namespace dartpilot::cli
