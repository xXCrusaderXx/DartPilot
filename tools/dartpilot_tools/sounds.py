"""python -m dartpilot_tools.sounds [--out ui/assets/sounds]

Synthesises the player app's sound effects, so they are the project's own work under its licence and can be tuned
here instead of taken from sample libraries. The set is small and dry on purpose: a darts room has no music, crowd or
fanfare, and the score caller has priority over every effect.

Every sound is built from a few sines and filtered noise with exponential decays, then peak-normalised to its level
and written as 16-bit mono WAV at 22.05 kHz. Noise comes from a seeded generator, so the same code writes the same
files.

- `dart`: a dart lands: a soft low thud, as a dart in sisal. Band-passed noise (150 to 400 Hz) with a 25 ms decay, a
  90 Hz body with a 45 ms decay and a 2 ms click on top. The only sound per dart.
- `miss`: the same thud, duller (lower band, no click) and quieter, for a dart outside the scoring area.
- `bust`: two muted notes falling a minor third (220 Hz, then 185 Hz), each with a weak second harmonic and a 90 ms
  decay. Never a buzzer.
- `visit`, `visit_high`: the end of a visit when the caller is off: a soft two-note chime rising a fourth, the high one
  a tone higher for 100 or more. Sines with two quieter harmonics, 5 ms attack, 120 ms decay.
- `one_eighty`: a 180 when the caller is off: one bright tone at 1047 Hz with a short tail.
- `leg`: game shot: a warm rising C major triad (523, 659, 784 Hz) played as a quick arpeggio, each note two slightly
  detuned oscillators with soft harmonics, about 0.9 s.
- `match`: the same triad with the octave on top and a longer tail.
- `attention`: the engine asks the player to confirm a dart: a neutral tick-tick at 1.6 kHz.
"""

import argparse
import io
import wave
from collections.abc import Callable
from pathlib import Path

import numpy as np

SAMPLE_RATE = 22050
SEED = 132

# Peak level of each sound in dBFS. The playback volume is the app's; these keep the sounds in balance with each
# other, the per-dart thud well below the events.
LEVELS_DB = {
    "dart": -9.0,
    "miss": -15.0,
    "bust": -8.0,
    "visit": -10.0,
    "visit_high": -10.0,
    "one_eighty": -9.0,
    "leg": -6.0,
    "match": -6.0,
    "attention": -11.0,
}

FADE_OUT_S = 0.01


def _time(duration_s: float) -> np.ndarray:
    return np.arange(round(duration_s * SAMPLE_RATE)) / SAMPLE_RATE


def _decay(t: np.ndarray, tau_s: float) -> np.ndarray:
    return np.exp(-t / tau_s)


def _attack(t: np.ndarray, attack_s: float) -> np.ndarray:
    return np.clip(t / attack_s, 0.0, 1.0)


def _bandpass(x: np.ndarray, centre_hz: float, q: float) -> np.ndarray:
    """RBJ band-pass biquad (constant peak gain), run sample by sample so the result does not depend on an FFT"""
    w = 2 * np.pi * centre_hz / SAMPLE_RATE
    alpha = np.sin(w) / (2 * q)
    a0 = 1 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2 * np.cos(w) / a0, (1 - alpha) / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi
        y2, y1 = y1, yi
        y[i] = yi
    return y


def _tone(t: np.ndarray, freq_hz: float, harmonics: tuple[float, ...] = (), detune_cents: float = 0.0) -> np.ndarray:
    """A sine with quieter harmonics (amplitudes of the 2nd, 3rd, ... partial), optionally as two detuned voices"""

    def voice(f: float) -> np.ndarray:
        out = np.sin(2 * np.pi * f * t)
        for k, amp in enumerate(harmonics, start=2):
            out += amp * np.sin(2 * np.pi * f * k * t)
        return out

    if detune_cents == 0.0:
        return voice(freq_hz)
    ratio = 2 ** (detune_cents / 1200)
    return 0.5 * (voice(freq_hz * ratio) + voice(freq_hz / ratio))


def _place(total_s: float, parts: list[tuple[float, np.ndarray]]) -> np.ndarray:
    """Mixes each (start in s, samples) into a buffer of `total_s`"""
    out = np.zeros(round(total_s * SAMPLE_RATE))
    for start_s, samples in parts:
        i = round(start_s * SAMPLE_RATE)
        n = min(len(samples), len(out) - i)
        out[i : i + n] += samples[:n]
    return out


def _thud(rng: np.random.Generator, centre_hz: float, click: float, duration_s: float) -> np.ndarray:
    t = _time(duration_s)
    noise = _bandpass(rng.standard_normal(len(t)), centre_hz, q=1.2) * _decay(t, 0.025)
    body = np.sin(2 * np.pi * 90 * t) * _decay(t, 0.045) * _attack(t, 0.002)
    tick = _bandpass(rng.standard_normal(len(t)), 2500, q=0.8) * _decay(t, 0.002)
    return 1.6 * noise / max(np.abs(noise).max(), 1e-9) + 0.8 * body + click * tick / max(np.abs(tick).max(), 1e-9)


