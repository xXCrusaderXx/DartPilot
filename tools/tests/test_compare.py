"""Comparing runs on the same throws (#25), against the fixture session (tests/fixtures/session-v1)."""

from pathlib import Path

from dartpilot_tools import compare
from dartpilot_tools.session import load_session

FIXTURE = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "session-v1"


def test_runs_are_compared_on_the_throws_they_share(tmp_path):
    session = load_session(FIXTURE)
    run = session.runs()[0]
    frames = compare.tables([session], {"a": run, "b": run}, "reference")
    assert list(frames["a"]["throw_id"]) == list(frames["b"]["throw_id"])
    table = compare.comparison(frames)
    assert list(table["run"]) == ["a", "b"]
    assert table["throws"].iloc[0] == len(frames["a"])


def test_the_command_writes_the_comparison(tmp_path):
    args = [str(FIXTURE), "--run", f"live={load_session(FIXTURE).runs()[0]}", "--annotations", "reference"]
    assert compare.main([*args, "--out", str(tmp_path)]) == 0
    text = (tmp_path / "comparison.md").read_text()
    assert "| live |" in text
    assert (tmp_path / "comparison_error.png").read_bytes()[:4] == b"\x89PNG"
