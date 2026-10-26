"""Candidate recall (#26) with a stand-in for the engine's projection."""

import math

from dartpilot_tools import candidate_recall as cr


def identity_projector(points):
    """Two cameras: one sees board millimetres as pixels, the other twice as large."""
    return [{"usb-1": (x, y), "usb-2": (2 * x, 2 * y)} for x, y in points]


def throw(throw_id, candidates_1, candidates_2):
    def measurement(camera, candidates):
        return {
            "camera": camera,
            "state": "seen" if candidates else "not_seen",
            "tip_candidates": candidates,
            "selected_candidate": 0 if candidates and "source" not in candidates[0] else None,
        }

    return {
        "throw_id": throw_id,
        "camera_measurements": [measurement("usb-1", candidates_1), measurement("usb-2", candidates_2)],
    }


def test_truth_points_leave_out_rejected_and_field_only():
    annotations = [
        {"throw_id": "s/1", "x_mm": 1.0, "y_mm": 2.0},
        {"throw_id": "s/2", "action": "rejected", "x_mm": 0.0, "y_mm": 0.0},
        {"throw_id": "s/3", "field_only": True, "x_mm": 0.0, "y_mm": 0.0},
        {"throw_id": "s/4", "no_dart": True},
    ]
    assert cr.truth_points(annotations) == {"s/1": (1.0, 2.0)}


def test_nearest_candidate_per_source_and_recall():
    truths = {"s/1": (10.0, 0.0), "s/2": (0.0, 50.0)}
    throws = [
        throw(
            "s/1",
            [
                {"pixel_xy": [13.0, 4.0]},
                {"pixel_xy": [10.0, 1.0], "source": "skeleton_end"},
                {"pixel_xy": [40.0, 0.0], "source": "axis_end"},
            ],
            [{"pixel_xy": [20.0, 3.0], "source": "contour_end"}],
        ),
        throw("s/2", [], [{"pixel_xy": [0.0, 100.0], "source": "axis_end"}]),
        {"throw_id": "s/9", "camera_measurements": []},
    ]
    rows = cr.candidate_rows(throws, truths, identity_projector)
    assert len(rows) == 4
    first = rows[(rows.throw_id == "s/1") & (rows.camera == "usb-1")].iloc[0]
    assert first["selected"] == 5.0
    assert first["skeleton_end"] == 1.0
    assert first["axis_end"] == 30.0
    assert math.isnan(first["contour_end"])
    assert first["generated"] == 1.0
    assert first["any"] == 1.0
    unseen = rows[(rows.throw_id == "s/2") & (rows.camera == "usb-1")].iloc[0]
    assert math.isnan(unseen["any"])

    table = cr.recall_table(rows, radii=(2, 5)).set_index("source")
    # Within 2 px: s/1 usb-1 (skeleton) and s/2 usb-2 (axis end, exact); the unseen view counts as a miss.
    assert table.loc["any", "<= 2 px"] == 0.5
    assert table.loc["any", "<= 5 px"] == 0.75
    assert table.loc["selected", "<= 5 px"] == 0.25


def test_px_per_mm_from_the_projection():
    scale = cr.px_per_mm(identity_projector, [(0.0, 0.0), (5.0, 5.0)])
    assert scale == {"usb-1": 1.0, "usb-2": 2.0}


def test_report_is_markdown_without_extra_packages():
    rows = cr.candidate_rows(
        [throw("s/1", [{"pixel_xy": [10.0, 0.0]}], [{"pixel_xy": [20.0, 0.0], "source": "axis_end"}])],
        {"s/1": (10.0, 0.0)},
        identity_projector,
    )
    text = cr.report(rows, {"usb-1": 1.0, "usb-2": 2.0}, ["s"], "tracker-026", "corrections")
    assert "| source | views | <= 2 px |" in text
    assert "| any | 2 | 1.00 |" in text
