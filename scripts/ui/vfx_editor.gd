extends Control
## VFX Editor — configure hit effects for shields, hulls, and immune impacts.
## Shield sections: pick a FieldStyle + radius (field overlay on ship).
## Hull sections: configure brightness/alpha flicker parameters.
## Immune section: FieldStyle for main hit + ProjectileStyle for impact burst.

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

var _player_ship_index: int = 4  # Default to Stiletto
var _enemy_ship_index: int = 0

# All available field style IDs (shared across shield sections)
var _field_style_ids: Array[String] = []

# All available projectile style IDs (for immune impact)
var _projectile_style_ids: Array[String] = []

# Per-section state for shield sections: {config_key: {renderer, field, style_index, style_label}}
var _sections: Dictionary = {}

# Hull flicker state
var _hull_sections: Dictionary = {}  # {config_prefix: {renderer, flash_timer, ...}}

# Immune impact state
var _immune_impact_style_index: int = 0
var _immune_impact_style_label: Label

# Ship labels (all sections that have ship browsers)
var _player_ship_labels: Array[Label] = []
var _enemy_ship_labels: Array[Label] = []

# Cached ShipData for computing bounding extent in preview
var _player_ship_data: ShipData = null
var _enemy_ship_data: ShipData = null


func _ready() -> void:
	_config = VfxConfigManager.load_config()
	_field_style_ids = FieldStyleManager.list_ids()
	_field_style_ids.sort()
	_projectile_style_ids = ProjectileStyleManager.list_ids()
	_projectile_style_ids.sort()

	_player_ship_data = _load_player_ship_data(_player_ship_index)
	_enemy_ship_data = _load_enemy_ship_data(_enemy_ship_index)

	_setup_vhs_overlay()
	_build_ui()
	_update_player_ship_preview()
	_update_enemy_ship_preview()

	ThemeManager.theme_changed.connect(_on_theme_changed)


