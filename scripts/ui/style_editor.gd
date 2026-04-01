extends Control
## Styles screen — tabbed: VHS/CRT parameters + Boss Bar audition + Headers.

var _vhs_overlay: ColorRect
var _background: ColorRect

# Track controls for theme_changed refresh
var _float_sliders: Dictionary = {}

var _updating_from_theme := false

# Tab state
var _active_tab: int = 0  # 0 = VHS/CRT, 1 = Boss Bar, 2 = Headers, 3 = Synthwave
var _tab_vhs_btn: Button
var _tab_boss_bar_btn: Button
var _tab_headers_btn: Button
var _tab_synthwave_btn: Button
var _vhs_content: ScrollContainer
var _boss_bar_content: Control
var _headers_content: Control
var _synthwave_content: Control
var _synthwave_rect: ColorRect

# Headers tab controls
var _header_preview_label: Label
var _header_font_option: OptionButton
var _header_size_slider: HSlider
var _header_size_label: Label
var _header_color_picker: ColorPickerButton
var _header_hdr_slider: HSlider
var _header_hdr_label: Label

# Boss bar audition state
var _boss_bar_preview: BossHealthBar = null
var _boss_bar_health_slider: HSlider
var _boss_bar_style_option: OptionButton
var _boss_bar_color_healthy: ColorPickerButton
var _boss_bar_color_damaged: ColorPickerButton
var _boss_bar_color_critical: ColorPickerButton


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

	# Top bar with tabs
	_build_top_bar(root_vbox)

	# ── VHS/CRT content ──
	_vhs_content = ScrollContainer.new()
	_vhs_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_vhs_content)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	_vhs_content.add_child(vbox)

	_build_vhs_controls(vbox)

	# ── Boss bar content ──
	_boss_bar_content = Control.new()
	_boss_bar_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_boss_bar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_bar_content.visible = false
	root_vbox.add_child(_boss_bar_content)
	_build_boss_bar_tab()

	# ── Headers content ──
	_headers_content = ScrollContainer.new()
	_headers_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_headers_content.visible = false
	root_vbox.add_child(_headers_content)
	_build_headers_tab()

	# ── Synthwave BG content ──
	_synthwave_content = Control.new()
	_synthwave_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_synthwave_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synthwave_content.visible = false
	root_vbox.add_child(_synthwave_content)
	_build_synthwave_tab()


func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(_on_back)
	ThemeManager.apply_button_style(back_btn)
	bar.add_child(back_btn)

	var title := Label.new()
	title.text = "STYLES"
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		title.add_theme_font_override("font", header_font)
	ThemeManager.apply_text_glow(title, "header")
	bar.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_tab_vhs_btn = Button.new()
	_tab_vhs_btn.text = "VHS / CRT"
	_tab_vhs_btn.toggle_mode = true
	_tab_vhs_btn.button_pressed = true
	_tab_vhs_btn.pressed.connect(_show_vhs_tab)
	ThemeManager.apply_button_style(_tab_vhs_btn)
	bar.add_child(_tab_vhs_btn)

	_tab_boss_bar_btn = Button.new()
	_tab_boss_bar_btn.text = "BOSS BAR"
	_tab_boss_bar_btn.toggle_mode = true
	_tab_boss_bar_btn.pressed.connect(_show_boss_bar_tab)
	ThemeManager.apply_button_style(_tab_boss_bar_btn)
	bar.add_child(_tab_boss_bar_btn)

	_tab_headers_btn = Button.new()
	_tab_headers_btn.text = "HEADERS"
	_tab_headers_btn.toggle_mode = true
	_tab_headers_btn.pressed.connect(_show_headers_tab)
	ThemeManager.apply_button_style(_tab_headers_btn)
	bar.add_child(_tab_headers_btn)

	_tab_synthwave_btn = Button.new()
	_tab_synthwave_btn.text = "SYNTHWAVE BG"
	_tab_synthwave_btn.toggle_mode = true
	_tab_synthwave_btn.pressed.connect(func(): _switch_to_tab(3))
	ThemeManager.apply_button_style(_tab_synthwave_btn)
	bar.add_child(_tab_synthwave_btn)


