#include <gtest/gtest.h>

#include <unistd.h>

#include <filesystem>
#include <string>

#include "SyntheticBoard.hpp"
#include "dartpilot/geometry/board_state.hpp"

namespace
{
using dartpilot::geometry::BoardState;
using synthetic_board::boardToImage;
using synthetic_board::project;
using synthetic_board::renderCameraImage;

const cv::Matx33d kView = boardToImage(40.0, 600.0, 15.0);

// A dart seen from the side: a dark shaft from the board point outwards and a light flight
cv::Mat withDart (cv::Mat image, double x_mm, double y_mm)
{
    const cv::Point2f tip = project(kView, x_mm, y_mm);
    const cv::Point2f back = tip + cv::Point2f(25.0f, -160.0f);
    cv::line(image, tip, tip + (back - tip) * 0.7f, cv::Scalar(60, 60, 60), 7, cv::LINE_AA);
    cv::ellipse(image, cv::RotatedRect(tip + (back - tip) * 0.85f, cv::Size2f(40, 60), 10), cv::Scalar(120, 220, 140), cv::FILLED, cv::LINE_AA);
    return image;
}
}  // namespace

TEST(BoardState, WithAReferenceADartIsOccupiedAndTheEmptyBoardEmpty)
{
    const cv::Mat empty = renderCameraImage(kView, 1.0, 90);
    const auto occupied = dartpilot::geometry::checkBoard(withDart(empty.clone(), 40.0, 70.0), &empty, nullptr, {});
    EXPECT_EQ(occupied.state, BoardState::Occupied);
    ASSERT_TRUE(occupied.image_point_px);
    // The marked point lies on the dart, between the board and the flight.
    EXPECT_LT(cv::norm(*occupied.image_point_px - cv::Point2d(project(kView, 40.0, 70.0))), 200.0);
    EXPECT_FALSE(occupied.reason.empty());

    const auto again = dartpilot::geometry::checkBoard(renderCameraImage(kView, 1.0, 90), &empty, nullptr, {});
    EXPECT_EQ(again.state, BoardState::Empty);
    EXPECT_FALSE(again.image_point_px);
}

TEST(BoardState, WithoutReferenceOrCalibrationItIsUnknown)
{
    const auto check = dartpilot::geometry::checkBoard(renderCameraImage(kView, 1.0, 90), nullptr, nullptr, {});
    EXPECT_EQ(check.state, BoardState::Unknown);
    EXPECT_EQ(dartpilot::geometry::checkBoard(cv::Mat(), nullptr, nullptr, {}).state, BoardState::Unknown);
    EXPECT_EQ(dartpilot::geometry::toString(BoardState::Occupied), "occupied");
}

TEST(BoardState, AReferenceOfAnotherSizeIsNotUsed)
{
    const cv::Mat empty = renderCameraImage(kView, 1.0, 90);
    cv::Mat small;
    cv::resize(empty, small, cv::Size(), 0.5, 0.5);
    EXPECT_EQ(dartpilot::geometry::checkBoard(withDart(empty.clone(), 40.0, 70.0), &small, nullptr, {}).state, BoardState::Unknown);
}

TEST(BoardState, SavesAndLoadsTheReference)
{
    EXPECT_EQ(dartpilot::geometry::emptyReferenceFileName("2.4.3.1.2"), "empty-usb-2.4.3.1.2.png");
    const std::string path = (std::filesystem::temp_directory_path() / ("dartpilot-empty-" + std::to_string(::getpid()) + ".png")).string();
    const cv::Mat empty = renderCameraImage(kView, 1.0, 90);
    ASSERT_TRUE(dartpilot::geometry::saveEmptyReference(path, empty));
    const cv::Mat loaded = dartpilot::geometry::loadEmptyReference(path);
    std::filesystem::remove(path);
    ASSERT_EQ(loaded.size(), empty.size());
    EXPECT_EQ(cv::norm(loaded, empty, cv::NORM_INF), 0.0);
    EXPECT_TRUE(dartpilot::geometry::loadEmptyReference(path).empty());
    EXPECT_FALSE(dartpilot::geometry::saveEmptyReference(path, cv::Mat()));
}
