"""Flags of an annotated throw (#15): what made it hard, derived from the run that detected it.

- ``cut``: a camera saw the dart cut off by the image border;
- ``occluded``: a camera did not see it, or saw something its axis did not agree with (an earlier dart in the way);
- ``near_wire``: its true point is within 2 mm of a ring or sector wire;
- ``darts_in_board``: darts already in the board when it landed, from the takeouts the run recorded (None without).
"""

from dartpilot_tools.scoring import score

# As the benchmark's "near_boundary"
NEAR_WIRE_MM = 2.0


def darts_in_board(records: list[dict]) -> dict[str, int] | None:
    """Per throw id, the darts that were in the board before it: throws and added darts since the last takeout.
    None if the run recorded no takeouts, since then a visit's end is unknown."""
    if not any("takeout" in r for r in records):
        return None
    counts: dict[str, int] = {}
    in_board = 0
    for record in records:
        if "takeout" in record:
            in_board = 0
        elif "correction" in record:
            action = record["correction"].get("action")
            if action == "added":
                counts.setdefault(record["throw_id"], in_board)
                in_board += 1
            elif action == "rejected":
                in_board = max(0, in_board - 1)
        elif "throw_id" in record and record["throw_id"] not in counts:
            counts[record["throw_id"]] = in_board
            in_board += 1
    return counts


def camera_states(throw: dict | None) -> list[str]:
    """The state each camera had for the throw (seen, cut, not_seen, disagrees), as far as the run recorded it."""
    if not throw:
        return []
    return [
        m.get("state") or m.get("reason") or ("seen" if m.get("used") else "")
        for m in throw.get("camera_measurements", [])
    ]


def flags(throw: dict | None, truth_mm: tuple[float, float] | None, in_board: int | None) -> dict:
    states = camera_states(throw)
    result = {
        "cut": "cut" in states,
        "occluded": any(s in ("not_seen", "disagrees") for s in states),
        "near_wire": truth_mm is not None and score(*truth_mm).boundary_distance_mm < NEAR_WIRE_MM,
        "darts_in_board": in_board,
    }
    return result
