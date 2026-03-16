extends Control
## Aesthetic Studio — real-time theme editor with live preview.
## Standalone screen for auditioning colors, typography, glow/grid, and VHS/CRT effects.

var _vhs_overlay: ColorRect
var _background: ColorRect
var _preset_selector: OptionButton
var _tab_container: TabContainer
var _preview_panel: VBoxContainer

# Track controls for theme_changed refresh
var _color_pickers: Dictionary = {}
var _float_sliders: Dictionary = {}
var _int_sliders: Dictionary = {}
var _font_selectors: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _preview_labels: Array[Label] = []
var _preview_buttons: Array[Button] = []
var _preview_panels: Array[PanelContainer] = []
var _preview_bars: Array[ProgressBar] = []

# Panels & Bars: samples container (rebuilt) vs slider container (stable)
var _bp_samples_vbox: VBoxContainer
# Buttons tab: preview container (rebuilt on theme change)
var _btn_preview_container: HBoxContainer

# Typography tab inline preview labels keyed by size key
var _typo_preview_labels: Dictionary = {}

# Labels that get text glow applied
var _header_glow_labels: Array[Label] = []
var _body_glow_labels: Array[Label] = []

# Cached font list for selector sync
var _available_fonts: Array[String] = []

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

	# Split: controls left, preview right
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 450
	root_vbox.add_child(split)

	# Tab container (left)
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.custom_minimum_size.x = 400
	split.add_child(_tab_container)

	_build_colors_tab()
	_build_typography_tab()
	_build_glow_grid_tab()
	_build_buttons_tab()
	_build_vhs_tab()
	_build_panels_bars_tab()

	# Preview panel (right)
	var preview_scroll := ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(preview_scroll)

	_preview_panel = VBoxContainer.new()
	_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_panel.add_theme_constant_override("separation", 16)
	preview_scroll.add_child(_preview_panel)

	_build_preview_panel()


var _save_btn: Button
var _save_as_btn: Button
var _delete_btn: Button

func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	var title := Label.new()
	title.text = "AESTHETIC STUDIO"
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		title.add_theme_font_override("font", header_font)
	bar.add_child(title)
	_preview_labels.append(title)

	_preset_selector = OptionButton.new()
	_preset_selector.custom_minimum_size.x = 220
	_refresh_preset_list()
	_preset_selector.item_selected.connect(_on_preset_selected)
	bar.add_child(_preset_selector)

	_save_btn = Button.new()
	_save_btn.text = "SAVE"
	_save_btn.pressed.connect(_on_save_preset)
	bar.add_child(_save_btn)

	_save_as_btn = Button.new()
	_save_as_btn.text = "SAVE AS..."
	_save_as_btn.pressed.connect(_on_save_as_preset)
	bar.add_child(_save_as_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "DELETE"
	_delete_btn.pressed.connect(_on_delete_preset)
	bar.add_child(_delete_btn)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(_on_back)
	bar.add_child(back_btn)

	_update_preset_buttons()


func _build_colors_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Colors"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var color_keys: Array[String] = [
		"header", "accent", "positive", "warning", "dimmed", "disabled",
		"text", "background", "panel", "bar_positive", "bar_negative", "grid_line_color",
	]
	for key in color_keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = key
		lbl.custom_minimum_size.x = 140
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		row.add_child(lbl)

		var picker := ColorPickerButton.new()
		picker.color = ThemeManager.get_color(key)
		picker.custom_minimum_size = Vector2(60, 30)
		picker.edit_alpha = false
		var bound_key: String = key
		picker.color_changed.connect(func(c: Color) -> void: _on_color_changed(bound_key, c))
		row.add_child(picker)
		_color_pickers[key] = picker


