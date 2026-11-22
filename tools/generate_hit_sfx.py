"""Generates the card sound effects in assets/sfx/ (stdlib only, deterministic).

- hit_*:   a short punch: a low sine "thump" whose pitch falls quickly, a
           filtered noise burst for the crack, and a tiny click at the start.
- shift_*: a soft whoosh: noise through a band-pass filter that sweeps up.
- hover:   one soft, very short tick (filtered noise, no tone).
- select:  a click followed by a lower clack, like a card being set down.
- empty_hit_*: an attack into an empty slot: a short falling swish that ends in
           a soft, dusty thud (no crack, quieter than a real hit).
- rip_gain: an airy rising swell with three rising bony clicks.
- rip_loss: a falling swell with three descending, heavier clacks.

Tweak the tables below and run `python3 tools/generate_hit_sfx.py` from the
repo root. The .tres files next to the .wavs pick variants and vary pitch.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sfx"

# name: (seconds, thump start Hz, thump end Hz, thump decay s, noise decay s,
#        noise lowpass 0..1 (lower = darker), noise level, seed)
HITS = {
    "hit_1": (0.20, 190.0, 55.0, 0.070, 0.030, 0.35, 0.55, 1),
    "hit_2": (0.18, 230.0, 70.0, 0.055, 0.022, 0.50, 0.65, 2),
    "hit_3": (0.24, 160.0, 45.0, 0.090, 0.040, 0.25, 0.45, 3),
}

# name: (seconds, sweep start Hz, sweep end Hz, resonance 0..1, peak, seed)
SHIFTS = {
    "shift_1": (0.28, 350.0, 1700.0, 0.55, 0.42, 11),
    "shift_2": (0.24, 450.0, 2100.0, 0.50, 0.38, 12),
}

# Clicks are built from transients: (delay s, band centre Hz, resonance 0..1,
# decay s, level), plus a short damped "body" knock (Hz, decay s, level).
# name: (transients, body, peak, seed)
CLICKS = {
    "hover": ([(0.0, 3800.0, 0.55, 0.0025, 1.0)], (900.0, 0.003, 0.25), 0.22, 21),
    "select": (
        [(0.0, 3200.0, 0.6, 0.003, 1.0), (0.022, 1700.0, 0.65, 0.006, 0.9)],
        (420.0, 0.009, 0.5),
        0.6,
        22,
    ),
}


# name: (seconds, swish start Hz, swish end Hz, thud at s, thud Hz, thud decay s,
#        peak, seed)
EMPTY_HITS = {
    "empty_hit_1": (0.22, 2400.0, 500.0, 0.15, 85.0, 0.035, 0.45, 31),
    "empty_hit_2": (0.20, 2800.0, 600.0, 0.13, 100.0, 0.030, 0.42, 32),
}

# name: (swell seconds, swell start Hz, swell end Hz, swell level,
#        clicks as (delay s, band centre Hz, decay s, level), body, peak, seed)
RIPS = {
    "rip_gain": (
        0.26,
        700.0,
        4200.0,
        0.35,
        [(0.04, 2300.0, 0.004, 0.8), (0.09, 3000.0, 0.004, 0.9), (0.14, 3900.0, 0.005, 1.0)],
        (650.0, 0.006, 0.25),
        0.55,
        41,
    ),
    "rip_loss": (
        0.30,
        3200.0,
        450.0,
        0.35,
        [(0.03, 2500.0, 0.005, 1.0), (0.09, 1700.0, 0.006, 0.9), (0.15, 1100.0, 0.008, 0.85)],
        (260.0, 0.014, 0.55),
        0.55,
        42,
    ),
}


def _mix(*layers):
    length = max(len(layer) for layer in layers)
    return [sum(layer[i] for layer in layers if i < len(layer)) for i in range(length)]


def _envelope_edges(samples, seconds, attack=0.0015, release=0.02):
    count = len(samples)
    for index in range(count):
        t = index / RATE
        samples[index] *= min(1.0, t / attack) * min(1.0, (seconds - t) / release)
    return samples


def _normalize(samples, peak):
    loudest = max(abs(s) for s in samples) or 1.0
    return [s * peak / loudest for s in samples]


def render_hit(seconds, f_start, f_end, thump_decay, noise_decay, lowpass, noise_level, seed):
    rng = random.Random(seed)
    samples = []
    phase = 0.0
    filtered = 0.0
    for index in range(int(RATE * seconds)):
        t = index / RATE
        # Exponential pitch drop from f_start to f_end.
        freq = f_end + (f_start - f_end) * math.exp(-t / 0.03)
        phase += 2 * math.pi * freq / RATE
        thump = math.sin(phase) * math.exp(-t / thump_decay)
        filtered += lowpass * (rng.uniform(-1, 1) - filtered)
        crack = filtered * noise_level * math.exp(-t / noise_decay)
        click = 0.6 * math.exp(-t / 0.002) if t < 0.01 else 0.0
        samples.append(thump + crack + click)
    return _normalize(_envelope_edges(samples, seconds), 0.7)


def render_shift(seconds, f_start, f_end, resonance, peak, seed):
    rng = random.Random(seed)
    samples = []
    low = band = 0.0
    damping = 2.0 * (1.0 - resonance) + 0.1
    for index in range(int(RATE * seconds)):
        progress = index / (RATE * seconds)
        cutoff = f_start * (f_end / f_start) ** progress
        f = 2.0 * math.sin(math.pi * cutoff / RATE)
        # State-variable filter, band-pass output.
        high = rng.uniform(-1, 1) - low - damping * band
        band += f * high
        low += f * band
        swell = math.sin(math.pi * progress) ** 1.5
        samples.append(band * swell)
    return _normalize(_envelope_edges(samples, seconds, 0.01, 0.04), peak)


def render_click(transients, body, peak, seed):
    rng = random.Random(seed)
    seconds = max(delay + decay * 8 for delay, _, _, decay, _ in transients) + 0.01
    samples = [0.0] * int(RATE * seconds)
    for delay, centre, resonance, decay, level in transients:
        start = int(RATE * delay)
        f = 2.0 * math.sin(math.pi * centre / RATE)
        damping = 2.0 * (1.0 - resonance) + 0.1
        low = band = 0.0
        for index in range(start, len(samples)):
            t = (index - start) / RATE
            # Band-passed noise burst with a near-instant decay: a dry "tk".
            high = rng.uniform(-1, 1) * math.exp(-t / decay) - low - damping * band
            band += f * high
            low += f * band
            samples[index] += band * level
    body_hz, body_decay, body_level = body
    first = int(RATE * transients[0][0])
    for index in range(first, len(samples)):
        t = (index - first) / RATE
        samples[index] += body_level * math.sin(2 * math.pi * body_hz * t) * math.exp(-t / body_decay)
    return _normalize(_envelope_edges(samples, seconds, 0.0003, 0.004), peak)


def render_empty_hit(seconds, f_start, f_end, thud_at, thud_hz, thud_decay, peak, seed):
    swish = [x * 0.55 for x in render_shift(seconds, f_start, f_end, 0.4, 1.0, seed)]
    rng = random.Random(seed + 100)
    thud = [0.0] * int(RATE * seconds)
    start = int(RATE * thud_at)
    dust = 0.0
    for index in range(start, len(thud)):
        t = (index - start) / RATE
        dust += 0.12 * (rng.uniform(-1, 1) - dust)
        knock = math.sin(2 * math.pi * thud_hz * t) * math.exp(-t / thud_decay)
        thud[index] = knock + 0.9 * dust * math.exp(-t / (thud_decay * 0.8))
    return _normalize(_envelope_edges(_mix(swish, thud), seconds, 0.005, 0.02), peak)


def render_rip(seconds, f_start, f_end, swell_level, clicks, body, peak, seed):
    swell = [x * swell_level for x in render_shift(seconds, f_start, f_end, 0.5, 1.0, seed)]
    transients = [(delay, centre, 0.62, decay, level) for delay, centre, decay, level in clicks]
    clack = render_click(transients, body, 1.0, seed + 1)
    return _normalize(_envelope_edges(_mix(swell, clack), seconds, 0.004, 0.03), peak)


def write_wav(path, samples):
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    print(f"wrote {path.relative_to(OUT_DIR.parent.parent)}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, params in HITS.items():
        write_wav(OUT_DIR / f"{name}.wav", render_hit(*params))
    for name, params in SHIFTS.items():
        write_wav(OUT_DIR / f"{name}.wav", render_shift(*params))
    for name, params in CLICKS.items():
        write_wav(OUT_DIR / f"{name}.wav", render_click(*params))
    for name, params in EMPTY_HITS.items():
        write_wav(OUT_DIR / f"{name}.wav", render_empty_hit(*params))
    for name, params in RIPS.items():
        write_wav(OUT_DIR / f"{name}.wav", render_rip(*params))


if __name__ == "__main__":
    main()
