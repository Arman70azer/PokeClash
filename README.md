# PokeClash

Jeu d'aventure façon DS avec créatures originales, jouable de 2 à 4 en coopération sur la même carte. Moteur : Godot 4 (GDScript).

## Ouvrir et tester

1. Installer Godot 4 (version standard, 4.3 ou plus récente) depuis https://godotengine.org/download/windows/
2. Lancer Godot, cliquer sur **Importer**, choisir le fichier `project.godot` de ce dossier.
3. Menu **Débogage > Personnaliser les instances d'exécution**, cocher **Activer plusieurs instances** et mettre 2 (jusqu'à 4).
4. Appuyer sur **F5** : deux fenêtres s'ouvrent.
5. Dans la première, cliquer sur **Héberger**. Dans la seconde, laisser `127.0.0.1` et cliquer sur **Rejoindre**.
6. Se déplacer avec les flèches ou ZQSD. Parler à un personnage en se plaçant face à lui puis Espace, Entrée ou E (la même touche fait défiler le dialogue). Échap quitte la session.

## Organisation

Le projet est rangé par fonctionnalité : chaque dossier regroupe les scènes et scripts d'un même système. Le journal des changements de structure est dans `docs/REFACTORING_LOG.md`.

```
project.godot          configuration (352x264, mise à l'échelle entière, filtre nearest), autoloads
main.tscn              scène principale : monde (cartes, joueurs), interface, combats, profils
core/                  socle commun
  network.gd           autoload Network : héberger / rejoindre / quitter (ENet, port 7777)
  game.gd              autoload Game : accès aux services (Game.world, Game.battles, Game.dialogue...)
  events.gd            autoload Events : signaux globaux (message_requested...)
  game_config.gd       taille des cases, règles de passage entre zones, taille de l'écran
  input_setup.gd       touches du jeu (clavier et manette)
world/                 le monde et ses cartes
  world.gd             chargement des cartes, apparition des joueurs, caméra
  game_map.gd          une carte : sol, obstacles, PNJ, passages (racine de chaque scène de maps/)
  map_zone.gd          zone faite d'un grand modèle 3D et de sa grille
  tile_zone.gd         zone faite de tuiles et d'objets 3D
  map_grid.gd          grille de déplacement : hauteurs et passages, case par case
  map_materials.gd     matériaux façon DS des modèles 3D
  map_object_3d.gd     objet 3D posé sur une carte (maison, bateau...)
  door.gd, warp.gd     portes animées et passages (y compris vers une autre carte)
  camera/              CameraRig (caméra qui suit le joueur) et CameraProfile (réglages)
maps/                  une carte par dossier : maps/<id>/<id>.tscn
  accumula/            Accumula Town, avec le quartier bourgeois et le port
  accumula_pokemon_center/   intérieur du Centre Pokémon
characters/            personnages du monde
  character_sprite.gd  sprite, ombre et halo d'un personnage
  character_sheet.gd   description d'une planche (une par personnage dans data/characters)
  sheet_loader.gd      détourage et mesure des planches
  npc.gd               personnage non joueur
player/                le joueur : déplacement (player.gd), conversations (player_interaction.gd),
                       passages de porte (warp_transition.gd), scène player.tscn
profile/               données des joueurs : PlayerProfiles (chez l'hôte), SaveService (fichiers),
                       NewGameConfig (ce que reçoit un nouveau joueur)
battle/                module de combat (voir « Combats »)
expedition/            zones d'expédition générées au hasard (voir « Expéditions »)
ui/                    menu, boîte de dialogue, police, fondu au noir
data/                  données de jeu (.tres) : pokemon, moves, items, trainers, characters, config
shaders/               rendu pixel des personnages et des cartes
tools/
  maps/                conversion des modèles, cuisson des grilles, génération du port
  characters/          fabrication de planches (make_nurse_joy.py)
  data/                import des Pokémon (PokeAPI), zones d'expédition
  tests/               tests automatiques (combat, PC, expéditions, partie complète, deux joueurs)
assets/                ressources utilisées par le jeu (voir assets/README.md)
source_assets/         fichiers sources (.dae, archives .zip), ignorés par Godot
docs/                  aperçus et journal de refactorisation
```

## Rendu en fausse 3D

Comme sur DS, le monde est une scène 3D vue par une caméra inclinée en perspective, affichée en 352x264 (un peu plus large que la résolution DS) :

- chaque carte (`maps/<id>`) contient une ou plusieurs zones : un grand modèle 3D qui contient le sol, le relief, les bâtiments et le décor ;
- les personnages sont des sprites 2D, affichés pixel pour pixel, qui passent devant ou derrière le décor selon leur position.

Échelle : 16 unités = 1 case ; à l'endroit visé par la caméra, 1 unité = 1 pixel. L'inclinaison, le champ et le cadrage de la caméra sont un profil de caméra (`CameraProfile`) : la vue par défaut est `data/config/camera/overworld.tres`. On peut donner un autre profil au nœud `World` (champ `camera_profile`) sans toucher au code.

### Halo de vision

