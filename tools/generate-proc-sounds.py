"""Create Arcanum's short, original proc tones using only the standard library."""
from pathlib import Path
import math
import struct
import wave

MEDIA = Path(__file__).resolve().parents[1] / "Arcanum" / "Media"
RATE = 22050

def write(name, notes):
    length = max(start + duration for start, duration, frequency in notes) + 0.03
    samples = []
    for i in range(int(length * RATE)):
        t = i / RATE
        value = 0.0
        for start, duration, frequency in notes:
            dt = t - start
            if 0 <= dt < duration:
                envelope = min(1, dt / 0.008) * (1 - dt / duration) ** 2
                value += math.sin(2 * math.pi * frequency * dt) * envelope * 0.20
        samples.append(struct.pack("<h", int(max(-1, min(1, value)) * 32767)))
    with wave.open(str(MEDIA / name), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(b"".join(samples))

write("ProcChime.wav", [(0, .25, 660), (.09, .28, 990)])
write("ProcPulse.wav", [(0, .16, 330), (.16, .20, 494)])
write("ProcFrost.wav", [(0, .20, 1175), (.08, .26, 880)])
write("ProcFire.wav", [(0, .22, 220), (.07, .28, 330), (.14, .24, 440)])
print("Generated four original PCM proc sounds.")
