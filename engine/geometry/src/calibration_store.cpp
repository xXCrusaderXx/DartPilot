#include "dartpilot/geometry/calibration_store.hpp"

#include <algorithm>

#include "dartpilot/geometry/board_plane.hpp"

namespace dartpilot::geometry
{
std::string intrinsicsFileName (std::string_view usb_port) { return "intrinsics-usb-" + std::string(usb_port) + ".yml"; }

std::string boardPlaneFileName (std::string_view usb_port) { return "board-usb-" + std::string(usb_port) + ".yml"; }

std::optional<StoredIntrinsics> referenceIntrinsics (const std::filesystem::path& directory, const std::string& usb_port, const ReferenceMode& mode)
{
    auto stored = loadIntrinsics((directory / intrinsicsFileName(usb_port)).string());
    if(!stored || stored->calibration.image_size_px != mode.image_size_px || stored->info.pixel_format != mode.pixel_format)
    {
        return std::nullopt;
    }
    return stored;
}

std::vector<RefinementInput> refinementInputs (const std::filesystem::path& directory, const std::vector<SetupCamera>& cameras,
                                               const ReferenceMode& mode)
{
    // Lenses of all cameras in the order of the list, so the model prior is chosen deterministically
    std::vector<std::pair<const SetupCamera*, StoredIntrinsics>> lenses;
    for(const auto& camera : cameras)
    {
        if(auto stored = referenceIntrinsics(directory, camera.usb_port, mode))
        {
            lenses.emplace_back(&camera, std::move(*stored));
        }
    }
    std::vector<RefinementInput> inputs;
    for(const auto& camera : cameras)
    {
        const auto plane = loadBoardPlane((directory / boardPlaneFileName(camera.usb_port)).string());
        if(!plane)
        {
            continue;
        }
        RefinementInput input;
        input.usb_port = camera.usb_port;
        input.correspondences = plane->correspondences;
        input.board_plane_created = plane->created;
        input.prior = boardOnlyPrior(mode.image_size_px);
        const auto own = std::find_if(lenses.begin(), lenses.end(), [&] (const auto& lens) { return lens.first->usb_port == camera.usb_port; });
        const auto same_model =
            std::find_if(lenses.begin(), lenses.end(), [&] (const auto& lens) { return lens.second.info.camera_name == camera.name; });
        if(own != lenses.end())
        {
            input.prior = priorFromCalibration(own->second.calibration, IntrinsicsSource::OwnCalibration);
            input.intrinsics_created = own->second.info.created;
        }
        else if(same_model != lenses.end())
        {
            input.prior = priorFromCalibration(same_model->second.calibration, IntrinsicsSource::ModelPrior);
            input.intrinsics_created = same_model->second.info.created;
        }
        inputs.push_back(std::move(input));
    }
    return inputs;
}

bool refinementStale (const StoredExtrinsics& stored, const std::vector<RefinementInput>& current)
{
    if(current.size() != stored.inputs.size())
    {
        return true;
    }
    for(std::size_t i = 0; i < current.size(); ++i)
    {
        const auto& now = current[i];
        const auto& then = stored.inputs[i];
        if(now.usb_port != then.usb_port || now.board_plane_created != then.board_plane_created ||
           now.intrinsics_created != then.intrinsics_created || now.prior.source != then.prior.source)
        {
            return true;
        }
    }
    return false;
}
}  // namespace dartpilot::geometry
