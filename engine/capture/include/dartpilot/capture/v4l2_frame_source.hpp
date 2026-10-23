#pragma once

#include <memory>
#include <string>

#include "dartpilot/capture/clock_mapper.hpp"
#include "dartpilot/capture/frame.hpp"
#include "dartpilot/capture/v4l2_device.hpp"

namespace dartpilot::capture
{
// Streams a camera's image node and, if it has one, its UVC metadata node with V4L2 mmap buffers
// (docs/adr/0005). Applies the capture settings of docs/adr/0002 when it starts.
class V4l2FrameSource final : public FrameSource
{
   public:
    V4l2FrameSource (CameraDevice camera, StreamSettings settings = {});
    ~V4l2FrameSource () override;

    bool start () override;
    void stop () override;
    std::optional<Frame> next (std::chrono::milliseconds timeout) override;
    std::string error () const override { return error_; }

    const CameraDevice& camera () const { return camera_; }
    // Fitted camera clock rate, 0 while there is no clock mapping
    double cameraClockHz () const { return clock_.clockHz(); }

   private:
    struct Node;

    bool fail (const std::string& message);
    void readMetadata ();

    CameraDevice camera_;
    StreamSettings settings_;
    std::unique_ptr<Node> image_;
    std::unique_ptr<Node> metadata_;
    ClockMapper clock_;
    std::string error_;
};
}  // namespace dartpilot::capture
