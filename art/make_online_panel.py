"""Builds the online panel's pictures (mod/PBZCoop/art/panel) in the local panel's look. Words that change are drawn in the
game by the mod. Needs Pillow: python art/make_online_panel.py"""
from make_local_panel import *


def online_background():
    w, h = 900, 560
    img, d = canvas(w, h)
    d.rectangle((0, 0, w * K, h * K), fill=BLACK)
    frame(d, w, h, FAINT)
    corners(d, w, h)
    spaced(d, (w * K / 2, 42 * K), "ONLINE CO-OP", font(25), BRIGHT, gap=7)
    d.line(((w / 2 - 170) * K, 67 * K, (w / 2 + 170) * K, 67 * K), fill=FAINT, width=K)
    spaced(d, (40 * K, 96 * K), "STATUS", font(13), DIM, gap=3, anchor="lm")
    d.rectangle((40 * K, 112 * K, 860 * K, 198 * K), fill=(10, 11, 13, 190), outline=FAINT, width=K)
    spaced(d, (40 * K, 226 * K), "CONNECT THROUGH", font(13), DIM, gap=3, anchor="lm")
    spaced(d, (40 * K, 332 * K), "PLAY", font(13), DIM, gap=3, anchor="lm")
    d.text((40 * K, 438 * K), "Host: your world, your partner joins you. Join: you join the host. Leave: back to playing alone.",
           font=font(13), fill=DIM, anchor="lm")
    d.text((40 * K, 464 * K), "Your choice is kept for the next start. Both players use the same way of connecting.",
           font=font(13), fill=DIM, anchor="lm")
    d.text((40 * K, 490 * K), "Tailscale: the host's address goes in PhantomPact.ini, under HostAddress.",
           font=font(13), fill=DIM, anchor="lm")
    save(img, "online_bg")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    online_background()
    card("online_steam", "Steam", "friends, no setup")
    card("online_tailscale", "Tailscale", "the host's address")
    selected("sel_card", 176, 58)
    selected("sel_button", 170, 46)
    button("online_host", "HOST")
    button("online_join", "JOIN")
    button("online_leave", "LEAVE")
    print("online panel art written to", os.path.normpath(OUT))
