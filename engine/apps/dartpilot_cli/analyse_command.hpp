#pragma once

// dartpilot analyse: setup diagnosis of a test recording (#137).
namespace dartpilot::cli
{
// argc and argv hold the arguments after "analyse". Returns the process exit code.
int runAnalyse (int argc, char* argv[]);
}  // namespace dartpilot::cli
