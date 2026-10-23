#include <gtest/gtest.h>

#include "dartpilot/capture/capture.hpp"
#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/fusion.hpp"
#include "dartpilot/geometry/geometry.hpp"
#include "dartpilot/replay/replay.hpp"
#include "dartpilot/scoring/scoring.hpp"
#include "dartpilot/tip_candidates/tip_candidates.hpp"
#include "dartpilot/version.hpp"

// Verifies that every module builds and links; replaced by real tests as the modules get logic.
TEST(Smoke, AllModulesLink)
{
    EXPECT_EQ(dartpilot::capture::moduleName(), "capture");
    EXPECT_EQ(dartpilot::event_detection::moduleName(), "event_detection");
    EXPECT_EQ(dartpilot::tip_candidates::moduleName(), "tip_candidates");
    EXPECT_EQ(dartpilot::geometry::moduleName(), "geometry");
    EXPECT_EQ(dartpilot::fusion::moduleName(), "fusion");
    EXPECT_EQ(dartpilot::scoring::moduleName(), "scoring");
    EXPECT_EQ(dartpilot::replay::moduleName(), "replay");
}

TEST(Smoke, VersionIsSet) { EXPECT_FALSE(dartpilot::kVersion.empty()); }
