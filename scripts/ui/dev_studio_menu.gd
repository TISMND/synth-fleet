extends Control
## Dev Studio sub-menu: Ships, Style, Components, Back.

var _vhs_overlay: ColorRect


func _ready() -> void:
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	$ButtonLayout/Columns/LeftCol/ShipsButton.pressed.connect(_on_ships)
	$ButtonLayout/Columns/LeftCol/StyleButton.pressed.connect(_on_style)
	$ButtonLayout/Columns/LeftCol/ComponentsButton.pressed.connect(_on_components)
	$ButtonLayout/Columns/LeftCol/EncountersButton.pressed.connect(_on_encounters)
	$ButtonLayout/Columns/LeftCol/LevelsButton.pressed.connect(_on_levels)
	$ButtonLayout/Columns/LeftCol/ObjectsButton.pressed.connect(_on_objects)
	$ButtonLayout/Columns/RightCol/SFXButton.pressed.connect(_on_sfx)
	$ButtonLayout/Columns/RightCol/VFXButton.pressed.connect(_on_vfx)
	$ButtonLayout/Columns/RightCol/EnvironmentsButton.pressed.connect(_on_environments)
	$ButtonLayout/Columns/RightCol/BackgroundsButton.pressed.connect(_on_backgrounds)
	$ButtonLayout/Columns/RightCol/AuditionsButton.pressed.connect(_on_auditions)
	$ButtonLayout/Columns/RightCol/SandboxButton.pressed.connect(_on_sandbox)
	$ButtonLayout/BackButton.pressed.connect(_on_back)

	_apply_styles()


func _on_ships() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ships_screen.tscn")


func _on_style() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/style_editor.tscn")


func _on_components() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/component_editor.tscn")


func _on_encounters() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/encounters_screen.tscn")


func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_editor.tscn")


func _on_objects() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/objects_screen.tscn")


func _on_sfx() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/sfx_editor.tscn")


func _on_vfx() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/vfx_editor.tscn")


func _on_environments() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/environments_screen.tscn")


func _on_backgrounds() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/bg_auditions_screen.tscn")


func _on_auditions() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/auditions_screen.tscn")


func _on_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/layout_sandbox.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _apply_styles() -> void:
	for col in $ButtonLayout/Columns.get_children():
		if col is VBoxContainer:
			for btn_node in col.get_children():
				if btn_node is Button:
					ThemeManager.apply_button_style(btn_node as Button)
	ThemeManager.apply_button_style($ButtonLayout/BackButton)


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
