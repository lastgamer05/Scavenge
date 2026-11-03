"""Generates game/data/maps/outskirts.txt, the first and easiest raid zone.

A small abandoned village: a quiet west end where Toa arrives (the combat lesson runs
there, so every enemy sits at least 20 cells east, beyond pistol earshot), a few houses
and a barn held by scavengers with bats and pistols, and two ways out.
Legend as in gen_ruins.py.
"""
import random
from pathlib import Path

W, H = 64, 48
rng = random.Random(11)
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

# Village roads
rect(1, 22, W - 2, 24, "=")
rect(34, 1, 36, H - 2, "=")

# West end: two empty cottages to loot while learning the ropes
cottages = [building(3, 12, 11, 19, doors=[(6, 19)]), building(14, 27, 22, 34, doors=[(17, 27)])]
# The village proper
houses = [building(40, 4, 49, 12, doors=[(44, 12)]), building(52, 4, 61, 12, vx=[56], doors=[(55, 12)]),
          building(40, 28, 50, 36, doors=[(44, 28)]), building(24, 38, 32, 45, doors=[(27, 38)])]
barn = building(50, 28, 61, 44, hy=[36], doors=[(50, 31), (55, 28)])

# Fences and hay bales outside
for x, y in [(14, 4), (20, 8), (26, 14), (8, 40), (44, 17), (57, 18), (39, 41)]:
    if all(g[yy][xx] == "," for yy in range(y, y + 2) for xx in range(x, x + 3)):
        rect(x, y, x + 2, y, "#")
ground = [(x, y) for y in range(2, H - 2) for x in range(2, W - 2) if g[y][x] == ","]
for x, y in rng.sample([(x, y) for y in range(H) for x in range(W) if g[y][x] in ",="], 60):
    put(x, y, "%")

# Lamps along the road, a campfire by the barn
for x, y in [(10, 21), (28, 25), (38, 21), (52, 25)]:
    put(x, y, "L")
put(45, 40, "f")
for (x, y), c in zip([(43, 39), (47, 41)], "HE"):
    put(x, y, c)
scatter(interior_cells(barn), "f")

# Extraction: the road out east, and a culvert in the south
rect(61, 22, 62, 24, "X")
rect(30, 46, 31, 46, "M")
rect(30, 45, 31, 45, ",")

# Toa arrives at the west end of the road
for x, y in [(3, 23), (4, 21), (3, 25)]:
    put(x, y, "P")

# Enemies (bats and pistols only), loot and weapons
plan = [
    (cottages[0], "", "lc", "k"),
    (cottages[1], "", "cl", ""),
    (houses[0], "H", "lc", ""),
    (houses[1], "E", "llc", "p"),
    (houses[2], "H", "cc", "b"),
    (houses[3], "E", "lc", ""),
    (barn, "HHE", "cccl", "p"),
]
for b, enemies, loot, weapons in plan:
    scatter(interior_cells(b), enemies + loot + weapons)
far_east = [(x, y) for y in range(2, H - 2) for x in range(30, W - 2) if g[y][x] in ",%"]
scatter(far_east, "HE" + "cc")
west = [(x, y) for y in range(2, H - 2) for x in range(2, 26) if g[y][x] in ",%"]
scatter(west, "cc")

# The combat lesson's gunshots must not wake anyone.
spawns = [(x, y) for y in range(H) for x in range(W) if g[y][x] == "P"]
for y in range(H):
    for x in range(W):
        if g[y][x] in "EFGHR":
            assert min((x - px) ** 2 + (y - py) ** 2 for px, py in spawns) >= 20 ** 2, (x, y)

out = Path(__file__).resolve().parent.parent / "game" / "data" / "maps" / "outskirts.txt"
out.write_text("\n".join("".join(r) for r in g) + "\n", encoding="utf-8")
print(out)
