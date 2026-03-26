extends Control
## VFX Editor — five field-style-based hit effect previews.
## Each section: pick a FieldStyle from dev studio + set radius.
## Immune section adds a second "impact" field style at point of contact.

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

# All available field style IDs (shared across sections)
var _field_style_ids: Array[String] = []

# Per-section state: {config_key: {renderer, field, style_index, style_label}}
var _sections: Dictionary = {}

# Ship labels
var _player_ship_label: Label
var _enemy_ship_label: Label


func _ready() -> void:
	_config = VfxConfigManager.load_config()
	_field_style_ids = FieldStyleManager.list_ids()
	_field_style_ids.sort()

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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


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

	_build_hit_section(content, "PLAYER SHIELD HIT", "player_shield", false)
	_build_hit_section(content, "PLAYER HULL HIT", "player_hull", false)
	_build_hit_section(content, "ENEMY SHIELD HIT", "enemy_shield", true)
	_build_hit_section(content, "ENEMY HULL HIT", "enemy_hull", true)
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


func _build_hit_section(parent: VBoxContainer, section_title: String, config_key: String, is_enemy: bool) -> void:
	## Builds one hit section: header with ship browser, preview panel with FieldRenderer,
	## field style picker + radius slider.
	var style_id_key: String = config_key + "_field_style_id"
	var radius_key: String = config_key + "_radius"

	# Find initial style index from config
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
		if not _player_ship_label:
			_player_ship_label = ship_label
		ship_label.text = str(PLAYER_SHIPS[_player_ship_index]["name"])
	else:
		if not _enemy_ship_label:
			_enemy_ship_label = ship_label
		ship_label.text = str(ENEMY_SHIPS[_enemy_ship_index]["name"]) if ENEMY_SHIPS.size() > 0 else "(none)"

	# Content row: preview panel + controls
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	# Preview panel
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
	panel.add_child(field)

	# Controls
	var controls_vbox := VBoxContainer.new()
	controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_vbox.add_theme_constant_override("separation", 8)
	row.add_child(controls_vbox)

	# Field style selector
	var style_label := _build_style_selector(controls_vbox, "Field Style", config_key)

	# Radius slider
	_build_radius_slider(controls_vbox, radius_key, float(_config.get(radius_key)))

	# Store section state
	_sections[config_key] = {
		"renderer": renderer,
		"field": field,
		"style_index": style_index,
		"style_label": style_label,
		"style_id_key": style_id_key,
		"radius_key": radius_key,
		"is_enemy": is_enemy,
	}

	# Build initial field
	_rebuild_field(config_key)


func _build_immune_section(parent: VBoxContainer) -> void:
	# Build the main immune field section using shared pattern
	_build_hit_section(parent, "IMMUNE HIT (Enemy)", "immune", true)

	# Add the immune impact sub-section (second field style + radius within same section)
	var sec: Dictionary = _sections["immune"]

	# Find the controls vbox — it's the last child of the content row
	var content_row: HBoxContainer = sec["field"].get_parent().get_parent() as HBoxContainer
	# Actually, need to find the controls_vbox from the row. Let me add it differently.
	# The impact controls go below the immune section as a nested row.

	var impact_row := HBoxContainer.new()
	impact_row.add_theme_constant_override("separation", 20)
	parent.add_child(impact_row)

	# Spacer to align with preview panel
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(280, 0)
	impact_row.add_child(spacer)

	var impact_controls := VBoxContainer.new()
	impact_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_controls.add_theme_constant_override("separation", 8)
	impact_row.add_child(impact_controls)

	var impact_header := Label.new()
	impact_header.text = "IMMUNE IMPACT (at hit point)"
	impact_controls.add_child(impact_header)
	ThemeManager.apply_text_glow(impact_header, "body")

	# Impact style index
	var current_impact_id: String = _config.immune_impact_field_style_id
	var impact_index: int = 0
	if current_impact_id != "":
		var idx: int = _field_style_ids.find(current_impact_id)
		if idx >= 0:
			impact_index = idx

	var impact_style_label := _build_style_selector(impact_controls, "Impact Style", "immune_impact")
	_build_radius_slider(impact_controls, "immune_impact_radius", _config.immune_impact_radius)

	_sections["immune_impact"] = {
		"renderer": null,
		"field": null,
		"style_index": impact_index,
		"style_label": impact_style_label,
		"style_id_key": "immune_impact_field_style_id",
		"radius_key": "immune_impact_radius",
		"is_enemy": true,
	}