func _switch_to_tab(idx: int) -> void:
	if _active_tab == idx:
		match idx:
			0: _tab_vhs_btn.button_pressed = true
			1: _tab_boss_bar_btn.button_pressed = true
			2: _tab_headers_btn.button_pressed = true
			3: _tab_synthwave_btn.button_pressed = true
		return
	_active_tab = idx
	_tab_vhs_btn.button_pressed = (idx == 0)
	_tab_boss_bar_btn.button_pressed = (idx == 1)
	_tab_headers_btn.button_pressed = (idx == 2)
	_tab_synthwave_btn.button_pressed = (idx == 3)
	_vhs_content.visible = (idx == 0)
	_boss_bar_content.visible = (idx == 1)
	_headers_content.visible = (idx == 2)
	_synthwave_content.visible = (idx == 3)


func _show_vhs_tab() -> void:
	_switch_to_tab(0)


func _show_boss_bar_tab() -> void:
	_switch_to_tab(1)


func _show_headers_tab() -> void:
	_switch_to_tab(2)


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


# ── Boss bar audition tab ────────────────────────────────────────────

func _build_boss_bar_tab() -> void:
	var hsplit := HBoxContainer.new()
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.add_theme_constant_override("separation", 20)
	_boss_bar_content.add_child(hsplit)

	# Left: preview area with black background
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(1200, 0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(preview_panel)

	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0.02, 0.02, 0.04)
	preview_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_panel.add_child(preview_bg)

	_boss_bar_preview = BossHealthBar.new()
	_boss_bar_preview.max_health = 100.0
	_boss_bar_preview.current_health = 72.0
	_boss_bar_preview.size = Vector2(1200, 80)
	preview_panel.add_child(_boss_bar_preview)

	# Right: controls
	var controls_scroll := ScrollContainer.new()
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(controls_scroll)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls)

	# Style selector
	var style_label := Label.new()
	style_label.text = "STYLE"
	controls.add_child(style_label)

	_boss_bar_style_option = OptionButton.new()
	_boss_bar_style_option.add_item("LED Segments")
	_boss_bar_style_option.add_item("Holographic")
	_boss_bar_style_option.selected = _boss_bar_preview.style
	_boss_bar_style_option.item_selected.connect(func(idx: int):
		_boss_bar_preview.style = idx
		_boss_bar_preview.save_settings()
	)
	controls.add_child(_boss_bar_style_option)

	# HDR slider
	var hdr_label := Label.new()
	hdr_label.text = "HDR INTENSITY"
	controls.add_child(hdr_label)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 8)
	controls.add_child(hdr_row)
	var hdr_slider := HSlider.new()
	hdr_slider.min_value = 0.5
	hdr_slider.max_value = 4.0
	hdr_slider.step = 0.1
	hdr_slider.value = _boss_bar_preview.hdr
	hdr_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(hdr_slider)
	var hdr_val_label := Label.new()
	hdr_val_label.text = str(snapped(_boss_bar_preview.hdr, 0.1))
	hdr_val_label.custom_minimum_size.x = 40
	hdr_row.add_child(hdr_val_label)
	hdr_slider.value_changed.connect(func(val: float):
		_boss_bar_preview.hdr = val
		hdr_val_label.text = str(snapped(val, 0.1))
		_boss_bar_preview.save_settings()
	)

	# Health slider
	var health_label := Label.new()
	health_label.text = "HEALTH %"
	controls.add_child(health_label)

	_boss_bar_health_slider = HSlider.new()
	_boss_bar_health_slider.min_value = 0.0
	_boss_bar_health_slider.max_value = 100.0
	_boss_bar_health_slider.step = 1.0
	_boss_bar_health_slider.value = 72.0
	_boss_bar_health_slider.value_changed.connect(func(val: float):
		_boss_bar_preview.take_damage(val)
	)
	controls.add_child(_boss_bar_health_slider)

	# Color pickers
	var col_healthy_label := Label.new()
	col_healthy_label.text = "COLOR: HEALTHY"
	controls.add_child(col_healthy_label)
	_boss_bar_color_healthy = ColorPickerButton.new()
	_boss_bar_color_healthy.color = _boss_bar_preview.color_healthy
	_boss_bar_color_healthy.custom_minimum_size = Vector2(60, 30)
	_boss_bar_color_healthy.color_changed.connect(func(c: Color):
		_boss_bar_preview.color_healthy = c
		_boss_bar_preview.save_settings()
	)
	controls.add_child(_boss_bar_color_healthy)

	var col_damaged_label := Label.new()
	col_damaged_label.text = "COLOR: DAMAGED"
	controls.add_child(col_damaged_label)
	_boss_bar_color_damaged = ColorPickerButton.new()
	_boss_bar_color_damaged.color = _boss_bar_preview.color_damaged
	_boss_bar_color_damaged.custom_minimum_size = Vector2(60, 30)
	_boss_bar_color_damaged.color_changed.connect(func(c: Color):
		_boss_bar_preview.color_damaged = c
		_boss_bar_preview.save_settings()
	)
	controls.add_child(_boss_bar_color_damaged)

	var col_critical_label := Label.new()
	col_critical_label.text = "COLOR: CRITICAL"
	controls.add_child(col_critical_label)
	_boss_bar_color_critical = ColorPickerButton.new()
	_boss_bar_color_critical.color = _boss_bar_preview.color_critical
	_boss_bar_color_critical.custom_minimum_size = Vector2(60, 30)
	_boss_bar_color_critical.color_changed.connect(func(c: Color):
		_boss_bar_preview.color_critical = c
		_boss_bar_preview.save_settings()
	)
	controls.add_child(_boss_bar_color_critical)

	_apply_theme_recursive(_boss_bar_content)


