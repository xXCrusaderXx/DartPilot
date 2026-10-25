#include "dartpilot/event_detection/event_detection.hpp"

#include <algorithm>

#include <opencv2/imgproc.hpp>

namespace dartpilot::event_detection
{
namespace
{
cv::Mat grey (const cv::Mat& image)
{
    cv::Mat bgr;
    image.convertTo(bgr, CV_8UC3);
    cv::Mat result;
    cv::cvtColor(bgr, result, cv::COLOR_BGR2GRAY);
    return result;
}
}  // namespace

std::string_view moduleName () { return "event_detection"; }

StillDetector::StillDetector (std::size_t cameras, StillSettings settings)
    : settings_(settings)
    , cameras_(cameras)
{
}

void StillDetector::restart ()
{
    for(auto& camera : cameras_)
    {
        camera.sum.release();
        camera.frames.clear();
    }
}

std::optional<StillMoment> StillDetector::addSample (std::int64_t time_ns, const std::vector<std::optional<StillSample>>& samples, bool measure_again)
{
    bool still = samples.size() == cameras_.size();
    for(std::size_t c = 0; c < cameras_.size() && c < samples.size(); ++c)
    {
        Camera& camera = cameras_[c];
        if(samples[c] && !samples[c]->image.empty())
        {
            cv::Mat small;
            cv::resize(samples[c]->image, small, cv::Size(), 0.25, 0.25, cv::INTER_AREA);
            cv::cvtColor(small, small, cv::COLOR_BGR2GRAY);
            small.convertTo(small, CV_32F);
            camera.moving = camera.previous_small.empty() || camera.previous_small.size() != small.size() ||
                            cv::mean(cv::abs(small - camera.previous_small))[0] > settings_.still_motion;
            camera.previous_small = small;
            camera.seen = true;
        }
        still = still && camera.seen && !camera.moving;
    }
    if(!still)
    {
        still_samples_ = 0;
        measured_since_motion_ = false;
        restart();
        return std::nullopt;
    }
    if(measured_since_motion_ && !(measure_again && time_ns - last_measured_ns_ >= settings_.retry_interval_ns))
    {
        return std::nullopt;
    }
    if(++still_samples_ < settings_.settle_samples)
    {
        return std::nullopt;
    }
    if(still_samples_ == settings_.settle_samples)
    {
        still_since_ns_ = time_ns;
    }
    bool complete = true;
    for(std::size_t c = 0; c < cameras_.size(); ++c)
    {
        Camera& camera = cameras_[c];
        const auto& sample = samples[c];
        if(sample && !sample->image.empty() && static_cast<int>(camera.frames.size()) < settings_.frames_to_average)
        {
            if(camera.sum.empty())
            {
                camera.sum = cv::Mat::zeros(sample->image.size(), CV_32FC3);
            }
            if(sample->image.size() == camera.sum.size())
            {
                cv::accumulate(sample->image, camera.sum);
                camera.frames.push_back(sample->sequence);
                camera.last_exposure_ns = sample->exposure_ns;
            }
        }
        complete = complete && static_cast<int>(camera.frames.size()) >= settings_.frames_to_average;
    }
    if(!complete)
    {
        return std::nullopt;
    }
    StillMoment moment;
    moment.start_ns = still_since_ns_;
    for(auto& camera : cameras_)
    {
        moment.means.push_back(camera.sum / static_cast<double>(camera.frames.size()));
        moment.frames.push_back(camera.frames);
        moment.end_ns = std::max(moment.end_ns, camera.last_exposure_ns);
    }
    measured_since_motion_ = true;
    last_measured_ns_ = time_ns;
    restart();
    return moment;
}

cv::Mat differenceMask (const cv::Mat& before, const cv::Mat& after, double threshold, int min_area_px)
{
    if(before.empty() || before.size() != after.size())
    {
        return {};
    }
    cv::Mat difference;
    cv::absdiff(grey(before), grey(after), difference);
    cv::Mat mask = difference > threshold;
    // Closing joins the thin point and the barrel to the flight; opening would erase the point.
    cv::morphologyEx(mask, mask, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(9, 9)));
    cv::Mat labels, stats, centroids;
    const int count = cv::connectedComponentsWithStats(mask, labels, stats, centroids, 8, CV_32S);
    int largest = 0;
    for(int i = 1; i < count; ++i)
    {
        if(largest == 0 || stats.at<int>(i, cv::CC_STAT_AREA) > stats.at<int>(largest, cv::CC_STAT_AREA))
        {
            largest = i;
        }
    }
    if(largest == 0 || stats.at<int>(largest, cv::CC_STAT_AREA) < min_area_px)
    {
        return {};
    }
    return labels == largest;
}
}  // namespace dartpilot::event_detection
