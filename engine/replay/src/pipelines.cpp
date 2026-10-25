#include "pipelines.hpp"

#include <algorithm>
#include <cmath>

#include <opencv2/imgproc.hpp>

#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/dart_tracker.hpp"
#include "dartpilot/geometry/board_state.hpp"
#include "dartpilot/tip_candidates/tip_candidates.hpp"

namespace dartpilot::replay
{
namespace
{
class TrackerPipeline : public Pipeline
{
   public:
    TrackerPipeline (const std::vector<const geometry::RefinedCamera*>& cameras, const geometry::BoardModel& board,
                     const fusion::TrackerSettings& settings)
        : tracker_(trackerCameras(cameras), board, settings)
    {
    }

    StillResult addStill (const std::vector<cv::Mat>& means) override
    {
        const auto update = tracker_.addStill(means);
        StillResult result;
        result.takeout = update.takeout;
        result.became_ready = update.became_ready;
        for(const auto& moved : update.moved_cameras)
        {
            result.moved_cameras.push_back(moved.first);
        }
        if(update.dart)
        {
            DetectedDart dart;
            dart.reason = update.dart->reason;
            if(update.dart->location)
            {
                dart.board_mm = update.dart->location->board_mm;
                dart.covariance_mm2 = update.dart->location->covariance_mm2;
                dart.cameras_agreeing = static_cast<int>(update.dart->location->views.size());
            }
            for(const auto& view : update.dart->cameras)
            {
                dart.cameras.push_back({view.state, view.used, std::nullopt, std::nullopt});
            }
            result.dart = dart;
        }
        return result;
    }

    bool ready () const override { return tracker_.ready(); }

   private:
    static std::vector<fusion::TrackerCamera> trackerCameras (const std::vector<const geometry::RefinedCamera*>& cameras)
    {
        std::vector<fusion::TrackerCamera> result;
        for(std::size_t c = 0; c < cameras.size(); ++c)
        {
            // No stored empty board: the one stored now need not match the recording, so the board is checked by its wires.
            result.push_back({"camera-" + std::to_string(c), cameras[c], {}});
        }
        return result;
    }

    fusion::DartTracker tracker_;
};

// Frame differencing as the first detection did it: what changed since the last still moment is the dart, its tip the
// point of the change that lies furthest towards the board, and the cameras' board points are averaged.
class BaselinePipeline : public Pipeline
{
   public:
    BaselinePipeline (std::vector<const geometry::RefinedCamera*> cameras, geometry::BoardModel board)
        : cameras_(std::move(cameras))
        , board_(board)
    {
    }

    StillResult addStill (const std::vector<cv::Mat>& means) override
    {
        StillResult result;
        if(means.size() != cameras_.size())
        {
            return result;
        }
        if(!ready())
        {
            for(std::size_t c = 0; c < cameras_.size(); ++c)
            {
                if(geometry::checkBoard(means[c], nullptr, cameras_[c], board_).state == geometry::BoardState::Occupied)
                {
                    return result;
                }
            }
            reference_ = clones(means);
            last_ = clones(means);
            result.became_ready = true;
            return result;
        }
        // All darts pulled when at most one camera still sees a change against the empty board
        if(darts_in_board_ > 0)
        {
            int still_changed = 0;
            for(std::size_t c = 0; c < cameras_.size(); ++c)
            {
                still_changed += event_detection::differenceMask(reference_[c], means[c]).empty() ? 0 : 1;
            }
            if(still_changed <= 1)
            {
                result.takeout = darts_in_board_;
                darts_in_board_ = 0;
                reference_ = clones(means);
                last_ = clones(means);
                return result;
            }
        }
        std::vector<cv::Mat> masks;
        bool any = false;
        for(std::size_t c = 0; c < cameras_.size(); ++c)
        {
            masks.push_back(event_detection::differenceMask(last_[c], means[c]));
            any = any || !masks.back().empty();
        }
        last_ = clones(means);
        if(!any)
        {
            return result;
        }
        DetectedDart dart;
        std::vector<cv::Point2f> points;
        for(std::size_t c = 0; c < cameras_.size(); ++c)
        {
            CameraResult camera;
            if(!cameras_[c])
            {
                camera.state = "not_calibrated";
            }
            else if(masks[c].empty())
            {
                camera.state = "not_seen";
            }
            else
            {
                camera.state = "seen";
                camera.tip_px = tip_candidates::extremePoint(masks[c], towardsBoard(*cameras_[c], masks[c]));
                if(camera.tip_px)
                {
                    camera.board_mm = geometry::imageToBoard(*cameras_[c], *camera.tip_px);
                    camera.used = true;
                    points.push_back(*camera.board_mm);
                }
            }
            dart.cameras.push_back(camera);
        }
        if(points.size() >= 2)
        {
            cv::Point2d mean(0.0, 0.0);
            for(const auto& p : points)
            {
                mean += cv::Point2d(p);
            }
            mean *= 1.0 / static_cast<double>(points.size());
            // The spread of the cameras' points and 0.5 mm for each of them
            cv::Matx22d covariance = cv::Matx22d::eye() * 0.25;
            for(const auto& p : points)
            {
                const cv::Vec2d d(p.x - mean.x, p.y - mean.y);
                covariance += d * d.t() * (1.0 / static_cast<double>(points.size() - 1));
            }
            dart.board_mm = cv::Point2f(mean);
            dart.covariance_mm2 = covariance;
            dart.cameras_agreeing = static_cast<int>(points.size());
        }
        else
        {
            dart.reason = "seen_by_one_camera";
        }
        ++darts_in_board_;
        result.dart = dart;
        return result;
    }

    bool ready () const override { return !reference_.empty(); }

   private:
    static std::vector<cv::Mat> clones (const std::vector<cv::Mat>& images)
    {
        std::vector<cv::Mat> result;
        for(const auto& image : images)
        {
            result.push_back(image.clone());
        }
        return result;
    }

    // The image direction of the board normal into the board where the change is: a dart sticks out of the board
    // towards the camera, so its tip is the end of the change nearest the board.
    static cv::Point2f towardsBoard (const geometry::RefinedCamera& camera, const cv::Mat& mask)
    {
        std::vector<cv::Point> pixels;
        cv::findNonZero(mask, pixels);
        const cv::Scalar mean = cv::mean(pixels);
        const cv::Point2f centre(static_cast<float>(mean[0]), static_cast<float>(mean[1]));
        const cv::Point2f on_board = geometry::imageToBoard(camera, centre);
        const float out_mm = geometry::cameraCentre(camera)[2] >= 0.0 ? 50.0f : -50.0f;
        return geometry::boardToImage(camera, {on_board.x, on_board.y, 0.0f}) - geometry::boardToImage(camera, {on_board.x, on_board.y, out_mm});
    }

    std::vector<const geometry::RefinedCamera*> cameras_;
    geometry::BoardModel board_;
    std::vector<cv::Mat> reference_;
    std::vector<cv::Mat> last_;
    int darts_in_board_ = 0;
};
}  // namespace

std::unique_ptr<Pipeline> makePipeline (std::string_view name, const std::vector<const geometry::RefinedCamera*>& cameras,
                                        const geometry::BoardModel& board, const fusion::TrackerSettings& settings)
{
    if(name == "tracker")
    {
        return std::make_unique<TrackerPipeline>(cameras, board, settings);
    }
    if(name == "baseline")
    {
        return std::make_unique<BaselinePipeline>(cameras, board);
    }
    return nullptr;
}
}  // namespace dartpilot::replay
