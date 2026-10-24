"""Reader for recorded sessions in the format of docs/replay-format.md."""

import json
from dataclasses import dataclass
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


@dataclass
class Session:
    directory: Path
    manifest: dict
    cameras: list[Camera]
    health: pd.DataFrame

    @property
    def id(self) -> str:
        return self.manifest["session_id"]


def load_session(directory: str | Path) -> Session:
    directory = Path(directory)
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest.get("format") != "dartpilot-session":
        raise ValueError(f"{directory} is not a DartPilot session")
    if manifest.get("version", 0) > SUPPORTED_VERSION:
        raise ValueError(f"session format version {manifest['version']} is newer than {SUPPORTED_VERSION}")
    cameras = []
    for info in manifest["cameras"]:
        camera_dir = directory / "cameras" / info["id"]
        frames = pd.read_csv(camera_dir / "frames.csv", dtype={"timestamp_source": "string"})
        # A crash can leave an unindexed tail in frames.mjpg, never an index line without its JPEG.
        size = (camera_dir / "frames.mjpg").stat().st_size
        frames = frames[frames["offset"] + frames["size"] <= size].reset_index(drop=True)
        frames["pts"] = frames["pts"].astype("Int64")
        clock = pd.read_csv(camera_dir / "clock.csv")
        cameras.append(Camera(info["id"], info, camera_dir, frames, clock))
    health_path = directory / "capture.csv"
    health = pd.read_csv(health_path) if health_path.exists() else pd.DataFrame()
    return Session(directory, manifest, cameras, health)
