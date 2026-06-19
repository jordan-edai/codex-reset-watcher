#!/usr/bin/env python3
"""Generate the app icon PNG and ICNS from the checked-in source artwork.

This optional maintainer script needs Pillow. The generated AppIcon.icns is
checked into source so normal builds do not need Pillow.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
ICONSET = ASSETS / "AppIcon.iconset"
SOURCE = ASSETS / "AppIconSource.png"
PNG = ASSETS / "AppIcon.png"
ICNS = ASSETS / "AppIcon.icns"


def content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    """Find the non-black art bounds in the imagegen source."""
    rgb = image.convert("RGB")
    black = Image.new("RGB", rgb.size, (0, 0, 0))
    diff = ImageChops.difference(rgb, black).convert("L")
    mask = diff.point(lambda value: 255 if value > 10 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("AppIconSource.png appears to be blank.")
    return bbox


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def prepare_icon(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    cropped = source.crop(content_bbox(source))
    fitted = ImageOps.fit(cropped, (1024, 1024), Image.Resampling.LANCZOS, centering=(0.5, 0.5))

    alpha = rounded_rect_mask(1024, 205)

    # Soften the very outer edge while keeping the button and inner artwork crisp.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.3))
    output = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    output.paste(fitted, (0, 0), alpha)
    return output


def write_iconset(source: Image.Image) -> None:
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True)

    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, pixels in specs:
        source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ICONSET / name)


def main() -> int:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Missing icon source artwork: {SOURCE}")

    ASSETS.mkdir(exist_ok=True)
    icon = prepare_icon(SOURCE)
    icon.save(PNG)
    write_iconset(icon)
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    print(SOURCE)
    print(PNG)
    print(ICNS)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
