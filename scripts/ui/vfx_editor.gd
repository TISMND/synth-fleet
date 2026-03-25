extends Control
## VFX Editor — four live previews: Player Shield/Hull + Enemy Shield/Hull.
## Browses player ship designs + enemy ships by renderer ID, with skin toggle.

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
var _player_skin: int = ShipRenderer.RenderMode.CHROME
var _enemy_skin: int = ShipRenderer.RenderMode.NEON

# Preview nodes — player
var _player_shield_renderer: ShipRenderer
var _player_shield_bubble: ShieldBubbleEffect
var _player_hull_renderer: ShipRenderer
# Preview nodes — enemy
var _enemy_shield_renderer: ShipRenderer
var _enemy_shield_bubble: ShieldBubbleEffect
var _enemy_hull_renderer: ShipRenderer
# Preview nodes — immune
var _immune_renderer: ShipRenderer
var _immune_bubble: ShieldBubbleEffect

# Ship labels
var _player_ship_label: Label
var _enemy_ship_label: Label

# Slider references for live update
var _sliders: Dictionary = {}  # key -> HSlider


func _ready() -> void:
	_config = VfxConfigManager.load_config()
	_setup_vhs_overlay()
	_build_ui()
	_apply_config_to_previews()
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

	# Scrollable content area for four sections
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

	_build_player_shield_section(content)
	_build_player_hull_section(content)
	_build_enemy_shield_section(content)
	_build_enemy_hull_section(content)
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


func _build_section(parent: VBoxContainer, section_title: String, is_shield: bool, is_enemy: bool) -> void:
	# Section header with ship selector
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	parent.add_child(header_row)

	var header := Label.new()
	header.text = section_title
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)
	ThemeManager.apply_text_glow(header, "header")

	# Ship browsing controls
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
		_player_ship_label = ship_label
		ship_label.text = str(PLAYER_SHIPS[0]["name"])
	else:
		_enemy_ship_label = ship_label
		ship_label.text = str(ENEMY_SHIPS[0]["name"]) if ENEMY_SHIPS.size() > 0 else "(none)"

	# Content row: preview panel (left) + sliders (right)
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
	panel.add_child(renderer)

	var bubble: ShieldBubbleEffect = null
	if is_shield:
		bubble = ShieldBubbleEffect.new()
		bubble.position = renderer.position
		panel.add_child(bubble)

	# Store references
	if not is_enemy:
		if is_shield:
			_player_shield_renderer = renderer
			_player_shield_bubble = bubble
		else:
			_player_hull_renderer = renderer
	else:
		if is_shield:
			_enemy_shield_renderer = renderer
			_enemy_shield_bubble = bubble
		else:
			_enemy_hull_renderer = renderer
		renderer.render_mode = ShipRenderer.RenderMode.NEON

	# Sliders
	var slider_vbox := VBoxContainer.new()
	slider_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_vbox.add_theme_constant_override("separation", 4)
	row.add_child(slider_vbox)

	if is_shield:
		var prefix: String = "enemy_" if is_enemy else ""
		_add_slider_row_vbox(slider_vbox, prefix + "shield_color_r", "Color R", 0.0, 1.0, _config.get(prefix + "shield_color_r"))
		_add_slider_row_vbox(slider_vbox, prefix + "shield_color_g", "Color G", 0.0, 1.0, _config.get(prefix + "shield_color_g"))
		_add_slider_row_vbox(slider_vbox, prefix + "shield_color_b", "Color B", 0.0, 1.0, _config.get(prefix + "shield_color_b"))
		_add_slider_row_vbox(slider_vbox, prefix + "shield_duration", "Duration", 0.05, 0.5, _config.get(prefix + "shield_duration"))
		_add_slider_row_vbox(slider_vbox, prefix + "shield_radius_mult", "Radius", 0.5, 2.0, _config.get(prefix + "shield_radius_mult"))
		_add_slider_row_vbox(slider_vbox, prefix + "shield_intensity", "Intensity", 0.2, 2.0, _config.get(prefix + "shield_intensity"))
	else:
		var prefix: String = "enemy_" if is_enemy else ""
		_add_slider_row_vbox(slider_vbox, prefix + "hull_peak_r", "Peak R", 1.0, 5.0, _config.get(prefix + "hull_peak_r"))
		_add_slider_row_vbox(slider_vbox, prefix + "hull_peak_g", "Peak G", 1.0, 5.0, _config.get(prefix + "hull_peak_g"))
		_add_slider_row_vbox(slider_vbox, prefix + "hull_peak_b", "Peak B", 1.0, 5.0, _config.get(prefix + "hull_peak_b"))
		_add_slider_row_vbox(slider_vbox, prefix + "hull_duration", "Duration", 0.04, 0.4, _config.get(prefix + "hull_duration"))
		_add_slider_row_vbox(slider_vbox, prefix + "hull_blink_speed", "Blink Speed", 2.0, 14.0, _config.get(prefix + "hull_blink_speed"))


