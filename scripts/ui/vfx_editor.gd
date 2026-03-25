extends Control
## VFX Editor — two live previews (shield bubble + hull flash) with slider controls.
## Browses all 9 player ship designs + enemy ships by renderer ID, with skin toggle.

var _config: VfxConfig
var _vhs_overlay: ColorRect
var _status_label: Label
var _auto_timer: float = 0.0
const AUTO_INTERVAL: float = 2.0

# Ship browsing — by renderer ID, not JSON data files
const PLAYER_SHIPS: Array[Dictionary] = [
	{"id": 0, "name": "Switchblade"},
	{"id": 1, "name": "Phantom"},
	{"id": 2, "name": "Mantis"},
	{"id": 3, "name": "Corsair"},
	{"id": 4, "name": "Stiletto"},
	{"id": 5, "name": "Trident"},
	{"id": 6, "name": "Orrery"},
	{"id": 7, "name": "Dreadnought"},
	{"id": 8, "name": "Bastion"},
]
const ENEMY_SHIPS: Array[Dictionary] = [
	{"visual_id": "sentinel", "name": "Sentinel"},
]

var _category: int = 0  # 0=player, 1=enemy
var _ship_index: int = 0
var _render_mode: int = ShipRenderer.RenderMode.CHROME
var _ship_label: Label
var _cat_btn: Button
var _skin_btn: Button

# Preview nodes
var _shield_renderer: ShipRenderer
var _shield_bubble: ShieldBubbleEffect
var _hull_renderer: ShipRenderer

# Slider references for live update
var _sliders: Dictionary = {}  # key -> HSlider


func _ready() -> void:
	_config = VfxConfigManager.load_config()
	_setup_vhs_overlay()
	_build_ui()
	_apply_config_to_previews()
	_update_ship_previews()

	ThemeManager.theme_changed.connect(_on_theme_changed)


func _process(delta: float) -> void:
	_auto_timer += delta
	if _auto_timer >= AUTO_INTERVAL:
		_auto_timer = 0.0
		_trigger_effects()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


# ── UI Construction ──

func _build_ui() -> void:
	# Grid background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	ThemeManager.apply_grid_background(bg)

	# Top bar
	_build_top_bar()
	# Ship selector row
	_build_ship_selector()
	# Two-column layout: shield (left) + hull (right)
	_build_preview_columns()
	# Bottom bar
	_build_bottom_bar()


func _build_top_bar() -> void:
	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(20, 10)
	top_bar.size = Vector2(1880, 50)
	add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn"))
	top_bar.add_child(back_btn)
	ThemeManager.apply_button_style(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var title := Label.new()
	title.text = "VFX EDITOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)
	ThemeManager.apply_text_glow(title, "header")

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)


func _build_ship_selector() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(20, 60)
	row.size = Vector2(1880, 40)
	add_child(row)

	var ship_lbl := Label.new()
	ship_lbl.text = "Ship:"
	row.add_child(ship_lbl)
	ThemeManager.apply_text_glow(ship_lbl, "body")

	_cat_btn = Button.new()
	_cat_btn.text = "PLAYER"
	_cat_btn.custom_minimum_size.x = 100
	_cat_btn.pressed.connect(_toggle_category)
	row.add_child(_cat_btn)
	ThemeManager.apply_button_style(_cat_btn)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_prev_ship)
	row.add_child(prev_btn)
	ThemeManager.apply_button_style(prev_btn)

	_ship_label = Label.new()
	_ship_label.text = "Switchblade"
	_ship_label.custom_minimum_size.x = 180
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_ship_label)
	ThemeManager.apply_text_glow(_ship_label, "body")

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_next_ship)
	row.add_child(next_btn)
	ThemeManager.apply_button_style(next_btn)

	# Spacer
	var sep := Control.new()
	sep.custom_minimum_size.x = 40
	row.add_child(sep)

	var skin_lbl := Label.new()
	skin_lbl.text = "Skin:"
	row.add_child(skin_lbl)
	ThemeManager.apply_text_glow(skin_lbl, "body")

	_skin_btn = Button.new()
	_skin_btn.text = "CHROME"
	_skin_btn.custom_minimum_size.x = 100
	_skin_btn.pressed.connect(_toggle_skin)
	row.add_child(_skin_btn)
	ThemeManager.apply_button_style(_skin_btn)


