# Journal de refactorisation

Passage progressif du projet vers un framework modulaire (voir l'audit du 4 octobre 2026).
Chaque entrée : ce qui a changé, les fichiers touchés, pourquoi, l'impact, les tests passés.

Tests de référence, à relancer après chaque étape :

```
godot --headless --path . -s res://tools/tests/test_battle.gd   # 90 vérifications du combat
godot --headless --path . -s res://tools/tests/test_smoke.gd    # partie lancée de bout en bout
```

Décisions validées le 4 octobre 2026 :
- pas de dépôt git (une copie du projet est faite avant de commencer) ;
- les sources (.dae, zips) vont dans `source_assets/`, ignoré par Godot ;
- le doublon du Centre Pokémon est supprimé ;
- chaque joueur charge sa propre scène de carte ;
- l'hôte sauvegarde les données de tous les joueurs ;
- les dossiers sont regroupés par fonctionnalité.

---

## 2026-10-04 · Étape 0 : sauvegarde

- **Changement** : copie complète du projet (hors `.godot/`) dans
  `../PokeClash_sauvegarde_2026-10-04_avant_refacto.zip` (1 255 fichiers).
- **Pourquoi** : pas de git, il faut un point de retour.
- **Impact** : aucun sur le projet.

## 2026-10-04 · Étape 1 : test de fumée

- **Changement** : nouveau `tools/tests/test_smoke.gd`. Il lance `main.tscn` en hôte, fait un
  pas, entre dans le Centre Pokémon, parle à l'infirmière (soin), ressort, et lance le combat
  contre Lyra.
- **Pourquoi** : vérifier automatiquement que la partie marche toujours après chaque étape.
- **Impact** : aucun sur le jeu.
- **Tests** : 11/11 réussis sur le projet d'origine.

## 2026-10-04 · Étape 2 : sources hors du projet Godot, doublon supprimé

- **Changement** :
  - `Accumula Town.dae`, `Pokémon Center.dae`, `plasma_ship_fly_.dae` → `source_assets/maps/…`
    et `source_assets/mapobjects/…` (leurs `.import` supprimés) ;
  - 15 zips de la racine d'`assets/` et 20 zips d'`assets/_archives/` → `source_assets/archives/` ;
  - dossier `assets/DS _ DSi - … - Interior Maps - Pokemon Center` supprimé (doublon exact
    d'`assets/maps/pokemon_center`, vérifié octet par octet) ;
  - `tools/dae_to_obj.py` accepte un dossier de sortie en 3e argument.
- **Pourquoi** : Godot importait les .dae à chaque ouverture et affichait des erreurs Collada ;
  1,2 Mo de doublon.
- **Impact** : plus d'erreurs Collada au lancement. Aucune scène n'utilisait ces fichiers.
- **Tests** : combat 90/90, fumée 11/11.

## 2026-10-04 · Étape 3 : dossiers regroupés par fonctionnalité

- **Changement** (toutes les références `res://` mises à jour automatiquement) :

  | Avant | Après |
  |---|---|
  | `scripts/battle/**` | `battle/**` |
  | `scripts/autoload/network.gd` | `core/network.gd` |
  | `scripts/world/*.gd` (sauf npc) | `world/` |
  | `scripts/world/npc.gd`, `scripts/characters/character_sprite.gd` | `characters/` |
  | `scripts/player/player.gd`, `scenes/player/player.tscn` | `player/` |
  | `scripts/ui/*.gd` | `ui/` |
  | `scenes/zones/*.tscn` | `maps/` |
  | `scenes/main.tscn` | `main.tscn` |
  | `tools/test_battle.gd` | `tools/tests/` |
  | outils de cartes (`bake_map_grid`, `dae_to_obj`, `place_model`, `build_port*`, `port_mesh`) | `tools/maps/` |
  | `tools/make_nurse_joy.py` | `tools/characters/` |

  Le script qui écrit `maps/port.tscn` est ajouté au projet : `tools/maps/build_port_scene.py`
  (il régénère la scène actuelle à l'identique, vérifié par comparaison).
- **Fichiers mis à jour** : `project.godot` (scène principale, autoload), `main.tscn`, les 13
  `.tres` de `data/`, `battle_ai.gd`, `battle_conditions.gd`, `world.gd`, README, CREDITS,
  docstrings des outils.
- **Pourquoi** : retrouver tout ce qui concerne une fonctionnalité au même endroit.
- **Impact** : aucun changement de comportement. Les chemins dans l'éditeur changent.
- **Tests** : combat 90/90, fumée 11/11, ouverture du projet sans erreur.

## 2026-10-04 · Étape 4 : configuration, caméra et touches centralisées

- **Changement** :
  - `core/game_config.gd` (GameConfig) : taille des cases (16), hauteur de passage entre
    zones (6), taille de l'écran lue dans project.godot ;
  - `world/camera/camera_profile.gd` (CameraProfile) et `data/config/camera/overworld.tres` :
    inclinaison 45°, champ 35°, cadrage 1 unité = 1 pixel, plans proche/lointain ;
  - `world/camera/camera_rig.gd` (CameraRig) : la caméra, et le test de visibilité du halo
    (ex-`World.is_hidden_from_camera`, maintenant `CameraRig.is_hiding`) ;
  - `core/input_setup.gd` (InputSetup) : les touches, sorties de world.gd.
- **Pourquoi** : réglages au même endroit ; d'autres profils de caméra possibles sans code.
- **Impact** : aucun changement visible (mêmes valeurs ; le test de fumée vérifie le cadrage).
- **Tests** : combat 90/90, fumée OK.

## 2026-10-04 · Étape 5 : autoloads Game et Events

- **Changement** : `core/game.gd` (Game : world, battles, battle_screen, dialogue, fade,
  profiles) et `core/events.gd` (Events.message_requested). Remplacent les groupes
  `dialogue_box`, `battle_service`, `battle_screen`, `screen_fade`, les
  `get_parent().get_parent()` de Player et Npc, et le chemin `World/Players` de BattleService.
- **Pourquoi** : un nœud déplacé ne casse plus rien ; le combat n'ouvre plus directement la
  boîte de dialogue.
- **Tests** : combat 90/90, fumée OK.

## 2026-10-04 · Étape 6 : personnages en données

- **Changement** : les tables SHEETS / TRAINERS de `character_sprite.gd` deviennent 23 fichiers
  `data/characters/*.tres` (CharacterSheet). Le détourage et les mesures passent dans
  `characters/sheet_loader.gd`. `character_sprite.gd` passe de 423 à 170 lignes.
- **Impact** : aucun : les 276 images (23 personnages × 4 directions × 3 images), les
  décalages des pieds et les ombres ont été comparés avant/après, tous identiques.
- **Tests** : combat 90/90, fumée OK. Les avertissements « invalid UID » des objets du port
  (cache d'import périmé) ont aussi disparu après réimport.

## 2026-10-04 · Étape 7 : une scène par carte, chargée par chaque joueur

- **Changement** :
  - `maps/accumula/accumula.tscn` (ville + quartier bourgeois + port + porte + PNJ) et
    `maps/accumula_pokemon_center/accumula_pokemon_center.tscn` (intérieur + infirmière),
    extraites de `main.tscn` ; les zones `port.tscn` et `quartier_bourgeois.tscn` vont dans
    `maps/accumula/` ;
  - `world/game_map.gd` (GameMap) : racine d'une carte, avec les requêtes de déplacement
    autrefois dans World (sol, hauteurs, obstacles, PNJ, passages) ;
  - `world/world.gd` réécrit : chargement des cartes, apparition des joueurs, caméra
    (276 → environ 190 lignes) ;
  - `player/player.gd` découpé : déplacement (player.gd), conversations
    (`player_interaction.gd`), animation des portes (`warp_transition.gd`) ;
  - Warp : `target_map`, et la porte d'arrivée désignée par son nom ; passage désigné sur le
    réseau par son nom (plus par son ordre) ;
  - Npc : n'envoie ses gestes qu'aux joueurs qui ont sa carte chargée (confirmation
    `Player.loaded_map`), demande l'état à l'hôte quand sa carte se charge.
- **Pourquoi** : choix validé « chaque joueur charge sa propre scène ».
- **Impact** : un client ne charge que la carte de son joueur ; l'hôte garde toutes les cartes
  où il y a des joueurs. Capture d'écran en ville avant/après : décor identique au pixel près
  (seuls deux PNJ, qui se déplacent au hasard, diffèrent).
- **Tests** : combat 90/90, fumée OK, nouveau `tools/tests/test_multiplayer.gd` (hôte et
  client dans deux processus : le client entre au Centre, l'hôte reste en ville ; aucune
  erreur « Node not found »).

## 2026-10-04 · Étape 8 : profils joueurs et sauvegarde chez l'hôte

- **Changement** :
  - `profile/player_profiles.gd` (PlayerProfiles, nœud Profiles de main.tscn) : données de
    chaque joueur chez l'hôte, sorties de `battle_service.gd` ;
  - `profile/save_service.gd` (SaveService) : un fichier JSON par pseudo dans
    `user://saves/`, écrit d'abord en `.tmp` puis renommé ;
  - `profile/new_game_config.gd` + `data/config/new_game.tres` : starter, niveau, objets
    (ex-constantes STARTER de battle_service.gd) ;
  - `to_dict` / `from_dict` sur PlayerData, PokemonInstance et Bag (ressources désignées
    par leur chemin) ; PlayerData gagne `player_name`, `map_id`, `cell`, `facing` ;
  - menu : champ « Pseudo » ; le monde fait apparaître un joueur quand ses données sont
    chargées, là où il s'était arrêté.
- **Pourquoi** : choix validé « l'hôte sauvegarde » ; plus de données de jeu dans le code
  du combat.
- **Sauvegardes** : départ d'un joueur, fin de session, fermeture du jeu, fin de combat,
  soin, et toutes les 60 secondes.
- **Tests** : combat 90/90, fumée 22/22 (sauvegarde écrite, puis reprise à la même case),
  deux joueurs OK. Les tests utilisent des pseudos `test_*` et effacent leurs fichiers.

## 2026-10-04 · Ajout : menu du jeu (équipe, sac, sauvegarde)

- **Changement** : nouveau dossier `menu/` (GameMenu, PartyPanel, MenuSprites), nœud
  `UI/GameMenu` dans main.tscn, autoload Game.menu ; action « menu » (Échap, X, Start) ;
  Échap ne quitte plus directement la session (entrée « Quitter » du menu).
  Données : `icon_sheet` / `icon_region` sur PokemonSpecies et ItemData,
  `can_use_on_pokemon` / `use_on_pokemon` sur ItemData (HealItem les définit),
  `play_time` sur PlayerData ; PlayerProfiles répond aux demandes du menu (copie des
  données, sauvegarde, objet utilisé). GameFont gagne une police à lettres blanches.
- **Tests** : combat 90/90, fumée 22/22, deux joueurs OK (le client reçoit son équipe et
  utilise un objet via l'hôte), captures de chaque écran du menu.

## 2026-10-04 · Menu du jeu dans le style du combat

- **Changement** : nouveau `ui/ds_ui.gd` (DsUi) : fond de l'écran tactile, bouton crème,
  curseur, cadre de message, flèche « suite », chiffres et jauge du HUD. Ces dessins étaient
  recopiés dans BattleMenu, BattleCommandMenu, BattleMessageBox et BattleInfoBox : ils
  appellent maintenant DsUi (rendu inchangé). Le menu du jeu, la colonne de l'équipe et la
  boîte de dialogue de l'exploration l'utilisent aussi : un seul style pour toute l'interface.
  Le menu glisse depuis les bords à l'ouverture et à la fermeture ; le résumé montre le
  Pokémon de face et ses attaques en boutons de type ; un combat qui commence ferme le menu.
- **Tests** : combat 90/90, fumée 22/22, deux joueurs OK, captures du menu, d'un dialogue
  et d'un combat.

## 2026-10-04 · Ajout : vendeurs et boutique du Centre Pokémon

- **Changement** : `shop/` (ShopData, ShopScreen), `data/shops/accumula_pokemon_center.tres`,
  4 objets (Poké Ball, Super Ball, Super Potion, Anti-Para), vendeur et vendeuse
  (`tools/characters/make_shop_clerks.py`, `data/characters/vendeur.tres`,
  `vendeuse.tres`) placés en (244, 1) et (244, 3). Npc gagne `shop` et `looks_around` ;
  PlayerProfiles gagne `request_buy` / `request_sell` (vérifiés par l'hôte) ; DsUi gagne
  des aides de texte ; argent de départ : 3 000.
- **Tests** : combat 90/90, fumée 26/26 (achat, revente, refus sans argent), deux joueurs OK,
  captures de toute la boutique.

## 2026-10-04 · Boutique : murs invisibles, vendeur, casquettes

- **Changement** : MapGrid gagne `walkable` (cases rendues praticables à la main, gardées au
  recalcul comme `blocked` et `opened`). Grille du Centre Pokémon : tapis devant le comptoir
  (242, 1) à (242, 3) praticables, coin du comptoir (243, 0) bloqué. Vendeur déplacé en
  (245, 1) (il débordait sur le comptoir). Casquettes bleues ajoutées par
  `tools/characters/make_shop_clerks.py`.
- **Tests** : combat 90/90, fumée 29/29 (sol devant le comptoir, comptoir infranchissable,
  vendeur joignable), deux joueurs OK.

## 2026-10-04 · Boutique : placement au comptoir, casquettes redessinées

- **Changement** : MapGrid gagne `offsets` (décalage d'affichage par case, gardé au recalcul) ;
  GameMap.cell_to_3d l'applique. Centre Pokémon : cases (242, -1..3) décalées de -5 unités
  (le joueur se colle au comptoir sans le chevaucher), cases (244, 0..3) de +8 (vendeurs
  juste derrière). Vendeur ramené en (244, 1). GameMap.npc_facing : un PNJ à comptoir
  (talk_reach > 1) répond aussi au client placé une case à côté. Casquettes : celle de Red
  (planche des dresseurs) recolorée en bleu et posée sur chaque image.
- **Tests** : combat 90/90, fumée 30/30, deux joueurs OK.

## 2026-10-04 · Retouches boutique

- Casquettes reculées d'un pixel (plus haut, et vers la nuque de profil) ; vendeur aligné sur
  le tapis bleu du haut (décalage (8, -8) sur la case (244, 1)). Fumée 30/30.

## 2026-10-04 · Ajout : PC de stockage

- **Données** : `storage/` (StorageConfig, PokemonBox, PokemonStorage, PcSprites, PcScreen),
  `data/config/storage.tres` (8 boîtes de 30). `PokemonInstance.uid` ; `PlayerData.storage`
  dans `to_dict` / `from_dict`. SaveService en version 2, copie `.v1.bak` des anciennes
  sauvegardes avant réécriture.
- **Interaction** : nouveau `world/interactable.gd` (Interactable) dont Npc hérite ;
  `GameMap.npc_facing` / `npc_at` deviennent `interactable_facing` / `interactable_at` ; la
  réaction de fin de dialogue (boutique, combat, soin) passe de PlayerInteraction à
  `Npc.on_interact_finished`. Nouveau `world/pc_terminal.gd` posé en (234, -7) dans le Centre.
- **Interface** : PcScreen (UI/Pc) avec DsUi, PartyPanel (places vides désignables, place
  d'origine en creux) et le nouveau composant `menu/pokemon_summary.gd`, extrait du menu
  (qui l'utilise aussi). DsUi gagne `draw_cursor_down`.
- **Hôte** : `request_pc_move`, `request_pc_rename`, `request_pc_wallpaper` dans
  PlayerProfiles.
- **Tests** : nouveau `tools/tests/test_storage.gd` 48/48 ; fumée 37/37 (terminal, refus du
  dernier Pokémon, retrait, dépôt, sauvegarde v2, ouverture et fermeture) ; deux joueurs OK
  (le PC du client passe par l'hôte) ; combat 90/90 ; captures de chaque écran.

## 2026-10-04 · Bulbizarre dans le PC

- NewGameConfig gagne `stored_species` / `stored_levels` : une nouvelle partie commence avec
  un Bulbizarre niveau 8 dans la boîte 1 (`data/config/new_game.tres`). La sauvegarde
  existante « Joueur » a reçu le même Bulbizarre (passée au format 2, copie
  `joueur.json.v1.bak` gardée). Fumée 38/38, deux joueurs OK.

## 2026-10-04 · PC : position et interface claire

- Le terminal est sur la case de son pied (235, -6) : on l'utilise de face depuis (235, -5)
  ou de côté. Grille du Centre : (236, -6) et (237, -6) praticables (sol devant le comptoir,
  refusé par le calcul), décalage d'affichage de (236, -6).
- Interface du PC sur panneaux clairs : DsUi gagne `draw_light_panel` / `draw_backdrop` ;
  PartyPanel et PokemonSummary gagnent un mode clair (le menu garde l'écran tactile brun).
- Tests : fumée 40/40, PC 48/48, combat 90/90.

## 2026-10-04 · PC : boîte agrandie, allumage de l'écran

- Cadre d'indications du bas retiré : la boîte occupe toute la hauteur (216 × 256), grille
  de 6 × 5 places de 34 × 39 ; le Pokémon désigné et le remplissage sont sous la grille ;
  les messages s'affichent par-dessus seulement quand il y en a.
- Fonds de boîte : le cadre gris de DS est retiré ; le paysage du titre est gardé à sa taille,
  le motif de la boîte est étendu par répétition (PcSprites.title / body_style).
- Animation d'allumage et d'extinction de l'écran (ligne lumineuse, ouverture en hauteur,
  fondu), à la place du fondu au noir.
- Tests : fumée 40/40, PC 48/48.

## 2026-10-04 · Écran du PC animé dans le décor

- Matériaux de carte : nouvel uniforme `uv_offset` (choisit une image d'une bande
  d'animation). PcTerminal anime la surface `lambert4` (écran du terminal du Centre) :
  allumage pendant le message, extinction à la sortie du PC (signal `PcScreen.closed`).
- Tests : fumée 40/40, PC 48/48, combat 90/90.

## 2026-10-04 · Résumé complet des Pokémon

- Données : `PokemonSpecies.female_ratio` ; `PokemonInstance.gender`, `original_trainer`,
  `met_location`, `met_level` (sauvegardés ; genre tiré d'après l'espèce pour les
  anciennes sauvegardes) ; `Nature.raised` / `lowered` ; NewGameConfig note l'origine des
  Pokémon de départ (`start_location`).
- Interface : nouveau `menu/summary_screen.gd` (SummaryScreen, 5 pages) utilisé par le menu
  et le PC ; l'ancien `menu/pokemon_summary.gd` est supprimé (remplacé).
- Tests : PC 50/50 (genre et origine), fumée 40/40, combat 90/90, captures de chaque page.

## 2026-10-04 · Import des Pokémon 1 à 649 (PokeAPI)

- Type Fée ajouté (PokemonType, couleur dans BattleStyle) et table des types actuelle
  (Acier ne résiste plus à Spectre ni Ténèbres). Étiquette FAIRY assemblée en code par
  MenuSprites avec les lettres des étiquettes existantes.
- Nouvelles données : AbilityData ; PokemonSpecies `description`, `abilities`,
  `hidden_ability`, `growth_rate`, `ev_yield` ; PokemonInstance tire son talent à la
  création, et les Pokémon déjà sauvegardés prennent le premier talent de leur espèce.
- `tools/data/import_pokeapi.py` : 649 espèces, 557 attaques nouvelles (187 avec effets
  joués), 170 talents. Attaques existantes conservées, sprites de Salamèche et Bulbizarre
  conservés ; leurs attaques apprises suivent maintenant les jeux récents.
- Espèces sans sprite de combat : icône de menu agrandie (BattleSprites._stand_in).
- Tests : combat 92/92 (validité des 649 espèces), PC 50/50, fumée 40/40, deux joueurs 6/8.

## 2026-10-04 · Sprites de combat de la 1re génération

- L'importeur repère les 151 blocs numérotés de `assets/Battle - Pokemon (1st Generation).png`
  (les blocs de version femelle et le bloc « Fixed Kabuto » sont ignorés) et renseigne
  face, dos et couleurs de fond de chaque espèce. Planche vérifiée sur les 151 espèces.
- Tests : combat 92/92, PC 50/50, fumée 40/40 ; capture d'un combat Pikachu contre Évoli.

## 2026-10-05 · Expérience, capture et expéditions

- Combat : expérience (`Growth`, partage entre les Pokémon qui ont combattu), montée de
  niveau et nouvelles attaques, évolutions après le combat (`EvolutionData`, importées de
  PokeAPI), capture (`BallItem`, `BattleEngine.throw_ball`, issue `CAUGHT`), combats
  sauvages (`BattleService.start_wild_battle`), dresseurs créés en jeu
  (`start_trainer_battle`, sprite envoyé au client), signal `battle_finished`.
- Écran de combat : barre d'expérience, annonces de niveau, animation de la Ball et de
  l'évolution, Pokémon sauvage qui apparaît sans Ball.
- Nouveau module `expedition/` : `ExpeditionBiome`, `ExpeditionProp`, `ZoneLayout`,
  `ZoneGenerator`, `ExpeditionZone`, `GateZone`, `ExpeditionMap`, `ExpeditionTrainer`,
  `ExpeditionGuard`, `ExpeditionScreen`, `ExpeditionService`, `WildPokemon` ; carte
  `maps/expedition`, données `data/expeditions` (script `tools/data/build_expedition_biomes.py`).
- Monde : `Player.teleport`, `World.unload_map`, `Npc.can_battle`, `TileZone.standing_sprite`.
  Une position sauvegardée en expédition est remplacée par le retour devant le gardien.
- Sauvegardes : aucune rupture ; l'expérience manquante des anciens Pokémon est complétée.
- Tests : combat 128/128, PC 50/50, expéditions 227/227, fumée 53/53, deux joueurs 8 + 13.