func _build_typography_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Typography"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Font selectors
	_available_fonts = _scan_font_files()
	var font_keys: Array[String] = ["font_header", "font_body"]
	for key in font_keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = key
		lbl.custom_minimum_size.x = 120
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		row.add_child(lbl)

		var selector := OptionButton.new()
		selector.custom_minimum_size.x = 250
		var current_path: String = ThemeManager.get_font_path(key)
		for i in _available_fonts.size():
			var font_path: String = _available_fonts[i]
			var font_name: String = font_path.get_file().get_basename()
			selector.add_item(font_name, i)
			if font_path == current_path:
				selector.selected = i
		var bound_key: String = key
		var bound_fonts: Array[String] = _available_fonts
		selector.item_selected.connect(func(idx: int) -> void:
			if idx >= 0 and idx < bound_fonts.size():
				ThemeManager.set_font_path(bound_key, bound_fonts[idx])
		)
		row.add_child(selector)
		_font_selectors[key] = selector

	# Font size sliders
	var size_keys: Array[String] = ["font_size_header", "font_size_title", "font_size_section", "font_size_body"]
	for key in size_keys:
		_add_int_slider(vbox, key, 8, 40, ThemeManager.get_font_size(key))

	# Preview text
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var preview_label := Label.new()
	preview_label.text = "Font Preview"
	preview_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	vbox.add_child(preview_label)

	var size_names: Array[String] = ["Header Size", "Title Size", "Section Size", "Body Size"]
	for i in size_keys.size():
		var sample := Label.new()
		sample.text = size_names[i] + ": The quick brown fox jumps over the lazy dog"
		sample.add_theme_font_size_override("font_size", ThemeManager.get_font_size(size_keys[i]))
		sample.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		sample.autowrap_mode = TextServer.AUTOWRAP_WORD
		var font_key: String = "font_header" if i < 2 else "font_body"
		var fnt: Font = ThemeManager.get_font(font_key)
		if fnt:
			sample.add_theme_font_override("font", fnt)
		vbox.add_child(sample)
		_preview_labels.append(sample)
		_typo_preview_labels[size_keys[i]] = sample



func _build_glow_grid_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Glow"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# ── Grid Glow section ──
	var grid_header := Label.new()
	grid_header.text = "Grid Glow"
	grid_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	grid_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(grid_header)

	var grid_floats: Dictionary = {
		"grid_spacing": {"min": 16.0, "max": 256.0},
		"grid_scroll_speed": {"min": 0.0, "max": 100.0},
		"grid_line_width": {"min": 0.5, "max": 4.0},
		"grid_inner_intensity": {"min": 0.0, "max": 1.0},
		"grid_aura_size": {"min": 0.0, "max": 8.0},
		"grid_aura_intensity": {"min": 0.0, "max": 2.0},
		"grid_bloom_size": {"min": 0.0, "max": 20.0},
		"grid_bloom_intensity": {"min": 0.0, "max": 1.5},
		"grid_smudge_blur": {"min": 0.0, "max": 4.0},
	}
	for key in grid_floats:
		var params: Dictionary = grid_floats[key]
		var min_val: float = float(params["min"])
		var max_val: float = float(params["max"])
		_add_float_slider(vbox, key, min_val, max_val, ThemeManager.get_float(key))

	# ── Header Text Glow section ──
	var header_sep := HSeparator.new()
	vbox.add_child(header_sep)

	var header_glow_lbl := Label.new()
	header_glow_lbl.text = "Header Text Glow"
	header_glow_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	header_glow_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(header_glow_lbl)

	var header_glow_params: Dictionary = {
		"header_inner_intensity": {"min": 0.0, "max": 1.0},
		"header_aura_size": {"min": 0.0, "max": 8.0},
		"header_aura_intensity": {"min": 0.0, "max": 2.0},
		"header_bloom_size": {"min": 0.0, "max": 20.0},
		"header_bloom_intensity": {"min": 0.0, "max": 1.5},
		"header_smudge_blur": {"min": 0.0, "max": 4.0},
	}
	for key in header_glow_params:
		var params: Dictionary = header_glow_params[key]
		var min_val: float = float(params["min"])
		var max_val: float = float(params["max"])
		_add_float_slider(vbox, key, min_val, max_val, ThemeManager.get_float(key))

	# ── Body Text Glow section ──
	var body_sep := HSeparator.new()
	vbox.add_child(body_sep)

	var body_glow_lbl := Label.new()
	body_glow_lbl.text = "Body Text Glow"
	body_glow_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	body_glow_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(body_glow_lbl)

	var body_glow_params: Dictionary = {
		"body_inner_intensity": {"min": 0.0, "max": 1.0},
		"body_aura_size": {"min": 0.0, "max": 8.0},
		"body_aura_intensity": {"min": 0.0, "max": 2.0},
		"body_bloom_size": {"min": 0.0, "max": 20.0},
		"body_bloom_intensity": {"min": 0.0, "max": 1.5},
		"body_smudge_blur": {"min": 0.0, "max": 4.0},
	}
	for key in body_glow_params:
		var params: Dictionary = body_glow_params[key]
		var min_val: float = float(params["min"])
		var max_val: float = float(params["max"])
		_add_float_slider(vbox, key, min_val, max_val, ThemeManager.get_float(key))


