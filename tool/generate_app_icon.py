from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "assets" / "fonts" / "SpaceGrotesk-Variable.ttf"
OUT = ROOT / "assets" / "icon" / "app_icon.png"


def main() -> None:
    size = 1024
    ink = (10, 10, 10)
    paper = (255, 255, 255)

    img = Image.new("RGB", (size, size), ink)
    draw = ImageDraw.Draw(img)

    if not FONT.is_file():
        raise SystemExit(f"missing font: {FONT}")

    font_size = 560
    font = ImageFont.truetype(str(FONT), font_size)
    if hasattr(font, "set_variation_by_axes"):
        try:
            font.set_variation_by_axes([700])
        except (OSError, ValueError, TypeError):
            pass

    text = "y"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=paper)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
