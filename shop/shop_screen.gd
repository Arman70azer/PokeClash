class_name ShopScreen
extends Control
## Écran de la boutique, ouvert en parlant à un vendeur (Npc.shop) : acheter, vendre,
## ou partir. Même style que l'écran de combat et le menu du jeu (DsUi) : listes de
## boutons crème sur l'écran tactile brun, cadres de message blancs, chiffres du HUD.
##
## - Acheter : les objets de la boutique et leur prix ; on choisit la quantité.
## - Vendre : les objets du sac qui ont un prix, rachetés à moitié prix.
## L'hôte fait autorité : chaque achat ou vente est une demande (PlayerProfiles), il
## répond avec l'argent et le sac à jour.

enum State { CLOSED, CHOICE, BUY, SELL, QUANTITY, WAITING, MESSAGE }

const CHOICES := ["Acheter", "Vendre", "Au revoir"]
const CHOICE_COLORS := [Color8(96, 192, 96), Color8(240, 184, 56), Color8(232, 88, 72)]
const POCKET_COLORS := [Color8(240, 184, 56), Color8(96, 192, 96), Color8(232, 88, 72), Color8(88, 144, 232), Color8(168, 120, 216)]
const LIST := Rect2(4, 32, 216, 174)
const SIDE := Rect2(224, 32, 124, 174)
const HINT := Rect2(4, 210, 344, 50)
const ROW_HEIGHT := 25.0
const ROW_STEP := 27.0
const ROWS := 5
const MAX_QUANTITY := 99
const OPEN_TIME := 0.18

var _state := State.CLOSED
var _shop: ShopData
var _data: PlayerData
var _choice := 0
var _index := 0
var _quantity := 1
## Liste dont vient la quantité choisie (BUY ou SELL).
var _list_state := State.BUY
var _message := ""
var _open_amount := 0.0
var _pulse := 0.0
var _tween: Tween


