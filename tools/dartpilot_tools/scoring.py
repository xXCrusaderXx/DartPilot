"""Port of engine/scoring: board point in mm to sector and ring, for scoring ground truth in the benchmark.

It must give the same result as the C++ scorer for every point; tests/fixtures/scoring/cases.json holds points scored
by the engine, and both this module's tests and the C++ ScoringTest check them.
"""

import math
from dataclasses import dataclass

SECTORS_CLOCKWISE_FROM_TOP = (20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5)
SECTOR_WIDTH_DEG = 18.0


@dataclass(frozen=True)
class BoardGeometry:
    """Ring boundaries and wire rotation; the defaults are the nominal tournament dimensions."""

    bull_radius_mm: float = 6.35
    outer_bull_radius_mm: float = 15.9
    triple_inner_radius_mm: float = 99.0
    triple_outer_radius_mm: float = 107.0
    double_inner_radius_mm: float = 162.0
    double_outer_radius_mm: float = 170.0
    # Counter-clockwise rotation of the radial wires from their nominal angles 9 + k * 18 degrees
    wire_rotation_deg: float = 0.0


@dataclass(frozen=True)
class Score:
    ring: str
    sector: int
    multiplier: int
    points: int
    label: str
    ring_boundary_distance_mm: float
    sector_boundary_distance_mm: float
    boundary_distance_mm: float


_RINGS = ("inner_bull", "outer_bull", "inner_single", "triple", "outer_single", "double", "miss")


def score(x_mm: float, y_mm: float, geometry: BoardGeometry | None = None) -> Score:
    g = geometry or BoardGeometry()
    r_mm = math.hypot(x_mm, y_mm)
    boundaries = (
        g.bull_radius_mm,
        g.outer_bull_radius_mm,
        g.triple_inner_radius_mm,
        g.triple_outer_radius_mm,
        g.double_inner_radius_mm,
        g.double_outer_radius_mm,
    )
    # Half-open rings [inner, outer): a point on a boundary counts as further out.
    ring = _RINGS[sum(1 for b in boundaries if b <= r_mm)]
    ring_distance = min(abs(r_mm - b) for b in boundaries)
    # Angle relative to the wires, so that sector 6 spans [-9, 9) degrees
    phi_deg = (math.degrees(math.atan2(y_mm, x_mm)) - g.wire_rotation_deg) % 360.0
    from_boundary_deg = (phi_deg + SECTOR_WIDTH_DEG / 2.0) % 360.0
    counter_clockwise_index = min(int(from_boundary_deg / SECTOR_WIDTH_DEG), 19)
    sector = SECTORS_CLOCKWISE_FROM_TOP[(5 - counter_clockwise_index) % 20]
    if ring in ("inner_bull", "outer_bull", "miss"):
        sector_distance = math.inf
    else:
        into = from_boundary_deg - counter_clockwise_index * SECTOR_WIDTH_DEG
        sector_distance = r_mm * math.sin(math.radians(min(into, SECTOR_WIDTH_DEG - into)))
    multiplier, points, label, sector_out = 0, 0, "miss", 0
    if ring == "inner_bull":
        multiplier, points, label = 2, 50, "50"
    elif ring == "outer_bull":
        multiplier, points, label = 1, 25, "25"
    elif ring in ("inner_single", "outer_single"):
        multiplier, sector_out, label = 1, sector, f"S{sector}"
    elif ring == "triple":
        multiplier, sector_out, label = 3, sector, f"T{sector}"
    elif ring == "double":
        multiplier, sector_out, label = 2, sector, f"D{sector}"
    if sector_out:
        points = sector_out * multiplier
    return Score(
        ring, sector_out, multiplier, points, label, ring_distance, sector_distance, min(ring_distance, sector_distance)
    )
