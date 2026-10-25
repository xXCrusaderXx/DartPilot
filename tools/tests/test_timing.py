import numpy as np

from dartpilot_tools.timing import Grid, event_phase, pair_offset


def _grid(name: str, start_ms: float, n: int = 3000, period_ms: float = 33.328) -> Grid:
    t = (start_ms + np.arange(n) * period_ms) * 1e6
    return Grid(name, t.astype(np.int64), period_ms, period_ms, 0.0, 0)


def test_the_offset_between_two_grids_is_their_phase_and_does_not_drift():
    a, b = _grid("a", 0.0), _grid("b", 25.0)
    offset = pair_offset(a, b)
    assert abs(offset.median_ms - (25.0 - 33.328)) < 0.01
    assert abs(offset.drift_ms_per_min) < 1e-6
    assert offset.jitter_ms < 1e-6


def test_impacts_measure_the_true_phase_and_so_the_timestamps_error():
    period, phase_true, error = 33.328, 20.0, 4.0
    rng = np.random.default_rng(1)
    onsets = []
    for s in rng.uniform(1000.0, 2000.0, 4000):
        a_on = np.ceil(s / period) * period
        b_on = np.ceil((s - phase_true) / period) * period + phase_true
        # b's timestamps run 4 ms early: they say its frames come 4 ms before they do
        onsets.append({"a": int(a_on * 1e6), "b": int((b_on - error) * 1e6)})
    result = event_phase(onsets, _grid("a", 0.0), _grid("b", phase_true - error))
    assert abs(result.phase_from_timestamps_ms - (phase_true - error)) < 0.01
    assert abs(result.timestamp_error_ms - error) < 1.0
