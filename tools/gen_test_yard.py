"""Generates game/data/maps/test_yard.txt (phase 1 test map).

Legend: # wall, . indoor floor, , outdoor ground, X extraction,
P player, E/F/G/H enemy (pistol/smg/shotgun/bat),
p/q/s/g/r/b/k weapon pickup (pistol/silenced/smg/shotgun/rifle/bat/knife).
"""
from pathlib import Path

W, H = 56, 38
g = [[","] * W for _ in range(H)]


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c


def outline(x0, y0, x1, y1):
    rect(x0, y0, x1, y1, "#")
    rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, ".")


def put(x, y, c):
    g[y][x] = c


rect(0, 0, W - 1, H - 1, "#")
rect(1, 1, W - 2, H - 2, ",")

# Main building with four rooms
outline(18, 6, 40, 26)
rect(29, 6, 29, 26, "#")
rect(18, 16, 40, 16, "#")
for y in (10, 11, 21, 22):
    put(29, y, ".")
for x in (23, 24, 34, 35):
    put(x, 16, ".")
for y in (19, 20):
    put(18, y, ".")
for x in (26, 27):
    put(x, 26, ".")
for y in (9, 10):
    put(40, y, ".")

# Shed
outline(44, 25, 52, 33)
for y in (29, 30):
    put(44, y, ".")

# Outdoor cover
for cx, cy in [(8, 8), (12, 20), (6, 26), (30, 31), (45, 15), (48, 8), (14, 12), (24, 33)]:
    rect(cx, cy, cx + 1, cy + 1, "#")
rect(4, 17, 10, 17, "#")

rect(51, 2, 52, 3, "X")
put(3, 35, "P")

for x, y, c in [(22, 9, "E"), (25, 12, "H"), (35, 11, "F"), (22, 21, "G"), (36, 22, "E"),
                (33, 19, "H"), (12, 6, "E"), (47, 19, "F"), (48, 30, "G"), (30, 3, "E")]:
    put(x, y, c)

for x, y, c in [(5, 33, "k"), (10, 30, "q"), (37, 8, "g"), (50, 31, "r"), (20, 24, "s"),
                (26, 8, "b"), (14, 34, "p")]:
    put(x, y, c)

out = Path(__file__).resolve().parent.parent / "game" / "data" / "maps" / "test_yard.txt"
out.write_text("\n".join("".join(r) for r in g) + "\n", encoding="utf-8")
print(out)
