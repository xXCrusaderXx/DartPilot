#include "camera_finder.hpp"

#include "dartpilot/capture/v4l2_device.hpp"

namespace dartpilot::setup
{
CameraFinder::CameraFinder (QObject* parent)
    : QObject(parent)
{
    refresh();
}

void CameraFinder::refresh ()
{
    cameras_.clear();
    for(const auto& camera : capture::findCameras())
    {
        cameras_.append(QVariantMap{{"path", QString::fromStdString(camera.path)},
                                    {"usbPort", QString::fromStdString(camera.usb_port)},
                                    {"name", QString::fromStdString(camera.name)}});
    }
    emit camerasChanged();
}
}  // namespace dartpilot::setup
