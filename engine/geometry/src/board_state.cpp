#include "dartpilot/geometry/board_state.hpp"

#include <filesystem>

#include <cmath>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/board_detection.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

namespace dartpilot::geometry
{
namespace
{
// Pixels of the image outside the range of the reference's values around them, after matching each channel's mean
// The board within radius_mm as it lies in the camera's image, as an 8-bit mask
cv::Mat boardRegion (const cv::Size& size, const RefinedCamera& camera, double radius_mm)
{
    cv::Mat region(size, CV_8U, cv::Scalar(0));
    std::vector<cv::Point> outline;
    for(int i = 0; i < 180; ++i)
    {
        const double a = 2.0 * CV_PI * i / 180.0;
        const cv::Point2f p =
            boardToImage(camera, cv::Point3f(static_cast<float>(radius_mm * std::cos(a)), static_cast<float>(radius_mm * std::sin(a)), 0.0f));
        outline.emplace_back(cvRound(p.x), cvRound(p.y));
    }
    cv::fillPoly(region, std::vector<std::vector<cv::Point>>{outline}, cv::Scalar(255));
    return region;
}

cv::Mat pixelsStandingOut (const cv::Mat& image, const cv::Mat& reference, const BoardCheckSettings& s)
{
    cv::Mat a, b;
    image.convertTo(a, CV_32FC3);
    reference.convertTo(b, CV_32FC3);
    const cv::Scalar mean_a = cv::mean(a), mean_b = cv::mean(b);
    std::vector<cv::Mat> a_channels, b_channels;
    cv::split(a, a_channels);
    cv::split(b, b_channels);
    const cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(2 * s.edge_tolerance_px + 1, 2 * s.edge_tolerance_px + 1));
    cv::Mat out(a.size(), CV_8U, cv::Scalar(0));
    for(int c = 0; c < 3; ++c)
    {
        a_channels[c] *= mean_b[c] / std::max(1.0, mean_a[c]);
        cv::Mat low, high;
        cv::erode(b_channels[c], low, kernel);
        cv::dilate(b_channels[c], high, kernel);
        out |= (a_channels[c] > high + s.confirm_level) | (a_channels[c] < low - s.confirm_level);
    }
    cv::morphologyEx(out, out, cv::MORPH_OPEN, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));
    return out;
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

BoardCheck checkBoard (const cv::Mat& image, const cv::Mat* reference, const RefinedCamera* calibration, const BoardModel& board,
                       const BoardCheckSettings& s)
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
        cv::Mat standing_out = observation ? pixelsStandingOut(image, *reference, s) : cv::Mat();
        if(!standing_out.empty() && calibration && s.board_radius_mm > 0.0)
        {
            standing_out &= boardRegion(standing_out.size(), *calibration, s.board_radius_mm);
        }
        if(!standing_out.empty() && cv::countNonZero(standing_out) >= s.min_confirmed_px)
        {
            std::vector<cv::Point> pixels;
            cv::findNonZero(standing_out, pixels);
            cv::Point2d sum(0, 0);
            for(const auto& p : pixels)
            {
                sum += cv::Point2d(p.x, p.y);
            }
            check.state = BoardState::Occupied;
            check.image_point_px = sum / static_cast<double>(pixels.size());
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
    if(!matched || matched->rms_mm > s.hidden_board_mm)
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
