#include "pin_check.hpp"

#include <algorithm>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "calibration_paths.hpp"
#include "dartpilot/scoring/score.hpp"

namespace dartpilot::setup
{
namespace
{
// Provisional: each camera alone is good to about 0.5 to 0.7 mm on held-out wires, and a click is good to about half
// a pixel, so two cameras that agree within 1 mm are as good as the calibration can show; #48 sets the budget.
constexpr double kGoodSpread_mm = 1.0;
constexpr double kFairSpread_mm = 2.0;

QString pinChecksPath () { return calibrationDirectory() + "/pin_checks.jsonl"; }
}  // namespace

PinCheck::PinCheck (QObject* parent)
    : QObject(parent)
{
}

void PinCheck::setCameras (const QVariantList& cameras)
{
    cameras_ = cameras;
    // Read every time the camera list changes, so a new refinement is used at once
    extrinsics_ = geometry::loadExtrinsics(extrinsicsPath().toStdString());
    points_.clear();
    emit camerasChanged();
    emit resultChanged();
    loadSaved();
}

void PinCheck::setReference (const QString& reference)
{
    if(reference != reference_)
    {
        reference_ = reference;
        emit resultChanged();
    }
}

const geometry::RefinedCamera* PinCheck::calibrationOf (const QString& usb_port) const
{
    if(!extrinsics_)
    {
        return nullptr;
    }
    for(const auto& camera : extrinsics_->refinement.cameras)
    {
        if(camera.usb_port == usb_port.toStdString())
        {
            return &camera;
        }
    }
    return nullptr;
}

void PinCheck::setPoint (const QString& usb_port, double x_px, double y_px)
{
    const auto* camera = calibrationOf(usb_port);
    if(!camera)
    {
        return;
    }
    // The pin enters the board on the playing surface, z = 0.
    const cv::Point2f board_mm = geometry::imageToBoard(*camera, cv::Point2f(static_cast<float>(x_px), static_cast<float>(y_px)));
    points_[usb_port] = {QPointF(x_px, y_px), board_mm};
    emit resultChanged();
}

void PinCheck::clear ()
{
    points_.clear();
    emit resultChanged();
}

QVariantList PinCheck::points () const
{
    QVariantList list;
    for(const auto& [usb_port, point] : points_)
    {
        int number = 0;
        for(int i = 0; i < cameras_.size(); ++i)
        {
            if(cameras_[i].toMap().value("usbPort").toString() == usb_port)
            {
                number = i + 1;
            }
        }
        QVariantMap entry{{"usbPort", usb_port},
                          {"number", number},
                          {"xMm", point.board_mm.x},
                          {"yMm", point.board_mm.y},
                          {"label", QString::fromStdString(scoring::label(scoring::score(point.board_mm.x, point.board_mm.y)))}};
        if(reference_ == "bull")
        {
            entry.insert("errorMm", std::hypot(point.board_mm.x, point.board_mm.y));
        }
        list.append(entry);
    }
    return list;
}

double PinCheck::spreadMm () const
{
    double spread = 0.0;
    for(auto a = points_.begin(); a != points_.end(); ++a)
    {
        for(auto b = std::next(a); b != points_.end(); ++b)
        {
            spread = std::max(spread, static_cast<double>(cv::norm(a->second.board_mm - b->second.board_mm)));
        }
    }
    return spread;
}

QString PinCheck::quality () const
{
    if(points_.size() < 2)
    {
        return {};
    }
    const double spread = spreadMm();
    return spread <= kGoodSpread_mm ? "good" : spread <= kFairSpread_mm ? "fair" : "poor";
}

QString PinCheck::summary () const
{
    if(!extrinsics_)
    {
        return "No refinement yet: run step 5 on the extrinsic page first.";
    }
    if(points_.size() < 2)
    {
        return "Click the point where the pin enters the board in at least two cameras.";
    }
    QString text = QString("The cameras put the pin up to %1 mm apart.").arg(spreadMm(), 0, 'f', 2);
    if(quality() == "fair")
    {
        text += " Check the clicks with the magnifier; if it stays, refine all cameras again.";
    }
    else if(quality() == "poor")
    {
        text += " Too far apart: check the clicks, then the calibration check page, and recalibrate the camera that disagrees.";
    }
    return text;
}

bool PinCheck::save ()
{
    if(points_.size() < 2 || !extrinsics_ || !QDir().mkpath(calibrationDirectory()))
    {
        return false;
    }
    QJsonArray points;
    for(const auto& [usb_port, point] : points_)
    {
        points.append(QJsonObject{{"camera", "usb-" + usb_port},
                                  {"image_px", QJsonArray{point.image_px.x(), point.image_px.y()}},
                                  {"board_mm", QJsonArray{point.board_mm.x, point.board_mm.y}}});
    }
    const QJsonObject record{{"created", QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                             {"extrinsics_created", QString::fromStdString(extrinsics_->created)},
                             {"reference", reference_ == "bull" ? QJsonValue("bull") : QJsonValue()},
                             {"spread_mm", spreadMm()},
                             {"points", points}};
    QFile file(pinChecksPath());
    if(!file.open(QIODevice::Append | QIODevice::Text))
    {
        return false;
    }
    file.write(QJsonDocument(record).toJson(QJsonDocument::Compact) + "\n");
    file.close();
    loadSaved();
    return true;
}

void PinCheck::loadSaved ()
{
    saved_spreads_mm_.clear();
    QFile file(pinChecksPath());
    if(extrinsics_ && file.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        const QString created = QString::fromStdString(extrinsics_->created);
        while(!file.atEnd())
        {
            const QJsonObject record = QJsonDocument::fromJson(file.readLine()).object();
            if(record.value("extrinsics_created").toString() == created)
            {
                saved_spreads_mm_.push_back(record.value("spread_mm").toDouble());
            }
        }
    }
    emit savedChanged();
}

double PinCheck::savedMedianSpreadMm () const
{
    if(saved_spreads_mm_.empty())
    {
        return 0.0;
    }
    std::vector<double> sorted = saved_spreads_mm_;
    std::sort(sorted.begin(), sorted.end());
    const std::size_t n = sorted.size();
    return n % 2 == 1 ? sorted[n / 2] : 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);
}
}  // namespace dartpilot::setup
