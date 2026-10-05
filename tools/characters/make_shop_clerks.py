"""Fabrique les planches du vendeur et de la vendeuse de la boutique du Centre Pokémon
(assets/characters/clerk_male.png et clerk_female.png) à partir de deux personnages de la
planche des dresseurs, recolorés avec le tablier bleu des vendeurs de Noir et Blanc :

- vendeur : le cuisinier aux cheveux noirs ; son tablier blanc devient bleu, le liseré
  rouge devient blanc ;
- vendeuse : la jeune femme aux cheveux châtains ; son haut devient un tablier bleu et
  sa jupe un pantalon sombre.

Les deux portent la casquette bleue et blanche des vendeurs, reprise du dessin de la
casquette de Red (planche des dresseurs) pour garder le style des personnages.

Chaque planche garde la disposition des cases de dresseur (96 x 128, 12 images de 32 x 32).

Usage, depuis le dossier du projet : python tools/characters/make_shop_clerks.py
"""
from PIL import Image

SRC = "assets/characters/Overworld - Trainers (Overworld).png"
BG = (32, 128, 96)

BLUE = (72, 136, 224)
BLUE_SHADE = (40, 88, 176)
BLUE_DARK = (24, 56, 128)
WHITE = (248, 248, 248)
PANTS = (64, 64, 80)
PANTS_SHADE = (40, 40, 56)

CLERKS = {
    "assets/characters/clerk_male.png": {
        "origin": (672, 768),
        "recolor": {
            (232, 232, 248): BLUE,
            (168, 168, 192): BLUE_SHADE,
            (192, 192, 136): BLUE_SHADE,
            (192, 72, 96): WHITE,
        },
    },
    "assets/characters/clerk_female.png": {
        "origin": (96, 128),
        "recolor": {
            (120, 128, 56): BLUE,
            (72, 80, 24): BLUE_DARK,
            (56, 88, 144): PANTS,
            (56, 64, 104): PANTS_SHADE,
        },
    },
}


# Casquette : celle du dresseur Red de la planche (même dessin, mêmes 12 images, même
# ombrage que les personnages du jeu), recolorée en bleu, posée sur la tête de chaque
# vendeur. Le panneau blanc du devant reste blanc, comme sur les casquettes des vendeurs.
CAP_SOURCE = (0, 640)
CAP_RECOLOR = {
    (240, 104, 72): (104, 168, 240),
    (192, 56, 56): (56, 112, 208),
    (136, 40, 64): (32, 64, 144),
}
CAP_COLORS = set(CAP_RECOLOR) | {(232, 232, 248), (184, 176, 208), (56, 64, 64)}
OUTLINE = (0, 0, 0)
# Images de dos (disposition des planches de dresseurs).
BACK = {0, 2, 10}


SKIN = {(216, 160, 120), (248, 208, 184), (216, 152, 112), (232, 184, 152), (248, 216, 176)}


## Écart maximal (en pixels) dont on remonte la casquette quand le visage du vendeur
## commence plus haut que celui de Red : au-delà, elle flotterait au-dessus de la tête.
MAX_RAISE = 3
## Recul de la casquette sur la tête, en pixels : vers la nuque de profil, et en hauteur.
CAP_BACK = 1
CAP_UP = 0
## De profil, la casquette descend un peu plus bas sur la tête, en pixels.
CAP_SIDE_DOWN = 2
SIDE = {1, 3, 4, 6, 7, 9}


