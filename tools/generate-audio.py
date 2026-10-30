"""Generate original, short game feedback cues. Standard library only, no samples.

Run from any directory. Deterministic seed; 22,050 Hz mono PCM WAV.
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
RATE = 22050


def generate():
    out = ROOT / 'assets/audio'
    out.mkdir(parents=True, exist_ok=True)
    cues = {
        'deal': (0.14, [(0, 0.11, 1350, 0.10)]),
        'chips': (0.20, [(0, 0.08, 1900, 0.15), (0.065, 0.10, 2450, 0.10)]),
        'turn': (0.25, [(0, 0.12, 660, 0.16), (0.10, 0.14, 880, 0.14)]),
        'win': (0.48, [(0, 0.20, 523.25, 0.12), (0.10, 0.22, 659.25, 0.12), (0.22, 0.25, 783.99, 0.13)]),
        'split': (0.32, [(0, 0.19, 587.33, 0.12), (0.12, 0.19, 739.99, 0.11)]),
    }
    for name, (duration, notes) in cues.items():
        rng = random.Random(name)
        samples = []
        for n in range(round(RATE * duration)):
            t = n / RATE
            value = 0.0
            for start, length, frequency, volume in notes:
                x = t - start
                if 0 <= x < length:
                    envelope = min(x / 0.006, 1) * (1 - x / length) ** 2
                    wave_value = math.sin(math.tau * frequency * x)
                    if name in ('deal', 'chips'):
                        wave_value = .65 * wave_value + .35 * rng.uniform(-1, 1)
                    value += volume * envelope * wave_value
            samples.append(round(max(-1, min(1, value)) * 32767))
        with wave.open(str(out / (name + '.wav')), 'wb') as audio:
            audio.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            audio.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
    print('Generated 5 original PCM feedback cues')


if __name__ == '__main__':
    generate()
