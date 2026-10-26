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
// Provisional quality gate in pixels of held-out error. #46 derives the final thresholds in board millimetres.
constexpr double kGoodHeldOut_px = 0.5;
constexpr double kFairHeldOut_px = 1.0;
constexpr double kGoodCoverage = 0.75;
constexpr double kFairCoverage = 0.4;
constexpr std::size_t kGoodViews = 15;
constexpr std::size_t kFairViews = 8;

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
    // All models are calibrated together, so switching shows the stored result instead of discarding it.
    saved_path_.clear();
    updateResultText();
    emit modelChanged();
    emit resultChanged();
    emit viewsChanged();
}

QString IntrinsicView::target () const { return target_ == geometry::CharucoTarget::phone() ? "phone" : "tablet"; }

void IntrinsicView::setTarget (const QString& target)
{
    const geometry::CharucoTarget next = target == QLatin1String("phone") ? geometry::CharucoTarget::phone() : geometry::CharucoTarget::tablet();
    if(next == target_)
    {
        return;
    }
    target_ = next;
    if(stream())
    {
        stream()->setCharucoTarget(target_);
    }
    detection_.reset();
    previous_detection_.reset();
    still_frames_ = 0;
    updateHint();
    emit targetChanged();
    emit detectionChanged();
}

double IntrinsicView::coverage () const
{
    const auto covered = std::count_if(coverage_.begin(), coverage_.end(), [] (int count) { return count > 0; });
    return static_cast<double>(covered) / coverage_.size();
}

QString IntrinsicView::cornersQuality () const
{
    if(cornersInFrame() >= std::ceil(kMinCornerShare * totalCorners())) return "good";
    return cornersInFrame() > 0 ? "fair" : "";
}

QString IntrinsicView::viewsQuality () const
{
    if(views_.size() >= kGoodViews) return "good";
    return views_.size() >= kFairViews ? "fair" : "";
}

QString IntrinsicView::coverageQuality () const
{
    if(coverage() >= kGoodCoverage) return "good";
    return coverage() >= kFairCoverage ? "fair" : "";
}

const IntrinsicView::ModelResult* IntrinsicView::selected () const
{
    const auto it = std::find_if(results_.begin(), results_.end(), [this] (const ModelResult& result) { return result.model == model_; });
    return it == results_.end() ? nullptr : &*it;
}

std::vector<int> IntrinsicView::outlierViews () const
{
    std::vector<int> outliers;
    const ModelResult* result = selected();
    if(!result || !result->calibration || result->calibration->per_view_rms_px.size() != views_.size() || views_.empty())
    {
        return outliers;
    }
    const auto& errors = result->calibration->per_view_rms_px;
    std::vector<double> sorted = errors;
    std::nth_element(sorted.begin(), sorted.begin() + sorted.size() / 2, sorted.end());
    const double median = sorted[sorted.size() / 2];
    for(std::size_t i = 0; i < errors.size(); ++i)
    {
        if(errors[i] > kOutlierFactor * median)
        {
            outliers.push_back(static_cast<int>(i));
        }
    }
    return outliers;
}

QVariantList IntrinsicView::views () const
{
    QVariantList list;
    const ModelResult* result = selected();
    const std::vector<int> outliers = outlierViews();
    for(std::size_t i = 0; i < views_.size(); ++i)
    {
        QVariantMap entry{{"index", static_cast<int>(i)}, {"corners", static_cast<int>(views_[i].ids.size())}};
        if(result && result->calibration && i < result->calibration->per_view_rms_px.size())
        {
            entry["rmsPx"] = result->calibration->per_view_rms_px[i];
            entry["outlier"] = std::find(outliers.begin(), outliers.end(), static_cast<int>(i)) != outliers.end();
        }
        list.append(entry);
    }
    return list;
}

QVariantList IntrinsicView::modelResults () const
{
    QVariantList list;
    for(const auto& result : results_)
    {
        QVariantMap entry{{"model", QString::fromLatin1(geometry::toString(result.model).data())},
                          {"ok", result.calibration.has_value() && result.validation.has_value()},
                          {"recommended", recommended_ == result.model}};
        if(result.calibration)
        {
            entry["rmsPx"] = result.calibration->rms_px;
        }
        if(result.validation)
        {
            entry["heldOutRmsPx"] = result.validation->rms_px;
        }
        list.append(entry);
    }
    return list;
}

QString IntrinsicView::recommendedModel () const { return recommended_ ? QString::fromLatin1(geometry::toString(*recommended_).data()) : QString(); }

