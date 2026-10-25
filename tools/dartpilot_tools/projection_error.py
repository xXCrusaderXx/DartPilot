"""python -m dartpilot_tools.projection_error SESSION... --run RUN --annotations SET [--calibration DIR] [--out DIR]

How well each camera on its own puts a dart on the board (#22): the error of each camera's board point (its tip
pixel's ray on the board plane) against the ground truth, per camera, by board region and by viewing angle. Writes
report.md, cameras.csv, error maps per camera and the error over the viewing angle.
"""

import argparse
import math
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

from dartpilot_tools.benchmark import metrics  # noqa: E402
from dartpilot_tools.scoring import score  # noqa: E402
from dartpilot_tools.session import load_session  # noqa: E402

DEFAULT_CALIBRATION = Path.home() / ".local/share/dartpilot/calibration"

# Ring boundaries of the nominal board in mm, for drawing
_RINGS_MM = [6.35, 15.9, 99.0, 107.0, 162.0, 170.0]


def _rotation(rvec: list[float]) -> np.ndarray:
    """Rodrigues: rotation vector to matrix."""
    theta = math.sqrt(sum(v * v for v in rvec))
    if theta < 1e-12:
        return np.eye(3)
    k = np.array(rvec) / theta
    kx = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(theta) * kx + (1 - math.cos(theta)) * kx @ kx


def camera_centres(extrinsics: Path) -> dict[str, np.ndarray]:
    """The centre of each refined camera in board coordinates (mm), by camera id (usb-<port>), from the board
    refinement's extrinsics.yml. Read without an OpenCV YAML parser: only the usb_port, rvec and tvec_mm fields."""
    text = extrinsics.read_text()
    centres = {}
    for block in re.split(r'usb_port:\s*"', text)[1:]:
        port = block.split('"', 1)[0]

        def vector(name: str, block: str = block) -> list[float] | None:
            m = re.search(name + r":\s*\[([^\]]*)\]", block, re.S)
            return [float(v) for v in m.group(1).replace("\n", " ").split(",")] if m else None

        rvec, tvec = vector("rvec"), vector("tvec_mm")
        if rvec is None or tvec is None:
            continue
        # The camera maps a board point p to R p + t; its centre is where that is zero.
        centres[f"usb-{port}"] = -_rotation(rvec).T @ np.array(tvec)
    return centres


def viewing_angle_deg(centre: np.ndarray, point_mm: tuple[float, float]) -> float:
    """Angle between the camera's line of sight to a board point and the board's normal: 0 straight on, towards 90
    for a grazing view."""
    sight = np.array([point_mm[0], point_mm[1], 0.0]) - centre
    return math.degrees(math.acos(abs(sight[2]) / np.linalg.norm(sight)))


def region(point_mm: tuple[float, float]) -> str:
    """The board region of a point for grouping: bull, inner single, triple, outer single, double, outside."""
    return {
        "inner_bull": "bull",
        "outer_bull": "bull",
        "inner_single": "inner single",
        "triple": "triple",
        "outer_single": "outer single",
        "double": "double",
    }.get(score(*point_mm).ring, "outside")


FUSED = "fused"


def _fused_pairs(session, run_id: str) -> list[metrics.Pair]:
    """The run's accepted throws with their fused point as the reference: how far each camera lies from what all
    cameras agreed on. A consistency check until there is ground truth, not an accuracy."""
    out = []
    for t in session.run(run_id).throws:
        point = t.get("board_point")
        if not t.get("accepted") or not point or "correction" in t:
            continue
        cameras = {
            m["camera"]: (m["board_point"]["x_mm"], m["board_point"]["y_mm"])
            for m in t.get("camera_measurements", [])
            if m.get("board_point")
        }
        out.append(
            metrics.Pair(
                t["throw_id"], True, (point["x_mm"], point["y_mm"]), (point["x_mm"], point["y_mm"]), None, cameras
            )
        )
    return out


