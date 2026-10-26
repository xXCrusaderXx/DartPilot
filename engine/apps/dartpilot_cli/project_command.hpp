#pragma once

// dartpilot project: where board points lie in each refined camera's image, for tools that compare candidates with
// ground truth in pixels (#26).
namespace dartpilot::cli
{
// argc and argv hold the arguments after "project". Returns the process exit code.
int runProject (int argc, char* argv[]);
}  // namespace dartpilot::cli
