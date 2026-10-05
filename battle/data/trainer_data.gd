class_name TrainerData
extends Resource
## Un dresseur adverse : nom, équipe, comportement et répliques de combat. Un fichier
## .tres par dresseur dans data/trainers, référencé par le PNJ qui le représente.

@export var name := ""
## Catégorie affichée devant le nom (« Dresseuse », « Champion »...).
@export var title := ""
## Équipe : copiée au début de chaque combat (le dresseur se soigne entre deux combats).
@export var team: Array[PokemonInstance] = []
## Comportement en combat (voir BattleAI.create) : &"random", &"trainer".
@export var ai: StringName = &"trainer"
@export var prize_money := 0
@export_group("Répliques")
## Dites dans le combat quand le dresseur perd ou gagne.
@export_multiline var defeat_line := ""
@export_multiline var victory_line := ""
@export_group("Sprite de combat")
@export var battle_sheet: Texture2D
@export var front_region := Rect2i()
@export var sheet_background_colors: Array[Color] = []


func full_name() -> String:
	return ("%s %s" % [title, name]).strip_edges()


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if name.is_empty():
		problems.append("dresseur sans nom (%s)" % resource_path)
	if team.is_empty():
		problems.append("dresseur %s sans Pokémon" % name)
	for pokemon in team:
		if pokemon == null:
			problems.append("dresseur %s : Pokémon vide dans l'équipe" % name)
		else:
			problems.append_array(pokemon.validate())
	return problems
