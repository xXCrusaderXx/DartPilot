#pragma once

#include <array>
#include <optional>
#include <vector>

#include <opencv2/core.hpp>

// Dartboard features in a camera image: the ring edges and the radial wires, as calibration points (#47).
// Works on the colour boundaries, which lie on the wires: the wires themselves are often only about a pixel wide.
namespace dartpilot::geometry
{
// The circles the calibration points lie on. The triple and double rings are only a few pixels wide in an oblique view;
// blur makes them look wider, so their edges are biased, but their centre lines are not.
enum class BoardCircle
{
    // Edge between the outer bull and the inner singles, radius 15.9 mm
    OuterBull,
    // Centre line of the triple ring, radius 103 mm
    TripleCentre,
    // Centre line of the double ring, radius 166 mm
    DoubleCentre,
};
constexpr int kBoardCircleCount = 3;
// Nominal radii of the BoardCircle values, in that order
constexpr std::array<double, kBoardCircleCount> kBoardCircleRadii_mm = {15.9, 103.0, 166.0};
constexpr int kRadialWireCount = 20;

struct BoardImagePoint
{
    // Radial wires are numbered counter-clockwise in the image, starting at an arbitrary wire; which one borders
    // sector 20 is decided later (orientation), so this index is not yet a board angle.
    int wire = 0;
    BoardCircle circle = BoardCircle::OuterBull;
    cv::Point2f image_px;
    // Standard deviation of the position, from the fit residuals of the wire line and the circle's ellipse
    double sigma_px = 0.0;
};

struct BoardDetection
{
    cv::Point2f bull_px;
    // Image of each BoardCircle, in that order
    std::array<cv::RotatedRect, kBoardCircleCount> circles;
    // Radial wires counter-clockwise in the image as point and unit direction (x0, y0, dx, dy), pointing outwards
    std::array<cv::Vec4f, kRadialWireCount> wires;
    // Intersections of every wire with every circle
    std::vector<BoardImagePoint> points;
    // Largest distance of a measured transition from its wire line; large values point to distortion or misdetection
    double worst_wire_residual_px = 0.0;
};

// Finds the board in an 8-bit BGR image of the empty board: red and green ring segments, the bull, the three circles
// and the 20 radial wires. Nothing if any of them is missing, e.g. when darts or a hand cover the board.
std::optional<BoardDetection> detectBoard (const cv::Mat& bgr);
}  // namespace dartpilot::geometry
