"""Generates game/data/maps/facility.txt, the prologue: the collapse's ground-zero facility.

Extra legend: Q locked vault door (2 cells), K sealed case, T teammate start, X rooftop helipad.
"""
from pathlib import Path

W, H = 60, 46
g = [[","] * W for _ in range(H)]


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c


def put(x, y, c):
    g[y][x] = c


rect(0, 0, W - 1, H - 1, "#")
rect(1, 1, W - 2, H - 2, ",")
# Approach road and yard
rect(28, 33, 31, H - 2, "=")
for x, y in [(10, 38), (18, 41), (40, 37), (47, 41), (22, 36)]:
    rect(x, y, x + 1, y + 1, "#")

# Facility block
rect(3, 2, 56, 32, "#")
rect(4, 3, 55, 31, ".")
# Central hall running north
rect(26, 12, 26, 31, "#")
rect(33, 12, 33, 31, "#")
for y in (16, 17, 26, 27):
    put(26, y, ".")
    put(33, y, ".")
put(29, 32, ".")
put(30, 32, ".")
# West labs
rect(4, 22, 25, 22, "#")
rect(14, 12, 14, 31, "#")
for x in (8, 9, 19, 20):
    put(x, 22, ".")
for y in (17, 18, 27, 28):
    put(14, y, ".")
# East labs
rect(34, 22, 55, 22, "#")
rect(45, 12, 45, 31, "#")
for x in (39, 40, 50, 51):
    put(x, 22, ".")
for y in (17, 18, 27, 28):
    put(45, y, ".")
# North corridor wall separating labs from the top rooms
rect(4, 11, 55, 11, "#")
for x in (29, 30, 40, 41):
    put(x, 11, ".")
# Vault (top-left) behind a locked door
rect(18, 3, 18, 10, "#")
put(10, 11, "Q")
put(11, 11, "Q")
put(9, 5, "K")
# Stairwell to the roof (top-right): the helipad
rect(46, 3, 46, 10, "#")
put(46, 6, ".")
put(46, 7, ".")
rect(49, 4, 54, 9, "X")

# Machinery blocks in the labs
for x, y in [(7, 14), (21, 25), (37, 14), (49, 25), (8, 26), (38, 27)]:
    rect(x, y, x + 1, y, "#")

put(29, 42, "P")
for x, y in [(28, 43), (31, 43), (30, 44)]:
    put(x, y, "T")
for x, y, c in [(20, 15, "E"), (8, 18, "H"), (10, 27, "E"), (22, 29, "F"), (38, 16, "E"),
                (52, 18, "H"), (40, 29, "G"), (50, 28, "E"), (30, 6, "F"), (36, 8, "E"), (24, 5, "H")]:
    put(x, y, c)
for x, y, c in [(6, 29, "c"), (52, 14, "l"), (16, 4, "l"), (35, 4, "c")]:
    put(x, y, c)
put(30, 38, "p")

out = Path(__file__).resolve().parent.parent / "game" / "data" / "maps" / "facility.txt"
out.write_text("\n".join("".join(r) for r in g) + "\n", encoding="utf-8")
print(out)
