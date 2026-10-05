class_name ScreenFade
extends ColorRect
## Fondu au noir de tout l'écran (entrée et sortie des bâtiments).


func _ready() -> void:
	Game.register(&"fade", self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.BLACK
	modulate.a = 0.0


func fade_out(duration := 0.35) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished


func fade_in(duration := 0.35) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