func _enter_tree() -> void:
	Game.register(&"shop", self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()
	visible = false
	if Game.profiles != null:
		Game.profiles.snapshot_received.connect(_on_snapshot)
		Game.profiles.request_answered.connect(_on_answer)
	Network.session_ended.connect(close)


func is_open() -> bool:
	return _state != State.CLOSED


func open(shop: ShopData) -> void:
	_shop = shop
	_state = State.CHOICE
	_choice = 0
	visible = true
	if Game.profiles != null:
		Game.profiles.request_snapshot()
	_animate(1.0)


func close() -> void:
	if _state == State.CLOSED:
		return
	_state = State.CLOSED
	_animate(0.0)


func _animate(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void:
		_open_amount = v
		queue_redraw(), _open_amount, target, OPEN_TIME)
	if target == 0.0:
		_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if _state == State.CLOSED:
		return
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	queue_redraw()


# --- Commandes ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.CLOSED:
		return
	var handled := true
	if event.is_action_pressed("move_up", true):
		_on_direction(Vector2i.UP)
	elif event.is_action_pressed("move_down", true):
		_on_direction(Vector2i.DOWN)
	elif event.is_action_pressed("move_left", true):
		_on_direction(Vector2i.LEFT)
	elif event.is_action_pressed("move_right", true):
		_on_direction(Vector2i.RIGHT)
	elif event.is_action_pressed("interact"):
		_on_accept()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		_on_back()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_direction(dir: Vector2i) -> void:
	match _state:
		State.CHOICE:
			if dir.y != 0:
				_choice = posmod(_choice + dir.y, CHOICES.size())
		State.BUY, State.SELL:
			var count := _entries().size()
			if dir.y != 0 and count > 0:
				_index = posmod(_index + dir.y, count)
		State.QUANTITY:
			var most := _max_quantity()
			# Haut / bas : une unité (en boucle), gauche / droite : dix.
			if dir.y != 0:
				_quantity = posmod(_quantity - 1 - dir.y, most) + 1
			elif dir.x != 0:
				_quantity = clampi(_quantity + dir.x * 10, 1, most)


func _on_accept() -> void:
	match _state:
		State.CHOICE:
			match _choice:
				0:
					_open_list(State.BUY)
				1:
					_open_list(State.SELL)
				2:
					close()
		State.BUY, State.SELL:
			var item := _selected()
			if item == null:
				return
			if _max_quantity() <= 0:
				_show(_cannot_text())
				return
			_list_state = _state
			_quantity = 1
			_state = State.QUANTITY
		State.QUANTITY:
			var item := _selected()
			if item == null or Game.profiles == null:
				return
			_state = State.WAITING
			if _list_state == State.BUY:
				Game.profiles.request_buy(_shop.resource_path, item.resource_path, _quantity)
			else:
				Game.profiles.request_sell(item.resource_path, _quantity)
		State.MESSAGE:
			_state = _list_state if _list_state in [State.BUY, State.SELL] else State.CHOICE


func _on_back() -> void:
	match _state:
		State.CHOICE:
			close()
		State.BUY, State.SELL:
			_state = State.CHOICE
		State.QUANTITY:
			_state = _list_state
		State.MESSAGE:
			_on_accept()


func _open_list(list: State) -> void:
	_state = list
	_list_state = list
	_index = 0


func _show(text: String) -> void:
	_message = text
	_state = State.MESSAGE


func _on_snapshot(data: PlayerData) -> void:
	_data = data
	_index = clampi(_index, 0, maxi(0, _entries().size() - 1))
	queue_redraw()


func _on_answer(message: String) -> void:
	if _state == State.CLOSED:
		return
	_show(message)


## Objets de la liste affichée : ceux de la boutique, ou ceux du sac qu'on peut vendre.
func _entries() -> Array[ItemData]:
	var found: Array[ItemData] = []
	var state := _state if _state in [State.BUY, State.SELL] else _list_state
	if state == State.BUY and _shop != null:
		for item in _shop.items:
			if item != null:
				found.append(item)
	elif state == State.SELL and _data != null:
		for item in _data.bag.items:
			if _data.bag.count(item) > 0 and ShopData.sell_price(item) > 0:
				found.append(item)
	return found


func _selected() -> ItemData:
	var items := _entries()
	return items[_index] if _index >= 0 and _index < items.size() else null


## Quantité maximale : ce que permet l'argent (achat) ou le sac (vente).
func _max_quantity() -> int:
	var item := _selected()
	if item == null or _data == null:
		return 0
	if _list_state == State.BUY:
		return mini(MAX_QUANTITY, _data.money / maxi(1, item.price))
	return _data.bag.count(item)


func _cannot_text() -> String:
	return "Vous n'avez pas assez d'argent." if _state == State.BUY else "Vous n'en avez plus."


func _unit_price(item: ItemData) -> int:
	return item.price if _list_state == State.BUY else ShopData.sell_price(item)


func _in_bag(item: ItemData) -> int:
	return _data.bag.count(item) if _data != null and item != null else 0


# --- Dessin ------------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.35 * _open_amount))
	var left_slide := roundf(-(1.0 - _open_amount) * 240.0)
	var right_slide := roundf((1.0 - _open_amount) * 140.0)
	# Argent, en haut à gauche.
	draw_set_transform(Vector2(left_slide, 0))
	var money := Rect2(4, 4, 140, 24)
	DsUi.draw_message_frame(self, money)
	DsUi.draw_text(self, money.position + Vector2(9, 3), "Argent")
	DsUi.draw_text_right(self, Vector2(money.end.x - 9, money.position.y + 3), str(_data.money) if _data != null else "…")
	if _state in [State.BUY, State.SELL, State.QUANTITY, State.WAITING] or (_state == State.MESSAGE and _list_state != State.CHOICE):
		_draw_list()
	draw_set_transform(Vector2(right_slide, 0))
	if _state == State.CHOICE or (_state == State.MESSAGE and _list_state == State.CHOICE):
		_draw_choices()
	elif _state != State.CLOSED:
		_draw_side()
	draw_set_transform(Vector2(0, roundf((1.0 - _open_amount) * 60.0)))
	_draw_hint()
	draw_set_transform(Vector2.ZERO)


func _draw_choices() -> void:
	var panel := Rect2(SIDE.position.x, SIDE.end.y - CHOICES.size() * 31 - 7, SIDE.size.x, CHOICES.size() * 31 + 7)
	DsUi.draw_touch_panel(self, panel)
	for i in CHOICES.size():
		var row := Rect2(panel.position + Vector2(4, 5 + i * 31), Vector2(panel.size.x - 8, 28))
		DsUi.draw_button(self, row, CHOICE_COLORS[i], i == _choice and _state == State.CHOICE, _pulse)
		DsUi.draw_text(self, row.position + Vector2(17, 6), CHOICES[i])


func _draw_list() -> void:
	DsUi.draw_touch_panel(self, LIST)
	var buying := _list_state == State.BUY
	DsUi.draw_text(self, LIST.position + Vector2(8, 3), "Acheter" if buying else "Vendre", true)
	DsUi.draw_text_right(self, LIST.position + Vector2(LIST.size.x - 8, 3), "Prix", true)
	var items := _entries()
	if items.is_empty():
		var empty := Rect2(LIST.position + Vector2(4, 22), Vector2(LIST.size.x - 8, ROW_HEIGHT))
		draw_colored_polygon(BattleStyle.panel_points(empty, 3), BattleSprites.HUD_PANEL_DARK)
		DsUi.draw_text(self, empty.position + Vector2(10, 4), "Rien à vendre.", true)
		return
	var first := clampi(_index - ROWS + 1, 0, maxi(0, items.size() - ROWS))
	for row in mini(ROWS, items.size() - first):
		var index := first + row
		var item := items[index]
		var rect := Rect2(LIST.position + Vector2(4, 22 + row * ROW_STEP), Vector2(LIST.size.x - 8, ROW_HEIGHT))
		var active := index == _index and _state in [State.BUY, State.SELL]
		var chosen := index == _index and not active
		DsUi.draw_button(self, rect, POCKET_COLORS[item.pocket], active or chosen, _pulse if active else 0.0)
		DsUi.draw_text(self, rect.position + Vector2(16, 4), item.name, false, rect.size.x - 70)
		DsUi.draw_text_right(self, Vector2(rect.end.x - 8, rect.position.y + 4), str(_unit_price(item)))
	# Flèches quand la liste continue au-dessus ou en dessous.
	if first > 0:
		_draw_scroll_arrow(Vector2(LIST.get_center().x, LIST.position.y + 20), -1)
	if first + ROWS < items.size():
		_draw_scroll_arrow(Vector2(LIST.get_center().x, LIST.end.y - 3), 1)


## Colonne de droite : l'objet choisi en grand, combien on en a, et la quantité.
func _draw_side() -> void:
	DsUi.draw_touch_panel(self, SIDE)
	var item := _selected()
	if item == null:
		return
	var center := SIDE.position + Vector2(SIDE.size.x / 2.0, 34)
	draw_circle(center, 25.0, BattleSprites.HUD_PANEL_DARK)
	draw_circle(center, 23.0, POCKET_COLORS[item.pocket].lerp(Color.WHITE, 0.55))
	var icon := MenuSprites.item_icon(item)
	if icon != null:
		draw_texture(icon, (center - icon.get_size() / 2.0 + Vector2(0, sin(_pulse) * 1.0)).round())
	var bag_line := Rect2(SIDE.position + Vector2(4, 66), Vector2(SIDE.size.x - 8, 22))
	DsUi.draw_message_frame(self, bag_line)
	DsUi.draw_text(self, bag_line.position + Vector2(8, 2), "Sac")
	DsUi.draw_text_right(self, Vector2(bag_line.end.x - 8, bag_line.position.y + 2), "x%d" % _in_bag(item))
	if _state in [State.QUANTITY, State.WAITING]:
		var box := Rect2(SIDE.position + Vector2(4, 94), Vector2(SIDE.size.x - 8, 76))
		DsUi.draw_message_frame(self, box)
		DsUi.draw_text(self, box.position + Vector2(8, 4), "Quantité")
		# Flèches de réglage autour du nombre.
		var qty_text := "x%d" % _quantity
		var qty_center := Vector2(box.get_center().x, box.position.y + 30)
		var half := DsUi.text_width(qty_text) / 2.0
		DsUi.draw_text(self, Vector2(qty_center.x - half, qty_center.y - 6), qty_text)
		_draw_scroll_arrow(Vector2(qty_center.x, qty_center.y - 9), -1)
		_draw_scroll_arrow(Vector2(qty_center.x, qty_center.y + 15), 1)
		draw_rect(Rect2(box.position.x + 8, box.position.y + 50, box.size.x - 16, 1), BattleStyle.MESSAGE_LINE)
		DsUi.draw_text(self, box.position + Vector2(8, 53), "Total")
		DsUi.draw_text_right(self, Vector2(box.end.x - 8, box.position.y + 53), str(_unit_price(item) * _quantity))


func _draw_hint() -> void:
	DsUi.draw_message_frame(self, HINT)
	var text := ""
	var icon: Texture2D = null
	match _state:
		State.CHOICE:
			text = "Bienvenue ! Que puis-je faire pour vous ?"
		State.BUY, State.SELL:
			var item := _selected()
			if item != null:
				text = item.description
				icon = MenuSprites.item_icon(item)
			else:
				text = "Vous n'avez rien que je puisse racheter."
		State.QUANTITY:
			var item := _selected()
			if _list_state == State.BUY:
				text = "%s ? Combien en voulez-vous ?" % item.name
			else:
				text = "Je vous reprends %s à %d pièce. Combien ?" % [item.name, _unit_price(item)]
		State.WAITING:
			text = "…"
		State.MESSAGE:
			text = _message
			DsUi.draw_more_arrow(self, HINT.end - Vector2(16, 12))
	var x := HINT.position.x + 9
	if icon != null:
		draw_texture(icon, Vector2(x - 2, HINT.position.y + 8))
		x += 34
	draw_multiline_string(GameFont.get_font(), Vector2(x, HINT.position.y + 4 + GameFont.ASCENT), text,
		HORIZONTAL_ALIGNMENT_LEFT, HINT.end.x - 12 - x, GameFont.CELL, 3)


## Petite flèche rouge vers le haut (-1) ou le bas (1), qui bat doucement.
func _draw_scroll_arrow(center: Vector2, direction: int) -> void:
	var c := center + Vector2(0, roundf(sin(_pulse)) * direction)
	var tip := c + Vector2(0, 3 * direction)
	draw_colored_polygon(PackedVector2Array([tip, c + Vector2(-4, -2 * direction), c + Vector2(4, -2 * direction)]), DsUi.CURSOR)
