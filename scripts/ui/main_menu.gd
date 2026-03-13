extends Control
## Main menu with navigation to Play, Loadout, and Dev Studio.


func _ready() -> void:
	$VBoxContainer/PlayButton.pressed.connect(_on_play)
	$VBoxContainer/LoadoutButton.pressed.connect(_on_loadout)
	$VBoxContainer/DevStudioButton.pressed.connect(_on_dev_studio)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/play_placeholder.tscn")


func _on_loadout() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/loadout_screen.tscn")


func _on_dev_studio() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
