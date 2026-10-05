class_name ShopData
extends Resource
## Une boutique : les objets qu'on peut y acheter (au prix de l'objet, ItemData.price).
## On y revend tout objet qui a un prix, pour la moitié de ce prix. Un fichier par
## boutique dans data/shops ; un PNJ vendeur la désigne dans son champ `shop`.

@export var name := "Boutique"
@export var items: Array[ItemData] = []


## Prix de revente d'un objet (0 : ne se vend pas).
static func sell_price(item: ItemData) -> int:
	return item.price / 2 if item != null else 0


func sells(item: ItemData) -> bool:
	for entry in items:
		if entry != null and entry.resource_path == item.resource_path:
			return true
	return false
