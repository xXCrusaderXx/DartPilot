#include "stream_view.hpp"

#include <QPainter>
#include <opencv2/imgproc.hpp>

namespace dartpilot::setup
{
namespace
{
// A camera that was unplugged or taken by another program is tried again this often.
constexpr auto kReopenInterval = std::chrono::seconds(2);
}  // namespace

void drawLabel (QPainter* painter, const QPointF& origin, const QString& text, int pixel_size, bool bold)
{
    QFont font = painter->font();
    font.setPixelSize(pixel_size);
    font.setBold(bold);
    painter->setFont(font);
    const QRectF box = QFontMetricsF(font).boundingRect(text).translated(origin).adjusted(-8, -4, 8, 4);
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    painter->setBrush(QColor(15, 18, 22, 200));
    painter->drawRoundedRect(box, box.height() / 2, box.height() / 2);
    painter->setPen(QColor(230, 233, 239));
    painter->drawText(origin, text);
}

StreamView::StreamView (QQuickItem* parent)
    : QQuickPaintedItem(parent)
{
    timer_.setInterval(15);
    connect(&timer_, &QTimer::timeout, this, &StreamView::poll);
}

StreamView::~StreamView () = default;

void StreamView::releaseStream ()
{
    timer_.stop();
    if(stream_)
    {
        detachStream(*stream_);
        stream_.reset();
    }
}

void StreamView::setDevicePath (const QString& path)
{
    if(path == device_path_)
    {
        return;
    }
    releaseStream();
    device_path_ = path;
    image_ = QImage();
    last_frame_count_ = 0;
    fps_ = 0.0;
    error_.clear();
    reopen_at_.reset();
    if(!path.isEmpty())
    {
        stream_ = CameraStream::acquire(path.toStdString());
        attachStream(*stream_);
        timer_.start();
    }
    emit devicePathChanged();
    emit statsChanged();
    update();
}

void StreamView::poll ()
{
    if(!stream_)
    {
        return;
    }
    const CameraSnapshot snapshot = stream_->latest();
    const QString error = QString::fromStdString(snapshot.error);
    if(error != error_)
    {
        error_ = error;
        emit statsChanged();
        update();
    }
    if(stream_->ended())
    {
        reopenEndedStream();
        return;
    }
    if(snapshot.frame_count == last_frame_count_ || snapshot.frame.empty())
    {
        return;
    }
    last_frame_count_ = snapshot.frame_count;

    cv::Mat rgb;
    cv::cvtColor(snapshot.frame, rgb, cv::COLOR_BGR2RGB);
    image_ = QImage(rgb.data, rgb.cols, rgb.rows, static_cast<qsizetype>(rgb.step), QImage::Format_RGB888).copy();
    onFrame(snapshot);
    if(snapshot.fps != fps_)
    {
        fps_ = snapshot.fps;
        emit statsChanged();
    }
    update();
}

void StreamView::reopenEndedStream ()
{
    const auto now = std::chrono::steady_clock::now();
    if(!reopen_at_)
    {
        reopen_at_ = now + kReopenInterval;
        return;
    }
    if(now < *reopen_at_)
    {
        return;
    }
    reopen_at_.reset();
    detachStream(*stream_);
    stream_ = CameraStream::acquire(device_path_.toStdString());
    attachStream(*stream_);
    last_frame_count_ = 0;
    // The old image would look live until the first new frame arrives.
    image_ = QImage();
    update();
}

QRectF StreamView::imageRect () const
{
    if(image_.isNull())
    {
        return {};
    }
    const QSizeF scaled = QSizeF(image_.size()).scaled(QSizeF(width(), height()), Qt::KeepAspectRatio);
    return {(width() - scaled.width()) / 2.0, (height() - scaled.height()) / 2.0, scaled.width(), scaled.height()};
}

void StreamView::paint (QPainter* painter)
{
    painter->fillRect(QRectF(0, 0, width(), height()), QColor(15, 18, 22));
    if(image_.isNull())
    {
        drawLabel(painter, QPointF(16, 32), error_.isEmpty() ? (device_path_.isEmpty() ? "Camera off" : "Waiting for frames") : error_, 16);
        return;
    }
    const QRectF target = imageRect();
    painter->setRenderHint(QPainter::SmoothPixmapTransform);
    painter->drawImage(target, image_);
    paintOverlay(painter, target, target.width() / image_.width());
    if(!error_.isEmpty())
    {
        // The last frame stays visible but dimmed, so a lost camera does not look like a still one.
        painter->fillRect(target, QColor(15, 18, 22, 170));
        drawLabel(painter, QPointF(16, 32), error_, 16);
    }
}
}  // namespace dartpilot::setup
