"""Planche du sol du désert des expéditions, tirée de Desert Resort (Noir 2 / Blanc 2) :
sable, sable ridé, sable orange des rencontres (cases de 16 × 16). Les falaises du désert
utilisent directement les textures de la carte (voir build_expedition_biomes.py).

    python tools/maps/build_desert_kit.py

Écrit assets/maps/desert_resort/desert_ground.png.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DESERT = os.path.join(ROOT, "assets", "maps", "desert_resort")
TEX = "Desert Resort Area 2_texture_%s.png"

# Case de la planche -> texture de la carte (sabaku = sable, e = rencontre).
TILES = {
    (0, 0): "0011",   # sable
    (1, 0): "00010",  # sable ridé
    (2, 0): "0045",   # sable orange : rencontres
}


def main():
    sheet = Image.new("RGBA", (16 * len(TILES), 16), (0, 0, 0, 0))
    for (x, y), name in TILES.items():
        tile = Image.open(os.path.join(DESERT, TEX % name)).convert("RGBA")
        sheet.paste(tile.crop((0, 0, 16, 16)), (x * 16, y * 16))
    sheet.save(os.path.join(DESERT, "desert_ground.png"))
    print("écrit", os.path.relpath(os.path.join(DESERT, "desert_ground.png"), ROOT))


if __name__ == "__main__":
    main()
