"""python -m dartpilot_tools.corrections SESSION [--run live] [--name corrections] [--confirmed-name confirmed]

Turns the corrections players made while a session was recorded (#115) into ground truth (ADR 0011), two annotation
sets the benchmark reads:

- annotations/<name>.jsonl: a corrected throw gets the point the player set, an added throw the dart the engine
  missed; rejected throws are listed with "no_dart" and no point. A point set by tapping on a phone is much less exact
  than a measured one, so these carry a variance of about (3 mm)^2.
- annotations/<confirmed-name>.jsonl: the throws the engine placed and the player left alone. Their field is right,
  their millimetres unknown, so they carry "field_only" and count only for field accuracy.

Every entry has the flags of dartpilot_tools.annotation.flags: cut, occluded, near_wire, darts_in_board.
"""

import argparse
import json
import sys
from pathlib import Path

from dartpilot_tools.annotation.flags import darts_in_board, flags
from dartpilot_tools.session import load_session

# A player's tap on the board drawing: a few millimetres
TAP_VARIANCE_MM2 = 9.0


def candidates(throws: list[dict]) -> list[dict]:
    """Ground-truth candidates from a live run's throws.jsonl; the last correction of each throw wins."""
    detected = {r["throw_id"]: r for r in throws if "throw_id" in r and "correction" not in r}
    in_board = darts_in_board(throws)
    last: dict[str, dict] = {}
    order: list[str] = []
    for record in throws:
        correction = record.get("correction")
        if not correction:
            continue
        throw_id = record["throw_id"]
        if throw_id not in last:
            order.append(throw_id)
        last[throw_id] = correction
    out = []
    for throw_id in order:
        correction = last[throw_id]
        entry = {
            "throw_id": throw_id,
            "source": f"correction:{correction.get('client', '')}",
            "action": correction["action"],
        }
        point = correction.get("board_point")
        if correction["action"] == "rejected" or not point:
            entry["no_dart"] = True
        else:
            entry.update(
                x_mm=point["x_mm"],
                y_mm=point["y_mm"],
                covariance_mm2={"xx": TAP_VARIANCE_MM2, "xy": 0.0, "yy": TAP_VARIANCE_MM2},
            )
        truth = (point["x_mm"], point["y_mm"]) if point else None
        entry["flags"] = flags(detected.get(throw_id), truth, in_board.get(throw_id) if in_board else None)
        out.append(entry)
    return out


def confirmed(throws: list[dict]) -> list[dict]:
    """The throws the engine placed and the player left alone: field-level ground truth at the engine's point."""
    corrected = {r["throw_id"] for r in throws if "correction" in r}
    in_board = darts_in_board(throws)
    out = []
    for record in throws:
        if "throw_id" not in record or "correction" in record or record["throw_id"] in corrected:
            continue
        point = record.get("board_point")
        if not record.get("accepted") or not point:
            continue
        truth = (point["x_mm"], point["y_mm"])
        out.append(
            {
                "throw_id": record["throw_id"],
                "source": "confirmed",
                "field_only": True,
                "x_mm": truth[0],
                "y_mm": truth[1],
                "flags": flags(record, truth, in_board.get(record["throw_id"]) if in_board else None),
            }
        )
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m dartpilot_tools.corrections", description=__doc__.split("\n\n")[1])
    parser.add_argument("session", type=Path)
    parser.add_argument("--run", default="live", help="the recorded run with the corrections (default: live)")
    parser.add_argument("--name", default="corrections", help="annotation set to write (default: corrections)")
    parser.add_argument(
        "--confirmed-name", default="confirmed", help="set of the confirmed fields (default: confirmed)"
    )
    args = parser.parse_args(argv)
    session = load_session(args.session)
    throws = session.run(args.run).throws
    entries = candidates(throws)
    directory = session.directory / "annotations"
    directory.mkdir(exist_ok=True)
    path = directory / f"{args.name}.jsonl"
    with_points = [e for e in entries if not e.get("no_dart")]
    path.write_text("".join(json.dumps(e) + "\n" for e in with_points))
    fields = confirmed(throws)
    fields_path = directory / f"{args.confirmed_name}.jsonl"
    fields_path.write_text("".join(json.dumps(e) + "\n" for e in fields))
    print(
        f"{len(with_points)} candidates with a point, {len(entries) - len(with_points)} rejected, written to {path}; "
        f"{len(fields)} confirmed fields, written to {fields_path}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