func _build_preview_columns() -> void:
	var col_y: float = 110.0
	var col_w: float = 900.0

	# ── Left column: Shield Hit ──
	var shield_header := Label.new()
	shield_header.text = "SHIELD HIT  (Soft Sphere)"
	shield_header.position = Vector2(60, col_y)
	add_child(shield_header)
	ThemeManager.apply_text_glow(shield_header, "header")

	# Shield preview panel
	var shield_panel := Panel.new()
	shield_panel.position = Vector2(60, col_y + 35)
	shield_panel.size = Vector2(280, 220)
	add_child(shield_panel)
	_style_panel(shield_panel)

	_shield_renderer = ShipRenderer.new()
	_shield_renderer.position = Vector2(140, 110)
	_shield_renderer.scale = Vector2(0.7, 0.7)
	_shield_renderer.animate = true
	shield_panel.add_child(_shield_renderer)

	_shield_bubble = ShieldBubbleEffect.new()
	_shield_bubble.position = _shield_renderer.position
	shield_panel.add_child(_shield_bubble)

	# Shield sliders
	var sy: float = col_y + 35
	var sx: float = 370.0
	sy = _add_slider(sx, sy, "shield_color_r", "Color R", 0.0, 1.0, _config.shield_color_r)
	sy = _add_slider(sx, sy, "shield_color_g", "Color G", 0.0, 1.0, _config.shield_color_g)
	sy = _add_slider(sx, sy, "shield_color_b", "Color B", 0.0, 1.0, _config.shield_color_b)
	sy = _add_slider(sx, sy, "shield_duration", "Duration", 0.05, 0.5, _config.shield_duration)
	sy = _add_slider(sx, sy, "shield_radius_mult", "Radius", 0.5, 2.0, _config.shield_radius_mult)
	sy = _add_slider(sx, sy, "shield_intensity", "Intensity", 0.2, 2.0, _config.shield_intensity)

	# ── Right column: Hull Flash ──
	var hull_header := Label.new()
	hull_header.text = "HULL FLASH  (Hard Blink)"
	hull_header.position = Vector2(col_w + 60, col_y)
	add_child(hull_header)
	ThemeManager.apply_text_glow(hull_header, "header")

	# Hull preview panel
	var hull_panel := Panel.new()
	hull_panel.position = Vector2(col_w + 60, col_y + 35)
	hull_panel.size = Vector2(280, 220)
	add_child(hull_panel)
	_style_panel(hull_panel)

	_hull_renderer = ShipRenderer.new()
	_hull_renderer.position = Vector2(140, 110)
	_hull_renderer.scale = Vector2(0.7, 0.7)
	_hull_renderer.animate = true
	hull_panel.add_child(_hull_renderer)

	# Hull sliders
	var hy: float = col_y + 35
	var hx: float = col_w + 370.0
	hy = _add_slider(hx, hy, "hull_peak_r", "Peak R", 1.0, 5.0, _config.hull_peak_r)
	hy = _add_slider(hx, hy, "hull_peak_g", "Peak G", 1.0, 5.0, _config.hull_peak_g)
	hy = _add_slider(hx, hy, "hull_peak_b", "Peak B", 1.0, 5.0, _config.hull_peak_b)
	hy = _add_slider(hx, hy, "hull_duration", "Duration", 0.04, 0.4, _config.hull_duration)
	hy = _add_slider(hx, hy, "hull_blink_speed", "Blink Speed", 2.0, 14.0, _config.hull_blink_speed)


func _build_bottom_bar() -> void:
	var bottom_y: float = 720.0

	_status_label = Label.new()
	_status_label.position = Vector2(60, bottom_y)
	_status_label.size = Vector2(1200, 40)
	add_child(_status_label)
	ThemeManager.apply_text_glow(_status_label, "body")
	_update_status()

	var replay_btn := Button.new()
	replay_btn.text = "REPLAY"
	replay_btn.position = Vector2(1560, bottom_y)
	replay_btn.size = Vector2(120, 40)
	replay_btn.pressed.connect(_trigger_effects)
	add_child(replay_btn)
	ThemeManager.apply_button_style(replay_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.position = Vector2(1700, bottom_y)
	save_btn.size = Vector2(120, 40)
	save_btn.pressed.connect(_save_config)
	add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)


# ── Slider factory ──

func _add_slider(x: float, y: float, key: String, label_text: String, min_val: float, max_val: float, value: float) -> float:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(x, y + 2)
	lbl.size = Vector2(90, 24)
	add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var slider := HSlider.new()
	slider.position = Vector2(x + 95, y)
	slider.size = Vector2(280, 28)
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = value
	slider.value_changed.connect(_on_slider_changed.bind(key))
	add_child(slider)
	_sliders[key] = slider

	var val_lbl := Label.new()
	val_lbl.name = key + "_val"
	val_lbl.text = "%.2f" % value
	val_lbl.position = Vector2(x + 380, y + 2)
	val_lbl.size = Vector2(60, 24)
	add_child(val_lbl)
	ThemeManager.apply_text_glow(val_lbl, "body")

	return y + 34.0


