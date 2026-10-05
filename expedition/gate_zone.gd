class_name GateZone
extends ExpeditionZone
## Le passage vers les expéditions, en haut à gauche d'Accumula : la rue du haut se
## prolonge vers l'ouest entre deux murs de pierre, à travers les arbres ; le gardien
## (ExpeditionGuard) se tient au bout de la rue et bouche le passage.

## Coin haut-gauche de la zone (case du monde) et sa taille.
const ORIGIN := Vector2i(-28, -16)
const SIZE := Vector2i(12, 12)
## Rangée du passage et ses extrémités (cases du monde).
const ROW := -9
const FROM_X := -24
const TO_X := -17
const GRASS := Vector2i(1, 211)
const PAVING := Vector2i(2, 277)
## Mur de pierre (4 cases) au nord, muret de pierres au sud.
const WALL := Rect2i(66, 9673, 62, 55)
const LOW_STONES: Array[Rect2i] = [Rect2i(32, 897, 16, 15), Rect2i(64, 7185, 15, 15), Rect2i(113, 7233, 14, 14)]
const TREES_FROM := "res://data/expeditions/foret.tres"
## Au sud du passage, des buissons bas : des arbres y cacheraient le passage.
const LOW_PROPS: Array[Rect2i] = [Rect2i(97, 9523, 30, 13), Rect2i(32, 897, 16, 15), Rect2i(0, 9905, 16, 15)]
const LOW_FOOTPRINTS: Array[Vector2i] = [Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 1)]


func _ready() -> void:
	build(_make_layout())


func _make_layout() -> ZoneLayout:
	var layout := ZoneLayout.new()
	layout.origin = ORIGIN
	layout.size = SIZE
	for y in SIZE.y:
		for x in SIZE.x:
			layout.ground[Vector2i(x, y)] = GRASS
	var reserved := {}
	for x in range(FROM_X, TO_X + 1):
		var path := layout.to_local(Vector2i(x, ROW))
		layout.walkable[path] = true
		layout.ground[path] = PAVING
		reserved[path + Vector2i.UP] = true
		reserved[path + Vector2i.DOWN] = true
		# Muret au sud : une pierre par case.
		var stone := ExpeditionProp.new()
		stone.region = LOW_STONES[posmod(x, LOW_STONES.size())]
		layout.props.append({"cell": path + Vector2i.DOWN, "prop": stone})
	# Mur au nord, par segments de quatre cases.
	for x in range(TO_X - 3, FROM_X - 1, -4):
		var wall := ExpeditionProp.new()
		wall.region = WALL
		wall.footprint = Vector2i(4, 1)
		layout.props.append({"cell": layout.to_local(Vector2i(x, ROW - 1)), "prop": wall})
	# Au nord du passage : la forêt ; au sud, des buissons bas.
	var south := {}
	for y in range(ROW + 2 - ORIGIN.y, SIZE.y):
		for x in SIZE.x:
			south[Vector2i(x, y)] = true
	var north_reserved := reserved.duplicate()
	north_reserved.merge(south)
	ZoneGenerator.new().fill_walls(load(TREES_FROM), layout, north_reserved, 17)
	var low := ExpeditionBiome.new()
	for i in LOW_PROPS.size():
		var prop := ExpeditionProp.new()
		prop.region = LOW_PROPS[i]
		prop.footprint = LOW_FOOTPRINTS[i]
		low.props.append(prop)
	var south_reserved := reserved.duplicate()
	for cell in layout.ground:
		if not south.has(cell):
			south_reserved[cell] = true
	ZoneGenerator.new().fill_walls(low, layout, south_reserved, 23)
	return layout
