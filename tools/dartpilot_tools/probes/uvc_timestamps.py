"""Compare driver timestamps with the camera's UVC PTS, from the CSV of tools/probes/uvc_timestamps.cpp.

The UVC PTS is the camera's own start-of-exposure time on its source clock (STC). SCR samples pair STC values
with host time, so a linear fit maps PTS onto the host's monotonic clock (ADR 0005).
"""

import argparse
import csv
from dataclasses import dataclass

import numpy as np

WRAP = 1 << 32


@dataclass
class TimestampReport:
    frames: int
    sequence_gaps: int
    driver_interval_std_ms: float
    pts_interval_ms: float
    pts_interval_std_ms: float
    stc_mhz: float
    driver_minus_pts_ms: tuple[float, float, float]


def unwrap32(values: np.ndarray) -> np.ndarray:
    """Removes the wrap-around of a 32-bit counter."""
    steps = np.diff(values, prepend=values[:1])
    return values + WRAP * np.cumsum(steps < -WRAP // 2)


def analyse(rows: list[list[str]]) -> TimestampReport:
    video = {int(r[1]): int(r[2]) for r in rows if r[0] == "video"}
    meta = [r for r in rows if r[0] == "meta"]
    stc = unwrap32(np.array([int(r[6]) for r in meta], dtype=np.int64))
    host = np.array([int(r[2]) for r in meta], dtype=np.int64)
    first_pts: dict[int, int] = {}
    for r in meta:
        if int(r[5]):
            first_pts.setdefault(int(r[1]), int(r[5]))
    frames = sorted(set(first_pts) & set(video))
    pts = unwrap32(np.array([first_pts[f] for f in frames], dtype=np.int64))
    driver = np.array([video[f] for f in frames], dtype=np.float64)

    slope, offset = np.polyfit(stc.astype(np.float64), host.astype(np.float64), 1)
    pts_host = slope * pts + offset
    pts_interval = np.diff(pts_host) / 1e6
    delta = (driver - pts_host) / 1e6
    seq = np.array(sorted(video))
    return TimestampReport(
        frames=len(video),
        sequence_gaps=int((np.diff(seq) != 1).sum()),
        driver_interval_std_ms=float((np.diff(driver) / 1e6).std()),
        pts_interval_ms=float(np.median(pts_interval)),
        pts_interval_std_ms=float(pts_interval.std()),
        stc_mhz=float(1e3 / slope),
        driver_minus_pts_ms=(float(np.median(delta)), float(delta.min()), float(delta.max())),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", nargs="+")
    for path in parser.parse_args().csv:
        with open(path, newline="") as f:
            rows = [r for r in csv.reader(f) if r and r[0] in ("video", "meta")]
        print(path, analyse(rows))


if __name__ == "__main__":
    main()
