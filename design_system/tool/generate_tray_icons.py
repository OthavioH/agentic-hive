"""Generates the system tray icons in `assets/tray/` from the Hive hex mark.

The geometry mirrors `HiveHexMark` (`lib/src/components/hive_hex_mark.dart`):
a pointy-top hexagon filling the square, with an inner hexagon outline at
0.42 of the radius and a stroke of 0.14 of the radius.

Colors are the `accent` (#C6EF4E) and `onAccent` (#0B0F0C) tokens. The macOS
template icon is black with alpha only; the inner cell is cut out.

Run from `design_system/` with Pillow installed:

    python tool/generate_tray_icons.py
"""

import math
import os

from PIL import Image, ImageDraw

ACCENT = (0xC6, 0xEF, 0x4E, 255)
ON_ACCENT = (0x0B, 0x0F, 0x0C, 255)
BLACK = (0, 0, 0, 255)
CLEAR = (0, 0, 0, 0)
SUPERSAMPLE = 16
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "tray")


def _hexagon(cx, cy, radius):
    return [
        (
            cx + radius * math.cos(math.radians(60 * i - 90)),
            cy + radius * math.sin(math.radians(60 * i - 90)),
        )
        for i in range(6)
    ]


def _cell_ring(draw, cx, cy, radius, color):
    """Draws the inner hexagon outline as a filled ring (crisp joins)."""
    half = radius * 0.14 / 2
    inner = radius * 0.42
    draw.polygon(_hexagon(cx, cy, inner + half), fill=color)
    return _hexagon(cx, cy, inner - half)


def render(size, template=False):
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), CLEAR)
    draw = ImageDraw.Draw(image)
    c = big / 2
    r = big / 2
    fill = BLACK if template else ACCENT
    draw.polygon(_hexagon(c, c, r), fill=fill)
    if template:
        # Cut the ring out of the black hexagon: draw the ring on a mask.
        mask = Image.new("L", (big, big), 0)
        mask_draw = ImageDraw.Draw(mask)
        hole = _cell_ring(mask_draw, c, c, r, 255)
        mask_draw.polygon(hole, fill=0)
        image.paste(CLEAR, (0, 0), mask)
    else:
        hole = _cell_ring(draw, c, c, r, ON_ACCENT)
        draw.polygon(hole, fill=ACCENT)
    return image.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    ico_sizes = [16, 20, 24, 32, 40, 48, 64]
    render(256).save(
        os.path.join(OUT, "hive_tray_windows.ico"),
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=[render(s) for s in ico_sizes],
    )
    render(32).save(os.path.join(OUT, "hive_tray_linux.png"))
    render(64).save(os.path.join(OUT, "hive_tray_linux@2x.png"))
    render(22, template=True).save(
        os.path.join(OUT, "hive_tray_macos_template.png")
    )
    render(44, template=True).save(
        os.path.join(OUT, "hive_tray_macos_template@2x.png")
    )


if __name__ == "__main__":
    main()
