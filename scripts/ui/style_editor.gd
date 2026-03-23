extends Control
## Style Editor — VHS/CRT parameter tuning.
## Other theme parameters (colors, fonts, bars, buttons) are baked via ThemeManager
## defaults and user://settings/aesthetic.json. Only VHS/CRT is editable here.

var _vhs_overlay: ColorRect
var _background: ColorRect

# Track controls for theme_changed refresh
var _float_sliders: Dictionary = {}

var _updating_from_theme := false


func _ready() -> void:
	_build_ui()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_refresh_all_from_theme()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


func _build_ui() -> void:
	# Background grid
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	ThemeManager.apply_grid_background(_background)

	# VHS overlay — CanvasLayer so it applies to everything
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	# Main layout
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# Top bar
	_build_top_bar(root_vbox)

	# VHS controls (no tab container needed — single section)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	_build_vhs_controls(vbox)


func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	var title := Label.new()
	title.text = "VHS / CRT"
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		title.add_theme_font_override("font", header_font)
	ThemeManager.apply_text_glow(title, "header")
	bar.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(_on_back)
	ThemeManager.apply_button_style(back_btn)
	bar.add_child(back_btn)


func _build_vhs_controls(vbox: VBoxContainer) -> void:
	var vhs_params: Dictionary = {
		"vhs_scanline_strength": {"min": 0.0, "max": 1.0},
		"vhs_scanline_spacing": {"min": 1.0, "max": 8.0},
		"vhs_chromatic_aberration": {"min": 0.0, "max": 5.0},
		"vhs_barrel_distortion": {"min": 0.0, "max": 0.5},
		"vhs_vignette_strength": {"min": 0.0, "max": 1.0},
		"vhs_noise_intensity": {"min": 0.0, "max": 0.5},
		"vhs_color_bleed": {"min": 0.0, "max": 5.0},
		"vhs_roll_speed": {"min": 0.0, "max": 2.0},
		"vhs_roll_strength": {"min": 0.0, "max": 0.1},
		"vhs_roll_period": {"min": 1.0, "max": 20.0},
	}
	for key in vhs_params:
		var params: Dictionary = vhs_params[key]
		var min_val: float = float(params["min"])
		var max_val: float = float(params["max"])
		_add_float_slider(vbox, key, min_val, max_val, ThemeManager.get_float(key))


# ── Slider builder ──────────────────────────────────────────

func _add_float_slider(parent: Control, key: String, min_val: float, max_val: float, current: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = key
	lbl.custom_minimum_size.x = 200
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = (max_val - min_val) / 200.0
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % current
	val_lbl.custom_minimum_size.x = 50
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	row.add_child(val_lbl)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%.2f" % val
		if not _updating_from_theme:
			ThemeManager.set_float(bound_key, val)
	)
	_float_sliders[key] = slider


# ── Events ──────────────────────────────────────────────────

func _on_back() -> void:
	ThemeManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _on_theme_changed() -> void:
	_refresh_all_from_theme()


func _refresh_all_from_theme() -> void:
	_updating_from_theme = true

	for key in _float_sliders:
		var slider: HSlider = _float_sliders[key]
		slider.value = ThemeManager.get_float(key)

	ThemeManager.apply_grid_background(_background)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	_updating_from_theme = false
