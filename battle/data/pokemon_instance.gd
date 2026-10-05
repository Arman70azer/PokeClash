class_name PokemonInstance
extends Resource
## Un Pokémon précis, avec ce qui doit être conservé d'un combat à l'autre : niveau,
## PV, attaques et PP, statut, objet tenu... C'est ce qui est enregistré dans l'équipe
## d'un joueur ou d'un dresseur. En combat, il est copié dans un BattlePokemon, et seul
## ce qui doit durer y est recopié à la fin (PV, PP, statut).

@export var species: PokemonSpecies
## Identifiant unique de ce Pokémon (créé à sa naissance, conservé dans la sauvegarde) :
## permet de vérifier qu'il n'est jamais à deux endroits à la fois (équipe, boîtes du PC).
@export var uid := ""
## Genre : &"male", &"female" ou &"none" (espèce asexuée).
@export var gender: StringName = &"none"
## Surnom ; vide = nom de l'espèce.
@export var nickname := ""
@export_range(1, 100) var level := 5
@export var experience := 0
@export_range(0, 24) var nature := 0
## Valeurs individuelles (0 à 31) et de base (0 à 255), dans l'ordre de Stat.PERMANENT.
@export var ivs := PackedInt32Array([0, 0, 0, 0, 0, 0])
@export var evs := PackedInt32Array([0, 0, 0, 0, 0, 0])
## Attaques connues (quatre au plus) et PP restants, dans le même ordre.
@export var moves: Array[MoveData] = []
@export var move_pp := PackedInt32Array()
## PV restants ; -1 = PV au maximum.
@export var current_hp := -1
## Statut permanent (voir BattleConditions) : &"" = aucun, &"poison", &"burn"...
@export var status: StringName = &""
## Compteur du statut (tours de sommeil restants).
@export var status_counter := 0
@export var held_item: ItemData
## Talent (non géré en génération 5 de ce prototype ; prévu pour plus tard).
@export var ability: StringName
## Bonheur/Amitié avec le dresseur (0-255, initialement 70).
@export_range(0, 255) var happiness := 70
## Origine : dresseur d'origine, lieu et niveau de la rencontre (vide : inconnus).
@export var original_trainer := ""
@export var met_location := ""
@export var met_level := 0


## Crée un Pokémon neuf : attaques de son niveau, PV au maximum. `rng` tire nature et
## IV au hasard ; sans rng, nature neutre (Hardi) et IV fixes à `fixed_iv`.
static func create(p_species: PokemonSpecies, p_level: int, rng: RandomNumberGenerator = null, fixed_iv := 15) -> PokemonInstance:
	if p_species == null:
		push_error("PokemonInstance.create : espèce manquante")
		return null
	var p := PokemonInstance.new()
	p.species = p_species
	p.level = clampi(p_level, 1, 100)
	if rng != null:
		p.nature = rng.randi_range(0, Nature.COUNT - 1)
		for i in 6:
			p.ivs[i] = rng.randi_range(0, 31)
	else:
		p.nature = 0
		p.ivs = PackedInt32Array([fixed_iv, fixed_iv, fixed_iv, fixed_iv, fixed_iv, fixed_iv])
	p.moves = p_species.moves_at_level(p.level)
	p.restore()
	p.uid = new_uid()
	p.gender = roll_gender(p_species, rng)
	if not p_species.abilities.is_empty():
		var pick := rng.randi_range(0, p_species.abilities.size() - 1) if rng != null else 0
		p.ability = p_species.abilities[pick].id
	p.met_level = p.level
	p.experience = Growth.experience_for(p_species.growth_rate, p.level)
	return p


func display_name() -> String:
	return nickname if not nickname.is_empty() else (species.name if species != null else "???")


## Valeur d'une statistique permanente, selon les règles de combat.
func stat(stat_id: int, rules: BattleRules = null) -> int:
	var r := rules if rules != null else BattleRules.default_rules()
	var index: int = Stat.PERMANENT.find(stat_id)
	if index == -1:
		push_error("PokemonInstance : %s n'est pas une statistique permanente" % Stat.stat_name(stat_id))
		return 0
	var value := r.stat_value(stat_id, species.base_stat(stat_id), level, ivs[index], evs[index], nature)
	return species.adjust_stat(stat_id, value, self)


func max_hp(rules: BattleRules = null) -> int:
	return stat(Stat.HP, rules)


func hp(rules: BattleRules = null) -> int:
	return max_hp(rules) if current_hp < 0 else current_hp


func is_fainted() -> bool:
	return current_hp == 0


func pp_left(index: int) -> int:
	if index < 0 or index >= moves.size():
		return 0
	if index >= move_pp.size():
		return moves[index].pp
	return move_pp[index]


