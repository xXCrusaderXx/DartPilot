from dartpilot_tools.corrections import TAP_VARIANCE_MM2, candidates


def test_the_last_correction_of_each_throw_wins_and_rejections_have_no_point():
    throws = [
        {"throw_id": "s/1", "accepted": True, "board_point": {"x_mm": 0.0, "y_mm": 100.0}},
        {
            "throw_id": "s/1",
            "correction": {"action": "corrected", "board_point": {"x_mm": 1.0, "y_mm": 60.0}, "client": "app"},
        },
        {
            "throw_id": "s/1",
            "correction": {"action": "corrected", "board_point": {"x_mm": 2.0, "y_mm": 61.0}, "client": "app"},
        },
        {"throw_id": "s/2", "accepted": False, "board_point": None},
        {"throw_id": "s/2", "correction": {"action": "rejected", "board_point": None, "client": "app"}},
        {
            "throw_id": "s/3",
            "correction": {"action": "added", "board_point": {"x_mm": -30.0, "y_mm": 0.0}, "client": "app"},
        },
    ]
    entries = candidates(throws)
    assert [e["throw_id"] for e in entries] == ["s/1", "s/2", "s/3"]
    assert (entries[0]["x_mm"], entries[0]["y_mm"]) == (2.0, 61.0)
    assert entries[0]["covariance_mm2"]["xx"] == TAP_VARIANCE_MM2
    assert entries[1]["no_dart"] is True
    assert entries[2]["source"] == "correction:app"


def test_flags_and_confirmed_fields_come_from_the_live_run():
    from dartpilot_tools.corrections import confirmed

    throws = [
        {
            "throw_id": "s/1",
            "accepted": True,
            "board_point": {"x_mm": 0.0, "y_mm": 105.0},
            "camera_measurements": [{"camera": "a", "used": True}, {"camera": "b", "used": False, "reason": "cut"}],
        },
        {
            "throw_id": "s/2",
            "accepted": False,
            "board_point": None,
            "camera_measurements": [{"camera": "a", "used": False, "reason": "disagrees"}],
        },
        {"throw_id": "s/2", "correction": {"action": "corrected", "board_point": {"x_mm": 0.0, "y_mm": 99.5}}},
        {"takeout": {"event_ns": 1, "darts_removed": 2}},
        {"throw_id": "s/3", "accepted": True, "board_point": {"x_mm": 30.0, "y_mm": 30.0}, "camera_measurements": []},
    ]
    corrected = candidates(throws)
    assert corrected[0]["flags"] == {"cut": False, "occluded": True, "near_wire": True, "darts_in_board": 1}
    fields = confirmed(throws)
    assert [f["throw_id"] for f in fields] == ["s/1", "s/3"]
    assert fields[0]["field_only"] is True
    assert fields[0]["flags"]["cut"] is True
    assert fields[0]["flags"]["darts_in_board"] == 0
    # The takeout starts a new visit.
    assert fields[1]["flags"]["darts_in_board"] == 0


def test_without_takeouts_the_dart_of_the_visit_is_unknown():
    throws = [{"throw_id": "s/1", "correction": {"action": "added", "board_point": {"x_mm": 1.0, "y_mm": 1.0}}}]
    assert candidates(throws)[0]["flags"]["darts_in_board"] is None


def test_a_detection_test_log_becomes_a_run_and_ratings():
    from dartpilot_tools.detection_test import convert

    camera = [{"camera": 1, "state": "seen", "used": True}, {"camera": 2, "state": "cut", "used": True}]
    log = [
        {"type": "start", "started_utc": "2026-10-25T10:48:00Z"},
        {
            "type": "throw",
            "id": "3",
            "position": 1,
            "accepted": True,
            "board_point": {"x_mm": 0.0, "y_mm": 60.0},
            "cameras": camera,
        },
        {
            "type": "throw",
            "id": "5",
            "position": 2,
            "accepted": True,
            "board_point": {"x_mm": 0.0, "y_mm": 120.0},
            "cameras": camera,
        },
        {"type": "rating", "id": "5", "outcome": "wrong", "truth": {"x_mm": 0.0, "y_mm": 100.0}},
        {"type": "throw", "id": "7", "position": 3, "accepted": False, "board_point": None, "cameras": camera},
        {"type": "missed", "id": "added-1", "position": 3, "truth": {"x_mm": 50.0, "y_mm": 0.0}},
        {"type": "missed", "id": "added-2", "position": 3, "truth": {"x_mm": 5.0, "y_mm": 0.0}},
        {"type": "removed", "id": "added-2"},
    ]
    throws, ratings = convert(log, "t")
    assert [t["throw_id"] for t in throws] == ["t/1", "t/2", "t/3"]
    by_id = {r["throw_id"]: r for r in ratings}
    assert by_id["t/1"]["field_only"] is True
    assert (by_id["t/2"]["y_mm"], by_id["t/2"].get("field_only")) == (100.0, None)
    assert by_id["t/2"]["flags"]["darts_in_board"] == 1
    # An abstention the player did not place has no truth; the missed dart has.
    assert "t/3" not in by_id
    assert by_id["t/4"]["outcome"] == "missed"
    assert len(ratings) == 3
