#include <gtest/gtest.h>

#include <unistd.h>

#include <filesystem>
#include <string>

#include "SyntheticBoard.hpp"
#include "dartpilot/geometry/board_plane.hpp"

namespace
{
using synthetic_board::boardToImage;
using synthetic_board::project;
using synthetic_board::renderCameraImage;

// The image sector the user would click for sector 20: the middle of its singles
int twentySector (const dartpilot::geometry::BoardDetection& detection, const cv::Matx33d& h)
{
    const auto sector = dartpilot::geometry::sectorAt(detection, project(h, 0.0, 60.0));
    EXPECT_TRUE(sector);
    return sector.value_or(0);
}
}  // namespace

TEST(BoardPlane, RecoversTheBoardFromAnObliqueView)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85));
    ASSERT_TRUE(detection);
    const auto correspondences = dartpilot::geometry::orientBoard(*detection, twentySector(*detection, h));
    ASSERT_EQ(correspondences.size(), 60u);
    const auto fit = dartpilot::geometry::fitBoardPlane(correspondences, nullptr);
    ASSERT_TRUE(fit);
    EXPECT_LT(fit->rms_px, 1.0);
    EXPECT_LT(fit->rms_mm, 1.0);
    // Points across the board map back to where they are, including the middle of the treble 20 and the bull.
    for(const cv::Point2f board : {cv::Point2f(0, 0), cv::Point2f(0, 103), cv::Point2f(-120, -60), cv::Point2f(150, 40)})
    {
        const cv::Point2f mapped = dartpilot::geometry::imageToBoard(*fit, project(h, board.x, board.y), nullptr);
        EXPECT_LT(cv::norm(mapped - board), 1.0) << board;
    }
}

TEST(BoardPlane, ClickingAnotherSectorRotatesTheBoard)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85));
    ASSERT_TRUE(detection);
    // One sector counter-clockwise of the real 20 is sector 5; calling it 20 turns the board by 18 degrees.
    const int wrong = (twentySector(*detection, h) + 1) % 20;
    const auto fit = dartpilot::geometry::fitBoardPlane(dartpilot::geometry::orientBoard(*detection, wrong), nullptr);
    ASSERT_TRUE(fit);
    const cv::Point2f mapped = dartpilot::geometry::imageToBoard(*fit, project(h, 0.0, 103.0), nullptr);
    const double angle_deg = std::atan2(mapped.y, mapped.x) * 180.0 / CV_PI;
    EXPECT_NEAR(angle_deg, 90.0 - 18.0, 1.0);
}

TEST(BoardPlane, SectorAtIgnoresPointsOffTheScoringArea)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85));
    ASSERT_TRUE(detection);
    EXPECT_FALSE(dartpilot::geometry::sectorAt(*detection, project(h, 0.0, 0.0)));
    EXPECT_FALSE(dartpilot::geometry::sectorAt(*detection, project(h, 0.0, 190.0)));
    EXPECT_TRUE(dartpilot::geometry::sectorAt(*detection, project(h, 0.0, 120.0)));
}

TEST(BoardPlane, SaveLoadRoundTrip)
{
    const cv::Matx33d h = boardToImage(40.0, 600.0, 15.0);
    const auto detection = dartpilot::geometry::detectBoard(renderCameraImage(h, 1.0, 85));
    ASSERT_TRUE(detection);
    dartpilot::geometry::StoredBoardPlane plane;
    plane.twenty_sector = twentySector(*detection, h);
    plane.correspondences = dartpilot::geometry::orientBoard(*detection, plane.twenty_sector);
    plane.fit = *dartpilot::geometry::fitBoardPlane(plane.correspondences, nullptr);
    plane.usb_port = "2.4.3.1.2";
    plane.created = "2026-10-24T18:00:00Z";
    const std::string path = (std::filesystem::temp_directory_path() / ("dartpilot-board-plane-" + std::to_string(::getpid()) + ".yml")).string();
    ASSERT_TRUE(dartpilot::geometry::saveBoardPlane(path, plane));
    const auto loaded = dartpilot::geometry::loadBoardPlane(path);
    std::filesystem::remove(path);
    ASSERT_TRUE(loaded);
    EXPECT_EQ(loaded->twenty_sector, plane.twenty_sector);
    EXPECT_EQ(loaded->usb_port, "2.4.3.1.2");
    EXPECT_EQ(loaded->correspondences.size(), 60u);
    EXPECT_NEAR(loaded->fit.rms_mm, plane.fit.rms_mm, 1e-12);
    EXPECT_NEAR(loaded->fit.board_to_image(0, 0), plane.fit.board_to_image(0, 0), 1e-9);
}
