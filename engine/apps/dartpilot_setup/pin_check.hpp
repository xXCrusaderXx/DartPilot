#pragma once

#include <map>
#include <optional>

#include <QtQml/qqmlregistration.h>
#include <QObject>
#include <QPointF>
#include <QVariantList>

#include "dartpilot/geometry/board_refinement.hpp"

namespace dartpilot::setup
{
// Cross-camera check with a pin (#13, #48): every camera's click on the point where one pin enters the board is
// mapped onto the board through that camera's calibration. With a good calibration all cameras land on the same
// board point; their spread is the calibration error as a dart would see it, without any measuring tool.
class PinCheck : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Cameras as CameraFinder lists them, for the order of the points
    Q_PROPERTY(QVariantList cameras READ cameras WRITE setCameras NOTIFY camerasChanged)
    Q_PROPERTY(bool calibrated READ calibrated NOTIFY camerasChanged)
    // none, or bull when the pin sits exactly in the centre of the bull
    Q_PROPERTY(QString reference READ reference WRITE setReference NOTIFY resultChanged)
    // Per clicked camera: usbPort, number, xMm, yMm, label and, with a reference, errorMm
    Q_PROPERTY(QVariantList points READ points NOTIFY resultChanged)
    Q_PROPERTY(int count READ count NOTIFY resultChanged)
    // Largest distance between the board points of two cameras
    Q_PROPERTY(double spreadMm READ spreadMm NOTIFY resultChanged)
    // good, fair or poor once two cameras are clicked
    Q_PROPERTY(QString quality READ quality NOTIFY resultChanged)
    Q_PROPERTY(QString summary READ summary NOTIFY resultChanged)
    // Measurements saved with the current calibration, and their median spread
    Q_PROPERTY(int savedCount READ savedCount NOTIFY savedChanged)
    Q_PROPERTY(double savedMedianSpreadMm READ savedMedianSpreadMm NOTIFY savedChanged)

   public:
    explicit PinCheck (QObject* parent = nullptr);

    QVariantList cameras () const { return cameras_; }
    void setCameras (const QVariantList& cameras);
    bool calibrated () const { return extrinsics_.has_value(); }
    QString reference () const { return reference_; }
    void setReference (const QString& reference);
    QVariantList points () const;
    int count () const { return static_cast<int>(points_.size()); }
    double spreadMm () const;
    QString quality () const;
    QString summary () const;
    int savedCount () const { return static_cast<int>(saved_spreads_mm_.size()); }
    double savedMedianSpreadMm () const;

    Q_INVOKABLE void setPoint (const QString& usb_port, double x_px, double y_px);
    Q_INVOKABLE void clear ();
    // Appends the measurement to pin_checks.jsonl in the calibration directory
    Q_INVOKABLE bool save ();

   signals:
    void camerasChanged ();
    void resultChanged ();
    void savedChanged ();

   private:
    struct Point
    {
        QPointF image_px;
        cv::Point2f board_mm;
    };

    const geometry::RefinedCamera* calibrationOf (const QString& usb_port) const;
    void loadSaved ();

    QVariantList cameras_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    QString reference_ = "none";
    // By USB port, so the order follows the ports
    std::map<QString, Point> points_;
    std::vector<double> saved_spreads_mm_;
};
}  // namespace dartpilot::setup