Quand le décor cache entièrement le personnage de ce joueur (derrière un bâtiment, un bateau, un mur d'Accumula), une lueur douce apparaît en fondu autour de lui et le personnage est dessiné par-dessus le décor. Tant qu'un seul pixel du personnage reste visible, le halo ne s'active pas.

Pour le savoir, `CameraRig.is_hiding` lance à chaque image un rayon de la caméra vers chaque pixel opaque du sprite (un sur trois en largeur et en hauteur, `CharacterSprite.vision_points`). Les rayons ne touchent que des volumes de collision réservés à cet usage (couche `MapMaterials.VISION_LAYER`), construits au chargement à partir des surfaces opaques des zones 3D et des objets 3D (`MapMaterials.add_vision_collider`). Le halo et le personnage vu à travers le décor utilisent `shaders/vision_halo.gdshader` et `shaders/pixel_sprite_xray.gdshader`. Les arbres et décors des zones en tuiles ne comptent pas encore. Seul l'écran du joueur concerné affiche le halo.

## Zones et déplacements

La ville actuelle est `assets/maps/accumula_town`, utilisée par la carte `maps/accumula`. Un modèle de zone n'a pas de collisions : elles viennent d'une grille (`MapGrid`) calculée à partir du modèle. Pour chaque case de 16x16 unités, la grille donne la hauteur du sol et les passages possibles vers les cases voisines : un escalier se monte, un mur, un rebord de terrasse, une clôture ou un arbre arrêtent.

Pour utiliser une autre zone :

1. Déposer le modèle et ses textures dans un dossier de `assets/maps/`.
2. Si le modèle est un `.dae`, le ranger dans `source_assets/maps/<zone>/` (Godot l'ignore : son importeur Collada perd une partie de ces cartes) et le convertir, le `.obj` étant écrit à côté des textures :
   `python tools/maps/dae_to_obj.py "source_assets/maps/<zone>/<modèle>.dae" <nom> assets/maps/<zone>`
3. Ouvrir le projet dans Godot une fois pour importer le `.obj`, puis calculer la grille :
   `godot --headless -s res://tools/maps/bake_map_grid.gd -- res://assets/maps/<zone>/<nom>.obj res://assets/maps/<zone>/<nom>_grid.tres`
   La commande affiche la grille : `o` atteignable, `.` praticable mais isolée, `#` bloquée.
4. Dans la scène de la carte (`maps/<id>/<id>.tscn`), régler `mesh` et `walk_grid` de la zone, puis `spawn_cells` de la racine (les cases de départ des joueurs) et la case de chaque PNJ.

Le calcul peut se tromper. Pour le corriger, ouvrir le fichier de grille (`<nom>_grid.tres`) dans l'inspecteur :

- `blocked` : cases à interdire (de l'eau au niveau du sol, par exemple) ;
- `walkable` : cases à autoriser (un tapis pris pour un obstacle, par exemple), avec leurs passages dans `opened` ;
- `offsets` : décalage d'affichage d'une case, en unités (un personnage s'y tient un peu à côté du centre, par exemple collé à un comptoir sans le chevaucher) ;
- `opened` : passages à autoriser entre deux cases voisines, notés (x1, y1, x2, y2) (un petit décor franchissable pris pour un obstacle, par exemple les touffes d'herbe au bord d'une pelouse).

Ces corrections sont conservées quand on recalcule la grille. Les coordonnées d'une case sont visibles en jeu en divisant la position du personnage par 16.

### Fondu de niveau

Quand un personnage descend dans une partie en contrebas (la place basse d'Accumula Town), un muret du niveau supérieur peut lui masquer la vue. La zone `Zone` de la carte `maps/accumula` peut effacer ce muret progressivement, en trame de pixels, à mesure que le joueur descend, et le faire réapparaître quand il remonte. Dans l'inspecteur, groupe **Fondu de niveau** :

- `fade_cells` : les cases où le fondu peut se déclencher (la place basse et son escalier) ;
- `fade_box` : la boîte, en unités du monde, de la géométrie à effacer ;
- `fade_level` et `fade_depth` : la hauteur du niveau supérieur et la descente nécessaire pour un effacement complet.

Le fondu s'applique à tout ce qui se trouve dans la boîte, quelle que soit la zone : à Accumula Town, il efface aussi le sol, les bâtiments, les arbres et les réverbères du quartier bourgeois qui se trouvent juste au sud de la place basse. Il ne concerne que l'écran du joueur qui descend : les autres joueurs voient la carte normalement.

Pour poser un objet de `assets/mapobjects/` sur une carte, ajouter sous son nœud `Objects` un `MeshInstance3D` avec le script `map_object_3d.gd`, régler son `mesh`, sa position (x et z en unités, y = hauteur du sol) et son `footprint` (les cases qu'il bloque).

## Zones en tuiles

Une zone peut aussi se construire à la main avec le tileset et les objets de `assets/mapobjects`, sans grand modèle : c'est le cas du quartier bourgeois (`maps/accumula/quartier_bourgeois.tscn`), placé dans la carte `maps/accumula`, au sud d'Accumula Town.

Ouvrir sa scène, passer en vue **2D** et peindre sur ses calques avec le TileSet `assets/tilesets/tileset.tres` (coordonnées des cases du monde) :

- `Ground` : le sol de base (herbe) ; une case sans sol n'est pas praticable ;
- `GroundDetail` : pavés, chemins, eau (les tuiles `solid` bloquent) ;
- `GroundDecor` : motifs posés par-dessus ;
- `Obstacles` : décor debout qui bloque sa case. Un arbre se peint avec ses quatre tuiles centrales (2x2 cases) ; un réverbère ou un sapin, avec sa seule tuile du bas. Ces décors sont listés dans `TREE_REGIONS` et `TALL_PROPS` au début de `world/tile_zone.gd`.

Les bâtiments sont des `MapObject3D` sous le nœud `Buildings` : `mesh`, position, `footprint` (cases bloquées) et `model_scale` (16 pour la fontaine, 8 pour les parasols, modélisés plus petits). `scrolling_surfaces` fait défiler la texture de certaines surfaces pour animer de l'eau : c'est ainsi que coule la fontaine (surfaces `fou_01` et `fou_01_3`). La grille de déplacement se calcule toute seule au lancement.

Le TileSet contient une seconde source de tuiles : le dallage d'Accumula Town (`assets/maps/accumula_town/Accumula Town_texture_0024.png`), utilisé à l'entrée du quartier pour prolonger la place d'Accumula sans rupture.

On passe d'une zone à l'autre entre deux cases voisines de même hauteur : l'avenue du quartier prolonge la sortie sud de la place d'Accumula.

## Le port

À l'est d'Accumula Town, le port (`maps/accumula/port.tscn`) est une zone en 3D comme Accumula : un modèle (`assets/maps/port/port.obj`) et sa grille de déplacement. On y entre en continuant vers la droite sur la grande route pavée d'Accumula.

- Raccord avec Accumula : la route pavée continue sur une case avec la même texture, calée au pixel près, puis viennent une fine bordure de pierre (celle des trottoirs d'Accumula, 3 unités de large) et directement le béton du quai. La texture d'Accumula utilisée est copiée dans `assets/maps/port/` (fichiers `accumula_*.png`).
- Le quai en béton est bordé d'une margelle de pierre et d'un mur qui descend dans l'eau. Au bout du quai, une fine bande de pierre claire marque le pied de la grande jetée en bitume (six cases de large), où accostent le ferry et le porte-conteneurs. Les pontons en bois (trois cases de large, appontements de deux), sobres, une marche plus bas, accueillent les autres bateaux ; on y descend par quelques marches.
- La mer est un modèle à part (`port_water.obj`), qui ne compte pas dans la grille : on ne marche pas dessus. Sa texture défile lentement (`scrolling_surfaces` du nœud `Water`).
- Objets créés pour le port, dans `assets/mapobjects/port/` : ferry (20 cases de long), porte-conteneurs, chalutier, voilier, barque, passerelle d'embarquement, bouées de chenal rouge et verte, bouée de sauvetage, bitte d'amarrage, réverbère, caisses, fûts et conteneurs. Les bateaux existent aussi tournés d'un quart de tour (suffixe `_v`), pour s'amarrer le long des pontons nord-sud. On y trouve aussi des modèles déjà présents : la grue et le phare de Driftveil City, un entrepôt frigorifique, un entrepôt de Nacrene City et le café.
- Bâtiments : chaque entrée est centrée sur une case et la façade est posée sur une limite de cases, pour que le joueur se retrouve bien en face de la porte (café : case (24, -13) ; entrepôt frigorifique : (27, 0) ; entrepôt de Nacrene, agrandi à 1,4 : (24, 12) ; phare : (46, -6)). Les cases bloquées (`footprint`, `extra_cells`) suivent les murs réels, escalier extérieur compris.
- Ce qui flotte se balance doucement : réglages `bob_height` (amplitude, en unités) et `bob_period` (en secondes) d'un `MapObject3D`.

Pour modifier le plan du port (taille des quais, pontons...), changer `tools/maps/build_port.py`, le relancer (`python tools/maps/build_port.py`), puis recalculer la grille :
`godot --headless -s res://tools/maps/bake_map_grid.gd -- res://assets/maps/port/port.obj res://assets/maps/port/port_grid.tres`.
Les objets se modifient de la même façon avec `tools/maps/build_port_objects.py`. Leur placement est écrit par `tools/maps/build_port_scene.py`, qui régénère toute la scène du port : modifier ce script plutôt que la scène, puis le relancer (`python tools/maps/build_port_scene.py`).

## Centre Pokémon

Avancer vers la porte du Centre Pokémon d'Accumula l'ouvre comme dans le jeu : la porte arrondie se sépare en deux battants qui glissent chacun de leur côté en suivant la courbe de la façade, le joueur entre, l'écran passe au noir et il se retrouve dans le Centre (`assets/maps/pokemon_center/`, modèle de Noir 2 et Blanc 2 converti par `tools/maps/dae_to_obj.py`, puis agrandi 1,3 fois et éloigné de la ville par `tools/maps/place_model.py` (`python tools/maps/place_model.py assets/maps/pokemon_center/pokemon_center.obj 4008.8 0 1.3`)). Le tapis du bas ramène dehors, porte ouverte qui se referme derrière lui.

- L'intérieur est une carte à part (`maps/accumula_pokemon_center`), placée à l'écart de la ville dans le monde. Un passage est un nœud `Warp` sous le nœud `Warps` d'une carte : cases qui le déclenchent, direction, carte d'arrivée (`target_map`), case et orientation d'arrivée, porte de départ et nom de la porte d'arrivée. Une porte animée est un nœud `Door` sous le nœud `Doors` d'une carte : zone et surface de la porte dans le modèle, et angle d'ouverture ; les battants sont découpés dans la porte du modèle, et le centre de la courbe est calculé tout seul. Le passage est décidé par l'hôte ; seul le joueur concerné voit la porte et le fondu (`ScreenFade`), les autres le voient disparaître puis réapparaître.
- L'Infirmière Joëlle est derrière le comptoir : on lui parle depuis l'autre côté (`talk_reach` du PNJ), et elle soigne toute l'équipe (`heals_party`, soin fait chez l'hôte). Son sprite (`assets/characters/nurse_joy.png`) est fait par `tools/characters/make_nurse_joy.py` à partir de la dresseuse aux cheveux roses de la planche des dresseurs : tenue rose à tablier blanc, coiffe blanche à croix rouge, mêmes 12 images d'animation.
- Couleurs : les textures des cartes et des objets sont importées sans compression (la compression des cartes graphiques ternissait les petites textures, surtout les bleus). Une zone peut aussi être ravivée avec `saturation`, `contrast` et `brightness` (MapZone) ; l'intérieur du Centre Pokémon est à 1,15 et 1,05, avec son ombrage de sommets réduit (`vertex_shading` 0,35) et ses ombres portées allégées (`shadow_opacity` 0,3), comme en ville.

## Menu du jeu

En exploration, Échap, X ou Start (manette) ouvre le menu : la liste à gauche, l'équipe à droite (icône, nom, niveau, statut, jauge et PV de chaque Pokémon). Il reprend le style de l'écran de combat : fond brun à petits points de l'écran tactile, boutons crème à bande de couleur, cadres de message blancs liserés de bleu, chiffres et jauges du HUD. Ces éléments sont dessinés par `ui/ds_ui.gd` (DsUi), partagé par le combat, le menu et la boîte de dialogue. À l'ouverture, la liste et l'équipe glissent depuis les bords de l'écran. Haut et bas pour choisir, `interact` pour valider, `cancel` ou la touche du menu pour revenir.

- **Pokémon** : on parcourt l'équipe ; valider ouvre le résumé complet (voir ci-dessous).
- **Sac** : les objets par poche (gauche / droite pour changer de poche), avec leur icône et leur description. Un objet de soin s'utilise sur un Pokémon de l'équipe, choisi dans la colonne de droite.
- **Sauvegarde** : pseudo, lieu, nombre de Pokémon et temps de jeu, puis l'hôte sauvegarde la partie.
- **Quitter** : quitte la session (l'hôte sauvegarde le joueur qui part).

Le menu affiche une copie des données envoyée par l'hôte (`PlayerProfiles.request_snapshot`) ; utiliser un objet ou sauvegarder est une demande à l'hôte, qui répond avec une copie à jour. Fichiers : `menu/game_menu.gd` (le menu), `menu/party_panel.gd` (la colonne de l'équipe), `menu/menu_sprites.gd` (icônes, étiquettes de types, sacoche).

Icônes : chaque espèce a `icon_sheet` et `icon_region` (planche `assets/icons_menu.png`, cases de 32x32 rangées par numéro du Pokédex : colonne `(n-1) % 26`, ligne `(n-1) / 26`, coin à (9 + 38 x colonne, 94 + 38 x ligne)) ; chaque objet a aussi `icon_sheet` et `icon_region` (planche des objets de Noir 2 et Blanc 2, cases de 32x32). Le fond de la case est rendu transparent. Un objet utilisable hors combat redéfinit `can_use_on_pokemon` et `use_on_pokemon` (voir `HealItem`).

## Boutique

Dans le Centre Pokémon, à droite, un vendeur et une vendeuse au tablier bleu et à la casquette bleue et blanche (reprise du dessin de la casquette de Red) se tiennent derrière le comptoir bleu (cases (244, 1) et (244, 3)) ; on leur parle depuis n'importe quelle case le long du comptoir. Le joueur et les vendeurs y sont dessinés collés au comptoir grâce aux décalages d'affichage de la grille (`offsets`). Leurs planches (`assets/characters/clerk_male.png`, `clerk_female.png`) sont faites par `tools/characters/make_shop_clerks.py` à partir de deux personnages de la planche des dresseurs, recolorés.

Après leurs répliques, l'écran de la boutique s'ouvre (`shop/shop_screen.gd`), dans le même style que le combat et le menu : Acheter, Vendre ou Au revoir. On choisit l'objet, puis la quantité (haut / bas : une unité, gauche / droite : dix), avec le total ; on revend un objet à la moitié de son prix. L'hôte vérifie l'argent et le sac, fait l'échange et sauvegarde.

- Une boutique est un fichier `ShopData` dans `data/shops/` (la liste des objets vendus, à leur prix `ItemData.price`), désigné par le champ `shop` d'un PNJ. `looks_around` faux garde le vendeur tourné vers son comptoir.
- Objets en vente au Centre d'Accumula : Poké Ball, Super Ball, Potion, Super Potion, Antidote, Anti-Para. Les Balls ne servent pas encore (pas de capture).
- Un nouveau joueur commence avec 3 000 Pokédollars (`data/config/new_game.tres`).

## PC de stockage

Dans le Centre Pokémon, le terminal à gauche du comptoir de l'infirmière est un PC (case (235, -6), son pied) : on l'utilise de face depuis (235, -5), ou de côté. Après « Arman allume le PC. », l'écran du PC s'ouvre avec un fondu au noir. Il reprend les boutons, le curseur, les cadres et les chiffres du menu et de la boutique, mais sur des panneaux clairs (blanc bleuté à petits points, `DsUi.draw_light_panel`) pour rester lumineux :

- à gauche, sur toute la hauteur, la boîte : le petit paysage du fond de Noir et Blanc en titre, et son motif étendu sous une grille de 6 × 5 grandes places ; en haut, gauche / droite change de boîte ;
- à droite, l'équipe (la même colonne que dans le menu) ;
- sous la grille, le Pokémon désigné (nom, niveau, PV) et le remplissage de la boîte. Les messages n'apparaissent que lorsqu'il y en a.

L'écran s'allume comme un vieil écran : une ligne lumineuse s'étire depuis le centre, s'ouvre en hauteur, puis s'efface pendant que la boîte et l'équipe arrivent ; il s'éteint de la même façon.

Valider sur un Pokémon propose Déplacer, Résumé ou Annuler. « Déplacer » le prend en main : il suit le curseur, et valider le pose (place vide) ou l'échange (place occupée), dans une boîte ou dans l'équipe. Retour le repose sans rien changer. La touche du menu ouvre les réglages de la boîte : Renommer (au clavier), Fond (24 fonds), Quitter le PC.

- Règles (toutes dans `storage/pokemon_storage.gd`) : jamais plus de 6 Pokémon dans l'équipe ; toujours au moins un Pokémon en état de se battre dans l'équipe ; un Pokémon déposé dans une boîte est soigné ; une opération refusée ne change rien.
- Réglages : `data/config/storage.tres` (8 boîtes de 30 places, 6 colonnes, noms et fonds par défaut, soin au dépôt).
- L'hôte fait autorité : l'écran demande l'opération (`PlayerProfiles.request_pc_move`, `request_pc_rename`, `request_pc_wallpaper`), l'hôte la vérifie, l'applique, sauvegarde et renvoie une copie à jour.
- Chaque Pokémon a un identifiant unique (`PokemonInstance.uid`) : `PokemonStorage.validate()` vérifie qu'aucun n'est à deux endroits.
- Sauvegarde : format version 2 (boîtes et identifiants). Une sauvegarde de version 1 se charge (boîtes vides, identifiants créés) et une copie intacte est gardée à côté (`<pseudo>.json.v1.bak`) avant d'être réécrite.
- L'écran du terminal s'allume dans le décor pendant le message (images de sa bande d'animation : éteint, à moitié, allumé) et s'éteint quand on quitte le PC : `PcTerminal` décale la texture de la surface `lambert4` du modèle (uniforme `uv_offset` des matériaux de carte).
- Pour ajouter un PC ailleurs : un nœud `PcTerminal` (script `world/pc_terminal.gd`) sous `Objects`, sur la case du terminal. Régler `zone_path` (la zone qui contient le modèle) et `screen_surface` (la surface de l'écran) pour animer son écran. Tout ce qu'on utilise avec « interact » hérite d'`Interactable` (`world/interactable.gd`), y compris les PNJ.
- Tests : `godot --headless --path . -s res://tools/tests/test_storage.gd` (48 vérifications).

## Résumé des Pokémon

Le résumé (`menu/summary_screen.gd`) s'ouvre depuis le menu (équipe) et depuis le PC (Résumé). Il occupe tout l'écran : à gauche, une carte fixe avec le Pokémon de face (qui respire comme au combat), son nom, son genre, son niveau, ses types, son statut, ses PV et son objet ; à droite, cinq pages :

- **Infos** : numéro du Pokédex, espèce, types, genre, dresseur d'origine, expérience, talent, objet tenu ;
- **Mémo** : nature (statistique augmentée en rouge, baissée en bleu), lieu et niveau de la rencontre, dresseur d'origine ;
- **Statistiques** : statistiques de base et valeurs réelles, marquées selon la nature, et total des statistiques de base ;
- **IV / EV** : IV (0 à 31) et EV (0 à 255) de chaque statistique, avec une jauge, et le total des EV sur 510 ;
- **Capacités** : les attaques avec leurs PP, leur type, leur catégorie, leur puissance et leur précision.

Gauche / droite change de page, haut / bas passe au Pokémon suivant, retour referme. Le genre est tiré à la naissance d'après `female_ratio` de l'espèce (12,5 % de femelles pour Salamèche et Bulbizarre) ; l'origine (`original_trainer`, `met_location`, `met_level`) est notée sur les Pokémon de départ. Les EV restent à 0 tant que l'expérience en fin de combat n'est pas codée.

## Combats

Parle à Lyra (sur la place d'Accumula) : après ses répliques, elle te défie. Un nouveau joueur reçoit un Salamèche niveau 8, 3 Potions et un Antidote (`data/config/new_game.tres`) ; Lyra se bat avec un Bulbizarre niveau 8. Règles de la génération 5 (Noir et Blanc).

Les 649 Pokémon des générations 1 à 5 sont dans `data/pokemon/`, avec les données actuelles de la série (type Fée compris, table des types de la génération 6 et suivantes). Voir « Données des Pokémon » plus bas.

Commandes en combat : déplacement pour naviguer dans les menus, `interact` (Espace, Entrée, E, A sur la manette) pour valider, `cancel` (X, Retour arrière, B) pour revenir.

### Organisation

```
data/                    données de jeu (Ressources .tres, modifiables dans l'inspecteur)
  pokemon/               espèces (PokemonSpecies) : types, statistiques, talents, attaques apprises, sprites
  moves/                 attaques (MoveData) et leurs effets (MoveEffect)
  abilities/             talents (AbilityData) : nom et description
  items/                 objets (ItemData, HealItem...)
  trainers/              dresseurs (TrainerData) : équipe, IA, répliques, sprite
battle/
  data/                  classes de données : types et table d'efficacité, statistiques, natures,
                         espèce, attaque, Pokémon (PokemonInstance), objet, sac, dresseur, joueur
  core/                  logique, sans affichage : BattleEngine (déroulé des tours), BattleRules
                         (formules), BattlePokemon, BattleSide, actions, ordre, calcul des dégâts
  status/                statuts et effets volatils (BattleCondition et ses sous-classes)
  effects/               effets d'attaques (niveaux de stats, statuts, contrecoup)
  ai/                    comportements de l'adversaire (BattleAI, TrainerAI)
  ui/                    écran de combat : terrain, cadres de PV, messages, menus, textes
  battle_service.gd      lancement des combats et réseau (nœud Battles de main.tscn)
tools/tests/test_battle.gd     tests automatiques de la logique
```

- **Mise en scène** : à l'entrée, l'écran clignote et des bandes noires le couvrent, puis il s'ouvre sur le terrain où les socles et les dresseurs glissent en place. Le dresseur lance sa Poké Ball (Ethan avec ses cinq images de lancer), qui s'ouvre dans un éclair : le Pokémon apparaît en silhouette blanche qui grandit. En combat, les Pokémon respirent et bougent (deuxième image de leur sprite), prennent leur élan pour attaquer, clignotent quand ils sont touchés. Les effets des attaques et des statuts (flammes, griffes, graines, lianes, bulles de poison, « Z » du sommeil, flèches des statistiques...) sont dans `BattleEffects` ; la sortie du combat reprend le fondu noir. Les barres de PV (jauge, icône « Lv. », chiffres, barre d'expérience) et les boutons FIGHT / BAG / RUN / POKÉMON viennent de la planche `assets/Battle HUD.png` (interface de Noir et Blanc, zones listées dans `BattleSprites`). Le fond et les menus d'attaques, d'équipe et de sac (boutons aux couleurs des types, fond brun de l'écran tactile) sont dessinés en code (`BattleStyle`, `BattleField`).
- **Logique et affichage séparés** : `BattleEngine` ne connaît aucun sprite. Il produit une liste d'évènements (attaque utilisée, PV perdus, K.O....) que `BattleScreen` joue dans l'ordre. Tout le texte affiché est dans `BattleText`.
- **Multijoueur** : l'hôte fait tourner le moteur ; l'équipe, le sac et l'argent de chaque joueur (`PlayerData`) viennent de `PlayerProfiles`. Un joueur choisit ses actions, les envoie à l'hôte, et reçoit les évènements à jouer. Chaque joueur a son propre combat ; les autres continuent d'explorer.
- **Déroulé d'un tour** : `BattleEngine.turn_steps` (début de tour, actions dans l'ordre, effets de fin de tour, K.O. et remplacements) ; la liste peut être modifiée pour d'autres règles. Les formules sont toutes dans `BattleRules`.
- **Persistance** : le combat travaille sur des copies (`BattlePokemon`) ; à la fin, seuls les PV, les PP et le statut sont recopiés dans le Pokémon de l'équipe. Après une défaite, l'équipe est soignée. L'hôte sauvegarde le joueur à la fin de chaque combat (voir « Sauvegarde »).

### Ajouter du contenu

- **Une attaque** : dupliquer un fichier de `data/moves/`, changer ses valeurs, et ajouter ses effets dans la liste `effects` (baisse de statistique, statut, contrecoup). Un effet nouveau : sous-classe de `MoveEffect` dans `battle/effects/`. Son animation : le champ `animation` choisit une fonction de `BattleEffects.play_move` (à ajouter pour une animation nouvelle ; sinon, un simple impact).
- **Un Pokémon** : dupliquer un fichier de `data/pokemon/` (statistiques, types, attaques apprises, zones des sprites dans la planche). Une espèce au comportement particulier : sous-classe de `PokemonSpecies` qui redéfinit `adjust_stat`, `battle_types` ou `moves_at_level`.
- **Un statut** : sous-classe de `BattleCondition`, inscrite dans `BattleConditions.SCRIPTS`.
- **Un dresseur** : fichier `TrainerData` dans `data/trainers/`, puis le mettre dans le champ `trainer` d'un PNJ.
- **Une IA** : sous-classe de `BattleAI`, inscrite dans `BattleAI.SCRIPTS`.

### Données des Pokémon

`tools/data/import_pokeapi.py` écrit les espèces n°1 à 649, leurs attaques et leurs talents à partir des tables de [PokeAPI](https://github.com/PokeAPI/pokeapi) gardées dans `source_assets/pokeapi/` (`--download` pour les récupérer à nouveau) :

- **Espèces** : nom français, types, statistiques de base, talents et talent caché, description du Pokédex, part de femelles, taux de capture, expérience de base, courbe d'expérience, EV donnés, attaques apprises par niveau (jeu le plus récent où l'espèce apparaît), icône de menu.
- **Attaques** : seulement celles apprises par niveau. Type, catégorie, puissance, précision, PP, priorité, cible, taux de critique, et les effets que le moteur sait jouer (niveaux de statistiques, statuts, Vampigraine, contrecoup). Les autres effets (soin, multi-coups, météo, entraves...) ne sont pas encore joués : l'attaque fait seulement ses dégâts.
- **Talents** : nom et description ; leurs effets en combat ne sont pas encore gérés.

Les attaques déjà présentes ne sont jamais réécrites (animations et effets réglés à la main) ; les sprites de combat réglés à la main d'une espèce sont gardés. Les 151 Pokémon de la 1re génération prennent leurs sprites de combat dans `assets/Battle - Pokemon (1st Generation).png` (l'importeur repère chaque bloc par son numéro, avec Pillow). Une espèce sans sprite de combat (n°152 à 649 pour l'instant) s'affiche avec son icône de menu agrandie. Le type Fée n'a pas d'étiquette dans Noir et Blanc : `MenuSprites` l'assemble avec les lettres des autres étiquettes.

### Tests

`godot --headless --path . -s res://tools/tests/test_battle.gd` : validité des 649 espèces, efficacité des types et immunités, formules, dégâts (STAB, critiques, brûlure), précision, niveaux de statistiques, statuts, Vampigraine, ordre des actions, K.O., victoire, défaite, remplacement, fuite, objets, Lutte, échange réseau, attaque à oublier, bonheur, évolutions par pierre, échange et bonheur.

### Expérience, évolution et capture

- **Expérience** : courbes d'expérience de la génération 5 (`Growth`, une courbe par espèce). Un Pokémon adverse K.O. donne de l'expérience à chaque Pokémon du joueur qui l'a affronté (partagée entre eux, x1,5 contre un dresseur). La barre bleue du cadre se remplit ; à chaque niveau, les PV gagnés s'ajoutent, et les attaques apprises à ce niveau sont apprises s'il en connaît moins de quatre. Sinon, à la fin du tour, le combat s'arrête (`BattleEngine.Phase.AWAITING_MOVE_CHOICE`) et le joueur choisit l'attaque à oublier, ou de ne pas apprendre la nouvelle ; c'est l'hôte qui applique le choix. Une attaque gagnée au dernier K.O. ou par une évolution se choisit de même avant la fermeture de l'écran de combat, et une évolution par objet la propose dans le menu. Les Pokémon des anciennes sauvegardes reçoivent l'expérience de leur niveau.
- **Évolution** : `PokemonSpecies.evolutions` (importées de PokeAPI : niveau, pierre, échange, bonheur, avec le bonheur demandé et le moment de la journée). Après le combat, un Pokémon qui a monté de niveau évolue s'il a atteint son niveau d'évolution, ou s'il est assez heureux au bon moment de la journée (heure de l'ordinateur de l'hôte : jour de 4 h à 20 h ; Évoli devient Mentali le jour, Noctali la nuit). Animation de clignotement, puis il apprend les attaques de sa nouvelle forme.
- **Pierres et Fil de liaison** (`EvolutionItem`, vendus au Centre Pokémon) : utilisés depuis le sac sur un Pokémon de l'équipe, ils le font évoluer. Le Fil de liaison remplace l'échange : il fait évoluer les Pokémon qui évoluent par échange (Kadabra, Machopeur…), objet tenu ou non.
- **Bonheur** (`PokemonInstance.happiness`, 70 au départ, 255 au plus) : +5, +3 ou +2 par niveau gagné (moins quand il est déjà élevé), +1 pour toute l'équipe tous les 128 pas, -1 à chaque K.O.
- **Capture** : les Poké Balls (`BallItem`, multiplicateur 1 ; Super Ball 1,5) se lancent depuis le sac contre un Pokémon sauvage, avec la formule de la génération 5 (PV restants, taux de capture de l'espèce, statut). La Ball se secoue jusqu'à trois fois ; capturé, le Pokémon rejoint l'équipe, ou le PC si elle est pleine. Une nouvelle partie commence avec 10 Poké Balls.

### Pas encore fait

Échange de Pokémon entre joueurs (le Fil de liaison en tient lieu), évolutions particulières (méthode « autre » : objet tenu la nuit, attaque connue…), effets des talents, sprites de combat des générations 2 à 5, combats doubles. Pas encore de sons ni de musique.

## Expéditions

En haut à gauche d'Accumula, la rue du haut se prolonge vers l'ouest entre un mur de pierre et un muret (`maps/accumula`, nœud `ExpeditionGate`). Le gardien bouche le passage : en lui parlant, on choisit une zone (Lagune, Volcan, Forêt, Jungle, Désert, Montagne, Cimetière), ou on rejoint l'expédition en cours.

- **Zones** : `data/expeditions/<zone>.tres` (`ExpeditionBiome`) : type, tuiles du sol, chemin, hautes herbes, liquide (eau, lave), décors debout (arbres, rochers, colonnes, tombes…) et dresseurs. Ces fichiers sont écrits par `tools/data/build_expedition_biomes.py` : modifier le script, puis le relancer.
- **Génération** (`expedition/zone_generator.gd`) : à chaque départ, une nouvelle graine. Labyrinthe organique, à la manière des forêts et des routes des jeux, tracé sur une grille de 2 × 2 cases (la taille d'un arbre, pour que les murs se remplissent sans trou) : 3 ou 4 clairières aux bords irréguliers (dont une au fond), des points de passage reliés par un arbre couvrant et une ou deux boucles, des couloirs qui serpentent dans un champ de bruit en préférant les lignes droites, et quelques impasses. Les biomes qui ont de petits décors d'une case ont des bords grignotés. Puis couloir d'entrée et sortie en bas, mares ou étendues liquides, chemins vers les dresseurs, plaques de hautes herbes, décors. Tout reste atteignable (vérifié à chaque étape). La même graine donne la même zone sur tous les ordinateurs : l'hôte n'envoie que la zone, la graine et le niveau.
- **Affichage** (`ExpeditionZone`) : le sol est composé en une image à partir des tuiles du tileset (ou d'une autre planche, `ExpeditionBiome.sheet`), les décors sont des modèles 3D (`ExpeditionProp.mesh`, un MultiMesh par modèle) ou des sprites debout, découpés dans le tileset ou dans leur propre image (`ExpeditionProp.sheet`) : les tombes du Cimetière sont dans `assets/tilesets/graves.png`, dessinées par `tools/maps/build_graves.py`. Le passage d'Accumula (`GateZone`) utilise le même affichage avec un plan dessiné à la main.
- **Forêt** : sol, hautes herbes (en 3D) et arbres de Lostlorn Forest (Noir 2 / Blanc 2), avec souches et troncs couchés. Dans la carte d'origine, les arbres sont de grands plans à texture répétée : `tools/maps/build_forest_kit.py` en découpe un arbre de chaque sorte, une touffe d'herbe et une souche (`assets/maps/lostlorn_forest/forest_*.obj`), compose la planche du sol (`forest_ground.png`) et convertit les objets voisins (`assets/mapobjects/dead_tree_01`, `dead_tree_02`, `stump_2`). Les `.dae` d'origine sont dans `source_assets/`.
- **Désert** : sable et falaises de Desert Resort (Noir 2 / Blanc 2). Les murs sont des falaises (`CliffStyle`) construites d'un seul maillage d'après le plan : une corniche basse au bord des passages (elle ne cache pas ce qui est derrière), un grand plateau au-delà. Les rencontres sont dans le sable orange.
- **Montagne** : pavés, sentiers et falaises de Victory Road (Noir 2 / Blanc 2) en terrasses basses près des passages, sommets enneigés (neige des Ruines Sinjoh) au-delà ; grands glaçons (`assets/mapobjects/big_icicle_*`) et rochers éparpillés dans les clairières, posés au sol.
- **Lagune** : îlots de sable de Humilau City (Noir 2 / Blanc 2) reliés par des pontons de bois, au milieu de la mer, avec un liseré d'eau claire au bord. Hautes herbes, palmiers et rochers (découpés dans la carte) seulement sur les îlots.

Planches du sol du désert, de la montagne et de la lagune, palmier, rocher et glaçons : `tools/maps/build_expedition_kits.py`.
- **Pas dans les rencontres** (`ExpeditionZone.on_step`, appelé à chaque pas d'un joueur, chez tous les joueurs qui voient la carte) : dans les hautes herbes de la forêt, la touffe s'agite, des feuilles jaillissent et l'herbe passe devant les jambes tant qu'on y est ; dans le sable du désert, de petits nuages de sable volent aux pieds.
- **Pokémon sauvages** (`WildPokemon`) : 1re génération seulement pour l'instant (`MAX_DEX`), espèces qui ont le type de la zone (les doubles types comptent). Le niveau de la zone est la moyenne du meilleur Pokémon de chaque joueur ; chaque Pokémon est à -3/+1 niveaux, sous la forme qu'il aurait à ce niveau (un Florizarre niveau 10 devient Bulbizarre, un Magicarpe niveau 25 devient Léviator). `data/pokemon/index.json` (écrit par l'import) évite de charger les 649 espèces.
- **Poké Balls** : celles du sac, 20 lancers au plus par joueur et par expédition. Après le 20e, les Pokémon sauvages ne se montrent plus ; les dresseurs restent.
- **Dresseurs** : 3 à 5 par zone, tirés d'après la graine (nom, sprite, équipe du type de la zone). Ils défient le joueur qui passe dans leur champ de vision (4 cases) ou qui leur parle, et ne se battent qu'une fois contre chaque joueur.
- **En groupe** : une seule expédition à la fois. Le premier qui parle au gardien choisit la zone ; les autres la rejoignent en lui parlant. Elle se termine quand plus personne n'y est. Après une défaite, on revient devant le gardien. La zone n'est pas sauvegardée : un joueur qui quitte pendant une expédition revient devant le gardien.
- Tests : `godot --headless --path . -s res://tools/tests/test_expedition.gd` (génération des 7 zones, Pokémon sauvages) ; le test de fumée fait une expédition complète (départ, rencontre, capture, retour) et le test à deux joueurs vérifie qu'un client rejoint la même zone.

## Fonctionnement réseau

L'hôte fait autorité. Un client envoie « je veux faire un pas vers la droite », l'hôte vérifie que le passage est possible (ni mur, ni autre joueur) puis annonce le déplacement à tout le monde. La grille étant un fichier du projet, tous les joueurs ont les mêmes collisions.

### Une carte par joueur

Chaque carte est une scène `maps/<id>/<id>.tscn`, chargée sous `World/Maps/<id>` (même chemin chez tout le monde).

- Un client ne charge que la carte où se trouve son joueur ; en passant une porte vers une autre carte, il charge la nouvelle et décharge l'ancienne.
- Une carte déchargée garde sa scène en mémoire (`World._scenes`) : y revenir ne relit rien sur le disque (sans cela, le TileSet du quartier bourgeois, 8 935 tuiles, prenait plusieurs secondes à chaque sortie du Centre Pokémon).
- L'hôte garde chargées toutes les cartes où il y a des joueurs, pour valider leurs déplacements, et n'affiche que la sienne. Les cartes ne doivent donc pas se superposer dans le monde (l'intérieur du Centre Pokémon est à environ +4000 unités de la ville).
- Chacun ne voit que les joueurs de sa carte. Les PNJ d'une carte n'envoient leurs gestes qu'aux joueurs qui l'ont chargée ; un joueur qui arrive sur une carte demande à l'hôte la position de ses PNJ.

### Sauvegarde

Le menu demande un pseudo. L'hôte garde les données de chaque joueur (`PlayerProfiles`) et les enregistre dans `user://saves/<pseudo>.json` (`SaveService`) : équipe, sac, argent et position. Il sauvegarde un joueur quand il part, à la fin de la session, en quittant le jeu, après un combat ou un soin, et toutes les minutes. En revenant avec le même pseudo, on reprend là où on s'était arrêté. Seules des données sont enregistrées (`PlayerData.to_dict`), jamais des nœuds.

### Tests

```
godot --headless --path . -s res://tools/tests/test_battle.gd     # logique des combats
godot --headless --path . -s res://tools/tests/test_expedition.gd # zones d'expédition
godot --headless --path . -s res://tools/tests/test_smoke.gd      # partie complète chez l'hôte
godot --headless --path . -s res://tools/tests/test_multiplayer.gd -- host     # deux joueurs :
godot --headless --path . -s res://tools/tests/test_multiplayer.gd -- client   # lancer les deux
```

## Personnages

Chaque personnage est un fichier `data/characters/<nom>.tres` (`CharacterSheet`) : sa planche (dans `assets/characters/`), la couleur de fond à rendre transparente, et l'emplacement de ses images de marche. Le nom du fichier sert d'identifiant (champ `sheet` d'un PNJ, `SLOT_LOOKS` dans `player/player.gd`). `SheetLoader` détoure la planche au chargement et aligne les pieds et l'ombre, quelle que soit la planche.

- Disposition `FRAMES` : pour chaque direction, les rectangles des trois images (pas, repos, pas). C'est le cas d'Ethan (les joueurs, chacun avec une teinte), de Lyra et de l'Infirmière Joëlle.
- Disposition `DS_TRAINER_CELL` : une case de 96x128 pixels de la planche `Overworld - Trainers (Overworld).png` (environ 80 dresseurs, 12 images de 32x32 dans l'ordre des jeux DS). Il suffit de donner le coin de la case (`cell_origin`) et sa couleur de fond.
- Pour ajouter un personnage : dupliquer un fichier de `data/characters/`, changer la planche et les réglages, puis utiliser son nom sur un PNJ.
