class_name EvolutionItem
extends ItemData
## Objet qui fait évoluer certains Pokémon, depuis le menu Sac : les pierres (évolution
## par objet dont l'identifiant est celui de la pierre, &"fire-stone"...) et le Fil de
## liaison, qui remplace l'échange (évolutions par échange).

## Déclenche les évolutions par échange au lieu de celles par objet.
@export var replaces_trade := false


## Espèce en laquelle cet objet ferait évoluer le Pokémon, ou null.
func evolution_for(pokemon: PokemonInstance) -> PokemonSpecies:
	if pokemon == null:
		return null
	return pokemon.trade_evolution() if replaces_trade else pokemon.item_evolution(id)


func can_use_on_pokemon(pokemon: PokemonInstance) -> String:
	return "" if evolution_for(pokemon) != null else "Ça n'aurait aucun effet."


func use_on_pokemon(pokemon: PokemonInstance) -> String:
	var next := evolution_for(pokemon)
	var before := pokemon.display_name()
	var lines := PackedStringArray(["Félicitations ! Votre %s a évolué en %s !" % [before, next.name]])
	for move in pokemon.evolve_into(next):
		lines.append("%s apprend %s !" % [pokemon.display_name(), move.name])
	return " ".join(lines)
