extends Node
## Autoload « Game » : accès aux services de la partie, sans chemins de nœuds ni groupes.
## Chaque service s'inscrit ici en entrant dans l'arbre et se retire en sortant
## (voir Game.register). Une valeur nulle veut dire que le service n'est pas chargé.

## Le monde (zones, grille, caméra, joueurs).
var world: World
## Combats et données des joueurs (chez l'hôte).
var battles: BattleService
## Écran de combat de cet ordinateur.
var battle_screen: BattleScreen
## Données et sauvegardes des joueurs (chez l'hôte).
var profiles: PlayerProfiles
## Menu du jeu (équipe, sac, sauvegarde) de cet ordinateur.
var menu: GameMenu
## PC de stockage de cet ordinateur.
var pc: PcScreen
## Boutique ouverte par un vendeur, sur cet ordinateur.
var shop: ShopScreen
## Expéditions (zones générées) et écran de choix de la zone.
var expeditions: ExpeditionService
var expedition_screen: ExpeditionScreen
## Boîte de dialogue de cet ordinateur.
var dialogue: DialogueBox
## Fondu au noir de tout l'écran.
var fade: ScreenFade


## Inscrit `node` comme service `slot` tant qu'il est dans l'arbre.
func register(slot: StringName, node: Node) -> void:
	set(slot, node)
	node.tree_exiting.connect(func():
		if get(slot) == node:
			set(slot, null), CONNECT_ONE_SHOT)
