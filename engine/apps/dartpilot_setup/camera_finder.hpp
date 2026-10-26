#pragma once

#include <QtQml/qqmlregistration.h>
#include <QObject>
#include <QVariantList>

namespace dartpilot::setup
{
// Lists the connected V4L2 cameras for QML, sorted by USB port: path, usbPort, name,
// and intrinsicsPath with hasIntrinsics for a stored intrinsic calibration, and intrinsicsWarning when it does not
// match the reference capture mode; hasBoardPlane and boardRmsMm for a stored board plane. number, label and the
// labels with the lens (lensChoice) or board state (boardChoice) are what the pages show for it.
class CameraFinder : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList cameras READ cameras NOTIFY camerasChanged)

   public:
    explicit CameraFinder (QObject* parent = nullptr);

    QVariantList cameras () const { return cameras_; }
    Q_INVOKABLE void refresh ();

   signals:
    void camerasChanged ();

   private:
    QVariantList cameras_;
};
}  // namespace dartpilot::setup
