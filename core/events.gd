extends Node
## Autoload « Events » : signaux qui traversent le jeu, pour que les systèmes se parlent
## sans se connaître. Celui qui émet ne sait pas qui écoute.

## Afficher des répliques dans la boîte de dialogue de cet ordinateur.
@warning_ignore("unused_signal")
signal message_requested(speaker: String, lines: PackedStringArray)
