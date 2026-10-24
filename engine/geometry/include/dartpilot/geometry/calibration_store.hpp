#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/intrinsics.hpp"

// The calibration files of a setup in one directory (~/.local/share/dartpilot/calibration), shared by the setup GUI and
// the engine API: which files belong to a camera, and the inputs of the joint refinement from them.
namespace dartpilot::geometry
{
// Calibrations belong to the USB port, because all reference cameras report the same serial number.
std::string intrinsicsFileName (std::string_view usb_port);
std::string boardPlaneFileName (std::string_view usb_port);
inline constexpr const char* kExtrinsicsFileName = "extrinsics.yml";

// The capture mode stored calibrations must have been made in (docs/adr/0002)
struct ReferenceMode
{
    cv::Size image_size_px{1280, 720};
    std::string pixel_format = "MJPG 1280x720 30fps";
};

struct SetupCamera
{
    std::string usb_port;
    // The camera's name, so that a camera without its own lens calibration can borrow one of the same model
    std::string name;
};

// The stored lens calibration of a camera, if it was made in the reference mode
std::optional<StoredIntrinsics> referenceIntrinsics (const std::filesystem::path& directory, const std::string& usb_port, const ReferenceMode& mode);

// One input per camera with a stored board plane, in the order of the cameras: its board points and the lens prior
// from its own calibration, else from one of the same model, else from the board alone.
std::vector<RefinementInput> refinementInputs (const std::filesystem::path& directory, const std::vector<SetupCamera>& cameras,
                                               const ReferenceMode& mode);

// Whether the stored refinement was made from other inputs than the current ones (a board measured or a lens
// calibrated since)
bool refinementStale (const StoredExtrinsics& stored, const std::vector<RefinementInput>& current);
}  // namespace dartpilot::geometry
