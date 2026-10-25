import json
import math
from pathlib import Path

import pytest

from dartpilot_tools.benchmark import metrics
from dartpilot_tools.benchmark.__main__ import main
from dartpilot_tools.session import load_session

FIXTURE = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "session-v1"


def test_pairs_the_run_with_the_ground_truth():
    session = load_session(FIXTURE)
    pairs = metrics.pairs(session, "replay", "reference")
    assert [p.throw_id for p in pairs] == ["20261024T120000Z-fixt/1"]
    frame = metrics.table(pairs)
    assert frame.loc[0, "error_mm"] == pytest.approx(math.hypot(0.4, 0.1))
    # The truth (12, 98) lies at about 98.7 mm; the result is 0.4 mm right and 0.1 mm up of it.
    assert frame.loc[0, "radial_mm"] == pytest.approx((0.4 * 12 + 0.1 * 98) / math.hypot(12, 98))
    assert frame.loc[0, "truth_label"] == "S20"
    assert frame.loc[0, "camera_error_mm:usb-1.2"] == pytest.approx(math.hypot(0.1, 0.4))


def test_summary_counts_abstentions_and_wrong_scores():
    pairs = [
        metrics.Pair("a/1", True, (0.0, 104.0), (0.0, 103.0), 40.0, {}),  # T20, right
        metrics.Pair("a/2", True, (0.0, 108.0), (0.0, 106.0), 45.0, {}),  # truth T20, result S20: wrong
        metrics.Pair("a/3", False, None, (0.0, 0.0), 30.0, {}),  # abstained on the bull
    ]
    s = metrics.summary(metrics.table(pairs))
    assert s["throws"] == 3
    assert s["accepted"] == 2
    assert s["abstention_rate"] == pytest.approx(1 / 3)
    assert s["segment_accuracy"] == pytest.approx(0.5)
    assert s["false_acceptance_rate"] == pytest.approx(1 / 3)
    assert s["error_mm"]["median"] == pytest.approx(1.5)
    assert s["radial_mm"]["mean"] == pytest.approx(1.5)
    assert s["groups"]["triple"]["accepted"] == 2


def test_command_writes_the_report(tmp_path):
    assert main([str(FIXTURE), "--run", "replay", "--annotations", "reference", "--out", str(tmp_path)]) == 0
    summary = json.loads((tmp_path / "summary.json").read_text())
    assert summary["throws"] == 1
    assert summary["frame_drop_rate"] is not None
    assert "Segment accuracy" in (tmp_path / "report.md").read_text()
    assert (tmp_path / "error_histogram.png").exists()


def test_field_only_truth_counts_for_the_field_but_not_the_millimetres():
    from dartpilot_tools.benchmark.metrics import Pair, summary, table

    pairs_ = [
        Pair("a", True, (0.0, 60.0), (0.0, 60.0), None, {}, field_only=True, flags={"darts_in_board": 0}),
        Pair("b", True, (0.0, 62.0), (0.0, 61.0), None, {}, flags={"occluded": True, "darts_in_board": 2}),
        Pair("c", False, None, (0.0, 61.0), None, {}, flags={"occluded": True, "darts_in_board": 1}),
    ]
    result = summary(table(pairs_))
    assert result["accepted"] == 2
    assert result["segment_accuracy"] == 1.0
    assert result["error_mm"]["count"] == 1
    assert result["groups"]["occluded"]["throws"] == 2
    assert result["groups"]["occluded"]["accepted"] == 1
    assert result["groups"]["first dart"]["throws"] == 1
    assert result["groups"]["third dart"]["accepted"] == 1
