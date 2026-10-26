#pragma once

#include <QtQml/qqmlregistration.h>
#include <QObject>
#include <QStringList>
#include <QVariantList>

namespace dartpilot::setup
{
// How far the setup is, per page of the sidebar: done, todo (a step to take), blocked (an earlier step is missing) or
// empty (the page has nothing to finish). Pages: 0 cameras, 1 intrinsic, 2 extrinsic, 3 calibration check, 4 pin
// check, 5 validation, 6 detection test.
class SetupProgress : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Cameras as CameraFinder lists them
    Q_PROPERTY(QVariantList cameras READ cameras WRITE setCameras NOTIFY changed)
    // From BoardRefiner: a refinement is stored, and whether it still matches the board planes and lenses
    Q_PROPERTY(bool refined READ refined WRITE setRefined NOTIFY changed)
    Q_PROPERTY(bool refinementStale READ refinementStale WRITE setRefinementStale NOTIFY changed)
    Q_PROPERTY(QStringList states READ states NOTIFY changed)
    // Per page: why it is blocked, and the page that unblocks it (-1 when it is not blocked)
    Q_PROPERTY(QStringList blockers READ blockers NOTIFY changed)
    Q_PROPERTY(QList<int> blockerPages READ blockerPages NOTIFY changed)

   public:
    explicit SetupProgress (QObject* parent = nullptr);

    static constexpr int kPageCount = 7;

    QVariantList cameras () const { return cameras_; }
    void setCameras (const QVariantList& cameras);
    bool refined () const { return refined_; }
    void setRefined (bool refined);
    bool refinementStale () const { return refinement_stale_; }
    void setRefinementStale (bool stale);
    QStringList states () const { return states_; }
    QStringList blockers () const { return blockers_; }
    QList<int> blockerPages () const { return blocker_pages_; }

   signals:
    void changed ();

   private:
    void update ();

    QVariantList cameras_;
    bool refined_ = false;
    bool refinement_stale_ = false;
    QStringList states_;
    QStringList blockers_;
    QList<int> blocker_pages_;
};
}  // namespace dartpilot::setup
