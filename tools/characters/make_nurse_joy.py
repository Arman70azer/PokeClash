"""Fabrique la planche de l'Infirmière Joëlle (assets/characters/nurse_joy.png) à partir de
la dresseuse aux cheveux roses de la planche des dresseurs : tenue recolorée (robe rose,
tablier blanc), barrettes retirées, coiffe blanche à croix rouge.

Usage, depuis le dossier du projet : python tools/characters/make_nurse_joy.py
"""
from PIL import Image

SRC = "assets/characters/Overworld - Trainers (Overworld).png"
OUT = "assets/characters/nurse_joy.png"
BG = (32, 128, 96)
OUTLINE = (0, 0, 0)
RECOLOR = {
    # chemisier lilas -> tablier blanc
    (232, 232, 248): (248, 248, 248),
    (168, 168, 216): (216, 216, 232),
    # jupe marine -> robe rose pâle
    (72, 88, 152): (232, 152, 176),
    (48, 56, 88): (176, 88, 120),
    # barrettes jaunes -> cheveux
    (248, 168, 0): (200, 72, 88),
    (248, 232, 80): (240, 128, 136),
}
HAIR = {(240, 128, 136), (200, 72, 88), (248, 176, 184), (112, 48, 64), (192, 120, 144)}
WHITE = (248, 248, 248)
SHADE = (208, 208, 224)
RED = (224, 48, 56)
# Images de face, de profil et de dos (disposition des planches de dresseurs).
FRONT = {8, 5, 11}
BACK = {2, 0, 10}

src = Image.open(SRC).convert("RGB")
cell = src.crop((0, 384, 96, 512))
px = cell.load()
# La dernière colonne appartient à la case voisine de la planche : fond.
for y in range(cell.height):
    for x in range(94, 96):
        px[x, y] = BG
for y in range(cell.height):
    for x in range(cell.width):
        c = px[x, y]
        if c in RECOLOR:
            px[x, y] = RECOLOR[c]

for index in range(12):
    fx, fy = (index % 3) * 32, (index // 3) * 32
    # Haut de la tête : premières lignes de cheveux.
    rows = [y for y in range(fy, fy + 32) if any(px[x, y] in HAIR for x in range(fx + 1, fx + 31))]
    if not rows:
        continue
    top = rows[0]
    xs = [x for x in range(fx + 1, fx + 31) for y in range(top, top + 4) if px[x, y] in HAIR]
    cx = (min(xs) + max(xs)) // 2
    left = index in (3, 6, 9)
    right = index in (4, 1, 7)
    if left:
        cx -= 1
    if right:
        cx += 1
    # Coiffe : 9 pixels de large posée sur le haut de la tête (elle remplace les
    # premières lignes de cheveux), cernée de noir.
    x0, x1 = cx - 4, cx + 4
    for x in range(x0 - 1, x1 + 2):
        for y in range(top, top + 4):
            if x in (x0 - 1, x1 + 1) or y == top:
                if px[x, y] in HAIR or px[x, y] == BG:
                    px[x, y] = OUTLINE
            else:
                px[x, y] = WHITE if y < top + 3 else SHADE
    if index not in BACK:
        # Croix rouge : au milieu de face, décalée vers l'avant de profil.
        mx = cx - 2 if left else (cx + 2 if right else cx)
        for (dx, dy) in ((0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)):
            px[mx + dx, top + 2 + dy] = RED

cell.save(OUT)
print("écrit", OUT)
