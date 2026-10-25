#pragma once

#include <cstdint>
#include <optional>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

// Throw events: time window, baseline frames before the throw and difference masks.
namespace dartpilot::event_detection
{
// Module name, used by the CLI and the smoke test
std::string_view moduleName ();

// The still moments live detection waits for (#121), in the times of the frames, so a replay finds the same moments
// whatever the speed it runs at
struct StillSettings
{
    // Every camera's latest frame is looked at this often
    std::int64_t sample_interval_ns = 100'000'000;
    // Mean brightness change between two samples at a quarter of the size above which a camera moves; image noise
    // gives about 1
    double still_motion = 2.5;
    // Samples every camera must be still before averaging starts, and frames averaged per camera
    int settle_samples = 15;
    int frames_to_average = 10;
    // While measure_again is set, a still board is measured again this often, e.g. while waiting for an empty board
    std::int64_t retry_interval_ns = 3'000'000'000;
};

struct StillMoment
{
    // When all cameras had settled, and the exposure time of the last frame averaged
    std::int64_t start_ns = 0;
    std::int64_t end_ns = 0;
    // Per camera: the mean image (float BGR) and the sequence numbers of the frames in it
    std::vector<cv::Mat> means;
    std::vector<std::vector<std::uint32_t>> frames;
};

struct StillSample
{
    cv::Mat image;
    std::uint32_t sequence = 0;
    std::int64_t exposure_ns = 0;
};

class StillDetector
{
   public:
    StillDetector (std::size_t cameras, StillSettings settings = {});

    // One sample at time_ns: per camera its frame if it has a new one since the last sample, nothing otherwise. A still
    // moment once all cameras have been still for the settle time and have given their frames to average; one per
    // stillness, or one every retry interval while measure_again is set.
    std::optional<StillMoment> addSample (std::int64_t time_ns, const std::vector<std::optional<StillSample>>& samples, bool measure_again);

    const StillSettings& settings () const { return settings_; }

   private:
    struct Camera
    {
        cv::Mat previous_small;
        bool seen = false;
        bool moving = true;
        cv::Mat sum;
        std::vector<std::uint32_t> frames;
        std::int64_t last_exposure_ns = 0;
    };
    void restart ();

    StillSettings settings_;
    std::vector<Camera> cameras_;
    int still_samples_ = 0;
    bool measured_since_motion_ = false;
    std::int64_t still_since_ns_ = 0;
    std::int64_t last_measured_ns_ = 0;
};

// The pixels whose brightness differs by more than threshold between two images of one camera (8-bit or float BGR),
// with gaps of a few pixels closed: the largest connected region, as an 8-bit mask. Empty if it is smaller than min_area_px.
cv::Mat differenceMask (const cv::Mat& before, const cv::Mat& after, double threshold = 25.0, int min_area_px = 150);
}  // namespace dartpilot::event_detection
