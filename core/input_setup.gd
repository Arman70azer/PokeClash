class_name InputSetup
extends RefCounted
## Touches du jeu, ajoutées au démarrage si elles n'existent pas déjà.

## Flèches + ZQSD (touches physiques, donc WASD sur un clavier QWERTY).
const KEYS := {
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	# Parler / faire défiler un dialogue / valider : Espace, Entrée ou E.
	"interact": [KEY_SPACE, KEY_ENTER, KEY_E],
	# Revenir en arrière dans un menu (combat) : X ou Retour arrière.
	"cancel": [KEY_X, KEY_BACKSPACE],
	# Ouvrir le menu du jeu (équipe, sac, sauvegarde) : Échap ou X.
	"menu": [KEY_ESCAPE, KEY_X],
}
## Manette : croix directionnelle, A pour valider, B pour revenir, Start pour le menu.
const PAD := {
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	"interact": JOY_BUTTON_A, "cancel": JOY_BUTTON_B, "menu": JOY_BUTTON_START,
}


static func install() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		var button := InputEventJoypadButton.new()
		button.button_index = PAD[action]
		InputMap.action_add_event(action, button)
