"""Generates game/data/maps/hideout.txt, the Bapas hideout in an abandoned metro station.

Legend on top of the raid maps': A leader, W weapons trader, D doctor, J junk dealer,
I informant, S stash, B donation box, X sortie gate.
"""
from pathlib import Path

W, H = 44, 26
g = [["."] * W for _ in range(H)]


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c


rect(0, 0, W - 1, H - 1, "#")
rect(1, 1, W - 2, H - 2, ".")
# Old platform edges: a cobbled walkway down the middle between pillar rows
rect(2, 11, W - 3, 14, "=")
for x in (9, 17, 26, 34):
    rect(x, 8, x + 1, 9, "#")
    rect(x, 16, x + 1, 17, "#")
# Trader nooks
rect(1, 4, 8, 4, "#")
rect(1, 21, 8, 21, "#")
rect(35, 4, W - 2, 4, "#")
rect(35, 21, W - 2, 21, "#")
for x in (4, 5, 39, 40):
    g[4][x] = "."
    g[21][x] = "."
# Sortie gate: the tunnel mouth on the east wall
rect(W - 1, 11, W - 1, 14, "X")
rect(W - 2, 11, W - 2, 14, "X")

for (x, y, c) in [(21, 3, "A"), (4, 2, "W"), (4, 23, "D"), (39, 2, "J"), (39, 23, "I"),
                  (14, 22, "S"), (28, 3, "B"), (6, 12, "P"),
                  (12, 2, "L"), (30, 2, "L"), (12, 23, "L"), (30, 23, "L"), (21, 6, "f"), (21, 19, "f")]:
    g[y][x] = c

out = Path(__file__).resolve().parent.parent / "game" / "data" / "maps" / "hideout.txt"
out.write_text("\n".join("".join(r) for r in g) + "\n", encoding="utf-8")
print(out)