func _build_vhs_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "VHS / CRT"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

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


func _build_buttons_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Buttons"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)

	# ── Style presets (audition buttons) ──
	var presets_header := Label.new()
	presets_header.text = "Button Style Presets"
	presets_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	presets_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(presets_header)

	var presets_row := HBoxContainer.new()
	presets_row.add_theme_constant_override("separation", 6)
	root.add_child(presets_row)

	var style_names: Array[String] = []
	for key in ThemeManager.BUTTON_STYLE_PRESETS:
		style_names.append(str(key))
	style_names.sort()

	for style_name in style_names:
		var style_btn := Button.new()
		style_btn.text = style_name
		style_btn.custom_minimum_size = Vector2(0, 32)
		style_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bound_name: String = style_name
		style_btn.pressed.connect(func() -> void:
			ThemeManager.apply_button_style_preset(bound_name)
		)
		presets_row.add_child(style_btn)

	# ── Live preview ──
	var preview_sep := HSeparator.new()
	root.add_child(preview_sep)

	var preview_header := Label.new()
	preview_header.text = "Preview"
	preview_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	preview_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(preview_header)

	_btn_preview_container = HBoxContainer.new()
	_btn_preview_container.add_theme_constant_override("separation", 10)
	root.add_child(_btn_preview_container)
	_populate_btn_preview()

	# ── Sliders ──
	var slider_sep := HSeparator.new()
	root.add_child(slider_sep)

	var slider_header := Label.new()
	slider_header.text = "Fine Tuning"
	slider_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	slider_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(slider_header)

	var btn_params: Dictionary = {
		"btn_border_width": {"min": 0.0, "max": 4.0},
		"btn_corner_radius": {"min": 0.0, "max": 20.0},
		"btn_border_alpha": {"min": 0.0, "max": 1.0},
		"btn_bg_alpha": {"min": 0.0, "max": 0.6},
		"btn_hover_brighten": {"min": 0.0, "max": 0.5},
		"btn_pressed_darken": {"min": 0.0, "max": 0.4},
		"btn_shadow_size": {"min": 0.0, "max": 12.0},
		"btn_shadow_alpha": {"min": 0.0, "max": 1.0},
	}
	for key in btn_params:
		var params: Dictionary = btn_params[key]
		var min_val: float = float(params["min"])
		var max_val: float = float(params["max"])
		_add_float_slider(root, key, min_val, max_val, ThemeManager.get_float(key))


func _build_panels_bars_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Panels & Bars"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	# Samples container (rebuilt on theme change)
	_bp_samples_vbox = VBoxContainer.new()
	_bp_samples_vbox.add_theme_constant_override("separation", 12)
	root.add_child(_bp_samples_vbox)
	_populate_bp_samples(_bp_samples_vbox)

	# ── LED Bars sliders (stable, never rebuilt) ──
	var led_sep := HSeparator.new()
	root.add_child(led_sep)

	var led_header := Label.new()
	led_header.text = "LED Bars"
	led_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	led_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(led_header)

	_add_toggle(root, "led_bar_enabled", "LED Bars Enabled", ThemeManager.get_float("led_bar_enabled"))
	_add_float_slider(root, "led_segment_count", 4.0, 40.0, ThemeManager.get_float("led_segment_count"))
	_add_float_slider(root, "led_segment_gap", 0.005, 0.04, ThemeManager.get_float("led_segment_gap"))
	_add_float_slider(root, "led_inner_intensity", 0.0, 1.0, ThemeManager.get_float("led_inner_intensity"))
	_add_float_slider(root, "led_aura_size", 0.0, 0.06, ThemeManager.get_float("led_aura_size"))
	_add_float_slider(root, "led_aura_intensity", 0.0, 2.0, ThemeManager.get_float("led_aura_intensity"))
	_add_float_slider(root, "led_bloom_size", 0.0, 0.15, ThemeManager.get_float("led_bloom_size"))
	_add_float_slider(root, "led_bloom_intensity", 0.0, 1.5, ThemeManager.get_float("led_bloom_intensity"))
	_add_float_slider(root, "led_smudge_blur", 0.0, 0.03, ThemeManager.get_float("led_smudge_blur"))


