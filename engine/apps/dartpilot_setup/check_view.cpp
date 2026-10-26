#include "check_view.hpp"

#include <algorithm>

#include <QPainter>
#include <QtConcurrent/QtConcurrentRun>
#include <opencv2/imgproc.hpp>

#include "calibration_paths.hpp"

namespace dartpilot::setup
{
namespace
{
constexpr int kFramesToAverage = 10;
// Time between two checks
constexpr int kPause_ms = 2000;
// Provisional, from the reference cameras: a fresh detection matches its own refinement within 0.4 to 1.0 mm in the
// light it was made in, and within about 1.6 mm under other light; a camera on the wrong port is off by 25 mm or more.
constexpr double kGoodCheck_mm = 1.0;
constexpr double kFairCheck_mm = 2.5;
// Another calibration counts as the better fit when it explains the image this much better than the own one
constexpr double kSwapFactor = 3.0;

QPointF toItem (const QRectF& target, double scale, const cv::Point2f& p) { return {target.x() + p.x * scale, target.y() + p.y * scale}; }
}  // namespace

CheckView::CheckView (QQuickItem* parent)
    : StreamView(parent)
{
    pause_.setSingleShot(true);
    pause_.setInterval(kPause_ms);
    connect(&pause_, &QTimer::timeout, this, &CheckView::startMeasuring);
    connect(&watcher_, &QFutureWatcherBase::finished, this, &CheckView::onChecked);
}

CheckView::~CheckView ()
{
    watcher_.waitForFinished();
    releaseStream();
}

void CheckView::setUsbPort (const QString& usb_port)
{
    if(usb_port == usb_port_)
    {
        return;
    }
    usb_port_ = usb_port;
    // A result belongs to the camera it was measured on.
    detection_.reset();
    check_.reset();
    swapped_with_.clear();
    checks_ = 0;
    startMeasuring();
}

void CheckView::startMeasuring ()
{
    // Read every time, so a new refinement is used at once
    extrinsics_ = geometry::loadExtrinsics(extrinsicsPath().toStdString());
    const bool calibrated = extrinsics_ && std::any_of(extrinsics_->refinement.cameras.begin(), extrinsics_->refinement.cameras.end(),
                                                       [&] (const auto& c) { return c.usb_port == usb_port_.toStdString(); });
    frame_sum_.release();
    frames_summed_ = 0;
    measuring_ = calibrated;
    if(!calibrated)
    {
        check_state_ = "nocalibration";
        emit resultChanged();
        update();
    }
    else if(check_state_ == "nocalibration")
    {
        check_state_ = "measuring";
        emit resultChanged();
    }
}

void CheckView::onFrame (const CameraSnapshot& snapshot)
{
    if(!measuring_ || watcher_.isRunning())
    {
        return;
    }
    if(frame_sum_.empty())
    {
        frame_sum_ = cv::Mat::zeros(snapshot.frame.size(), CV_32FC3);
    }
    cv::accumulate(snapshot.frame, frame_sum_);
    if(++frames_summed_ < kFramesToAverage)
    {
        return;
    }
    measuring_ = false;
    cv::Mat mean;
    frame_sum_.convertTo(mean, CV_8UC3, 1.0 / frames_summed_);
    checking_port_ = usb_port_;
    watcher_.setFuture(QtConcurrent::run(
        [mean, extrinsics = *extrinsics_, port = usb_port_.toStdString()]
        {
            Result result;
            result.detection = geometry::detectBoard(mean);
            if(!result.detection)
            {
                return result;
            }
            std::optional<geometry::CalibrationCheck> best_other;
            for(const auto& camera : extrinsics.refinement.cameras)
            {
                auto check = geometry::checkCalibration(*result.detection, camera, extrinsics.refinement.board);
                if(camera.usb_port == port)
                {
                    result.check = std::move(check);
                }
                else if(check && (!best_other || check->rms_mm < best_other->rms_mm))
                {
                    best_other = std::move(check);
                    result.swapped_with = QString::fromStdString(camera.usb_port);
                }
            }
            if(!result.check || !best_other || best_other->rms_mm * kSwapFactor > result.check->rms_mm || best_other->rms_mm > kFairCheck_mm)
            {
                result.swapped_with.clear();
            }
            return result;
        }));
}

void CheckView::onChecked ()
{
    const Result result = watcher_.result();
    if(checking_port_ == usb_port_)
    {
        detection_ = result.detection;
        check_ = result.check;
        swapped_with_ = result.swapped_with;
        check_state_ = !detection_ ? "noboard" : check_ ? "checked" : "nocalibration";
        ++checks_;
        emit resultChanged();
        update();
    }
    pause_.start();
}

QString CheckView::quality () const
{
    if(check_state_ != "checked" || !check_)
    {
        return {};
    }
    if(!swapped_with_.isEmpty())
    {
        return "poor";
    }
    return check_->rms_mm <= kGoodCheck_mm ? "good" : check_->rms_mm <= kFairCheck_mm ? "fair" : "poor";
}

QString CheckView::qualityText () const
{
    if(check_state_ == "nocalibration")
    {
        return "No refinement for this camera yet: run step 5 on the extrinsic page.";
    }
    if(check_state_ == "noboard")
    {
        return "Board not found: remove the darts, or something covers the board.";
    }
    if(check_state_ != "checked" || !check_)
    {
        return "Checking …";
    }
    if(!swapped_with_.isEmpty())
    {
        return "This image fits the calibration of the camera on USB " + swapped_with_ +
               ". The cameras were probably plugged into other ports: plug them back, or calibrate again.";
    }
    const QString off = QString("%1 mm off the calibration").arg(check_->rms_mm, 0, 'f', 2);
    const QString q = quality();
    if(q == "good")
    {
        return "Matches the calibration: " + off + ".";
    }
    if(q == "fair")
    {
        return "Slightly off: " + off + ". Other light than during the calibration, or the camera moved a little. Calibrate again if it stays.";
    }
    return "The camera or the board has moved: " + off + ". Calibrate this camera again on the extrinsic page.";
}

void CheckView::paintOverlay (QPainter* painter, const QRectF& target, double scale)
{
    if(!detection_ || !check_ || check_->predicted_px.size() != detection_->points.size())
    {
        return;
    }
    painter->setRenderHint(QPainter::Antialiasing);
    // Where the calibration expects each point, and where it is found now; the line between them is the drift.
    for(std::size_t i = 0; i < detection_->points.size(); ++i)
    {
        const QPointF expected = toItem(target, scale, check_->predicted_px[i]);
        const QPointF found = toItem(target, scale, detection_->points[i].image_px);
        painter->setPen(QPen(QColor(251, 191, 36), 1.5));
        painter->drawLine(expected, found);
        painter->setBrush(Qt::NoBrush);
        painter->setPen(QPen(QColor(56, 189, 248), 1.5));
        painter->drawEllipse(expected, 4.5, 4.5);
        painter->setPen(Qt::NoPen);
        painter->setBrush(QColor(52, 211, 153));
        painter->drawEllipse(found, 2.0, 2.0);
    }
}
}  // namespace dartpilot::setup