def camera_table(sessions, run_id: str, annotation_set: str, centres: dict[str, np.ndarray]) -> pd.DataFrame:
    """One row per throw and camera that has its own board point: error, its radial and tangential part, the region
    of the true point, and the viewing angle where the camera's pose is known. `annotation_set` "fused" compares
    each camera with the run's fused point instead of ground truth."""
    rows = []
    for session in sessions:
        pairs = (
            _fused_pairs(session, run_id) if annotation_set == FUSED else metrics.pairs(session, run_id, annotation_set)
        )
        for pair in pairs:
            if pair.field_only:
                continue
            tx, ty = pair.truth_mm
            r = math.hypot(tx, ty)
            ux, uy = (tx / r, ty / r) if r > 1e-9 else (1.0, 0.0)
            for camera, (cx, cy) in pair.camera_points.items():
                dx, dy = cx - tx, cy - ty
                centre = centres.get(camera)
                rows.append(
                    {
                        "session": session.id,
                        "throw_id": pair.throw_id,
                        "camera": camera,
                        "truth_x_mm": tx,
                        "truth_y_mm": ty,
                        "x_mm": cx,
                        "y_mm": cy,
                        "error_mm": math.hypot(dx, dy),
                        "radial_mm": dx * ux + dy * uy,
                        "tangential_mm": -dx * uy + dy * ux,
                        "region": region(pair.truth_mm),
                        "viewing_angle_deg": viewing_angle_deg(centre, pair.truth_mm) if centre is not None else None,
                    }
                )
    return pd.DataFrame(rows)


def summary(table: pd.DataFrame) -> pd.DataFrame:
    """Per camera: count, median, P95 and maximum error, and the mean radial and tangential error (a bias)."""
    if table.empty:
        return pd.DataFrame(columns=["camera", "count", "median_mm", "p95_mm", "max_mm", "radial_mm", "tangential_mm"])
    grouped = table.groupby("camera")
    return pd.DataFrame(
        {
            "count": grouped.size(),
            "median_mm": grouped["error_mm"].median(),
            "p95_mm": grouped["error_mm"].quantile(0.95),
            "max_mm": grouped["error_mm"].max(),
            "radial_mm": grouped["radial_mm"].mean(),
            "tangential_mm": grouped["tangential_mm"].mean(),
        }
    ).reset_index()


def by_region(table: pd.DataFrame) -> pd.DataFrame:
    """Median error per camera and board region, regions as columns."""
    if table.empty:
        return pd.DataFrame()
    return table.pivot_table(index="camera", columns="region", values="error_mm", aggfunc="median")


def _board(ax) -> None:
    for radius in _RINGS_MM:
        ax.add_patch(plt.Circle((0, 0), radius, fill=False, color="#94a3b8", linewidth=0.6))
    for k in range(20):
        a = math.radians(9 + 18 * k)
        ax.plot(
            [15.9 * math.cos(a), 170 * math.cos(a)], [15.9 * math.sin(a), 170 * math.sin(a)], color="#cbd5e1", lw=0.5
        )
    ax.set_aspect("equal")
    ax.set_xlim(-185, 185)
    ax.set_ylim(-185, 185)
    ax.set_xticks([])
    ax.set_yticks([])


def plot_maps(table: pd.DataFrame, path: Path, exaggerate: float | None = None) -> None:
    """One board per camera: each true point coloured by that camera's error, with the error as an arrow drawn
    `exaggerate` times longer; by default so that the P95 error shows as about 25 mm."""
    cameras = sorted(table["camera"].unique())
    fig, axes = plt.subplots(1, len(cameras), figsize=(5 * len(cameras), 5.4), squeeze=False)
    vmax = max(1.0, float(table["error_mm"].quantile(0.95)))
    exaggerate = exaggerate or round(25 / vmax)
    for ax, camera in zip(axes[0], cameras, strict=True):
        rows = table[table["camera"] == camera]
        _board(ax)
        dots = ax.scatter(rows["truth_x_mm"], rows["truth_y_mm"], c=rows["error_mm"], cmap="viridis", vmin=0, vmax=vmax)
        ax.quiver(
            rows["truth_x_mm"],
            rows["truth_y_mm"],
            (rows["x_mm"] - rows["truth_x_mm"]) * exaggerate,
            (rows["y_mm"] - rows["truth_y_mm"]) * exaggerate,
            angles="xy",
            scale_units="xy",
            scale=1,
            width=0.004,
            color="#ef4444",
        )
        ax.set_title(f"{camera}: median {rows['error_mm'].median():.1f} mm", fontsize=10)
    fig.colorbar(dots, ax=axes[0].tolist(), label="error mm", shrink=0.8)
    fig.suptitle(f"Error of each camera's own board point (arrows ×{exaggerate:g})", fontsize=11)
    fig.savefig(path, dpi=110)
    plt.close(fig)


