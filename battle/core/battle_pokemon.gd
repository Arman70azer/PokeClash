class_name BattlePokemon
extends RefCounted
## Un Pokémon pendant un combat : copie de travail de son PokemonInstance. Tout ce qui
## ne dure que le combat vit ici (niveaux de statistiques, statuts volatils...) ; à la
## fin, sync_to_source() recopie dans le PokemonInstance ce qui doit durer.

var source: PokemonInstance
var side := 0
## Place dans l'équipe de son camp.
var team_index := 0

var species: PokemonSpecies
var name := ""
var level := 1
var types: Array = []
var max_hp := 1
var hp := 1
## Statistiques permanentes calculées une fois au début du combat.
var stats := {}
## Niveaux de statistiques, de -6 à +6.
var stages := {}
var moves: Array[MoveData] = []
var pp := PackedInt32Array()
## Statut principal (poison, brûlure...) : un seul à la fois, ou null.
var status: BattleCondition
## Effets volatils (Vampigraine...) : disparaissent quand le Pokémon est rappelé.
var volatiles: Array[BattleCondition] = []
var held_item: ItemData
## Vrai une fois son K.O. annoncé.
var faint_announced := false
## Vrai s'il a déjà été envoyé au combat.
var has_battled := false
## Pokémon adverses (place dans l'équipe d'en face) qui l'ont affronté : ils se partagent
## l'expérience quand il est mis K.O.
var fought_by: Array[int] = []


static func from_instance(instance: PokemonInstance, p_side: int, p_index: int, rules: BattleRules) -> BattlePokemon:
	var problems := instance.validate() if instance != null else PackedStringArray(["Pokémon manquant"])
	if not problems.is_empty():
		push_error("BattlePokemon : Pokémon invalide : %s" % ", ".join(problems))
		return null
	var p := BattlePokemon.new()
	p.source = instance
	p.side = p_side
	p.team_index = p_index
	p.species = instance.species
	p.name = instance.display_name()
	p.level = instance.level
	p.types = instance.species.battle_types(instance)
	for stat in Stat.PERMANENT:
		p.stats[stat] = instance.stat(stat, rules)
	p.max_hp = p.stats[Stat.HP]
	p.hp = instance.hp(rules)
	p.moves = instance.moves.duplicate()
	p.pp.resize(p.moves.size())
	for i in p.moves.size():
		p.pp[i] = instance.pp_left(i)
	p.held_item = instance.held_item
	p.reset_stages()
	return p


func reset_stages() -> void:
	for stat in Stat.STAGED:
		stages[stat] = 0


func is_fainted() -> bool:
	return hp <= 0


func has_type(type: int) -> bool:
	return type in types


func has_volatile(id: StringName) -> bool:
	return get_volatile(id) != null


func get_volatile(id: StringName) -> BattleCondition:
	for condition in volatiles:
		if condition.id == id:
			return condition
	return null


## Tous les effets actifs : statut principal puis volatils.
func conditions() -> Array[BattleCondition]:
	var all: Array[BattleCondition] = []
	if status != null:
		all.append(status)
	all.append_array(volatiles)
	return all


## Index des attaques encore utilisables (PP restants).
func usable_moves() -> Array[int]:
	var usable: Array[int] = []
	for i in moves.size():
		if pp[i] > 0:
			usable.append(i)
	return usable


## Valeur d'une statistique en combat, niveaux et statuts compris. `ignore_positive` /
## `ignore_negative` : pour les coups critiques, qui ignorent certains niveaux.
func effective_stat(stat: int, rules: BattleRules, ignore_positive := false, ignore_negative := false) -> int:
	var stage: int = stages.get(stat, 0)
	if (ignore_positive and stage > 0) or (ignore_negative and stage < 0):
		stage = 0
	var value := float(stats[stat]) * rules.stage_multiplier(stage)
	for condition in conditions():
		value = condition.modify_stat(stat, value, rules)
	return maxi(1, int(floor(value)))


## Reprend niveau, statistiques et attaques de son PokemonInstance après une montée de
## niveau ; les PV gagnés s'ajoutent aux PV restants.
func refresh_from_source(rules: BattleRules) -> void:
	var old_max := max_hp
	level = source.level
	species = source.species
	for stat in Stat.PERMANENT:
		stats[stat] = source.stat(stat, rules)
	max_hp = stats[Stat.HP]
	if hp > 0:
		hp = mini(max_hp, hp + max_hp - old_max)
	while moves.size() < source.moves.size():
		moves.append(source.moves[moves.size()])
		pp.append(moves[moves.size() - 1].pp)


## Recopie dans le PokemonInstance ce qui dure après le combat.
func sync_to_source() -> void:
	source.current_hp = hp
	source.move_pp = pp.duplicate()
	if status != null and status.persists_after_battle:
		source.status = status.id
		source.status_counter = status.counter
	else:
		source.status = &""
		source.status_counter = 0