func _process(delta: float) -> void:
	_auto_timer += delta
	if _auto_timer >= AUTO_INTERVAL:
		_auto_timer = 0.0
		_trigger_effects()

	# Process hull flicker animations
	for prefix in _hull_sections:
		var sec: Dictionary = _hull_sections[prefix]
		if float(sec["flash_timer"]) > 0.0:
			_process_hull_flash(sec, delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _load_player_ship_data(index: int) -> ShipData:
	var ship_name: String = str(PLAYER_SHIPS[index]["name"]).to_lower()
	var data: ShipData = ShipDataManager.load_by_id(ship_name)
	if not data:
		data = ShipData.new()
	return data


func _load_enemy_ship_data(index: int) -> ShipData:
	var vis_id: String = str(ENEMY_SHIPS[index]["visual_id"])
	var all_enemies: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	for s in all_enemies:
		if s.visual_id == vis_id:
			return s
	return ShipData.new()


# ── UI Construction ──

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	ThemeManager.apply_grid_background(bg)

	_build_top_bar()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 60
	scroll.offset_bottom = -60
	scroll.offset_left = 20
	scroll.offset_right = -20
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	scroll.add_child(content)

	_build_shield_section(content, "PLAYER SHIELD HIT", "player_shield", false)
	_build_hull_section(content, "PLAYER HULL HIT", "player_hull", false)
	_build_shield_section(content, "ENEMY SHIELD HIT", "enemy_shield", true)
	_build_hull_section(content, "ENEMY HULL HIT", "enemy_hull", true)
	_build_immune_section(content)

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


# ── Shield Hit Section (FieldStyle + radius) ──

func _build_shield_section(parent: VBoxContainer, section_title: String, config_key: String, is_enemy: bool) -> void:
	var style_id_key: String = config_key + "_field_style_id"
	var radius_key: String = config_key + "_ratio"

	var current_style_id: String = str(_config.get(style_id_key))
	var style_index: int = 0
	if current_style_id != "":
		var idx: int = _field_style_ids.find(current_style_id)
		if idx >= 0:
			style_index = idx

	# Header with ship browser
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	parent.add_child(header_row)

	var header := Label.new()
	header.text = section_title
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)
	ThemeManager.apply_text_glow(header, "header")

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_prev_player_ship if not is_enemy else _prev_enemy_ship)
	header_row.add_child(prev_btn)
	ThemeManager.apply_button_style(prev_btn)

	var ship_label := Label.new()
	ship_label.custom_minimum_size.x = 140
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_row.add_child(ship_label)
	ThemeManager.apply_text_glow(ship_label, "body")

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_next_player_ship if not is_enemy else _next_enemy_ship)
	header_row.add_child(next_btn)
	ThemeManager.apply_button_style(next_btn)

	if not is_enemy:
		_player_ship_labels.append(ship_label)
		ship_label.text = str(PLAYER_SHIPS[_player_ship_index]["name"])
	else:
		_enemy_ship_labels.append(ship_label)
		ship_label.text = str(ENEMY_SHIPS[_enemy_ship_index]["name"]) if ENEMY_SHIPS.size() > 0 else "(none)"

	# Content row: preview panel + controls
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(280, 220)
	row.add_child(panel)
	_style_panel(panel)

	var renderer := ShipRenderer.new()
	renderer.position = Vector2(140, 110)
	renderer.scale = Vector2(0.7, 0.7)
	renderer.animate = true
	if is_enemy:
		renderer.ship_id = -1
		renderer.enemy_visual_id = str(ENEMY_SHIPS[_enemy_ship_index]["visual_id"]) if ENEMY_SHIPS.size() > 0 else "sentinel"
		renderer.render_mode = ShipRenderer.RenderMode.NEON
	else:
		renderer.ship_id = int(PLAYER_SHIPS[_player_ship_index]["id"])
		renderer.render_mode = ShipRenderer.RenderMode.CHROME
	panel.add_child(renderer)

	var field := FieldRenderer.new()
	field.position = renderer.position
	field._stay_visible = false
	field.visible = false
	panel.add_child(field)

	# Controls
	var controls_vbox := VBoxContainer.new()
	controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_vbox.add_theme_constant_override("separation", 8)
	row.add_child(controls_vbox)

	var style_label := _build_field_style_selector(controls_vbox, "Field Style", config_key)
	_build_ratio_slider(controls_vbox, radius_key, float(_config.get(radius_key)))

	_sections[config_key] = {
		"renderer": renderer,
		"field": field,
		"style_index": style_index,
		"style_label": style_label,
		"style_id_key": style_id_key,
		"radius_key": radius_key,
		"is_enemy": is_enemy,
	}

	_rebuild_field(config_key)


# ── Hull Hit Section (flicker params) ──

