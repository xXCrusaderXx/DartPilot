"""python -m dartpilot_tools.timing SESSION... [--out docs/benchmarks/timing.md]

How synchronous the cameras are (#20, technical plan 5.1 experiment 1), from recorded sessions:

- From the frame times (mapped UVC PTS, ADR 0005): each camera's frame interval and its jitter, and per camera pair the
  offset between their frame grids over the session, split into a constant part, a drift and the jitter around them.
- From darts landing, an event every camera sees at the same instant: per camera the first frame that shows the
  impact. A camera whose grid is a phase φ after another's shows the impact in an earlier frame of its own (φ − T
  after the other's onset instead of φ) in a share φ / T of the impacts. That share measures the true phase without
  the timestamps; comparing it with the phase the timestamps give measures their error. It needs no extra hardware,
  but is only as precise as the number of impacts allows.

The cameras run free, so the offset between them is a phase within one frame period, which this measures. A shared
visible timing reference (a blinking LED) would measure it per frame; it is not needed for this report.
"""

import argparse
import itertools
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from dartpilot_tools.session import Session, load_session

# A frame differs from the one before when this many pixels at a quarter of the size change by more than 25 grey
# levels, as the live detection's local-change test (event_detection::moved)
LOCAL_LEVEL = 25
LOCAL_PIXELS = 30
# Frames before an impact that must be still, so a moving hand is not taken for one
STILL_BEFORE = 4


@dataclass
class Grid:
    camera: str
    exposure_ns: np.ndarray
    period_ms: float
    interval_p95_ms: float
    jitter_ms: float
    lost: int


def grid(session: Session, camera_id: str) -> Grid:
    """The camera's frame times from the mapped PTS, with its period and how evenly it keeps it."""
    frames = session.camera(camera_id).frames
    frames = frames[frames["timestamp_source"] == "pts"]
    t = frames["exposure_ns"].to_numpy(dtype=np.int64)
    intervals = np.diff(t) / 1e6
    period = float(np.median(intervals))
    # Gaps of more than one period are lost frames, not jitter
    regular = intervals[intervals < 1.5 * period]
    lost = int(np.sum(np.round(intervals[intervals >= 1.5 * period] / period) - 1))
    return Grid(camera_id, t, period, float(np.quantile(intervals, 0.95)), float(np.std(regular - period)), lost)


@dataclass
class PairOffset:
    a: str
    b: str
    # Frame of b nearest to each frame of a, b − a, in ms
    median_ms: float
    std_ms: float
    p95_abs_ms: float
    drift_ms_per_min: float
    # Around the constant offset and the drift
    jitter_ms: float
    samples: int


def pair_offset(a: Grid, b: Grid) -> PairOffset:
    j = np.clip(np.searchsorted(b.exposure_ns, a.exposure_ns), 1, len(b.exposure_ns) - 1)
    before, after = b.exposure_ns[j - 1], b.exposure_ns[j]
    nearest = np.where(np.abs(after - a.exposure_ns) < np.abs(a.exposure_ns - before), after, before)
    offset_ms = (nearest - a.exposure_ns) / 1e6
    # Drift moves the offset across ±T/2, where the nearest frame jumps by a period; unwrap it before fitting
    unwrapped = np.unwrap(offset_ms * 2 * math.pi / a.period_ms) * a.period_ms / (2 * math.pi)
    minutes = (a.exposure_ns - a.exposure_ns[0]) / 60e9
    slope, intercept = np.polyfit(minutes, unwrapped, 1) if len(minutes) > 1 else (0.0, float(unwrapped[0]))
    residual = unwrapped - (slope * minutes + intercept)
    return PairOffset(
        a.camera,
        b.camera,
        float(np.median(offset_ms)),
        float(np.std(offset_ms)),
        float(np.quantile(np.abs(offset_ms), 0.95)),
        float(slope),
        float(np.std(residual)),
        int(len(offset_ms)),
    )


def _small(session: Session, camera_id: str, row: int) -> np.ndarray:
    jpeg = session.camera(camera_id).read_frame(row)
    image = cv2.imdecode(np.frombuffer(jpeg, np.uint8), cv2.IMREAD_GRAYSCALE)
    return cv2.resize(image, None, fx=0.25, fy=0.25, interpolation=cv2.INTER_AREA).astype(np.int16)


