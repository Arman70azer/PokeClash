class_name HealItem
extends ItemData
## Objet de soin : rend des PV (Potion...) et/ou guérit des statuts (Antidote...).

## PV rendus ; -1 = tous.
@export var heal_amount := 0
## Statuts guéris (&"poison", &"burn"...). Vide = aucun.
@export var cures: Array[StringName] = []


func can_use_on(_engine: BattleEngine, target: BattlePokemon) -> String:
	if target == null or target.is_fainted():
		return "Ça ne marchera pas sur un Pokémon K.O."
	var heals := heal_amount != 0 and target.hp < target.max_hp
	var cures_status := target.status != null and target.status.id in cures
	if not heals and not cures_status:
		return "Ça ne sert à rien maintenant."
	return ""


func use_on(engine: BattleEngine, target: BattlePokemon) -> void:
	if heal_amount != 0 and target.hp < target.max_hp:
		var amount := target.max_hp if heal_amount < 0 else heal_amount
		engine.heal(target, amount)
	if target.status != null and target.status.id in cures:
		engine.cure_status(target)


func can_use_on_pokemon(pokemon: PokemonInstance) -> String:
	if pokemon == null or pokemon.is_fainted():
		return "Ça ne marchera pas sur un Pokémon K.O."
	var heals := heal_amount != 0 and pokemon.hp() < pokemon.max_hp()
	var cures_status := not pokemon.status.is_empty() and pokemon.status in cures
	if not heals and not cures_status:
		return "Ça ne servirait à rien."
	return ""


func use_on_pokemon(pokemon: PokemonInstance) -> String:
	var lines := PackedStringArray()
	if heal_amount != 0 and pokemon.hp() < pokemon.max_hp():
		var before := pokemon.hp()
		var amount := pokemon.max_hp() if heal_amount < 0 else heal_amount
		pokemon.current_hp = mini(pokemon.max_hp(), before + amount)
		if pokemon.current_hp == pokemon.max_hp():
			pokemon.current_hp = -1
		lines.append("%s récupère %d PV." % [pokemon.display_name(), pokemon.hp() - before])
	if not pokemon.status.is_empty() and pokemon.status in cures:
		pokemon.status = &""
		pokemon.status_counter = 0
		lines.append("%s est guéri." % pokemon.display_name())
	return " ".join(lines)
