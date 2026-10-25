#!/usr/bin/env python3
"""Build RoomQuote's App Store screenshots (English, 6.9" iPhone, 1320x2868).

Same visual language as SnapWorth's live set: a serif headline, a short sans
subhead, two-colour diagonal grounds, and tilted phones that run across frame
edges so the gallery reads as one strip. The phone screens are real simulator
captures; only the frame around them is drawn.

    python3 marketing/build_screenshots.py

Inputs: marketing/captures/{quote,manual,materials,home}.png (1320x2868, taken
from a Debug build with sample data, status bar overridden to 9:41).
Output: marketing/screenshots/en_69_0N_<slug>.png, sRGB, no alpha.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
FONTS = HERE / "fonts"
CAPTURES = HERE / "captures"
OUT = HERE / "screenshots"
ICON = HERE.parent / "RoomQuote/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Light-1024.png"

W, H = 1320, 2868
FRAMES = 4

WHITE = (255, 255, 255)
INK = (21, 24, 29)          # Theme.textPrimary
ACCENT = (194, 65, 12)      # Theme.accentFill, #C2410C
SLATE = (51, 71, 91)        # second ground colour, the role sage plays in SnapWorth
BODY = (46, 52, 50)         # titanium-ish frame, close to SnapWorth's device colour
BODY_EDGE = (28, 32, 31)


@dataclass
class Caption:
    headline: str
    subhead: str
    dark_ground: bool  # white text on the accent ground


CAPTIONS = [
    Caption("Quote before you leave.", "Measure the room, price the job and send a clean PDF on the spot.", False),
    Caption("Measure it once.", "Scan with LiDAR or type the sizes. Doors and windows come off.", False),
    Caption("Paint, floor or tiles.", "Coats, waste and coverage, rounded up to whole cans and boxes.", True),
    Caption("Every quote, tracked.", "Draft, sent, accepted, paid, with your win rate each month.", True),
]
SLUGS = ["quote-before-you-leave", "measure-it-once", "paint-floor-or-tiles", "every-quote-tracked"]

# Claims the captions must not make (keeps the copy honest for App Review).
FORBIDDEN = ["accurate", "exact", "precise", "unlimited", "free trial", "ipad", "guarantee"]


def font(name: str, style: str, size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONTS / f"{name}-Variable.ttf"), size)
    f.set_variation_by_name(style)
    return f


# ── Grounds ──────────────────────────────────────────────────────────────────

def ground() -> Image.Image:
    """One wide canvas for the whole strip, so shapes can cross frame edges."""
    img = Image.new("RGB", (W * FRAMES, H), WHITE)
    d = ImageDraw.Draw(img)
    # Frame 1: slate wedge rising from the lower left, as SnapWorth's sage one.
    d.polygon([(0, 1450), (W + 140, H), (0, H)], fill=SLATE)
    # Frame 2: a small accent corner at the top right that leads into frame 3.
    d.polygon([(2 * W - 120, 0), (2 * W, 0), (2 * W, 150)], fill=ACCENT)
    # Frame 3: accent ground with a white wedge on the left.
    d.polygon([(2 * W, 0), (3 * W, 0), (3 * W, H), (2 * W + 980, H), (2 * W, 900)], fill=ACCENT)
    # Frame 4: accent all over.
    d.rectangle([3 * W, 0, 4 * W, H], fill=ACCENT)
    return img


# ── Text ─────────────────────────────────────────────────────────────────────

def wrap(text: str, f: ImageFont.FreeTypeFont, measure: int) -> list[str]:
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    lines, current = [], ""
    for word in text.split():
        trial = f"{current} {word}".strip()
        if d.textlength(trial, font=f) > measure and current:
            lines.append(current)
            current = word
        else:
            current = trial
    return lines + ([current] if current else [])


def draw_caption(img: Image.Image, index: int, caption: Caption) -> None:
    d = ImageDraw.Draw(img)
    x0 = index * W
    ink = WHITE if caption.dark_ground else INK
    size = 112
    hf = font("Fraunces", "Bold", size)
    while d.textlength(caption.headline, font=hf) > W - 120:
        size -= 2
        hf = font("Fraunces", "Bold", size)
    tw = d.textlength(caption.headline, font=hf)
    d.text((x0 + (W - tw) / 2, 120), caption.headline, font=hf, fill=ink)

    sf = font("DMSans", "Regular", 54)
    y = 120 + int(size * 1.25)
    for line in wrap(caption.subhead, sf, W - 200):
        lw = d.textlength(line, font=sf)
        d.text((x0 + (W - lw) / 2, y), line, font=sf, fill=ink)
        y += 72


# ── Device ───────────────────────────────────────────────────────────────────

def rounded(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def flat_device(capture: Path, width: int = 1100) -> Image.Image:
    """Capture inside a drawn frame, with a Dynamic Island, upright and flat."""
    bezel = int(width * 0.028)
    screen_w = width - 2 * bezel
    with Image.open(capture) as im:
        screen = im.convert("RGB").resize((screen_w, int(im.height * screen_w / im.width)), Image.LANCZOS)
    height = screen.height + 2 * bezel
    radius = int(width * 0.135)
    device = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(device)
    d.rounded_rectangle([0, 0, width - 1, height - 1], radius=radius, fill=BODY + (255,))
    d.rounded_rectangle([0, 0, width - 1, height - 1], radius=radius, outline=(92, 100, 97, 255), width=4)
    device.paste(screen, (bezel, bezel), rounded(screen.size, radius - bezel))
    # Dynamic Island over the status bar.
    iw, ih = int(width * 0.28), int(width * 0.082)
    top = bezel + int(width * 0.03)
    d.rounded_rectangle([(width - iw) // 2, top, (width + iw) // 2, top + ih], radius=ih // 2, fill=(8, 8, 8, 255))
    return device


def solve(a: list[list[float]], b: list[float]) -> list[float]:
    """Gaussian elimination for the 8x8 perspective system (no numpy needed)."""
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        m[col], m[pivot] = m[pivot], m[col]
        for r in range(n):
            if r != col:
                factor = m[r][col] / m[col][col]
                m[r] = [x - factor * y for x, y in zip(m[r], m[col])]
    return [m[i][n] / m[i][i] for i in range(n)]


def warp(img: Image.Image, quad: list[tuple[float, float]], canvas_size: tuple[int, int]) -> Image.Image:
    """Map img's corners (TL, TR, BR, BL) onto quad in a canvas-sized layer."""
    w, h = img.size
    src = [(0, 0), (w, 0), (w, h), (0, h)]
    a, b = [], []
    for (x, y), (u, v) in zip(quad, src):  # PIL wants output -> input
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
    coeffs = solve(a, b)
    return img.transform(canvas_size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)


