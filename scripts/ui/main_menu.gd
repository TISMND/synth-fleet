extends Control
## Main menu with navigation to Play, Loadout, and Dev Studio.

var _vhs_overlay: ColorRect


func _ready() -> void:
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Update play button text based on campaign progress
	if GameState.current_level > 0:
		$VBoxContainer/PlayButton.text = "CONTINUE (LVL " + str(GameState.current_level + 1) + ")"
	else:
		$VBoxContainer/PlayButton.text = "PLAY"

	$VBoxContainer/PlayButton.pressed.connect(_on_play)
	$VBoxContainer/RestartButton.pressed.connect(_on_restart)
	$VBoxContainer/HangarButton.pressed.connect(_on_hangar)
	$VBoxContainer/ShipViewerButton.pressed.connect(_on_ship_viewer)
	$VBoxContainer/AestheticStudioButton.pressed.connect(_on_aesthetic_studio)
	$VBoxContainer/DevStudioButton.pressed.connect(_on_dev_studio)

	_apply_styles()


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_restart() -> void:
	GameState.reset_campaign()
	$VBoxContainer/PlayButton.text = "PLAY"


func _on_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_ship_viewer() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ship_viewer.tscn")


func _on_aesthetic_studio() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/aesthetic_studio.tscn")


func _on_dev_studio() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio.tscn")


func _apply_styles() -> void:
	# Title
	var title: Label = $VBoxContainer/Title
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		title.add_theme_font_override("font", header_font)
	ThemeManager.apply_text_glow(title, "header")

	# Buttons
	for btn_node in $VBoxContainer.get_children():
		if btn_node is Button:
			ThemeManager.apply_button_style(btn_node as Button)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_styles()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
