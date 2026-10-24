#pragma once

// Synthetic dartboard images for tests: a top view in board coordinates, projected by a known camera.
#include <array>
#include <cmath>
#include <vector>

#include <opencv2/calib3d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

namespace synthetic_board
{
constexpr std::array<double, 6> kRadii_mm = {6.35, 15.9, 99.0, 107.0, 162.0, 170.0};
constexpr double kTopScale_px_per_mm = 4.0;
constexpr int kTopSize_px = 1600;  // 400 mm around the bull

// Top view of a dartboard in board coordinates (docs/board-coordinates.md): sectors alternate dark single with red
// rings and light single with green rings, the bull is red inside the green outer bull.
struct Look
{
    cv::Vec3b red{40, 40, 190};
    cv::Vec3b green{30, 110, 30};
    cv::Vec3b dark{25, 25, 25};
    cv::Vec3b light{200, 215, 225};
    // Red plates on the number ring outside the double ring, as some boards carry them
    bool plates = false;
};

inline cv::Mat renderTopView (const Look& look = {})
{
    cv::Mat top(kTopSize_px, kTopSize_px, CV_8UC3, cv::Scalar(20, 20, 20));
    const double c = kTopSize_px / 2.0;
    for(int v = 0; v < kTopSize_px; ++v)
    {
        for(int u = 0; u < kTopSize_px; ++u)
        {
            const double x = (u - c) / kTopScale_px_per_mm, y = (c - v) / kTopScale_px_per_mm;
            const double r = std::hypot(x, y);
            if(r >= kRadii_mm[5])
            {
                // Plates between 180 and 200 mm in four places
                const double plate_angle = std::fmod(std::atan2(y, x) * 180.0 / CV_PI + 360.0, 90.0);
                if(look.plates && r > 180.0 && r < 200.0 && plate_angle > 30.0 && plate_angle < 45.0)
                {
                    top.at<cv::Vec3b>(v, u) = look.red;
                }
                continue;
            }
            const double phi = std::fmod(std::atan2(y, x) * 180.0 / CV_PI + 360.0 + 9.0, 360.0);
            const bool even = static_cast<int>(phi / 18.0) % 2 == 0;
            const cv::Vec3b red = look.red, green = look.green, dark = look.dark, light = look.light;
            cv::Vec3b colour;
            if(r < kRadii_mm[0])
            {
                colour = red;
            }
            else if(r < kRadii_mm[1])
            {
                colour = green;
            }
            else if((r >= kRadii_mm[2] && r < kRadii_mm[3]) || r >= kRadii_mm[4])
            {
                colour = even ? red : green;
            }
            else
            {
                colour = even ? dark : light;
            }
            top.at<cv::Vec3b>(v, u) = colour;
        }
    }
    return top;
}

// Homography from board millimetres to image pixels for a camera above the board, tilted towards it
inline cv::Matx33d boardToImage (double tilt_deg, double distance_mm, double yaw_deg)
{
    const cv::Matx33d k(700, 0, 640, 0, 700, 360, 0, 0, 1);
    const cv::Vec3d rvec(-tilt_deg * CV_PI / 180.0, 0.0, yaw_deg * CV_PI / 180.0);
    cv::Matx33d rotation;
    cv::Rodrigues(rvec, rotation);
    const cv::Vec3d t(0.0, 0.0, distance_mm);
    const cv::Matx33d rt(rotation(0, 0), rotation(0, 1), t[0], rotation(1, 0), rotation(1, 1), t[1], rotation(2, 0), rotation(2, 1), t[2]);
    // Board y points up, image y down
    const cv::Matx33d flip(1, 0, 0, 0, -1, 0, 0, 0, 1);
    return k * rt * flip;
}

inline cv::Point2f project (const cv::Matx33d& h, double x_mm, double y_mm)
{
    const cv::Vec3d p = h * cv::Vec3d(x_mm, y_mm, 1.0);
    return {static_cast<float>(p[0] / p[2]), static_cast<float>(p[1] / p[2])};
}

inline cv::Mat renderCameraImage (const cv::Matx33d& board_to_image, double blur_sigma_px, int jpeg_quality, const Look& look = {})
{
    const double c = kTopSize_px / 2.0;
    // Top-view pixels to board millimetres
    const cv::Matx33d top_to_board(1 / kTopScale_px_per_mm, 0, -c / kTopScale_px_per_mm, 0, -1 / kTopScale_px_per_mm, c / kTopScale_px_per_mm, 0, 0,
                                   1);
    cv::Mat image;
    cv::warpPerspective(renderTopView(look), image, cv::Mat(board_to_image * top_to_board), cv::Size(1280, 720), cv::INTER_AREA, cv::BORDER_CONSTANT,
                        cv::Scalar(15, 15, 15));
    cv::GaussianBlur(image, image, cv::Size(), blur_sigma_px);
    std::vector<uchar> jpeg;
    cv::imencode(".jpg", image, jpeg, {cv::IMWRITE_JPEG_QUALITY, jpeg_quality});
    return cv::imdecode(jpeg, cv::IMREAD_COLOR);
}

}  // namespace synthetic_board
