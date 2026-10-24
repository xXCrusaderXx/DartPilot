#include "camera_finder.hpp"

#include <QFileInfo>

#include "calibration_paths.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/intrinsics.hpp"

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
        const QString path = intrinsicsPath(usb_port);
        QString warning;
        bool has_intrinsics = false;
        if(QFileInfo::exists(path))
        {
            const auto stored = geometry::loadIntrinsics(path.toStdString());
            has_intrinsics = stored.has_value();
            if(!stored)
            {
                warning = "The stored calibration cannot be read.";
            }
            else
            {
                for(const auto& mismatch : geometry::settingsMismatches(
                        *stored, {camera.usb_port, cv::Size(kReferenceWidth_px, kReferenceHeight_px), kReferencePixelFormat}))
                {
                    QString sentence = QString::fromStdString(mismatch);
                    sentence[0] = sentence[0].toUpper();
                    warning += sentence + ". ";
                }
            }
        }
        const auto board = geometry::loadBoardPlane(boardPlanePath(usb_port).toStdString());
        cameras_.append(QVariantMap{{"path", QString::fromStdString(camera.path)},
                                    {"hasBoardPlane", board.has_value()},
                                    {"boardRmsMm", board ? board->fit.rms_mm : 0.0},
                                    {"usbPort", usb_port},
                                    {"intrinsicsPath", path},
                                    {"hasIntrinsics", has_intrinsics},
                                    {"intrinsicsWarning", warning.trimmed()},
                                    {"name", QString::fromStdString(camera.name)}});
    }
    emit camerasChanged();
}
}  // namespace dartpilot::setup
