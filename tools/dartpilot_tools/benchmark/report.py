"""Benchmark report: Markdown for people, summary.json for comparing runs, and plots."""

import json
from pathlib import Path

import pandas as pd


def _fmt(value, digits: int = 2) -> str:
    if value is None:
        return "–"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def _pct(share, digits: int = 1) -> str:
    return "–" if share is None else f"{100 * share:.{digits}f} %"


def _q(q: dict, keys: tuple[str, ...]) -> str:
    return " / ".join(_fmt(q[k]) for k in keys) + " mm"


def markdown(summary: dict, title: str) -> str:
    lines = [f"# {title}", ""]
    if not summary.get("throws"):
        return "\n".join(lines + ["No throws with ground truth.", ""])
    radial, tangential, latency = summary["radial_mm"], summary["tangential_mm"], summary["latency_ms"]
    lines += [
        "| Metric | Value |",
        "| - | - |",
        f"| Throws with ground truth | {summary['throws']} |",
        f"| Accepted | {summary['accepted']} |",
        f"| Abstention rate | {_pct(summary['abstention_rate'])} |",
        f"| Segment accuracy (accepted) | {_pct(summary['segment_accuracy'])} |",
        f"| Multiplier accuracy (accepted) | {_pct(summary['multiplier_accuracy'])} |",
        f"| False acceptance rate | {_pct(summary['false_acceptance_rate'])} |",
        f"| Error median / P90 / P95 / max | {_q(summary['error_mm'], ('median', 'p90', 'p95', 'max'))} |",
        f"| Radial mean / median abs | {_fmt(radial['mean'])} / {_fmt(radial['median_abs'])} mm |",
        f"| Tangential mean / median abs | {_fmt(tangential['mean'])} / {_fmt(tangential['median_abs'])} mm |",
        f"| Latency P50 / P95 | {_fmt(latency['median'], 1)} / {_fmt(latency['p95'], 1)} ms |",
    ]
    if summary.get("frame_drop_rate") is not None:
        lines.append(f"| Frame drop rate | {_pct(summary['frame_drop_rate'], 3)} |")
    lines += [
        "",
        "## Groups",
        "",
        "| Group | Throws | Accepted | Segment accuracy | Error median / P90 |",
        "| - | - | - | - | - |",
    ]
    for name, g in summary["groups"].items():
        lines.append(
            f"| {name} | {g.get('throws', '–')} | {g['accepted']} | {_pct(g['segment_accuracy'])} "
            f"| {_q(g['error_mm'], ('median', 'p90'))} |"
        )
    if summary["cameras"]:
        lines += ["", "## Per camera", "", "| Camera | Throws | Error median / P90 |", "| - | - | - |"]
        for camera, q in summary["cameras"].items():
            lines.append(f"| {camera} | {q['count']} | {_q(q, ('median', 'p90'))} |")
    return "\n".join(lines + [""])


def plots(frame: pd.DataFrame, directory: Path) -> list[Path]:
    """An error histogram and the errors as vectors on the board, if matplotlib can draw without a display."""
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    written = []
    accepted = frame[frame["accepted"]]
    if accepted.empty:
        return written
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.hist(accepted["error_mm"].dropna(), bins=30)
    ax.set_xlabel("error (mm)")
    ax.set_ylabel("throws")
    path = directory / "error_histogram.png"
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)
    written.append(path)

    fig, ax = plt.subplots(figsize=(6, 6))
    ax.scatter(accepted["radial_mm"], accepted["tangential_mm"], s=12)
    ax.axhline(0, color="grey", linewidth=0.5)
    ax.axvline(0, color="grey", linewidth=0.5)
    ax.set_xlabel("radial error (mm, outwards +)")
    ax.set_ylabel("tangential error (mm, counter-clockwise +)")
    ax.set_aspect("equal")
    path = directory / "error_components.png"
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)
    written.append(path)
    return written


def write(summary: dict, frame: pd.DataFrame, directory: Path, title: str) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    frame.to_csv(directory / "throws.csv", index=False)
    (directory / "report.md").write_text(markdown(summary, title))
    plots(frame, directory)
