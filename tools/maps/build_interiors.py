"""Intérieurs des bâtiments d'Accumula, du quartier bourgeois et du port, tirés des cartes
intérieures de Pokémon Noir 2 / Blanc 2 (archives de source_assets/archives).

Pour chaque intérieur : le .dae est lu dans son archive, converti en .obj (voir
dae_to_obj.py) et agrandi 1,3 fois comme le Centre Pokémon, pour que les personnages
aient la même taille dans tous les intérieurs. Le modèle reste autour de son origine :
chaque carte le place dans le monde avec `cell_offset` (voir MapZone), ce qui permet de
réutiliser un même intérieur pour deux bâtiments identiques.

    python tools/maps/build_interiors.py

Puis, une fois le projet importé dans Godot, calculer la grille de chaque intérieur :
    godot --headless -s res://tools/maps/bake_map_grid.gd -- res://assets/maps/<nom>/<nom>.obj res://assets/maps/<nom>/<nom>_grid.tres
"""
import os
import shutil
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dae_to_obj  # noqa: E402
import place_model  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARCHIVES = os.path.join(ROOT, "source_assets", "archives")
ARCHIVE = "DS _ DSi - Pokemon Black 2 _ White 2 - Interior Maps - %s.zip"
SCALE = 1.3

# Dossier de assets/maps -> nom de l'intérieur dans les archives.
INTERIORS = {
    "nuvema_house_3_1f": "Nuvema Town House 3 1F",
    "nuvema_house_2_2f": "Nuvema Town House 2 2F",
    "aspertia_building_7": "Aspertia City Building 7",
    "aspertia_building_8": "Aspertia City Building 8",
    "black_city_house_1": "Black City House 1",
    "driftveil_hotel_room_1": "Driftveil City Hotel Room 1",
    "driftveil_hotel_room_3": "Driftveil City Hotel Room 3",
    "floccesy_house_5": "Floccesy Town House 5",
    "lentimas_house_6": "Lentimas Town House 6",
    "humilau_house_7": "Humilau City House 7",
    "cafe_warehouse_interior": "Cafe Warehouse",
    "nacrene_warehouse_interior": "Nacrene City Warehouse 1",
}


def build(folder, name):
    out = os.path.join(ROOT, "assets", "maps", folder)
    os.makedirs(out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(os.path.join(ARCHIVES, ARCHIVE % name)) as archive:
            archive.extractall(tmp)
        dae = None
        for base, _, files in os.walk(tmp):
            for f in files:
                if f.endswith(".png"):
                    shutil.copy(os.path.join(base, f), os.path.join(out, f))
                elif f.endswith(".dae"):
                    dae = os.path.join(base, f)
        dae_to_obj.main(dae, folder, out)
    place_model.main(os.path.join(out, folder + ".obj"), 0.0, 0.0, SCALE)


def main():
    for folder, name in INTERIORS.items():
        build(folder, name)


if __name__ == "__main__":
    main()