def plot_angle(table: pd.DataFrame, path: Path) -> None:
    """Error over the viewing angle, all cameras."""
    rows = table.dropna(subset=["viewing_angle_deg"])
    fig, ax = plt.subplots(figsize=(7, 4))
    for camera, group in rows.groupby("camera"):
        ax.scatter(group["viewing_angle_deg"], group["error_mm"], label=camera, s=14)
    ax.set_xlabel("viewing angle to the board normal (°)")
    ax.set_ylabel("error mm")
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)


def report(table: pd.DataFrame, run_id: str, annotation_set: str) -> str:
    lines = [f"# Single-camera projection error: run `{run_id}` against `{annotation_set}`", ""]
    if annotation_set == FUSED:
        lines += [
            "Against the run's fused point: how far each camera lies from the cameras' agreement, not from the truth.",
            "",
        ]
    if table.empty:
        return "\n".join(lines + ["No camera of the run has its own board point for a throw with ground truth."]) + "\n"
    s = summary(table)
    lines += [
        "| Camera | Throws | Median mm | P95 mm | Max mm | Mean radial mm | Mean tangential mm |",
        "| - | - | - | - | - | - | - |",
    ]
    for _, row in s.iterrows():
        lines.append(
            f"| {row['camera']} | {row['count']} | {row['median_mm']:.2f} | {row['p95_mm']:.2f} | {row['max_mm']:.2f} "
            f"| {row['radial_mm']:+.2f} | {row['tangential_mm']:+.2f} |"
        )
    regions = by_region(table)
    if not regions.empty:
        lines += ["", "Median error by region of the true point (mm):", ""]
        lines += ["| Camera | " + " | ".join(regions.columns) + " |", "| - |" + " - |" * len(regions.columns)]
        for camera, row in regions.iterrows():
            lines.append(f"| {camera} | " + " | ".join("–" if pd.isna(v) else f"{v:.2f}" for v in row) + " |")
    lines += ["", "![Error maps](error_maps.png)", ""]
    if table["viewing_angle_deg"].notna().any():
        lines += ["![Error over the viewing angle](error_angle.png)", ""]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m dartpilot_tools.projection_error", description=__doc__.split("\n\n")[1]
    )
    parser.add_argument("sessions", nargs="+", type=Path, help="session directories")
    parser.add_argument("--run", required=True, help="detection run id, results/<run id>/")
    parser.add_argument(
        "--annotations", required=True, help="annotation set(s), comma separated; 'fused' for the run's fused point"
    )
    parser.add_argument(
        "--calibration", type=Path, default=DEFAULT_CALIBRATION, help="directory with extrinsics.yml, for the angles"
    )
    parser.add_argument("--out", type=Path, default=Path("projection-error"), help="output directory")
    args = parser.parse_args(argv)

    extrinsics = args.calibration / "extrinsics.yml"
    centres = camera_centres(extrinsics) if extrinsics.exists() else {}
    table = camera_table([load_session(s) for s in args.sessions], args.run, args.annotations, centres)
    args.out.mkdir(parents=True, exist_ok=True)
    table.to_csv(args.out / "cameras.csv", index=False)
    if not table.empty:
        plot_maps(table, args.out / "error_maps.png")
        if table["viewing_angle_deg"].notna().any():
            plot_angle(table, args.out / "error_angle.png")
    (args.out / "report.md").write_text(report(table, args.run, args.annotations))
    print(args.out / "report.md")
    return 0 if not table.empty else 1


if __name__ == "__main__":
    sys.exit(main())
