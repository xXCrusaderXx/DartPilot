#include <gtest/gtest.h>

#include <cmath>
#include <limits>
#include <numbers>

#include "dartpilot/scoring/score.hpp"

namespace
{
using dartpilot::scoring::BoardGeometry;
using dartpilot::scoring::Ring;
using dartpilot::scoring::score;

double radians (double degrees) { return degrees * std::numbers::pi / 180.0; }

// Point at radius r_mm and angle phi_deg (counter-clockwise from the x axis)
dartpilot::scoring::Score scoreAt (double r_mm, double phi_deg, const BoardGeometry& geometry = {})
{
    return score(r_mm * std::cos(radians(phi_deg)), r_mm * std::sin(radians(phi_deg)), geometry);
}

// Middle of the i-th sector clockwise from the top
double sectorMiddle_deg (int i) { return 90.0 - 18.0 * i; }

// Independent reference: the sector whose middle is angularly closest to the point
int referenceSector (double x_mm, double y_mm)
{
    const double phi_deg = std::atan2(y_mm, x_mm) * 180.0 / std::numbers::pi;
    int best = 0;
    double best_difference = 1e9;
    for(int i = 0; i < 20; ++i)
    {
        const double difference = std::abs(std::remainder(phi_deg - sectorMiddle_deg(i), 360.0));
        if(difference < best_difference)
        {
            best_difference = difference;
            best = dartpilot::scoring::kSectorsClockwiseFromTop[i];
        }
    }
    return best;
}
}  // namespace

TEST(Score, EverySectorInEveryRing)
{
    for(int i = 0; i < 20; ++i)
    {
        const int sector = dartpilot::scoring::kSectorsClockwiseFromTop[i];
        const double phi = sectorMiddle_deg(i);
        EXPECT_EQ(scoreAt(50.0, phi).points, sector) << sector;
        EXPECT_EQ(scoreAt(103.0, phi).points, 3 * sector) << sector;
        EXPECT_EQ(scoreAt(130.0, phi).points, sector) << sector;
        EXPECT_EQ(scoreAt(166.0, phi).points, 2 * sector) << sector;
        EXPECT_EQ(scoreAt(103.0, phi).ring, Ring::Triple);
        EXPECT_EQ(scoreAt(166.0, phi).ring, Ring::Double);
    }
}

TEST(Score, Bulls)
{
    EXPECT_EQ(score(0.0, 0.0).points, 50);
    EXPECT_EQ(score(0.0, 0.0).ring, Ring::InnerBull);
    EXPECT_EQ(score(3.0, -4.0).points, 50);
    EXPECT_EQ(score(10.0, 0.0).points, 25);
    EXPECT_EQ(score(10.0, 0.0).sector, 0);
    EXPECT_EQ(score(-7.0, 7.0).ring, Ring::OuterBull);
}

TEST(Score, Miss)
{
    const auto miss = score(0.0, 200.0);
    EXPECT_EQ(miss.ring, Ring::Miss);
    EXPECT_EQ(miss.points, 0);
    EXPECT_EQ(miss.sector, 0);
    EXPECT_EQ(miss.multiplier, 0);
    EXPECT_DOUBLE_EQ(miss.boundary_distance_mm, 30.0);
}

TEST(Score, RingBoundariesBelongToTheRegionFurtherOut)
{
    // On the x axis the angle is exactly 0, the middle of sector 6.
    EXPECT_EQ(score(6.35, 0.0).ring, Ring::OuterBull);
    EXPECT_EQ(score(15.9, 0.0).ring, Ring::InnerSingle);
    EXPECT_EQ(score(99.0, 0.0).ring, Ring::Triple);
    EXPECT_EQ(score(107.0, 0.0).ring, Ring::OuterSingle);
    EXPECT_EQ(score(162.0, 0.0).ring, Ring::Double);
    EXPECT_EQ(score(170.0, 0.0).ring, Ring::Miss);

    EXPECT_EQ(score(std::nextafter(6.35, 0.0), 0.0).ring, Ring::InnerBull);
    EXPECT_EQ(score(std::nextafter(99.0, 0.0), 0.0).ring, Ring::InnerSingle);
    EXPECT_EQ(score(std::nextafter(170.0, 0.0), 0.0).ring, Ring::Double);
}

