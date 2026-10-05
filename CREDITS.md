# Crédits

## Graphismes

- **Serene Village - revamped** (v1.9) par **LimeZu** : https://limezu.itch.io/serenevillagerevamped
  Licence : Creative Commons Attribution 4.0 International (CC-BY 4.0), https://creativecommons.org/licenses/by/4.0/
  Fichier utilisé : `assets/tilesets/serene_village/serene_village_16x16.png` (renommé, non modifié).
  La carte n'utilise plus ce tileset depuis le passage à `assets/tilesets/tileset.png`, mais les fichiers sont toujours dans le projet.

## Données

- **PokeAPI** (https://github.com/PokeAPI/pokeapi), licence BSD-3-Clause : tables CSV dans `source_assets/pokeapi/`, converties par `tools/data/import_pokeapi.py` en `data/pokemon/`, `data/moves/` et `data/abilities/`. Les noms et textes des Pokémon, attaques et talents restent la propriété de Nintendo / Game Freak / The Pokémon Company.

## Créations du projet

- `assets/maps/port/` (sauf les fichiers `accumula_*.png`, copiés d'Accumula Town) et `assets/mapobjects/port/` : modèles et textures créés pour PokeClash, générés par `tools/maps/build_port.py` et `tools/maps/build_port_objects.py`, dans le style des objets de Noir et Blanc.

Ce crédit doit rester visible dans le jeu publié (écran de crédits) et dans ce fichier.

## À remplacer avant toute diffusion

- `assets/characters/clerk_male.png` et `clerk_female.png` : vendeurs recolorés par `tools/characters/make_shop_clerks.py` à partir de la planche des dresseurs, même situation que celle-ci.
- `assets/characters/Ethan.png`, `assets/characters/Lyra.png` et `assets/characters/Overworld - Trainers (Overworld).png` : planches extraites de Pokémon HeartGold/SoulSilver (Nintendo / Game Freak), sans licence de réutilisation. Utilisable pour un prototype privé uniquement ; à remplacer par un personnage original ou sous licence libre avant de partager ou publier le jeu.
- `assets/Battle - Pokemon (1st Generation).png`, `assets/Trainers - Trainers (Front).png`, `assets/Trainers - Trainers (Back).png`, `assets/Trainers - Trainer Vs. Faces.png`, `assets/Miscellaneous - Battle Bases.png`, `assets/Miscellaneous - Text Boxes.png`, `assets/Battle HUD.png` (interface de Noir et Blanc, extraite par Ploaj) : sprites de combat extraits de Pokémon HeartGold/SoulSilver (Nintendo / Game Freak), via The Spriters Resource (Random Talking Bush, MufasaKong, Tsuka, Lemon), même situation.
- `assets/Font_Poke.png` : police extraite de Pokémon HeartGold/SoulSilver (Nintendo / Game Freak), même situation.
- `assets/tilesets/tileset.png` et sa version réorganisée `tileset_wide.png` : tileset fourni sans indication d'auteur ni de licence. Origine à vérifier avant toute diffusion.
- `assets/maps/pokemon_center/` : intérieur du Centre Pokémon extrait de Pokémon Noir 2/Blanc 2 (Nintendo / Game Freak), même situation.
- `assets/mapobjects/` : modèles 3D d'objets extraits de Pokémon Noir/Blanc, Noir 2/Blanc 2 et HeartGold/SoulSilver (Nintendo / Game Freak), même situation.
- `assets/maps/accumula_town/` : carte d'Accumula Town extraite de Pokémon Noir 2/Blanc 2 (Nintendo / Game Freak), même situation. `accumula_town.obj` et `.mtl` sont une conversion du fichier `.dae` d'origine (rangé dans `source_assets/maps/accumula_town/`), faite par `tools/maps/dae_to_obj.py` ; `accumula_town_grid.tres` est la grille de déplacement calculée à partir du modèle.
- Menu du jeu (Nintendo / Game Freak, même situation) :
  - `assets/icons_menu.png` : icônes de menu des Pokémon de X et Y, planche de MightyMewtwo (/u/Layell) ;
  - `assets/DS _ DSi - Pokemon Black _ White - Miscellaneous - Party Screen.png` : panneaux de l'écran d'équipe de Noir et Blanc, extraits par Floofy Panthar (crédit demandé) ;
  - `assets/DS _ DSi - Pokemon Black _ White - Miscellaneous - Miscellaneous Icons.png` : étiquettes de types et de statuts de Noir et Blanc (Smogon PokéAPI, KleinStudio / Pokémon Essentials BW) ;
  - `assets/DS _ DSi - Pokemon Black 2 _ White 2 - Miscellaneous - Items.png` et `... - Bags.png` : icônes d'objets et sacoches de Noir 2 et Blanc 2, extraites par Ploaj.
  - `assets/DS _ DSi - Pokemon Black _ White - Miscellaneous - Box Backgrounds.png` : fonds des boîtes du PC de Noir et Blanc (fonds des boîtes du PC de stockage).