## Soin complet : PV, PP et statut (Centre Pokémon).
func restore() -> void:
	current_hp = -1
	status = &""
	status_counter = 0
	move_pp.resize(moves.size())
	for i in moves.size():
		move_pp[i] = moves[i].pp


# --- Expérience et évolution ------------------------------------------------------------

## Expérience totale au début de son niveau, et au début du suivant.
func level_floor() -> int:
	return Growth.experience_for(species.growth_rate, level)


func next_level_experience() -> int:
	return Growth.experience_for(species.growth_rate, level + 1)


## Ajoute de l'expérience et monte les niveaux atteints. Renvoie un dictionnaire par
## niveau gagné : {"level", "learned": attaques apprises, "skipped": attaques qu'il n'a
## pas pu apprendre (quatre déjà connues), "needs_replacement": attaque qui demande l'oubli
## d'une autre pour être apprise}.
func gain_experience(amount: int) -> Array[Dictionary]:
	var gained: Array[Dictionary] = []
	if amount <= 0 or level >= Growth.MAX_LEVEL:
		return gained
	experience = mini(experience + amount, Growth.experience_for(species.growth_rate, Growth.MAX_LEVEL))
	while level < Growth.MAX_LEVEL and experience >= next_level_experience():
		var old_max := max_hp()
		level += 1
		# Les PV gagnés avec le niveau s'ajoutent aux PV restants.
		if current_hp > 0:
			current_hp = mini(max_hp(), current_hp + max_hp() - old_max)
		var step := {"level": level, "learned": [], "skipped": [], "needs_replacement": null}
		for move in species.moves_learned_at(level):
			if learn_move(move):
				step["learned"].append(move)
			elif moves.size() >= 4:
				step["needs_replacement"] = move
		gained.append(step)
	return gained


## Apprend une attaque s'il en connaît moins de quatre. Faux s'il ne peut pas (ou la
## connaît déjà).
func learn_move(move: MoveData) -> bool:
	if move == null or move in moves or moves.size() >= 4:
		return false
	moves.append(move)
	move_pp.resize(moves.size())
	move_pp[moves.size() - 1] = move.pp
	return true


## Apprend une attaque en remplaçant une autre si nécessaire. Retourne un dictionnaire :
## {"success": booléen, "new_move": MoveData, "replaced_move": MoveData ou null}.
## Si le Pokémon connaît déjà 4 attaques et qu'on n'oublie pas l'une d'elles, c'échoue.
func learn_move_with_replacement(move: MoveData, index_to_forget: int = -1) -> Dictionary:
	var result := {"success": false, "new_move": move, "replaced_move": null}
	if move == null or move in moves:
		return result

	if moves.size() < 4:
		result["success"] = learn_move(move)
		return result

	if index_to_forget < 0 or index_to_forget >= moves.size():
		return result

	var old_move := moves[index_to_forget]
	moves[index_to_forget] = move
	move_pp[index_to_forget] = move.pp
	result["success"] = true
	result["replaced_move"] = old_move
	return result


## Évolution par le niveau possible maintenant, ou null.
func ready_evolution() -> PokemonSpecies:
	var evolution := species.level_evolution(level) if species != null else null
	return evolution.species() if evolution != null else null


## Évolution par pierre possible pour cet objet, ou null.
func item_evolution(item_id: StringName) -> PokemonSpecies:
	var evolution := species.item_evolution(item_id) if species != null else null
	return evolution.species() if evolution != null else null


## Évolution par échange possible, ou null.
func trade_evolution() -> PokemonSpecies:
	var evolution := species.trade_evolution() if species != null else null
	return evolution.species() if evolution != null else null


## Évolution par bonheur possible, ou null.
func happiness_evolution() -> PokemonSpecies:
	if species == null or happiness < 220:
		return null
	var evolution := species.happiness_evolution()
	return evolution.species() if evolution != null else null


## Modifie le bonheur (amitié) avec le dresseur.
func modify_happiness(delta: int) -> void:
	happiness = clampi(happiness + delta, 0, 255)


## Fait évoluer ce Pokémon : nouvelle espèce, PV gagnés ajoutés, attaques de son niveau
## dans la nouvelle espèce apprises si possible. Renvoie les attaques apprises.
func evolve_into(new_species: PokemonSpecies) -> Array[MoveData]:
	var learned: Array[MoveData] = []
	if new_species == null:
		return learned
	var old_max := max_hp()
	species = new_species
	if current_hp > 0:
		current_hp = mini(max_hp(), current_hp + max_hp() - old_max)
	if ability_data() == null and not species.abilities.is_empty():
		ability = species.abilities[0].id
	for move in species.moves_learned_at(level):
		if learn_move(move):
			learned.append(move)
	return learned


