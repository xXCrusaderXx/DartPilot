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


def test_axis_error_is_the_distance_of_the_truth_from_each_cameras_line():
    t = throw("s/1", [{"pixel_xy": [3.0, 4.0]}], [])
    # usb-1 sees the dart enter on x = 2 mm, usb-2 has no axis
    t["camera_measurements"][0]["axis_line"] = {"a": 1.0, "b": 0.0, "c_mm": 2.0}
    rows = cr.candidate_rows([t], {"s/1": (3.5, 4.0)}, identity_projector)
    assert rows.set_index("camera").loc["usb-1", "axis_mm"] == 1.5
    assert math.isnan(rows.set_index("camera").loc["usb-2", "axis_mm"])
    table = cr.axis_table(rows).set_index("camera")
    assert table.loc["all", "views"] == 1
    assert table.loc["all", "<= 2 mm"] == 1.0


def test_leave_one_out_measures_each_camera_against_the_others():
    def measurement(camera, a, b, c):
        return {"camera": camera, "axis_line": {"a": a, "b": b, "c_mm": c}}

    # x = 0 and y = 0 cross at the origin; the third line x + y = 2 * sqrt(2) ... passes it by 2 mm
    s = 2**0.5 / 2
    t = {
        "throw_id": "s/1",
        "camera_measurements": [measurement("u1", 1, 0, 0), measurement("u2", 0, 1, 0), measurement("u3", s, s, 2)],
    }
    rows = cr.leave_one_out([t, {"throw_id": "s/2", "camera_measurements": []}]).set_index("camera")
    assert math.isclose(rows.loc["u3", "axis_mm"], 2.0)
    assert len(rows) == 3
    # Two lines alone leave nothing to check against.
    assert cr.leave_one_out([{"throw_id": "s/3", "camera_measurements": t["camera_measurements"][:2]}]).empty


def test_no_truth_gives_an_empty_table_not_an_error():
    rows = cr.candidate_rows([throw("s/1", [], [])], {}, identity_projector)
    assert rows.empty
    assert cr.recall_table(rows)["views"].tolist() == [0] * 6


def test_confidence_rows_use_the_located_point_as_reference_at_the_nearer_end():
    near = {
        "pixel_xy": [11.0, 0.0],
        "source": "axis_end",
        "covariance_px2": [[4.0, 0.0], [0.0, 1.0]],
        "confidence": 0.7,
    }
    same_end = {
        "pixel_xy": [10.0, 3.0],
        "source": "skeleton_end",
        "covariance_px2": [[4.0, 0.0], [0.0, 1.0]],
        "confidence": 0.7,
    }
    far_end = {
        "pixel_xy": [90.0, 0.0],
        "source": "axis_end",
        "covariance_px2": [[1.0, 0.0], [0.0, 1.0]],
        "confidence": 0.9,
    }
    t = {
        "throw_id": "s/1",
        "accepted": True,
        "board_point": {"x_mm": 10.0, "y_mm": 0.0},
        "diagnostics": {"cameras_agreeing": 3},
        "camera_measurements": [
            {"camera": "usb-1", "tip_candidates": [{"pixel_xy": [10.0, 0.0]}, near, same_end, far_end]},
        ],
    }
    two_cameras = dict(t, throw_id="s/2", diagnostics={"cameras_agreeing": 2})
    rows = cr.confidence_rows([t, two_cameras], identity_projector)
    assert sorted(rows["source"]) == ["axis_end", "skeleton_end"]
    by_source = rows.set_index("source")
    assert by_source.loc["axis_end", "error_px"] == 1.0
    assert math.isclose(by_source.loc["axis_end", "mahalanobis2"], 0.25)
    assert math.isclose(by_source.loc["skeleton_end", "mahalanobis2"], 9.0)
    by_confidence, coverage = cr.calibration_tables(rows)
    assert by_confidence.set_index("confidence").loc["0.6 – 1", "candidates"] == 2
    assert coverage.set_index("source").loc["all", "within 1 sigma"] == 0.5
