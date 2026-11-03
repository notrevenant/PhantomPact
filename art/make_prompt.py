# Player 2's interaction prompt: a round pad button glyph ("A") and a square keyboard key ("E"), in the panel's silver.
# Writes mod/PBZCoop/art/panel/prompt_*.png at three times their 64-unit size, so they stay sharp on big screens (the Lua
# gives the widget its size). Run: python art/make_prompt.py
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mod", "PBZCoop", "art", "panel")
K = 8                       # drawn this much bigger than its 64 units...
SCALE = 3                   # ...and saved at this
SILVER = (232, 232, 226, 255)
DARK = (14, 14, 16, 200)


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size * K)
        except OSError:
            continue
    return ImageFont.load_default()


def glyph(name, text, round_):
    s = 64
    img = Image.new("RGBA", (s * K, s * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box = (4 * K, 4 * K, (s - 4) * K, (s - 4) * K)
    if round_:
        d.ellipse(box, fill=DARK, outline=SILVER, width=3 * K)
    else:
        d.rounded_rectangle(box, radius=10 * K, fill=DARK, outline=SILVER, width=3 * K)
    d.text((s * K / 2, s * K / 2 + 1 * K), text, font=font(34), fill=SILVER, anchor="mm")
    img = img.resize((s * SCALE, s * SCALE), Image.LANCZOS)
    img.save(os.path.join(OUT, name), optimize=True)
    print("wrote", name)


glyph("prompt_a.png", "A", True)
glyph("prompt_b.png", "B", True)
glyph("prompt_e.png", "E", False)
glyph("prompt_space.png", "_", False)
