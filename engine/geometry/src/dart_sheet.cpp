#include "dartpilot/geometry/dart_sheet.hpp"

#include <algorithm>
#include <cmath>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>
#ifdef DARTPILOT_HAVE_CHARUCO
#include <opencv2/objdetect/aruco_detector.hpp>
#endif

namespace dartpilot::geometry
{
namespace
{
// The sheet is measured at this resolution after rectifying the photo
constexpr double kRectified_px_per_mm = 10.0;
// A pixel belongs to the dart when it differs from the paper around it by more than this (grey levels, any channel)
constexpr double kObjectLevel = 45.0;
// The steel point is thinner than this; the flight wider than this, or than half its widest
constexpr double kPointWidth_mm = 3.5;
constexpr double kFlightWidth_mm = 12.0;
// The barrel is where the width is at least this share of the barrel's diameter
constexpr double kBarrelShare = 0.8;

#ifdef DARTPILOT_HAVE_CHARUCO
cv::aruco::Dictionary dictionary () { return cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_50); }

// Corners of marker i (0 top left, then clockwise) on the sheet, in mm, in the order ArUco reports them
std::vector<cv::Point2f> markerCorners_mm (int i)
{
    const double s = DartSheet::kMarker_mm, m = DartSheet::kMargin_mm;
    const double x = i == 0 || i == 3 ? m : DartSheet::kWidth_mm - m - s;
    const double y = i < 2 ? m : DartSheet::kHeight_mm - m - s;
    return {{static_cast<float>(x), static_cast<float>(y)},
            {static_cast<float>(x + s), static_cast<float>(y)},
            {static_cast<float>(x + s), static_cast<float>(y + s)},
            {static_cast<float>(x), static_cast<float>(y + s)}};
}
#endif

// Length of the run that starts at index from and goes in step direction while keep holds
template <typename Keep>
int run (const std::vector<double>& w, int from, int step, Keep keep)
{
    int length = 0;
    for(int i = from; i >= 0 && i < static_cast<int>(w.size()) && keep(w[static_cast<std::size_t>(i)]); i += step)
    {
        ++length;
    }
    return length;
}
}  // namespace

cv::Mat dartSheetImage (double px_per_mm)
{
#ifdef DARTPILOT_HAVE_CHARUCO
    const cv::Size size(cvRound(DartSheet::kWidth_mm * px_per_mm), cvRound(DartSheet::kHeight_mm * px_per_mm));
    cv::Mat sheet(size, CV_8UC3, cv::Scalar(255, 255, 255));
    const auto aruco = dictionary();
    for(int i = 0; i < 4; ++i)
    {
        const auto corners = markerCorners_mm(i);
        const int side = cvRound(DartSheet::kMarker_mm * px_per_mm);
        cv::Mat marker;
        cv::aruco::generateImageMarker(aruco, DartSheet::kFirstMarkerId + i, side, marker, 1);
        cv::cvtColor(marker, marker, cv::COLOR_GRAY2BGR);
        marker.copyTo(sheet(cv::Rect(cvRound(corners[0].x * px_per_mm), cvRound(corners[0].y * px_per_mm), side, side)));
    }
    // A 100 mm scale to check the print, and how to use the sheet
    const int y = cvRound((DartSheet::kHeight_mm - DartSheet::kMargin_mm - DartSheet::kMarker_mm / 2) * px_per_mm);
    const int x0 = cvRound(55.0 * px_per_mm), x1 = cvRound(155.0 * px_per_mm);
    cv::line(sheet, {x0, y}, {x1, y}, cv::Scalar(0, 0, 0), std::max(1, cvRound(0.4 * px_per_mm)));
    for(int mm = 0; mm <= 100; mm += 10)
    {
        const int x = cvRound((55.0 + mm) * px_per_mm);
        cv::line(sheet, {x, y}, {x, y - cvRound((mm % 50 == 0 ? 5.0 : 3.0) * px_per_mm)}, cv::Scalar(0, 0, 0), std::max(1, cvRound(0.3 * px_per_mm)));
    }
    const double font = 0.12 * px_per_mm;
    cv::putText(sheet, "100 mm - print at 100 %", {x0, y + cvRound(6.0 * px_per_mm)}, cv::FONT_HERSHEY_SIMPLEX, font, cv::Scalar(0, 0, 0),
                std::max(1, cvRound(0.25 * px_per_mm)));
    // Between the top markers, outside the area the dart is searched in
    cv::putText(sheet, "DartPilot dart sheet: lay one dart in the middle, photograph from above",
                {cvRound(46.0 * px_per_mm), cvRound(28.0 * px_per_mm)}, cv::FONT_HERSHEY_SIMPLEX, font * 0.8, cv::Scalar(90, 90, 90),
                std::max(1, cvRound(0.2 * px_per_mm)));
    return sheet;
#else
    (void) px_per_mm;
    return {};
#endif
}

