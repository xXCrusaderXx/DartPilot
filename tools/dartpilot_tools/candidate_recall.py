"""python -m dartpilot_tools.candidate_recall SESSION... --run RUN [--annotations SET] [--extrinsics FILE] [--out DIR]

Candidate recall (#26): for every annotated throw and every camera, whether one of the camera's tip candidates lies
within N pixels of where the true entry point appears in its image. The true point is projected with the engine's own
camera model (`dartpilot project`), so the tool and the engine never disagree on the lens. Candidates come from a
tracker replay (`dartpilot replay --pipeline tracker`), which writes the selected tip first and then every generated
candidate with its source. Also the axis error (#27): how far the true point lies from the line on the board on which
each camera sees the dart enter, which is what the location is made of. Writes report.md and candidates.csv.
"""

import argparse
import hashlib
import json
import math
import os
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

import pandas as pd

from dartpilot_tools.session import load_session

DEFAULT_EXTRINSICS = Path.home() / ".local/share/dartpilot/calibration/extrinsics.yml"
RADII_PX = (2, 5, 10, 20)
# The selected tip of a replay carries no source; every generated candidate does.
SELECTED = "selected"
SOURCES = (SELECTED, "axis_end", "contour_end", "skeleton_end")

Projector = Callable[[list[tuple[float, float]]], list[dict[str, tuple[float, float]]]]


def engine_projector(extrinsics: Path, dartpilot: str) -> Projector:
    """Projects board points with `dartpilot project`: per point, the pixel in each camera's image by camera id."""

    def project(points: list[tuple[float, float]]) -> list[dict[str, tuple[float, float]]]:
        if not points:
            return []
        lines = "".join(json.dumps({"x_mm": x, "y_mm": y}) + "\n" for x, y in points)
        out = subprocess.run(
            [dartpilot, "project", "--extrinsics", str(extrinsics)],
            input=lines,
            capture_output=True,
            text=True,
            check=True,
        )
        return [{k: (v[0], v[1]) for k, v in json.loads(line).items()} for line in out.stdout.splitlines()]

    return project


def truth_points(annotations: list[dict]) -> dict[str, tuple[float, float]]:
    """Board points of the annotated throws by throw id; rejected darts and field-only truths have none."""
    points = {}
    for a in annotations:
        if a.get("no_dart") or a.get("field_only") or a.get("action") == "rejected" or "x_mm" not in a:
            continue
        points[a["throw_id"]] = (float(a["x_mm"]), float(a["y_mm"]))
    return points


def candidate_rows(throws: list[dict], truths: dict[str, tuple[float, float]], project: Projector) -> pd.DataFrame:
    """One row per annotated throw and camera: the distance from the true point's image to the nearest candidate of
    each source (NaN where the camera has none) and to the nearest of all."""
    pairs = [(t, truths[t["throw_id"]]) for t in throws if t.get("throw_id") in truths and "correction" not in t]
    images = project([point for _, point in pairs])
    rows = []
    for (result, truth_mm), image in zip(pairs, images, strict=True):
        for m in result.get("camera_measurements", []):
            truth_px = image.get(m["camera"])
            if truth_px is None:
                continue
            row = {"throw_id": result["throw_id"], "camera": m["camera"], "state": m.get("state", "")}
            nearest: dict[str, float] = {}
            line = m.get("axis_line")
            row["axis_mm"] = (
                abs(line["a"] * truth_mm[0] + line["b"] * truth_mm[1] - line["c_mm"]) if line else float("nan")
            )
            for i, c in enumerate(m.get("tip_candidates", [])):
                source = c.get("source", SELECTED if i == m.get("selected_candidate") else "unknown")
                dx, dy = c["pixel_xy"][0] - truth_px[0], c["pixel_xy"][1] - truth_px[1]
                d = (dx * dx + dy * dy) ** 0.5
                nearest[source] = min(nearest.get(source, float("inf")), d)
            for source in SOURCES:
                row[source] = nearest.get(source, float("nan"))
            generated = [v for k, v in nearest.items() if k != SELECTED]
            row["generated"] = min(generated) if generated else float("nan")
            row["any"] = min(nearest.values()) if nearest else float("nan")
            rows.append(row)
    return pd.DataFrame(rows, columns=["throw_id", "camera", "state", "axis_mm", *SOURCES, "generated", "any"])


