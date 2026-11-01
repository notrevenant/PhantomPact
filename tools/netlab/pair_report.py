"""Compares what two copies of the game saw (tools/netlab/pair.lua), on the clock they share.

  python -I tools/netlab/pair_report.py <host recording> <guest recording>

For each side it reports how far the ghost on the other PC was from the real player, how far behind it runs, and how
evenly it moves. For the enemies the guest mirrors: how far apart the two copies were, and how soon health arrived.
"""
import bisect
import math
import sys


def load(path):
    rec = {"P": [], "G": [], "T": [], "E": {}}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            p = line.split()
            if len(p) < 5:
                continue
            if p[0] in "PGT":
                rec[p[0]].append(tuple(float(v) for v in p[1:5]))
            elif p[0] == "E" and len(p) >= 7:
                rec["E"].setdefault(p[2], []).append((float(p[1]), float(p[3]), float(p[4]), float(p[5]), float(p[6])))
    return rec


def at(path, t, _cache={}):
    """The path's position at time t, or None outside it."""
    times = _cache.setdefault(id(path), [r[0] for r in path])
    i = bisect.bisect_left(times, t)
    if i == 0 or i >= len(path):
        return None
    a, b = path[i - 1], path[i]
    f = (t - a[0]) / max(b[0] - a[0], 1e-6)
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f


def flat(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def pct(values, p):
    if not values:
        return float("nan")
    values = sorted(values)
    return values[min(len(values) - 1, int(len(values) * p))]


def line(name, values, unit):
    print(f"  {name:<34} p50 {pct(values, .5):7.1f}  p95 {pct(values, .95):7.1f}  max {max(values) if values else float('nan'):7.1f} {unit}")


def ghost(title, real, shown):
    print(title)
    if len(real) < 10 or len(shown) < 10:
        print("  not enough data")
        return
    moving = []
    for a, b in zip(real, real[1:]):
        dt = b[0] - a[0]
        if dt > 0 and math.hypot(b[1] - a[1], b[2] - a[2]) / dt > 50:
            moving.append(b[0])
    now_err, best = [], None
    for g in shown:
        r = at(real, g[0])
        if r:
            now_err.append(flat(g[1:], r))
    # How far behind it runs: the delay at which the ghost lines up best with the real path.
    for ms in range(0, 400, 5):
        errs = []
        for g in shown[::3]:
            r = at(real, g[0] - ms / 1000)
            if r:
                errs.append(flat(g[1:], r))
        if errs:
            score = sum(errs) / len(errs)
            if best is None or score < best[0]:
                best = (score, ms)
    jumps = sum(1 for a, b in zip(shown, shown[1:]) if flat(a[1:], b[1:]) > 150)
    speed_change = []
    for a, b, c in zip(shown, shown[1:], shown[2:]):
        d1, d2 = max(b[0] - a[0], 1e-3), max(c[0] - b[0], 1e-3)
        v1 = (b[1] - a[1]) / d1, (b[2] - a[2]) / d1
        v2 = (c[1] - b[1]) / d2, (c[2] - b[2]) / d2
        speed_change.append(math.hypot(v2[0] - v1[0], v2[1] - v1[1]))
    line("gap to the real player, same moment", now_err, "cm")
    print(f"  runs behind the real player by {best[1]} ms, and is then off by {best[0]:.1f} cm on average")
    line("speed change frame to frame", speed_change, "cm/s")
    print(f"  jumps over 150 cm in one frame: {jumps} of {len(shown)} frames")


def enemies(host, guest):
    print("enemies, guest's copy against the host's:")
    gaps, stale, shared = [], [], 0
    for name, ours in guest["E"].items():
        theirs = host["E"].get(name)
        if not theirs or len(theirs) < 5:
            continue
        shared += 1
        for row in ours[::2]:
            r = at(theirs, row[0])
            if r:
                gaps.append(flat(row[1:], r))
    print(f"  {shared} enemies seen on both")
    if gaps:
        line("distance between the two copies", gaps, "cm")
    # Health: when did the guest's copy reach each value the host's passed through?
    delays = []
    for name, ours in guest["E"].items():
        theirs = host["E"].get(name)
        if not theirs:
            continue
        for a, b in zip(theirs, theirs[1:]):
            if b[4] < a[4] - 1:
                for row in ours:
                    if row[0] >= b[0] - 1 and row[4] <= b[4] + 1:
                        delays.append((row[0] - b[0]) * 1000)
                        break
    if delays:
        line("host's health change shown on guest", delays, "ms")


def main():
    host, guest = load(sys.argv[1]), load(sys.argv[2])
    print("frames recorded: host", len(host["P"]), "guest", len(guest["P"]))
    ghost("host's player, as the guest sees it:", host["P"], guest["G"])
    ghost("guest's player, as the host sees it:", guest["P"], host["G"])
    enemies(host, guest)


if __name__ == "__main__":
    main()
