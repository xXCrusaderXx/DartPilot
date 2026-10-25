"""Single-camera projection error (#22) against the fixture session (tests/fixtures/session-v1)."""

import math
from pathlib import Path

import numpy as np
import pytest

from dartpilot_tools import projection_error as pe
from dartpilot_tools.session import load_session

FIXTURE = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "session-v1"

# One camera 400 mm in front of the board's centre, looking straight at it, and one turned 90° about x
EXTRINSICS = """%YAML:1.0
---
refinement:
   cameras:
      -
         usb_port: "1.2"
         rvec: [ 0., 0., 0. ]
         tvec_mm: [ 0., 0.,
             400. ]
      -
         usb_port: "1.3"
         rvec: [ 1.5707963267948966, 0., 0. ]
         tvec_mm: [ 0., 0., 400. ]
"""


def test_camera_centres_from_the_refinement(tmp_path):
    path = tmp_path / "extrinsics.yml"
    path.write_text(EXTRINSICS)
    centres = pe.camera_centres(path)
    assert np.allclose(centres["usb-1.2"], [0, 0, -400])
    # Rotated 90° about x, the camera sits 400 mm along the board's y axis.
    assert np.allclose(centres["usb-1.3"], [0, -400, 0], atol=1e-9)


def test_viewing_angle():
    assert pe.viewing_angle_deg(np.array([0.0, 0.0, -400.0]), (0.0, 0.0)) == pytest.approx(0)
    assert pe.viewing_angle_deg(np.array([0.0, 0.0, -400.0]), (400.0, 0.0)) == pytest.approx(45)


def test_each_cameras_error_against_the_ground_truth(tmp_path):
    session = load_session(FIXTURE)
    run = session.runs()[0]
    (tmp_path / "extrinsics.yml").write_text(EXTRINSICS)
    table = pe.camera_table([session], run, "reference", pe.camera_centres(tmp_path / "extrinsics.yml"))
    # The fixture's throw 1: usb-1.2 put it at (12.1, 98.4), the truth is (12.0, 98.0).
    row = table[(table["throw_id"] == "20261024T120000Z-fixt/1") & (table["camera"] == "usb-1.2")].iloc[0]
    assert row["error_mm"] == pytest.approx(math.hypot(0.1, 0.4))
    assert row["region"] == "inner single"
    assert row["viewing_angle_deg"] == pytest.approx(math.degrees(math.atan(math.hypot(12, 98) / 400)))
    s = pe.summary(table)
    assert int(s[s["camera"] == "usb-1.2"]["count"].iloc[0]) >= 1


def test_the_command_writes_the_report(tmp_path):
    session = load_session(FIXTURE)
    (tmp_path / "extrinsics.yml").write_text(EXTRINSICS)
    out = tmp_path / "out"
    args = [str(FIXTURE), "--run", session.runs()[0], "--annotations", "reference"]
    assert pe.main([*args, "--calibration", str(tmp_path), "--out", str(out)]) == 0
    report = (out / "report.md").read_text()
    assert "| usb-1.2 |" in report
    assert (out / "error_maps.png").read_bytes()[:4] == b"\x89PNG"
    assert (out / "error_angle.png").exists()
    assert (out / "cameras.csv").exists()


def test_against_the_fused_point():
    session = load_session(FIXTURE)
    table = pe.camera_table([session], session.runs()[0], pe.FUSED, {})
    # The fixture's throw 1 was fused at (12.4, 98.1); usb-1.2 alone put it at (12.1, 98.4).
    row = table[table["throw_id"] == "20261024T120000Z-fixt/1"].iloc[0]
    assert row["error_mm"] == pytest.approx(math.hypot(0.3, 0.3))
    assert "not from the truth" in pe.report(table, "run", pe.FUSED)
