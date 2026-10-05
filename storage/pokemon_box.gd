class_name PokemonBox
extends RefCounted
## Une boîte du PC : identifiant stable, nom, fond, et des emplacements qui contiennent
## chacun un Pokémon (PokemonInstance, le même objet que dans l'équipe) ou rien (null).

## Identifiant stable (ne change pas quand on renomme la boîte).
var id: StringName
var name := ""
## Fond de la boîte (indice dans la planche des fonds).
var wallpaper := 0
## Un élément par place : PokemonInstance ou null.
var slots: Array = []


func _init(p_id: StringName = &"", p_name := "", p_capacity := 30, p_wallpaper := 0) -> void:
	id = p_id
	name = p_name
	wallpaper = p_wallpaper
	slots.resize(p_capacity)


func capacity() -> int:
	return slots.size()


func get_pokemon(slot: int) -> PokemonInstance:
	return slots[slot] if slot >= 0 and slot < slots.size() else null


func count() -> int:
	var n := 0
	for pokemon in slots:
		if pokemon != null:
			n += 1
	return n


func is_full() -> bool:
	return count() >= capacity()


func is_empty() -> bool:
	return count() == 0


## Première place libre, ou -1 si la boîte est pleine.
func first_free() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


## Données à sauvegarder : seulement les places occupées.
func to_dict() -> Dictionary:
	var filled := []
	for i in slots.size():
		if slots[i] != null:
			filled.append({"slot": i, "pokemon": (slots[i] as PokemonInstance).to_dict()})
	return {"id": String(id), "name": name, "wallpaper": wallpaper, "capacity": slots.size(), "pokemon": filled}


## Recrée une boîte sauvegardée. Les Pokémon illisibles ou placés hors de la boîte sont
## signalés dans `problems` et mis dans `overflow` (jamais perdus).
static func from_dict(data: Dictionary, default_capacity: int, problems: PackedStringArray, overflow: Array) -> PokemonBox:
	var capacity := maxi(int(data.get("capacity", default_capacity)), default_capacity)
	var box := PokemonBox.new(StringName(data.get("id", "")), data.get("name", ""), capacity, int(data.get("wallpaper", 0)))
	for entry in data.get("pokemon", []):
		var pokemon := PokemonInstance.from_dict(entry.get("pokemon", {}))
		if pokemon == null:
			problems.append("%s : un Pokémon illisible a été ignoré" % box.name)
			continue
		var slot := int(entry.get("slot", -1))
		if slot < 0 or slot >= capacity or box.slots[slot] != null:
			problems.append("%s : place %d invalide, Pokémon mis de côté" % [box.name, slot])
			overflow.append(pokemon)
			continue
		box.slots[slot] = pokemon
	return box
