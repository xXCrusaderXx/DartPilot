#include "dartpilot/fusion/dart_tracker.hpp"

#include <algorithm>
#include <cmath>
#include <optional>
#include <thread>

#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/board_state.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

namespace dartpilot::fusion
{
namespace
{
// Half size of the patch around each axis point in which a change is compared with the empty board and the last state
constexpr int kPatch_px = 2;
// A still moment holds at most this many changes: a pulled dart and the one put in, and one more for safety
constexpr int kMaxChanges = 3;
// How far around the axis of a pulled dart the board is taken as it is now, so that its flight is covered as well
constexpr int kPulledReach_px = 45;

// Runs work(c) for every camera at once; each call may only write what belongs to its own camera.
template <typename Work>
void forEachCamera (std::size_t count, Work work)
{
    std::vector<std::thread> threads;
    for(std::size_t c = 1; c < count; ++c)
    {
        threads.emplace_back([&work, c] { work(c); });
    }
    if(count > 0)
    {
        work(0);
    }
    for(auto& thread : threads)
    {
        thread.join();
    }
}

// Mean absolute grey difference of two images around the axis points of an observation
double differenceAlong (const tip_candidates::DartObservation& observation, const cv::Mat& a, const cv::Mat& b)
{
    const cv::Rect image(0, 0, a.cols, a.rows);
    double sum = 0.0;
    int count = 0;
    for(const auto& p : observation.axis_px)
    {
        const cv::Rect patch = cv::Rect(cvRound(p.x) - kPatch_px, cvRound(p.y) - kPatch_px, 2 * kPatch_px + 1, 2 * kPatch_px + 1) & image;
        if(patch.area() > 0)
        {
            cv::Mat a_gray, b_gray;
            cv::cvtColor(a(patch), a_gray, cv::COLOR_BGR2GRAY);
            cv::cvtColor(b(patch), b_gray, cv::COLOR_BGR2GRAY);
            a_gray.convertTo(a_gray, CV_32F);
            b_gray.convertTo(b_gray, CV_32F);
            sum += cv::mean(cv::abs(a_gray - b_gray))[0];
            ++count;
        }
    }
    return count > 0 ? sum / count : 0.0;
}
}  // namespace

DartTracker::DartTracker (std::vector<TrackerCamera> cameras, geometry::BoardModel board)
    : cameras_(std::move(cameras))
    , board_(std::move(board))
{
}

TrackerUpdate DartTracker::addStill (const std::vector<cv::Mat>& images)
{
    // Kept as the state of the board, so they must not share memory with the caller's images.
    std::vector<cv::Mat> means;
    for(const auto& image : images)
    {
        means.push_back(image.clone());
    }
    TrackerUpdate update;
    const std::size_t count = cameras_.size();
    if(means.size() != count || std::any_of(means.begin(), means.end(), [] (const cv::Mat& m) { return m.empty(); }))
    {
        return update;
    }
    if(!ready())
    {
        // Darts left in the board must not become the empty board.
        for(std::size_t c = 0; c < count; ++c)
        {
            const cv::Mat& stored = cameras_[c].stored_empty;
            if(geometry::checkBoard(means[c], stored.empty() ? nullptr : &stored, cameras_[c].calibration, board_).state ==
               geometry::BoardState::Occupied)
            {
                return update;
            }
        }
        reference_ = means;
        last_ = means;
        update.became_ready = true;
        return update;
    }

    std::vector<std::optional<tip_candidates::DartObservation>> against_empty(count);
    if(darts_in_board_ > 0)
    {
        forEachCamera(count, [&] (std::size_t c) { against_empty[c] = tip_candidates::observeDart(means[c], reference_[c]); });
    }
    // Pulled when at most one camera still sees something against the empty board: a dart in the board stands out to
    // at least two cameras, while a single camera may keep a trace of a pushed-out fibre.
    if(darts_in_board_ > 0 && std::count_if(against_empty.begin(), against_empty.end(), [] (const auto& o) { return o.has_value(); }) <= 1)
    {
        // All darts pulled: the empty board, as it is now, becomes the reference for the next visit.
        update.takeout = darts_in_board_;
        darts_in_board_ = 0;
        reference_ = means;
        last_ = means;
        return update;
    }

    // A camera whose view changed as a whole was knocked: everything in it differs from before, which is no dart. Checked
    // after the takeout, so that three darts pulled at once are not taken for it.
    std::vector<std::optional<cv::Point2d>> shifts(count);
    forEachCamera(count, [&] (std::size_t c) { shifts[c] = tip_candidates::viewChange(last_[c], means[c]); });
    for(std::size_t c = 0; c < count; ++c)
    {
        if(const auto& shift = shifts[c])
        {
            update.moved_cameras.emplace_back(static_cast<int>(c), *shift);
            last_[c] = means[c];
            // The empty board as this camera sees it now; with darts in the board it is refreshed at the takeout, which
            // tolerates one camera that still sees something.
            if(darts_in_board_ == 0)
            {
                reference_[c] = means[c];
            }
        }
    }
    if(!update.moved_cameras.empty())
    {
        return update;
    }

    // A player may pull a dart and put the next one in without the board being still in between. Each change is
    // looked at in turn: one where the image is the empty board again is a pulled dart, which is then taken out of the
    // comparison by copying the current image over it, and the search goes on for the dart that was put in.
    std::vector<cv::Mat> before = last_;
    std::vector<std::optional<tip_candidates::DartObservation>> changes(count);
    for(int pass = 0; pass < kMaxChanges; ++pass)
    {
        // The changed object is the one that stands out from the empty board: in the image before, a pulled dart; in
        // the image now, a dart put in.
        std::vector<int> seen;
        double in_before = 0.0, in_now = 0.0;
        forEachCamera(count, [&] (std::size_t c) { changes[c] = tip_candidates::observeDart(means[c], before[c]); });
        for(std::size_t c = 0; c < count; ++c)
        {
            if(!changes[c])
            {
                continue;
            }
            seen.push_back(static_cast<int>(c));
            in_before += differenceAlong(*changes[c], before[c], reference_[c]);
            in_now += differenceAlong(*changes[c], means[c], reference_[c]);
        }
        if(seen.empty() || darts_in_board_ == 0 || in_before <= in_now)
        {
            break;
        }
        darts_in_board_ = std::max(0, darts_in_board_ - 1);
        for(const int c : seen)
        {
            cv::Mat mask = cv::Mat::zeros(means[c].size(), CV_8U);
            const auto& ends = changes[c]->ends_px;
            if(ends.size() >= 2)
            {
                cv::line(mask, ends.front(), ends.back(), cv::Scalar(255), 2 * kPulledReach_px + 1);
            }
            for(const auto& p : changes[c]->axis_px)
            {
                cv::circle(mask, p, kPulledReach_px, cv::Scalar(255), cv::FILLED);
            }
            before[c] = before[c].clone();
            means[c].copyTo(before[c], mask);
        }
        std::fill(changes.begin(), changes.end(), std::nullopt);
    }
    last_ = means;
    if(std::none_of(changes.begin(), changes.end(), [] (const auto& o) { return o.has_value(); }))
    {
        return update;
    }

    TrackedDart dart;
    dart.cameras.resize(count);
    std::vector<geometry::DartView> views;
    std::vector<std::size_t> view_camera;
    for(std::size_t c = 0; c < count; ++c)
    {
        auto& view = dart.cameras[c];
        if(!changes[c])
        {
            view.state = "not_seen";
            continue;
        }
        view.state = changes[c]->cut ? "cut" : "seen";
        if(cameras_[c].calibration)
        {
            views.push_back({cameras_[c].calibration, *changes[c]});
            view_camera.push_back(c);
        }
    }
    dart.location = views.size() >= 2 ? geometry::locateDart(views) : std::nullopt;
    if(dart.location)
    {
        for(const int v : dart.location->views)
        {
            dart.cameras[view_camera[static_cast<std::size_t>(v)]].used = true;
        }
        for(const std::size_t c : view_camera)
        {
            if(!dart.cameras[c].used)
            {
                dart.cameras[c].state = "disagrees";
            }
        }
    }
    else
    {
        const auto seen = std::count_if(changes.begin(), changes.end(), [] (const auto& o) { return o.has_value(); });
        dart.reason = seen >= 2 ? "cameras_disagree" : "seen_by_one_camera";
    }
    ++darts_in_board_;
    update.dart = std::move(dart);
    return update;
}
}  // namespace dartpilot::fusion
