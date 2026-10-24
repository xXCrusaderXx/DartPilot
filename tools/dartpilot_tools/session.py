"""Reader for recorded sessions and their results in the format of docs/replay-format.md."""

import json
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

SUPPORTED_VERSION = 1


@dataclass
class Camera:
    id: str
    info: dict
    directory: Path
    frames: pd.DataFrame
    clock: pd.DataFrame

    def read_frame(self, row: int) -> bytes:
        """JPEG bytes of the frame in index row `row`."""
        entry = self.frames.iloc[row]
        with open(self.directory / "frames.mjpg", "rb") as f:
            f.seek(int(entry["offset"]))
            return f.read(int(entry["size"]))

    def frame_by_sequence(self, sequence: int) -> int:
        """Index row of the frame with this V4L2 sequence number; result records refer to frames by it."""
        rows = self.frames.index[self.frames["sequence"] == sequence]
        if len(rows) == 0:
            raise KeyError(f"camera {self.id} has no frame {sequence}")
        return int(rows[0])


@dataclass
class Run:
    """One detection run over a session: results/<run id>/."""

    id: str
    directory: Path
    info: dict
    throws: list[dict]
    calibration_checks: pd.DataFrame


@dataclass
class Session:
    directory: Path
    manifest: dict
    cameras: list[Camera]
    health: pd.DataFrame
    throws: pd.DataFrame = field(default_factory=pd.DataFrame)

    @property
    def id(self) -> str:
        return self.manifest["session_id"]

    def camera(self, camera_id: str) -> Camera:
        for camera in self.cameras:
            if camera.id == camera_id:
                return camera
        raise KeyError(f"no camera {camera_id} in session {self.id}")

    def runs(self) -> list[str]:
        """Ids of the detection runs stored with the session, sorted."""
        results = self.directory / "results"
        return sorted(p.name for p in results.iterdir() if (p / "run.json").exists()) if results.is_dir() else []

    def run(self, run_id: str) -> "Run":
        return load_run(self, run_id)

    def annotations(self, name: str) -> list[dict]:
        """Ground-truth records of annotations/<name>.jsonl, one per throw."""
        return _read_jsonl(self.directory / "annotations" / f"{name}.jsonl")

    def replay_order(self) -> pd.DataFrame:
        """Frames of all cameras in the order a replay processes them: by exposure_ns, equal times by camera id.

        Columns: camera, row (index row in that camera's frames), sequence, exposure_ns.
        """
        parts = [
            pd.DataFrame(
                {
                    "camera": camera.id,
                    "row": range(len(camera.frames)),
                    "sequence": camera.frames["sequence"],
                    "exposure_ns": camera.frames["exposure_ns"],
                }
            )
            for camera in self.cameras
        ]
        if not parts:
            return pd.DataFrame(columns=["camera", "row", "sequence", "exposure_ns"])
        frames = pd.concat(parts, ignore_index=True)
        # Stable, so frames of one camera with equal times keep their recorded order, as in the C++ replay.
        return frames.sort_values(["exposure_ns", "camera"], kind="stable").reset_index(drop=True)


def _read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def load_session(directory: str | Path) -> Session:
    directory = Path(directory)
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest.get("format") != "dartpilot-session":
        raise ValueError(f"{directory} is not a DartPilot session")
    if manifest.get("version", 0) > SUPPORTED_VERSION:
        raise ValueError(f"session format version {manifest['version']} is newer than {SUPPORTED_VERSION}")
    cameras = []
    for info in manifest["cameras"]:
        camera_id = info["id"]
        # The id names a directory; it must not lead out of the session.
        if not camera_id or "/" in camera_id or camera_id in (".", ".."):
            raise ValueError(f"{directory}: camera without a valid id")
        camera_dir = directory / "cameras" / camera_id
        frames = pd.read_csv(camera_dir / "frames.csv", dtype={"timestamp_source": "string"})
        # A crash can leave an unindexed tail in frames.mjpg, never an index line without its JPEG.
        size = (camera_dir / "frames.mjpg").stat().st_size
        frames = frames[frames["offset"] + frames["size"] <= size].reset_index(drop=True)
        frames["pts"] = frames["pts"].astype("Int64")
        clock = pd.read_csv(camera_dir / "clock.csv")
        cameras.append(Camera(camera_id, info, camera_dir, frames, clock))
    health_path = directory / "capture.csv"
    health = pd.read_csv(health_path) if health_path.exists() else pd.DataFrame()
    throws_path = directory / "throws.csv"
    throws = pd.DataFrame()
    if throws_path.exists():
        throws = pd.read_csv(throws_path, dtype={"throw_id": "string", "source": "string"})
    return Session(directory, manifest, cameras, health, throws)


def load_run(session: Session, run_id: str) -> Run:
    """The results of one detection run: run.json, throws.jsonl and calibration_checks.jsonl."""
    if not run_id or "/" in run_id or run_id in (".", ".."):
        raise ValueError(f"invalid run id {run_id!r}")
    directory = session.directory / "results" / run_id
    info = json.loads((directory / "run.json").read_text())
    checks = pd.DataFrame(_read_jsonl(directory / "calibration_checks.jsonl"))
    return Run(run_id, directory, info, _read_jsonl(directory / "throws.jsonl"), checks)