func _build_player_shield_section(parent: VBoxContainer) -> void:
	_build_section(parent, "PLAYER SHIELD HIT", true, false)

func _build_player_hull_section(parent: VBoxContainer) -> void:
	_build_section(parent, "PLAYER HULL FLASH", false, false)

func _build_enemy_shield_section(parent: VBoxContainer) -> void:
	_build_section(parent, "ENEMY SHIELD HIT", true, true)

func _build_enemy_hull_section(parent: VBoxContainer) -> void:
	_build_section(parent, "ENEMY HULL FLASH", false, true)


func _build_immune_section(parent: VBoxContainer) -> void:
	# Header (no ship browser — immune effect is universal)
	var header := Label.new()
	header.text = "IMMUNE HIT"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)
	ThemeManager.apply_text_glow(header, "header")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	# Preview panel
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(280, 220)
	row.add_child(panel)
	_style_panel(panel)

	_immune_renderer = ShipRenderer.new()
	_immune_renderer.position = Vector2(140, 110)
	_immune_renderer.scale = Vector2(0.7, 0.7)
	_immune_renderer.animate = true
	_immune_renderer.ship_id = 4  # Stiletto
	_immune_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	panel.add_child(_immune_renderer)

	_immune_bubble = ShieldBubbleEffect.new()
	_immune_bubble.position = _immune_renderer.position
	_immune_bubble.ship_radius = ShipRenderer.get_ship_scale(4) * 50.0
	panel.add_child(_immune_bubble)

	# Sliders
	var slider_vbox := VBoxContainer.new()
	slider_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_vbox.add_theme_constant_override("separation", 4)
	row.add_child(slider_vbox)

	_add_slider_row_vbox(slider_vbox, "immune_color_r", "Color R", 0.0, 1.0, _config.immune_color_r)
	_add_slider_row_vbox(slider_vbox, "immune_color_g", "Color G", 0.0, 1.0, _config.immune_color_g)
	_add_slider_row_vbox(slider_vbox, "immune_color_b", "Color B", 0.0, 1.0, _config.immune_color_b)
	_add_slider_row_vbox(slider_vbox, "immune_duration", "Duration", 0.05, 0.5, _config.immune_duration)
	_add_slider_row_vbox(slider_vbox, "immune_radius_mult", "Radius", 0.5, 2.0, _config.immune_radius_mult)
	_add_slider_row_vbox(slider_vbox, "immune_intensity", "Intensity", 0.2, 2.0, _config.immune_intensity)


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


# ── Slider factory ──

func _add_slider_row_vbox(parent: VBoxContainer, key: String, label_text: String, min_val: float, max_val: float, value: float) -> void:
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
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	_sliders[key] = slider

	var val_lbl := Label.new()
	val_lbl.name = key + "_val"
	val_lbl.text = "%.2f" % value
	val_lbl.custom_minimum_size.x = 50
	row.add_child(val_lbl)
	ThemeManager.apply_text_glow(val_lbl, "body")


func _on_slider_changed(value: float, key: String) -> void:
	_config.set(key, value)

	var val_node: Label = find_child(key + "_val", true, false) as Label
	if val_node:
		val_node.text = "%.2f" % value

	_apply_config_to_previews()
	_trigger_effects()
	_update_status()


