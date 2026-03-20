extends Control
## Play sub-menu: Hangar, Begin, Back.

var _vhs_overlay: ColorRect


func _ready() -> void:
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	$VBoxContainer/HangarButton.pressed.connect(_on_hangar)
	$VBoxContainer/LevelsButton.pressed.connect(_on_levels)
	$VBoxContainer/BeginButton.pressed.connect(_on_begin)
	$VBoxContainer/BackButton.pressed.connect(_on_back)

	_apply_styles()


func _on_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select_screen.tscn")


func _on_begin() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


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
		_on_back()
