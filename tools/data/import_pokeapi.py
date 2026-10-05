"""Importe les Pokémon 1 à 649 (générations 1 à 5) depuis les tables CSV de PokeAPI
(https://github.com/PokeAPI/pokeapi, licence BSD) : un fichier .tres par espèce dans
data/pokemon, par attaque apprise dans data/moves et par talent dans data/abilities.

Données actuelles (type Fée compris), noms et descriptions en français :
- espèces : numéro, nom, types, statistiques de base, talents (dont le talent caché),
  description du Pokédex, part de femelles, taux de capture, expérience de base, courbe
  d'expérience, EV donnés, attaques apprises par niveau (jeu le plus récent où l'espèce
  apparaît), icône de menu (assets/icons_menu.png) ;
- attaques : type, catégorie, puissance, précision, PP, priorité, cible, taux de
  critique, et les effets que le moteur sait jouer (niveaux de statistiques, brûlure,
  gel, paralysie, poison, toxik, sommeil, Vampigraine, contrecoup) ;
- talents : nom et description (leurs effets en combat ne sont pas encore gérés).

Les fichiers d'attaques qui existent déjà ne sont jamais réécrits (ils ont été réglés à
la main : animations, effets). Pour une espèce qui existe déjà, les sprites de combat
réglés à la main sont conservés.

Usage, depuis le dossier du projet :
    python tools/data/import_pokeapi.py --download   # récupère les tables (une fois)
    python tools/data/import_pokeapi.py              # écrit les fichiers .tres
Les tables sont gardées dans source_assets/pokeapi/ (ignoré par Godot).
"""
import csv
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV_DIR = os.path.join(ROOT, "source_assets", "pokeapi")
BASE_URL = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/"
TABLES = [
    "pokemon_species", "pokemon", "pokemon_stats", "pokemon_types", "pokemon_abilities",
    "pokemon_species_names", "pokemon_species_flavor_text", "abilities", "ability_names",
    "ability_flavor_text", "moves", "move_names", "move_flavor_text", "move_meta",
    "move_meta_stat_changes", "pokemon_moves", "growth_rates", "pokemon_evolution", "items",
]
LAST_SPECIES = 649
LAST_GEN1 = 151
FRENCH = 5
# Jeux dont on prend les attaques apprises, du plus récent au plus ancien.
VERSION_GROUPS = [25, 20, 18, 17, 16, 15, 14, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
LEVEL_UP = 1
# Évolutions (evolution_trigger_id de PokeAPI) -> EvolutionData.Method.
EVOLVE_LEVEL, EVOLVE_ITEM, EVOLVE_TRADE, EVOLVE_HAPPINESS, EVOLVE_OTHER = 0, 1, 2, 3, 4
# Types de PokeAPI -> ordre de PokemonType.Type.
TYPES = {1: 0, 2: 6, 3: 9, 4: 7, 5: 8, 6: 12, 7: 11, 8: 13, 9: 16, 10: 1, 11: 2, 12: 4,
         13: 3, 14: 10, 15: 5, 16: 14, 17: 15, 18: 17}
# Catégories : statut, physique, spéciale -> MoveData.Category.
CATEGORIES = {1: 2, 2: 0, 3: 1}
TARGET_USER = 7
# Problèmes de statut (move_meta.meta_ailment_id) -> BattleConditions.
AILMENTS = {1: "paralysis", 2: "sleep", 3: "freeze", 4: "burn", 5: "poison", 18: "leech_seed"}
TOXIC_EFFECT = 34
# Catégories de move_meta où les changements de statistiques visent le lanceur.
RAISES_USER = {7}

ICON_SHEET = "res://assets/icons_menu.png"
# Planche des sprites de combat de la 1re génération : un bloc de 324 × 195 par espèce
# (deux pour celles qui ont une version femelle), 10 par ligne, l'en-tête porte le numéro.
# Dans un bloc : face (deux images), puis dos (deux images), de 80 × 80, 81 de pas.
GEN1_SHEET = "assets/Battle - Pokemon (1st Generation).png"
GEN1_BLOCK = (324, 195)
GEN1_FRONT = (1, 34)
GEN1_BACK = (163, 34)
GEN1_BACKGROUNDS = "Array[Color]([Color(0.5764706, 0.73333335, 0.9254902, 1), Color(0.32941177, 0.64705884, 0.29411766, 1)])"
# Sprites de combat réglés à la main, à garder quand on réécrit une espèce.
SPRITE_FIELDS = ["battle_sheet", "front_region", "back_region", "sheet_background_colors", "animation_frame_offset"]


def read(name):
    with open(os.path.join(CSV_DIR, name + ".csv"), encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def download():
    os.makedirs(CSV_DIR, exist_ok=True)
    for table in TABLES:
        target = os.path.join(CSV_DIR, table + ".csv")
        print("téléchargement", table)
        urllib.request.urlretrieve(BASE_URL + table + ".csv", target)
    open(os.path.join(CSV_DIR, "LICENSE.md"), "w", encoding="utf-8").write(
        "Données de PokeAPI (https://github.com/PokeAPI/pokeapi), licence BSD-3-Clause.\n")


def gen1_blocks():
    """Coin de chaque bloc numéroté de la planche, dans l'ordre (n°1 à 151), ou {} sans Pillow."""
    try:
        from PIL import Image
    except ImportError:
        print("Pillow absent : sprites de la 1re génération non branchés (pip install pillow)")
        return {}
    sheet = Image.open(os.path.join(ROOT, GEN1_SHEET)).convert("RGB")
    width, height = sheet.size
    blocks = []
    for y in range(0, height - GEN1_FRONT[1] - 80, GEN1_BLOCK[1]):
        for x in range(0, width - GEN1_BLOCK[0] + 1, GEN1_BLOCK[0]):
            # Bloc d'une espèce : son numéro est écrit en blanc en haut à gauche ; les blocs
            # de version femelle n'en ont pas.
            white = sum(1 for dx in range(3, 30) for dy in range(3, 15) if sum(sheet.getpixel((x + dx, y + dy))) > 700)
            if white > 15:
                blocks.append((x, y))
    return {n + 1: blocks[n] for n in range(min(LAST_GEN1, len(blocks)))}


def ident(identifier):
    return re.sub(r"[^a-z0-9]+", "_", identifier.lower()).strip("_")


def text(value):
    """Chaîne pour un fichier .tres (guillemets et barres échappés)."""
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def clean(flavor):
    flavor = flavor.replace("­\n", "").replace("­", "").replace("\f", " ").replace("\n", " ")
    flavor = flavor.replace("POKéMON", "Pokémon").replace("’", "'")
    return re.sub(r"\s+", " ", flavor).strip()


def latest_french(rows, key, version_key):
    """Texte français le plus récent pour chaque `key`."""
    best = {}
    for row in rows:
        if int(row["language_id"]) != FRENCH:
            continue
        k = int(row[key])
        v = int(row[version_key])
        if k not in best or v > best[k][0]:
            best[k] = (v, clean(row["flavor_text"]))
    return {k: v[1] for k, v in best.items()}


def french_names(rows, key):
    return {int(r[key]): r["name"] for r in rows if int(r["local_language_id"]) == FRENCH}


def main():
    if "--download" in sys.argv:
        download()
        return
    species = {int(r["id"]): r for r in read("pokemon_species") if int(r["id"]) <= LAST_SPECIES}
    pokemon = {int(r["species_id"]): r for r in read("pokemon")
               if int(r["species_id"]) <= LAST_SPECIES and r["is_default"] == "1"}
    poke_ids = {int(p["id"]): sid for sid, p in pokemon.items()}
    names = french_names(read("pokemon_species_names"), "pokemon_species_id")
    descriptions = latest_french(read("pokemon_species_flavor_text"), "species_id", "version_id")
    growth = {int(r["id"]): r["identifier"] for r in read("growth_rates")}

    stats, efforts, types, abilities = {}, {}, {}, {}
    for r in read("pokemon_stats"):
        sid = poke_ids.get(int(r["pokemon_id"]))
        if sid is not None:
            stats.setdefault(sid, {})[int(r["stat_id"])] = int(r["base_stat"])
            efforts.setdefault(sid, {})[int(r["stat_id"])] = int(r["effort"])
    for r in read("pokemon_types"):
        sid = poke_ids.get(int(r["pokemon_id"]))
        if sid is not None:
            types.setdefault(sid, []).append((int(r["slot"]), TYPES[int(r["type_id"])]))
    for r in read("pokemon_abilities"):
        sid = poke_ids.get(int(r["pokemon_id"]))
        if sid is not None:
            abilities.setdefault(sid, []).append((int(r["slot"]), int(r["ability_id"]), r["is_hidden"] == "1"))

    # Attaques apprises par niveau, dans le jeu le plus récent où l'espèce en a.
    by_group = {}
    for r in read("pokemon_moves"):
        if int(r["pokemon_move_method_id"]) != LEVEL_UP:
            continue
        sid = poke_ids.get(int(r["pokemon_id"]))
        if sid is None:
            continue
        by_group.setdefault(sid, {}).setdefault(int(r["version_group_id"]), []).append(
            (max(1, int(r["level"] or 1)), int(r["move_id"])))
    learnsets = {}
    for sid, groups in by_group.items():
        for group in VERSION_GROUPS:
            if group in groups:
                learnsets[sid] = sorted(set(groups[group]))
                break

    # Évolutions : une par espèce d'arrivée (la première ligne, celle des premiers jeux).
    items = {int(r["id"]): r["identifier"] for r in read("items")}
    evolutions = {}
    seen = set()
    for r in read("pokemon_evolution"):
        target = int(r["evolved_species_id"])
        if target > LAST_SPECIES or target in seen or not species.get(target, {}).get("evolves_from_species_id"):
            continue
        seen.add(target)
        source = int(species[target]["evolves_from_species_id"])
        trigger = int(r["evolution_trigger_id"])
        level = int(r["minimum_level"] or 0)
        if trigger == 1 and level > 0:
            method = EVOLVE_LEVEL
        elif trigger == 1 and r["minimum_happiness"]:
            method = EVOLVE_HAPPINESS
        elif trigger == 2:
            method = EVOLVE_TRADE
        elif trigger == 3:
            method = EVOLVE_ITEM
        else:
            method = EVOLVE_OTHER
        item = items.get(int(r["trigger_item_id"]), "") if r["trigger_item_id"] else ""
        evolutions.setdefault(source, []).append((ident(species[target]["identifier"]), method, level, item))

    moves = {int(r["id"]): r for r in read("moves")}
    move_names = french_names(read("move_names"), "move_id")
    move_texts = latest_french(read("move_flavor_text"), "move_id", "version_group_id")
    meta = {int(r["move_id"]): r for r in read("move_meta")}
    stat_changes = {}
    for r in read("move_meta_stat_changes"):
        stat_changes.setdefault(int(r["move_id"]), []).append((int(r["stat_id"]), int(r["change"])))
    ability_rows = {int(r["id"]): r for r in read("abilities")}
    ability_names = french_names(read("ability_names"), "ability_id")
    ability_texts = latest_french(read("ability_flavor_text"), "ability_id", "version_group_id")

    os.makedirs(os.path.join(ROOT, "data", "abilities"), exist_ok=True)
    used_moves = {m for ls in learnsets.values() for _, m in ls}
    used_abilities = {a for ab in abilities.values() for _, a, _ in ab}
    written = {"moves": 0, "moves_kept": 0, "abilities": 0, "species": 0, "effects": 0}

    move_paths = {}
    for mid in sorted(used_moves):
        row = moves[mid]
        path = "data/moves/%s.tres" % ident(row["identifier"])
        move_paths[mid] = "res://" + path
        if os.path.exists(os.path.join(ROOT, path)):
            written["moves_kept"] += 1
            continue
        effects = move_effects(row, meta.get(mid), stat_changes.get(mid, []))
        written["effects"] += 1 if effects else 0
        write(path, move_tres(row, move_names.get(mid, row["identifier"]), move_texts.get(mid, ""), effects,
                             int((meta.get(mid) or {}).get("crit_rate") or 0)))
        written["moves"] += 1

    ability_paths = {}
    for aid in sorted(used_abilities):
        row = ability_rows[aid]
        path = "data/abilities/%s.tres" % ident(row["identifier"])
        ability_paths[aid] = "res://" + path
        write(path, ability_tres(row, ability_names.get(aid, row["identifier"]), ability_texts.get(aid, "")))
        written["abilities"] += 1

    gen1 = gen1_blocks()
    for sid in sorted(species):
        row = species[sid]
        path = "data/pokemon/%s.tres" % ident(row["identifier"])
        kept = sprite_fields(os.path.join(ROOT, path))
        if not kept[0] and sid in gen1:
            kept = gen1_sprites(*gen1[sid])
        write(path, species_tres(sid, row, pokemon[sid], names.get(sid, row["identifier"]), descriptions.get(sid, ""),
                                 stats[sid], efforts[sid], [t for _, t in sorted(types[sid])],
                                 sorted(abilities.get(sid, [])), learnsets.get(sid, []), growth[int(row["growth_rate_id"])],
                                 move_paths, ability_paths, kept, evolutions.get(sid, []),
                                 ident(species[int(row["evolves_from_species_id"])]["identifier"]) if row["evolves_from_species_id"] else ""))
        written["species"] += 1
    # Index léger (numéro et types) : choisir des espèces sans charger les 649 fichiers
    # (Pokémon sauvages des expéditions).
    index = {}
    for sid in sorted(species):
        index[ident(species[sid]["identifier"])] = {"dex": sid, "types": [t for _, t in sorted(types[sid])]}
    with open(os.path.join(ROOT, "data", "pokemon", "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, separators=(",", ":"))
    print("espèces : %(species)d, attaques créées : %(moves)d (dont %(effects)d avec effets), "
          "attaques gardées : %(moves_kept)d, talents : %(abilities)d" % written)


def move_effects(row, meta, changes):
    """Effets que le moteur sait jouer : [(script, champs)]."""
    effects = []
    if meta is None:
        return effects
    to_user = int(row["target_id"]) == TARGET_USER or int(meta["meta_category_id"]) in RAISES_USER
    stat_chance = int(meta["stat_chance"] or 0) or 100
    for stat_id, change in changes:
        if 2 <= stat_id <= 8:
            effects.append(("stat_stage_effect", {"stat": stat_id - 1, "stages": change, "chance": stat_chance,
                                                  "who": 1 if to_user else 0}))
    ailment = int(meta["meta_ailment_id"] or 0)
    if ailment in AILMENTS:
        condition = "toxic" if int(row["effect_id"] or 0) == TOXIC_EFFECT else AILMENTS[ailment]
        chance = int(meta["ailment_chance"] or 0) or 100
        effects.append(("inflict_condition_effect", {"condition": condition, "chance": chance}))
    drain = int(meta["drain"] or 0)
    if drain < 0:
        effects.append(("recoil_effect", {"denominator": max(1, round(100 / -drain))}))
    return effects


def move_tres(row, name, description, effects, crit=0):
    scripts = sorted({e[0] for e in effects})
    lines = ['[gd_resource type="Resource" script_class="MoveData" format=3]', "",
             '[ext_resource type="Script" path="res://battle/data/move_data.gd" id="move"]']
    if effects:
        lines.append('[ext_resource type="Script" path="res://battle/data/move_effect.gd" id="effect"]')
    for s in scripts:
        lines.append('[ext_resource type="Script" path="res://battle/effects/%s.gd" id="%s"]' % (s, s))
    lines.append("")
    for i, (script, fields) in enumerate(effects):
        lines.append('[sub_resource type="Resource" id="e%d"]' % i)
        lines.append('script = ExtResource("%s")' % script)
        for key, value in fields.items():
            if key == "condition":
                lines.append('condition = &"%s"' % value)
            elif not (key == "chance" and value == 100) and not (key == "who" and value == 0):
                lines.append("%s = %d" % (key, value))
        lines.append("")
    accuracy = int(row["accuracy"]) if row["accuracy"] else 0
    lines += ["[resource]", 'script = ExtResource("move")', 'id = &"%s"' % ident(row["identifier"]),
              "name = " + text(name), "type = %d" % TYPES[int(row["type_id"])],
              "category = %d" % CATEGORIES[int(row["damage_class_id"])],
              "power = %d" % int(row["power"] or 0), "accuracy = %d" % accuracy, "pp = %d" % int(row["pp"] or 1),
              "priority = %d" % int(row["priority"] or 0)]
    if int(row["target_id"]) == TARGET_USER:
        lines.append("target = 1")
    if crit:
        lines.append("critical_stage = %d" % min(4, crit))
    if effects:
        lines.append('effects = Array[ExtResource("effect")]([%s])' % ", ".join('SubResource("e%d")' % i for i in range(len(effects))))
    if description:
        lines.append("description = " + text(description))
    return "\n".join(lines) + "\n"


def ability_tres(row, name, description):
    lines = ['[gd_resource type="Resource" script_class="AbilityData" format=3]', "",
             '[ext_resource type="Script" path="res://battle/data/ability_data.gd" id="ability"]', "",
             "[resource]", 'script = ExtResource("ability")', 'id = &"%s"' % ident(row["identifier"]), "name = " + text(name)]
    if description:
        lines.append("description = " + text(description))
    return "\n".join(lines) + "\n"


def sprite_fields(path):
    """Sprites de combat déjà réglés dans un fichier existant : (lignes, ressources)."""
    if not os.path.exists(path):
        return ([], {})
    content = open(path, encoding="utf-8").read()
    ext = dict(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', content))
    ext = {v: k for k, v in ext.items()}
    lines = [l for l in content.splitlines() if l.split(" = ")[0] in SPRITE_FIELDS]
    used = {}
    for l in lines:
        for rid in re.findall(r'ExtResource\("([^"]+)"\)', l):
            if rid in ext:
                used[rid] = ext[rid]
    return (lines, used)


def gen1_sprites(x, y):
    lines = ['battle_sheet = ExtResource("battle")',
             "front_region = Rect2i(%d, %d, 80, 80)" % (x + GEN1_FRONT[0], y + GEN1_FRONT[1]),
             "back_region = Rect2i(%d, %d, 80, 80)" % (x + GEN1_BACK[0], y + GEN1_BACK[1]),
             "sheet_background_colors = " + GEN1_BACKGROUNDS]
    return (lines, {"battle": "res://" + GEN1_SHEET})


def species_tres(sid, row, poke, name, description, stats, efforts, types, abilities, learnset, growth, move_paths,
                 ability_paths, kept, evolves, evolves_from):
    kept_lines, kept_ext = kept
    lines = ['[gd_resource type="Resource" script_class="PokemonSpecies" format=3]', "",
             '[ext_resource type="Script" path="res://battle/data/pokemon_species.gd" id="species"]',
             '[ext_resource type="Script" path="res://battle/data/learnset_entry.gd" id="entry"]',
             '[ext_resource type="Script" path="res://battle/data/ability_data.gd" id="ability"]',
             '[ext_resource type="Texture2D" path="%s" id="icons"]' % ICON_SHEET]
    if evolves:
        lines.append('[ext_resource type="Script" path="res://battle/data/evolution_data.gd" id="evolution"]')
    for rid, path in kept_ext.items():
        lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (path, rid))
    move_ids = {}
    for _, mid in learnset:
        if mid not in move_ids:
            move_ids[mid] = "m%d" % mid
            lines.append('[ext_resource type="Resource" path="%s" id="m%d"]' % (move_paths[mid], mid))
    for _, aid, _ in abilities:
        lines.append('[ext_resource type="Resource" path="%s" id="a%d"]' % (ability_paths[aid], aid))
    lines.append("")
    for i, (level, mid) in enumerate(learnset):
        lines += ['[sub_resource type="Resource" id="l%d"]' % i, 'script = ExtResource("entry")']
        if level != 1:
            lines.append("level = %d" % level)
        lines += ['move = ExtResource("%s")' % move_ids[mid], ""]
    for i, (target, method, level, item) in enumerate(evolves):
        lines += ['[sub_resource type="Resource" id="v%d"]' % i, 'script = ExtResource("evolution")',
                  'species_id = &"%s"' % target]
        if method:
            lines.append("method = %d" % method)
        if level:
            lines.append("min_level = %d" % level)
        if item:
            lines.append('item = &"%s"' % item)
        lines.append("")
    normal = ['ExtResource("a%d")' % aid for _, aid, hidden in abilities if not hidden]
    hidden = [aid for _, aid, h in abilities if h]
    gender_rate = int(row["gender_rate"])
    female = -1.0 if gender_rate < 0 else gender_rate * 12.5
    column, line = (sid - 1) % 26, (sid - 1) // 26
    lines += ["[resource]", 'script = ExtResource("species")', 'id = &"%s"' % ident(row["identifier"]),
              "dex_number = %d" % sid, "name = " + text(name), "types = Array[int]([%s])" % ", ".join(map(str, types)),
              "base_hp = %d" % stats[1], "base_attack = %d" % stats[2], "base_defense = %d" % stats[3],
              "base_sp_attack = %d" % stats[4], "base_sp_defense = %d" % stats[5], "base_speed = %d" % stats[6],
              "description = " + text(description),
              'abilities = Array[ExtResource("ability")]([%s])' % ", ".join(normal)]
    if hidden:
        lines.append('hidden_ability = ExtResource("a%d")' % hidden[0])
    if evolves_from:
        lines.append('evolves_from = &"%s"' % evolves_from)
    if evolves:
        lines.append('evolutions = Array[ExtResource("evolution")]([%s])' % ", ".join('SubResource("v%d")' % i for i in range(len(evolves))))
    lines += ['growth_rate = &"%s"' % growth,
              "ev_yield = PackedInt32Array(%s)" % ", ".join(str(efforts.get(i, 0)) for i in range(1, 7)),
              "base_experience = %d" % int(poke["base_experience"] or 0),
              "catch_rate = %d" % int(row["capture_rate"] or 0), "female_ratio = %g" % female,
              'learnset = Array[ExtResource("entry")]([%s])' % ", ".join('SubResource("l%d")' % i for i in range(len(learnset)))]
    lines += kept_lines
    lines += ['icon_sheet = ExtResource("icons")', "icon_region = Rect2i(%d, %d, 32, 32)" % (9 + 38 * column, 94 + 38 * line)]
    return "\n".join(lines) + "\n"


def write(path, content):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)


if __name__ == "__main__":
    main()
