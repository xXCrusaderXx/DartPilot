#include "board_refiner.hpp"

#include <algorithm>

#include <QDateTime>
#include <QDir>
#include <QtConcurrent/QtConcurrentRun>

#include "calibration_paths.hpp"

namespace dartpilot::setup
{
namespace
{
// Provisional quality gate in board millimetres on held-out wires, like the board fit; #48 sets the error budget.
constexpr double kGoodHeldOut_mm = 0.5;
constexpr double kFairHeldOut_mm = 1.0;

// A stored intrinsic calibration that was made in the reference capture mode
bool inReferenceMode (const geometry::StoredIntrinsics& stored)
{
    return stored.calibration.image_size_px == cv::Size(kReferenceWidth_px, kReferenceHeight_px) && stored.info.pixel_format == kReferencePixelFormat;
}

QString sourceText (geometry::IntrinsicsSource source)
{
    switch(source)
    {
        case geometry::IntrinsicsSource::OwnCalibration:
            return "own lens calibration";
        case geometry::IntrinsicsSource::ModelPrior:
            return "lens of another camera of this model";
        case geometry::IntrinsicsSource::BoardOnly:
            return "board only";
    }
    return {};
}
}  // namespace

BoardRefiner::BoardRefiner (QObject* parent)
    : QObject(parent)
    , stored_(geometry::loadExtrinsics(extrinsicsPath().toStdString()))
{
    connect(&watcher_, &QFutureWatcherBase::finished, this, &BoardRefiner::onFinished);
}

BoardRefiner::~BoardRefiner () { watcher_.waitForFinished(); }

void BoardRefiner::setCameras (const QVariantList& cameras)
{
    cameras_ = cameras;
    emit camerasChanged();
    updateStale();
}

int BoardRefiner::refinableCount () const
{
    int count = 0;
    for(const auto& camera : cameras_)
    {
        count += camera.toMap().value("hasBoardPlane").toBool() ? 1 : 0;
    }
    return count;
}

std::vector<geometry::RefinementInput> BoardRefiner::currentInputs () const
{
    // Intrinsics of all connected cameras, in the order of the list, so the model prior is chosen deterministically
    std::vector<std::pair<std::string, geometry::StoredIntrinsics>> intrinsics;
    for(const auto& camera : cameras_)
    {
        const QString usb_port = camera.toMap().value("usbPort").toString();
        if(auto stored = geometry::loadIntrinsics(intrinsicsPath(usb_port).toStdString()); stored && inReferenceMode(*stored))
        {
            intrinsics.emplace_back(usb_port.toStdString(), std::move(*stored));
        }
    }

    std::vector<geometry::RefinementInput> inputs;
    for(const auto& camera : cameras_)
    {
        const QVariantMap map = camera.toMap();
        const QString usb_port = map.value("usbPort").toString();
        const auto plane = geometry::loadBoardPlane(boardPlanePath(usb_port).toStdString());
        if(!plane)
        {
            continue;
        }
        geometry::RefinementInput input;
        input.usb_port = usb_port.toStdString();
        input.correspondences = plane->correspondences;
        input.board_plane_created = plane->created;
        input.prior = geometry::boardOnlyPrior(cv::Size(kReferenceWidth_px, kReferenceHeight_px));
        const auto own = std::find_if(intrinsics.begin(), intrinsics.end(), [&] (const auto& entry) { return entry.first == input.usb_port; });
        const auto same_model = std::find_if(intrinsics.begin(), intrinsics.end(), [&] (const auto& entry)
                                             { return entry.second.info.camera_name == map.value("name").toString().toStdString(); });
        if(own != intrinsics.end())
        {
            input.prior = geometry::priorFromCalibration(own->second.calibration, geometry::IntrinsicsSource::OwnCalibration);
            input.intrinsics_created = own->second.info.created;
        }
        else if(same_model != intrinsics.end())
        {
            input.prior = geometry::priorFromCalibration(same_model->second.calibration, geometry::IntrinsicsSource::ModelPrior);
            input.intrinsics_created = same_model->second.info.created;
        }
        inputs.push_back(std::move(input));
    }
    return inputs;
}

void BoardRefiner::updateStale ()
{
    bool stale = false;
    if(stored_)
    {
        const auto inputs = currentInputs();
        stale = inputs.size() != stored_->inputs.size();
        for(std::size_t i = 0; !stale && i < inputs.size(); ++i)
        {
            const auto& now = inputs[i];
            const auto& then = stored_->inputs[i];
            stale = now.usb_port != then.usb_port || now.board_plane_created != then.board_plane_created ||
                    now.intrinsics_created != then.intrinsics_created || now.prior.source != then.prior.source;
        }
    }
    if(stale != stale_)
    {
        stale_ = stale;
        emit resultChanged();
    }
}

void BoardRefiner::refine ()
{
    if(watcher_.isRunning())
    {
        return;
    }
    running_inputs_ = currentInputs();
    if(running_inputs_.empty())
    {
        message_ = "No camera has a board plane yet.";
        emit resultChanged();
        return;
    }
    message_ = "Refining …";
    emit resultChanged();
    watcher_.setFuture(QtConcurrent::run([inputs = running_inputs_] { return geometry::refineBoardCameras(inputs); }));
    emit runningChanged();
}

void BoardRefiner::onFinished ()
{
    emit runningChanged();
    const auto refinement = watcher_.result();
    if(!refinement)
    {
        message_ = "The refinement failed: a camera could not be posed from its board points. Detect its board again.";
        emit resultChanged();
        return;
    }
    geometry::StoredExtrinsics stored;
    stored.created = QDateTime::currentDateTimeUtc().toString(Qt::ISODate).toStdString();
    stored.refinement = *refinement;
    stored.inputs = running_inputs_;
    const bool saved = QDir().mkpath(calibrationDirectory()) && geometry::saveExtrinsics(extrinsicsPath().toStdString(), stored);
    stored_ = std::move(stored);
    stale_ = false;
    message_ = saved ? "Refined and saved." : "Refined, but saving failed.";
    emit resultChanged();
}

QVariantList BoardRefiner::results () const
{
    QVariantList list;
    if(!stored_)
    {
        return list;
    }
    for(std::size_t i = 0; i < stored_->refinement.cameras.size(); ++i)
    {
        const auto& camera = stored_->refinement.cameras[i];
        const double held_out_mm = camera.held_out_rms_mm;
        const QString quality = held_out_mm <= kGoodHeldOut_mm ? "good" : held_out_mm <= kFairHeldOut_mm ? "fair" : "poor";
        QString text = QString("Error on held-out wires: %1 mm.").arg(held_out_mm, 0, 'f', 2);
        if(quality != "good")
        {
            text += camera.source == geometry::IntrinsicsSource::OwnCalibration
                        ? " Detect the board of this camera again in even light."
                        : " A ChArUco lens calibration of this camera on the intrinsic page can lower it.";
        }
        list.append(QVariantMap{{"usbPort", QString::fromStdString(camera.usb_port)},
                                {"source", sourceText(camera.source)},
                                {"heldOutMm", held_out_mm},
                                {"rmsMm", camera.rms_mm},
                                {"uncertaintyMm", camera.uncertainty_mm},
                                {"edgeOffsetMm", camera.edge_offset_mm},
                                {"focalPx", camera.intrinsics.camera_matrix(0, 0)},
                                {"outliers", camera.outliers},
                                {"quality", quality},
                                {"qualityText", text}});
    }
    return list;
}

double BoardRefiner::outerBullMm () const
{
    return stored_ ? stored_->refinement.board.radii_mm[static_cast<int>(geometry::BoardCircle::OuterBull)] : 0.0;
}

double BoardRefiner::trebleMm () const
{
    return stored_ ? stored_->refinement.board.radii_mm[static_cast<int>(geometry::BoardCircle::TripleCentre)] : 0.0;
}
}  // namespace dartpilot::setup
