import json

import numpy as np
import pytest

from dartpilot_tools.capture_report import report
from dartpilot_tools.session import load_session

FRAME_NS = 33_328_000


def write_session(root, sequences, truncate_last=False):
    session = root / "20261024T080000Z-abcd"
    camera_dir = session / "cameras" / "usb-1.2"
    camera_dir.mkdir(parents=True)
    manifest = {
        "format": "dartpilot-session",
        "version": 1,
        "session_id": "20261024T080000Z-abcd",
        "cameras": [{"id": "usb-1.2", "summary": {"overflow_drops": 2}}],
        "notes": "test",
    }
    (session / "manifest.json").write_text(json.dumps(manifest))
    lines = ["sequence,exposure_ns,timestamp_source,driver_ns,arrival_ns,pts,offset,size"]
    offset = 0
    for i, seq in enumerate(sequences):
        exposure = 1_000_000_000 + seq * FRAME_NS
        source = "driver" if i == 0 else "pts"
        pts = "" if i == 0 else str(seq * 500_000)
        lines.append(f"{seq},{exposure},{source},{exposure},{exposure + 31_000_000 + i * 1000},{pts},{offset},4")
        offset += 4
    (camera_dir / "frames.csv").write_text("\n".join(lines) + "\n")
    size = offset - (2 if truncate_last else 0)
    (camera_dir / "frames.mjpg").write_bytes(b"\xff\xd8\x00\x00" * (size // 4) + b"\xff\xd8"[: size % 4])
    (camera_dir / "clock.csv").write_text("sequence,camera_ticks,host_ns\n")
    health = ["time_ns,camera,frames,lost_frames,overflow_drops,pts_frames,effective_fps,latency_ms,queued,brightness"]
    health += [f"{t},usb-1.2,30,0,0,29,30.0,31.0,{q},{b}" for t, q, b in [(1, 3, 110.0), (2, 5, 112.5), (3, 1, "")]]
    (session / "capture.csv").write_text("\n".join(health) + "\n")
    return session


def test_report_counts_losses_and_timing(tmp_path):
    session = load_session(write_session(tmp_path, [1, 2, 3, 5, 6, 7, 10]))
    (r,) = report(session)
    assert r.frames == 7
    assert r.lost_frames == 3
    assert r.lost_rate == pytest.approx(3 / 10)
    assert r.overflow_drops == 2
    assert r.pts_share == pytest.approx(6 / 7)
    assert r.interval_ms == pytest.approx(FRAME_NS / 1e6)
    assert r.interval_jitter_ms == pytest.approx(0.0)
    assert r.latency_p50_ms == pytest.approx(31.003, abs=1e-3)
    assert r.max_queued == 5
    assert (r.brightness_min, r.brightness_max) == (110.0, 112.5)
    assert r.effective_fps == pytest.approx(6 / (9 * FRAME_NS / 1e9))


def test_index_lines_beyond_the_file_are_ignored(tmp_path):
    session = load_session(write_session(tmp_path, [1, 2, 3], truncate_last=True))
    assert len(session.cameras[0].frames) == 2
    assert session.cameras[0].read_frame(1)[:2] == b"\xff\xd8"
    assert np.issubdtype(session.cameras[0].frames["sequence"].dtype, np.integer)


def test_newer_format_is_refused(tmp_path):
    path = write_session(tmp_path, [1, 2])
    manifest = json.loads((path / "manifest.json").read_text())
    manifest["version"] = 2
    (path / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(ValueError, match="newer"):
        load_session(path)