std::optional<DartPhotoMeasure> measureDartPhoto (const cv::Mat& photo, std::string* why)
{
    const auto fail = [&] (const char* reason)
    {
        if(why)
        {
            *why = reason;
        }
        return std::nullopt;
    };
#ifdef DARTPILOT_HAVE_CHARUCO
    if(photo.empty())
    {
        return fail("sheet_not_found");
    }
    // The sheet's plane from its markers: at least three of four
    cv::Mat grey;
    cv::cvtColor(photo, grey, cv::COLOR_BGR2GRAY);
    std::vector<std::vector<cv::Point2f>> corners;
    std::vector<int> ids;
    cv::aruco::ArucoDetector(dictionary()).detectMarkers(grey, corners, ids);
    std::vector<cv::Point2f> image_points, sheet_points;
    int markers = 0;
    for(std::size_t k = 0; k < ids.size(); ++k)
    {
        const int i = ids[k] - DartSheet::kFirstMarkerId;
        if(i < 0 || i > 3)
        {
            continue;
        }
        ++markers;
        const auto on_sheet = markerCorners_mm(i);
        for(int c = 0; c < 4; ++c)
        {
            image_points.push_back(corners[k][static_cast<std::size_t>(c)]);
            sheet_points.push_back(on_sheet[static_cast<std::size_t>(c)] * static_cast<float>(kRectified_px_per_mm));
        }
    }
    if(markers < 3)
    {
        return fail("sheet_not_found");
    }
    const cv::Mat homography = cv::findHomography(image_points, sheet_points, cv::RANSAC, 3.0);
    if(homography.empty())
    {
        return fail("sheet_not_found");
    }
    cv::Mat sheet;
    const cv::Size size(cvRound(DartSheet::kWidth_mm * kRectified_px_per_mm), cvRound(DartSheet::kHeight_mm * kRectified_px_per_mm));
    cv::warpPerspective(photo, sheet, homography, size, cv::INTER_LINEAR, cv::BORDER_CONSTANT, cv::Scalar(255, 255, 255));

    // The dart: what differs from the paper around it, inside the area between the markers and the scale
    // The paper's brightness, which the light makes uneven: a median over 40 mm, much wider than a flight, taken at an
    // eighth of the size
    cv::Mat small, paper;
    cv::resize(sheet, small, cv::Size(), 0.125, 0.125, cv::INTER_AREA);
    cv::medianBlur(small, small, 2 * cvRound(20.0 * kRectified_px_per_mm * 0.125) + 1);
    cv::resize(small, paper, sheet.size(), 0, 0, cv::INTER_LINEAR);
    cv::Mat difference;
    cv::absdiff(sheet, paper, difference);
    std::vector<cv::Mat> channels;
    cv::split(difference, channels);
    cv::Mat mask = (cv::max(cv::max(channels[0], channels[1]), channels[2]) > kObjectLevel);
    const double top_mm = DartSheet::kMargin_mm + DartSheet::kMarker_mm + 3.0;
    const double bottom_mm = DartSheet::kHeight_mm - DartSheet::kMargin_mm - DartSheet::kMarker_mm - 3.0;
    cv::Mat inside = cv::Mat::zeros(mask.size(), CV_8U);
    inside(cv::Rect(cvRound(5.0 * kRectified_px_per_mm), cvRound(top_mm * kRectified_px_per_mm),
                    cvRound((DartSheet::kWidth_mm - 10.0) * kRectified_px_per_mm), cvRound((bottom_mm - top_mm) * kRectified_px_per_mm)))
        .setTo(255);
    mask &= inside;
    cv::morphologyEx(mask, mask, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(7, 7)));
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
    // A dart covers well over 4 cm²
    if(largest == 0 || stats.at<int>(largest, cv::CC_STAT_AREA) < 400.0 * kRectified_px_per_mm * kRectified_px_per_mm / 100.0 * 4.0)
    {
        return fail("dart_not_found");
    }
    const cv::Mat dart = labels == largest;

    // Its axis: the main direction of its pixels
    std::vector<cv::Point> pixels;
    cv::findNonZero(dart, pixels);
    cv::Mat data(static_cast<int>(pixels.size()), 2, CV_64F);
    for(std::size_t i = 0; i < pixels.size(); ++i)
    {
        data.at<double>(static_cast<int>(i), 0) = pixels[i].x;
        data.at<double>(static_cast<int>(i), 1) = pixels[i].y;
    }
    const cv::PCA pca(data, cv::Mat(), cv::PCA::DATA_AS_ROW);
    const cv::Point2d centre(pca.mean.at<double>(0), pca.mean.at<double>(1));
    cv::Point2d axis(pca.eigenvectors.at<double>(0, 0), pca.eigenvectors.at<double>(0, 1));
    const cv::Point2d across(-axis.y, axis.x);
    double low = 0.0, high = 0.0;
    for(const auto& p : pixels)
    {
        const double t = (cv::Point2d(p) - centre).dot(axis);
        low = std::min(low, t);
        high = std::max(high, t);
    }
    // Width per mm along the axis: the spread of the dart's pixels across it
    const int length_mm = static_cast<int>(std::floor((high - low) / kRectified_px_per_mm));
    std::vector<double> lo(static_cast<std::size_t>(length_mm + 1), 1e9), hi(static_cast<std::size_t>(length_mm + 1), -1e9);
    for(const auto& p : pixels)
    {
        const cv::Point2d q = cv::Point2d(p) - centre;
        const int bin = std::clamp(static_cast<int>((q.dot(axis) - low) / kRectified_px_per_mm), 0, length_mm);
        lo[static_cast<std::size_t>(bin)] = std::min(lo[static_cast<std::size_t>(bin)], q.dot(across));
        hi[static_cast<std::size_t>(bin)] = std::max(hi[static_cast<std::size_t>(bin)], q.dot(across));
    }
    std::vector<double> width(lo.size(), 0.0);
    for(std::size_t i = 0; i < width.size(); ++i)
    {
        width[i] = hi[i] >= lo[i] ? (hi[i] - lo[i] + 1.0) / kRectified_px_per_mm : 0.0;
    }
    // The point is the narrow end: turn the profile so it starts there
    const std::size_t ends = std::min<std::size_t>(10, width.size() / 4);
    double near = 0.0, far = 0.0;
    for(std::size_t i = 0; i < ends; ++i)
    {
        near += width[i];
        far += width[width.size() - 1 - i];
    }
    const bool reversed = near > far;
    if(reversed)
    {
        std::reverse(width.begin(), width.end());
        axis = -axis;
    }

    DartPhotoMeasure measure;
    measure.width_mm = width;
    const int n = static_cast<int>(width.size());
    measure.total_mm = (high - low) / kRectified_px_per_mm;
    const double widest = *std::max_element(width.begin(), width.end());
    const double flight_level = std::max(kFlightWidth_mm, 0.5 * widest);
    const int point = run(width, 0, 1, [] (double w) { return w < kPointWidth_mm; });
    const int flight = run(width, n - 1, -1, [&] (double w) { return w >= flight_level; });
    measure.point_mm = point;
    measure.flight_mm = flight;
    // Barrel: the widest part between point and flight; the shaft the rest up to the flight
    std::vector<double> middle(width.begin() + point, width.end() - flight);
    if(!middle.empty())
    {
        std::vector<double> sorted(middle);
        std::sort(sorted.begin(), sorted.end());
        measure.barrel_diameter_mm = sorted[sorted.size() * 9 / 10];
        int barrel = run(middle, 0, 1, [&] (double w) { return w >= kBarrelShare * measure.barrel_diameter_mm; });
        // The barrel may start with a narrower front: skip it up to the first wide part
        int start = 0;
        while(barrel == 0 && start + 1 < static_cast<int>(middle.size()))
        {
            barrel = run(middle, ++start, 1, [&] (double w) { return w >= kBarrelShare * measure.barrel_diameter_mm; });
        }
        measure.point_mm += start;
        measure.barrel_mm = barrel;
        measure.shaft_mm = static_cast<double>(middle.size()) - start - barrel;
    }

    // The dart turned point left, with a little paper around it
    const double angle = std::atan2(axis.y, axis.x) * 180.0 / CV_PI;
    const int out_w = cvRound(high - low + 4.0 * kRectified_px_per_mm), out_h = cvRound(widest * kRectified_px_per_mm + 8.0 * kRectified_px_per_mm);
    // Rotation by -angle about the dart's centre, which lands in the middle of the picture
    const double r = -angle * CV_PI / 180.0, c = std::cos(r), s = std::sin(r);
    const cv::Matx23d rotation(c, -s, out_w / 2.0 - (c * centre.x - s * centre.y), s, c, out_h / 2.0 - (s * centre.x + c * centre.y));
    cv::warpAffine(sheet, measure.image, rotation, cv::Size(out_w, out_h), cv::INTER_LINEAR, cv::BORDER_CONSTANT, cv::Scalar(255, 255, 255));
    return measure;
#else
    (void) photo;
    return fail("sheet_not_found");
#endif
}
}  // namespace dartpilot::geometry
