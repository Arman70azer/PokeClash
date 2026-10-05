"""Dessine les tombes du cimetière des expéditions (assets/tilesets/graves.png), dans le
style des décors du tileset : contour doux, lumière en haut à gauche, pierre gris-bleu,
un peu de mousse au pied. Chaque tombe est une forme (masque) ombrée automatiquement,
puis gravée. Relancer après modification :
    python tools/maps/build_graves.py

Les zones de chaque tombe dans l'image sont reprises dans
tools/data/build_expedition_biomes.py (GRAVES).
"""
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "tilesets", "graves.png")

OUTLINE = (52, 56, 70, 255)
DARK = (92, 97, 114, 255)
MID = (128, 133, 150, 255)
LIGHT = (164, 169, 184, 255)
HIGHLIGHT = (200, 204, 216, 255)
ENGRAVED = (76, 80, 98, 255)
MOSS = (86, 116, 70, 255)
MOSS_LIGHT = (118, 148, 88, 255)
GRASS = (70, 104, 62, 255)
GRASS_LIGHT = (102, 138, 78, 255)

# Tombes : nom -> (x, y, largeur, hauteur) dans l'image.
LAYOUT = {
    "grave_round": (0, 4, 16, 20),
    "grave_cross": (16, 0, 16, 24),
    "grave_double": (32, 4, 28, 20),
    "grave_broken": (60, 8, 16, 16),
}
SIZE = (76, 24)


