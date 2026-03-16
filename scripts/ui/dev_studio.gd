extends Control
## Dev Studio — tabbed container for Weapon Builder, Ship Builder, Aesthetic Workshop.

var _vhs_overlay: ColorRect


func _ready() -> void:
	$BackButton.pressed.connect(_on_back)
	ThemeManager.apply_grid_background($Background)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_styles()


func _apply_styles() -> void:
	ThemeManager.apply_button_style($BackButton)

	var title: Label = $VBoxContainer/Header/Title
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		title.add_theme_font_override("font", header_font)
	ThemeManager.apply_header_chrome(title)


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
	ThemeManager.apply_grid_background($Background)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_styles()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		_on_back()
