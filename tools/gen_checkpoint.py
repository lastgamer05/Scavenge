"""Generates game/data/maps/checkpoint.txt, the hardest raid zone: a Centra supply depot.

A walled compound with barracks, a depot, a motor pool and a command block whose vault
holds the safes. Gaps in the wall let Toa in from the scrubland to the south; most
guards carry rifles and SMGs, and the compound is well lit. R = rifle enemy.
Legend otherwise as in gen_ruins.py.
"""
import random
from pathlib import Path

W, H = 96, 72
rng = random.Random(23)
g = [[","] * W for _ in range(H)]


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c


def put(x, y, c):
    g[y][x] = c


def building(x0, y0, x1, y1, vx=(), hy=(), doors=()):
    """Rectangular building with interior walls. Each room boundary gets a 2-cell doorway."""
    rect(x0, y0, x1, y1, "#")
    rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, ".")
    ys = [y0] + list(hy) + [y1]
    xs = [x0] + list(vx) + [x1]
    for x in vx:
        rect(x, y0, x, y1, "#")
        for a, b in zip(ys, ys[1:]):
            m = (a + b) // 2
            put(x, m, ".")
            put(x, m + 1, ".")
    for y in hy:
        rect(x0, y, x1, y, "#")
        for a, b in zip(xs, xs[1:]):
            m = (a + b) // 2
            put(m, y, ".")
            put(m + 1, y, ".")
    for x, y in doors:
        put(x, y, ".")
        if x in (x0, x1):
            put(x, y + 1, ".")
        else:
            put(x + 1, y, ".")
    return (x0, y0, x1, y1)


def interior_cells(b):
    x0, y0, x1, y1 = b
    return [(x, y) for y in range(y0 + 1, y1) for x in range(x0 + 1, x1) if g[y][x] == "."]


def scatter(cells, chars):
    picks = rng.sample(cells, len(chars))
    for (x, y), c in zip(picks, chars):
        put(x, y, c)


rect(0, 0, W - 1, H - 1, "#")
rect(1, 1, W - 2, H - 2, ",")

# Compound wall with a main gate (north road) and breaches
CX0, CY0, CX1, CY1 = 8, 6, 87, 52
rect(CX0, CY0, CX1, CY0, "#")
rect(CX0, CY1, CX1, CY1, "#")
rect(CX0, CY0, CX0, CY1, "#")
rect(CX1, CY0, CX1, CY1, "#")
for x0, y0, x1, y1 in [(46, CY0, 49, CY0), (20, CY1, 22, CY1), (60, CY1, 62, CY1),
                       (CX0, 30, CX0, 32), (CX1, 22, CX1, 24), (38, CY1, 39, CY1)]:
    rect(x0, y0, x1, y1, "=" if y0 == CY0 else "%")
# Inner roads
rect(46, 1, 49, CY1 - 1, "=")
rect(CX0 + 1, 28, CX1 - 1, 30, "=")

barracks = [building(12, 9, 30, 18, vx=[21], doors=[(16, 18), (25, 18)]),
            building(12, 34, 30, 44, vx=[21], hy=[39], doors=[(16, 34), (25, 34), (30, 41)])]
depot = building(54, 9, 83, 22, vx=[64, 74], doors=[(58, 22), (68, 22), (78, 22), (54, 14)])
command = building(54, 34, 83, 49, vx=[66], hy=[42], doors=[(60, 34), (54, 38), (72, 34)])
vault = building(70, 43, 82, 48, doors=[(70, 45)])
motor_pool = [(34, 10), (38, 14), (34, 40), (39, 44)]
for x, y in motor_pool:  # parked trucks
    rect(x, y, x + 3, y + 1, "#")
# Guard posts: sandbag rings
for x, y in [(42, 25), (52, 25), (42, 32), (52, 32)]:
    rect(x, y, x + 1, y, "#")

# Scrub outside the walls
for x, y in rng.sample([(x, y) for y in range(H) for x in range(W) if g[y][x] in ",="], 120):
    put(x, y, "%")

# Floodlights inside, fires at the guard posts
for x, y in [(11, 8), (44, 8), (51, 8), (84, 8), (11, 27), (84, 27), (11, 50), (44, 50), (51, 50), (84, 50),
             (33, 31), (62, 31)]:
    put(x, y, "L")
for x, y in [(44, 26), (51, 33)]:
    put(x, y, "f")
for b in (barracks[0], depot):
    scatter(interior_cells(b), "f")

# Extraction: the south road out, a storm drain, a flare clearing and a fuel truck
rect(46, 69, 49, 70, "X")
rect(3, 60, 4, 61, "M")
rect(88, 62, 90, 64, "Z")
rect(90, 3, 92, 4, "V")
rect(90, 5, 92, 6, "#")

# Toa comes in through the scrub to the south
for x, y in [(10, 66), (30, 68), (70, 67), (90, 58)]:
    put(x, y, "P")

# Guards, loot and weapons
plan = [
    (barracks[0], "EFREFR", "llll", "s"),
    (barracks[1], "FRGERF", "lllc", "g"),
    (depot, "RFRGFRE", "ccccccv", "r"),
    (command, "RRFFGRF", "lllvv", "q"),
    (vault, "RF", "vvv", ""),
]
for b, enemies, loot, weapons in plan:
    scatter(interior_cells(b), enemies + loot + weapons)
yard = [(x, y) for y in range(CY0 + 1, CY1) for x in range(CX0 + 1, CX1) if g[y][x] in ",=%"]
scatter(yard, "RRFFEGRFRE" + "cccc")
outside = [(x, y) for y in range(CY1 + 2, H - 2) for x in range(2, W - 2) if g[y][x] in ",%"]
scatter(outside, "ccc" + "p")

out = Path(__file__).resolve().parent.parent / "game" / "data" / "maps" / "checkpoint.txt"
out.write_text("\n".join("".join(r) for r in g) + "\n", encoding="utf-8")
print(out)
