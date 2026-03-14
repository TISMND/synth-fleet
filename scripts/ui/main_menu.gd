extends Control
## Main menu with navigation to Play, Loadout, and Dev Studio.


func _ready() -> void:
	ThemeManager.apply_grid_background($Background)
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Update play button text based on campaign progress
	if GameState.current_level > 0:
		$VBoxContainer/PlayButton.text = "CONTINUE (LVL " + str(GameState.current_level + 1) + ")"
	else:
		$VBoxContainer/PlayButton.text = "PLAY"

	$VBoxContainer/PlayButton.pressed.connect(_on_play)
	$VBoxContainer/RestartButton.pressed.connect(_on_restart)
	$VBoxContainer/HangarButton.pressed.connect(_on_hangar)
	$VBoxContainer/DevStudioButton.pressed.connect(_on_dev_studio)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_restart() -> void:
	GameState.reset_campaign()
	$VBoxContainer/PlayButton.text = "PLAY"


func _on_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_dev_studio() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio.tscn")


func _on_theme_changed() -> void:
	ThemeManager.apply_grid_background($Background)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
