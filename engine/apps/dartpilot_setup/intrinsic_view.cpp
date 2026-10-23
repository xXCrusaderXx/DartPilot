#include "intrinsic_view.hpp"

#include <algorithm>
#include <cmath>
#include <map>

#include <QDateTime>
#include <QDir>
#include <QImage>
#include <QPainter>
#include <QtConcurrent/QtConcurrentRun>

#include "calibration_paths.hpp"
#include "dartpilot/geometry/charuco.hpp"

namespace dartpilot::setup
{
namespace
{
// A view is captured automatically when this share of the target's corners is visible ...
constexpr double kMinCornerShare = 0.4;
// ... and the corners moved less than this between frames for kStillFrames frames.
constexpr double kStillMotionPx = 1.5;
constexpr int kStillFrames = 10;
constexpr int kMinFramesBetweenCaptures = 15;
// A view repeats an earlier one when most corners are shared and lie within this distance on average.
constexpr double kNovelMotionPx = 40.0;
// A view is marked as outlier when its error exceeds this multiple of the median view error.
constexpr double kOutlierFactor = 2.0;

// Mean and maximum displacement of the corners two views share, and how many they share.
struct Motion
{
    int common = 0;
    double mean_px = 0.0;
    double max_px = 0.0;
};

Motion motionBetween (const geometry::CalibrationView& a, const geometry::CalibrationView& b)
{
    std::map<int, cv::Point2f> by_id;
    for(std::size_t i = 0; i < a.ids.size(); ++i)
    {
        by_id[a.ids[i]] = a.image_points_px[i];
    }
    Motion motion;
    double sum = 0.0;
    for(std::size_t i = 0; i < b.ids.size(); ++i)
    {
        const auto it = by_id.find(b.ids[i]);
        if(it == by_id.end())
        {
            continue;
        }
        const double d = cv::norm(it->second - b.image_points_px[i]);
        sum += d;
        motion.max_px = std::max(motion.max_px, d);
        ++motion.common;
    }
    motion.mean_px = motion.common > 0 ? sum / motion.common : 0.0;
    return motion;
}

QString regionName (int col, int row)
{
    static const char* const rows[] = {"top", "middle", "bottom"};
    static const char* const cols[] = {"left", "centre", "right"};
    if(col == 1 && row == 1)
    {
        return "centre";
    }
    if(col == 1)
    {
        return rows[row];
    }
    if(row == 1)
    {
        return cols[col];
    }
    return QString(rows[row]) + " " + cols[col];
}
}  // namespace

IntrinsicView::IntrinsicView (QQuickItem* parent)
    : StreamView(parent)
{
    connect(&watcher_, &QFutureWatcherBase::finished, this, &IntrinsicView::onCalibrated);
    updateHint();
}

IntrinsicView::~IntrinsicView ()
{
    watcher_.waitForFinished();
    releaseStream();
}

bool IntrinsicView::charucoAvailable () const { return geometry::charucoAvailable(); }

QString IntrinsicView::model () const { return QString::fromLatin1(geometry::toString(model_).data()); }

void IntrinsicView::setModel (const QString& model)
{
    const auto parsed = geometry::parseDistortionModel(model.toStdString());
    if(!parsed || *parsed == model_)
    {
        return;
    }
    model_ = *parsed;
    invalidateResult();
    emit modelChanged();
}

int IntrinsicView::totalCorners () const { return geometry::CharucoTarget{}.cornerCount(); }

double IntrinsicView::coverage () const
{
    const auto covered = std::count_if(coverage_.begin(), coverage_.end(), [] (int count) { return count > 0; });
    return static_cast<double>(covered) / coverage_.size();
}

QVariantList IntrinsicView::views () const
{
    QVariantList list;
    double median = 0.0;
    if(result_ && !result_->per_view_rms_px.empty())
    {
        std::vector<double> sorted = result_->per_view_rms_px;
        std::nth_element(sorted.begin(), sorted.begin() + sorted.size() / 2, sorted.end());
        median = sorted[sorted.size() / 2];
    }
    for(std::size_t i = 0; i < views_.size(); ++i)
    {
        QVariantMap entry{{"index", static_cast<int>(i)}, {"corners", static_cast<int>(views_[i].ids.size())}};
        if(result_ && i < result_->per_view_rms_px.size())
        {
            entry["rmsPx"] = result_->per_view_rms_px[i];
            entry["outlier"] = result_->per_view_rms_px[i] > kOutlierFactor * median;
        }
        list.append(entry);
    }
    return list;
}

void IntrinsicView::attachStream (CameraStream& stream) { stream.addCharucoUser(1); }

void IntrinsicView::detachStream (CameraStream& stream)
{
    stream.addCharucoUser(-1);
    detection_.reset();
    previous_detection_.reset();
    still_frames_ = 0;
    emit detectionChanged();
}

void IntrinsicView::onFrame (const CameraSnapshot& snapshot)
{
    image_size_px_ = cv::Size(snapshot.frame.cols, snapshot.frame.rows);
    detection_ = snapshot.charuco;
    ++frames_since_capture_;

    const int min_corners = static_cast<int>(std::ceil(kMinCornerShare * totalCorners()));
    if(detection_ && previous_detection_ && static_cast<int>(detection_->ids.size()) >= min_corners)
    {
        const Motion motion = motionBetween(*previous_detection_, *detection_);
        const bool still = motion.common * 2 >= static_cast<int>(detection_->ids.size()) && motion.max_px < kStillMotionPx;
        still_frames_ = still ? still_frames_ + 1 : 0;
    }
    else
    {
        still_frames_ = 0;
    }
    previous_detection_ = detection_;

    if(auto_capture_ && still_frames_ >= kStillFrames && frames_since_capture_ >= kMinFramesBetweenCaptures && isNovel(*detection_))
    {
        addView(*detection_);
    }
    updateHint();
    emit detectionChanged();
}

bool IntrinsicView::isNovel (const geometry::CalibrationView& view) const
{
    return std::none_of(views_.begin(), views_.end(),
                        [&view] (const geometry::CalibrationView& existing)
                        {
                            const Motion motion = motionBetween(existing, view);
                            return motion.common * 2 >= static_cast<int>(view.ids.size()) && motion.mean_px < kNovelMotionPx;
                        });
}

bool IntrinsicView::capture ()
{
    if(!detection_)
    {
        return false;
    }
    addView(*detection_);
    return true;
}

void IntrinsicView::addView (const geometry::CalibrationView& view)
{
    views_.push_back(view);
    for(const auto& point : view.image_points_px)
    {
        const int col = std::clamp(static_cast<int>(point.x * kCoverageCols / std::max(1, image_size_px_.width)), 0, kCoverageCols - 1);
        const int row = std::clamp(static_cast<int>(point.y * kCoverageRows / std::max(1, image_size_px_.height)), 0, kCoverageRows - 1);
        ++coverage_[row * kCoverageCols + col];
    }
    frames_since_capture_ = 0;
    still_frames_ = 0;
    invalidateResult();
    updateHint();
    emit viewsChanged();
    emit captured();
}

void IntrinsicView::removeView (int index)
{
    if(index < 0 || index >= static_cast<int>(views_.size()))
    {
        return;
    }
    views_.erase(views_.begin() + index);
    coverage_.fill(0);
    const std::vector<geometry::CalibrationView> remaining = std::move(views_);
    views_.clear();
    for(const auto& view : remaining)
    {
        addView(view);
    }
    invalidateResult();
    emit viewsChanged();
}

void IntrinsicView::clearViews ()
{
    views_.clear();
    coverage_.fill(0);
    invalidateResult();
    updateHint();
    emit viewsChanged();
}

void IntrinsicView::invalidateResult ()
{
    if(!result_ && result_text_.isEmpty())
    {
        return;
    }
    result_.reset();
    result_text_.clear();
    saved_path_.clear();
    emit resultChanged();
}

void IntrinsicView::updateHint ()
{
    QString hint;
    if(!charucoAvailable())
    {
        hint = "This build has no ChArUco detection (OpenCV 4.7 or newer needed).";
    }
    else if(!detection_)
    {
        hint = "Hold the pattern in front of the camera.";
    }
    else if(cornersInFrame() < std::ceil(kMinCornerShare * totalCorners()))
    {
        hint = "Bring more of the pattern into view.";
    }
    else
    {
        // The 3x3 region of the image with the fewest covered cells is where the next views should go.
        int best_col = 1, best_row = 1;
        double lowest = 2.0;
        for(int row = 0; row < 3; ++row)
        {
            for(int col = 0; col < 3; ++col)
            {
                int cells = 0, covered = 0;
                for(int y = row * kCoverageRows / 3; y < (row + 1) * kCoverageRows / 3; ++y)
                {
                    for(int x = col * kCoverageCols / 3; x < (col + 1) * kCoverageCols / 3; ++x)
                    {
                        ++cells;
                        covered += coverage_[y * kCoverageCols + x] > 0 ? 1 : 0;
                    }
                }
                const double share = cells > 0 ? static_cast<double>(covered) / cells : 1.0;
                if(share < lowest)
                {
                    lowest = share;
                    best_col = col;
                    best_row = row;
                }
            }
        }
        if(lowest < 0.75)
        {
            hint = "Move the pattern to the " + regionName(best_col, best_row) + " of the image, tilted in different directions.";
        }
        else if(views_.size() < 15)
        {
            hint = "Good coverage. Add views with the pattern tilted by 30-45 degrees and at different distances.";
        }
        else
        {
            hint = "Enough views for a first calibration.";
        }
    }
    if(hint != hint_)
    {
        hint_ = hint;
        emit detectionChanged();
    }
}

void IntrinsicView::calibrate ()
{
    if(watcher_.isRunning() || views_.size() < 3 || image_size_px_.empty())
    {
        return;
    }
    watcher_.setFuture(
        QtConcurrent::run([views = views_, size = image_size_px_, model = model_] { return geometry::calibrateIntrinsics(views, size, model); }));
    emit resultChanged();
}

void IntrinsicView::onCalibrated ()
{
    result_ = watcher_.result();
    saved_path_.clear();
    if(!result_)
    {
        result_text_ = "Calibration failed: OpenCV rejected the views. Remove poor views or add more and try again.";
    }
    else
    {
        const auto& k = result_->camera_matrix;
        QStringList coefficients;
        for(std::size_t i = 0; i < result_->dist_coeffs.total(); ++i)
        {
            coefficients << QString::number(result_->dist_coeffs.at<double>(static_cast<int>(i)), 'g', 4);
        }
        result_text_ = QString("RMS %1 px over %2 views\nfx %3  fy %4  cx %5  cy %6 px")
                           .arg(result_->rms_px, 0, 'f', 3)
                           .arg(views_.size())
                           .arg(k(0, 0), 0, 'f', 1)
                           .arg(k(1, 1), 0, 'f', 1)
                           .arg(k(0, 2), 0, 'f', 1)
                           .arg(k(1, 2), 0, 'f', 1);
        if(result_->std_deviations.size() >= 4)
        {
            result_text_ += QString("\n± %1  %2  %3  %4 px")
                                .arg(result_->std_deviations[0], 0, 'f', 2)
                                .arg(result_->std_deviations[1], 0, 'f', 2)
                                .arg(result_->std_deviations[2], 0, 'f', 2)
                                .arg(result_->std_deviations[3], 0, 'f', 2);
        }
        result_text_ += "\nDistortion (" + model() + "): " + coefficients.join("  ");
    }
    emit resultChanged();
    emit viewsChanged();
}

QString IntrinsicView::calibrationDirectory () const { return setup::calibrationDirectory(); }

QString IntrinsicView::patternDownloadUrl () const { return setup::patternDownloadUrl(); }

QString IntrinsicView::save ()
{
    if(!result_ || usb_port_.isEmpty() || !QDir().mkpath(calibrationDirectory()))
    {
        return {};
    }
    const QString path = intrinsicsPath(usb_port_);
    geometry::CalibrationInfo info;
    info.usb_port = usb_port_.toStdString();
    info.camera_name = camera_name_.toStdString();
    info.pixel_format = "MJPG 1280x720 30fps";
    info.target = geometry::CharucoTarget{}.describe();
    info.created = QDateTime::currentDateTimeUtc().toString(Qt::ISODate).toStdString();
    if(!geometry::saveIntrinsics(path.toStdString(), *result_, info, views_))
    {
        return {};
    }
    saved_path_ = path;
    emit resultChanged();
    return path;
}

QString IntrinsicView::savePattern ()
{
    const geometry::CharucoTarget target;
    const cv::Mat pattern = geometry::CharucoFinder(target).patternImage(cv::Size(geometry::kPatternImageWidth_px, geometry::kPatternImageHeight_px));
    if(pattern.empty() || !QDir().mkpath(calibrationDirectory()))
    {
        return {};
    }
    const QString path = calibrationDirectory() + "/" + QString::fromStdString(target.imageFileName());
    const QImage image(pattern.data, pattern.cols, pattern.rows, static_cast<qsizetype>(pattern.step), QImage::Format_Grayscale8);
    return image.save(path) ? path : QString();
}

void IntrinsicView::paintOverlay (QPainter* painter, const QRectF& target, double scale)
{
    const double cell_w = target.width() / kCoverageCols;
    const double cell_h = target.height() / kCoverageRows;
    for(int row = 0; row < kCoverageRows; ++row)
    {
        for(int col = 0; col < kCoverageCols; ++col)
        {
            const int count = coverage_[row * kCoverageCols + col];
            if(count > 0)
            {
                painter->fillRect(QRectF(target.x() + col * cell_w, target.y() + row * cell_h, cell_w, cell_h),
                                  QColor(52, 211, 153, std::min(35 + 20 * count, 110)));
            }
        }
    }
    if(detection_)
    {
        const bool still = still_frames_ > 0;
        painter->setPen(Qt::NoPen);
        painter->setBrush(still ? QColor(56, 189, 248) : QColor(251, 191, 36));
        const double radius = std::max(2.0, 3.0 * scale);
        for(const auto& point : detection_->image_points_px)
        {
            painter->drawEllipse(QPointF(target.x() + point.x * scale, target.y() + point.y * scale), radius, radius);
        }
        if(auto_capture_ && still_frames_ > 0)
        {
            const double progress = std::min(1.0, static_cast<double>(still_frames_) / kStillFrames);
            painter->fillRect(QRectF(target.x(), target.bottom() - 6, target.width() * progress, 6), QColor(56, 189, 248));
        }
    }
}
}  // namespace dartpilot::setup
