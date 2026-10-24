#include "dartpilot/geometry/board_state.hpp"

#include <filesystem>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

namespace dartpilot::geometry
{
namespace
{
// Without a reference: a board whose wire crossings are further than this from the calibration is partly hidden
// (unhidden boards check within about 1 mm under the light they were calibrated in, #92).
constexpr double kHiddenBoard_mm = 2.5;
// An object found against the reference is confirmed only if it still stands out when every pixel may match the
// reference anywhere within kEdgeTolerance_px: a camera that warmed up since the reference was stored zooms and softens
// its image a little, which leaves traces along every wire and number, but a dart is far wider than that. It needs
// kMinConfirmed_px pixels that differ by more than kConfirmLevel in some colour channel.
constexpr int kEdgeTolerance_px = 2;
constexpr double kConfirmLevel = 30.0;
constexpr int kMinConfirmed_px = 150;

// Pixels of the image outside the range of the reference's values around them, after matching each channel's mean
int pixelsStandingOut (const cv::Mat& image, const cv::Mat& reference)
{
    cv::Mat a, b;
    image.convertTo(a, CV_32FC3);
    reference.convertTo(b, CV_32FC3);
    const cv::Scalar mean_a = cv::mean(a), mean_b = cv::mean(b);
    std::vector<cv::Mat> a_channels, b_channels;
    cv::split(a, a_channels);
    cv::split(b, b_channels);
    const cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(2 * kEdgeTolerance_px + 1, 2 * kEdgeTolerance_px + 1));
    cv::Mat out(a.size(), CV_8U, cv::Scalar(0));
    for(int c = 0; c < 3; ++c)
    {
        a_channels[c] *= mean_b[c] / std::max(1.0, mean_a[c]);
        cv::Mat low, high;
        cv::erode(b_channels[c], low, kernel);
        cv::dilate(b_channels[c], high, kernel);
        out |= (a_channels[c] > high + kConfirmLevel) | (a_channels[c] < low - kConfirmLevel);
    }
    cv::morphologyEx(out, out, cv::MORPH_OPEN, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));
    return cv::countNonZero(out);
}
}  // namespace

std::string_view toString (BoardState state)
{
    switch(state)
    {
        case BoardState::Empty:
            return "empty";
        case BoardState::Occupied:
            return "occupied";
        case BoardState::Unknown:
            return "unknown";
    }
    return "unknown";
}

BoardCheck checkBoard (const cv::Mat& image, const cv::Mat* reference, const RefinedCamera* calibration, const BoardModel& board)
{
    BoardCheck check;
    if(image.empty())
    {
        check.reason = "No image.";
        return check;
    }
    if(reference && !reference->empty() && reference->size() == image.size())
    {
        const auto observation = tip_candidates::observeDart(image, *reference);
        if(observation && pixelsStandingOut(image, *reference) >= kMinConfirmed_px)
        {
            cv::Point2d sum(0, 0);
            for(const auto& p : observation->axis_px)
            {
                sum += cv::Point2d(p.x, p.y);
            }
            check.state = BoardState::Occupied;
            check.image_point_px = sum / static_cast<double>(observation->axis_px.size());
            check.reason = "Something stands out from the empty board.";
        }
        else
        {
            check.state = BoardState::Empty;
        }
        return check;
    }
    if(!calibration)
    {
        check.reason = "No empty-board reference and no calibration.";
        return check;
    }
    cv::Mat image_8u;
    image.convertTo(image_8u, CV_8UC3);
    const auto detection = detectBoard(image_8u);
    const auto matched = detection ? checkCalibration(*detection, *calibration, board) : std::nullopt;
    if(!matched || matched->rms_mm > kHiddenBoard_mm)
    {
        check.state = BoardState::Occupied;
        check.reason = matched ? "The board's wires are partly hidden." : "The board cannot be found: something hides it.";
        return check;
    }
    check.reason = "No empty-board reference; the wires are all visible, but a dart in a field may not hide any.";
    return check;
}

std::string emptyReferenceFileName (std::string_view usb_port) { return "empty-usb-" + std::string(usb_port) + ".png"; }

bool saveEmptyReference (const std::string& path, const cv::Mat& image)
{
    if(image.empty())
    {
        return false;
    }
    cv::Mat image_8u;
    image.convertTo(image_8u, CV_8UC3);
    try
    {
        return cv::imwrite(path, image_8u);
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}

cv::Mat loadEmptyReference (const std::string& path)
{
    // A missing file is the normal case before the first reference; OpenCV would log a warning for it.
    if(!std::filesystem::exists(path))
    {
        return {};
    }
    return cv::imread(path, cv::IMREAD_COLOR);
}
}  // namespace dartpilot::geometry