# ── Headers tab ─────────────────────────────────────────────

const AVAILABLE_FONTS: Array = [
	{"label": "Bungee", "path": "res://assets/fonts/Bungee-Regular.ttf"},
	{"label": "Audiowide", "path": "res://assets/fonts/Audiowide-Regular.ttf"},
	{"label": "Orbitron", "path": "res://assets/fonts/Orbitron.ttf"},
	{"label": "Russo One", "path": "res://assets/fonts/RussoOne-Regular.ttf"},
	{"label": "Share Tech Mono", "path": "res://assets/fonts/ShareTechMono-Regular.ttf"},
]


func _build_headers_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	_headers_content.add_child(vbox)

	# ── Live preview ──
	var preview_panel := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.02, 0.02, 0.04, 0.9)
	preview_style.set_corner_radius_all(4)
	preview_style.set_content_margin_all(20)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	vbox.add_child(preview_panel)

	_header_preview_label = Label.new()
	_header_preview_label.text = "SAMPLE HEADER TEXT"
	_header_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_panel.add_child(_header_preview_label)
	_refresh_header_preview()

	# ── Font picker ──
	var font_row := HBoxContainer.new()
	font_row.add_theme_constant_override("separation", 8)
	vbox.add_child(font_row)

	var font_lbl := Label.new()
	font_lbl.text = "TYPEFACE"
	font_lbl.custom_minimum_size.x = 200
	font_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	font_row.add_child(font_lbl)

	_header_font_option = OptionButton.new()
	_header_font_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_path: String = ThemeManager.get_font_path("font_header")
	var selected_idx: int = 0
	for i in AVAILABLE_FONTS.size():
		var entry: Dictionary = AVAILABLE_FONTS[i]
		_header_font_option.add_item(str(entry["label"]))
		if str(entry["path"]) == current_path:
			selected_idx = i
	_header_font_option.selected = selected_idx
	_header_font_option.item_selected.connect(_on_header_font_changed)
	font_row.add_child(_header_font_option)

	# ── Size slider ──
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	vbox.add_child(size_row)

	var size_lbl := Label.new()
	size_lbl.text = "SIZE"
	size_lbl.custom_minimum_size.x = 200
	size_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	size_row.add_child(size_lbl)

	_header_size_slider = HSlider.new()
	_header_size_slider.min_value = 12
	_header_size_slider.max_value = 48
	_header_size_slider.step = 1
	_header_size_slider.value = ThemeManager.get_font_size("font_size_header")
	_header_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_size_slider.custom_minimum_size.x = 120
	_header_size_slider.value_changed.connect(_on_header_size_changed)
	size_row.add_child(_header_size_slider)

	_header_size_label = Label.new()
	_header_size_label.text = str(int(_header_size_slider.value))
	_header_size_label.custom_minimum_size.x = 50
	_header_size_label.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	size_row.add_child(_header_size_label)

	# ── Color picker ──
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	vbox.add_child(color_row)

	var color_lbl := Label.new()
	color_lbl.text = "COLOR"
	color_lbl.custom_minimum_size.x = 200
	color_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	color_row.add_child(color_lbl)

	_header_color_picker = ColorPickerButton.new()
	_header_color_picker.color = ThemeManager.get_color("header")
	_header_color_picker.custom_minimum_size = Vector2(60, 30)
	_header_color_picker.color_changed.connect(_on_header_color_changed)
	color_row.add_child(_header_color_picker)

	# ── HDR bloom multiplier ──
	# This adds a ColorRect behind the label with color > 1.0 so Godot's
	# WorldEnvironment glow picks it up — real bloom, not the shader rect hack.
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 8)
	vbox.add_child(hdr_row)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "HDR BLOOM"
	hdr_lbl.custom_minimum_size.x = 200
	hdr_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	hdr_row.add_child(hdr_lbl)

	_header_hdr_slider = HSlider.new()
	_header_hdr_slider.min_value = 0.0
	_header_hdr_slider.max_value = 3.0
	_header_hdr_slider.step = 0.05
	_header_hdr_slider.value = ThemeManager.get_float("header_hdr_bloom")
	_header_hdr_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_hdr_slider.custom_minimum_size.x = 120
	_header_hdr_slider.value_changed.connect(_on_header_hdr_changed)
	hdr_row.add_child(_header_hdr_slider)

	_header_hdr_label = Label.new()
	_header_hdr_label.text = "%.2f" % _header_hdr_slider.value
	_header_hdr_label.custom_minimum_size.x = 50
	_header_hdr_label.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	hdr_row.add_child(_header_hdr_label)

	# ── Shader glow sliders (existing text_glow params) ──
	var glow_section_lbl := Label.new()
	glow_section_lbl.text = "SHADER GLOW (RECT-BASED)"
	glow_section_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	vbox.add_child(glow_section_lbl)

	var glow_params: Dictionary = {
		"header_inner_intensity": {"min": 0.0, "max": 2.0},
		"header_aura_size": {"min": 0.0, "max": 5.0},
		"header_aura_intensity": {"min": 0.0, "max": 2.0},
		"header_bloom_size": {"min": 0.0, "max": 5.0},
		"header_bloom_intensity": {"min": 0.0, "max": 2.0},
		"header_smudge_blur": {"min": 0.0, "max": 5.0},
	}
	for key in glow_params:
		var params: Dictionary = glow_params[key]
		_add_float_slider(vbox, key, float(params["min"]), float(params["max"]), ThemeManager.get_float(key))


