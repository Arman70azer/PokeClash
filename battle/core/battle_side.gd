class_name BattleSide
extends RefCounted
## Un camp du combat : le joueur, un dresseur adverse ou un Pokémon sauvage.
## Un seul Pokémon actif pour l'instant (combat simple) ; `active_index` deviendra une
## liste pour les combats doubles.

var index := 0
var name := ""
## Camp contrôlé par un joueur humain (ses actions arrivent par submit_action).
var is_human := false
## Identifiant réseau du joueur qui contrôle ce camp (0 si l'IA).
var peer_id := 0
var team: Array[BattlePokemon] = []
var active_index := -1
var ai: BattleAI
var bag: Bag
var trainer: TrainerData
## Balls qu'il peut encore lancer dans ce combat (-1 : sans limite ; voir les expéditions).
var balls_left := -1
## Tentatives de fuite ratées (la formule de fuite en tient compte).
var run_attempts := 0


func active() -> BattlePokemon:
	return team[active_index] if active_index >= 0 and active_index < team.size() else null


## Index des Pokémon qui peuvent être envoyés (non K.O. et pas déjà au combat).
func available_reserves() -> Array[int]:
	var found: Array[int] = []
	for i in team.size():
		if i != active_index and not team[i].is_fainted():
			found.append(i)
	return found


func has_usable_pokemon() -> bool:
	for pokemon in team:
		if not pokemon.is_fainted():
			return true
	return false


func first_usable_index() -> int:
	for i in team.size():
		if not team[i].is_fainted():
			return i
	return -1
