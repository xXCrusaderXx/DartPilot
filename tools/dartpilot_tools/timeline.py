"""python -m dartpilot_tools.timeline SESSION [--run RUN] [--throw ID ...] [--out DIR] [--margin-ms MS]

Draws one timeline per throw (#21): a row per camera with every frame at its exposure time and its arrival at the
host, frames lost in between, the frames the detection run used before and after the dart, the throw's event window
and event time, and how each camera saw the dart. Written as PNG files, one per throw.
"""

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

from dartpilot_tools.session import Session, load_session  # noqa: E402


@dataclass
class CameraTimeline:
    camera: str
    # Frames inside the shown span: sequence, exposure_ns, arrival_ns
    frames: pd.DataFrame
    # Exposure times where frames are missing: a gap of more than 1.5 frame intervals, one entry per lost frame
    lost_ns: list[int] = field(default_factory=list)
    baseline: set[int] = field(default_factory=set)
    after: set[int] = field(default_factory=set)
    # The run's view of this camera: seen, cut, not_seen, disagrees; and whether its measurement counted
    state: str | None = None
    used: bool | None = None
    candidates: int = 0


@dataclass
class ThrowTimeline:
    throw_id: str
    event_ns: int
    start_ns: int
    end_ns: int
    window: tuple[int, int] | None
    cameras: list[CameraTimeline]
    result: dict | None = None


def _throw_row(session: Session, throw_id: str) -> pd.Series | None:
    if session.throws.empty:
        return None
    rows = session.throws[session.throws["throw_id"] == throw_id]
    return rows.iloc[0] if len(rows) else None


def throw_timeline(session: Session, throw_id: str, run: str | None = None, margin_ms: float = 500) -> ThrowTimeline:
    """The frames and decisions around one throw, `margin_ms` before and after its event window."""
    row = _throw_row(session, throw_id)
    result = None
    if run is not None:
        result = next((t for t in session.run(run).throws if t.get("throw_id") == throw_id and "accepted" in t), None)
    if row is not None:
        event_ns = int(row["event_ns"])
        window = (int(row["window_start_ns"]), int(row["window_end_ns"]))
    elif result is not None and result.get("diagnostics", {}).get("event_ns") is not None:
        event_ns = int(result["diagnostics"]["event_ns"])
        window = None
    else:
        raise KeyError(f"throw {throw_id} is neither in throws.csv nor in run {run}")
    margin_ns = int(margin_ms * 1e6)
    start_ns = (window[0] if window else event_ns) - margin_ns
    end_ns = (window[1] if window else event_ns) + margin_ns

    measurements = {m["camera"]: m for m in (result or {}).get("camera_measurements", [])}
    cameras = []
    for camera in session.cameras:
        frames = camera.frames
        intervals = frames["exposure_ns"].diff()
        typical = intervals.median() if len(frames) > 1 else None
        shown = frames[(frames["exposure_ns"] >= start_ns) & (frames["exposure_ns"] <= end_ns)]
        lost = []
        if typical and typical > 0:
            # A gap in the exposure times beyond 1.5 intervals; the sequence numbers say how many frames it held.
            for i in shown.index:
                if i == 0:
                    continue
                gap = frames.at[i, "sequence"] - frames.at[i - 1, "sequence"] - 1
                if gap > 0 or intervals.at[i] > 1.5 * typical:
                    count = max(int(gap), round(intervals.at[i] / typical) - 1)
                    step = intervals.at[i] / (count + 1)
                    lost += [int(frames.at[i - 1, "exposure_ns"] + step * (k + 1)) for k in range(count)]
        m = measurements.get(camera.id, {})
        cameras.append(
            CameraTimeline(
                camera=camera.id,
                frames=shown[["sequence", "exposure_ns", "arrival_ns"]].reset_index(drop=True),
                lost_ns=lost,
                baseline=set(m.get("frames", {}).get("baseline", [])),
                after=set(m.get("frames", {}).get("after", [])),
                state=m.get("state"),
                used=m.get("used"),
                candidates=len(m.get("tip_candidates", [])),
            )
        )
    return ThrowTimeline(throw_id, event_ns, start_ns, end_ns, window, cameras, result)


