"""python -m dartpilot_tools.benchmark SESSION... --run RUN --annotations SET [--out DIR]

Pairs the throws of a detection run with the ground truth of an annotation set, in one or more sessions, and writes
report.md, summary.json, throws.csv and plots into the output directory.
"""

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

from dartpilot_tools.benchmark import metrics, report
from dartpilot_tools.session import load_session


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m dartpilot_tools.benchmark", description=__doc__.split("\n\n")[1])
    parser.add_argument("sessions", nargs="+", type=Path, help="session directories")
    parser.add_argument("--run", required=True, help="detection run id, results/<run id>/")
    parser.add_argument("--annotations", required=True, help="annotation set, annotations/<set>.jsonl")
    parser.add_argument("--out", type=Path, default=Path("benchmark"), help="output directory (default: benchmark)")
    args = parser.parse_args(argv)

    frames = []
    drops = []
    for directory in args.sessions:
        session = load_session(directory)
        frame = metrics.table(metrics.pairs(session, args.run, args.annotations))
        frame.insert(0, "session", session.id)
        frames.append(frame)
        rate = metrics.frame_drop_rate(session)
        if rate is not None:
            drops.append(rate)
    frame = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    summary = metrics.summary(frame)
    summary["run"] = args.run
    summary["annotations"] = args.annotations
    summary["sessions"] = [str(s) for s in args.sessions]
    summary["frame_drop_rate"] = max(drops) if drops else None
    report.write(summary, frame, args.out, f"Benchmark: run {args.run} against {args.annotations}")
    json.dump({k: summary[k] for k in ("throws", "accepted") if k in summary}, sys.stdout)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