func _build_hull_section(parent: VBoxContainer, section_title: String, config_prefix: String, is_enemy: bool) -> void:
	# Header with ship browser
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	parent.add_child(header_row)

	var header := Label.new()
	header.text = section_title
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)
	ThemeManager.apply_text_glow(header, "header")

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_prev_player_ship if not is_enemy else _prev_enemy_ship)
	header_row.add_child(prev_btn)
	ThemeManager.apply_button_style(prev_btn)

	var ship_label := Label.new()
	ship_label.custom_minimum_size.x = 140
	ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_row.add_child(ship_label)
	ThemeManager.apply_text_glow(ship_label, "body")

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_next_player_ship if not is_enemy else _next_enemy_ship)
	header_row.add_child(next_btn)
	ThemeManager.apply_button_style(next_btn)

	if not is_enemy:
		_player_ship_labels.append(ship_label)
		ship_label.text = str(PLAYER_SHIPS[_player_ship_index]["name"])
	else:
		_enemy_ship_labels.append(ship_label)
		ship_label.text = str(ENEMY_SHIPS[_enemy_ship_index]["name"]) if ENEMY_SHIPS.size() > 0 else "(none)"

	# Content row: preview panel + controls
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(280, 220)
	row.add_child(panel)
	_style_panel(panel)

	var renderer := ShipRenderer.new()
	renderer.position = Vector2(140, 110)
	renderer.scale = Vector2(0.7, 0.7)
	renderer.animate = true
	if is_enemy:
		renderer.ship_id = -1
		renderer.enemy_visual_id = str(ENEMY_SHIPS[_enemy_ship_index]["visual_id"]) if ENEMY_SHIPS.size() > 0 else "sentinel"
		renderer.render_mode = ShipRenderer.RenderMode.NEON
	else:
		renderer.ship_id = int(PLAYER_SHIPS[_player_ship_index]["id"])
		renderer.render_mode = ShipRenderer.RenderMode.CHROME
	panel.add_child(renderer)

	# Controls — flash parameters
	var controls_vbox := VBoxContainer.new()
	controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_vbox.add_theme_constant_override("separation", 8)
	row.add_child(controls_vbox)

	var desc := Label.new()
	desc.text = "Ship brightness/alpha flicker on hit"
	controls_vbox.add_child(desc)
	ThemeManager.apply_text_glow(desc, "body")

	# Flash color (RGBA sliders)
	var color_arr: Array = _config.get(config_prefix + "_flash_color")
	var flash_color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), float(color_arr[3]))
	_build_color_row(controls_vbox, "Color R", config_prefix, 0, flash_color.r)
	_build_color_row(controls_vbox, "Color G", config_prefix, 1, flash_color.g)
	_build_color_row(controls_vbox, "Color B", config_prefix, 2, flash_color.b)

	# Flash intensity
	_build_param_slider(controls_vbox, "Intensity", config_prefix + "_flash_intensity",
		float(_config.get(config_prefix + "_flash_intensity")), 1.0, 5.0, 0.1)

	# Flash duration
	_build_param_slider(controls_vbox, "Duration", config_prefix + "_flash_duration",
		float(_config.get(config_prefix + "_flash_duration")), 0.05, 1.0, 0.05)

	# Flash count
	_build_param_slider(controls_vbox, "Flashes", config_prefix + "_flash_count",
		float(_config.get(config_prefix + "_flash_count")), 1.0, 10.0, 1.0)

	_hull_sections[config_prefix] = {
		"renderer": renderer,
		"is_enemy": is_enemy,
		"flash_timer": 0.0,
		"flash_phase": 0,
	}


# ── Immune Section ──

func _build_immune_section(parent: VBoxContainer) -> void:
	# Main immune field — reuse shield section builder
	_build_shield_section(parent, "IMMUNE HIT (Enemy)", "immune", true)

	# Immune Impact sub-section — projectile style browser
	var impact_header := Label.new()
	impact_header.text = "IMMUNE IMPACT (at hit point)"
	parent.add_child(impact_header)
	ThemeManager.apply_text_glow(impact_header, "header")

	var impact_row := HBoxContainer.new()
	impact_row.add_theme_constant_override("separation", 20)
	parent.add_child(impact_row)

	# Spacer to align with preview panels
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(280, 0)
	impact_row.add_child(spacer)

	var impact_controls := VBoxContainer.new()
	impact_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_controls.add_theme_constant_override("separation", 8)
	impact_row.add_child(impact_controls)

	var desc := Label.new()
	desc.text = "Uses impact/muzzle/trail effects from a Projectile Style"
	impact_controls.add_child(desc)
	ThemeManager.apply_text_glow(desc, "body")

	# Projectile style selector
	var current_id: String = _config.immune_impact_projectile_style_id
	_immune_impact_style_index = 0
	if current_id != "" and _projectile_style_ids.has(current_id):
		_immune_impact_style_index = _projectile_style_ids.find(current_id)

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	impact_controls.add_child(style_row)

	var lbl := Label.new()
	lbl.text = "Proj. Style"
	lbl.custom_minimum_size.x = 90
	style_row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_on_prev_immune_impact_style)
	style_row.add_child(prev_btn)
	ThemeManager.apply_button_style(prev_btn)

	_immune_impact_style_label = Label.new()
	_immune_impact_style_label.custom_minimum_size.x = 180
	_immune_impact_style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_row.add_child(_immune_impact_style_label)
	ThemeManager.apply_text_glow(_immune_impact_style_label, "body")

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_on_next_immune_impact_style)
	style_row.add_child(next_btn)
	ThemeManager.apply_button_style(next_btn)

	if _projectile_style_ids.size() > 0:
		_immune_impact_style_label.text = _projectile_style_ids[_immune_impact_style_index]
	else:
		_immune_impact_style_label.text = "(none)"

	# Effect summary label — shows what effects the selected style has
	var summary_label := Label.new()
	summary_label.name = "immune_impact_summary"
	impact_controls.add_child(summary_label)
	ThemeManager.apply_text_glow(summary_label, "body")
	_update_immune_impact_summary()

	# Scale slider
	_build_param_slider(impact_controls, "Scale", "immune_impact_scale",
		_config.immune_impact_scale, 0.1, 5.0, 0.1)


