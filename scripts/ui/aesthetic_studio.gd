extends Control
## Aesthetic Studio — real-time theme editor with live preview.
## Standalone screen for auditioning colors, typography, glow/grid, and VHS/CRT effects.

var _vhs_overlay: ColorRect
var _background: ColorRect
var _preset_selector: OptionButton
var _tab_container: TabContainer
var _hud_tab_vbox: VBoxContainer

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

# Panels tab: samples container (rebuilt)
var _panels_samples_vbox: VBoxContainer
# HUD tab: supercharged preview bar (special refresh)
var _supercharged_preview_bar: ProgressBar
# Buttons tab: preview container (rebuilt on theme change)
var _btn_preview_container: HBoxContainer
# Per-state preview buttons in buttons tab (rebuilt on theme change)
var _btn_state_containers: Array[HBoxContainer] = []

# Typography tab inline preview labels keyed by size key
var _typo_preview_labels: Dictionary = {}

# Labels that get text glow applied
var _header_glow_labels: Array[Label] = []
var _body_glow_labels: Array[Label] = []

# Header style mode selector
var _header_mode_selector: OptionButton
var _chrome_controls_box: VBoxContainer

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

	# Tab container (full width)
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_tab_container)

	_build_typography_tab()
	_build_grid_tab()
	_build_buttons_tab()
	_build_vhs_tab()
	_build_panels_tab()
	_build_bars_tab()
	_build_hud_tab()


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


# ── Reusable color picker row helper ─────────────────────────

func _add_color_picker_row(parent: Control, color_key: String, display_label: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = display_label if display_label != "" else color_key
	lbl.custom_minimum_size.x = 140
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	row.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.color = ThemeManager.get_color(color_key)
	picker.custom_minimum_size = Vector2(60, 30)
	picker.edit_alpha = false
	var bound_key: String = color_key
	picker.color_changed.connect(func(c: Color) -> void: _on_color_changed(bound_key, c))
	row.add_child(picker)
	_color_pickers[color_key] = picker


func _build_typography_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Typography"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# ── Text color pickers ──
	var colors_header := Label.new()
	colors_header.text = "Text Colors"
	colors_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	colors_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(colors_header)

	_add_color_picker_row(vbox, "header", "Header")
	_add_color_picker_row(vbox, "text", "Body Text")
	_add_color_picker_row(vbox, "dimmed", "Dimmed")
	_add_color_picker_row(vbox, "disabled", "Disabled")

	var sep0 := HSeparator.new()
	vbox.add_child(sep0)

	# Font selectors
	_available_fonts = _scan_font_files()
	var font_keys: Array[String] = ["font_header", "font_body", "font_button"]
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

	# ── Header Style section (mode selector: Neon Glow / Chrome Metal) ──
	var header_sep := HSeparator.new()
	vbox.add_child(header_sep)

	var header_style_lbl := Label.new()
	header_style_lbl.text = "Header Style"
	header_style_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	header_style_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(header_style_lbl)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mode_row)

	var mode_lbl := Label.new()
	mode_lbl.text = "Mode"
	mode_lbl.custom_minimum_size.x = 200
	mode_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	mode_row.add_child(mode_lbl)

	_header_mode_selector = OptionButton.new()
	_header_mode_selector.add_item("Neon Glow")
	_header_mode_selector.add_item("Chrome Metal")
	_header_mode_selector.selected = 1 if ThemeManager.get_float("header_chrome_enabled") > 0.5 else 0
	_header_mode_selector.item_selected.connect(_on_header_mode_selected)
	mode_row.add_child(_header_mode_selector)

	# ── Chrome Metal controls (only visible in Chrome mode) ──
	_chrome_controls_box = VBoxContainer.new()
	_chrome_controls_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_chrome_controls_box)

	# Chrome tint color picker
	var tint_row := HBoxContainer.new()
	tint_row.add_theme_constant_override("separation", 8)
	_chrome_controls_box.add_child(tint_row)

	var tint_lbl := Label.new()
	tint_lbl.text = "chrome_tint"
	tint_lbl.custom_minimum_size.x = 200
	tint_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	tint_row.add_child(tint_lbl)

	var tint_picker := ColorPickerButton.new()
	tint_picker.color = ThemeManager.get_color("chrome_tint")
	tint_picker.custom_minimum_size = Vector2(60, 30)
	tint_picker.edit_alpha = false
	tint_picker.color_changed.connect(func(c: Color) -> void: _on_color_changed("chrome_tint", c))
	tint_row.add_child(tint_picker)
	_color_pickers["chrome_tint"] = tint_picker

	var chrome_float_params: Dictionary = {
		"header_chrome_highlight_pos": {"min": 0.0, "max": 1.0},
		"header_chrome_highlight_width": {"min": 0.01, "max": 0.5},
		"header_chrome_highlight_intensity": {"min": 0.5, "max": 3.0},
		"header_chrome_secondary_pos": {"min": 0.0, "max": 1.0},
		"header_chrome_secondary_intensity": {"min": 0.0, "max": 1.5},
		"header_chrome_base_brightness": {"min": 0.0, "max": 1.0},
		"header_chrome_top_brightness": {"min": 0.0, "max": 1.0},
	}
	for key in chrome_float_params:
		var params: Dictionary = chrome_float_params[key]
		var min_val: float = float(params["min"])
		var max_val: float = float(params["max"])
		_add_float_slider(_chrome_controls_box, key, min_val, max_val, ThemeManager.get_float(key))

	# ── Header Glow sliders (always visible — applies to both neon and chrome) ──
	var glow_sub_header := Label.new()
	glow_sub_header.text = "Header Glow"
	glow_sub_header.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	vbox.add_child(glow_sub_header)

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

	_update_header_mode_visibility()

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


