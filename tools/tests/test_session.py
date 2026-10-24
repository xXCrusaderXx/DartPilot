"""The reader against the fixture session that tests/ReplayTest.cpp reads as well (tests/fixtures/session-v1)."""

import json
from pathlib import Path

import pytest

from dartpilot_tools.session import load_run, load_session

FIXTURE = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "session-v1"


@pytest.fixture
def session():
    return load_session(FIXTURE)


def test_manifest_and_cameras(session):
    assert session.id == "20261024T120000Z-fixt"
    assert [c.id for c in session.cameras] == ["usb-1.2", "usb-1.3"]
    a = session.camera("usb-1.2")
    assert a.info["calibration"]["extrinsics"] == {"file": "extrinsics.yml", "sha256": "22bb"}
    assert session.camera("usb-1.3").info["name"] == 'Cam B "quoted" é'
    with pytest.raises(KeyError):
        session.camera("usb-9")


def test_frames_and_the_truncated_tail(session):
    a = session.camera("usb-1.2")
    assert list(a.frames["sequence"]) == [1, 2, 3, 5]
    assert a.frames["exposure_ns"][1] == 5_033_333_333
    assert a.frames["pts"].isna().tolist() == [False, False, True, False]
    assert a.read_frame(a.frame_by_sequence(5)) == b"placeholder usb-1.2 frame 5\n"
    # The last JPEG of usb-1.3 never reached frames.mjpg completely.
    assert list(session.camera("usb-1.3").frames["sequence"]) == [11, 12]
    with pytest.raises(KeyError):
        a.frame_by_sequence(4)


def test_replay_order_matches_the_engine(session):
    order = session.replay_order()
    assert list(zip(order["camera"], order["sequence"], strict=True)) == [
        ("usb-1.2", 1),
        ("usb-1.3", 11),
        # Same exposure time: ordered by camera id
        ("usb-1.2", 2),
        ("usb-1.3", 12),
        ("usb-1.2", 3),
        ("usb-1.2", 5),
    ]


def test_throws_runs_and_annotations(session):
    assert list(session.throws["throw_id"]) == ["20261024T120000Z-fixt/1"]
    assert session.runs() == ["replay"]
    run = session.run("replay")
    assert run.info["config"]["calibration_check"]["frames"] == 10
    accepted, rejected = run.throws
    assert accepted["score"]["label"] == "T20"
    assert accepted["board_point"]["covariance_mm2"]["yy"] == 0.9
    # Every result points back to its source frames.
    for measurement in accepted["camera_measurements"]:
        camera = session.camera(measurement["camera"])
        for sequence in measurement["frames"]["baseline"] + measurement["frames"]["after"]:
            camera.frame_by_sequence(sequence)
    assert rejected["accepted"] is False and rejected["board_point"] is None
    checks = run.calibration_checks
    assert list(checks["camera"]) == ["usb-1.2", "usb-1.3"]
    assert checks["rms_mm"][0] == pytest.approx(0.4321)
    assert bool(checks["board_found"][1]) is False
    (truth,) = session.annotations("reference")
    assert truth["throw_id"] == accepted["throw_id"]
    assert session.annotations("missing") == []


def test_refuses_newer_versions_and_bad_names(tmp_path, session):
    copy = tmp_path / "session"
    copy.mkdir()
    manifest = json.loads((FIXTURE / "manifest.json").read_text())
    manifest["version"] = 2
    (copy / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(ValueError, match="newer"):
        load_session(copy)
    with pytest.raises(ValueError):
        load_run(session, "../x")