func _populate_btn_preview() -> void:
	var btn_names: Array[String] = ["PLAY", "HANGAR", "WEAPONS", "DISABLED"]
	for i in btn_names.size():
		var btn := Button.new()
		btn.text = btn_names[i]
		btn.custom_minimum_size = Vector2(110, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 3:
			btn.disabled = true
		ThemeManager.apply_button_style(btn)
		_btn_preview_container.add_child(btn)
		_preview_buttons.append(btn)


func _populate_bp_samples(vbox: VBoxContainer) -> void:
	# Sample panel
	var panel_lbl := Label.new()
	panel_lbl.text = "Sample Panel"
	panel_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	panel_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(panel_lbl)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeManager.get_color("panel")
	panel_style.border_color = ThemeManager.get_color("accent")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	vbox.add_child(panel)
	_preview_panels.append(panel)

	var panel_text := Label.new()
	panel_text.text = "This is a sample panel with themed colors.\nUseful for seeing how panels look with the current theme."
	panel_text.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(panel_text)
	_preview_labels.append(panel_text)

	# Progress bars
	var bars_lbl := Label.new()
	bars_lbl.text = "Sample Bars"
	bars_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	bars_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(bars_lbl)

	var bar_data: Array[Dictionary] = [
		{"name": "Shield (75%)", "value": 75.0, "color_key": "bar_positive"},
		{"name": "Hull (40%)", "value": 40.0, "color_key": "warning"},
	]
	for bd in bar_data:
		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", 8)
		vbox.add_child(bar_row)

		var bar_label := Label.new()
		bar_label.text = str(bd["name"])
		bar_label.custom_minimum_size.x = 100
		bar_label.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		bar_row.add_child(bar_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(200, 20)
		bar.max_value = 100.0
		var bar_value: float = float(bd["value"])
		bar.value = bar_value
		bar.show_percentage = false
		var color_key: String = str(bd["color_key"])
		var fill_col: Color = ThemeManager.get_color(color_key)
		ThemeManager.apply_led_bar(bar, fill_col, bar_value / 100.0)
		bar_row.add_child(bar)
		_preview_bars.append(bar)


func _build_preview_panel() -> void:
	# Mock menu
	var menu_section := _make_section_label("Menu Preview")
	_preview_panel.add_child(menu_section)

	var menu_panel := PanelContainer.new()
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = ThemeManager.get_color("panel")
	menu_style.border_color = ThemeManager.get_color("accent")
	menu_style.set_border_width_all(1)
	menu_style.set_corner_radius_all(4)
	menu_style.set_content_margin_all(16)
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	_preview_panel.add_child(menu_panel)
	_preview_panels.append(menu_panel)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu_vbox)

	var menu_title := Label.new()
	menu_title.text = "SYNTH FLEET"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	menu_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		menu_title.add_theme_font_override("font", header_font)
	menu_vbox.add_child(menu_title)
	_preview_labels.append(menu_title)
	_header_glow_labels.append(menu_title)
	ThemeManager.apply_text_glow(menu_title, "header")

	for btn_text in ["PLAY", "HANGAR", "AESTHETIC STUDIO"]:
		var btn := Button.new()
		btn.text = btn_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeManager.apply_button_style(btn)
		menu_vbox.add_child(btn)
		_preview_buttons.append(btn)

	# Mini HUD
	var hud_section := _make_section_label("HUD Preview")
	_preview_panel.add_child(hud_section)

	var hud_panel := PanelContainer.new()
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(ThemeManager.get_color("background"), 0.8)
	hud_style.border_color = ThemeManager.get_color("dimmed")
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(2)
	hud_style.set_content_margin_all(8)
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	_preview_panel.add_child(hud_panel)
	_preview_panels.append(hud_panel)

	var hud_vbox := VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 4)
	hud_panel.add_child(hud_vbox)

	# Shield bar
	var shield_row := HBoxContainer.new()
	shield_row.add_theme_constant_override("separation", 6)
	hud_vbox.add_child(shield_row)

	var shield_lbl := Label.new()
	shield_lbl.text = "SHD"
	shield_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	shield_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	shield_row.add_child(shield_lbl)
	_preview_labels.append(shield_lbl)
	_body_glow_labels.append(shield_lbl)
	ThemeManager.apply_text_glow(shield_lbl, "body")

	var shield_bar := ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(150, 14)
	shield_bar.max_value = 100.0
	shield_bar.value = 80.0
	shield_bar.show_percentage = false
	ThemeManager.apply_led_bar(shield_bar, ThemeManager.get_color("bar_positive"), 0.8)
	shield_row.add_child(shield_bar)
	_preview_bars.append(shield_bar)

	# Hull bar
	var hull_row := HBoxContainer.new()
	hull_row.add_theme_constant_override("separation", 6)
	hud_vbox.add_child(hull_row)

	var hull_lbl := Label.new()
	hull_lbl.text = "HUL"
	hull_lbl.add_theme_color_override("font_color", ThemeManager.get_color("warning"))
	hull_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	hull_row.add_child(hull_lbl)
	_preview_labels.append(hull_lbl)
	_body_glow_labels.append(hull_lbl)
	ThemeManager.apply_text_glow(hull_lbl, "body")

	var hull_bar := ProgressBar.new()
	hull_bar.custom_minimum_size = Vector2(150, 14)
	hull_bar.max_value = 100.0
	hull_bar.value = 45.0
	hull_bar.show_percentage = false
	ThemeManager.apply_led_bar(hull_bar, ThemeManager.get_color("warning"), 0.45)
	hull_row.add_child(hull_bar)
	_preview_bars.append(hull_bar)

	# Weapon slots
	var wep_row := HBoxContainer.new()
	wep_row.add_theme_constant_override("separation", 4)
	hud_vbox.add_child(wep_row)

	var slot_colors: Array[String] = ["accent", "header", "positive", "warning"]
	var slot_states: Array[String] = ["ON", "ON", "OFF", "ON"]
	for i in 4:
		var slot := Label.new()
		var color_key: String = slot_colors[i]
		var state: String = slot_states[i]
		slot.text = "[" + str(i + 1) + ":" + state + "]"
		if state == "OFF":
			slot.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
		else:
			slot.add_theme_color_override("font_color", ThemeManager.get_color(color_key))
		slot.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		wep_row.add_child(slot)
		_preview_labels.append(slot)
		_body_glow_labels.append(slot)
		ThemeManager.apply_text_glow(slot, "body")

	# Text samples
	var text_section := _make_section_label("Typography Samples")
	_preview_panel.add_child(text_section)

	var text_panel := PanelContainer.new()
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = ThemeManager.get_color("panel")
	text_style.set_border_width_all(1)
	text_style.border_color = ThemeManager.get_color("dimmed")
	text_style.set_corner_radius_all(4)
	text_style.set_content_margin_all(12)
	text_panel.add_theme_stylebox_override("panel", text_style)
	_preview_panel.add_child(text_panel)
	_preview_panels.append(text_panel)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 6)
	text_panel.add_child(text_vbox)

	var samples: Array[Dictionary] = [
		{"text": "Header Text Sample", "size_key": "font_size_header", "color_key": "header", "font_key": "font_header", "is_header": true},
		{"text": "Title Text Sample", "size_key": "font_size_title", "color_key": "accent", "font_key": "font_header", "is_header": true},
		{"text": "Section heading", "size_key": "font_size_section", "color_key": "text", "font_key": "font_body", "is_header": false},
		{"text": "Body text — The fleet approaches the orbital station. Weapons systems online. All loops synchronized.", "size_key": "font_size_body", "color_key": "text", "font_key": "font_body", "is_header": false},
	]
	for s in samples:
		var sample := Label.new()
		sample.text = str(s["text"])
		sample.add_theme_font_size_override("font_size", ThemeManager.get_font_size(str(s["size_key"])))
		sample.add_theme_color_override("font_color", ThemeManager.get_color(str(s["color_key"])))
		sample.autowrap_mode = TextServer.AUTOWRAP_WORD
		var font_key: String = str(s["font_key"])
		var fnt: Font = ThemeManager.get_font(font_key)
		if fnt:
			sample.add_theme_font_override("font", fnt)
		text_vbox.add_child(sample)
		_preview_labels.append(sample)
		var is_header: bool = bool(s["is_header"])
		if is_header:
			_header_glow_labels.append(sample)
			ThemeManager.apply_text_glow(sample, "header")
		else:
			_body_glow_labels.append(sample)
			ThemeManager.apply_text_glow(sample, "body")


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		lbl.add_theme_font_override("font", header_font)
	_preview_labels.append(lbl)
	return lbl


