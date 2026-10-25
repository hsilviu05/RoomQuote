#!/usr/bin/env python3
"""Build RoomQuote's wide header (3840x1646), in the style of SnapWorth's:
a serif headline with one accent word on the left, two phones on the right,
and slate and accent wedges in the corners. Reuses build_screenshots.py's
device drawing, so the phones match the App Store set.

    python3 marketing/build_header.py
"""

from PIL import Image, ImageDraw

import build_screenshots as shots

W, H = 3840, 1646


def main() -> None:
    canvas = Image.new("RGB", (W, H), shots.WHITE)
    d = ImageDraw.Draw(canvas)
    d.polygon([(0, 1060), (2050, H), (0, H)], fill=shots.SLATE)
    d.polygon([(2400, 0), (W, 0), (W, 900)], fill=shots.ACCENT)

    # Phones: the quote upright-ish in front, materials large and tipped behind it on the right.
    shots.place(canvas, shots.CAPTURES / "materials.png", cx=3330, cy=1150, width=1250, angle=24, lean=0.10)
    shots.place(canvas, shots.CAPTURES / "quote.png", cx=2560, cy=1330, width=820, angle=-6, lean=0.04)

    # Headline, three lines, "leave" in the accent colour.
    lines = [["Quote the job"], ["before you"], [("leave", shots.ACCENT), " the room."]]
    size = 176
    hf = shots.font("Fraunces", "Bold", size)
    x0, y = 380, 400
    for parts in lines:
        x = x0
        for part in parts:
            text, colour = part if isinstance(part, tuple) else (part, shots.INK)
            d.text((x, y), text, font=hf, fill=colour)
            x += d.textlength(text, font=hf)
        y += int(size * 1.05)

    sf = shots.font("DMSans", "Regular", 62)
    for line in ["Measure a room, price paint, floors or tiles,", "and send a PDF quote in minutes."]:
        d.text((x0 + 6, y + 30), line, font=sf, fill=shots.INK)
        y += 84

    shots.OUT.mkdir(exist_ok=True)
    path = shots.OUT / "header_3840x1646.png"
    canvas.save(path, "PNG", optimize=True)
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
