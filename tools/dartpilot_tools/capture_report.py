"""Capture health report of a recorded session: frame rate, losses, latency and timestamp quality per camera (#7)."""

import argparse
import json
from dataclasses import asdict, dataclass

import numpy as np

from dartpilot_tools.session import Camera, Session, load_session


@dataclass
class CameraReport:
    camera: str
    frames: int
    duration_s: float
    effective_fps: float
    lost_frames: int
    lost_rate: float
    overflow_drops: int
    pts_share: float
    latency_p50_ms: float
    latency_p95_ms: float
    interval_ms: float
    interval_jitter_ms: float
    max_queued: int
    brightness_min: float
    brightness_max: float


def camera_report(session: Session, camera: Camera) -> CameraReport:
    frames = camera.frames
    exposure = frames["exposure_ns"].to_numpy(dtype=np.int64)
    sequence = frames["sequence"].to_numpy(dtype=np.int64)
    pts = (frames["timestamp_source"] == "pts").to_numpy()
    lost = int(np.clip(np.diff(sequence) - 1, 0, None).sum())
    duration_s = float(exposure[-1] - exposure[0]) / 1e9 if len(exposure) > 1 else 0.0
    latency_ms = (frames["arrival_ns"].to_numpy(dtype=np.int64) - exposure) / 1e6
    # Intervals only between consecutive PTS frames: the switch from driver to PTS timestamps is a jump.
    consecutive = (np.diff(sequence) == 1) & pts[1:] & pts[:-1]
    intervals_ms = np.diff(exposure)[consecutive] / 1e6

    health = session.health
    health = health[health["camera"] == camera.id] if not health.empty else health
    overflow = int(health["overflow_drops"].max()) if not health.empty else 0
    if "summary" in camera.info:
        overflow = int(camera.info["summary"].get("overflow_drops", overflow))
    brightness = health["brightness"].dropna() if not health.empty else []

    return CameraReport(
        camera=camera.id,
        frames=len(frames),
        duration_s=duration_s,
        effective_fps=(len(frames) - 1) / duration_s if duration_s > 0 else 0.0,
        lost_frames=lost,
        lost_rate=lost / (len(frames) + lost) if len(frames) else 0.0,
        overflow_drops=overflow,
        pts_share=float(pts.mean()) if len(pts) else 0.0,
        latency_p50_ms=float(np.percentile(latency_ms, 50)) if len(latency_ms) else 0.0,
        latency_p95_ms=float(np.percentile(latency_ms, 95)) if len(latency_ms) else 0.0,
        interval_ms=float(intervals_ms.mean()) if len(intervals_ms) else 0.0,
        interval_jitter_ms=float(intervals_ms.std()) if len(intervals_ms) else 0.0,
        max_queued=int(health["queued"].max()) if not health.empty else 0,
        brightness_min=float(np.min(brightness)) if len(brightness) else float("nan"),
        brightness_max=float(np.max(brightness)) if len(brightness) else float("nan"),
    )


def report(session: Session) -> list[CameraReport]:
    return [camera_report(session, camera) for camera in session.cameras]


def markdown(session: Session, reports: list[CameraReport]) -> str:
    lines = [
        f"Session `{session.id}`, {session.manifest.get('notes') or 'no notes'}",
        "",
        "| Camera | Frames | Duration | FPS | Lost | Overflow | PTS | Latency P50 / P95 | Interval | Jitter "
        "| Max queued |",
        "| - | - | - | - | - | - | - | - | - | - | - |",
    ]
    for r in reports:
        lines.append(
            f"| {r.camera} | {r.frames} | {r.duration_s / 60:.1f} min | {r.effective_fps:.2f} | {r.lost_frames} "
            f"({100 * r.lost_rate:.2f} %) | {r.overflow_drops} | {100 * r.pts_share:.1f} % | "
            f"{r.latency_p50_ms:.2f} / {r.latency_p95_ms:.2f} ms | {r.interval_ms:.3f} ms | "
            f"{1000 * r.interval_jitter_ms:.1f} µs | {r.max_queued} |"
        )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sessions", nargs="+", help="session directories")
    parser.add_argument("--json", action="store_true", help="print JSON instead of a Markdown table")
    args = parser.parse_args()
    for path in args.sessions:
        session = load_session(path)
        reports = report(session)
        if args.json:
            print(json.dumps({"session": session.id, "cameras": [asdict(r) for r in reports]}, indent=2))
        else:
            print(markdown(session, reports))
            print()


if __name__ == "__main__":
    main()
