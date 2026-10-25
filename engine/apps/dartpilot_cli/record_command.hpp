#pragma once

// dartpilot record: records all cameras into a session directory (docs/replay-format.md, issue #6).
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/session/session_writer.hpp"

namespace dartpilot::cli
{
// How a camera is recorded in a session: id, port, mode, controls and the calibrations it was recorded with
session::CameraInfo recordedCamera (const capture::CameraDevice& device, const capture::StreamSettings& stream);

// argc and argv hold the arguments after "record". Returns the process exit code.
int runRecord (int argc, char* argv[]);
}  // namespace dartpilot::cli
