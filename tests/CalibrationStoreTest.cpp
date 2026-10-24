#include <gtest/gtest.h>

#include <filesystem>
#include <random>
#include <string>

#include "SyntheticBoard.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/calibration_store.hpp"

using namespace dartpilot;

TEST(CalibrationStore, RefinementInputsComeFromTheStoredBoardPlanesAndGoStaleWhenOneChanges)
{
    const auto directory = std::filesystem::temp_directory_path() / ("dartpilot-store-" + std::to_string(std::random_device{}()));
    std::filesystem::create_directories(directory);
    const std::vector<geometry::SetupCamera> cameras = {{"1.2", "Cam"}, {"1.3", "Cam"}};
    EXPECT_TRUE(geometry::refinementInputs(directory, cameras, {}).empty());

    const auto detection = geometry::detectBoard(synthetic_board::renderCameraImage(synthetic_board::boardToImage(40.0, 600.0, 15.0), 1.0, 90));
    ASSERT_TRUE(detection);
    geometry::StoredBoardPlane plane;
    plane.usb_port = "1.3";
    plane.created = "2026-10-24T20:00:00Z";
    plane.correspondences = geometry::orientBoard(*detection, 0);
    plane.fit = *geometry::fitBoardPlane(plane.correspondences, nullptr);
    ASSERT_TRUE(geometry::saveBoardPlane((directory / geometry::boardPlaneFileName("1.3")).string(), plane));

    const auto inputs = geometry::refinementInputs(directory, cameras, {});
    ASSERT_EQ(inputs.size(), 1u);
    EXPECT_EQ(inputs[0].usb_port, "1.3");
    EXPECT_EQ(inputs[0].prior.source, geometry::IntrinsicsSource::BoardOnly);

    geometry::StoredExtrinsics stored;
    stored.inputs = inputs;
    EXPECT_FALSE(geometry::refinementStale(stored, inputs));
    plane.created = "2026-10-24T21:00:00Z";
    ASSERT_TRUE(geometry::saveBoardPlane((directory / geometry::boardPlaneFileName("1.3")).string(), plane));
    EXPECT_TRUE(geometry::refinementStale(stored, geometry::refinementInputs(directory, cameras, {})));
    std::filesystem::remove_all(directory);
}