def recall_table(rows: pd.DataFrame, radii: tuple[int, ...] = RADII_PX) -> pd.DataFrame:
    """Share of camera views with a candidate of each source within each radius. Views where the camera saw no
    object count as misses, so recall is against every view of an annotated dart."""
    table = []
    for source in (*SOURCES, "generated", "any"):
        entry = {"source": source, "views": len(rows)}
        for r in radii:
            entry[f"<= {r} px"] = float((rows[source] <= r).mean()) if len(rows) else float("nan")
        table.append(entry)
    return pd.DataFrame(table)


def px_per_mm(project: Projector, points: list[tuple[float, float]]) -> dict[str, float]:
    """How many pixels a millimetre on the board spans in each camera near the annotated points, for reading radii
    against the truth's uncertainty."""
    if not points:
        return {}
    shifted = [p for x, y in points for p in ((x, y), (x + 1.0, y), (x, y + 1.0))]
    images = project(shifted)
    scale: dict[str, list[float]] = {}
    for i in range(0, len(images), 3):
        base, ex, ey = images[i], images[i + 1], images[i + 2]
        for camera, (u, v) in base.items():
            for shifted_px in (ex[camera], ey[camera]):
                scale.setdefault(camera, []).append(((shifted_px[0] - u) ** 2 + (shifted_px[1] - v) ** 2) ** 0.5)
    return {camera: sum(values) / len(values) for camera, values in scale.items()}


def _markdown(table: pd.DataFrame) -> str:
    """A table as Markdown, numbers with two decimals"""

    def cell(value) -> str:
        return f"{value:.2f}" if isinstance(value, float) else str(value)

    header = "| " + " | ".join(str(c) for c in table.columns) + " |"
    rule = "| " + " | ".join("-" for _ in table.columns) + " |"
    body = ["| " + " | ".join(cell(v) for v in row) + " |" for row in table.itertuples(index=False)]
    return "\n".join([header, rule, *body])


def report(rows: pd.DataFrame, scale: dict[str, float], sessions: list[str], run_id: str, annotation_set: str) -> str:
    lines = [
        "# Candidate recall",
        "",
        f"Run `{run_id}`, annotations `{annotation_set}`, sessions {', '.join(f'`{s}`' for s in sessions)}.",
        f"{rows['throw_id'].nunique() if len(rows) else 0} annotated throws, {len(rows)} camera views.",
        "",
        "Share of camera views with a candidate within the radius of the true entry point's image:",
        "",
        _markdown(recall_table(rows)),
        "",
        "Recall of all candidates together per camera (views where the camera saw an object, and all views):",
        "",
    ]
    per_camera = []
    for camera, group in rows.groupby("camera"):
        seen = group[group["any"].notna()]
        per_camera.append(
            {
                "camera": camera,
                "views": len(group),
                "seen": len(seen),
                "<= 10 px (seen)": float((seen["any"] <= 10).mean()) if len(seen) else float("nan"),
                "<= 10 px (all)": float((group["any"] <= 10).mean()),
                "px per mm": scale.get(camera, float("nan")),
            }
        )
    lines += [_markdown(pd.DataFrame(per_camera)), ""]
    if "axis_mm" in rows and rows["axis_mm"].notna().any():
        lines += [
            "Axis error: distance of the true point from the line on which each camera sees the dart enter (mm):",
            "",
            _markdown(axis_table(rows)),
            "",
        ]
    return "\n".join(lines)