func _build_grid_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Grid"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# ── Grid color pickers ──
	var grid_colors_header := Label.new()
	grid_colors_header.text = "Grid Colors"
	grid_colors_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	grid_colors_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	vbox.add_child(grid_colors_header)

	_add_color_picker_row(vbox, "grid_line_color", "Grid Lines")
	_add_color_picker_row(vbox, "background", "Background")

	var color_sep := HSeparator.new()
	vbox.add_child(color_sep)

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
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	# ── Interactive Preview ──
	var interact_lbl := Label.new()
	interact_lbl.text = "Interactive Preview"
	interact_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	interact_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(interact_lbl)

	_btn_preview_container = HBoxContainer.new()
	_btn_preview_container.add_theme_constant_override("separation", 10)
	root.add_child(_btn_preview_container)
	_populate_btn_preview()

	root.add_child(HSeparator.new())

	# ── Button Colors ──
	var colors_header := Label.new()
	colors_header.text = "Colors"
	colors_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	colors_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(colors_header)

	_add_color_picker_row(root, "accent", "Accent")
	_add_toggle(root, "btn_use_chrome", "Use Chrome Tint", ThemeManager.get_float("btn_use_chrome"))

	root.add_child(HSeparator.new())

	# ── Global Shape ──
	_add_section_header(root, "Shape")
	_add_compact_float(root, "border_width", "btn_border_width", 0.0, 4.0)
	_add_compact_float(root, "corner_radius", "btn_corner_radius", 0.0, 20.0)
	_add_toggle(root, "btn_border_bottom_only", "Bottom Border Only", ThemeManager.get_float("btn_border_bottom_only"))
	_add_compact_int(root, "font_size", "font_size_button", 8, 24)

	root.add_child(HSeparator.new())

	# ── Per-State Sections ──
	var state_defs: Array[Dictionary] = [
		{"label": "Normal", "prefix": "btn_normal", "lock": ""},
		{"label": "Hover", "prefix": "btn_hover", "lock": "hover"},
		{"label": "Pressed", "prefix": "btn_pressed", "lock": "pressed"},
		{"label": "Disabled", "prefix": "btn_disabled", "lock": "disabled"},
	]
	for def in state_defs:
		var state_label: String = str(def["label"])
		var prefix: String = str(def["prefix"])
		var lock: String = str(def["lock"])
		_build_btn_state_section(root, state_label, prefix, lock)
		root.add_child(HSeparator.new())