def device_quad(cx: float, cy: float, width: float, height: float, angle: float, lean: float) -> list[tuple[float, float]]:
    """A rectangle tipped back by `lean` (top edge narrower) and turned by `angle` degrees."""
    top = width * (1 - lean) / 2
    bottom = width / 2
    pts = [(-top, -height / 2), (top, -height / 2), (bottom, height / 2), (-bottom, height / 2)]
    r = math.radians(angle)
    return [(cx + x * math.cos(r) - y * math.sin(r), cy + x * math.sin(r) + y * math.cos(r)) for x, y in pts]


def place(canvas: Image.Image, capture: Path, cx: float, cy: float, width: float, angle: float, lean: float) -> None:
    device = flat_device(capture)
    height = width * device.height / device.width
    quad = device_quad(cx, cy, width, height, angle, lean)
    size = canvas.size

    # Soft shadow, then the side of the phone (a darker copy nudged down-right), then the face.
    shadow = warp(device, [(x + 40, y + 70) for x, y in quad], size)
    alpha = shadow.getchannel("A").point(lambda p: int(p * 0.35)).filter(ImageFilter.GaussianBlur(45))
    canvas.paste(Image.new("RGB", size, (20, 20, 20)), (0, 0), alpha)

    side = Image.new("RGBA", device.size, BODY_EDGE + (255,))
    side.putalpha(device.getchannel("A"))
    for step in range(16, 0, -2):
        canvas.paste(warp(side, [(x + step, y + step * 0.7) for x, y in quad], size), (0, 0),
                     warp(side, [(x + step, y + step * 0.7) for x, y in quad], size))
    face = warp(device, quad, size)
    canvas.paste(face, (0, 0), face)


def place_icon(canvas: Image.Image, cx: int, cy: int, side: int) -> None:
    with Image.open(ICON) as im:
        icon = im.convert("RGB").resize((side, side), Image.LANCZOS)
    mask = rounded((side, side), int(side * 0.2237))
    shadow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [cx - side // 2 + 10, cy - side // 2 + 30, cx + side // 2 - 10, cy + side // 2 + 40],
        radius=int(side * 0.22), fill=90)
    canvas.paste(Image.new("RGB", canvas.size, (60, 40, 30)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(30)))
    canvas.paste(icon, (cx - side // 2, cy - side // 2), mask)


# ── Build ────────────────────────────────────────────────────────────────────

def check() -> None:
    for caption in CAPTIONS:
        text = f"{caption.headline} {caption.subhead}".lower()
        for word in FORBIDDEN:
            assert word not in text, f"caption says {word!r}: {caption.headline}"
    for name in ("quote", "manual", "materials", "home"):
        path = CAPTURES / f"{name}.png"
        with Image.open(path) as im:
            assert im.size == (W, H), f"{path} is {im.size}, expected {(W, H)}"


def main() -> None:
    check()
    strip = ground()
    # Frame 1: the quote, tipped back and turned, running into frame 2's left edge.
    place(strip, CAPTURES / "quote.png", cx=720, cy=1960, width=1060, angle=-20, lean=0.09)
    # Frame 2: the app icon, then the measurement form nearly upright.
    place_icon(strip, W + W // 2, 640, 300)
    place(strip, CAPTURES / "manual.png", cx=W + 680, cy=2060, width=1000, angle=-4, lean=0.04)
    # Frame 3: materials, leaning the other way and crossing into frame 4.
    place(strip, CAPTURES / "materials.png", cx=2 * W + 700, cy=1990, width=1040, angle=18, lean=0.08)
    # Frame 4: the quotes list, tipped back.
    place(strip, CAPTURES / "home.png", cx=3 * W + 760, cy=1960, width=1040, angle=-14, lean=0.08)

    # Captions last, so phones never cover them.
    for index, caption in enumerate(CAPTIONS):
        draw_caption(strip, index, caption)

    OUT.mkdir(exist_ok=True)
    for index, slug in enumerate(SLUGS):
        frame = strip.crop((index * W, 0, (index + 1) * W, H)).convert("RGB")
        path = OUT / f"en_69_{index + 1:02d}_{slug}.png"
        frame.save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(HERE.parent)}")


if __name__ == "__main__":
    main()