## Vérifie la cohérence de la donnée ; renvoie la liste des problèmes trouvés.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if species == null:
		problems.append("Pokémon sans espèce")
		return problems
	if moves.is_empty():
		problems.append("%s n'a aucune attaque" % display_name())
	if moves.size() > 4:
		problems.append("%s connaît plus de quatre attaques" % display_name())
	for move in moves:
		if move == null:
			problems.append("%s : attaque vide" % display_name())
	if ivs.size() != 6 or evs.size() != 6:
		problems.append("%s : il faut six IV et six EV" % display_name())
	return problems


## Données à sauvegarder : un dictionnaire de valeurs simples (les espèces, attaques et
## objets sont désignés par le chemin de leur fichier .tres).
func to_dict() -> Dictionary:
	var move_paths := PackedStringArray()
	for move in moves:
		move_paths.append(move.resource_path)
	return {
		"uid": uid,
		"species": species.resource_path,
		"nickname": nickname,
		"level": level,
		"experience": experience,
		"nature": nature,
		"ivs": Array(ivs),
		"evs": Array(evs),
		"moves": Array(move_paths),
		"move_pp": Array(move_pp),
		"current_hp": current_hp,
		"status": String(status),
		"status_counter": status_counter,
		"held_item": held_item.resource_path if held_item != null else "",
		"ability": String(ability),
		"gender": String(gender),
		"original_trainer": original_trainer,
		"met_location": met_location,
		"met_level": met_level,
		"happiness": happiness,
	}


## Recrée un Pokémon sauvegardé par to_dict(), ou null si la donnée est inutilisable.
static func from_dict(data: Dictionary) -> PokemonInstance:
	var p_species := _load_resource(data.get("species", "")) as PokemonSpecies
	if p_species == null:
		push_error("PokemonInstance.from_dict : espèce introuvable %s" % data.get("species", ""))
		return null
	var p := PokemonInstance.new()
	p.species = p_species
	p.nickname = data.get("nickname", "")
	p.level = clampi(int(data.get("level", 5)), 1, 100)
	# Expérience d'avant les courbes d'expérience : au moins celle de son niveau.
	p.experience = maxi(int(data.get("experience", 0)), Growth.experience_for(p_species.growth_rate, p.level))
	p.nature = int(data.get("nature", 0))
	p.ivs = PackedInt32Array(data.get("ivs", [0, 0, 0, 0, 0, 0]))
	p.evs = PackedInt32Array(data.get("evs", [0, 0, 0, 0, 0, 0]))
	var known: Array[MoveData] = []
	for path in data.get("moves", []):
		var move := _load_resource(path) as MoveData
		if move != null:
			known.append(move)
	p.moves = known
	p.move_pp = PackedInt32Array(data.get("move_pp", []))
	p.current_hp = int(data.get("current_hp", -1))
	p.status = StringName(data.get("status", ""))
	p.status_counter = int(data.get("status_counter", 0))
	p.held_item = _load_resource(data.get("held_item", "")) as ItemData
	p.ability = StringName(data.get("ability", ""))
	# Pokémon sauvegardé avant l'import des talents : il prend le premier talent de son espèce.
	if p.ability_data() == null and not p_species.abilities.is_empty():
		p.ability = p_species.abilities[0].id
	# Sauvegarde d'avant le genre : on le tire d'après l'espèce.
	p.gender = StringName(data.get("gender", "")) if data.has("gender") else roll_gender(p_species, null)
	p.original_trainer = data.get("original_trainer", "")
	p.met_location = data.get("met_location", "")
	p.met_level = int(data.get("met_level", 0))
	# Ancienne sauvegarde sans identifiant : on lui en donne un.
	p.uid = data.get("uid", "")
	if p.uid.is_empty():
		p.uid = new_uid()
	# Bonheur : ancienne sauvegarde utilise la valeur par défaut (70).
	p.happiness = clampi(int(data.get("happiness", 70)), 0, 255)
	return p


static func _load_resource(path: String) -> Resource:
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


## Nouvel identifiant unique (16 chiffres hexadécimaux tirés au hasard).
static func new_uid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]


## Genre tiré au hasard d'après la part de femelles de l'espèce.
static func roll_gender(p_species: PokemonSpecies, rng: RandomNumberGenerator) -> StringName:
	if p_species == null or p_species.female_ratio < 0.0:
		return &"none"
	var roll := (rng.randf() if rng != null else randf()) * 100.0
	return &"female" if roll < p_species.female_ratio else &"male"


## Talent du Pokémon (parmi ceux de son espèce), ou null s'il n'en a pas.
func ability_data() -> AbilityData:
	if species == null or String(ability).is_empty():
		return null
	for candidate in species.abilities + [species.hidden_ability]:
		if candidate != null and candidate.id == ability:
			return candidate
	return null