def leave_one_out(throws: list[dict], min_crossing_deg: float = 15.0) -> pd.DataFrame:
    """Axis consistency without ground truth (#27): for every throw with axis lines from three or more cameras, how far
    each camera's line passes the point where the other cameras' lines cross. One row per throw and camera."""
    rows = []
    for t in throws:
        if "correction" in t:
            continue
        lines = {m["camera"]: m["axis_line"] for m in t.get("camera_measurements", []) if m.get("axis_line")}
        if len(lines) < 3:
            continue
        for camera, own in lines.items():
            others = [line for name, line in lines.items() if name != camera]
            point = _crossing(others, min_crossing_deg)
            if point is None:
                continue
            distance = abs(own["a"] * point[0] + own["b"] * point[1] - own["c_mm"])
            rows.append({"throw_id": t["throw_id"], "camera": camera, "axis_mm": distance})
    return pd.DataFrame(rows, columns=["throw_id", "camera", "axis_mm"])


def _crossing(lines: list[dict], min_crossing_deg: float) -> tuple[float, float] | None:
    """Least-squares crossing of lines a x + b y = c, or None if they cross too flatly to fix a point."""
    sxx = sxy = syy = sx = sy = 0.0
    for line in lines:
        a, b, c = line["a"], line["b"], line["c_mm"]
        sxx, sxy, syy, sx, sy = sxx + a * a, sxy + a * b, syy + b * b, sx + a * c, sy + b * c
    flattest = min(abs(p["a"] * q["b"] - p["b"] * q["a"]) for i, p in enumerate(lines) for q in lines[i + 1 :])
    det = sxx * syy - sxy * sxy
    if flattest < math.sin(math.radians(min_crossing_deg)) or abs(det) < 1e-12:
        return None
    return ((syy * sx - sxy * sy) / det, (sxx * sy - sxy * sx) / det)


def axis_table(rows: pd.DataFrame) -> pd.DataFrame:
    """Per camera and over all: views with an axis, median and 90th percentile of the axis error, share within 1 and
    2 mm."""
    table = []
    for name, group in [*rows.groupby("camera"), ("all", rows)]:
        errors = group["axis_mm"].dropna()
        table.append(
            {
                "camera": name,
                "views": len(errors),
                "median mm": float(errors.median()) if len(errors) else float("nan"),
                "P90 mm": float(errors.quantile(0.9)) if len(errors) else float("nan"),
                "<= 1 mm": float((errors <= 1).mean()) if len(errors) else float("nan"),
                "<= 2 mm": float((errors <= 2).mean()) if len(errors) else float("nan"),
            }
        )
    return pd.DataFrame(table)


def confidence_rows(throws: list[dict], project: Projector, min_cameras: int = 3) -> pd.DataFrame:
    """Calibration of the candidates' confidence and covariance (#28) without ground truth: for throws located by at
    least `min_cameras` cameras, the located point's image in each camera stands in for the tip. The location comes
    from the cameras' axis planes, not from the candidates, so it is an independent reference. Every generated
    candidate at the end of the dart nearest that image gives one row: its error in pixels, its squared Mahalanobis
    distance under its own covariance, and its confidence."""
    located = [
        t
        for t in throws
        if t.get("accepted")
        and t.get("board_point")
        and t.get("diagnostics", {}).get("cameras_agreeing", 0) >= min_cameras
    ]
    images = project([(t["board_point"]["x_mm"], t["board_point"]["y_mm"]) for t in located])
    rows = []
    for t, image in zip(located, images, strict=True):
        for m in t.get("camera_measurements", []):
            reference = image.get(m["camera"])
            generated = [c for c in m.get("tip_candidates", []) if c.get("source") and "covariance_px2" in c]
            if reference is None or not generated:
                continue
            nearest = min(generated, key=lambda c: math.dist(c["pixel_xy"], reference))
            # The candidates at the same end share one covariance, so the nearest one picks the end.
            for c in generated:
                if c["covariance_px2"] != nearest["covariance_px2"]:
                    continue
                e = (c["pixel_xy"][0] - reference[0], c["pixel_xy"][1] - reference[1])
                (a, b), (_, d) = c["covariance_px2"]
                det = a * d - b * b
                mahalanobis2 = (d * e[0] ** 2 - 2 * b * e[0] * e[1] + a * e[1] ** 2) / det if det > 0 else float("inf")
                rows.append(
                    {
                        "throw_id": t["throw_id"],
                        "camera": m["camera"],
                        "source": c["source"],
                        "error_px": math.hypot(*e),
                        "mahalanobis2": mahalanobis2,
                        "confidence": c["confidence"],
                    }
                )
    return pd.DataFrame(rows, columns=["throw_id", "camera", "source", "error_px", "mahalanobis2", "confidence"])


