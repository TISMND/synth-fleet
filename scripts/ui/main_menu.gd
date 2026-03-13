extends Control
## Main menu — Play, Loadout (sequencer), Studio (placeholder).


func _ready() -> void:
	$VBox/PlayButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	$VBox/LoadoutButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/weapon_customizer.tscn")
	)
	$VBox/StudioButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/aesthetic_workshop.tscn")
	)
	$VBox/EffectsButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/effect_designer.tscn")
	)  # Button text is now "WEAPON BUILDER"
