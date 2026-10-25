"""Benchmark metrics of a detection run against ground truth (technical plan, section 6.1)."""

import math
from dataclasses import dataclass

import numpy as np
import pandas as pd

from dartpilot_tools.scoring import score
from dartpilot_tools.session import Session

# A ground-truth point closer than this to a ring or sector boundary counts as "near a boundary"
NEAR_BOUNDARY_MM = 2.0


@dataclass
class Pair:
    """One throw of a run with its ground truth."""

    throw_id: str
    accepted: bool
    result_mm: tuple[float, float] | None
    truth_mm: tuple[float, float]
    latency_ms: float | None
    camera_points: dict[str, tuple[float, float]]
    # The truth knows the field only (a dart the player confirmed), not its millimetres
    field_only: bool = False
    flags: dict | None = None


def pairs(session: Session, run_id: str, annotation_set: str) -> list[Pair]:
    """The throws of a run that have ground truth, in the order of the annotations. annotation_set may name several
    sets separated by commas, e.g. "corrections,confirmed"."""
    # The throws the engine sent; a live run also holds the players' corrections and the takeouts.
    results = {t["throw_id"]: t for t in session.run(run_id).throws if "throw_id" in t and "correction" not in t}
    out = []
    truths = [truth for name in annotation_set.split(",") for truth in session.annotations(name.strip())]
    for truth in truths:
        if truth.get("no_dart"):
            continue
        result = results.get(truth["throw_id"])
        if result is None:
            continue
        point = result.get("board_point")
        cameras = {
            m["camera"]: (m["board_point"]["x_mm"], m["board_point"]["y_mm"])
            for m in result.get("camera_measurements", [])
            if m.get("board_point")
        }
        out.append(
            Pair(
                truth["throw_id"],
                bool(result.get("accepted")) and point is not None,
                (point["x_mm"], point["y_mm"]) if point else None,
                (truth["x_mm"], truth["y_mm"]),
                result.get("processing_latency_ms"),
                cameras,
                bool(truth.get("field_only")),
                truth.get("flags"),
            )
        )
    return out


def table(pairs_: list[Pair]) -> pd.DataFrame:
    """One row per throw: the error and its components, and how result and truth score."""
    rows = []
    for p in pairs_:
        truth = score(*p.truth_mm)
        row = {
            "throw_id": p.throw_id,
            "accepted": p.accepted,
            "truth_label": truth.label,
            "truth_ring": truth.ring,
            "near_boundary": truth.boundary_distance_mm < NEAR_BOUNDARY_MM,
            "field_only": p.field_only,
            "cut": bool((p.flags or {}).get("cut")),
            "occluded": bool((p.flags or {}).get("occluded")),
            "darts_in_board": (p.flags or {}).get("darts_in_board"),
            "latency_ms": p.latency_ms,
            "error_mm": math.nan,
            "radial_mm": math.nan,
            "tangential_mm": math.nan,
            "result_label": None,
        }
        if p.result_mm is not None and p.field_only:
            row["result_label"] = score(*p.result_mm).label
        elif p.result_mm is not None:
            dx, dy = p.result_mm[0] - p.truth_mm[0], p.result_mm[1] - p.truth_mm[1]
            r = math.hypot(*p.truth_mm)
            # Components along the radius through the true point and across it (counter-clockwise positive)
            ux, uy = (p.truth_mm[0] / r, p.truth_mm[1] / r) if r > 1e-9 else (1.0, 0.0)
            row.update(
                error_mm=math.hypot(dx, dy),
                radial_mm=dx * ux + dy * uy,
                tangential_mm=-dx * uy + dy * ux,
                result_label=score(*p.result_mm).label,
            )
        for camera, point in p.camera_points.items() if not p.field_only else []:
            row[f"camera_error_mm:{camera}"] = math.hypot(point[0] - p.truth_mm[0], point[1] - p.truth_mm[1])
        rows.append(row)
    return pd.DataFrame(rows)