def cap_pixels(cell, index):
    """Pixels de la casquette de Red dans l'image `index` : {(dx, dy): couleur}, relatifs
    au sommet et au milieu de la tête, et l'écart entre le sommet de la tête et le visage."""
    fx, fy = (index % 3) * 32, (index // 3) * 32
    bg = cell.getpixel((0, 0))
    px = cell.load()
    cap = {(x, y) for x in range(fx, fx + 31) for y in range(fy, fy + 20) if px[x, y] in CAP_COLORS}
    bottom = max(y for _, y in cap)
    # Contour noir de la casquette (au-dessus de son bord bas).
    for x in range(fx, fx + 31):
        for y in range(fy, bottom + 1):
            if px[x, y] == OUTLINE and any((x + i, y + j) in cap for i in (-1, 0, 1) for j in (-1, 0, 1)):
                cap.add((x, y))
    top, center, face = head_anchor(px, fx, fy, bg)
    pixels = {(x - center, y - top): CAP_RECOLOR.get(px[x, y], px[x, y]) for x, y in cap}
    return pixels, face


def head_anchor(px, fx, fy, bg):
    """Sommet de la tête, milieu de la tête et écart jusqu'au haut du visage (None de dos)."""
    rows = [y for y in range(fy, fy + 32) if any(px[x, y] != bg for x in range(fx, fx + 31))]
    top = rows[0]
    xs = [x for x in range(fx, fx + 31) for y in range(top, top + 4) if px[x, y] != bg]
    skin = [y for y in range(top, top + 16) if any(px[x, y] in SKIN for x in range(fx, fx + 31))]
    return top, (min(xs) + max(xs)) // 2, (skin[0] - top) if skin else None


def add_cap(px, fx, fy, cap, red_face, fallback_raise, index=5):
    """Pose la casquette ; renvoie de combien elle a été remontée."""
    top, center, face = head_anchor(px, fx, fy, BG)
    raise_by = fallback_raise
    if face is not None and red_face is not None:
        raise_by = max(0, min(MAX_RAISE, red_face - face))
    # Casquette un peu reculée sur la tête : de profil, d'un pixel vers la nuque.
    cap_top = top - raise_by - CAP_UP + (CAP_SIDE_DOWN if index in SIDE else 0)
    center += {3: 1, 6: 1, 9: 1, 1: -1, 4: -1, 7: -1}.get(index, 0) * CAP_BACK
    xs = [center + dx for dx, _ in cap]
    # Cheveux au-dessus de la casquette : effacés.
    for x in range(min(xs), max(xs) + 1):
        for y in range(fy, max(fy, cap_top)):
            px[x, y] = BG
    for (dx, dy), color in cap.items():
        x, y = center + dx, cap_top + dy
        if fx <= x < fx + 32 and fy <= y < fy + 32:
            px[x, y] = color
    return raise_by


def main():
    src = Image.open(SRC).convert("RGB")
    sx, sy = CAP_SOURCE
    red = src.crop((sx, sy, sx + 96, sy + 128))
    caps = [cap_pixels(red, index) for index in range(12)]
    for out, spec in CLERKS.items():
        x, y = spec["origin"]
        cell = src.crop((x, y, x + 96, y + 128))
        background = cell.getpixel((0, 0))
        px = cell.load()
        for j in range(cell.height):
            for i in range(cell.width):
                c = px[i, j]
                if c == background:
                    px[i, j] = BG
                elif c in spec["recolor"]:
                    px[i, j] = spec["recolor"][c]
        # La grille de la planche n'est pas régulière : les bords de la case peuvent mordre
        # sur le fond de la case voisine (traits unis), qu'on efface.
        for i in list(range(3)) + list(range(cell.width - 3, cell.width)):
            column = [px[i, j] for j in range(cell.height)]
            if max(column.count(c) for c in set(column) if c != BG) > cell.height // 2 if set(column) - {BG} else False:
                for j in range(cell.height):
                    px[i, j] = BG
        for j in list(range(3)) + list(range(cell.height - 3, cell.height)):
            row = [px[i, j] for i in range(cell.width)]
            if max(row.count(c) for c in set(row) if c != BG) > cell.width // 2 if set(row) - {BG} else False:
                for i in range(cell.width):
                    px[i, j] = BG
        # De face d'abord : les images de dos reprennent le même écart.
        front_raise = add_cap(px, 64, 32, caps[5][0], caps[5][1], 0)
        for index in range(12):
            if index != 5:
                add_cap(px, (index % 3) * 32, (index // 3) * 32, caps[index][0], caps[index][1], front_raise, index)
        cell.save(out)
        print("écrit", out)


if __name__ == "__main__":
    main()