def dart(rng: np.random.Generator) -> np.ndarray:
    return _thud(rng, centre_hz=250, click=0.35, duration_s=0.12)


def miss(rng: np.random.Generator) -> np.ndarray:
    return _thud(rng, centre_hz=170, click=0.0, duration_s=0.10)


def _muted_note(freq_hz: float, duration_s: float) -> np.ndarray:
    t = _time(duration_s)
    return _tone(t, freq_hz, harmonics=(0.25,)) * _decay(t, 0.09) * _attack(t, 0.004)


def bust(rng: np.random.Generator) -> np.ndarray:
    return _place(0.45, [(0.0, _muted_note(220, 0.45)), (0.15, _muted_note(185, 0.3))])


def _chime(low_hz: float) -> np.ndarray:
    def note(freq_hz: float, duration_s: float) -> np.ndarray:
        t = _time(duration_s)
        return _tone(t, freq_hz, harmonics=(0.3, 0.1)) * _decay(t, 0.12) * _attack(t, 0.005)

    return _place(0.4, [(0.0, 0.8 * note(low_hz, 0.4)), (0.1, note(low_hz * 4 / 3, 0.3))])


def visit(rng: np.random.Generator) -> np.ndarray:
    return _chime(587.3)


def visit_high(rng: np.random.Generator) -> np.ndarray:
    return _chime(659.3)


def one_eighty(rng: np.random.Generator) -> np.ndarray:
    t = _time(0.6)
    return _tone(t, 1046.5, harmonics=(0.35, 0.15, 0.05)) * _decay(t, 0.16) * _attack(t, 0.003)


def _triad(freqs_hz: list[float], step_s: float, tail_s: float) -> np.ndarray:
    total = step_s * (len(freqs_hz) - 1) + tail_s
    parts = []
    for i, f in enumerate(freqs_hz):
        t = _time(total - i * step_s)
        # The upper partials fade faster than the fundamental, which keeps the chord warm instead of bright.
        tone = _tone(t, f, detune_cents=3) + 0.2 * _tone(t, 2 * f) * _decay(t, 0.08)
        parts.append((i * step_s, tone * _decay(t, tail_s / 3.5) * _attack(t, 0.008)))
    return _place(total, parts)


def leg(rng: np.random.Generator) -> np.ndarray:
    return _triad([523.3, 659.3, 784.0], step_s=0.08, tail_s=0.74)


def match(rng: np.random.Generator) -> np.ndarray:
    return _triad([523.3, 659.3, 784.0, 1046.5], step_s=0.1, tail_s=1.0)


def attention(rng: np.random.Generator) -> np.ndarray:
    t = _time(0.03)
    tick = np.sin(2 * np.pi * 1600 * t) * _decay(t, 0.008) * _attack(t, 0.001)
    return _place(0.22, [(0.0, tick), (0.12, tick)])


RECIPES: dict[str, Callable[[np.random.Generator], np.ndarray]] = {
    "dart": dart,
    "miss": miss,
    "bust": bust,
    "visit": visit,
    "visit_high": visit_high,
    "one_eighty": one_eighty,
    "leg": leg,
    "match": match,
    "attention": attention,
}


def render(name: str) -> np.ndarray:
    """The sound `name` as 16-bit samples, normalised to its level and faded out at the end"""
    # Each sound has its own seed, so changing one recipe leaves the others' files as they are.
    rng = np.random.default_rng([SEED, list(RECIPES).index(name)])
    x = RECIPES[name](rng)
    x = x * (10 ** (LEVELS_DB[name] / 20) / np.abs(x).max())
    fade = min(len(x), round(FADE_OUT_S * SAMPLE_RATE))
    x[len(x) - fade :] *= np.linspace(1.0, 0.0, fade)
    return np.round(x * 32767).astype("<i2")


def wav_bytes(samples: np.ndarray) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(samples.tobytes())
    return buffer.getvalue()


def write_all(out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for name in RECIPES:
        path = out / f"{name}.wav"
        path.write_bytes(wav_bytes(render(name)))
        paths.append(path)
    return paths


def main(argv: list[str] | None = None) -> int:
    default_out = Path(__file__).resolve().parents[2] / "ui" / "assets" / "sounds"
    summary = __doc__.split("\n\n")[1]
    parser = argparse.ArgumentParser(description=summary, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--out", type=Path, default=default_out, help=f"output folder (default: {default_out})")
    args = parser.parse_args(argv)
    for path in write_all(args.out):
        print(f"{path} ({path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