def shaded(mask):
    """Pixels d'une forme pleine : contour sur les bords, puis du clair au sombre de
    gauche à droite sur chaque ligne, le haut de la forme éclairé."""
    pixels = {}
    for (x, y) in mask:
        if any((x + dx, y + dy) not in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            pixels[(x, y)] = OUTLINE
            continue
        row = [px for (px, py) in mask if py == y]
        left, right = min(row) + 1, max(row) - 1
        from_right = right - x
        if (x, y - 2) not in mask:
            color = HIGHLIGHT if from_right > 1 else LIGHT
        elif x == left:
            color = HIGHLIGHT
        elif from_right == 0:
            color = DARK
        elif from_right <= max(1, (right - left) // 4):
            color = MID
        else:
            color = LIGHT
        pixels[(x, y)] = color
    return pixels


def rounded_stone(x0, y0, w, h, radius):
    """Stèle : rectangle au sommet arrondi."""
    mask = set()
    for y in range(h):
        for x in range(w):
            if y < radius:
                cx = radius - 0.5 if x < w / 2 else w - radius - 0.5
                dx = max(0.0, abs(x - cx) - 0.0) if (x < radius or x >= w - radius) else 0.0
                if dx * dx + (radius - 0.5 - y) ** 2 > radius * radius:
                    continue
            mask.add((x0 + x, y0 + y))
    return mask


def rect(x0, y0, w, h):
    return {(x, y) for x in range(x0, x0 + w) for y in range(y0, y0 + h)}


def moss(pixels, rng, rows, amount):
    """Mousse en petites plaques sur le bas des pierres (pas sur le contour), plus dense
    vers le sol."""
    rows = list(rows)
    for (x, y), color in list(pixels.items()):
        if y not in rows or color == OUTLINE:
            continue
        depth = (rows.index(y) + 1) / len(rows)
        if rng.random() < amount * depth:
            pixels[(x, y)] = MOSS
            right = (x + 1, y)
            if right in pixels and pixels[right] != OUTLINE and rng.random() < 0.5:
                pixels[right] = MOSS_LIGHT


def stacked(*shapes):
    """Formes ombrées l'une après l'autre : chacune garde son contour par-dessus la
    précédente (une stèle posée sur son socle)."""
    pixels = {}
    for shape in shapes:
        pixels.update(shaded(shape))
    return pixels


def grass(pixels, x0, x1, y, rng):
    """Touffes d'herbe au pied de la tombe, par-dessus le bas du contour."""
    for x in range(x0, x1):
        if rng.random() < 0.55:
            pixels[(x, y)] = GRASS if rng.random() < 0.6 else GRASS_LIGHT
            if rng.random() < 0.35:
                pixels[(x, y - 1)] = GRASS_LIGHT


def grave_round(rng):
    x0, y0, w, h = LAYOUT["grave_round"]
    stone = rounded_stone(x0 + 3, y0 + 1, 10, 16, 5)
    base = rect(x0 + 2, y0 + 15, 12, 4)
    pixels = stacked(base, stone)
    # Croix gravée et deux lignes d'inscription.
    for y in range(y0 + 4, y0 + 9):
        pixels[(x0 + 8, y)] = ENGRAVED
    for x in range(x0 + 6, x0 + 11):
        pixels[(x, y0 + 5)] = ENGRAVED
    for x in range(x0 + 5, x0 + 11):
        pixels[(x, y0 + 11)] = ENGRAVED
    for x in range(x0 + 6, x0 + 10):
        pixels[(x, y0 + 13)] = ENGRAVED
    moss(pixels, rng, range(y0 + 12, y0 + 19), 0.35)
    grass(pixels, x0 + 1, x0 + 15, y0 + 19, rng)
    return pixels


def grave_cross(rng):
    x0, y0, w, h = LAYOUT["grave_cross"]
    pixels = stacked(rect(x0 + 4, y0 + 18, 8, 5), rect(x0 + 6, y0 + 1, 4, 19) | rect(x0 + 2, y0 + 5, 12, 4))
    # Rainure au croisement des bras.
    pixels[(x0 + 7, y0 + 6)] = ENGRAVED
    pixels[(x0 + 8, y0 + 7)] = ENGRAVED
    moss(pixels, rng, range(y0 + 14, y0 + 23), 0.35)
    grass(pixels, x0 + 3, x0 + 13, y0 + 23, rng)
    return pixels


def grave_double(rng):
    x0, y0, w, h = LAYOUT["grave_double"]
    stone = rounded_stone(x0 + 2, y0 + 1, 24, 16, 4)
    base = rect(x0 + 1, y0 + 15, 26, 4)
    pixels = stacked(base, stone)
    # Deux noms gravés, côte à côte.
    for left in (x0 + 5, x0 + 15):
        for x in range(left, left + 7):
            pixels[(x, y0 + 5)] = ENGRAVED
        for x in range(left + 1, left + 6):
            pixels[(x, y0 + 8)] = ENGRAVED
        for x in range(left + 1, left + 6):
            pixels[(x, y0 + 11)] = ENGRAVED
    moss(pixels, rng, range(y0 + 12, y0 + 19), 0.3)
    grass(pixels, x0 + 1, x0 + 27, y0 + 19, rng)
    return pixels


def grave_broken(rng):
    x0, y0, w, h = LAYOUT["grave_broken"]
    # Stèle brisée en biais, un éclat tombé à côté.
    top = [3, 2, 2, 3, 5, 6, 5, 7, 8]  # cassure irrégulière, plus haute à gauche
    stone = {(x0 + 3 + i, y) for i, t in enumerate(top) for y in range(y0 + t, y0 + 12)}
    base = rect(x0 + 2, y0 + 11, 11, 4)
    chip = rect(x0 + 12, y0 + 12, 3, 2) | {(x0 + 13, y0 + 11)}
    pixels = stacked(base, stone, chip)
    # Fissure.
    for i, (dx, dy) in enumerate(((5, 6), (6, 7), (6, 8), (7, 9))):
        pixels[(x0 + dx, y0 + dy)] = ENGRAVED
    moss(pixels, rng, range(y0 + 8, y0 + 15), 0.3)
    grass(pixels, x0 + 1, x0 + 15, y0 + 15, rng)
    return pixels


def main():
    img = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    for draw in (grave_round, grave_cross, grave_double, grave_broken):
        rng = random.Random(draw.__name__)
        for (x, y), color in draw(rng).items():
            if 0 <= x < SIZE[0] and 0 <= y < SIZE[1]:
                img.putpixel((x, y), color)
    img.save(OUT)
    print("écrit", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
