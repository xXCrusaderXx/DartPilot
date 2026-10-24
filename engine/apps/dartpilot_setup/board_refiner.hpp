#pragma once

#include <optional>

#include <QtQml/qqmlregistration.h>
#include <QFutureWatcher>
#include <QObject>
#include <QVariantList>

#include "dartpilot/geometry/board_refinement.hpp"

namespace dartpilot::setup
{
// Refines all cameras with a stored board plane together (#13, ADR 0006) and stores the result. Each camera's lens
// starts from its own intrinsic calibration, else from the calibration of another camera of the same model, else
// from the board alone.
class BoardRefiner : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Cameras as CameraFinder lists them; the refinement uses those with a board plane.
    Q_PROPERTY(QVariantList cameras READ cameras WRITE setCameras NOTIFY camerasChanged)
    Q_PROPERTY(int refinableCount READ refinableCount NOTIFY camerasChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString message READ message NOTIFY resultChanged)
    Q_PROPERTY(bool hasResult READ hasResult NOTIFY resultChanged)
    // The board planes or intrinsics changed after the stored refinement, or a camera was added or removed
    Q_PROPERTY(bool stale READ stale NOTIFY resultChanged)
    // Per refined camera: usbPort, source, heldOutMm, rmsMm, uncertaintyMm, edgeOffsetMm, focalPx, outliers,
    // quality (good, fair or poor) and qualityText
    Q_PROPERTY(QVariantList results READ results NOTIFY resultChanged)
    Q_PROPERTY(double outerBullMm READ outerBullMm NOTIFY resultChanged)
    Q_PROPERTY(double trebleMm READ trebleMm NOTIFY resultChanged)

   public:
    explicit BoardRefiner (QObject* parent = nullptr);
    ~BoardRefiner () override;

    QVariantList cameras () const { return cameras_; }
    void setCameras (const QVariantList& cameras);
    int refinableCount () const;
    bool running () const { return watcher_.isRunning(); }
    QString message () const { return message_; }
    bool hasResult () const { return stored_.has_value(); }
    bool stale () const { return stale_; }
    QVariantList results () const;
    double outerBullMm () const;
    double trebleMm () const;

    Q_INVOKABLE void refine ();

   signals:
    void camerasChanged ();
    void runningChanged ();
    void resultChanged ();

   private:
    std::vector<geometry::RefinementInput> currentInputs () const;
    void updateStale ();
    void onFinished ();

    QVariantList cameras_;
    QString message_;
    bool stale_ = false;
    std::optional<geometry::StoredExtrinsics> stored_;
    std::vector<geometry::RefinementInput> running_inputs_;
    QFutureWatcher<std::optional<geometry::BoardRefinement>> watcher_;
};
}  // namespace dartpilot::setup
