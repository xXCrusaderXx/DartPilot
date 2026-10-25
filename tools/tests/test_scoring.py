import json
import math
from pathlib import Path

from dartpilot_tools.scoring import score

CASES = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "scoring" / "cases.json"


def test_matches_the_engine_scorer_on_shared_cases():
    cases = json.loads(CASES.read_text())
    assert len(cases) > 500
    for case in cases:
        s = score(case["x_mm"], case["y_mm"])
        assert (s.label, s.points, s.multiplier, s.sector) == (
            case["label"],
            case["points"],
            case["multiplier"],
            case["sector"],
        ), case
        expected = case["boundary_distance_mm"]
        assert math.isclose(s.boundary_distance_mm, expected, abs_tol=1e-5) or (
            expected < 0 and math.isinf(s.boundary_distance_mm)
        ), case


def test_known_points():
    assert score(0.0, 103.0).label == "T20"
    assert score(0.0, 0.0).label == "50"
    assert score(0.0, 200.0).label == "miss"