QString IntrinsicView::quality () const
{
    const ModelResult* result = selected();
    if(!result || !result->validation)
    {
        return {};
    }
    const double held_out_px = result->validation->rms_px;
    if(held_out_px <= kGoodHeldOut_px && coverage() >= kGoodCoverage && views_.size() >= kGoodViews)
    {
        return "good";
    }
    return held_out_px <= kFairHeldOut_px && views_.size() >= kFairViews ? "fair" : "poor";
}

QString IntrinsicView::qualityText () const
{
    const ModelResult* result = selected();
    if(!result || !result->validation)
    {
        return {};
    }
    QString text = QString("Error on held-out views: %1 px.").arg(result->validation->rms_px, 0, 'f', 2);
    if(quality() != "good")
    {
        if(views_.size() < kGoodViews)
        {
            text += QString(" Capture at least %1 views.").arg(kGoodViews);
        }
        if(coverage() < kGoodCoverage)
        {
            text += " Cover more of the image, especially corners and edges.";
        }
        if(result->validation->rms_px > kGoodHeldOut_px)
        {
            text += " Remove the red views, keep the pattern still and flat, and check the focus.";
        }
    }
    text += " Provisional thresholds in pixels; the gate in board millimetres follows with #46 and the camera poses (#13).";
    return text;
}

void IntrinsicView::attachStream (CameraStream& stream)
{
    stream.setCharucoTarget(target_);
    stream.addCharucoUser(1);
}

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
        targets_used_.insert(target_.describe());
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
    targets_used_.insert(target_.describe());
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
    targets_used_.clear();
    coverage_.fill(0);
    invalidateResult();
    updateHint();
    emit viewsChanged();
}

