import io
import wave
from pathlib import Path

import numpy as np
import pytest

from dartpilot_tools import sounds

# The longest each sound may be: per-dart sounds short enough for three darts in quick succession, the game shot
# under a second and nothing longer than the match.
MAX_SECONDS = {
    "dart": 0.15,
    "miss": 0.15,
    "bust": 0.5,
    "visit": 0.5,
    "visit_high": 0.5,
    "one_eighty": 0.7,
    "leg": 1.0,
    "match": 1.5,
    "attention": 0.3,
}

ASSETS = Path(__file__).resolve().parents[2] / "ui" / "assets" / "sounds"


def test_every_recipe_has_a_level_and_a_bound():
    assert set(sounds.RECIPES) == set(sounds.LEVELS_DB) == set(MAX_SECONDS)


@pytest.mark.parametrize("name", list(sounds.RECIPES))
def test_generation_is_deterministic(name):
    assert sounds.wav_bytes(sounds.render(name)) == sounds.wav_bytes(sounds.render(name))


@pytest.mark.parametrize("name", list(sounds.RECIPES))
def test_length_and_level_are_within_bounds(name):
    samples = sounds.render(name)
    assert 0.05 < len(samples) / sounds.SAMPLE_RATE <= MAX_SECONDS[name]
    peak_db = 20 * np.log10(np.abs(samples.astype(float)).max() / 32767)
    assert peak_db == pytest.approx(sounds.LEVELS_DB[name], abs=0.1)
    assert peak_db <= -3
    # Faded out, so the sound ends without a click
    assert abs(int(samples[-1])) <= 1


def test_the_set_stays_small(tmp_path):
    paths = sounds.write_all(tmp_path)
    assert sum(p.stat().st_size for p in paths) < 400_000
    with wave.open(str(paths[0])) as w:
        assert (w.getnchannels(), w.getsampwidth(), w.getframerate()) == (1, 2, sounds.SAMPLE_RATE)


@pytest.mark.parametrize("name", list(sounds.RECIPES))
def test_the_app_ships_the_generated_sounds(name):
    # Within one step of the 16-bit scale, so a numpy release that rounds a sine differently does not fail this.
    with wave.open(io.BytesIO((ASSETS / f"{name}.wav").read_bytes())) as w:
        shipped = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(int)
    expected = sounds.render(name).astype(int)
    assert len(shipped) == len(expected)
    assert np.abs(shipped - expected).max() <= 1
