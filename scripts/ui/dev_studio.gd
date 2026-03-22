extends Control
## Dev Studio — tabbed container for component editors (Weapons, Beams, Fields, etc.).
## Includes a collapsible bloom tuning panel that live-updates all SubViewport bloom
## via VFXFactory's tracked Environment list.

var _vhs_overlay: ColorRect
var _bloom_panel: Panel
var _bloom_visible := false
var _bloom_sliders: Dictionary = {}  # key -> HSlider
var _bloom_labels: Dictionary = {}   # key -> Label
var _bloom_toggles: Array[CheckButton] = []
var _bloom_toggle_btn: Button
var _bloom_count_label: Label


func _ready() -> void:
	$BackButton.pressed.connect(_on_back)
	ThemeManager.apply_grid_background($Background)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_styles()
	_build_bloom_panel()


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
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


# ── Bloom Tuning Panel ──────────────────────────────────────

func _build_bloom_panel() -> void:
	# Toggle button in header row
	_bloom_toggle_btn = Button.new()
	_bloom_toggle_btn.text = "BLOOM"
	_bloom_toggle_btn.custom_minimum_size = Vector2(80, 28)
	_bloom_toggle_btn.pressed.connect(_toggle_bloom_panel)
	$VBoxContainer/Header.add_child(_bloom_toggle_btn)
	ThemeManager.apply_button_style(_bloom_toggle_btn)

	# Panel — anchored top-right, below header
	_bloom_panel = Panel.new()
	_bloom_panel.size = Vector2(380, 355)
	_bloom_panel.position = Vector2(1920 - 400, 60)
	_bloom_panel.z_index = 40  # Above tab content
	_bloom_panel.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.04, 0.08, 0.94)
	panel_style.border_color = ThemeManager.get_color("accent")
	panel_style.border_width_bottom = 1
	panel_style.border_width_top = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_bloom_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_bloom_panel)

	var y: float = 10.0
	var title := Label.new()
	title.text = "BLOOM TUNING"
	title.position = Vector2(12, y)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_bloom_panel.add_child(title)

	# Debug: show how many bloom environments are tracked
	_bloom_count_label = Label.new()
	_bloom_count_label.position = Vector2(200, y)
	_bloom_count_label.add_theme_font_size_override("font_size", 11)
	_bloom_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_bloom_panel.add_child(_bloom_count_label)
	y += 24.0

	# KILL BLOOM button — toggles root viewport glow
	var kill_btn := Button.new()
	kill_btn.text = "KILL BLOOM"
	kill_btn.toggle_mode = true
	kill_btn.position = Vector2(12, y)
	kill_btn.size = Vector2(120, 26)
	kill_btn.toggled.connect(func(off: bool):
		var env: Environment = ThemeManager.get_environment()
		if env:
			env.glow_enabled = not off
		kill_btn.text = "BLOOM KILLED" if off else "KILL BLOOM"
	)
	_bloom_panel.add_child(kill_btn)
	ThemeManager.apply_button_style(kill_btn)
	y += 32.0

	_add_bloom_slider("glow_hdr_threshold", "Threshold", y, 0.0, 2.0)
	y += 32.0
	_add_bloom_slider("glow_intensity", "Intensity", y, 0.0, 5.0)
	y += 32.0
	_add_bloom_slider("glow_bloom", "Bloom Mix", y, 0.0, 1.0)
	y += 38.0

	# Glow level toggles
	var levels_lbl := Label.new()
	levels_lbl.text = "Levels (0=tight ... 6=wide):"
	levels_lbl.position = Vector2(12, y)
	levels_lbl.add_theme_font_size_override("font_size", 12)
	levels_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_bloom_panel.add_child(levels_lbl)
	y += 22.0

	for lvl in 7:
		var cb := CheckButton.new()
		cb.text = str(lvl)
		cb.button_pressed = ThemeManager.get_float("glow_level_%d" % lvl) > 0.5
		cb.position = Vector2(12 + float(lvl) * 50, y)
		cb.add_theme_font_size_override("font_size", 11)
		cb.custom_minimum_size = Vector2(46, 24)
		var level_idx: int = lvl
		cb.toggled.connect(func(_on: bool): _apply_live_bloom())
		_bloom_panel.add_child(cb)
		_bloom_toggles.append(cb)
	y += 36.0

	# Save button
	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.position = Vector2(12, y)
	save_btn.size = Vector2(100, 32)
	save_btn.pressed.connect(_save_bloom_settings)
	_bloom_panel.add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)

	var status := Label.new()
	status.name = "BloomStatus"
	status.text = ""
	status.position = Vector2(120, y + 6)
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_bloom_panel.add_child(status)


func _add_bloom_slider(key: String, display: String, y: float, min_val: float, max_val: float) -> void:
	var current: float = ThemeManager.get_float(key)

	var lbl := Label.new()
	lbl.text = display + ":"
	lbl.position = Vector2(12, y)
	lbl.size = Vector2(100, 24)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_bloom_panel.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = current
	slider.step = 0.01
	slider.position = Vector2(115, y + 2)
	slider.size = Vector2(190, 18)
	_bloom_panel.add_child(slider)
	_bloom_sliders[key] = slider

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % current
	val_lbl.position = Vector2(312, y)
	val_lbl.size = Vector2(55, 24)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_bloom_panel.add_child(val_lbl)
	_bloom_labels[key] = val_lbl

	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%.2f" % v
		_apply_live_bloom()
	)


func _toggle_bloom_panel() -> void:
	_bloom_visible = not _bloom_visible
	_bloom_panel.visible = _bloom_visible
	_bloom_toggle_btn.text = "BLOOM X" if _bloom_visible else "BLOOM"


func _apply_live_bloom() -> void:
	# Bloom runs on the ROOT viewport — modify ThemeManager's root Environment directly.
	var env: Environment = ThemeManager.get_environment()
	if not env:
		_bloom_count_label.text = "NO ROOT ENV"
		return
	env.glow_intensity = _bloom_sliders["glow_intensity"].value
	env.glow_bloom = _bloom_sliders["glow_bloom"].value
	env.glow_hdr_threshold = _bloom_sliders["glow_hdr_threshold"].value
	for i in 7:
		env.set_glow_level(i, _bloom_toggles[i].button_pressed)
	_bloom_count_label.text = "root env"


func _save_bloom_settings() -> void:
	# NOW write to ThemeManager for persistence
	for key in _bloom_sliders:
		ThemeManager.set_float(key, _bloom_sliders[key].value)
	for i in 7:
		ThemeManager.set_float("glow_level_%d" % i, 1.0 if _bloom_toggles[i].button_pressed else 0.0)
	ThemeManager.save_settings()

	var status: Label = _bloom_panel.get_node("BloomStatus") as Label
	if status:
		status.text = "Saved!"
		get_tree().create_timer(2.0).timeout.connect(func(): status.text = "")
