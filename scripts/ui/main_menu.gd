extends Control
## Main menu with navigation to Play sub-menu, Options, Quit, and Dev Studio sub-menu.

var _vhs_overlay: ColorRect


func _ready() -> void:
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	$VBoxContainer/PlayButton.pressed.connect(_on_play)
	$VBoxContainer/OptionsButton.pressed.connect(_on_options)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)
	$VBoxContainer/DevStudioButton.pressed.connect(_on_dev_studio)

	_apply_styles()


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/play_menu.tscn")


func _on_options() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/options_screen.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _on_dev_studio() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _apply_styles() -> void:
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
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