func _on_header_font_changed(idx: int) -> void:
	if idx < 0 or idx >= AVAILABLE_FONTS.size():
		return
	var path: String = str(AVAILABLE_FONTS[idx]["path"])
	ThemeManager.set_font_path("font_header", path)
	_refresh_header_preview()


func _on_header_size_changed(val: float) -> void:
	_header_size_label.text = str(int(val))
	ThemeManager.set_font_size("font_size_header", int(val))
	_refresh_header_preview()


func _on_header_color_changed(color: Color) -> void:
	ThemeManager.set_color("header", color)
	_refresh_header_preview()


func _on_header_hdr_changed(val: float) -> void:
	_header_hdr_label.text = "%.2f" % val
	if not _updating_from_theme:
		ThemeManager.set_float("header_hdr_bloom", val)
	_refresh_header_preview()


func _refresh_header_preview() -> void:
	if not _header_preview_label:
		return
	var font: Font = ThemeManager.get_font("font_header")
	if font:
		_header_preview_label.add_theme_font_override("font", font)
	_header_preview_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_header_preview_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	ThemeManager.apply_header_style(_header_preview_label)


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
	if _tab_vhs_btn:
		ThemeManager.apply_button_style(_tab_vhs_btn)
	if _tab_boss_bar_btn:
		ThemeManager.apply_button_style(_tab_boss_bar_btn)
	if _tab_headers_btn:
		ThemeManager.apply_button_style(_tab_headers_btn)
	if _tab_synthwave_btn:
		ThemeManager.apply_button_style(_tab_synthwave_btn)

	# Refresh header controls
	if _header_size_slider:
		_header_size_slider.value = ThemeManager.get_font_size("font_size_header")
		_header_size_label.text = str(int(_header_size_slider.value))
	if _header_color_picker:
		_header_color_picker.color = ThemeManager.get_color("header")
	if _header_hdr_slider:
		_header_hdr_slider.value = ThemeManager.get_float("header_hdr_bloom")
		_header_hdr_label.text = "%.2f" % _header_hdr_slider.value
	_refresh_header_preview()

	_updating_from_theme = false