# ── Preview management ──

func _apply_config_to_previews() -> void:
	# Player shield
	_player_shield_bubble.shield_color = Color(_config.shield_color_r, _config.shield_color_g, _config.shield_color_b)
	_player_shield_bubble.flash_duration = _config.shield_duration
	_player_shield_bubble.radius_mult = _config.shield_radius_mult
	_player_shield_bubble.intensity = _config.shield_intensity

	# Player hull
	_player_hull_renderer.hull_flash_opacity = maxf(maxf(_config.hull_peak_r, _config.hull_peak_g), _config.hull_peak_b) / 5.0
	_player_hull_renderer.hull_blink_speed = _config.hull_blink_speed
	_player_hull_renderer.hull_flash_duration = _config.hull_duration

	# Enemy shield
	_enemy_shield_bubble.shield_color = Color(_config.enemy_shield_color_r, _config.enemy_shield_color_g, _config.enemy_shield_color_b)
	_enemy_shield_bubble.flash_duration = _config.enemy_shield_duration
	_enemy_shield_bubble.radius_mult = _config.enemy_shield_radius_mult
	_enemy_shield_bubble.intensity = _config.enemy_shield_intensity

	# Enemy hull
	_enemy_hull_renderer.hull_flash_opacity = maxf(maxf(_config.enemy_hull_peak_r, _config.enemy_hull_peak_g), _config.enemy_hull_peak_b) / 5.0
	_enemy_hull_renderer.hull_blink_speed = _config.enemy_hull_blink_speed
	_enemy_hull_renderer.hull_flash_duration = _config.enemy_hull_duration

	# Immune
	if _immune_bubble:
		_immune_bubble.shield_color = Color(_config.immune_color_r, _config.immune_color_g, _config.immune_color_b)
		_immune_bubble.flash_duration = _config.immune_duration
		_immune_bubble.radius_mult = _config.immune_radius_mult
		_immune_bubble.intensity = _config.immune_intensity


func _update_player_ship_preview() -> void:
	if PLAYER_SHIPS.is_empty():
		return
	var entry: Dictionary = PLAYER_SHIPS[_player_ship_index]
	var sid: int = int(entry["id"])
	_player_shield_renderer.ship_id = sid
	_player_hull_renderer.ship_id = sid
	_player_shield_renderer.render_mode = _player_skin
	_player_hull_renderer.render_mode = _player_skin
	_player_shield_bubble.ship_radius = ShipRenderer.get_ship_scale(sid) * 50.0
	_player_ship_label.text = str(entry["name"])


func _update_enemy_ship_preview() -> void:
	if ENEMY_SHIPS.is_empty():
		return
	var entry: Dictionary = ENEMY_SHIPS[_enemy_ship_index]
	var vis_id: String = str(entry["visual_id"])
	_enemy_shield_renderer.ship_id = -1
	_enemy_shield_renderer.enemy_visual_id = vis_id
	_enemy_hull_renderer.ship_id = -1
	_enemy_hull_renderer.enemy_visual_id = vis_id
	_enemy_shield_renderer.render_mode = _enemy_skin
	_enemy_hull_renderer.render_mode = _enemy_skin
	_enemy_shield_bubble.ship_radius = ShipRenderer.get_ship_scale(-1) * 50.0
	_enemy_ship_label.text = str(entry["name"])


func _trigger_effects() -> void:
	_player_shield_bubble.trigger()
	_player_hull_renderer.trigger_hull_flash(_config.hull_duration)
	_enemy_shield_bubble.trigger()
	_enemy_hull_renderer.trigger_hull_flash(_config.enemy_hull_duration)
	if _immune_bubble:
		_immune_bubble.trigger()
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
	_status_label.text = "Player: shd=%.2fs hull=%.2fs  |  Enemy: shd=%.2fs hull=%.2fs" % [
		_config.shield_duration, _config.hull_duration,
		_config.enemy_shield_duration, _config.enemy_hull_duration,
	]


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