def impact_onsets(session: Session) -> list[dict[str, int]]:
    """Per recorded throw, the exposure time of the first frame of each camera that shows the dart's impact, after
    frames that were still, searched from the start of the throw's window to its event (the still moment after it).
    Throws where a camera saw no clean onset are left out."""
    if session.throws.empty:
        return []
    out = []
    for _, throw in session.throws.iterrows():
        event = int(throw["event_ns"])
        onsets: dict[str, int] = {}
        for camera in session.cameras:
            frames = camera.frames
            rows = np.flatnonzero(
                (frames["exposure_ns"] >= int(throw["window_start_ns"])) & (frames["exposure_ns"] <= event)
            )
            previous, still = None, 0
            for row in rows:
                small = _small(session, camera.id, int(row))
                if previous is not None:
                    moved = int(np.count_nonzero(np.abs(small - previous) > LOCAL_LEVEL)) >= LOCAL_PIXELS
                    if moved and still >= STILL_BEFORE:
                        onsets[camera.id] = int(frames["exposure_ns"].iloc[row])
                        break
                    still = 0 if moved else still + 1
                previous = small
        if len(onsets) == len(session.cameras):
            out.append(onsets)
    return out


@dataclass
class EventPhase:
    a: str
    b: str
    impacts: int
    # Share of impacts that b showed in an earlier frame than a's onset frame + its phase
    earlier_share: float
    # The phase of b after a the timestamps give, averaged over the impacts, and how much later the impacts say it
    # really is: the timestamps' error of b against a
    phase_from_timestamps_ms: float
    timestamp_error_ms: float
    uncertainty_ms: float


def event_phase(onsets: list[dict[str, int]], a: Grid, b: Grid) -> EventPhase | None:
    """With b's grid a phase φ after a's (0 ≤ φ < T), the first frame of b that shows an impact is φ after a's in a
    share 1 − φ/T of the impacts, and φ − T (earlier) in a share φ/T. The share of earlier ones therefore measures
    the true φ; the timestamps give φ as the onset difference modulo T. Their mismatch is the timestamps' error."""
    if not onsets:
        return None
    period = a.period_ms
    differences = np.array([(o[b.camera] - o[a.camera]) / 1e6 for o in onsets])
    # Onsets a period or more apart are not the same impact
    differences = differences[np.abs(differences) < period]
    n = len(differences)
    if n == 0:
        return None
    earlier = differences < 0
    phase_ts = np.mod(differences, period)
    share = float(np.mean(earlier))
    return EventPhase(
        a.camera,
        b.camera,
        n,
        share,
        float(np.mean(phase_ts)),
        float(share * period - np.mean(phase_ts)),
        period * math.sqrt(max(share * (1 - share), 1.0 / n) / n),
    )


def report(sessions: list[Session]) -> str:
    lines = [
        "# Camera timing: data",
        "",
        "Tables of [camera-timing.md](camera-timing.md) (#20), generated by `python -m dartpilot_tools.timing` "
        "from the sessions listed; see the module's description for the method.",
        "",
    ]
    for session in sessions:
        ids = [c.id for c in session.cameras]
        grids = {c: grid(session, c) for c in ids}
        duration_min = (
            max(g.exposure_ns[-1] for g in grids.values()) - min(g.exposure_ns[0] for g in grids.values())
        ) / 60e9
        lines += [
            f"## {session.id}",
            "",
            f"{duration_min:.1f} min, {session.manifest.get('notes', '')}".rstrip(", "),
            "",
            "| Camera | Period | Interval P95 | Jitter (1 σ) | Lost frames |",
            "| - | - | - | - | - |",
        ]
        for g in grids.values():
            lines.append(
                f"| {g.camera} | {g.period_ms:.3f} ms | {g.interval_p95_ms:.2f} ms | {g.jitter_ms:.3f} ms | {g.lost} |"
            )
        lines += [
            "",
            "| Pair (b − a) | Offset median | Std | P95 abs | Drift | Jitter around offset and drift |",
            "| - | - | - | - | - | - |",
        ]
        for a, b in itertools.combinations(ids, 2):
            p = pair_offset(grids[a], grids[b])
            lines.append(
                f"| {b} − {a} | {p.median_ms:+.2f} ms | {p.std_ms:.2f} ms | {p.p95_abs_ms:.2f} ms "
                f"| {p.drift_ms_per_min:+.3f} ms/min | {p.jitter_ms:.3f} ms |"
            )
        onsets = impact_onsets(session)
        if onsets:
            lines += [
                "",
                f"Impacts seen by every camera: {len(onsets)}.",
                "",
                "| Pair (b − a) | Impacts | Phase from timestamps (mean) | Timestamp error from impacts | ± (1 σ) |",
                "| - | - | - | - | - |",
            ]
            for a, b in itertools.combinations(ids, 2):
                e = event_phase(onsets, grids[a], grids[b])
                if e:
                    lines.append(
                        f"| {b} − {a} | {e.impacts} | {e.phase_from_timestamps_ms:.1f} ms "
                        f"| {e.timestamp_error_ms:+.1f} ms | {e.uncertainty_ms:.1f} ms |"
                    )
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m dartpilot_tools.timing", description=__doc__.split("\n\n")[1])
    parser.add_argument("sessions", nargs="+", type=Path)
    parser.add_argument("--out", type=Path, help="write the report here instead of printing it")
    args = parser.parse_args(argv)
    text = report([load_session(s) for s in args.sessions])
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
