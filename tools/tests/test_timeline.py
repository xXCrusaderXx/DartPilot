"""The throw timeline against the fixture session (tests/fixtures/session-v1)."""

from pathlib import Path

from dartpilot_tools import timeline
from dartpilot_tools.session import load_session

FIXTURE = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "session-v1"
THROW = "20261024T120000Z-fixt/1"


def test_frames_window_and_the_run_view_of_a_throw():
    session = load_session(FIXTURE)
    run = session.runs()[0]
    t = timeline.throw_timeline(session, THROW, run, margin_ms=100)
    assert t.event_ns == 5_050_000_000
    assert t.window == (4_900_000_000, 5_150_000_000)
    assert (t.start_ns, t.end_ns) == (4_800_000_000, 5_250_000_000)
    first = t.cameras[0]
    assert first.camera == "usb-1.2"
    # Every frame in the span, with its exposure and arrival
    assert list(first.frames.columns) == ["sequence", "exposure_ns", "arrival_ns"]
    assert all(t.start_ns <= e <= t.end_ns for e in first.frames["exposure_ns"])
    # The run's measurement of this camera: the frames before and after the dart, its state and candidates
    assert first.baseline == {1, 2}
    assert first.after == {5}
    assert first.candidates == 1


def test_a_lost_frame_shows_where_it_was_due():
    session = load_session(FIXTURE)
    t = timeline.throw_timeline(session, THROW, margin_ms=100)
    # Sequence 4 of usb-1.2 is missing: one lost frame between 3 and 5, at the time it was due
    lost = t.cameras[0].lost_ns
    assert len(lost) == 1
    assert abs(lost[0] - 5_100_000_000) < 1_000


def test_the_command_writes_one_picture_per_throw(tmp_path):
    session = load_session(FIXTURE)
    assert timeline.main([str(FIXTURE), "--run", session.runs()[0], "--throw", THROW, "--out", str(tmp_path)]) == 0
    picture = tmp_path / "1.png"
    assert picture.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