def _draw(ax, timeline: ThrowTimeline, start_ms: float, end_ms: float, zoomed: bool) -> None:
    def ms(ns: float) -> float:
        return (ns - timeline.event_ns) / 1e6

    if timeline.window:
        ax.axvspan(ms(timeline.window[0]), ms(timeline.window[1]), color="#38bdf8", alpha=0.08, label="event window")
    ax.axvline(0, color="#ef4444", linestyle="--", linewidth=1, label="event")
    for y, cam in enumerate(timeline.cameras):
        exposure = cam.frames["exposure_ns"].map(ms)
        arrival = cam.frames["arrival_ns"].map(ms)
        ax.vlines(exposure, y - 0.3, y + 0.3, color="#94a3b8", linewidth=0.8)
        # Delivery: from exposure to arrival at the host, readable only up close
        if zoomed:
            ax.hlines([y - 0.36] * len(exposure), exposure, arrival, color="#94a3b8", linewidth=0.8)
            ax.plot(arrival, [y - 0.36] * len(arrival), "|", color="#64748b", markersize=6, label="arrival at host")
        marked = [(cam.baseline, "#3b82f6", "baseline frames"), (cam.after, "#f59e0b", "after frames")]
        for sequences, colour, label in marked:
            chosen = cam.frames[cam.frames["sequence"].isin(sequences)]
            if len(chosen):
                ax.vlines(chosen["exposure_ns"].map(ms), y - 0.4, y + 0.4, color=colour, linewidth=2.2, label=label)
        if cam.lost_ns:
            ax.plot([ms(t) for t in cam.lost_ns], [y] * len(cam.lost_ns), "x", color="#ef4444", label="lost frame")
        if cam.state is not None and not zoomed:
            text = f"{cam.state}{' ✓' if cam.used else ''}" + (f", {cam.candidates} cand." if cam.candidates else "")
            ax.annotate(text, (1.005, y), xycoords=("axes fraction", "data"), va="center", fontsize=8)
    ax.set_yticks(range(len(timeline.cameras)), [c.camera for c in timeline.cameras])
    ax.set_ylim(-0.7, len(timeline.cameras) - 0.3)
    ax.set_xlim(start_ms, end_ms)


def plot(timeline: ThrowTimeline, path: Path, zoom_ms: float = 150) -> None:
    """Writes the timeline of one throw as a PNG: the whole span, and below it `zoom_ms` around the event, where
    the offsets between the cameras and each frame's delivery to the host show."""
    rows = len(timeline.cameras)
    fig, (overview, zoom) = plt.subplots(2, 1, figsize=(12, 2.4 + 1.8 * rows), height_ratios=[1, 1])
    span = ((timeline.start_ns - timeline.event_ns) / 1e6, (timeline.end_ns - timeline.event_ns) / 1e6)
    _draw(overview, timeline, *span, zoomed=False)
    _draw(zoom, timeline, -zoom_ms, zoom_ms, zoomed=True)
    zoom.set_xlabel("ms from the event")
    result = timeline.result
    if result is None:
        title = timeline.throw_id
    elif result.get("accepted"):
        label = (result.get("score") or {}).get("label", "")
        title = f"{timeline.throw_id}  {label}  conf {result.get('confidence', 0):.2f}"
    else:
        reason = (result.get("diagnostics") or {}).get("reason") or result.get("reason", "")
        title = f"{timeline.throw_id}  abstained: {reason}"
    overview.set_title(title, fontsize=10, loc="left")
    zoom.set_title(f"±{zoom_ms:.0f} ms around the event", fontsize=9, loc="left")
    # One legend entry per kind, however many cameras drew it
    handles, labels = [], []
    for ax in (overview, zoom):
        h, lab = ax.get_legend_handles_labels()
        handles += h
        labels += lab
    unique = dict(zip(labels, handles, strict=True))
    fig.legend(unique.values(), unique.keys(), loc="lower center", fontsize=7, ncols=7, frameon=False)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(path, dpi=120)
    plt.close(fig)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m dartpilot_tools.timeline", description=__doc__.split("\n\n")[1])
    parser.add_argument("session", type=Path, help="session directory")
    parser.add_argument("--run", help="detection run whose frames and camera states to show, results/<run id>/")
    parser.add_argument("--throw", action="append", dest="throws", help="throw id; all of throws.csv if left out")
    parser.add_argument("--out", type=Path, help="output directory (default: the run's or session's timeline/)")
    parser.add_argument("--margin-ms", type=float, default=500, help="time shown around the event window")
    args = parser.parse_args(argv)

    session = load_session(args.session)
    throws = args.throws
    if not throws:
        throws = list(session.throws["throw_id"]) if not session.throws.empty else []
        if not throws and args.run:
            throws = [t["throw_id"] for t in session.run(args.run).throws if "accepted" in t]
    if not throws:
        print(f"{args.session}: no throws", file=sys.stderr)
        return 1
    out = args.out or (session.directory / "results" / args.run if args.run else session.directory) / "timeline"
    out.mkdir(parents=True, exist_ok=True)
    for throw_id in throws:
        timeline = throw_timeline(session, throw_id, args.run, args.margin_ms)
        path = out / f"{throw_id.rsplit('/', 1)[-1]}.png"
        plot(timeline, path)
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