void IntrinsicView::removeOutlierViews ()
{
    const std::vector<int> outliers = outlierViews();
    for(auto it = outliers.rbegin(); it != outliers.rend(); ++it)
    {
        views_.erase(views_.begin() + *it);
    }
    if(outliers.empty())
    {
        return;
    }
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

void IntrinsicView::setUsbPort (const QString& usb_port)
{
    if(usb_port == usb_port_) return;
    usb_port_ = usb_port;
    emit usbPortChanged();
    emit savedChanged();
}

QString IntrinsicView::savedSummary () const
{
    if(usb_port_.isEmpty())
    {
        return {};
    }
    const auto stored = geometry::loadIntrinsics(intrinsicsPath(usb_port_).toStdString());
    if(!stored)
    {
        return {};
    }
    QString summary = QString("%1 model, %2 views, fit %3 px")
                          .arg(QString::fromLatin1(geometry::toString(stored->calibration.model).data()))
                          .arg(stored->views.size())
                          .arg(stored->calibration.rms_px, 0, 'f', 2);
    if(stored->validation)
    {
        summary += QString(", held-out %1 px").arg(stored->validation->rms_px, 0, 'f', 2);
    }
    summary += ", " + QString::fromStdString(stored->info.created);
    const auto mismatches =
        geometry::settingsMismatches(*stored, {usb_port_.toStdString(), cv::Size(kReferenceWidth_px, kReferenceHeight_px), kReferencePixelFormat});
    for(const auto& mismatch : mismatches)
    {
        summary += ". Not valid: " + QString::fromStdString(mismatch);
    }
    return summary;
}

bool IntrinsicView::loadSaved ()
{
    if(usb_port_.isEmpty() || watcher_.isRunning())
    {
        return false;
    }
    const auto stored = geometry::loadIntrinsics(intrinsicsPath(usb_port_).toStdString());
    if(!stored || stored->views.empty())
    {
        return false;
    }
    views_.clear();
    targets_used_.clear();
    if(!stored->info.target.empty())
    {
        targets_used_.insert(stored->info.target);
    }
    coverage_.fill(0);
    image_size_px_ = stored->calibration.image_size_px;
    for(const auto& view : stored->views)
    {
        addView(view);
    }
    if(stored->calibration.model != model_)
    {
        model_ = stored->calibration.model;
        emit modelChanged();
    }
    invalidateResult();
    emit viewsChanged();
    calibrate();
    return true;
}

void IntrinsicView::invalidateResult ()
{
    if(results_.empty() && result_text_.isEmpty())
    {
        return;
    }
    results_.clear();
    recommended_.reset();
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
    // Every model is calibrated and validated, so the choice between them is made on held-out data.
    watcher_.setFuture(QtConcurrent::run(
        [views = views_, size = image_size_px_]
        {
            std::vector<ModelResult> results;
            for(const auto model : {geometry::DistortionModel::Standard, geometry::DistortionModel::Rational, geometry::DistortionModel::Fisheye})
            {
                results.push_back({model, geometry::calibrateIntrinsics(views, size, model), geometry::validateIntrinsics(views, size, model)});
            }
            return results;
        }));
    emit resultChanged();
}

void IntrinsicView::onCalibrated ()
{
    results_ = watcher_.result();
    std::vector<std::pair<geometry::DistortionModel, geometry::HeldOutValidation>> validations;
    for(const auto& result : results_)
    {
        if(result.calibration && result.validation)
        {
            validations.emplace_back(result.model, *result.validation);
        }
    }
    recommended_ = geometry::recommendModel(validations);
    if(recommended_ && *recommended_ != model_)
    {
        model_ = *recommended_;
        emit modelChanged();
    }
    saved_path_.clear();
    updateResultText();
    emit resultChanged();
    emit viewsChanged();
}

void IntrinsicView::updateResultText ()
{
    const ModelResult* result = selected();
    if(!result)
    {
        result_text_.clear();
        return;
    }
    if(!result->calibration)
    {
        result_text_ = "Calibration with the " + model() + " model failed: OpenCV rejected the views. Remove poor views or add more.";
        return;
    }
    const auto& calibration = *result->calibration;
    const auto& k = calibration.camera_matrix;
    QStringList coefficients;
    for(std::size_t i = 0; i < calibration.dist_coeffs.total(); ++i)
    {
        coefficients << QString::number(calibration.dist_coeffs.at<double>(static_cast<int>(i)), 'g', 4);
    }
    result_text_ = QString("RMS %1 px over %2 views\nfx %3  fy %4  cx %5  cy %6 px")
                       .arg(calibration.rms_px, 0, 'f', 3)
                       .arg(views_.size())
                       .arg(k(0, 0), 0, 'f', 1)
                       .arg(k(1, 1), 0, 'f', 1)
                       .arg(k(0, 2), 0, 'f', 1)
                       .arg(k(1, 2), 0, 'f', 1);
    if(calibration.std_deviations.size() >= 4)
    {
        result_text_ += QString("\n± %1  %2  %3  %4 px")
                            .arg(calibration.std_deviations[0], 0, 'f', 2)
                            .arg(calibration.std_deviations[1], 0, 'f', 2)
                            .arg(calibration.std_deviations[2], 0, 'f', 2)
                            .arg(calibration.std_deviations[3], 0, 'f', 2);
    }
    result_text_ += "\nDistortion (" + model() + "): " + coefficients.join("  ");
}

QString IntrinsicView::calibrationDirectory () const { return setup::calibrationDirectory(); }

QString IntrinsicView::patternDownloadUrl () const { return setup::patternDownloadUrl(target_); }

QString IntrinsicView::save ()
{
    const ModelResult* result = selected();
    if(!result || !result->calibration || usb_port_.isEmpty() || !QDir().mkpath(calibrationDirectory()))
    {
        return {};
    }
    const QString path = intrinsicsPath(usb_port_);
    geometry::CalibrationInfo info;
    info.usb_port = usb_port_.toStdString();
    info.camera_name = camera_name_.toStdString();
    info.pixel_format = kReferencePixelFormat;
    std::string targets;
    for(const auto& used : targets_used_)
    {
        targets += (targets.empty() ? "" : "; ") + used;
    }
    info.target = targets;
    info.created = QDateTime::currentDateTimeUtc().toString(Qt::ISODate).toStdString();
    if(!geometry::saveIntrinsics(path.toStdString(), *result->calibration, info, views_, result->validation))
    {
        return {};
    }
    saved_path_ = path;
    emit resultChanged();
    emit savedChanged();
    return path;
}

QString IntrinsicView::savePattern ()
{
    const geometry::CharucoTarget& target = target_;
    const cv::Mat pattern = geometry::CharucoFinder(target).patternImage(target.imageSize_px());
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

    // Held-out error per image region of the selected model, where the calibration is weakest
    const ModelResult* result = selected();
    if(result && result->validation)
    {
        constexpr int kGrid = geometry::HeldOutValidation::kRegionGrid;
        const int label_px = std::max(11, static_cast<int>(target.height() / 40));
        for(int region = 0; region < kGrid * kGrid; ++region)
        {
            const double error_px = result->validation->region_rms_px[region];
            const QPointF centre(target.x() + (region % kGrid + 0.5) * target.width() / kGrid,
                                 target.y() + (region / kGrid + 0.5) * target.height() / kGrid);
            const QString text = std::isnan(error_px) ? QStringLiteral("no points") : QString::number(error_px, 'f', 2) + " px";
            drawLabel(painter, centre - QPointF(label_px * 2.0, 0.0), text, label_px, error_px > kGoodHeldOut_px);
        }
    }
}
}  // namespace dartpilot::setup
