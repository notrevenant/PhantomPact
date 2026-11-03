"""The Nexus install guide's pictures of the two panels (art/nexus/guide/install-4-f5-panel.png and install-5-local-panel.png),
built from the panels' own art (mod/PBZCoop/art/panel, so run make_local_panel.py and make_online_panel.py first) laid out as
the Lua lays it out, over a darkened shot of the game. Twice the size the Nexus page shows them, so they stay sharp.
Needs Pillow and a font with Chinese (Noto Sans CJK on Linux: fonts-noto-cjk; Microsoft YaHei on Windows).
Run: python art/make_guide_panels.py"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PANEL = os.path.join(HERE, "..", "mod", "PBZCoop", "art", "panel")
OUT = os.path.join(HERE, "nexus", "guide")
BACKDROP = os.path.join(HERE, "nexus", "06-bamboo-forest.jpg")
W, H = 1320, 940                # twice the 660 x 470 the page shows
PANEL_X, PANEL_Y, PANEL_W = 40, 140, 1240
UNIT = PANEL_W / 900            # screen pixels per panel unit
RED = (232, 34, 40)
WHITE = (240, 240, 240)

SANS = [("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", "Noto Sans CJK SC"),
        ("C:/Windows/Fonts/msyhbd.ttc", "C:/Windows/Fonts/msyh.ttc", "Microsoft YaHei")]


def sans(size, bold=False):
    for heavy, regular, family in SANS:
        path = heavy if bold else regular
        if not os.path.exists(path):
            continue
        for index in range(12):
            try:
                f = ImageFont.truetype(path, size, index=index)
            except OSError:
                break
            if f.getname()[0] == family:
                return f
    raise SystemExit("No font with Chinese: install fonts-noto-cjk, or run this on Windows.")


def backdrop():
    shot = Image.open(BACKDROP).convert("RGB")
    scale = max(W / shot.width, H / shot.height)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    left, top = (shot.width - W) // 2, (shot.height - H) // 2
    shot = shot.crop((left, top, left + W, top + H)).filter(ImageFilter.GaussianBlur(3))
    dark = Image.new("RGB", (W, H), (0, 0, 0))
    return Image.blend(shot, dark, 0.45).convert("RGBA")


def put(img, name, x, y, w, h, opacity=1.0):
    """One panel picture at panel units (x, y, w, h), as panel.lua's place() puts it on screen."""
    part = Image.open(os.path.join(PANEL, name + ".png")).convert("RGBA")
    part = part.resize((round(w * UNIT), round(h * UNIT)), Image.LANCZOS)
    if opacity < 1:
        part.putalpha(part.getchannel("A").point(lambda a: round(a * opacity)))
    img.alpha_composite(part, (PANEL_X + round(x * UNIT), PANEL_Y + round(y * UNIT)))


def heading(img, english, chinese):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, 124), fill=(0, 0, 0, 255))
    d.text((40, 42), english, font=sans(38, True), fill=RED, anchor="lm")
    d.text((40, 96), chinese, font=sans(28), fill=WHITE, anchor="lm")


def online():
    img = backdrop()
    heading(img, "Press F5, then HOST or GUEST. Press Steam to pick a friend",
            "按 F5,然后按开房或加入。点 Steam 可以选择好友")
    put(img, "online_bg", 0, 0, 900, 560)
    put(img, "close", 848, 14, 38, 38)
    put(img, "online_lang_en", 40, 18, 76, 30)
    put(img, "online_lang_zh", 124, 18, 76, 30)
    put(img, "sel_lang", 40, 18, 76, 30)
    put(img, "online_steam", 40, 244, 176, 58, 0.3)       # connected: the card is dimmed, as in the game
    put(img, "sel_card", 40, 244, 176, 58)
    put(img, "online_host", 40, 350, 170, 46)
    put(img, "online_join_on", 228, 350, 170, 46)
    put(img, "online_leave", 416, 350, 170, 46)
    put(img, "online_settings", 690, 494, 170, 46)
    # The status line, in the game's own tip text (a sans), centred in the box.
    d = ImageDraw.Draw(img)
    d.text((PANEL_X + 450 * UNIT, PANEL_Y + 155 * UNIT), "Connected to Wanderer. Ping 31 ms. Route: direct.",
           font=sans(26), fill=WHITE, anchor="mm")
    img.convert("RGB").save(os.path.join(OUT, "install-4-f5-panel.png"), optimize=True)


def local():
    img = backdrop()
    heading(img, "Press F4: hold a button on each pad, drag its card onto a player",
            "按 F4:按住每个手柄上的任意键,再把它的卡片拖到玩家上")
    put(img, "bg", 0, 0, 900, 560)
    put(img, "close", 848, 14, 38, 38)
    for n, x in enumerate((40, 116, 192, 268), start=1):
        put(img, "tab%d" % n, x, 116, 64, 64, 1.0 if n <= 2 else 0.3)
    put(img, "sel_tab", 116, 116, 64, 64)
    put(img, "layout_tb", 480, 116, 118, 70)
    put(img, "layout_lr", 612, 116, 118, 70, 0.55)
    put(img, "sel_layout", 480, 116, 118, 70)
    put(img, "slot1", 40, 232, 196, 78)
    put(img, "slot2", 248, 232, 196, 78)
    put(img, "card_kbm", 50, 246, 176, 58)
    put(img, "card_joy1", 258, 246, 176, 58)
    put(img, "card_joy2", 416, 340, 176, 58)
    put(img, "hold5", 416, 398, 176, 6)                   # joystick 2's button held, its card lighting up
    put(img, "multiplayer", 40, 490, 170, 46)
    put(img, "apply", 690, 490, 170, 46)
    img.convert("RGB").save(os.path.join(OUT, "install-5-local-panel.png"), optimize=True)


if __name__ == "__main__":
    online()
    local()
    print("guide pictures written to", os.path.normpath(OUT))
