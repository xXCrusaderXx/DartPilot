"""python -m dartpilot_tools.detection_test LOG [--sessions DIR]

Turns a detection test of the setup GUI (#197, ~/.local/share/dartpilot/detection-tests/<start>.jsonl) into a small
session without frames, as a reference run is stored: the darts as the run "detection-test" and the player's ratings as
the annotation set "ratings" (ADR 0011), so the benchmark scores it like any other run:

- a dart rated right is field-level truth at the engine's point ("field_only");
- a dart moved to another field, an abstention given its point, or a dart the engine missed is truth at the tapped
  point, with about (3 mm)^2 of variance;
- a dart rated "no dart" is listed with "no_dart".

Every entry has the flags of dartpilot_tools.annotation.flags; darts_in_board comes from the dart's place in its round.
"""

import argparse
import json
import sys
from pathlib import Path

from dartpilot_tools.annotation.flags import flags
from dartpilot_tools.corrections import TAP_VARIANCE_MM2

RUN_ID = "detection-test"
ANNOTATION_SET = "ratings"


def _point(value: dict | None) -> tuple[float, float] | None:
    return (value["x_mm"], value["y_mm"]) if value else None


def convert(log: list[dict], session_id: str) -> tuple[list[dict], list[dict]]:
    """The run's throws and the annotations of a detection-test log, keyed by "<session id>/<n>"."""
    darts: dict[str, dict] = {}
    order: list[str] = []
    for entry in log:
        kind = entry.get("type")
        if kind in ("throw", "missed"):
            darts[entry["id"]] = {"entry": entry, "outcome": "right" if entry.get("accepted") else "abstained"}
            if kind == "missed":
                darts[entry["id"]].update(outcome="missed", truth=_point(entry.get("truth")))
            order.append(entry["id"])
        elif kind == "rating" and entry["id"] in darts:
            darts[entry["id"]].update(outcome=entry["outcome"], truth=_point(entry.get("truth")))
        elif kind == "removed" and entry["id"] in darts:
            order.remove(entry["id"])
            del darts[entry["id"]]
    throws, annotations = [], []
    for n, key in enumerate(order, start=1):
        dart = darts[key]
        entry = dart["entry"]
        throw_id = f"{session_id}/{n}"
        cameras = [
            {"camera": f"camera-{c['camera']}", "state": c.get("state"), "used": bool(c.get("used"))}
            for c in entry.get("cameras", [])
        ]
        detected = entry.get("type") == "throw"
        if detected:
            throws.append(
                {
                    "throw_id": throw_id,
                    "accepted": bool(entry.get("accepted")),
                    "board_point": entry.get("board_point"),
                    "score": None,
                    "confidence": entry.get("confidence"),
                    "camera_measurements": cameras,
                    "diagnostics": {"reason": entry.get("reason") or None, "params_revision": entry.get("revision")},
                    "processing_latency_ms": entry.get("processing_ms"),
                }
            )
        record = {"throw_id": throw_id, "source": "detection-test", "outcome": dart["outcome"]}
        in_board = max(0, int(entry.get("position", 1)) - 1)
        if dart["outcome"] == "falseAlarm":
            record["no_dart"] = True
            record["flags"] = flags({"camera_measurements": cameras}, None, in_board)
        else:
            truth = dart.get("truth")
            if truth is None and dart["outcome"] == "right" and entry.get("board_point"):
                truth = _point(entry["board_point"])
                record["field_only"] = True
            if truth is None:
                # An abstention the player did not place: no truth
                continue
            record.update(x_mm=truth[0], y_mm=truth[1])
            if not record.get("field_only"):
                record["covariance_mm2"] = {"xx": TAP_VARIANCE_MM2, "xy": 0.0, "yy": TAP_VARIANCE_MM2}
            record["flags"] = flags({"camera_measurements": cameras}, truth, in_board)
        annotations.append(record)
    return throws, annotations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m dartpilot_tools.detection_test", description=__doc__.split("\n\n")[1]
    )
    parser.add_argument("log", type=Path, help="a detection test's <start>.jsonl")
    parser.add_argument(
        "--sessions",
        type=Path,
        default=Path.home() / ".local/share/dartpilot/sessions",
        help="where to store the session (default: ~/.local/share/dartpilot/sessions)",
    )
    args = parser.parse_args(argv)
    log = [json.loads(line) for line in args.log.read_text().splitlines() if line.strip()]
    start = next((e for e in log if e.get("type") == "start"), {})
    session_id = f"{args.log.stem}-dtst"
    throws, annotations = convert(log, session_id)
    directory = args.sessions / session_id
    (directory / "results" / RUN_ID).mkdir(parents=True, exist_ok=True)
    (directory / "annotations").mkdir(exist_ok=True)
    manifest = {
        "format": "dartpilot-session",
        "version": 1,
        "session_id": session_id,
        "created_utc": start.get("started_utc", ""),
        "notes": f"Detection test of the setup GUI ({args.log.name}); ratings by the player, no frames",
        "cameras": [],
    }
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    params = [e for e in log if e.get("type") == "params"]
    run = {
        "run_id": RUN_ID,
        "config": {"params": params[-1]["params"] if params else {}, "params_revisions": len(params)},
    }
    (directory / "results" / RUN_ID / "run.json").write_text(json.dumps(run, indent=2) + "\n")
    (directory / "results" / RUN_ID / "throws.jsonl").write_text("".join(json.dumps(t) + "\n" for t in throws))
    (directory / "annotations" / f"{ANNOTATION_SET}.jsonl").write_text(
        "".join(json.dumps(a) + "\n" for a in annotations)
    )
    print(f"{len(throws)} darts, {len(annotations)} rated, written to {directory}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
