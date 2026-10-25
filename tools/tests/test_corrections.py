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