# ── Shared UI builders ──

func _build_style_selector(parent: VBoxContainer, label_text: String, section_key: String) -> Label:
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

	# Set initial text
	var current_id: String = str(_config.get(section_key + "_field_style_id"))
	if current_id != "" and _field_style_ids.has(current_id):
		style_label.text = current_id
	elif _field_style_ids.size() > 0:
		style_label.text = _field_style_ids[0]
	else:
		style_label.text = "(none)"

	return style_label


func _build_radius_slider(parent: VBoxContainer, key: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Radius"
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "body")

	var slider := HSlider.new()
	slider.min_value = 10.0
	slider.max_value = 200.0
	slider.step = 1.0
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	slider.value_changed.connect(_on_radius_changed.bind(key))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = key + "_val"
	val_lbl.text = "%.0f" % value
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


# ── Style cycling ──

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


# ── Radius slider ──

func _on_radius_changed(value: float, key: String) -> void:
	_config.set(key, value)
	var val_node: Label = find_child(key + "_val", true, false) as Label
	if val_node:
		val_node.text = "%.0f" % value

	# Find which section this radius belongs to and rebuild its field
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if str(sec["radius_key"]) == key:
			_rebuild_field(section_key)
			break

	_trigger_effects()
	_update_status()


# ── Field rebuild ──

func _rebuild_field(section_key: String) -> void:
	var sec: Dictionary = _sections[section_key]
	var field: FieldRenderer = sec["field"] as FieldRenderer
	if not field:
		return  # immune_impact has no preview field

	# Remove old sprite children
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
	var radius: float = float(_config.get(radius_key))
	field.setup(style, radius)


# ── Preview management ──

func _update_player_ship_preview() -> void:
	if PLAYER_SHIPS.is_empty():
		return
	var entry: Dictionary = PLAYER_SHIPS[_player_ship_index]
	var sid: int = int(entry["id"])
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if bool(sec["is_enemy"]):
			continue
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.ship_id = sid
			renderer.render_mode = ShipRenderer.RenderMode.CHROME
	if _player_ship_label:
		_player_ship_label.text = str(entry["name"])


func _update_enemy_ship_preview() -> void:
	if ENEMY_SHIPS.is_empty():
		return
	var entry: Dictionary = ENEMY_SHIPS[_enemy_ship_index]
	var vis_id: String = str(entry["visual_id"])
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		if not bool(sec["is_enemy"]):
			continue
		var renderer: ShipRenderer = sec["renderer"] as ShipRenderer
		if renderer:
			renderer.ship_id = -1
			renderer.enemy_visual_id = vis_id
			renderer.render_mode = ShipRenderer.RenderMode.NEON
	if _enemy_ship_label:
		_enemy_ship_label.text = str(entry["name"])


func _trigger_effects() -> void:
	for section_key in _sections:
		var sec: Dictionary = _sections[section_key]
		var field: FieldRenderer = sec["field"] as FieldRenderer
		if field:
			field.pulse()
	_auto_timer = 0.0


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
	for section_key in ["player_shield", "player_hull", "enemy_shield", "enemy_hull", "immune"]:
		if not _sections.has(section_key):
			continue
		var sec: Dictionary = _sections[section_key]
		var style_id_key: String = str(sec["style_id_key"])
		var sid: String = str(_config.get(style_id_key))
		if sid == "":
			sid = "(none)"
		parts.append("%s: %s" % [section_key, sid])
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
