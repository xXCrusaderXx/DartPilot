#include "white_balance_sweep.hpp"

#include <linux/videodev2.h>

#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/capture/white_balance.hpp"
#include "dartpilot/geometry/board_detection.hpp"

namespace dartpilot::cli
{
bool sweepWhiteBalance (std::vector<SweepCamera>& cameras, const std::function<void(std::chrono::steady_clock::duration)>& wait,
                        const std::function<cv::Mat(std::size_t camera)>& grab, const std::function<void(int kelvin)>& progress,
                        const std::atomic<bool>& stop)
{
    for(int kelvin = capture::kMinWhiteBalance_K; kelvin <= capture::kMaxWhiteBalance_K; kelvin += capture::kWhiteBalanceStep_K)
    {
        if(stop)
        {
            return false;
        }
        for(const auto& camera : cameras)
        {
            // The automatic white balance may have been switched on since the camera started.
            const capture::CameraControls controls(camera.device_path);
            controls.set(V4L2_CID_AUTO_WHITE_BALANCE, 0);
            controls.set(V4L2_CID_WHITE_BALANCE_TEMPERATURE, kelvin);
        }
        wait(kWhiteBalanceSettle);
        for(std::size_t c = 0; c < cameras.size(); ++c)
        {
            const cv::Mat image = grab(c);
            cameras[c].found_at_K.emplace_back(kelvin, !image.empty() && geometry::detectBoard(image).has_value());
        }
        progress(kelvin);
    }
    return true;
}
}  // namespace dartpilot::cli