func _on_slider_changed(value: float, key: String) -> void:
	# Update config
	match key:
		"shield_color_r": _config.shield_color_r = value
		"shield_color_g": _config.shield_color_g = value
		"shield_color_b": _config.shield_color_b = value
		"shield_duration": _config.shield_duration = value
		"shield_radius_mult": _config.shield_radius_mult = value
		"shield_intensity": _config.shield_intensity = value
		"hull_peak_r": _config.hull_peak_r = value
		"hull_peak_g": _config.hull_peak_g = value
		"hull_peak_b": _config.hull_peak_b = value
		"hull_duration": _config.hull_duration = value
		"hull_blink_speed": _config.hull_blink_speed = value

	# Update value label
	var val_node: Label = get_node_or_null(key + "_val") as Label
	if val_node:
		val_node.text = "%.2f" % value

	_apply_config_to_previews()
	_trigger_effects()
	_update_status()


# ── Preview management ──

func _apply_config_to_previews() -> void:
	# Shield bubble
	_shield_bubble.shield_color = Color(_config.shield_color_r, _config.shield_color_g, _config.shield_color_b)
	_shield_bubble.flash_duration = _config.shield_duration
	_shield_bubble.radius_mult = _config.shield_radius_mult
	_shield_bubble.intensity = _config.shield_intensity

	# Hull flash — ShipRenderer's flash shader mixes toward white at hull_flash_opacity.
	# Peak RGB sliders control intensity: use max channel as opacity (1.0 = normal, 5.0 = full).
	_hull_renderer.hull_flash_opacity = maxf(maxf(_config.hull_peak_r, _config.hull_peak_g), _config.hull_peak_b) / 5.0
	_hull_renderer.hull_blink_speed = _config.hull_blink_speed
	_hull_renderer.hull_flash_duration = _config.hull_duration


func _update_ship_previews() -> void:
	var list: Array[Dictionary] = _current_ship_list()
	if list.is_empty():
		return
	var entry: Dictionary = list[_ship_index]

	if _category == 0:
		# Player ship
		var sid: int = int(entry["id"])
		_shield_renderer.ship_id = sid
		_hull_renderer.ship_id = sid
		_shield_bubble.ship_radius = ShipRenderer.get_ship_scale(sid) * 50.0
	else:
		# Enemy ship
		var vis_id: String = str(entry["visual_id"])
		_shield_renderer.ship_id = -1
		_shield_renderer.enemy_visual_id = vis_id
		_hull_renderer.ship_id = -1
		_hull_renderer.enemy_visual_id = vis_id
		_shield_bubble.ship_radius = ShipRenderer.get_ship_scale(-1) * 50.0

	_shield_renderer.render_mode = _render_mode
	_hull_renderer.render_mode = _render_mode
	_ship_label.text = str(entry["name"])
	_trigger_effects()


func _trigger_effects() -> void:
	_shield_bubble.trigger()
	_hull_renderer.trigger_hull_flash(_config.hull_duration)
	_auto_timer = 0.0


func _current_ship_list() -> Array[Dictionary]:
	if _category == 0:
		return PLAYER_SHIPS
	return ENEMY_SHIPS


# ── Ship selector callbacks ──

func _toggle_category() -> void:
	_category = 1 - _category
	_cat_btn.text = "ENEMY" if _category == 1 else "PLAYER"
	_ship_index = 0
	_update_ship_previews()


func _prev_ship() -> void:
	var list: Array[Dictionary] = _current_ship_list()
	if list.is_empty():
		return
	_ship_index = (_ship_index - 1 + list.size()) % list.size()
	_update_ship_previews()


func _next_ship() -> void:
	var list: Array[Dictionary] = _current_ship_list()
	if list.is_empty():
		return
	_ship_index = (_ship_index + 1) % list.size()
	_update_ship_previews()


func _toggle_skin() -> void:
	if _render_mode == ShipRenderer.RenderMode.CHROME:
		_render_mode = ShipRenderer.RenderMode.NEON
		_skin_btn.text = "NEON"
	else:
		_render_mode = ShipRenderer.RenderMode.CHROME
		_skin_btn.text = "CHROME"
	_shield_renderer.render_mode = _render_mode
	_hull_renderer.render_mode = _render_mode


# ── Save / Status ──

func _save_config() -> void:
	VfxConfigManager.save(_config)
	_status_label.text = "Saved!"


func _update_status() -> void:
	_status_label.text = "Shield: R%.2f G%.2f B%.2f  dur=%.2fs  rad=%.1fx  int=%.1f   |   Hull: R%.1f G%.1f B%.1f  dur=%.2fs  spd=%.1f" % [
		_config.shield_color_r, _config.shield_color_g, _config.shield_color_b,
		_config.shield_duration, _config.shield_radius_mult, _config.shield_intensity,
		_config.hull_peak_r, _config.hull_peak_g, _config.hull_peak_b,
		_config.hull_duration, _config.hull_blink_speed,
	]


# ── Styling helpers ──

func _style_panel(panel: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.9)
	sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sb)


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
