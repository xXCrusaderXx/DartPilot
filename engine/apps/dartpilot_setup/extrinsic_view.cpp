#include "extrinsic_view.hpp"

#include <algorithm>
#include <array>

#include <QDateTime>
#include <QDir>
#include <QMouseEvent>
#include <QPainter>
#include <QtConcurrent/QtConcurrentRun>
#include <opencv2/imgproc.hpp>

#include "calibration_paths.hpp"

namespace dartpilot::setup
{
namespace
{
constexpr int kFramesToAverage = 10;
// Provisional, in board millimetres; #48 sets the error budget
constexpr double kGoodFit_mm = 0.5;
constexpr double kFairFit_mm = 1.0;
// Sector numbers counter-clockwise from 20, the order of the image sectors after the one the user clicked
constexpr std::array<int, 20> kSectorsCounterClockwiseFromTwenty = {20, 5, 12, 9, 14, 11, 8, 16, 7, 19, 3, 17, 2, 15, 10, 6, 13, 4, 18, 1};

QPointF toItem (const QRectF& target, double scale, const cv::Point2f& p) { return {target.x() + p.x * scale, target.y() + p.y * scale}; }
}  // namespace

ExtrinsicView::ExtrinsicView (QQuickItem* parent)
    : StreamView(parent)
{
    setAcceptedMouseButtons(Qt::LeftButton);
    connect(&watcher_, &QFutureWatcherBase::finished, this, &ExtrinsicView::onDetected);
}

ExtrinsicView::~ExtrinsicView ()
{
    watcher_.waitForFinished();
    releaseStream();
}

QString ExtrinsicView::fitQuality () const
{
    if(!plane_)
        return "";
    return rmsMm() <= kGoodFit_mm ? "good" : rmsMm() <= kFairFit_mm ? "fair" : "poor";
}

void ExtrinsicView::setUsbPort (const QString& usb_port)
{
    if(usb_port == usb_port_)
    {
        return;
    }
    usb_port_ = usb_port;
    // A detection belongs to the camera it was made on; clicking into it must never save it under another camera.
    frame_sum_.release();
    frames_summed_ = 0;
    detection_.reset();
    twenty_sector_.reset();
    save_failed_ = false;
    setPhase("idle", QString());
    plane_ = usb_port.isEmpty() ? std::nullopt : geometry::loadBoardPlane(boardPlanePath(usb_port).toStdString());
    emit resultChanged();
}

void ExtrinsicView::setPhase (const QString& phase, const QString& message)
{
    phase_ = phase;
    message_ = message;
    emit phaseChanged();
    update();
}

void ExtrinsicView::detect ()
{
    if(!stream())
    {
        return;
    }
    frame_sum_.release();
    frames_summed_ = 0;
    detection_.reset();
    twenty_sector_.reset();
    save_failed_ = false;
    setPhase("detecting", "Looking for the board…");
}

void ExtrinsicView::onFrame (const CameraSnapshot& snapshot)
{
    if(phase_ != "detecting" || watcher_.isRunning())
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
    cv::Mat mean;
    frame_sum_.convertTo(mean, CV_8UC3, 1.0 / frames_summed_);
    detecting_port_ = usb_port_;
    watcher_.setFuture(QtConcurrent::run([mean] { return geometry::detectBoard(mean); }));
}

void ExtrinsicView::onDetected ()
{
    if(detecting_port_ != usb_port_)
    {
        return;
    }
    detection_ = watcher_.result();
    if(!detection_)
    {
        setPhase("failed", "Board not found. Remove all darts, make sure nothing covers it, and check the light.");
        return;
    }
    setPhase("pick", "Click into the sector 20.");
}

void ExtrinsicView::orient (int twenty_sector)
{
    twenty_sector_ = twenty_sector;
    geometry::StoredBoardPlane plane;
    plane.twenty_sector = twenty_sector;
    plane.usb_port = usb_port_.toStdString();
    plane.created = QDateTime::currentDateTimeUtc().toString(Qt::ISODate).toStdString();
    plane.correspondences = geometry::orientBoard(*detection_, twenty_sector);

    // The stored intrinsics remove the lens distortion, if they belong to this camera and mode.
    std::optional<geometry::IntrinsicCalibration> intrinsics;
    if(const auto stored = geometry::loadIntrinsics(intrinsicsPath(usb_port_).toStdString()))
    {
        if(geometry::settingsMismatches(*stored, {plane.usb_port, cv::Size(kReferenceWidth_px, kReferenceHeight_px), kReferencePixelFormat}).empty())
        {
            intrinsics = stored->calibration;
        }
    }
    const auto fit = geometry::fitBoardPlane(plane.correspondences, intrinsics ? &*intrinsics : nullptr);
    if(!fit)
    {
        setPhase("failed", "The board plane could not be fitted.");
        return;
    }
    plane.fit = *fit;
    QDir().mkpath(calibrationDirectory());
    const bool stored = geometry::saveBoardPlane(boardPlanePath(usb_port_).toStdString(), plane);
    plane_ = plane;
    save_failed_ = !stored;
    emit resultChanged();
    setPhase("done", stored ? "Saved. Check that the numbers match the board; if not, click the sector 20 again."
                            : "Fitted, but saving failed. Check that the calibration directory is writable, then click the sector 20 again.");
    if(stored)
    {
        emit saved();
    }
}

void ExtrinsicView::mousePressEvent (QMouseEvent* event)
{
    const QRectF target = imageRect();
    if(!detection_ || (phase_ != "pick" && phase_ != "done") || target.isEmpty())
    {
        event->ignore();
        return;
    }
    const double scale = target.width() / imageSize().width;
    const cv::Point2f image_px(static_cast<float>((event->position().x() - target.x()) / scale),
                               static_cast<float>((event->position().y() - target.y()) / scale));
    const auto sector = geometry::sectorAt(*detection_, image_px);
    if(!sector)
    {
        setPhase(phase_, "Click inside the scoring area, into the sector 20.");
        return;
    }
    orient(*sector);
}

void ExtrinsicView::paintOverlay (QPainter* painter, const QRectF& target, double scale)
{
    painter->setRenderHint(QPainter::Antialiasing);
    if(detection_)
    {
        const QColor accent(56, 189, 248);
        painter->setPen(QPen(accent, 1.5));
        painter->setBrush(Qt::NoBrush);
        for(const auto& circle : detection_->circles)
        {
            painter->save();
            painter->translate(toItem(target, scale, circle.center));
            painter->rotate(circle.angle);
            painter->drawEllipse(QPointF(0, 0), circle.size.width / 2 * scale, circle.size.height / 2 * scale);
            painter->restore();
        }
        // Wires from the bull to a little beyond the double ring
        const double reach_px = 0.6 * std::max(detection_->circles.back().size.width, detection_->circles.back().size.height);
        for(const auto& wire : detection_->wires)
        {
            const cv::Point2f from(wire[0], wire[1]);
            const cv::Point2f to = from + cv::Point2f(wire[2], wire[3]) * static_cast<float>(reach_px);
            painter->drawLine(toItem(target, scale, from), toItem(target, scale, to));
        }
        painter->setPen(Qt::NoPen);
        painter->setBrush(QColor(52, 211, 153));
        for(const auto& point : detection_->points)
        {
            painter->drawEllipse(toItem(target, scale, point.image_px), 2.5, 2.5);
        }

        // Sector numbers in the outer singles, so the user can check the orientation at a glance
        if(twenty_sector_)
        {
            QFont font = painter->font();
            font.setPixelSize(std::max(12, static_cast<int>(target.height() / 40)));
            font.setBold(true);
            painter->setFont(font);
            for(int s = 0; s < geometry::kRadialWireCount; ++s)
            {
                cv::Point2f sum(0, 0);
                int n = 0;
                for(const auto& point : detection_->points)
                {
                    const bool bounds = point.wire == s || point.wire == (s + 1) % geometry::kRadialWireCount;
                    if(bounds && point.circle != geometry::BoardCircle::OuterBull)
                    {
                        sum += point.image_px;
                        ++n;
                    }
                }
                if(n == 0)
                {
                    continue;
                }
                const int number =
                    kSectorsCounterClockwiseFromTwenty[(s - *twenty_sector_ + geometry::kRadialWireCount) % geometry::kRadialWireCount];
                const QPointF centre = toItem(target, scale, sum * (1.0f / n));
                const QRectF box(centre.x() - 16, centre.y() - 11, 32, 22);
                painter->setPen(Qt::NoPen);
                painter->setBrush(number == 20 ? QColor(251, 191, 36) : QColor(15, 18, 22, 200));
                painter->drawRoundedRect(box, 11, 11);
                painter->setPen(number == 20 ? QColor(15, 18, 22) : QColor(230, 233, 239));
                painter->drawText(box, Qt::AlignCenter, QString::number(number));
            }
        }
    }
}
}  // namespace dartpilot::setup
