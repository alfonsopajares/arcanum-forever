"""Generate Arcanum's circular UI textures without external dependencies."""
import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
SIZE = 128


def pixels(kind):
    result = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = (x + 0.5 - SIZE / 2) / (SIZE / 2), (y + 0.5 - SIZE / 2) / (SIZE / 2)
            radius = math.hypot(u, v)
            alpha = max(0, min(1, (0.99 - radius) * SIZE / 2))
            if kind == "CircleMask":
                color = (255, 255, 255)
            elif kind == "Ring":
                ring = math.exp(-((radius - 0.925) / 0.024) ** 2)
                inner = math.exp(-((radius - 0.86) / 0.01) ** 2) * 0.5
                alpha *= max(ring, inner)
                color = (90, 185, 245)
            else:
                depth = math.sqrt(max(0, 1 - radius * radius))
                light = max(0, (-u * 0.35 - v * 0.5 + depth * 0.6))
                glint = math.exp(-((u + 0.32) ** 2 + (v + 0.38) ** 2) / 0.018)
                swirl = (0.5 + 0.5 * math.sin(math.atan2(v, u) * 3 + radius * 20)) * depth
                ring = math.exp(-((radius - 0.925) / 0.022) ** 2)
                color = (
                    min(255, int(8 + 32 * light + 95 * glint + 55 * ring)),
                    min(255, int(24 + 85 * light + 25 * swirl + 110 * glint + 110 * ring)),
                    min(255, int(60 + 125 * light + 35 * swirl + 90 * glint + 85 * ring)),
                )
            result.extend((*color, int(alpha * 255)))
    return bytes(result)


def png(rgba):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    raw = b"".join(b"\0" + rgba[y * SIZE * 4:(y + 1) * SIZE * 4] for y in range(SIZE))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


media = ROOT / "Arcanum" / "Media"
preview = ROOT / "work" / "art-preview"
media.mkdir(parents=True, exist_ok=True)
preview.mkdir(parents=True, exist_ok=True)
for name in ("Orb", "CircleMask", "Ring"):
    rgba = pixels(name)
    bgra = bytearray(rgba)
    for index in range(0, len(bgra), 4):
        bgra[index], bgra[index + 2] = bgra[index + 2], bgra[index]
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    (media / (name + ".tga")).write_bytes(header + bgra)
    (preview / (name + ".png")).write_bytes(png(rgba))
print("Generated three 128px circular textures with transparent corners.")
