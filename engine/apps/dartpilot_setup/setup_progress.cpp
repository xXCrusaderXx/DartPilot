#include "setup_progress.hpp"

#include <QVariantMap>

namespace dartpilot::setup
{
SetupProgress::SetupProgress (QObject* parent)
    : QObject(parent)
{
    update();
}

void SetupProgress::setCameras (const QVariantList& cameras)
{
    cameras_ = cameras;
    update();
}

void SetupProgress::setRefined (bool refined)
{
    if(refined != refined_)
    {
        refined_ = refined;
        update();
    }
}

void SetupProgress::setRefinementStale (bool stale)
{
    if(stale != refinement_stale_)
    {
        refinement_stale_ = stale;
        update();
    }
}

void SetupProgress::update ()
{
    bool all_lenses = true;
    bool all_boards = true;
    for(const auto& camera : cameras_)
    {
        const QVariantMap map = camera.toMap();
        all_lenses = all_lenses && map.value("hasIntrinsics").toBool() && map.value("intrinsicsWarning").toString().isEmpty();
        all_boards = all_boards && map.value("hasBoardPlane").toBool();
    }
    const bool have_cameras = !cameras_.isEmpty();
    const bool calibrated = refined_ && !refinement_stale_;

    states_ = QStringList(kPageCount, "empty");
    blockers_ = QStringList(kPageCount);
    blocker_pages_ = QList<int>(kPageCount, -1);
    states_[0] = have_cameras ? "done" : "todo";
    // A lens calibration of its own is optional: the refinement can borrow one or fit the lens from the board.
    states_[1] = !have_cameras ? "blocked" : all_lenses ? "done" : "todo";
    states_[2] = !have_cameras ? "blocked" : all_boards && calibrated ? "done" : "todo";
    for(int page : {1, 2})
    {
        if(states_[page] == "blocked")
        {
            blockers_[page] = "No camera is connected.";
            blocker_pages_[page] = 0;
        }
    }
    for(int page = 3; page < kPageCount; ++page)
    {
        if(!have_cameras)
        {
            states_[page] = "blocked";
            blockers_[page] = "No camera is connected.";
            blocker_pages_[page] = 0;
        }
        // An out-of-date refinement still works here; checking whether a camera moved is what these pages are for.
        else if(!refined_)
        {
            states_[page] = "blocked";
            blockers_[page] = "The cameras are not calibrated to the board yet.";
            blocker_pages_[page] = 2;
        }
    }
    emit changed();
}
}  // namespace dartpilot::setup