TEST(Score, RadialWiresSplitNeighbouringSectors)
{
    // The wire between 6 (clockwise) and 13 (counter-clockwise) lies at 9 degrees.
    EXPECT_EQ(scoreAt(50.0, 9.0 - 1e-6).sector, 6);
    EXPECT_EQ(scoreAt(50.0, 9.0 + 1e-6).sector, 13);
    // Across the wire between 11 and 8, where the angle wraps through 180 / -180 degrees
    EXPECT_EQ(score(-50.0, 1e-6).sector, 11);
    EXPECT_EQ(score(-50.0, -1e-6).sector, 11);
    EXPECT_EQ(scoreAt(50.0, 189.0 + 1e-6).sector, 8);
    EXPECT_EQ(scoreAt(50.0, 189.0 - 1e-6).sector, 11);
}

TEST(Score, BoundaryDistances)
{
    // In the middle of sector 6 at 50 mm the nearest wire is 50 * sin(9 degrees) away, the nearest ring 34.1 mm.
    const auto s6 = score(50.0, 0.0);
    EXPECT_NEAR(s6.sector_boundary_distance_mm, 50.0 * std::sin(radians(9.0)), 1e-9);
    EXPECT_NEAR(s6.ring_boundary_distance_mm, 50.0 - 15.9, 1e-9);
    EXPECT_NEAR(s6.boundary_distance_mm, s6.sector_boundary_distance_mm, 1e-12);

    // Just inside the triple ring the ring boundary is nearest.
    const auto t6 = score(99.5, 0.0);
    EXPECT_NEAR(t6.boundary_distance_mm, 0.5, 1e-9);

    // The bulls have no radial wires.
    EXPECT_EQ(score(10.0, 0.0).sector_boundary_distance_mm, std::numeric_limits<double>::infinity());
    EXPECT_NEAR(score(10.0, 0.0).boundary_distance_mm, 3.65, 1e-9);

    // Near a wire the distance is small.
    EXPECT_LT(scoreAt(120.0, 9.0 - 0.1).sector_boundary_distance_mm, 0.21);
}

TEST(Score, MeasuredGeometry)
{
    BoardGeometry rotated;
    rotated.wire_rotation_deg = 18.0;
    // Rotating the wires by one sector moves sector 20 to where 5 was.
    EXPECT_EQ(scoreAt(50.0, 108.0, rotated).sector, 20);
    EXPECT_EQ(scoreAt(50.0, 90.0, rotated).sector, 1);

    BoardGeometry wide;
    wide.double_outer_radius_mm = 171.0;
    EXPECT_EQ(score(170.5, 0.0).ring, Ring::Miss);
    EXPECT_EQ(score(170.5, 0.0, wide).ring, Ring::Double);
}

TEST(Score, GeometryValidation)
{
    EXPECT_TRUE(BoardGeometry{}.isValid());
    BoardGeometry swapped;
    swapped.triple_inner_radius_mm = 110.0;
    EXPECT_FALSE(swapped.isValid());
    BoardGeometry undefined;
    undefined.wire_rotation_deg = std::numeric_limits<double>::quiet_NaN();
    EXPECT_FALSE(undefined.isValid());
}

TEST(Score, Labels)
{
    EXPECT_EQ(dartpilot::scoring::label(scoreAt(103.0, 90.0)), "T20");
    EXPECT_EQ(dartpilot::scoring::label(scoreAt(166.0, sectorMiddle_deg(18))), "D12");
    EXPECT_EQ(dartpilot::scoring::label(scoreAt(50.0, sectorMiddle_deg(1))), "S1");
    EXPECT_EQ(dartpilot::scoring::label(score(0.0, 0.0)), "50");
    EXPECT_EQ(dartpilot::scoring::label(score(10.0, 0.0)), "25");
    EXPECT_EQ(dartpilot::scoring::label(score(0.0, 180.0)), "miss");
}

// Every point of a 0.5 mm grid over the board against the independent reference
TEST(Score, MatchesReferenceOnAFineGrid)
{
    int checked = 0;
    for(double y = -175.0; y <= 175.0; y += 0.5)
    {
        for(double x = -175.0; x <= 175.0; x += 0.5)
        {
            const auto result = score(x, y);
            const double r = std::hypot(x, y);
            if(r < 15.9 || r >= 170.0)
            {
                continue;
            }
            ASSERT_EQ(result.sector, referenceSector(x, y)) << "at (" << x << ", " << y << ")";
            const int multiplier = (r >= 99.0 && r < 107.0) ? 3 : (r >= 162.0) ? 2 : 1;
            ASSERT_EQ(result.multiplier, multiplier) << "at (" << x << ", " << y << ")";
            ++checked;
        }
    }
    EXPECT_GT(checked, 350000);
}

TEST(Score, IsDeterministic)
{
    const auto a = score(-73.25, 41.5);
    const auto b = score(-73.25, 41.5);
    EXPECT_EQ(a.points, b.points);
    EXPECT_EQ(a.boundary_distance_mm, b.boundary_distance_mm);
}