# ── Shared UI builders ──

func _build_field_style_selector(parent: VBoxContainer, label_text: String, section_key: String) -> Label:
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	parent.add_child(style_row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	style_row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_on_prev_style.bind(section_key))
	style_row.add_child(prev_btn)
	ThemeManager.apply_button_style(prev_btn)

	var style_label := Label.new()
	style_label.custom_minimum_size.x = 180
	style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_row.add_child(style_label)
	ThemeManager.apply_text_glow(style_label, "body")

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_on_next_style.bind(section_key))
	style_row.add_child(next_btn)
	ThemeManager.apply_button_style(next_btn)

	var current_id: String = str(_config.get(section_key + "_field_style_id"))
	if current_id != "" and _field_style_ids.has(current_id):
		style_label.text = current_id
	elif _field_style_ids.size() > 0:
		style_label.text = _field_style_ids[0]
	else:
		style_label.text = "(none)"

	return style_label


func _build_ratio_slider(parent: VBoxContainer, key: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Ratio"
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	slider.value_changed.connect(_on_ratio_changed.bind(key))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = key + "_val"
	val_lbl.text = "%.2f" % value
	val_lbl.custom_minimum_size.x = 50
	row.add_child(val_lbl)
	ThemeManager.apply_text_glow(val_lbl, "body")


func _build_param_slider(parent: VBoxContainer, label_text: String, config_key: String,
		value: float, min_val: float, max_val: float, step_val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	slider.value_changed.connect(_on_param_changed.bind(config_key))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = config_key + "_val"
	val_lbl.text = _format_param(value, step_val)
	val_lbl.custom_minimum_size.x = 50
	row.add_child(val_lbl)
	ThemeManager.apply_text_glow(val_lbl, "body")


func _build_color_row(parent: VBoxContainer, label_text: String, config_prefix: String,
		channel: int, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	slider.value_changed.connect(_on_color_changed.bind(config_prefix, channel))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = config_prefix + "_color_" + str(channel) + "_val"
	val_lbl.text = "%.2f" % value
	val_lbl.custom_minimum_size.x = 50
	row.add_child(val_lbl)
	ThemeManager.apply_text_glow(val_lbl, "body")


func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -50
	bar.offset_left = 20
	bar.offset_right = -20
	add_child(bar)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status_label)
	ThemeManager.apply_text_glow(_status_label, "body")
	_update_status()

	var replay_btn := Button.new()
	replay_btn.text = "REPLAY"
	replay_btn.custom_minimum_size.x = 120
	replay_btn.pressed.connect(_trigger_effects)
	bar.add_child(replay_btn)
	ThemeManager.apply_button_style(replay_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.custom_minimum_size.x = 120
	save_btn.pressed.connect(_save_config)
	bar.add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)


# ── Field style cycling (shield + immune sections) ──

func _on_prev_style(section_key: String) -> void:
	if _field_style_ids.is_empty():
		return
	var sec: Dictionary = _sections[section_key]
	var idx: int = int(sec["style_index"])
	idx = (idx - 1 + _field_style_ids.size()) % _field_style_ids.size()
	sec["style_index"] = idx
	_apply_style_change(section_key)


func _on_next_style(section_key: String) -> void:
	if _field_style_ids.is_empty():
		return
	var sec: Dictionary = _sections[section_key]
	var idx: int = int(sec["style_index"])
	idx = (idx + 1) % _field_style_ids.size()
	sec["style_index"] = idx
	_apply_style_change(section_key)


func _apply_style_change(section_key: String) -> void:
	var sec: Dictionary = _sections[section_key]
	var idx: int = int(sec["style_index"])
	var style_id: String = _field_style_ids[idx]
	var style_id_key: String = str(sec["style_id_key"])
	var label: Label = sec["style_label"] as Label
	label.text = style_id
	_config.set(style_id_key, style_id)
	_rebuild_field(section_key)
	_trigger_effects()
	_update_status()


# ── Immune impact projectile style cycling ──

func _on_prev_immune_impact_style() -> void:
	if _projectile_style_ids.is_empty():
		return
	_immune_impact_style_index = (_immune_impact_style_index - 1 + _projectile_style_ids.size()) % _projectile_style_ids.size()
	_apply_immune_impact_change()


func _on_next_immune_impact_style() -> void:
	if _projectile_style_ids.is_empty():
		return
	_immune_impact_style_index = (_immune_impact_style_index + 1) % _projectile_style_ids.size()
	_apply_immune_impact_change()


func _apply_immune_impact_change() -> void:
	var style_id: String = _projectile_style_ids[_immune_impact_style_index]
	_immune_impact_style_label.text = style_id
	_config.immune_impact_projectile_style_id = style_id
	_update_immune_impact_summary()
	_update_status()


func _update_immune_impact_summary() -> void:
	var summary_node: Label = find_child("immune_impact_summary", true, false) as Label
	if not summary_node:
		return

	var style_id: String = _config.immune_impact_projectile_style_id
	if style_id == "" or not _projectile_style_ids.has(style_id):
		summary_node.text = "No style selected"
		return

	var style: ProjectileStyle = ProjectileStyleManager.load_by_id(style_id)
	if not style:
		summary_node.text = "Style not found"
		return

	var profile: Dictionary = style.effect_profile
	if profile.is_empty():
		summary_node.text = "No effects defined"
		return

	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	var parts: Array[String] = []

	var impact_layers: Array = defaults.get("impact", []) as Array
	if impact_layers.size() > 0:
		var types: Array[String] = []
		for layer in impact_layers:
			var d: Dictionary = layer as Dictionary
			types.append(str(d.get("type", "?")))
		parts.append("Impact: " + ", ".join(types))

	var muzzle_layers: Array = defaults.get("muzzle", []) as Array
	if muzzle_layers.size() > 0:
		var types: Array[String] = []
		for layer in muzzle_layers:
			var d: Dictionary = layer as Dictionary
			types.append(str(d.get("type", "?")))
		parts.append("Muzzle: " + ", ".join(types))

	var trail_layers: Array = defaults.get("trail", []) as Array
	if trail_layers.size() > 0:
		var types: Array[String] = []
		for layer in trail_layers:
			var d: Dictionary = layer as Dictionary
			types.append(str(d.get("type", "?")))
		parts.append("Trail: " + ", ".join(types))

	if parts.is_empty():
		summary_node.text = "No impact/muzzle/trail effects"
	else:
		summary_node.text = " | ".join(parts)


# ── Parameter callbacks ──

func _on_param_changed(value: float, config_key: String) -> void:
	_config.set(config_key, value)
	var step: float = 0.1
	if config_key.ends_with("_flash_count"):
		_config.set(config_key, int(value))
		step = 1.0
	var val_node: Label = find_child(config_key + "_val", true, false) as Label
	if val_node:
		val_node.text = _format_param(value, step)
	_update_status()


func _on_color_changed(value: float, config_prefix: String, channel: int) -> void:
	var color_arr: Array = _config.get(config_prefix + "_flash_color")
	color_arr[channel] = value
	var val_node: Label = find_child(config_prefix + "_color_" + str(channel) + "_val", true, false) as Label
	if val_node:
		val_node.text = "%.2f" % value
	_update_status()


func _on_ratio_changed(value: float, key: String) -> void:
	_config.set(key, value)
	var val_node: Label = find_child(key + "_val", true, false) as Label
	if val_node:
		val_node.text = "%.2f" % value

	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if str(sec["radius_key"]) == key:
			_rebuild_field(section_key)
			break

	_trigger_effects()
	_update_status()


# ── Field rebuild (shield + immune sections only) ──

func _rebuild_field(section_key: String) -> void:
	var sec: Dictionary = _sections[section_key]
	var field: FieldRenderer = sec["field"] as FieldRenderer
	if not field:
		return

	for child in field.get_children():
		child.queue_free()

	if _field_style_ids.is_empty():
		return
	var idx: int = int(sec["style_index"])
	var style_id: String = _field_style_ids[idx]
	var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
	if not style:
		return
	var radius_key: String = str(sec["radius_key"])
	var ratio: float = float(_config.get(radius_key))
	var is_enemy: bool = bool(sec["is_enemy"])
	var extent: float = 40.0
	if is_enemy and _enemy_ship_data:
		extent = _enemy_ship_data.bounding_extent()
	elif not is_enemy and _player_ship_data:
		extent = _player_ship_data.bounding_extent()
	var radius: float = ratio * extent
	field.setup(style, radius)


# ── Preview management ──

func _update_player_ship_preview() -> void:
	if PLAYER_SHIPS.is_empty():
		return
	var entry: Dictionary = PLAYER_SHIPS[_player_ship_index]
	var sid: int = int(entry["id"])
	# Update shield sections
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if bool(sec["is_enemy"]):
			continue
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.ship_id = sid
			renderer.render_mode = ShipRenderer.RenderMode.CHROME
	# Update hull sections
	for prefix in _hull_sections:
		var sec: Dictionary = _hull_sections[prefix]
		if bool(sec["is_enemy"]):
			continue
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.ship_id = sid
			renderer.render_mode = ShipRenderer.RenderMode.CHROME
	for lbl in _player_ship_labels:
		lbl.text = str(entry["name"])
	# Reload ship data and rebuild fields so ratio preview scales correctly
	_player_ship_data = _load_player_ship_data(_player_ship_index)
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if not bool(sec["is_enemy"]):
			_rebuild_field(section_key)


func _update_enemy_ship_preview() -> void:
	if ENEMY_SHIPS.is_empty():
		return
	var entry: Dictionary = ENEMY_SHIPS[_enemy_ship_index]
	var vis_id: String = str(entry["visual_id"])
	# Update shield sections
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if not bool(sec["is_enemy"]):
			continue
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.ship_id = -1
			renderer.enemy_visual_id = vis_id
			renderer.render_mode = ShipRenderer.RenderMode.NEON
	# Update hull sections
	for prefix in _hull_sections:
		var sec: Dictionary = _hull_sections[prefix]
		if not bool(sec["is_enemy"]):
			continue
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.ship_id = -1
			renderer.enemy_visual_id = vis_id
			renderer.render_mode = ShipRenderer.RenderMode.NEON
	for lbl in _enemy_ship_labels:
		lbl.text = str(entry["name"])
	# Reload ship data and rebuild fields so ratio preview scales correctly
	_enemy_ship_data = _load_enemy_ship_data(_enemy_ship_index)
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if bool(sec["is_enemy"]):
			_rebuild_field(section_key)


func _trigger_effects() -> void:
	# Pulse shield/immune fields
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		var field: FieldRenderer = sec["field"] as FieldRenderer
		if field:
			field.pulse()
	# Start hull flash animations
	for prefix in _hull_sections:
		var sec: Dictionary = _hull_sections[prefix]
		sec["flash_timer"] = float(_config.get(prefix + "_flash_duration"))
		sec["flash_phase"] = 0
	_auto_timer = 0.0


# ── Hull flash animation ──

func _process_hull_flash(sec: Dictionary, delta: float) -> void:
	var prefix: String = ""
	for key in _hull_sections:
		if _hull_sections[key] == sec:
			prefix = key
			break
	if prefix == "":
		return

	var duration: float = float(_config.get(prefix + "_flash_duration"))
	var count: int = int(_config.get(prefix + "_flash_count"))
	var intensity: float = float(_config.get(prefix + "_flash_intensity"))
	var color_arr: Array = _config.get(prefix + "_flash_color")
	var flash_color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), 1.0)

	var timer: float = float(sec["flash_timer"])
	timer -= delta
	sec["flash_timer"] = maxf(timer, 0.0)

	if timer <= 0.0:
		# Reset to normal
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.modulate = Color.WHITE
		return

	# Calculate flash phase: oscillate between bright and normal
	var progress: float = 1.0 - (timer / duration)
	var cycle: float = progress * count * 2.0  # Each flash = bright + dark
	var phase: float = fmod(cycle, 2.0)
	var is_bright: bool = phase < 1.0

	var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
	if renderer:
		if is_bright:
			# Lerp toward flash color at intensity
			var bright_color := flash_color * intensity
			bright_color.a = 1.0
			renderer.modulate = bright_color
		else:
			renderer.modulate = Color.WHITE


