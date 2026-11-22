"""Generates the Agentic Hive app icons for Windows, macOS, and Linux.

Reuses the Hive hex mark geometry and `accent`/`onAccent` tokens from
`generate_tray_icons.py`:

- Windows: `frontend/windows/runner/resources/app_icon.ico`
  Multi-resolution `.ico` (16, 24, 32, 48, 64, 128, 256) on a transparent
  background.
- macOS: `frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`
  Every size listed in `Contents.json` (16, 32, 64, 128, 256, 512, 1024),
  with the hex mark centered on a dark (`#050706`) rounded-square tile.
- Linux: `frontend/linux/runner/resources/app_icon.png`
  256x256 PNG on a transparent background, bundled next to the binary and
  loaded as the GTK window icon.

Run from `design_system/` with Pillow installed:

    python tool/generate_app_icons.py
"""

import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_tray_icons import (
    ACCENT,
    CLEAR,
    ON_ACCENT,
    _cell_ring,
    _hexagon,
    render,
)

# `HiveColors.dark.background` and `HiveColors.dark.borderSubtle`.
DARK_TILE_BG = (0x05, 0x07, 0x06, 255)
DARK_TILE_BORDER = (0x26, 0x30, 0x2A, 255)

REPO_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")
)
WINDOWS_ICO = os.path.join(
    REPO_ROOT, "frontend", "windows", "runner", "resources", "app_icon.ico"
)
MACOS_ICONSET = os.path.join(
    REPO_ROOT,
    "frontend",
    "macos",
    "Runner",
    "Assets.xcassets",
    "AppIcon.appiconset",
)
LINUX_PNG = os.path.join(
    REPO_ROOT, "frontend", "linux", "runner", "resources", "app_icon.png"
)

WINDOWS_ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
LINUX_ICON_SIZE = 256


def render_macos_tile(size: int) -> Image.Image:
    """Renders the hex mark centered on a dark rounded-square macOS tile."""
    supersample = min(16, max(4, 4096 // size))
    big = size * supersample
    image = Image.new("RGBA", (big, big), CLEAR)
    draw = ImageDraw.Draw(image)

    # Apple HIG grid: ~10% outer margin, ~22.5% corner radius on the tile.
    margin = big * 0.10
    tile_size = big - 2 * margin
    corner_radius = tile_size * 0.225
    border_width = max(1, round(big * 0.004))

    draw.rounded_rectangle(
        [margin, margin, big - margin, big - margin],
        radius=corner_radius,
        fill=DARK_TILE_BG,
        outline=DARK_TILE_BORDER,
        width=border_width,
    )

    center = big / 2
    hex_radius = tile_size * 0.36
    draw.polygon(_hexagon(center, center, hex_radius), fill=ACCENT)
    hole = _cell_ring(draw, center, center, hex_radius, ON_ACCENT)
    draw.polygon(hole, fill=ACCENT)

    return image.resize((size, size), Image.LANCZOS)


def _macos_sizes_from_contents(contents_path: str) -> list[tuple[str, int]]:
    with open(contents_path, encoding="utf-8") as f:
        contents = json.load(f)
    seen: dict[str, int] = {}
    for entry in contents["images"]:
        filename = entry["filename"]
        base_size = int(entry["size"].split("x")[0])
        scale = int(entry["scale"].removesuffix("x"))
        seen[filename] = base_size * scale
    return sorted(seen.items(), key=lambda item: item[1])


def generate_windows_icon() -> None:
    os.makedirs(os.path.dirname(WINDOWS_ICO), exist_ok=True)
    base = render(WINDOWS_ICO_SIZES[-1])
    rest = [render(s) for s in WINDOWS_ICO_SIZES[:-1]]
    base.save(
        WINDOWS_ICO,
        format="ICO",
        sizes=[(s, s) for s in WINDOWS_ICO_SIZES],
        append_images=rest,
    )


def generate_macos_icons() -> None:
    contents_path = os.path.join(MACOS_ICONSET, "Contents.json")
    for filename, px in _macos_sizes_from_contents(contents_path):
        render_macos_tile(px).save(os.path.join(MACOS_ICONSET, filename))


def generate_linux_icon() -> None:
    os.makedirs(os.path.dirname(LINUX_PNG), exist_ok=True)
    render(LINUX_ICON_SIZE).save(LINUX_PNG)


def main() -> None:
    generate_windows_icon()
    generate_macos_icons()
    generate_linux_icon()


if __name__ == "__main__":
    main()
