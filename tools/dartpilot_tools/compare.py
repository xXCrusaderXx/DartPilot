"""python -m dartpilot_tools.compare SESSION... --run NAME=RUN_ID ... --annotations SET [--out DIR]

Compares several detection runs on exactly the same throws (#25, technical plan section 5.3, experiment 3): only
throws with ground truth that every run has a result for count, so a variant that abstains more is not compared on
easier throws. Writes comparison.md (median/P95 error, segment and multiplier accuracy, false acceptance and
abstention per run) and an error plot.
"""

import argparse
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

from dartpilot_tools.benchmark import metrics  # noqa: E402
from dartpilot_tools.session import load_session  # noqa: E402


def tables(sessions, runs: dict[str, str], annotation_set: str) -> dict[str, pd.DataFrame]:
    """Per run name, the benchmark table over the throws every run has, keyed by session and throw id."""
    frames = {}
    for name, run_id in runs.items():
        parts = []
        for session in sessions:
            frame = metrics.table(metrics.pairs(session, run_id, annotation_set))
            frame.insert(0, "session", session.id)
            parts.append(frame)
        frames[name] = pd.concat(parts, ignore_index=True) if parts else pd.DataFrame()
    keys = None
    for frame in frames.values():
        own = set(zip(frame.get("session", []), frame.get("throw_id", []), strict=True))
        keys = own if keys is None else keys & own
    keys = keys or set()
    return {
        name: frame[[(s, t) in keys for s, t in zip(frame["session"], frame["throw_id"], strict=True)]].reset_index(
            drop=True
        )
        if not frame.empty
        else frame
        for name, frame in frames.items()
    }


def comparison(frames: dict[str, pd.DataFrame]) -> pd.DataFrame:
    """One row per run with the core metrics of its summary"""
    rows = []
    for name, frame in frames.items():
        s = metrics.summary(frame)
        error = s.get("error_mm", {})
        rows.append(
            {
                "run": name,
                "throws": s.get("throws", 0),
                "median_mm": error.get("median"),
                "p95_mm": error.get("p95"),
                "segment_accuracy": s.get("segment_accuracy"),
                "multiplier_accuracy": s.get("multiplier_accuracy"),
                "false_acceptance_rate": s.get("false_acceptance_rate"),
                "abstention_rate": s.get("abstention_rate"),
            }
        )
    return pd.DataFrame(rows)


def _fmt(value, kind: str) -> str:
    if value is None or pd.isna(value):
        return "–"
    return f"{100 * value:.1f} %" if kind == "share" else f"{value:.2f}"


def report(table: pd.DataFrame, runs: dict[str, str], annotation_set: str) -> str:
    lines = [f"# Comparison against `{annotation_set}` on the same throws", ""]
    lines += [f"- `{name}`: run `{run_id}`" for name, run_id in runs.items()]
    throws = int(table["throws"].max()) if len(table) else 0
    lines += ["", f"{throws} throws with ground truth that every run has.", ""]
    lines += [
        "| Run | Median mm | P95 mm | Segment | Multiplier | False acceptance | Abstention |",
        "| - | - | - | - | - | - | - |",
    ]
    for _, row in table.iterrows():
        lines.append(
            f"| {row['run']} | {_fmt(row['median_mm'], 'mm')} | {_fmt(row['p95_mm'], 'mm')} "
            f"| {_fmt(row['segment_accuracy'], 'share')} | {_fmt(row['multiplier_accuracy'], 'share')} "
            f"| {_fmt(row['false_acceptance_rate'], 'share')} | {_fmt(row['abstention_rate'], 'share')} |"
        )
    lines += ["", "![Error per run](comparison_error.png)", ""]
    return "\n".join(lines)


def plot(frames: dict[str, pd.DataFrame], path: Path) -> None:
    """The error of the accepted throws per run, as box plots"""
    names = list(frames)
    data = [frames[n].loc[frames[n]["accepted"], "error_mm"].dropna().to_numpy() for n in names]
    fig, ax = plt.subplots(figsize=(max(5, 1.6 * len(names)), 4))
    ax.boxplot(data, tick_labels=names, showfliers=True)
    ax.set_ylabel("error mm (accepted throws)")
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m dartpilot_tools.compare", description=__doc__.split("\n\n")[1])
    parser.add_argument("sessions", nargs="+", type=Path, help="session directories")
    parser.add_argument("--run", action="append", required=True, help="NAME=RUN_ID, once per variant")
    parser.add_argument("--annotations", required=True, help="annotation set(s), comma separated")
    parser.add_argument("--out", type=Path, default=Path("comparison"), help="output directory")
    args = parser.parse_args(argv)

    runs = {}
    for item in args.run:
        name, _, run_id = item.partition("=")
        runs[name] = run_id or name
    frames = tables([load_session(s) for s in args.sessions], runs, args.annotations)
    table = comparison(frames)
    args.out.mkdir(parents=True, exist_ok=True)
    table.to_csv(args.out / "comparison.csv", index=False)
    plot(frames, args.out / "comparison_error.png")
    (args.out / "comparison.md").write_text(report(table, runs, args.annotations))
    print(args.out / "comparison.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