func _build_panels_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Panels"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	# Panel color picker
	_add_color_picker_row(root, "panel", "Panel Color")

	var sep := HSeparator.new()
	root.add_child(sep)

	# Samples container (rebuilt on theme change)
	_panels_samples_vbox = VBoxContainer.new()
	_panels_samples_vbox.add_theme_constant_override("separation", 12)
	root.add_child(_panels_samples_vbox)
	_populate_panels_samples(_panels_samples_vbox)


func _build_bars_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Bars"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)

	# ── HUD Bar Colors (4-column grid) ──
	var hud_header := Label.new()
	hud_header.text = "HUD Bar Colors"
	hud_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	hud_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(hud_header)

	var hud_grid := GridContainer.new()
	hud_grid.columns = 4
	hud_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_grid.add_theme_constant_override("h_separation", 12)
	hud_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(hud_grid)

	var hud_specs: Array = [
		{"key": "bar_shield", "label": "SHIELD", "preview_val": 85.0, "segments": 10},
		{"key": "bar_hull", "label": "HULL", "preview_val": 60.0, "segments": 8},
		{"key": "bar_thermal", "label": "THERMAL", "preview_val": 30.0, "segments": 6},
		{"key": "bar_electric", "label": "ELECTRIC", "preview_val": 70.0, "segments": 8},
	]
	for spec in hud_specs:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		hud_grid.add_child(col)

		var lbl := Label.new()
		lbl.text = spec["label"]
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		col.add_child(lbl)

		var seg_count: int = int(spec.get("segments", 8))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.max_value = 100.0
		bar.value = float(spec["preview_val"])
		bar.show_percentage = false
		var color_key: String = str(spec["key"])
		var bar_color: Color = ThemeManager.get_color(color_key)
		ThemeManager.apply_led_bar(bar, bar_color, float(spec["preview_val"]) / 100.0, seg_count)
		col.add_child(bar)
		_preview_bars.append(bar)

		var picker := ColorPickerButton.new()
		picker.color = ThemeManager.get_color(color_key)
		picker.custom_minimum_size = Vector2(40, 26)
		picker.edit_alpha = false
		var bound_key: String = color_key
		picker.color_changed.connect(func(c: Color) -> void: _on_color_changed(bound_key, c))
		col.add_child(picker)
		_color_pickers[color_key] = picker

	var sep1 := HSeparator.new()
	root.add_child(sep1)

	# ── Color Bar States (2-column grid: Warning + Disabled) ──
	var states_header := Label.new()
	states_header.text = "Color Bar States"
	states_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	states_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(states_header)

	var states_grid := GridContainer.new()
	states_grid.columns = 2
	states_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	states_grid.add_theme_constant_override("h_separation", 12)
	states_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(states_grid)

	var state_specs: Array = [
		{"key": "bar_warning", "label": "WARNING"},
		{"key": "bar_disabled", "label": "DISABLED"},
	]
	for spec in state_specs:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		states_grid.add_child(col)

		var lbl := Label.new()
		lbl.text = spec["label"]
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		col.add_child(lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.max_value = 100.0
		bar.value = 75.0
		bar.show_percentage = false
		var color_key: String = str(spec["key"])
		var bar_color: Color = ThemeManager.get_color(color_key)
		ThemeManager.apply_led_bar(bar, bar_color, 0.75, 8)
		col.add_child(bar)
		_preview_bars.append(bar)

		var picker := ColorPickerButton.new()
		picker.color = ThemeManager.get_color(color_key)
		picker.custom_minimum_size = Vector2(40, 26)
		picker.edit_alpha = false
		var bound_key: String = color_key
		picker.color_changed.connect(func(c: Color) -> void: _on_color_changed(bound_key, c))
		col.add_child(picker)
		_color_pickers[color_key] = picker

	var sep2 := HSeparator.new()
	root.add_child(sep2)

	# ── Supercharged (own section with animated bar + controls) ──
	var sc_header := Label.new()
	sc_header.text = "Supercharged"
	sc_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	sc_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(sc_header)

	# Full-width animated preview bar
	_supercharged_preview_bar = ProgressBar.new()
	_supercharged_preview_bar.custom_minimum_size = Vector2(0, 22)
	_supercharged_preview_bar.max_value = 100.0
	_supercharged_preview_bar.value = 85.0
	_supercharged_preview_bar.show_percentage = false
	ThemeManager.apply_supercharged_bar(_supercharged_preview_bar, ThemeManager.get_color("bar_supercharged"), 0.85, 12)
	root.add_child(_supercharged_preview_bar)

	# Controls row: color picker + float sliders
	var sc_controls := HBoxContainer.new()
	sc_controls.add_theme_constant_override("separation", 16)
	sc_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(sc_controls)

	# Color picker
	var sc_color_box := VBoxContainer.new()
	sc_color_box.add_theme_constant_override("separation", 2)
	sc_controls.add_child(sc_color_box)
	var sc_color_lbl := Label.new()
	sc_color_lbl.text = "Color"
	sc_color_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	sc_color_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	sc_color_box.add_child(sc_color_lbl)
	var sc_picker := ColorPickerButton.new()
	sc_picker.color = ThemeManager.get_color("bar_supercharged")
	sc_picker.custom_minimum_size = Vector2(40, 26)
	sc_picker.edit_alpha = false
	sc_picker.color_changed.connect(func(c: Color) -> void: _on_color_changed("bar_supercharged", c))
	sc_color_box.add_child(sc_picker)
	_color_pickers["bar_supercharged"] = sc_picker

	# Slider helper — adds a labeled slider inline in an HBox
	var sc_slider_specs: Array = [
		{"key": "supercharged_speed", "label": "Speed", "min": 0.1, "max": 5.0},
		{"key": "supercharged_intensity", "label": "Intensity", "min": 0.0, "max": 2.0},
		{"key": "supercharged_distortion", "label": "Distortion", "min": 0.0, "max": 0.5},
	]
	for sspec in sc_slider_specs:
		var slider_box := VBoxContainer.new()
		slider_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider_box.add_theme_constant_override("separation", 2)
		sc_controls.add_child(slider_box)

		var s_lbl := Label.new()
		s_lbl.text = sspec["label"]
		s_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		s_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		slider_box.add_child(s_lbl)

		var s_key: String = str(sspec["key"])
		var s_min: float = float(sspec["min"])
		var s_max: float = float(sspec["max"])
		var slider := HSlider.new()
		slider.min_value = s_min
		slider.max_value = s_max
		slider.step = (s_max - s_min) / 200.0
		slider.value = ThemeManager.get_float(s_key)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 60
		var bound_float_key: String = s_key
		slider.value_changed.connect(func(val: float) -> void:
			if not _updating_from_theme:
				ThemeManager.set_float(bound_float_key, val)
		)
		slider_box.add_child(slider)
		_float_sliders[s_key] = slider

	# ── Segment Shape ──
	var seg_sep := HSeparator.new()
	root.add_child(seg_sep)

	var seg_header := Label.new()
	seg_header.text = "Segment Shape"
	seg_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	seg_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	root.add_child(seg_header)

	_add_float_slider(root, "led_segment_width_px", 4.0, 20.0, ThemeManager.get_float("led_segment_width_px"))
	_add_float_slider(root, "led_segment_gap_px", 0.0, 20.0, ThemeManager.get_float("led_segment_gap_px"))

	# ── Inner Glow ──
	var inner_header := Label.new()
	inner_header.text = "Inner Glow"
	inner_header.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	root.add_child(inner_header)

	_add_float_slider(root, "led_inner_intensity", 0.0, 2.0, ThemeManager.get_float("led_inner_intensity"))
	_add_float_slider(root, "led_inner_softness", 0.1, 3.0, ThemeManager.get_float("led_inner_softness"))

	# ── Aura ──
	var aura_header := Label.new()
	aura_header.text = "Aura"
	aura_header.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	root.add_child(aura_header)

	_add_float_slider(root, "led_aura_size", 0.0, 0.15, ThemeManager.get_float("led_aura_size"))
	_add_float_slider(root, "led_aura_intensity", 0.0, 3.0, ThemeManager.get_float("led_aura_intensity"))
	_add_float_slider(root, "led_aura_falloff", 0.1, 4.0, ThemeManager.get_float("led_aura_falloff"))

	# ── Bloom ──
	var bloom_header := Label.new()
	bloom_header.text = "Bloom"
	bloom_header.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	root.add_child(bloom_header)

	_add_float_slider(root, "led_bloom_size", 0.0, 0.3, ThemeManager.get_float("led_bloom_size"))
	_add_float_slider(root, "led_bloom_intensity", 0.0, 2.0, ThemeManager.get_float("led_bloom_intensity"))
	_add_float_slider(root, "led_bloom_falloff", 0.1, 4.0, ThemeManager.get_float("led_bloom_falloff"))

	# ── Smudge ──
	var smudge_header := Label.new()
	smudge_header.text = "Smudge"
	smudge_header.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	root.add_child(smudge_header)

	_add_float_slider(root, "led_smudge_blur", 0.0, 0.03, ThemeManager.get_float("led_smudge_blur"))


func _build_hud_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "HUD"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	_hud_tab_vbox = VBoxContainer.new()
	_hud_tab_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_tab_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(_hud_tab_vbox)

	_build_hud_tab_content(_hud_tab_vbox)


func _populate_btn_preview() -> void:
	# Single interactive button at top — natural text width
	var btn := Button.new()
	btn.text = "INTERACTIVE"
	btn.custom_minimum_size = Vector2(140, 38)
	ThemeManager.apply_button_style(btn)
	_btn_preview_container.add_child(btn)
	_preview_buttons.append(btn)


func _build_btn_state_section(parent: VBoxContainer, state_label: String,
		prefix: String, lock_state: String) -> void:
	# Header row: section label + container for locked preview button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	parent.add_child(header_row)

	var lbl := Label.new()
	lbl.text = state_label
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	header_row.add_child(lbl)

	# Preview button in its own container so we can rebuild it on theme change
	var btn_container := HBoxContainer.new()
	header_row.add_child(btn_container)
	btn_container.set_meta("_state_label", state_label)
	btn_container.set_meta("_lock_state", lock_state)
	_btn_state_containers.append(btn_container)
	_rebuild_state_preview_btn(btn_container, state_label, lock_state)

	# 6 sliders in 2-column grid (3 rows × 2 cols)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)

	_add_compact_float_to(grid, "border_alpha", prefix + "_border_alpha", 0.0, 1.0)
	_add_compact_float_to(grid, "bg_alpha", prefix + "_bg_alpha", 0.0, 1.0)
	_add_compact_float_to(grid, "glow_size", prefix + "_glow_size", 0.0, 10.0)
	_add_compact_float_to(grid, "glow_alpha", prefix + "_glow_alpha", 0.0, 1.0)
	_add_compact_float_to(grid, "font_opacity", prefix + "_font_opacity", 0.0, 1.0)
	_add_compact_float_to(grid, "font_whiten", prefix + "_font_whiten", 0.0, 1.0)


func _rebuild_state_preview_btn(container: HBoxContainer, state_label: String, lock_state: String) -> void:
	for child in container.get_children():
		child.queue_free()
	var preview_btn := Button.new()
	preview_btn.text = state_label.to_upper()
	preview_btn.custom_minimum_size = Vector2(120, 34)
	ThemeManager.apply_button_style(preview_btn)
	if lock_state != "":
		ThemeManager.lock_button_state(preview_btn, lock_state)
	else:
		preview_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(preview_btn)
	_preview_buttons.append(preview_btn)


func _add_section_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	parent.add_child(lbl)


func _add_compact_float(parent: Control, display_name: String, key: String,
		min_val: float, max_val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = display_name
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = (max_val - min_val) / 200.0
	slider.value = ThemeManager.get_float(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 80
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % slider.value
	val_lbl.custom_minimum_size.x = 38
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	val_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	row.add_child(val_lbl)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%.2f" % val
		if not _updating_from_theme:
			ThemeManager.set_float(bound_key, val)
	)
	_float_sliders[key] = slider


func _add_compact_float_to(parent: Control, display_name: String, key: String,
		min_val: float, max_val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = display_name
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = (max_val - min_val) / 200.0
	slider.value = ThemeManager.get_float(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 60
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % slider.value
	val_lbl.custom_minimum_size.x = 34
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	val_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	row.add_child(val_lbl)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%.2f" % val
		if not _updating_from_theme:
			ThemeManager.set_float(bound_key, val)
	)
	_float_sliders[key] = slider


func _add_compact_int(parent: Control, display_name: String, key: String,
		min_val: int, max_val: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = display_name
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 1
	slider.value = ThemeManager.get_font_size(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 80
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = str(int(slider.value))
	val_lbl.custom_minimum_size.x = 38
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	val_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	row.add_child(val_lbl)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = str(int(val))
		if not _updating_from_theme:
			ThemeManager.set_font_size(bound_key, int(val))
	)
	_int_sliders[key] = slider


func _populate_panels_samples(vbox: VBoxContainer) -> void:
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


func _refresh_bars_preview() -> void:
	# Refresh inline preview bars (HUD + state bars use apply_led_bar)
	var bar_color_keys: Array = [
		"bar_shield", "bar_hull", "bar_thermal", "bar_electric",
		"bar_warning", "bar_disabled",
		"bar_shield", "bar_hull", "bar_thermal", "bar_electric",
	]
	var bar_values: Array = [85.0, 60.0, 30.0, 70.0, 75.0, 75.0, 80.0, 45.0, 30.0, 70.0]
	var bar_segments: Array = [10, 8, 6, 8, 8, 8, 10, 8, 6, 8]
	var idx: int = 0
	for bar in _preview_bars:
		if not is_instance_valid(bar):
			idx += 1
			continue
		if idx < bar_color_keys.size():
			var color_key: String = bar_color_keys[idx]
			var val: float = bar_values[idx]
			var seg: int = bar_segments[idx]
			ThemeManager.apply_led_bar(bar, ThemeManager.get_color(color_key), val / 100.0, seg)
		idx += 1

	# Refresh supercharged bar separately
	if is_instance_valid(_supercharged_preview_bar):
		ThemeManager.apply_supercharged_bar(
			_supercharged_preview_bar,
			ThemeManager.get_color("bar_supercharged"),
			0.85,
			12
		)


func _build_hud_tab_content(parent: VBoxContainer) -> void:
	# Mock menu
	var menu_section := _make_section_label("Menu Preview")
	parent.add_child(menu_section)

	var menu_panel := PanelContainer.new()
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = ThemeManager.get_color("panel")
	menu_style.border_color = ThemeManager.get_color("accent")
	menu_style.set_border_width_all(1)
	menu_style.set_corner_radius_all(4)
	menu_style.set_content_margin_all(16)
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	parent.add_child(menu_panel)
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
	ThemeManager.apply_header_chrome(menu_title)

	for btn_text in ["PLAY", "HANGAR", "AESTHETIC STUDIO"]:
		var btn := Button.new()
		btn.text = btn_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeManager.apply_button_style(btn)
		menu_vbox.add_child(btn)
		_preview_buttons.append(btn)

	# Mini HUD with all 4 bars
	var hud_section := _make_section_label("HUD Preview")
	parent.add_child(hud_section)

	var hud_panel := PanelContainer.new()
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(ThemeManager.get_color("background"), 0.8)
	hud_style.border_color = ThemeManager.get_color("dimmed")
	hud_style.set_border_width_all(1)
	hud_style.set_corner_radius_all(2)
	hud_style.set_content_margin_all(8)
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	parent.add_child(hud_panel)
	_preview_panels.append(hud_panel)

	var hud_vbox := VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 4)
	hud_panel.add_child(hud_vbox)

	# All 4 HUD bars from specs
	var specs: Array = ThemeManager.get_status_bar_specs()
	var preview_values: Dictionary = {"SHIELD": 80.0, "HULL": 45.0, "THERMAL": 30.0, "ELECTRIC": 70.0}
	var short_names: Dictionary = {"SHIELD": "SHD", "HULL": "HUL", "THERMAL": "THR", "ELECTRIC": "ELC"}
	var preview_segments: Dictionary = {"SHIELD": 10, "HULL": 8, "THERMAL": 6, "ELECTRIC": 8}
	for spec in specs:
		var bar_name: String = str(spec["name"])
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var val: float = float(preview_values.get(bar_name, 50.0))
		var short: String = str(short_names.get(bar_name, bar_name))
		var seg: int = int(preview_segments.get(bar_name, 8))

		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", 6)
		hud_vbox.add_child(bar_row)

		var bar_lbl := Label.new()
		bar_lbl.text = short
		bar_lbl.add_theme_color_override("font_color", color)
		bar_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		bar_row.add_child(bar_lbl)
		_preview_labels.append(bar_lbl)
		_body_glow_labels.append(bar_lbl)
		ThemeManager.apply_text_glow(bar_lbl, "body")

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 14)
		bar.max_value = 100.0
		bar.value = val
		bar.show_percentage = false
		ThemeManager.apply_led_bar(bar, color, val / 100.0, seg)
		bar_row.add_child(bar)
		_preview_bars.append(bar)

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
	parent.add_child(text_section)

	var text_panel := PanelContainer.new()
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = ThemeManager.get_color("panel")
	text_style.set_border_width_all(1)
	text_style.border_color = ThemeManager.get_color("dimmed")
	text_style.set_corner_radius_all(4)
	text_style.set_content_margin_all(12)
	text_panel.add_theme_stylebox_override("panel", text_style)
	parent.add_child(text_panel)
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
			ThemeManager.apply_header_chrome(sample)
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

func _on_header_mode_selected(idx: int) -> void:
	if _updating_from_theme:
		return
	ThemeManager.set_float("header_chrome_enabled", 1.0 if idx == 1 else 0.0)


func _update_header_mode_visibility() -> void:
	var chrome_on: bool = ThemeManager.get_float("header_chrome_enabled") > 0.5
	_chrome_controls_box.visible = chrome_on


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
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


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

	# Sync header mode selector
	if _header_mode_selector:
		_header_mode_selector.selected = 1 if ThemeManager.get_float("header_chrome_enabled") > 0.5 else 0
		_update_header_mode_visibility()

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

	# Rebuild preview panel and dynamic content (deferred, after sliders done)
	_rebuild_preview_and_dynamic.call_deferred()


func _rebuild_preview_and_dynamic() -> void:
	# Clear tracked arrays (except _preview_bars — those are inline in the bars tab)
	_preview_labels.clear()
	_preview_buttons.clear()
	_preview_panels.clear()
	_header_glow_labels.clear()
	_body_glow_labels.clear()

	# Clear HUD tab content — also trim _preview_bars to just the Bars tab entries (first 6)
	for child in _hud_tab_vbox.get_children():
		child.queue_free()
	if _preview_bars.size() > 6:
		_preview_bars.resize(6)

	# Clear panels sample content
	for child in _panels_samples_vbox.get_children():
		child.queue_free()

	# Clear button preview
	for child in _btn_preview_container.get_children():
		child.queue_free()

	# Refresh inline bars (no rebuild needed, just re-apply styles)
	_refresh_bars_preview()

	# Use call_deferred so queue_free completes first
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_build_hud_tab_content(_hud_tab_vbox)
	_populate_panels_samples(_panels_samples_vbox)
	_populate_btn_preview()
	# Rebuild per-state locked preview buttons
	for container in _btn_state_containers:
		if is_instance_valid(container):
			var sl: String = str(container.get_meta("_state_label"))
			var ls: String = str(container.get_meta("_lock_state"))
			_rebuild_state_preview_btn(container, sl, ls)


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