def _quantiles(values: pd.Series) -> dict:
    v = values.dropna().to_numpy(dtype=float)
    if len(v) == 0:
        return {"count": 0, "median": None, "p90": None, "p95": None, "max": None}
    return {
        "count": int(len(v)),
        "median": float(np.median(v)),
        "p90": float(np.quantile(v, 0.9)),
        "p95": float(np.quantile(v, 0.95)),
        "max": float(v.max()),
    }


def summary(frame: pd.DataFrame) -> dict:
    """The core metrics of a table() as a JSON-friendly dict."""
    if frame.empty:
        return {"throws": 0}
    accepted = frame[frame["accepted"]]
    correct = accepted["result_label"] == accepted["truth_label"]
    multiplier_ok = accepted["result_label"].str[:1] == accepted["truth_label"].str[:1]
    result = {
        "throws": int(len(frame)),
        "accepted": int(len(accepted)),
        "abstention_rate": float(1.0 - len(accepted) / len(frame)),
        "segment_accuracy": float(correct.mean()) if len(accepted) else None,
        "multiplier_accuracy": float(multiplier_ok.mean()) if len(accepted) else None,
        # Accepted throws that score differently from the truth, as a share of all throws
        "false_acceptance_rate": float((~correct).sum() / len(frame)),
        "error_mm": _quantiles(accepted["error_mm"]),
        "radial_mm": {"mean": _mean(accepted["radial_mm"]), "median_abs": _median_abs(accepted["radial_mm"])},
        "tangential_mm": {
            "mean": _mean(accepted["tangential_mm"]),
            "median_abs": _median_abs(accepted["tangential_mm"]),
        },
        "latency_ms": _quantiles(frame["latency_ms"]),
        "groups": {},
        "cameras": {},
    }
    # Groups over all throws with ground truth, so that abstentions show where they happen
    in_board = (
        frame["darts_in_board"] if "darts_in_board" in frame else pd.Series([None] * len(frame), index=frame.index)
    )
    groups = {
        "near_boundary": frame["near_boundary"],
        "bull": frame["truth_ring"].isin(["inner_bull", "outer_bull"]),
        "double": frame["truth_ring"] == "double",
        "triple": frame["truth_ring"] == "triple",
        "cut": frame["cut"] if "cut" in frame else frame["near_boundary"] & False,
        "occluded": frame["occluded"] if "occluded" in frame else frame["near_boundary"] & False,
        "first dart": in_board == 0,
        "second dart": in_board == 1,
        "third dart": in_board >= 2,
    }
    for name, mask in groups.items():
        part = frame[mask.fillna(False).astype(bool)]
        if name.endswith("dart") and len(part) == 0:
            continue
        taken = part[part["accepted"]]
        result["groups"][name] = {
            "throws": int(len(part)),
            "accepted": int(len(taken)),
            "segment_accuracy": float((taken["result_label"] == taken["truth_label"]).mean()) if len(taken) else None,
            "error_mm": _quantiles(taken["error_mm"]),
        }
    for column in frame.columns:
        if column.startswith("camera_error_mm:"):
            result["cameras"][column.split(":", 1)[1]] = _quantiles(frame[column])
    return result


def _mean(values: pd.Series) -> float | None:
    v = values.dropna()
    return float(v.mean()) if len(v) else None


def _median_abs(values: pd.Series) -> float | None:
    v = values.dropna()
    return float(v.abs().median()) if len(v) else None


def frame_drop_rate(session: Session) -> float | None:
    """Lost and dropped frames as a share of all frames, from the capture health of the recording."""
    health = session.health
    if health.empty:
        return None
    last = health.groupby("camera").last()
    frames = last["frames"].sum()
    lost = last["lost_frames"].sum() + last["overflow_drops"].sum()
    return float(lost / (frames + lost)) if frames + lost > 0 else None
