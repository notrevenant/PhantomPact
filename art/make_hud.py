"""Builds the partner compass's pictures (mod/PBZCoop/art/compass_line.png and partner_dot.png) from the Lumina paintings in
art/, at far more pixels than the game shows, so they stay sharp on big screens: hud.lua gives each widget its size, and
keeps the line's height to width at LINE_ASPECT (39 / 1024), which this keeps too. Needs Pillow: python art/make_hud.py"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "mod", "PBZCoop", "art")
LINE_W = 1792                   # as wide as the painting's stroke really is: nothing is made up by enlarging it
LINE_ASPECT = 39 / 1024         # hud.lua's LINE_ASPECT
DOT = 384                       # the seal, square; shown at 40 units


def ink_alpha(img, floor=26, gain=3):
    """The paintings are light on black: brightness becomes opacity, and the black around them goes."""
    return ImageOps.grayscale(img).point(lambda v: 0 if v < floor else min(255, (v - floor) * gain))


def compass_line():
    raw = Image.open(os.path.join(HERE, "lumina-compass-line-original.png")).convert("RGB")
    gray = ImageOps.grayscale(raw)
    x0, y0, x1, y1 = gray.point(lambda v: 255 if v > 60 else 0).getbbox()
    width = x1 - x0
    height = width * LINE_ASPECT
    mid = (y0 + y1) / 2
    strip = raw.crop((x0, round(mid - height / 2), x1, round(mid + height / 2)))
    strip = strip.resize((LINE_W, round(LINE_W * LINE_ASPECT)), Image.LANCZOS)
    line = strip.convert("RGBA")
    # Softer than the seal's: the stroke's darker ink stays part of it instead of turning into holes.
    line.putalpha(ink_alpha(strip, floor=14, gain=2).filter(ImageFilter.GaussianBlur(0.8)))
    line.save(os.path.join(OUT, "compass_line.png"), optimize=True)


def partner_dot():
    raw = Image.open(os.path.join(HERE, "lumina-partner-seal-original.png")).convert("RGB")
    x0, y0, x1, y1 = ImageOps.grayscale(raw).point(lambda v: 255 if v > 50 else 0).getbbox()
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    seal = raw.crop((round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2)))
    seal = seal.resize((DOT, DOT), Image.LANCZOS).convert("RGBA")
    # A round edge, drawn four times bigger and shrunk, so it's smooth.
    mask = Image.new("L", (DOT * 4, DOT * 4), 0)
    ImageDraw.Draw(mask).ellipse((4, 4, DOT * 4 - 5, DOT * 4 - 5), fill=255)
    seal.putalpha(mask.resize((DOT, DOT), Image.LANCZOS))
    seal.save(os.path.join(OUT, "partner_dot.png"), optimize=True)


if __name__ == "__main__":
    compass_line()
    partner_dot()
    print("compass art written to", os.path.normpath(OUT))
