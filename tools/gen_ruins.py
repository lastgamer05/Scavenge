"""Generates game/data/maps/ruins.txt, the phase 3 open district map.

Legend (on top of test_yard's): = road, % rubble floor (walkable),
L gas lamp, f burning barrel / campfire,
X gate, M sewer, Z flare, V car extraction cells.
Several P cells: the game picks one at random.
"""
import random
from pathlib import Path

W, H = 112, 80
rng = random.Random(7)
g = [[","] * W for _ in range(H)]


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c


def put(x, y, c):
    g[y][x] = c


def building(x0, y0, x1, y1, vx=(), hy=(), doors=(), holes=1):
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
    # Collapsed sections of outer wall: extra ways in.
    for _ in range(holes):
        side = rng.choice("nsew")
        if side in "ns":
            x = rng.randint(x0 + 2, x1 - 3)
            y = y0 if side == "n" else y1
            put(x, y, "%")
            put(x + 1, y, "%")
        else:
            y = rng.randint(y0 + 2, y1 - 3)
            x = x0 if side == "w" else x1
            put(x, y, "%")
            put(x, y + 1, "%")
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

# Roads
rect(1, 18, W - 2, 21, "=")
rect(1, 50, W - 2, 53, "=")
rect(30, 1, 33, H - 2, "=")
rect(74, 1, 77, H - 2, "=")

# Buildings
apartment = building(4, 3, 26, 15, vx=[15], hy=[9], doors=[(10, 15), (20, 15)])
pharmacy = building(38, 4, 68, 15, vx=[48, 58], doors=[(42, 15), (63, 15)], holes=2)
warehouse = building(82, 3, 108, 16, vx=[96], doors=[(88, 16), (101, 16), (82, 8)])
office = building(38, 25, 68, 46, vx=[48, 58], hy=[35], doors=[(52, 25), (52, 46), (38, 30), (68, 40)], holes=2)
houses = [building(4, 25, 14, 33, doors=[(8, 25)]), building(17, 25, 27, 33, doors=[(21, 33)]),
          building(4, 38, 14, 46, doors=[(14, 41)]), building(17, 38, 27, 46, vx=[22], doors=[(21, 38)])]
factory = building(82, 25, 108, 46, vx=[95], hy=[36], doors=[(82, 30), (88, 25), (101, 46)], holes=2)
south = [building(6, 58, 26, 74, vx=[16], hy=[66], doors=[(10, 58), (26, 70)]),
         building(40, 58, 64, 74, vx=[52], doors=[(45, 58), (58, 74)]),
         building(84, 58, 106, 72, hy=[65], doors=[(90, 58), (84, 68)])]

# Factory machinery blocks
for cx, cy in [(86, 28), (90, 31), (99, 39), (103, 42), (86, 41)]:
    rect(cx, cy, cx + 1, cy + 1, "#")

# Outdoor rubble blocks and wrecked cars (cars sit on roads)
ground = [(x, y) for y in range(2, H - 2) for x in range(2, W - 2) if g[y][x] == ","]
for x, y in rng.sample(ground, 40):
    if all(g[yy][xx] == "," for yy in range(y - 1, y + 3) for xx in range(x - 1, x + 3)):
        rect(x, y, x + 1, y + rng.randint(0, 1), "#")
for x, y in [(8, 19), (44, 51), (62, 19), (31, 36), (75, 63), (96, 51), (75, 10)]:
    if g[y][x] == "=":
        if x in range(30, 34) or x in range(74, 78):
            rect(x, y, x + 1, y + 2, "#")
        else:
            rect(x, y, x + 2, y + 1, "#")
# Walkable debris
for x, y in rng.sample([(x, y) for y in range(H) for x in range(W) if g[y][x] in ",="], 140):
    put(x, y, "%")

# Lamps: only a few still burn
for x, y in [(12, 17), (36, 22), (56, 17), (72, 22), (80, 49), (40, 54), (20, 54), (72, 40)]:
    put(x, y, "L")

# Scavenger camps: fire with guards around it
camps = [(20, 49), (95, 49), (56, 77), (66, 22)]
for fx, fy in camps:
    put(fx, fy, "f")
for (fx, fy), guards in zip(camps, ["EGE", "FEH", "EGF", "EH"]):
    spots = [(fx + dx, fy + dy) for dx, dy in [(-2, -1), (2, 1), (-1, 2), (2, -2), (0, -2)]]
    for (x, y), c in zip([s for s in spots if g[s[1]][s[0]] in ",=%"], guards):
        put(x, y, c)
# Burning barrels inside a few buildings
for b in (office, factory, south[2]):
    scatter(interior_cells(b), "f")

# Extraction points
rect(109, 35, 110, 38, "X")  # gate on the east edge
rect(34, 66, 35, 67, "M")  # sewer manhole
rect(5, 52, 7, 54, "Z")  # flare zone on the west road
rect(101, 76, 103, 77, "V")  # parked car
rect(101, 74, 103, 75, "#")

# Player spawns on the outskirts
for x, y in [(3, 77), (60, 2), (110, 60), (3, 2)]:
    put(x, y, "P")

# Enemies, loot and weapons per building
plan = [
    (apartment, "EEH", "llc", "k"),
    (pharmacy, "EFH", "lllv", "q"),
    (warehouse, "EGF", "ccccv", "s"),
    (office, "EEFFGH", "lllvv", "r"),
    (houses[0], "E", "c", ""), (houses[1], "H", "l", "p"),
    (houses[2], "E", "c", "b"), (houses[3], "F", "lc", ""),
    (factory, "EFGH", "cccv", "g"),
    (south[0], "EGH", "llc", "p"),
    (south[1], "EF", "lcv", ""),
    (south[2], "EFG", "ccl", "s"),
]
for b, enemies, loot, weapons in plan:
    scatter(interior_cells(b), enemies + loot + weapons)
# Outdoor wanderers, crates and a couple of weapons
outdoor = [(x, y) for y in range(2, H - 2) for x in range(2, W - 2) if g[y][x] in ",%"]
scatter(outdoor, "EEFG" + "cccccc" + "pk")

out = Path(__file__).resolve().parent.parent / "game" / "data" / "maps" / "ruins.txt"
out.write_text("\n".join("".join(r) for r in g) + "\n", encoding="utf-8")
print(out)