def calibration_tables(rows: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Error by confidence band, and how often the error lies within the stated 1 and 2 sigma ellipses (for a 2D
    normal error 39 % and 86 %)."""
    bands = [(0.6, 1.01, "0.6 – 1"), (0.4, 0.6, "0.4 – 0.6"), (0.2, 0.4, "0.2 – 0.4"), (0.0, 0.2, "0 – 0.2")]
    by_confidence = []
    for low, high, name in bands:
        group = rows[(rows["confidence"] >= low) & (rows["confidence"] < high)]
        by_confidence.append(
            {
                "confidence": name,
                "candidates": len(group),
                "median error px": float(group["error_px"].median()) if len(group) else float("nan"),
                "P90 error px": float(group["error_px"].quantile(0.9)) if len(group) else float("nan"),
            }
        )
    coverage = []
    for name, group in [*rows.groupby("source"), ("all", rows)]:
        coverage.append(
            {
                "source": name,
                "candidates": len(group),
                "within 1 sigma": float((group["mahalanobis2"] <= 1).mean()) if len(group) else float("nan"),
                "within 2 sigma": float((group["mahalanobis2"] <= 4).mean()) if len(group) else float("nan"),
            }
        )
    return pd.DataFrame(by_confidence), pd.DataFrame(coverage)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("sessions", nargs="+", type=Path)
    parser.add_argument("--run", required=True, help="a tracker replay run id")
    parser.add_argument("--annotations", default="corrections")
    parser.add_argument("--extrinsics", type=Path, default=DEFAULT_EXTRINSICS)
    parser.add_argument("--dartpilot", default=os.environ.get("DARTPILOT", "dartpilot"), help="the engine's CLI")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)

    project = engine_projector(args.extrinsics, args.dartpilot)
    digest = _sha256(args.extrinsics)
    frames, names, points, consistency, calibration = [], [], [], [], []
    for directory in args.sessions:
        session = load_session(directory)
        run = session.run(args.run)
        recorded = {c.get("extrinsics_sha256") for c in run.info.get("calibration", {}).values()} - {None}
        if recorded and digest not in recorded:
            print(
                f"warning: {session.id} was replayed with another board refinement than {args.extrinsics}",
                file=sys.stderr,
            )
        annotation_file = session.directory / "annotations" / f"{args.annotations}.jsonl"
        truths = truth_points(session.annotations(args.annotations)) if annotation_file.exists() else {}
        frames.append(candidate_rows(run.throws, truths, project))
        consistency.append(leave_one_out(run.throws))
        calibration.append(confidence_rows(run.throws, project))
        names.append(session.id)
        points += list(truths.values())
    rows = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    text = report(rows, px_per_mm(project, points), names, args.run, args.annotations)
    loo = pd.concat(consistency, ignore_index=True)
    if len(loo):
        text += (
            "\nAxis consistency without ground truth: for throws with axis lines from three or more cameras, how far "
            "each camera's line passes the crossing of the others' (mm):\n\n" + _markdown(axis_table(loo)) + "\n"
        )
    rated = pd.concat(calibration, ignore_index=True) if calibration else pd.DataFrame()
    if len(rated):
        by_confidence, coverage = calibration_tables(rated)
        text += (
            "\nConfidence against error, on throws located by three or more cameras (the located point's image "
            "stands in for the tip):\n\n"
            + _markdown(by_confidence)
            + "\n\nErrors within the candidates' own covariance:\n\n"
            + _markdown(coverage)
            + "\n"
        )
    print(text)
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "report.md").write_text(text + "\n")
        rows.to_csv(args.out / "candidates.csv", index=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
