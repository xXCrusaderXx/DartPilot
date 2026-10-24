import numpy as np

from dartpilot_tools.probes.uvc_timestamps import analyse, unwrap32


def test_unwrap32_continues_after_wrap():
    values = np.array([(1 << 32) - 10, (1 << 32) - 5, 3, 8], dtype=np.int64)
    assert list(unwrap32(values)) == [(1 << 32) - 10, (1 << 32) - 5, (1 << 32) + 3, (1 << 32) + 8]


def test_pts_mapped_to_host_clock():
    # 15 MHz device clock, host clock in ns with an offset; driver timestamps jitter by 4 ms.
    rows = []
    for seq in range(1, 31):
        stc = seq * 500_000
        host = 1_000_000_000 + round(stc * 1e3 / 15)
        rows.append(["meta", str(seq), str(host), "0", "0x8c", str(stc), str(stc), "0"])
        rows.append(["video", str(seq), str(host + (4_000_000 if seq % 3 == 0 else 0))])
    report = analyse(rows)
    assert report.sequence_gaps == 0
    assert abs(report.stc_mhz - 15.0) < 1e-6
    assert abs(report.pts_interval_ms - 1e3 / 30) < 1e-6
    assert report.pts_interval_std_ms < 1e-6
    assert report.driver_interval_std_ms > 1.0