func _apply_theme_recursive(node: Node) -> void:
	if node is Button:
		ThemeManager.apply_button_style(node as Button)
	for child in node.get_children():
		_apply_theme_recursive(child)


# ═══════════════════════════════════════════════════════════════════
# SYNTHWAVE BG TAB
# ═══════════════════════════════════════════════════════════════════

const _SW_PATH: String = "user://settings/synthwave_bg.json"


func _build_synthwave_tab() -> void:
	# Full-screen shader preview
	_synthwave_rect = ColorRect.new()
	_synthwave_rect.color = Color.WHITE
	_synthwave_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_synthwave_content.add_child(_synthwave_rect)

	var shader: Shader = load("res://assets/shaders/synthwave_bg.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_synthwave_rect.material = mat

	# Semi-transparent slider panel on left
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	panel_bg.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel_bg.offset_right = 310
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synthwave_content.add_child(panel_bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = 300
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_synthwave_content.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# ── PLANET ──
	_sw_tab_section(vbox, "PLANET")
	_sw_tab_slider(vbox, "planet_hdr", "HDR", 0.5, 4.0, 1.5)
	_sw_tab_slider(vbox, "planet_radius", "Radius", 0.03, 0.2, 0.08)
	_sw_tab_slider(vbox, "planet_x", "Position X", 0.35, 0.85, 0.63)
	_sw_tab_color(vbox, "planet_color_top", "Top Color", Color(1.0, 0.85, 0.3))
	_sw_tab_color(vbox, "planet_color_bot", "Bot Color", Color(0.9, 0.2, 0.08))
	_sw_tab_slider(vbox, "atmo_glow", "Atmo Glow", 0.0, 2.0, 0.6)
	_sw_tab_color(vbox, "atmo_color", "Atmo Color", Color(0.2, 0.6, 1.0))
	_sw_tab_slider(vbox, "slice_start", "Slice Start", 0.1, 0.6, 0.32)
	_sw_tab_slider(vbox, "slice_band_h", "Slice Band H", 0.02, 0.12, 0.058)
	_sw_tab_slider(vbox, "slice_gap_base", "Slice Gap Base", 0.002, 0.03, 0.005)
	_sw_tab_slider(vbox, "slice_gap_grow", "Slice Gap Grow", 0.005, 0.04, 0.015)

	vbox.add_child(HSeparator.new())

	# ── RING ──
	_sw_tab_section(vbox, "RING")
	_sw_tab_slider(vbox, "ring_hdr", "HDR", 0.5, 6.0, 2.5)
	_sw_tab_color(vbox, "ring_color", "Color", Color(0.1, 0.8, 1.0))
	_sw_tab_slider(vbox, "ring_inner", "Inner Radius", 0.05, 0.5, 0.10)
	_sw_tab_slider(vbox, "ring_outer", "Outer Radius", 0.1, 1.5, 1.1)
	_sw_tab_slider(vbox, "ring_tilt", "Tilt Squish", 0.05, 0.8, 0.15)
	_sw_tab_slider(vbox, "ring_angle", "Rotation", -0.8, 0.8, 0.35)
	_sw_tab_slider(vbox, "ring_band_width", "Band Width", 0.005, 0.08, 0.018)
	_sw_tab_slider(vbox, "ring_gap_base", "Gap Base", 0.002, 0.05, 0.010)
	_sw_tab_slider(vbox, "ring_gap_grow", "Gap Growth", 0.0, 0.03, 0.014)
	_sw_tab_slider(vbox, "ring_glow_size", "Glow Size", 0.0, 0.03, 0.008)

	vbox.add_child(HSeparator.new())

	# ── GRID ──
	_sw_tab_section(vbox, "GRID")
	_sw_tab_slider(vbox, "grid_core_brightness", "Core HDR", 0.5, 12.0, 6.0)
	_sw_tab_slider(vbox, "grid_core_tint", "Core Pink", 0.0, 1.0, 0.0)
	_sw_tab_slider(vbox, "grid_bloom_brightness", "Bloom HDR", 0.5, 8.0, 3.0)
	_sw_tab_slider(vbox, "grid_line_w", "Line Width", 0.001, 0.03, 0.008)
	_sw_tab_slider(vbox, "grid_bloom_w", "Bloom Width", 0.01, 0.15, 0.06)
	_sw_tab_color(vbox, "grid_color", "Grid Color", Color(1.0, 0.08, 0.52))
	_sw_tab_slider(vbox, "scroll_speed", "Scroll Speed", 0.0, 2.0, 0.5)
	_sw_tab_slider(vbox, "grid_freq", "Frequency", 0.5, 5.0, 2.0)

	vbox.add_child(HSeparator.new())

	# ── CORRIDOR ──
	_sw_tab_section(vbox, "CORRIDOR")
	_sw_tab_slider(vbox, "horizon", "Horizon", 0.3, 0.65, 0.5)
	_sw_tab_slider(vbox, "corridor_gap", "Gap Size", 0.02, 0.25, 0.10)
	_sw_tab_slider(vbox, "grid_fade_width", "Fade Width", 0.02, 0.4, 0.18)

	vbox.add_child(HSeparator.new())

	# ── STARS ──
	_sw_tab_section(vbox, "STARS")
	_sw_tab_slider(vbox, "star_density", "Density", 0.85, 0.99, 0.94)
	_sw_tab_slider(vbox, "star_size", "Size", 0.001, 0.008, 0.003)
	_sw_tab_slider(vbox, "star_glow_size", "Glow Size", 0.0, 0.015, 0.005)
	_sw_tab_slider(vbox, "star_brightness", "Brightness", 0.5, 5.0, 2.5)
	_sw_tab_slider(vbox, "star_twinkle", "Twinkle", 0.0, 1.0, 0.6)
	_sw_tab_color(vbox, "star_color", "Color", Color(0.7, 0.85, 1.0))

	vbox.add_child(HSeparator.new())

	# ── SKY ──
	_sw_tab_section(vbox, "SKY")
	_sw_tab_slider(vbox, "nebula_intensity", "Nebula", 0.0, 0.5, 0.12)
	_sw_tab_color(vbox, "accent_color", "Accent Color", Color(0.1, 0.8, 1.0))

	vbox.add_child(HSeparator.new())

	# ── WARP STREAKS ──
	_sw_tab_section(vbox, "WARP STREAKS")
	_sw_tab_slider(vbox, "warp_streak_intensity", "Intensity", 0.0, 2.0, 0.5)
	_sw_tab_slider(vbox, "warp_streak_speed", "Speed", 0.1, 5.0, 1.0)
	_sw_tab_slider(vbox, "warp_streak_count", "Count", 4.0, 40.0, 20.0)
	_sw_tab_slider(vbox, "warp_inner_radius", "Inner Radius", 0.05, 0.5, 0.2)
	_sw_tab_slider(vbox, "warp_fade_width", "Fade In Width", 0.02, 0.3, 0.1)
	_sw_tab_slider(vbox, "warp_max_length", "Max Length", 0.02, 0.4, 0.12)
	_sw_tab_slider(vbox, "warp_streak_width", "Line Width", 0.0005, 0.006, 0.0015)

	vbox.add_child(HSeparator.new())

	# ── MOTION LIGHTS ──
	_sw_tab_section(vbox, "MOTION LIGHTS")
	_sw_tab_slider(vbox, "light_brightness", "Brightness", 0.0, 3.0, 0.5)
	_sw_tab_slider(vbox, "light_speed", "Speed", 0.05, 2.0, 0.5)

	# Load saved settings
	_sw_load_settings()


func _sw_tab_section(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_text_glow(label, "header")
	var hf: Font = ThemeManager.get_font("font_header")
	if hf:
		label.add_theme_font_override("font", hf)
	parent.add_child(label)


func _sw_tab_slider(parent: VBoxContainer, param: String, display: String,
		min_val: float, max_val: float, default_val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = display
	label.custom_minimum_size.x = 110
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = (max_val - min_val) / 200.0
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	row.add_child(slider)

	var val_label := Label.new()
	val_label.custom_minimum_size.x = 40
	val_label.add_theme_font_size_override("font_size", 11)
	val_label.text = "%.3f" % default_val
	row.add_child(val_label)

	slider.value_changed.connect(func(v: float) -> void:
		val_label.text = "%.3f" % v
		_sw_set_param(param, v)
	)
	slider.set_meta("sw_param", param)


func _sw_tab_color(parent: VBoxContainer, param: String, display: String, default_col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = display
	label.custom_minimum_size.x = 110
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var picker := ColorPickerButton.new()
	picker.color = default_col
	picker.custom_minimum_size = Vector2(60, 24)
	picker.edit_alpha = false
	row.add_child(picker)

	picker.color_changed.connect(func(c: Color) -> void:
		_sw_set_param(param, c)
	)
	picker.set_meta("sw_param", param)


func _sw_set_param(param: String, value: Variant) -> void:
	var mat: ShaderMaterial = _synthwave_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(param, value)
	_sw_save_settings()


func _sw_save_settings() -> void:
	var data: Dictionary = {}
	_sw_collect(_synthwave_content, data)
	var dir_path: String = _SW_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f: FileAccess = FileAccess.open(_SW_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _sw_collect(node: Node, out: Dictionary) -> void:
	if node.has_meta("sw_param"):
		var param: String = node.get_meta("sw_param")
		if node is HSlider:
			out[param] = node.value
		elif node is ColorPickerButton:
			var c: Color = node.color
			out[param] = {"r": c.r, "g": c.g, "b": c.b}
	for child in node.get_children():
		_sw_collect(child, out)


func _sw_load_settings() -> void:
	if not FileAccess.file_exists(_SW_PATH):
		return
	var f: FileAccess = FileAccess.open(_SW_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return
	var data: Variant = json.data
	f.close()
	if not data is Dictionary:
		return
	var d: Dictionary = data as Dictionary
	var mat: ShaderMaterial = _synthwave_rect.material as ShaderMaterial
	if not mat:
		return
	for key in d:
		var val: Variant = d[key]
		if val is Dictionary:
			var cd: Dictionary = val as Dictionary
			if cd.has("r"):
				val = Color(float(cd["r"]), float(cd["g"]), float(cd["b"]))
		mat.set_shader_parameter(key, val)
	_sw_sync_controls(_synthwave_content, d)


func _sw_sync_controls(node: Node, data: Dictionary) -> void:
	if node.has_meta("sw_param"):
		var param: String = node.get_meta("sw_param")
		if data.has(param):
			var val: Variant = data[param]
			if node is HSlider:
				if val is Dictionary:
					return
				node.set_value_no_signal(float(val))
				var p: Node = node.get_parent()
				var idx: int = node.get_index()
				if idx + 1 < p.get_child_count():
					var vl: Node = p.get_child(idx + 1)
					if vl is Label:
						vl.text = "%.3f" % float(val)
			elif node is ColorPickerButton:
				if val is Color:
					node.color = val as Color
				elif val is Dictionary:
					var cd: Dictionary = val as Dictionary
					node.color = Color(float(cd["r"]), float(cd["g"]), float(cd["b"]))
	for child in node.get_children():
		_sw_sync_controls(child, data)