# ── Ship selector callbacks ──

func _prev_player_ship() -> void:
	_player_ship_index = (_player_ship_index - 1 + PLAYER_SHIPS.size()) % PLAYER_SHIPS.size()
	_update_player_ship_preview()

func _next_player_ship() -> void:
	_player_ship_index = (_player_ship_index + 1) % PLAYER_SHIPS.size()
	_update_player_ship_preview()

func _prev_enemy_ship() -> void:
	if ENEMY_SHIPS.is_empty():
		return
	_enemy_ship_index = (_enemy_ship_index - 1 + ENEMY_SHIPS.size()) % ENEMY_SHIPS.size()
	_update_enemy_ship_preview()

func _next_enemy_ship() -> void:
	if ENEMY_SHIPS.is_empty():
		return
	_enemy_ship_index = (_enemy_ship_index + 1) % ENEMY_SHIPS.size()
	_update_enemy_ship_preview()


# ── Save / Status ──

func _save_config() -> void:
	VfxConfigManager.save(_config)
	_status_label.text = "Saved!"


func _update_status() -> void:
	var parts: Array[String] = []
	# Shield sections
	for section_key in ["player_shield", "enemy_shield", "immune"]:
		if not _sections.has(section_key):
			continue
		var sec: Dictionary = _sections[section_key]
		var style_id_key: String = str(sec["style_id_key"])
		var sid: String = str(_config.get(style_id_key))
		if sid == "":
			sid = "(none)"
		parts.append("%s: %s" % [section_key, sid])
	# Hull sections
	for prefix in ["player_hull", "enemy_hull"]:
		var count: int = int(_config.get(prefix + "_flash_count"))
		var intensity: float = float(_config.get(prefix + "_flash_intensity"))
		parts.append("%s: %dx @ %.1f" % [prefix, count, intensity])
	# Immune impact
	var impact_id: String = _config.immune_impact_projectile_style_id
	if impact_id == "":
		impact_id = "(none)"
	parts.append("impact: %s" % impact_id)
	_status_label.text = "  |  ".join(parts)


# ── Styling helpers ──

func _style_panel(panel: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.9)
	sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
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


func _format_param(value: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(value)
	elif step >= 0.1:
		return "%.1f" % value
	else:
		return "%.2f" % value
