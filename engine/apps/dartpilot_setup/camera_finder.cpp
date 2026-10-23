#include "camera_finder.hpp"

#include <QFileInfo>

#include "calibration_paths.hpp"
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
        const QString usb_port = QString::fromStdString(camera.usb_port);
        cameras_.append(QVariantMap{{"path", QString::fromStdString(camera.path)},
                                    {"usbPort", usb_port},
                                    {"intrinsicsPath", intrinsicsPath(usb_port)},
                                    {"hasIntrinsics", QFileInfo::exists(intrinsicsPath(usb_port))},
                                    {"name", QString::fromStdString(camera.name)}});
    }
    emit camerasChanged();
}
}  // namespace dartpilot::setup
