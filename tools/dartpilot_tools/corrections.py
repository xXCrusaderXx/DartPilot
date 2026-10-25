"""python -m dartpilot_tools.corrections SESSION [--run live] [--name corrections]

Turns the corrections players made while a session was recorded (#115) into ground-truth candidates: an annotation set
annotations/<name>.jsonl the benchmark reads. A corrected throw gets the point the player set, an added throw the dart
the engine missed; rejected throws are listed with "no_dart" and no point. A point set by tapping on a phone is much
less exact than an annotation, so the candidates carry a variance of about (3 mm)^2.
"""

import argparse
import json
import sys
from pathlib import Path

from dartpilot_tools.session import load_session

# A player's tap on the board drawing: a few millimetres
TAP_VARIANCE_MM2 = 9.0


def candidates(throws: list[dict]) -> list[dict]:
    """Ground-truth candidates from a live run's throws.jsonl; the last correction of each throw wins."""
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
        out.append(entry)
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m dartpilot_tools.corrections", description=__doc__.split("\n\n")[1])
    parser.add_argument("session", type=Path)
    parser.add_argument("--run", default="live", help="the recorded run with the corrections (default: live)")
    parser.add_argument("--name", default="corrections", help="annotation set to write (default: corrections)")
    args = parser.parse_args(argv)
    session = load_session(args.session)
    entries = candidates(session.run(args.run).throws)
    directory = session.directory / "annotations"
    directory.mkdir(exist_ok=True)
    path = directory / f"{args.name}.jsonl"
    with_points = [e for e in entries if not e.get("no_dart")]
    path.write_text("".join(json.dumps(e) + "\n" for e in with_points))
    print(f"{len(with_points)} candidates with a point, {len(entries) - len(with_points)} rejected, written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
