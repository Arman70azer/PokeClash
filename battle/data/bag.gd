class_name Bag
extends Resource
## Le sac d'un joueur : objets et quantités.

@export var items: Array[ItemData] = []
@export var counts := PackedInt32Array()


func count(item: ItemData) -> int:
	var i := items.find(item)
	return counts[i] if i != -1 else 0


func add(item: ItemData, amount := 1) -> void:
	if item == null or amount <= 0:
		push_error("Bag.add : objet ou quantité invalide")
		return
	var i := items.find(item)
	if i == -1:
		items.append(item)
		counts.append(amount)
	else:
		counts[i] += amount


## Retire des objets ; faux (et rien n'est retiré) s'il n'y en a pas assez.
func remove(item: ItemData, amount := 1) -> bool:
	var i := items.find(item)
	if i == -1 or counts[i] < amount:
		return false
	counts[i] -= amount
	if counts[i] == 0:
		items.remove_at(i)
		counts.remove_at(i)
	return true


## Objets utilisables en combat, avec leur quantité.
func battle_items() -> Array[ItemData]:
	var found: Array[ItemData] = []
	for item in items:
		if item.usable_in_battle and count(item) > 0:
			found.append(item)
	return found


func find_by_id(item_id: StringName) -> ItemData:
	for item in items:
		if item.id == item_id:
			return item
	return null


## Données à sauvegarder : chemin du fichier de chaque objet -> quantité.
func to_dict() -> Dictionary:
	var result := {}
	for i in items.size():
		result[items[i].resource_path] = counts[i]
	return result


static func from_dict(data: Dictionary) -> Bag:
	var bag := Bag.new()
	for path in data:
		if ResourceLoader.exists(path):
			bag.add(load(path), int(data[path]))
		else:
			push_warning("Bag.from_dict : objet introuvable %s" % path)
	return bag