# ── Slider builders ──────────────────────────────────────────

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


func _add_int_slider(parent: Control, key: String, min_val: int, max_val: int, current: int) -> void:
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
	slider.step = 1
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = str(current)
	val_lbl.custom_minimum_size.x = 50
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	row.add_child(val_lbl)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = str(int(val))
		if not _updating_from_theme:
			ThemeManager.set_font_size(bound_key, int(val))
	)
	_int_sliders[key] = slider


func _add_toggle(parent: Control, key: String, label_text: String, current: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 200
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	row.add_child(lbl)

	var toggle := CheckButton.new()
	toggle.button_pressed = current > 0.5
	row.add_child(toggle)

	var bound_key: String = key
	toggle.toggled.connect(func(pressed: bool) -> void:
		if not _updating_from_theme:
			ThemeManager.set_float(bound_key, 1.0 if pressed else 0.0)
	)
	_toggle_buttons[key] = toggle


# ── Font scanning ────────────────────────────────────────────

func _scan_font_files() -> Array[String]:
	var fonts: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://assets/fonts")
	if not dir:
		return fonts
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower: String = file_name.to_lower()
			if lower.ends_with(".ttf") or lower.ends_with(".otf"):
				fonts.append("res://assets/fonts/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	fonts.sort()
	return fonts


# ── Callbacks ────────────────────────────────────────────────

func _on_color_changed(key: String, color: Color) -> void:
	if _updating_from_theme:
		return
	ThemeManager.set_color(key, color)


func _on_preset_selected(idx: int) -> void:
	var preset_name: String = _preset_selector.get_item_text(idx)
	# Strip " *" modified indicator if present
	if preset_name.ends_with(" *"):
		preset_name = preset_name.substr(0, preset_name.length() - 2)
	ThemeManager.apply_preset(preset_name)


func _on_save_preset() -> void:
	var active: String = ThemeManager.get_active_preset()
	if active == "" or ThemeManager.is_builtin_preset(active):
		# No active custom preset — redirect to Save As
		_on_save_as_preset()
		return
	ThemeManager.save_custom_preset(active)
	_refresh_preset_list()
	_update_preset_buttons()


func _on_save_as_preset() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Save Preset As"
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Preset name..."
	line_edit.custom_minimum_size.x = 250
	var active: String = ThemeManager.get_active_preset()
	if active != "" and not ThemeManager.is_builtin_preset(active):
		line_edit.text = active
	dialog.add_child(line_edit)
	dialog.confirmed.connect(func() -> void:
		var preset_name: String = line_edit.text.strip_edges()
		if preset_name != "" and not ThemeManager.is_builtin_preset(preset_name):
			ThemeManager.save_custom_preset(preset_name)
			_refresh_preset_list()
			_update_preset_buttons()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()


func _on_delete_preset() -> void:
	var active: String = ThemeManager.get_active_preset()
	if active == "" or ThemeManager.is_builtin_preset(active):
		return
	ThemeManager.delete_custom_preset(active)
	_refresh_preset_list()
	_update_preset_buttons()


func _on_back() -> void:
	ThemeManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_theme_changed() -> void:
	_refresh_all_from_theme()


func _refresh_all_from_theme() -> void:
	_updating_from_theme = true

	# Update color pickers
	for key in _color_pickers:
		var picker: ColorPickerButton = _color_pickers[key]
		picker.color = ThemeManager.get_color(key)

	# Update float sliders
	for key in _float_sliders:
		var slider: HSlider = _float_sliders[key]
		slider.value = ThemeManager.get_float(key)

	# Update toggle buttons
	for key in _toggle_buttons:
		var toggle: CheckButton = _toggle_buttons[key]
		toggle.button_pressed = ThemeManager.get_float(key) > 0.5

	# Update int sliders
	for key in _int_sliders:
		var slider: HSlider = _int_sliders[key]
		slider.value = ThemeManager.get_font_size(key)

	# Sync font selector dropdowns
	for key in _font_selectors:
		var selector: OptionButton = _font_selectors[key]
		var current_path: String = ThemeManager.get_font_path(key)
		for i in _available_fonts.size():
			if _available_fonts[i] == current_path:
				selector.selected = i
				break

	# Update typography tab inline preview labels
	for size_key in _typo_preview_labels:
		var lbl: Label = _typo_preview_labels[size_key]
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size(size_key))
			lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
			var font_key: String = "font_header" if size_key in ["font_size_header", "font_size_title"] else "font_body"
			var fnt: Font = ThemeManager.get_font(font_key)
			if fnt:
				lbl.add_theme_font_override("font", fnt)

	# Update grid background
	ThemeManager.apply_grid_background(_background)

	# Update VHS overlay
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	# Refresh preset list and button states
	_refresh_preset_list()
	_update_preset_buttons()

	_updating_from_theme = false

	# Rebuild preview panel and buttons/panels content (deferred, after sliders done)
	_rebuild_preview_and_buttons.call_deferred()


func _rebuild_preview_and_buttons() -> void:
	# Clear tracked arrays
	_preview_labels.clear()
	_preview_buttons.clear()
	_preview_panels.clear()
	_preview_bars.clear()
	_header_glow_labels.clear()
	_body_glow_labels.clear()

	# Clear preview panel children
	for child in _preview_panel.get_children():
		child.queue_free()

	# Clear buttons/panels sample content (not the LED sliders)
	for child in _bp_samples_vbox.get_children():
		child.queue_free()

	# Clear button preview
	for child in _btn_preview_container.get_children():
		child.queue_free()

	# Use call_deferred so queue_free completes first
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_build_preview_panel()
	_populate_bp_samples(_bp_samples_vbox)
	_populate_btn_preview()


func _refresh_preset_list() -> void:
	var names: Array[String] = ThemeManager.list_preset_names()
	var active: String = ThemeManager.get_active_preset()
	var dirty: bool = ThemeManager.is_preset_dirty()
	_preset_selector.clear()
	var selected_idx: int = -1
	for i in names.size():
		var display: String = names[i]
		if names[i] == active and dirty:
			display = names[i] + " *"
		_preset_selector.add_item(display)
		if names[i] == active:
			selected_idx = i
	if active == "" or selected_idx < 0:
		# No active preset — add an "Unsaved" entry at the top
		_preset_selector.add_item("(unsaved)")
		selected_idx = _preset_selector.item_count - 1
	_preset_selector.selected = selected_idx


func _update_preset_buttons() -> void:
	var active: String = ThemeManager.get_active_preset()
	var is_custom: bool = active != "" and not ThemeManager.is_builtin_preset(active)
	# SAVE: enabled when a custom preset is active and dirty
	_save_btn.disabled = not is_custom or not ThemeManager.is_preset_dirty()
	# DELETE: enabled only for custom presets
	_delete_btn.disabled = not is_custom
