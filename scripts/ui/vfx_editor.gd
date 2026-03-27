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

# Impact types available for immune impact dropdown
const IMPACT_TYPES: Array[String] = ["", "burst", "ring_expand", "shatter_lines", "nova_flash", "ripple", "deflect"]
const IMPACT_TYPE_LABELS: Array[String] = ["(None)", "Burst", "Ring Expand", "Shatter Lines", "Nova Flash", "Ripple", "Deflect (TV Off)"]

# Per-section state for shield sections: {config_key: {renderer, field, style_id_key, radius_key, is_enemy}}
var _sections: Dictionary = {}

# Hull flicker state
var _hull_sections: Dictionary = {}  # {config_prefix: {renderer, flash_timer, ...}}

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

	_build_field_style_dropdown(controls_vbox, "Field Style", config_key)
	_build_ratio_slider(controls_vbox, radius_key, float(_config.get(radius_key)))
	var dur_key: String = config_key + "_pulse_duration"
	var dur_val: Variant = _config.get(dur_key)
	if dur_val != null:
		_build_param_slider(controls_vbox, "Duration", dur_key, float(dur_val), 0.05, 2.0, 0.05)

	_sections[config_key] = {
		"renderer": renderer,
		"field": field,
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

	# Immune Impact sub-section — direct impact effect config
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

	# Impact type dropdown
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	impact_controls.add_child(type_row)

	var type_lbl := Label.new()
	type_lbl.text = "Type"
	type_lbl.custom_minimum_size.x = 90
	type_row.add_child(type_lbl)
	ThemeManager.apply_text_glow(type_lbl, "body")

	var type_dropdown := OptionButton.new()
	type_dropdown.custom_minimum_size.x = 220
	for i in IMPACT_TYPE_LABELS.size():
		type_dropdown.add_item(IMPACT_TYPE_LABELS[i], i)
	var current_type_idx: int = IMPACT_TYPES.find(_config.immune_impact_type)
	if current_type_idx >= 0:
		type_dropdown.select(current_type_idx)
	else:
		type_dropdown.select(0)
	type_dropdown.item_selected.connect(_on_immune_impact_type_selected)
	type_row.add_child(type_dropdown)
	ThemeManager.apply_button_style(type_dropdown)

	# Impact color
	var color_arr: Array = _config.immune_impact_color
	_build_impact_color_row(impact_controls, "Color R", 0, float(color_arr[0]))
	_build_impact_color_row(impact_controls, "Color G", 1, float(color_arr[1]))
	_build_impact_color_row(impact_controls, "Color B", 2, float(color_arr[2]))

	# Impact params
	_build_param_slider(impact_controls, "Particles", "immune_impact_particle_count",
		float(_config.immune_impact_particle_count), 1.0, 30.0, 1.0)
	_build_param_slider(impact_controls, "Lifetime", "immune_impact_lifetime",
		_config.immune_impact_lifetime, 0.05, 1.0, 0.05)
	_build_param_slider(impact_controls, "Radius", "immune_impact_radius",
		_config.immune_impact_radius, 5.0, 60.0, 1.0)
	_build_param_slider(impact_controls, "Speed", "immune_impact_speed_scale",
		_config.immune_impact_speed_scale, 0.1, 3.0, 0.1)


# ── Shared UI builders ──

func _build_field_style_dropdown(parent: VBoxContainer, label_text: String, section_key: String) -> OptionButton:
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	parent.add_child(style_row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	style_row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var dropdown := OptionButton.new()
	dropdown.custom_minimum_size.x = 220
	dropdown.add_item("(None)", 0)
	for i in _field_style_ids.size():
		dropdown.add_item(_field_style_ids[i], i + 1)
	style_row.add_child(dropdown)
	ThemeManager.apply_button_style(dropdown)

	# Select current value
	var current_id: String = str(_config.get(section_key + "_field_style_id"))
	if current_id != "" and _field_style_ids.has(current_id):
		dropdown.select(_field_style_ids.find(current_id) + 1)
	else:
		dropdown.select(0)

	dropdown.item_selected.connect(_on_field_style_selected.bind(section_key))
	return dropdown


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


func _build_impact_color_row(parent: VBoxContainer, label_text: String, channel: int, value: float) -> void:
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
	slider.value_changed.connect(_on_impact_color_changed.bind(channel))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = "immune_impact_color_" + str(channel) + "_val"
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


# ── Field style dropdown callback ──

func _on_field_style_selected(index: int, section_key: String) -> void:
	var style_id: String = ""
	if index > 0 and index - 1 < _field_style_ids.size():
		style_id = _field_style_ids[index - 1]
	var sec: Dictionary = _sections[section_key]
	var style_id_key: String = str(sec["style_id_key"])
	_config.set(style_id_key, style_id)
	_rebuild_field(section_key)
	_trigger_effects()
	_update_status()


# ── Immune impact type dropdown callback ──

func _on_immune_impact_type_selected(index: int) -> void:
	_config.immune_impact_type = IMPACT_TYPES[index]
	_update_status()


func _on_impact_color_changed(value: float, channel: int) -> void:
	_config.immune_impact_color[channel] = value
	var val_node: Label = find_child("immune_impact_color_" + str(channel) + "_val", true, false) as Label
	if val_node:
		val_node.text = "%.2f" % value
	_update_status()


# ── Parameter callbacks ──

func _on_param_changed(value: float, config_key: String) -> void:
	_config.set(config_key, value)
	var step: float = 0.1
	if config_key.ends_with("_flash_count") or config_key.ends_with("_particle_count"):
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

	var style_id_key: String = str(sec["style_id_key"])
	var style_id: String = str(_config.get(style_id_key))
	if style_id == "":
		return
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
	var dur_key: String = section_key + "_pulse_duration"
	var dur_val: Variant = _config.get(dur_key)
	if dur_val != null and float(dur_val) > 0.0:
		style.pulse_total_duration = float(dur_val)
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
	var impact_type: String = _config.immune_impact_type
	if impact_type == "":
		impact_type = "(none)"
	parts.append("impact: %s" % impact_type)
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
