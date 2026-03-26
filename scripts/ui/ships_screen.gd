extends Control
## Ships screen — configuration and preview.
## Left panel: ship selection. Center: ship preview (WASD movement).
## Right panel: attribute sliders + skin dropdown + save. Bottom: HUD replica.

const SKIN_NAMES: Array[String] = ["CHROME", "NEON", "VOID", "HIVEMIND", "SPORE", "EMBER", "FROST", "SOLAR", "SPORT", "GUNMETAL", "MILITIA", "STEALTH"]
const SKIN_KEYS: Array[String] = ["chrome", "neon", "void", "hivemind", "spore", "ember", "frost", "solar", "sport", "gunmetal", "militia", "stealth"]

const BANK_LERP := 6.0
const LEFT_PANEL_W := 200.0
const RIGHT_PANEL_W := 280.0
const HUD_HEIGHT := 110.0

var _accel := 1200.0
var _top_speed := 400.0
var _velocity := 0.0
var _velocity_y := 0.0
var _bank := 0.0
var _ship_draw: Node2D
var _exhaust_draw: Node2D
var _exhaust_particles: Array[Dictionary] = []
var _exhaust_timer := 0.0
var _ship_selector: Node2D
var _selected_ship := 0
var _vhs_overlay: ColorRect
var _hud_replica: Control = null  # Compact horizontal bar strip (not the game HUD)
var _compact_bars: Dictionary = {}  # bar_name -> {bar: ProgressBar, label: Label}
var _compact_bar_segments: Dictionary = {}  # bar_name -> int
var _right_panel: Panel = null
var _sliders: Dictionary = {}  # key -> HSlider
var _slider_labels: Dictionary = {}  # key -> Label
var _working_stats: Dictionary = {}
var _updating_sliders := false
var _skin_dropdown: OptionButton = null
var _working_render_mode: String = "chrome"

# Category system
var _category: String = "PLAYER"  # "PLAYER", "ENEMIES", "BOSSES"
var _category_tab_buttons: Array[Button] = []
var _level_dropdown: OptionButton = null
var _selected_level: String = "geometric"
const LEVEL_OPTIONS: Array[Dictionary] = [
	{"id": "geometric", "label": "GEOMETRIC"},
	{"id": "vehicle", "label": "VEHICLE"},
	{"id": "lifeform", "label": "LIFEFORM"},
	{"id": "boss", "label": "BOSS"},
]
var _enemy_ships: Array[ShipData] = []  # all enemies
var _filtered_enemy_ships: Array[ShipData] = []  # filtered by level
var _selected_enemy_index: int = -1
var _working_enemy: ShipData = null
var _enemy_idle_time: float = 0.0
var _enemy_tab: String = "stats"  # "stats" or "effects"
# Boss state
var _boss_list: Array[BossData] = []
var _filtered_boss_list: Array[BossData] = []
var _selected_boss_index: int = -1
var _working_boss: BossData = null
var _boss_tab: String = "core"  # "core", "segments", "enrage"
var _selected_segment_index: int = -1
var _boss_preview_nodes: Array = []  # ShipRenderers in viewport for composite preview
var _explosion_color_rect: ColorRect = null
var _enemy_weapon_dropdown: OptionButton = null
var _explosion_preview: Node2D = null
var _hitbox_overlay: Node2D = null
var _hitbox_shape_dropdown: OptionButton = null
var _weapon_preview_btn: Button = null
var _weapon_preview_active: bool = false
var _weapon_preview_container: Node2D = null
var _weapon_preview_fire_point: Node2D = null
var _ship_viewport: SubViewport = null
var _ship_grid_bg: ColorRect = null
var _weapon_preview_controller: HardpointController = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Ship rendering goes in its own SubViewport with ACES bloom.
	# UI panels (left/right/bottom) stay on root and render on top.
	var svc := SubViewportContainer.new()
	svc.name = "ShipViewportContainer"
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	_ship_viewport = SubViewport.new()
	_ship_viewport.name = "ShipViewport"
	_ship_viewport.size = Vector2i(1920, 1080)
	_ship_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ship_viewport.transparent_bg = false
	svc.add_child(_ship_viewport)
	VFXFactory.add_bloom_to_viewport(_ship_viewport)

	# Grid background inside SubViewport
	_ship_grid_bg = ColorRect.new()
	_ship_grid_bg.size = Vector2(1920, 1080)
	_ship_grid_bg.z_index = -10
	_ship_viewport.add_child(_ship_grid_bg)
	ThemeManager.apply_grid_background(_ship_grid_bg)

	_exhaust_draw = _ExhaustDraw.new()
	_exhaust_draw.viewer = self
	_ship_viewport.add_child(_exhaust_draw)

	_ship_draw = ShipRenderer.new()
	_ship_viewport.add_child(_ship_draw)

	_weapon_preview_container = Node2D.new()
	_ship_viewport.add_child(_weapon_preview_container)

	_hitbox_overlay = _HitboxOverlay.new()
	_hitbox_overlay.viewer = self
	_ship_viewport.add_child(_hitbox_overlay)

	_ship_selector = _ShipSelector.new()
	_ship_selector.viewer = self
	add_child(_ship_selector)

	# Category tab bar (top of screen)
	var tab_bar := HBoxContainer.new()
	tab_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_bar.offset_left = LEFT_PANEL_W
	tab_bar.offset_right = -RIGHT_PANEL_W
	tab_bar.offset_top = 0
	tab_bar.offset_bottom = 36
	tab_bar.add_theme_constant_override("separation", 0)
	add_child(tab_bar)

	var tab_names: Array[String] = ["PLAYER", "ENEMIES", "BOSSES"]
	for tab_name in tab_names:
		var btn := Button.new()
		btn.text = tab_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 36
		var cat_id: String = tab_name
		btn.pressed.connect(func() -> void: _switch_category(cat_id))
		ThemeManager.apply_button_style(btn)
		tab_bar.add_child(btn)
		_category_tab_buttons.append(btn)
	_update_category_tab_buttons()

	# Level filter dropdown on left panel (visible for ENEMIES/BOSSES)
	_level_dropdown = OptionButton.new()
	for opt in LEVEL_OPTIONS:
		var lbl: String = opt["label"]
		_level_dropdown.add_item(lbl)
	_level_dropdown.selected = 0
	_level_dropdown.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_level_dropdown.offset_left = 4
	_level_dropdown.offset_top = 6
	_level_dropdown.offset_right = LEFT_PANEL_W - 4
	_level_dropdown.offset_bottom = 40
	_level_dropdown.item_selected.connect(_on_level_changed)
	_level_dropdown.visible = false
	add_child(_level_dropdown)
	ThemeManager.apply_button_style(_level_dropdown)

	# Center ship in preview area (between left panel, right panel, above HUD)
	var vp_size: Vector2 = get_viewport_rect().size
	var cx: float = LEFT_PANEL_W + (vp_size.x - LEFT_PANEL_W - RIGHT_PANEL_W) * 0.5
	var cy: float = (vp_size.y - HUD_HEIGHT) * 0.5
	_ship_draw.position = Vector2(cx, cy)

	_build_right_panel()
	_build_hud_replica()
	_load_enemy_ships()
	_load_bosses()
	_select_ship(0)


func _exit_tree() -> void:
	_stop_weapon_preview()


func _process(delta: float) -> void:
	if _category == "ENEMIES":
		_process_enemy(delta)
		return
	if _category == "BOSSES":
		# Boss preview is static composite — no per-frame ship movement needed
		return

	var input_dir := 0.0
	if Input.is_action_pressed("move_left"):
		input_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir += 1.0

	var input_dir_y := 0.0
	if Input.is_action_pressed("move_up"):
		input_dir_y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir_y += 1.0

	if input_dir != 0.0:
		_velocity = move_toward(_velocity, input_dir * _top_speed, _accel * delta)
	else:
		_velocity = move_toward(_velocity, 0.0, _accel * delta)

	if input_dir_y != 0.0:
		_velocity_y = move_toward(_velocity_y, input_dir_y * _top_speed, _accel * delta)
	else:
		_velocity_y = move_toward(_velocity_y, 0.0, _accel * delta)

	_ship_draw.position.x += _velocity * delta
	_ship_draw.position.y += _velocity_y * delta
	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position.x = clampf(_ship_draw.position.x, LEFT_PANEL_W + 60.0, vp_size.x - RIGHT_PANEL_W - 60.0)
	_ship_draw.position.y = clampf(_ship_draw.position.y, 60.0, vp_size.y - HUD_HEIGHT - 60.0)

	var target_bank: float = -_velocity / maxf(_top_speed, 1.0)
	_bank = lerpf(_bank, target_bank, BANK_LERP * delta)
	_ship_draw.bank = _bank
	_ship_draw.ship_id = _selected_ship
	_ship_draw.show_hardpoint_marker = false

	_exhaust_timer += delta
	if _exhaust_timer > 0.016:
		_exhaust_timer = 0.0
		_spawn_exhaust()
	_update_exhaust(delta)
	_exhaust_draw.queue_redraw()
	_hitbox_overlay.queue_redraw()


func _process_enemy(delta: float) -> void:
	_enemy_idle_time += delta
	var vp_size: Vector2 = get_viewport_rect().size
	var cx: float = LEFT_PANEL_W + (vp_size.x - LEFT_PANEL_W - RIGHT_PANEL_W) * 0.5
	var cy: float = (vp_size.y - HUD_HEIGHT) * 0.5
	_ship_draw.position = Vector2(cx, cy + sin(_enemy_idle_time * 1.5) * 3.0)
	_ship_draw.bank = 0.0
	_ship_draw.ship_id = -1  # Signal enemy drawing mode
	_exhaust_particles.clear()
	_exhaust_draw.queue_redraw()

	# Keep weapon preview fire point synced to ship position
	if _weapon_preview_fire_point and is_instance_valid(_weapon_preview_fire_point):
		_weapon_preview_fire_point.position = _ship_draw.position + Vector2(0, 20)
	_hitbox_overlay.queue_redraw()


func _spawn_exhaust() -> void:
	var ship_pos: Vector2 = _ship_draw.position
	var s: float = ShipRenderer.get_ship_scale(_selected_ship)
	var x_shift: float = _bank * 2.5 * s
	var engines: Array[Vector2] = ShipRenderer.get_engine_offsets(_selected_ship)
	for eng in engines:
		var ex: float = eng.x
		var ey: float = eng.y
		var side_factor: float = signf(ex) if ex != 0.0 else 0.0
		var banked_x: float = ex * (1.0 + _bank * side_factor * 0.15) * s + x_shift
		var local_pos := Vector2(banked_x, ey * s)
		var world_pos: Vector2 = ship_pos + local_pos
		_exhaust_particles.append({
			"pos": world_pos,
			"vel": Vector2(randf_range(-15.0, 15.0), randf_range(80.0, 160.0)),
			"life": 1.0,
			"max_life": 1.0,
			"size": randf_range(2.0, 4.5),
		})


func _update_exhaust(delta: float) -> void:
	var i := 0
	while i < _exhaust_particles.size():
		var p: Dictionary = _exhaust_particles[i]
		var life: float = p["life"]
		life -= delta * 1.5
		p["life"] = life
		if life <= 0.0:
			_exhaust_particles.remove_at(i)
			continue
		var vel: Vector2 = p["vel"]
		var pos: Vector2 = p["pos"]
		pos += vel * delta
		p["pos"] = pos
		i += 1


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
	if _ship_grid_bg:
		ThemeManager.apply_grid_background(_ship_grid_bg)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_right_panel_theme()
	for btn in _category_tab_buttons:
		ThemeManager.apply_button_style(btn)
	_update_category_tab_buttons()
	if _level_dropdown:
		ThemeManager.apply_button_style(_level_dropdown)
	_apply_compact_bar_theme()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		# Scroll wheel on left panel
		if mb.position.x <= LEFT_PANEL_W:
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_ship_selector.scroll_by(_ShipSelector.SCROLL_SPEED)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_ship_selector.scroll_by(-_ShipSelector.SCROLL_SPEED)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var vp_size: Vector2 = get_viewport_rect().size
			if mb.position.x <= LEFT_PANEL_W and mb.position.y < vp_size.y - HUD_HEIGHT and mb.position.y >= _ShipSelector.HEADER_HEIGHT:
				var slot: int = _ship_selector.get_slot_at(mb.position.y)
				if _category == "PLAYER":
					if slot >= 0 and slot < _ShipSelector.SHIP_COUNT:
						_select_ship(slot)
				elif _category == "ENEMIES":
					if slot >= 0 and slot < _filtered_enemy_ships.size():
						_select_enemy(slot)
				elif _category == "BOSSES":
					if slot >= 0 and slot < _filtered_boss_list.size():
						_select_boss(slot)


# ── Ship selection wiring ─────────────────────────────────────

func _select_ship(index: int) -> void:
	_selected_ship = index
	_exhaust_particles.clear()

	# Load stats: check for user override first, then registry defaults
	var ship_id: String = ShipRegistry.get_ship_name(index).to_lower()
	var override: ShipData = ShipDataManager.load_by_id(ship_id)
	var stats: Dictionary
	if override:
		stats = override.stats.duplicate()
		_working_render_mode = override.render_mode
		# Load collision hitbox from override
		stats["collision_width"] = override.collision_width
		stats["collision_height"] = override.collision_height
		stats["collision_shape"] = override.collision_shape
	else:
		stats = ShipRegistry.SHIP_STATS[index].duplicate()
		_working_render_mode = "chrome"
		stats["collision_width"] = 30.0
		stats["collision_height"] = 30.0
		stats["collision_shape"] = "circle"

	_working_stats = stats
	_accel = float(stats.get("acceleration", 1200))
	_top_speed = float(stats.get("speed", 400))

	# Update sliders without triggering save
	_updating_sliders = true
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		slider.value = float(stats.get(key, slider.value))
		_slider_labels[key].text = str(int(slider.value))
	# Update skin dropdown
	if _skin_dropdown:
		var skin_idx: int = SKIN_KEYS.find(_working_render_mode)
		_skin_dropdown.selected = maxi(skin_idx, 0)
	# Update hitbox shape dropdown
	if _hitbox_shape_dropdown:
		var cs: String = str(stats.get("collision_shape", "circle"))
		match cs:
			"rectangle": _hitbox_shape_dropdown.selected = 1
			"capsule": _hitbox_shape_dropdown.selected = 2
			_: _hitbox_shape_dropdown.selected = 0
	_updating_sliders = false

	# Apply render mode to preview
	_apply_render_mode()
	_update_hud_from_stats()
	_ship_selector.queue_redraw()


func _apply_render_mode() -> void:
	var mode: int = ShipRenderer.RenderMode.NEON
	match _working_render_mode:
		"chrome": mode = ShipRenderer.RenderMode.CHROME
		"neon": mode = ShipRenderer.RenderMode.NEON
		"void": mode = ShipRenderer.RenderMode.VOID
		"hivemind": mode = ShipRenderer.RenderMode.HIVEMIND
		"spore": mode = ShipRenderer.RenderMode.SPORE
		"ember": mode = ShipRenderer.RenderMode.EMBER
		"frost": mode = ShipRenderer.RenderMode.FROST
		"solar": mode = ShipRenderer.RenderMode.SOLAR
		"sport": mode = ShipRenderer.RenderMode.SPORT
		"gunmetal": mode = ShipRenderer.RenderMode.GUNMETAL
		"militia": mode = ShipRenderer.RenderMode.MILITIA
		"stealth": mode = ShipRenderer.RenderMode.STEALTH
	_ship_draw.render_mode = mode
	_ship_selector.render_mode = mode
	_ship_draw.queue_redraw()
	_ship_selector.queue_redraw()


# ── Enemy ship management ─────────────────────────────────────

func _load_enemy_ships() -> void:
	_enemy_ships = ShipDataManager.load_all_by_type("enemy")
	_filter_enemy_ships()


func _create_new_enemy() -> void:
	var new_id: String = ShipDataManager.generate_id("enemy")
	var data: Dictionary = {
		"id": new_id,
		"display_name": "New Enemy",
		"type": "enemy",
		"render_mode": "neon",
		"visual_id": "sentinel",
		"weapon_id": "",
		"level": _selected_level,
		"stats": {
			"hull_hp": 50,
			"shield_hp": 0,
			"speed": 150,
			"acceleration": 600,
		},
	}
	ShipDataManager.save(new_id, data)
	_load_enemy_ships()
	_ship_selector.enemy_ships = _filtered_enemy_ships
	# Select the newly created enemy
	for i in range(_filtered_enemy_ships.size()):
		if _filtered_enemy_ships[i].id == new_id:
			_select_enemy(i)
			break
	_ship_selector.queue_redraw()


func _select_enemy(index: int) -> void:
	if index < 0 or index >= _filtered_enemy_ships.size():
		return
	_stop_weapon_preview()
	_selected_enemy_index = index
	_working_enemy = _filtered_enemy_ships[index]
	_working_render_mode = _working_enemy.render_mode
	_exhaust_particles.clear()
	_velocity = 0.0
	_velocity_y = 0.0
	_bank = 0.0
	_enemy_idle_time = 0.0

	_ship_draw.enemy_visual_id = _working_enemy.visual_id
	_ship_draw.show_hardpoint_marker = true
	_ship_draw.hardpoint_marker_offsets = _working_enemy.hardpoint_offsets
	_apply_render_mode()

	_rebuild_right_panel()
	_update_enemy_hud()
	_ship_selector.queue_redraw()


func _switch_category(cat: String) -> void:
	if cat == _category:
		return
	_stop_weapon_preview()
	_category = cat
	_update_category_tab_buttons()

	_ship_selector.category = _category
	_ship_selector.scroll_offset = 0.0

	# Clear boss preview when leaving BOSSES
	for node in _boss_preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_boss_preview_nodes.clear()

	if _category == "PLAYER":
		_level_dropdown.visible = false
		_selected_enemy_index = -1
		_working_enemy = null
		if _ship_draw:
			_ship_draw.visible = true
		_rebuild_right_panel()
		_select_ship(_selected_ship)
		if _hud_replica:
			_hud_replica.visible = true
	elif _category == "ENEMIES":
		_level_dropdown.visible = true
		if _ship_draw:
			_ship_draw.visible = true
		if _hud_replica:
			_hud_replica.visible = false
		_filter_enemy_ships()
		_ship_selector.enemy_ships = _filtered_enemy_ships
		if _filtered_enemy_ships.size() > 0:
			_select_enemy(0)
		else:
			_selected_enemy_index = -1
			_working_enemy = null
			_rebuild_right_panel()
	elif _category == "BOSSES":
		_level_dropdown.visible = true
		if _ship_draw:
			_ship_draw.visible = false
		if _hud_replica:
			_hud_replica.visible = false
		_selected_enemy_index = -1
		_working_enemy = null
		# Auto-select "BOSS" in the level filter dropdown
		_selected_level = "boss"
		for i in range(LEVEL_OPTIONS.size()):
			if LEVEL_OPTIONS[i]["id"] == "boss":
				_level_dropdown.selected = i
				break
		_filter_bosses()
		_ship_selector.boss_list = _filtered_boss_list
		if _filtered_boss_list.size() > 0:
			_select_boss(0)
		else:
			_selected_boss_index = -1
			_working_boss = null
			_rebuild_right_panel()

	_ship_selector.queue_redraw()
	_ship_draw.queue_redraw()


func _update_category_tab_buttons() -> void:
	var tab_names: Array[String] = ["PLAYER", "ENEMIES", "BOSSES"]
	for i in range(_category_tab_buttons.size()):
		if tab_names[i] == _category:
			_category_tab_buttons[i].modulate = Color(1.3, 1.3, 1.6)
		else:
			_category_tab_buttons[i].modulate = Color(0.6, 0.6, 0.7)


func _on_level_changed(index: int) -> void:
	if index >= 0 and index < LEVEL_OPTIONS.size():
		var opt: Dictionary = LEVEL_OPTIONS[index]
		_selected_level = opt["id"]
	_ship_selector.scroll_offset = 0.0
	if _category == "BOSSES":
		_filter_bosses()
		_ship_selector.boss_list = _filtered_boss_list
		if _filtered_boss_list.size() > 0:
			_select_boss(0)
		else:
			_selected_boss_index = -1
			_working_boss = null
			_rebuild_right_panel()
	else:
		_filter_enemy_ships()
		_ship_selector.enemy_ships = _filtered_enemy_ships
		if _filtered_enemy_ships.size() > 0:
			_select_enemy(0)
		else:
			_selected_enemy_index = -1
			_working_enemy = null
			_rebuild_right_panel()
	_ship_selector.queue_redraw()


func _filter_enemy_ships() -> void:
	_filtered_enemy_ships.clear()
	for s in _enemy_ships:
		if s.level == _selected_level:
			_filtered_enemy_ships.append(s)


func _save_enemy() -> void:
	if not _working_enemy:
		return
	var saved_id: String = _working_enemy.id
	ShipDataManager.save(saved_id, _working_enemy.to_dict())
	_load_enemy_ships()
	_ship_selector.enemy_ships = _filtered_enemy_ships
	# Re-select — if level changed, enemy may have left this filter
	var found := false
	for i in range(_filtered_enemy_ships.size()):
		if _filtered_enemy_ships[i].id == saved_id:
			_selected_enemy_index = i
			_working_enemy = _filtered_enemy_ships[i]
			found = true
			break
	if not found:
		if _filtered_enemy_ships.size() > 0:
			_select_enemy(clampi(_selected_enemy_index, 0, _filtered_enemy_ships.size() - 1))
		else:
			_selected_enemy_index = -1
			_working_enemy = null
			_rebuild_right_panel()
	_ship_selector.queue_redraw()


func _delete_enemy() -> void:
	if not _working_enemy:
		return
	ShipDataManager.delete(_working_enemy.id)
	_load_enemy_ships()
	_ship_selector.enemy_ships = _filtered_enemy_ships
	if _filtered_enemy_ships.size() > 0:
		_select_enemy(clampi(_selected_enemy_index, 0, _filtered_enemy_ships.size() - 1))
	else:
		_selected_enemy_index = -1
		_working_enemy = null
		_rebuild_right_panel()
	_ship_selector.queue_redraw()


func _update_enemy_hud() -> void:
	# Enemy HUD is hidden; nothing to update for now
	pass


# ── Boss management ──────────────────────────────────────────

func _load_bosses() -> void:
	_boss_list = BossDataManager.load_all()
	_filter_bosses()


func _filter_bosses() -> void:
	_filtered_boss_list.clear()
	for b in _boss_list:
		if b.level == _selected_level:
			_filtered_boss_list.append(b)


func _create_new_boss() -> void:
	var new_id: String = BossDataManager.generate_id()
	var data: Dictionary = {
		"id": new_id,
		"display_name": "New Boss",
		"level": _selected_level,
		"core_ship_id": "",
		"core_weapon_overrides": [],
		"core_immune_until_segments_dead": false,
		"segments": [],
		"enrage_threshold": 0.5,
		"enrage_speed_mult": 1.5,
	}
	BossDataManager.save(new_id, data)
	_load_bosses()
	_ship_selector.boss_list = _filtered_boss_list
	for i in range(_filtered_boss_list.size()):
		if _filtered_boss_list[i].id == new_id:
			_select_boss(i)
			break
	_ship_selector.queue_redraw()


func _select_boss(index: int) -> void:
	if index < 0 or index >= _filtered_boss_list.size():
		return
	_stop_weapon_preview()
	_selected_boss_index = index
	_working_boss = _filtered_boss_list[index]
	_rebuild_right_panel()
	_update_boss_preview()
	_ship_selector.queue_redraw()


func _save_boss() -> void:
	if not _working_boss:
		return
	var saved_id: String = _working_boss.id
	BossDataManager.save(saved_id, _working_boss.to_dict())
	_load_bosses()
	_ship_selector.boss_list = _filtered_boss_list
	var found := false
	for i in range(_filtered_boss_list.size()):
		if _filtered_boss_list[i].id == saved_id:
			_selected_boss_index = i
			_working_boss = _filtered_boss_list[i]
			found = true
			break
	if not found:
		if _filtered_boss_list.size() > 0:
			_select_boss(clampi(_selected_boss_index, 0, _filtered_boss_list.size() - 1))
		else:
			_selected_boss_index = -1
			_working_boss = null
			_rebuild_right_panel()
	_ship_selector.queue_redraw()


func _delete_boss() -> void:
	if not _working_boss:
		return
	BossDataManager.delete(_working_boss.id)
	_load_bosses()
	_ship_selector.boss_list = _filtered_boss_list
	if _filtered_boss_list.size() > 0:
		_select_boss(clampi(_selected_boss_index, 0, _filtered_boss_list.size() - 1))
	else:
		_selected_boss_index = -1
		_working_boss = null
		_rebuild_right_panel()
	_ship_selector.queue_redraw()


func _update_boss_preview() -> void:
	# Clear old preview nodes
	for node in _boss_preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_boss_preview_nodes.clear()
	if not _working_boss or not _ship_viewport:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var center := Vector2(
		LEFT_PANEL_W + (vp_size.x - LEFT_PANEL_W - RIGHT_PANEL_W) * 0.5,
		(vp_size.y - HUD_HEIGHT) * 0.5
	)
	# Core body
	if _working_boss.core_ship_id != "":
		var core_ship: ShipData = ShipDataManager.load_by_id(_working_boss.core_ship_id)
		if core_ship:
			var r := ShipRenderer.new()
			r.ship_id = -1
			r.enemy_visual_id = core_ship.visual_id
			r.render_mode = _ShipSelector._render_mode_from_string(core_ship.render_mode)
			r.position = center
			r.animate = true
			_ship_viewport.add_child(r)
			_boss_preview_nodes.append(r)
	# Segments
	for seg in _working_boss.segments:
		var seg_dict: Dictionary = seg as Dictionary
		var seg_ship_id: String = str(seg_dict.get("ship_id", ""))
		if seg_ship_id == "":
			continue
		var seg_ship: ShipData = ShipDataManager.load_by_id(seg_ship_id)
		if not seg_ship:
			continue
		var offset_arr: Array = seg_dict.get("offset", [0.0, 0.0]) as Array
		var ox: float = float(offset_arr[0]) if offset_arr.size() > 0 else 0.0
		var oy: float = float(offset_arr[1]) if offset_arr.size() > 1 else 0.0
		var r := ShipRenderer.new()
		r.ship_id = -1
		r.enemy_visual_id = seg_ship.visual_id
		r.render_mode = _ShipSelector._render_mode_from_string(seg_ship.render_mode)
		r.position = center + Vector2(ox, oy)
		r.animate = true
		_ship_viewport.add_child(r)
		_boss_preview_nodes.append(r)


func _update_hud_from_stats() -> void:
	if _compact_bars.is_empty():
		return
	# Update segment counts from stats, then rebuild LED bars
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not _compact_bars.has(bar_name):
			continue
		var seg_key: String = str(spec.get("segments_stat", ""))
		var seg: int = int(_working_stats.get(seg_key, ShipData.DEFAULT_SEGMENTS.get(bar_name, 8)))
		_compact_bar_segments[bar_name] = seg
		var entry: Dictionary = _compact_bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		bar.max_value = seg
		bar.value = seg  # Always show full in preview
		ThemeManager.apply_led_bar(bar, color, 1.0, seg, false)


# ── Right attribute panel ─────────────────────────────────────

func _auto_size_right_panel() -> void:
	# Wait one frame so Godot computes minimum sizes from the content tree
	await get_tree().process_frame
	if not _right_panel or _right_panel.get_child_count() == 0:
		return
	# Measure what the content actually needs
	var content_min_w: float = 0.0
	for child in _right_panel.get_children():
		var cw: float = child.get_combined_minimum_size().x
		content_min_w = maxf(content_min_w, cw)
	# Add padding for the ScrollContainer/VBox offsets (10px each side)
	var panel_w: float = maxf(RIGHT_PANEL_W, content_min_w + 24.0)
	var vp_size: Vector2 = get_viewport_rect().size
	var panel_h: float = vp_size.y - HUD_HEIGHT
	_right_panel.position = Vector2(vp_size.x - panel_w, 0)
	_right_panel.size = Vector2(panel_w, panel_h)

func _build_right_panel() -> void:
	_right_panel = Panel.new()
	_right_panel.clip_contents = true
	add_child(_right_panel)
	# Set initial size so content has something to anchor to
	var vp_size: Vector2 = get_viewport_rect().size
	_right_panel.position = Vector2(vp_size.x - RIGHT_PANEL_W, 0)
	_right_panel.size = Vector2(RIGHT_PANEL_W, vp_size.y - HUD_HEIGHT)
	_rebuild_right_panel_contents()


func _rebuild_right_panel() -> void:
	if not _right_panel:
		return
	_explosion_color_rect = null
	_explosion_preview = null
	for child in _right_panel.get_children():
		_right_panel.remove_child(child)
		child.queue_free()
	_sliders.clear()
	_slider_labels.clear()
	_skin_dropdown = null
	_rebuild_right_panel_contents()


func _rebuild_right_panel_contents() -> void:
	_sliders.clear()
	_slider_labels.clear()
	_skin_dropdown = null

	if _category == "ENEMIES":
		_build_enemy_right_panel()
	elif _category == "BOSSES":
		_build_bosses_right_panel()
	else:
		_build_player_right_panel()
	_apply_right_panel_theme()
	# Auto-size after content is built — defers to next frame to measure
	_auto_size_right_panel()


func _build_player_right_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_top = 14
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "ATTRIBUTES"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 8
	vbox.add_child(spacer1)

	# Section: Bar Segments
	var seg_label := Label.new()
	seg_label.text = "BAR SEGMENTS"
	seg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(seg_label)

	_add_slider_row(vbox, "shield_segments", "SHD", 4, 25, 1)
	_add_slider_row(vbox, "hull_segments", "HUL", 4, 25, 1)
	_add_slider_row(vbox, "thermal_segments", "THR", 2, 25, 1)
	_add_slider_row(vbox, "electric_segments", "ELC", 2, 25, 1)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 12
	vbox.add_child(spacer2)

	# Section: Propulsion
	var prop_label := Label.new()
	prop_label.text = "PROPULSION"
	prop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prop_label)

	_add_slider_row(vbox, "acceleration", "ACCEL", 400, 10000, 50)
	_add_slider_row(vbox, "speed", "SPEED", 200, 600, 10)

	# Spacer
	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 12
	vbox.add_child(spacer3)

	# Section: Slots
	var slots_label := Label.new()
	slots_label.text = "SLOTS"
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(slots_label)

	_add_slider_row(vbox, "weapon_slots", "WEAPONS", 1, 6, 1)
	_add_slider_row(vbox, "core_slots", "CORES", 1, 3, 1)
	_add_slider_row(vbox, "field_slots", "FIELDS", 0, 4, 1)
	_add_slider_row(vbox, "particle_slots", "PARTICLES", 0, 2, 1)

	# Spacer
	var spacer3b := Control.new()
	spacer3b.custom_minimum_size.y = 12
	vbox.add_child(spacer3b)

	# Section: Hitbox
	_build_hitbox_section(vbox, _working_stats)

	# Spacer
	var spacer3c := Control.new()
	spacer3c.custom_minimum_size.y = 12
	vbox.add_child(spacer3c)

	# Section: Skin
	var skin_label := Label.new()
	skin_label.text = "SKIN"
	skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skin_label)

	_skin_dropdown = OptionButton.new()
	for i in range(SKIN_NAMES.size()):
		_skin_dropdown.add_item(SKIN_NAMES[i], i)
	_skin_dropdown.selected = 0
	_skin_dropdown.item_selected.connect(_on_skin_changed)
	vbox.add_child(_skin_dropdown)

	# Spacer to push buttons down
	var spacer4 := Control.new()
	spacer4.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer4)

	# Save button
	var save_btn := Button.new()
	save_btn.text = "SAVE CHANGES"
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "RESET DEFAULT"
	reset_btn.pressed.connect(_on_reset_default)
	vbox.add_child(reset_btn)
	ThemeManager.apply_button_style(reset_btn)


func _build_enemy_right_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_top = 14
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "ENEMY ATTRIBUTES"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	if not _working_enemy:
		var hint := Label.new()
		hint.text = "Select or create an enemy"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(hint)
		return

	# Tab bar
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_row)

	var stats_btn := Button.new()
	stats_btn.text = "STATS"
	stats_btn.toggle_mode = true
	stats_btn.button_pressed = (_enemy_tab == "stats")
	stats_btn.pressed.connect(func() -> void:
		_enemy_tab = "stats"
		_rebuild_right_panel()
	)
	tab_row.add_child(stats_btn)
	ThemeManager.apply_button_style(stats_btn)

	var effects_btn := Button.new()
	effects_btn.text = "EFFECTS"
	effects_btn.toggle_mode = true
	effects_btn.button_pressed = (_enemy_tab == "effects")
	effects_btn.pressed.connect(func() -> void:
		_enemy_tab = "effects"
		_rebuild_right_panel()
	)
	tab_row.add_child(effects_btn)
	ThemeManager.apply_button_style(effects_btn)

	_add_section_spacer(vbox)

	if _enemy_tab == "stats":
		_build_enemy_stats_tab(vbox)
	else:
		_build_enemy_effects_tab(vbox)

	# Spacer to push buttons down
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	# Buttons
	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.pressed.connect(_save_enemy)
	vbox.add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.pressed.connect(_delete_enemy)
	vbox.add_child(del_btn)
	ThemeManager.apply_button_style(del_btn)

	# Set slider values from working enemy
	_updating_sliders = true
	var direct_keys: Array[String] = ["explosion_size", "collision_width", "collision_height"]
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		var val: float = 0.0
		if key in direct_keys:
			val = float(_working_enemy.get(key))
		else:
			val = float(_working_enemy.stats.get(key, slider.min_value))
		slider.value = val
		_slider_labels[key].text = str(int(val)) if slider.step >= 1.0 else str(snapped(val, 0.1))
	_updating_sliders = false


func _build_enemy_stats_tab(vbox: VBoxContainer) -> void:
	# ── IDENTITY ──
	var id_label := Label.new()
	id_label.text = "IDENTITY"
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(id_label)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(name_hbox)
	var name_lbl := Label.new()
	name_lbl.text = "NAME"
	name_lbl.custom_minimum_size.x = 40
	name_hbox.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.text = _working_enemy.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_enemy_name_changed)
	name_hbox.add_child(name_edit)

	# Level assignment dropdown
	var level_hbox := HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(level_hbox)
	var level_lbl := Label.new()
	level_lbl.text = "LEVEL"
	level_lbl.custom_minimum_size.x = 40
	level_hbox.add_child(level_lbl)
	var level_dd := OptionButton.new()
	level_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_level_idx: int = 0
	for i in range(LEVEL_OPTIONS.size()):
		var opt: Dictionary = LEVEL_OPTIONS[i]
		var lbl: String = opt["label"]
		level_dd.add_item(lbl)
		var opt_id: String = opt["id"]
		if opt_id == _working_enemy.level:
			current_level_idx = i
	level_dd.selected = current_level_idx
	level_dd.item_selected.connect(func(idx: int) -> void:
		if _working_enemy and idx >= 0 and idx < LEVEL_OPTIONS.size():
			var opt: Dictionary = LEVEL_OPTIONS[idx]
			_working_enemy.level = opt["id"]
	)
	ThemeManager.apply_button_style(level_dd)
	level_hbox.add_child(level_dd)

	_add_section_spacer(vbox)

	# ── HEALTH ──
	var health_label := Label.new()
	health_label.text = "HEALTH"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(health_label)

	_add_slider_row(vbox, "shield_hp", "SHD", 0, 200, 5)
	_add_slider_row(vbox, "hull_hp", "HULL", 10, 500, 5)

	_add_section_spacer(vbox)

	# ── HITBOX ──
	_build_hitbox_section(vbox, _working_enemy)

	_add_section_spacer(vbox)

	# ── WEAPON ──
	var weap_label := Label.new()
	weap_label.text = "WEAPON"
	weap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(weap_label)

	var wd_hbox := HBoxContainer.new()
	wd_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(wd_hbox)
	var wd_lbl := Label.new()
	wd_lbl.text = "WPN"
	wd_lbl.custom_minimum_size.x = 40
	wd_hbox.add_child(wd_lbl)
	_enemy_weapon_dropdown = OptionButton.new()
	_enemy_weapon_dropdown.clip_text = true
	_enemy_weapon_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_weapon_dropdown.add_item("(none)", 0)
	var enemy_weapons: Array[WeaponData] = WeaponDataManager.load_all()
	var selected_idx: int = 0
	var item_idx: int = 1
	for w in enemy_weapons:
		if not w.is_enemy_weapon:
			continue
		var label: String = w.display_name if w.display_name != "" else w.id
		_enemy_weapon_dropdown.add_item(label, item_idx)
		_enemy_weapon_dropdown.set_item_metadata(item_idx, w.id)
		if w.id == _working_enemy.weapon_id:
			selected_idx = item_idx
		item_idx += 1
	_enemy_weapon_dropdown.selected = selected_idx
	_enemy_weapon_dropdown.item_selected.connect(_on_enemy_weapon_changed)
	wd_hbox.add_child(_enemy_weapon_dropdown)

	_weapon_preview_btn = Button.new()
	_weapon_preview_btn.text = "PREVIEW"
	_weapon_preview_btn.custom_minimum_size = Vector2(0, 34)
	_weapon_preview_btn.pressed.connect(_on_weapon_preview_toggle)
	_weapon_preview_btn.disabled = (_working_enemy.weapon_id == "")
	ThemeManager.apply_button_style(_weapon_preview_btn)
	vbox.add_child(_weapon_preview_btn)

	# ── HP readout ──
	_add_section_spacer(vbox)
	var hp_readout := Label.new()
	hp_readout.name = "HPReadout"
	var shp: int = int(_working_enemy.stats.get("shield_hp", 0))
	var hhp: int = int(_working_enemy.stats.get("hull_hp", 50))
	hp_readout.text = "HULL: %d HP | SHIELD: %d HP" % [hhp, shp]
	hp_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hp_readout)


func _build_enemy_effects_tab(vbox: VBoxContainer) -> void:
	# ── SKIN ──
	var skin_label := Label.new()
	skin_label.text = "SKIN"
	skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skin_label)

	_skin_dropdown = OptionButton.new()
	_skin_dropdown.clip_text = true
	for i in range(SKIN_NAMES.size()):
		_skin_dropdown.add_item(SKIN_NAMES[i], i)
	var enemy_skin_idx: int = SKIN_KEYS.find(_working_render_mode)
	_skin_dropdown.selected = maxi(enemy_skin_idx, 0)
	_skin_dropdown.item_selected.connect(_on_skin_changed)
	vbox.add_child(_skin_dropdown)

	# ── EXPLOSION ──
	_add_section_spacer(vbox)
	var exp_label := Label.new()
	exp_label.text = "EXPLOSION"
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(exp_label)

	var color_hbox := HBoxContainer.new()
	color_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(color_hbox)
	var color_lbl := Label.new()
	color_lbl.text = "COLOR"
	color_lbl.custom_minimum_size.x = 40
	color_hbox.add_child(color_lbl)
	var color_btn := ColorPickerButton.new()
	color_btn.color = _working_enemy.explosion_color
	color_btn.custom_minimum_size = Vector2(0, 28)
	color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_btn.edit_alpha = false
	color_btn.color_changed.connect(_on_explosion_color_changed)
	color_hbox.add_child(color_btn)

	_explosion_color_rect = ColorRect.new()
	_explosion_color_rect.custom_minimum_size = Vector2(28, 28)
	_explosion_color_rect.color = _working_enemy.explosion_color
	color_hbox.add_child(_explosion_color_rect)

	_add_slider_row(vbox, "explosion_size", "SIZE", 0.3, 4.0, 0.1)

	var shake_hbox := HBoxContainer.new()
	shake_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(shake_hbox)
	var shake_lbl := Label.new()
	shake_lbl.text = "SHAKE"
	shake_lbl.custom_minimum_size.x = 40
	shake_hbox.add_child(shake_lbl)
	var shake_check := CheckButton.new()
	shake_check.button_pressed = _working_enemy.enable_screen_shake
	shake_check.text = "Screen Shake"
	shake_check.toggled.connect(_on_explosion_shake_toggled)
	shake_hbox.add_child(shake_check)

	var preview_btn := Button.new()
	preview_btn.text = "PREVIEW EXPLOSION"
	preview_btn.pressed.connect(_preview_explosion)
	vbox.add_child(preview_btn)
	ThemeManager.apply_button_style(preview_btn)


func _build_bosses_right_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_top = 14
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "BOSS EDITOR"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# NEW button when no boss selected
	if not _working_boss:
		var new_btn := Button.new()
		new_btn.text = "NEW BOSS"
		new_btn.pressed.connect(_create_new_boss)
		vbox.add_child(new_btn)
		ThemeManager.apply_button_style(new_btn)
		var hint := Label.new()
		hint.text = "Select or create a boss"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(hint)
		return

	# Tab bar
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_row)

	for tab_name in ["CORE", "SEGMENTS", "ENRAGE"]:
		var btn := Button.new()
		btn.text = tab_name
		btn.toggle_mode = true
		var tab_key: String = tab_name.to_lower()
		btn.button_pressed = (_boss_tab == tab_key)
		btn.pressed.connect(func() -> void:
			_boss_tab = tab_key
			_rebuild_right_panel()
		)
		tab_row.add_child(btn)
		ThemeManager.apply_button_style(btn)

	_add_section_spacer(vbox)

	match _boss_tab:
		"core": _build_boss_core_tab(vbox)
		"segments": _build_boss_segments_tab(vbox)
		"enrage": _build_boss_enrage_tab(vbox)

	# Spacer + buttons
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	var new_btn := Button.new()
	new_btn.text = "NEW BOSS"
	new_btn.pressed.connect(_create_new_boss)
	vbox.add_child(new_btn)
	ThemeManager.apply_button_style(new_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.pressed.connect(_save_boss)
	vbox.add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.pressed.connect(_delete_boss)
	vbox.add_child(del_btn)
	ThemeManager.apply_button_style(del_btn)


func _build_boss_core_tab(vbox: VBoxContainer) -> void:
	# ── IDENTITY ──
	var id_label := Label.new()
	id_label.text = "IDENTITY"
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(id_label)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(name_hbox)
	var name_lbl := Label.new()
	name_lbl.text = "NAME"
	name_lbl.custom_minimum_size.x = 50
	name_hbox.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.text = _working_boss.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_name: String) -> void:
		if _working_boss:
			_working_boss.display_name = new_name
			_ship_selector.queue_redraw()
	)
	name_hbox.add_child(name_edit)

	# Level dropdown
	var level_hbox := HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(level_hbox)
	var level_lbl := Label.new()
	level_lbl.text = "LEVEL"
	level_lbl.custom_minimum_size.x = 50
	level_hbox.add_child(level_lbl)
	var level_dd := OptionButton.new()
	level_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_level_idx: int = 0
	for i in range(LEVEL_OPTIONS.size()):
		var opt: Dictionary = LEVEL_OPTIONS[i]
		level_dd.add_item(opt["label"])
		if opt["id"] == _working_boss.level:
			current_level_idx = i
	level_dd.selected = current_level_idx
	level_dd.item_selected.connect(func(idx: int) -> void:
		if _working_boss and idx >= 0 and idx < LEVEL_OPTIONS.size():
			_working_boss.level = LEVEL_OPTIONS[idx]["id"]
	)
	ThemeManager.apply_button_style(level_dd)
	level_hbox.add_child(level_dd)

	_add_section_spacer(vbox)

	# ── CORE SHIP ──
	var core_label := Label.new()
	core_label.text = "CORE SHIP"
	core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(core_label)

	var core_dd := OptionButton.new()
	core_dd.clip_text = true
	core_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_dd.add_item("(none)")
	var all_enemies: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	var core_selected: int = 0
	for i in range(all_enemies.size()):
		var s: ShipData = all_enemies[i]
		var label: String = s.display_name if s.display_name != "" else s.id
		core_dd.add_item(label)
		core_dd.set_item_metadata(i + 1, s.id)
		if s.id == _working_boss.core_ship_id:
			core_selected = i + 1
	core_dd.selected = core_selected
	core_dd.item_selected.connect(func(idx: int) -> void:
		if not _working_boss:
			return
		if idx == 0:
			_working_boss.core_ship_id = ""
			_working_boss.core_weapon_overrides = []
		else:
			_working_boss.core_ship_id = str(core_dd.get_item_metadata(idx))
			_working_boss.core_weapon_overrides = []
		_update_boss_preview()
		_rebuild_right_panel()
	)
	vbox.add_child(core_dd)

	_add_section_spacer(vbox)

	# ── IMMUNITY ──
	var immune_check := CheckButton.new()
	immune_check.text = "Immune until all segments destroyed"
	immune_check.button_pressed = _working_boss.core_immune_until_segments_dead
	immune_check.toggled.connect(func(pressed: bool) -> void:
		if _working_boss:
			_working_boss.core_immune_until_segments_dead = pressed
	)
	vbox.add_child(immune_check)

	_add_section_spacer(vbox)

	# ── WEAPONS (per-hardpoint) ──
	if _working_boss.core_ship_id != "":
		_build_weapon_overrides_section(vbox, _working_boss.core_ship_id, _working_boss.core_weapon_overrides, func(overrides: Array) -> void:
			if _working_boss:
				_working_boss.core_weapon_overrides = overrides
		)


func _build_weapon_overrides_section(vbox: VBoxContainer, ship_id: String, overrides: Array, on_change: Callable) -> void:
	## Builds per-hardpoint weapon dropdown rows for a given enemy ship.
	var weap_label := Label.new()
	weap_label.text = "WEAPONS"
	weap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(weap_label)

	var ship: ShipData = ShipDataManager.load_by_id(ship_id)
	if not ship:
		return

	# Determine hardpoint count
	var hp_count: int = ship.hardpoint_offsets.size()
	if hp_count == 0:
		hp_count = 1  # Single center hardpoint

	# Load all enemy weapons for dropdowns
	var all_weapons: Array[WeaponData] = WeaponDataManager.load_all()
	var enemy_weapons: Array[WeaponData] = []
	for w in all_weapons:
		if w.is_enemy_weapon:
			enemy_weapons.append(w)

	# Default weapon from the ship's weapon_id
	var default_weapon_id: String = ship.weapon_id

	# Build override lookup
	var override_map: Dictionary = {}
	for ovr in overrides:
		var d: Dictionary = ovr as Dictionary
		var hp_idx: int = int(d.get("hardpoint_index", 0))
		override_map[hp_idx] = str(d.get("weapon_id", ""))

	for hp_idx in range(hp_count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "HP %d" % hp_idx
		lbl.custom_minimum_size.x = 40
		row.add_child(lbl)

		var dd := OptionButton.new()
		dd.clip_text = true
		dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# First item: use ship default
		var default_label: String = "(default: %s)" % default_weapon_id if default_weapon_id != "" else "(none)"
		dd.add_item(default_label)
		var selected: int = 0
		var current_override: String = str(override_map.get(hp_idx, ""))
		for wi in range(enemy_weapons.size()):
			var w: WeaponData = enemy_weapons[wi]
			var w_label: String = w.display_name if w.display_name != "" else w.id
			dd.add_item(w_label)
			dd.set_item_metadata(wi + 1, w.id)
			if w.id == current_override:
				selected = wi + 1
		dd.selected = selected

		var captured_idx: int = hp_idx
		dd.item_selected.connect(func(item_idx: int) -> void:
			if not _working_boss:
				return
			# Rebuild overrides array
			var new_overrides: Array = []
			# Copy existing overrides for other hardpoints
			for existing in overrides:
				var ed: Dictionary = existing as Dictionary
				if int(ed.get("hardpoint_index", -1)) != captured_idx:
					new_overrides.append(existing)
			# Add new override if not default
			if item_idx > 0:
				new_overrides.append({
					"hardpoint_index": captured_idx,
					"weapon_id": str(dd.get_item_metadata(item_idx)),
				})
			on_change.call(new_overrides)
		)
		row.add_child(dd)


func _build_boss_segments_tab(vbox: VBoxContainer) -> void:
	var seg_header := Label.new()
	seg_header.text = "SEGMENTS"
	seg_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(seg_header)

	# Segment list
	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		var offset_arr: Array = seg.get("offset", [0.0, 0.0]) as Array
		var ox: float = float(offset_arr[0]) if offset_arr.size() > 0 else 0.0
		var oy: float = float(offset_arr[1]) if offset_arr.size() > 1 else 0.0

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var seg_label := Label.new()
		var ship_name: String = seg_ship_id if seg_ship_id != "" else "(none)"
		seg_label.text = "%d: %s (%.0f, %.0f)" % [i, ship_name, ox, oy]
		seg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_selected: bool = (i == _selected_segment_index)
		if is_selected:
			seg_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		row.add_child(seg_label)

		var sel_btn := Button.new()
		sel_btn.text = "EDIT" if not is_selected else "..."
		var captured_i: int = i
		sel_btn.pressed.connect(func() -> void:
			_selected_segment_index = captured_i
			_rebuild_right_panel()
		)
		ThemeManager.apply_button_style(sel_btn)
		row.add_child(sel_btn)

	# Add / Remove buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var add_btn := Button.new()
	add_btn.text = "ADD SEGMENT"
	add_btn.pressed.connect(func() -> void:
		if _working_boss:
			_working_boss.segments.append(BossData._default_segment())
			_selected_segment_index = _working_boss.segments.size() - 1
			_update_boss_preview()
			_rebuild_right_panel()
	)
	btn_row.add_child(add_btn)
	ThemeManager.apply_button_style(add_btn)

	if _selected_segment_index >= 0 and _selected_segment_index < _working_boss.segments.size():
		var rem_btn := Button.new()
		rem_btn.text = "REMOVE"
		rem_btn.pressed.connect(func() -> void:
			if _working_boss and _selected_segment_index >= 0 and _selected_segment_index < _working_boss.segments.size():
				_working_boss.segments.remove_at(_selected_segment_index)
				_selected_segment_index = mini(_selected_segment_index, _working_boss.segments.size() - 1)
				_update_boss_preview()
				_rebuild_right_panel()
		)
		btn_row.add_child(rem_btn)
		ThemeManager.apply_button_style(rem_btn)

	_add_section_spacer(vbox)

	# Selected segment detail
	if _selected_segment_index >= 0 and _selected_segment_index < _working_boss.segments.size():
		_build_segment_detail(vbox, _selected_segment_index)


func _build_segment_detail(vbox: VBoxContainer, seg_idx: int) -> void:
	var seg: Dictionary = _working_boss.segments[seg_idx] as Dictionary

	var detail_label := Label.new()
	detail_label.text = "SEGMENT %d" % seg_idx
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(detail_label)

	# Ship picker
	var ship_hbox := HBoxContainer.new()
	ship_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(ship_hbox)
	var ship_lbl := Label.new()
	ship_lbl.text = "SHIP"
	ship_lbl.custom_minimum_size.x = 50
	ship_hbox.add_child(ship_lbl)

	var ship_dd := OptionButton.new()
	ship_dd.clip_text = true
	ship_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_dd.add_item("(none)")
	var all_enemies: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	var ship_selected: int = 0
	var current_ship_id: String = str(seg.get("ship_id", ""))
	for i in range(all_enemies.size()):
		var s: ShipData = all_enemies[i]
		var label: String = s.display_name if s.display_name != "" else s.id
		ship_dd.add_item(label)
		ship_dd.set_item_metadata(i + 1, s.id)
		if s.id == current_ship_id:
			ship_selected = i + 1
	ship_dd.selected = ship_selected
	ship_dd.item_selected.connect(func(idx: int) -> void:
		if not _working_boss or seg_idx >= _working_boss.segments.size():
			return
		var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
		if idx == 0:
			s["ship_id"] = ""
			s["weapon_overrides"] = []
		else:
			s["ship_id"] = str(ship_dd.get_item_metadata(idx))
			s["weapon_overrides"] = []
		_working_boss.segments[seg_idx] = s
		_update_boss_preview()
		_rebuild_right_panel()
	)
	ship_hbox.add_child(ship_dd)

	_add_section_spacer(vbox)

	# Offset sliders
	var offset_label := Label.new()
	offset_label.text = "OFFSET"
	offset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(offset_label)

	var offset_arr: Array = seg.get("offset", [0.0, 0.0]) as Array
	var ox: float = float(offset_arr[0]) if offset_arr.size() > 0 else 0.0
	var oy: float = float(offset_arr[1]) if offset_arr.size() > 1 else 0.0

	# X offset
	var x_row := HBoxContainer.new()
	x_row.add_theme_constant_override("separation", 6)
	vbox.add_child(x_row)
	var x_lbl := Label.new()
	x_lbl.text = "X"
	x_lbl.custom_minimum_size.x = 20
	x_row.add_child(x_lbl)
	var x_slider := HSlider.new()
	x_slider.min_value = -300.0
	x_slider.max_value = 300.0
	x_slider.step = 1.0
	x_slider.value = ox
	x_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_row.add_child(x_slider)
	var x_val := Label.new()
	x_val.text = str(int(ox))
	x_val.custom_minimum_size.x = 40
	x_row.add_child(x_val)
	x_slider.value_changed.connect(func(val: float) -> void:
		x_val.text = str(int(val))
		if _working_boss and seg_idx < _working_boss.segments.size():
			var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
			var off: Array = s.get("offset", [0.0, 0.0]) as Array
			s["offset"] = [val, float(off[1]) if off.size() > 1 else 0.0]
			_working_boss.segments[seg_idx] = s
			_update_boss_preview()
	)

	# Y offset
	var y_row := HBoxContainer.new()
	y_row.add_theme_constant_override("separation", 6)
	vbox.add_child(y_row)
	var y_lbl := Label.new()
	y_lbl.text = "Y"
	y_lbl.custom_minimum_size.x = 20
	y_row.add_child(y_lbl)
	var y_slider := HSlider.new()
	y_slider.min_value = -300.0
	y_slider.max_value = 300.0
	y_slider.step = 1.0
	y_slider.value = oy
	y_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_row.add_child(y_slider)
	var y_val := Label.new()
	y_val.text = str(int(oy))
	y_val.custom_minimum_size.x = 40
	y_row.add_child(y_val)
	y_slider.value_changed.connect(func(val: float) -> void:
		y_val.text = str(int(val))
		if _working_boss and seg_idx < _working_boss.segments.size():
			var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
			var off: Array = s.get("offset", [0.0, 0.0]) as Array
			s["offset"] = [float(off[0]) if off.size() > 0 else 0.0, val]
			_working_boss.segments[seg_idx] = s
			_update_boss_preview()
	)

	_add_section_spacer(vbox)

	# Per-hardpoint weapons for this segment
	var seg_ship_id: String = str(seg.get("ship_id", ""))
	if seg_ship_id != "":
		var seg_overrides: Array = seg.get("weapon_overrides", []) as Array
		_build_weapon_overrides_section(vbox, seg_ship_id, seg_overrides, func(new_overrides: Array) -> void:
			if _working_boss and seg_idx < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
				s["weapon_overrides"] = new_overrides
				_working_boss.segments[seg_idx] = s
		)

	_add_section_spacer(vbox)

	# Detach config
	var detach_label := Label.new()
	detach_label.text = "DETACH"
	detach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(detach_label)

	var can_detach: bool = bool(seg.get("can_detach", false))
	var detach_check := CheckButton.new()
	detach_check.text = "Can Detach"
	detach_check.button_pressed = can_detach
	detach_check.toggled.connect(func(pressed: bool) -> void:
		if _working_boss and seg_idx < _working_boss.segments.size():
			var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
			s["can_detach"] = pressed
			_working_boss.segments[seg_idx] = s
			_rebuild_right_panel()
	)
	vbox.add_child(detach_check)

	if can_detach:
		var reattach_check := CheckButton.new()
		reattach_check.text = "Reattach after path"
		reattach_check.button_pressed = bool(seg.get("reattach", true))
		reattach_check.toggled.connect(func(pressed: bool) -> void:
			if _working_boss and seg_idx < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
				s["reattach"] = pressed
				_working_boss.segments[seg_idx] = s
		)
		vbox.add_child(reattach_check)

		# Detach speed
		var spd_row := HBoxContainer.new()
		spd_row.add_theme_constant_override("separation", 6)
		vbox.add_child(spd_row)
		var spd_lbl := Label.new()
		spd_lbl.text = "SPEED"
		spd_lbl.custom_minimum_size.x = 50
		spd_row.add_child(spd_lbl)
		var spd_slider := HSlider.new()
		spd_slider.min_value = 50.0
		spd_slider.max_value = 500.0
		spd_slider.step = 10.0
		spd_slider.value = float(seg.get("detach_speed", 200.0))
		spd_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spd_row.add_child(spd_slider)
		var spd_val := Label.new()
		spd_val.text = str(int(spd_slider.value))
		spd_val.custom_minimum_size.x = 40
		spd_row.add_child(spd_val)
		spd_slider.value_changed.connect(func(val: float) -> void:
			spd_val.text = str(int(val))
			if _working_boss and seg_idx < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
				s["detach_speed"] = val
				_working_boss.segments[seg_idx] = s
		)

		# HP threshold
		var thr_row := HBoxContainer.new()
		thr_row.add_theme_constant_override("separation", 6)
		vbox.add_child(thr_row)
		var thr_lbl := Label.new()
		thr_lbl.text = "HP %"
		thr_lbl.custom_minimum_size.x = 50
		thr_row.add_child(thr_lbl)
		var thr_slider := HSlider.new()
		thr_slider.min_value = 0.0
		thr_slider.max_value = 1.0
		thr_slider.step = 0.05
		thr_slider.value = float(seg.get("detach_hp_threshold", 0.0))
		thr_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thr_row.add_child(thr_slider)
		var thr_val := Label.new()
		thr_val.text = "%.0f%%" % (thr_slider.value * 100.0)
		thr_val.custom_minimum_size.x = 40
		thr_row.add_child(thr_val)
		thr_slider.value_changed.connect(func(val: float) -> void:
			thr_val.text = "%.0f%%" % (val * 100.0)
			if _working_boss and seg_idx < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[seg_idx] as Dictionary
				s["detach_hp_threshold"] = val
				_working_boss.segments[seg_idx] = s
		)


func _build_boss_enrage_tab(vbox: VBoxContainer) -> void:
	var enrage_label := Label.new()
	enrage_label.text = "ENRAGE PHASE"
	enrage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(enrage_label)

	# Threshold
	var thr_row := HBoxContainer.new()
	thr_row.add_theme_constant_override("separation", 6)
	vbox.add_child(thr_row)
	var thr_lbl := Label.new()
	thr_lbl.text = "HP %"
	thr_lbl.custom_minimum_size.x = 50
	thr_row.add_child(thr_lbl)
	var thr_slider := HSlider.new()
	thr_slider.min_value = 0.1
	thr_slider.max_value = 0.9
	thr_slider.step = 0.05
	thr_slider.value = _working_boss.enrage_threshold
	thr_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thr_row.add_child(thr_slider)
	var thr_val := Label.new()
	thr_val.text = "%.0f%%" % (_working_boss.enrage_threshold * 100.0)
	thr_val.custom_minimum_size.x = 40
	thr_row.add_child(thr_val)
	thr_slider.value_changed.connect(func(val: float) -> void:
		thr_val.text = "%.0f%%" % (val * 100.0)
		if _working_boss:
			_working_boss.enrage_threshold = val
	)

	# Speed mult
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 6)
	vbox.add_child(spd_row)
	var spd_lbl := Label.new()
	spd_lbl.text = "SPEED"
	spd_lbl.custom_minimum_size.x = 50
	spd_row.add_child(spd_lbl)
	var spd_slider := HSlider.new()
	spd_slider.min_value = 1.0
	spd_slider.max_value = 3.0
	spd_slider.step = 0.1
	spd_slider.value = _working_boss.enrage_speed_mult
	spd_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spd_row.add_child(spd_slider)
	var spd_val := Label.new()
	spd_val.text = "%.1fx" % _working_boss.enrage_speed_mult
	spd_val.custom_minimum_size.x = 40
	spd_row.add_child(spd_val)
	spd_slider.value_changed.connect(func(val: float) -> void:
		spd_val.text = "%.1fx" % val
		if _working_boss:
			_working_boss.enrage_speed_mult = val
	)

	_add_section_spacer(vbox)

	# Core skin override
	var skin_hbox := HBoxContainer.new()
	skin_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(skin_hbox)
	var skin_lbl := Label.new()
	skin_lbl.text = "SKIN"
	skin_lbl.custom_minimum_size.x = 50
	skin_hbox.add_child(skin_lbl)
	var skin_dd := OptionButton.new()
	skin_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_dd.add_item("(no change)")
	var skin_selected: int = 0
	for i in range(SKIN_NAMES.size()):
		skin_dd.add_item(SKIN_NAMES[i])
		if SKIN_KEYS[i] == _working_boss.enrage_core_render_mode:
			skin_selected = i + 1
	skin_dd.selected = skin_selected
	skin_dd.item_selected.connect(func(idx: int) -> void:
		if not _working_boss:
			return
		if idx == 0:
			_working_boss.enrage_core_render_mode = ""
		else:
			_working_boss.enrage_core_render_mode = SKIN_KEYS[idx - 1]
	)
	skin_hbox.add_child(skin_dd)

	_add_section_spacer(vbox)

	# Enrage weapon overrides for core
	if _working_boss.core_ship_id != "":
		var enrage_weap_label := Label.new()
		enrage_weap_label.text = "ENRAGE CORE WEAPONS"
		enrage_weap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(enrage_weap_label)
		_build_weapon_overrides_section(vbox, _working_boss.core_ship_id, _working_boss.enrage_core_weapon_overrides, func(overrides: Array) -> void:
			if _working_boss:
				_working_boss.enrage_core_weapon_overrides = overrides
		)


func _build_hitbox_section(vbox: VBoxContainer, source: Variant) -> void:
	var hitbox_label := Label.new()
	hitbox_label.text = "HITBOX"
	hitbox_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hitbox_label)

	# Show/hide toggle
	var show_check := CheckButton.new()
	show_check.text = "Show"
	show_check.button_pressed = _hitbox_overlay.visible
	show_check.toggled.connect(func(on: bool) -> void: _hitbox_overlay.visible = on)
	vbox.add_child(show_check)

	# Shape dropdown
	var shape_hbox := HBoxContainer.new()
	shape_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(shape_hbox)
	var shape_lbl := Label.new()
	shape_lbl.text = "SHAPE"
	shape_lbl.custom_minimum_size.x = 40
	shape_hbox.add_child(shape_lbl)
	_hitbox_shape_dropdown = OptionButton.new()
	_hitbox_shape_dropdown.clip_text = true
	_hitbox_shape_dropdown.add_item("Circle", 0)
	_hitbox_shape_dropdown.add_item("Rectangle", 1)
	_hitbox_shape_dropdown.add_item("Capsule", 2)
	var current_shape: String = ""
	if source is ShipData:
		current_shape = (source as ShipData).collision_shape
	elif source is Dictionary:
		current_shape = str((source as Dictionary).get("collision_shape", "circle"))
	match current_shape:
		"rectangle": _hitbox_shape_dropdown.selected = 1
		"capsule": _hitbox_shape_dropdown.selected = 2
		_: _hitbox_shape_dropdown.selected = 0
	_hitbox_shape_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hitbox_shape_dropdown.item_selected.connect(_on_hitbox_shape_changed)
	shape_hbox.add_child(_hitbox_shape_dropdown)

	# Width/Height sliders
	_add_slider_row(vbox, "collision_width", "W", 6, 300, 2)
	_add_slider_row(vbox, "collision_height", "H", 6, 300, 2)


func _on_hitbox_shape_changed(index: int) -> void:
	if _updating_sliders:
		return
	var shape_name: String = "circle"
	match index:
		1: shape_name = "rectangle"
		2: shape_name = "capsule"
	if _category == "ENEMIES" and _working_enemy:
		_working_enemy.collision_shape = shape_name
	elif _category == "PLAYER":
		_working_stats["collision_shape"] = shape_name
	_hitbox_overlay.queue_redraw()


func _add_section_spacer(parent: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	parent.add_child(spacer)


func _add_slider_row(parent: VBoxContainer, key: String, label_text: String, min_val: float, max_val: float, step: float) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 40
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var val_label := Label.new()
	val_label.custom_minimum_size.x = 36
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.text = str(int(min_val))
	hbox.add_child(val_label)

	_sliders[key] = slider
	_slider_labels[key] = val_label
	slider.value_changed.connect(_on_attr_changed.bind(key))


func _on_attr_changed(value: float, key: String) -> void:
	if _updating_sliders:
		return

	var slider: HSlider = _sliders.get(key)
	if slider and slider.step < 1.0:
		_slider_labels[key].text = str(snapped(value, 0.1))
	else:
		_slider_labels[key].text = str(int(value))

	if _category == "ENEMIES" and _working_enemy:
		if key == "explosion_size":
			_working_enemy.explosion_size = value
		elif key == "collision_width":
			_working_enemy.collision_width = value
			_hitbox_overlay.queue_redraw()
		elif key == "collision_height":
			_working_enemy.collision_height = value
			_hitbox_overlay.queue_redraw()
		else:
			_working_enemy.stats[key] = value
		# Update HP readout
		var readout: Label = _right_panel.find_child("HPReadout", true, false) as Label
		if readout:
			var shp: int = int(_working_enemy.stats.get("shield_hp", 0))
			var hhp: int = int(_working_enemy.stats.get("hull_hp", 50))
			readout.text = "HULL: %d HP | SHIELD: %d HP" % [hhp, shp]
		return

	# Player mode
	_working_stats[key] = value

	if key == "speed":
		_top_speed = value
	elif key == "acceleration":
		_accel = value
	elif key in ["collision_width", "collision_height"]:
		_hitbox_overlay.queue_redraw()

	_update_hud_from_stats()


func _on_skin_changed(index: int) -> void:
	if _updating_sliders:
		return
	_working_render_mode = SKIN_KEYS[index] if index < SKIN_KEYS.size() else "chrome"
	if _category == "ENEMIES" and _working_enemy:
		_working_enemy.render_mode = _working_render_mode
	_apply_render_mode()


# ── Enemy attribute handlers ─────────────────────────────────

func _on_enemy_name_changed(new_name: String) -> void:
	if _working_enemy:
		_working_enemy.display_name = new_name
		_ship_selector.queue_redraw()


func _on_enemy_weapon_changed(index: int) -> void:
	if not _working_enemy:
		return
	_stop_weapon_preview()
	if index <= 0:
		_working_enemy.weapon_id = ""
	else:
		var wid: String = str(_enemy_weapon_dropdown.get_item_metadata(index))
		_working_enemy.weapon_id = wid
	if _weapon_preview_btn:
		_weapon_preview_btn.disabled = (_working_enemy.weapon_id == "")


func _on_weapon_preview_toggle() -> void:
	if _weapon_preview_active:
		_stop_weapon_preview()
	else:
		_start_weapon_preview()


func _start_weapon_preview() -> void:
	if not _working_enemy or _working_enemy.weapon_id == "":
		return
	var weapon: WeaponData = WeaponDataManager.load_by_id(_working_enemy.weapon_id)
	if not weapon:
		return

	_weapon_preview_active = true
	_weapon_preview_btn.text = "STOP"

	# Create fire point that follows ship position (inside ship SubViewport for bloom)
	_weapon_preview_fire_point = Node2D.new()
	_weapon_preview_fire_point.position = _ship_draw.position + Vector2(0, 20)
	_ship_viewport.add_child(_weapon_preview_fire_point)

	# Create HardpointController — same system as player/enemy gameplay
	_weapon_preview_controller = HardpointController.new()
	_weapon_preview_controller.is_enemy = true  # enemy collision layers
	_weapon_preview_fire_point.add_child(_weapon_preview_controller)
	_weapon_preview_controller.setup(weapon, 180.0 + weapon.direction_deg, _weapon_preview_container)

	# Start playback and activate (unmute loop)
	LoopMixer.start_all()
	_weapon_preview_controller.activate()


func _stop_weapon_preview() -> void:
	_weapon_preview_active = false
	if _weapon_preview_btn:
		_weapon_preview_btn.text = "PREVIEW"

	# Cleanup controller (removes loop from LoopMixer)
	if _weapon_preview_controller:
		_weapon_preview_controller.cleanup()
		_weapon_preview_controller = null

	# Remove fire point
	if _weapon_preview_fire_point and is_instance_valid(_weapon_preview_fire_point):
		_weapon_preview_fire_point.queue_free()
		_weapon_preview_fire_point = null

	# Clear any remaining projectiles
	if _weapon_preview_container:
		for child in _weapon_preview_container.get_children():
			child.queue_free()


func _on_explosion_color_changed(color: Color) -> void:
	if _working_enemy:
		_working_enemy.explosion_color = color
	if _explosion_color_rect:
		_explosion_color_rect.color = color


func _on_explosion_shake_toggled(pressed: bool) -> void:
	if _working_enemy:
		_working_enemy.enable_screen_shake = pressed


func _preview_explosion() -> void:
	if not _working_enemy:
		return
	# Remove any existing preview
	if _explosion_preview and is_instance_valid(_explosion_preview):
		_explosion_preview.queue_free()
	var explosion := ExplosionEffect.new()
	explosion.explosion_color = _working_enemy.explosion_color
	explosion.explosion_size = _working_enemy.explosion_size
	explosion.enable_screen_shake = false  # Don't shake in preview
	explosion.position = _ship_draw.position
	_ship_viewport.add_child(explosion)
	_explosion_preview = explosion


func _on_save_pressed() -> void:
	var ship_id: String = ShipRegistry.get_ship_name(_selected_ship).to_lower()
	var col_shape: String = "circle"
	if _hitbox_shape_dropdown:
		match _hitbox_shape_dropdown.selected:
			1: col_shape = "rectangle"
			2: col_shape = "capsule"
	var data: Dictionary = {
		"id": ship_id,
		"display_name": ShipRegistry.get_ship_name(_selected_ship),
		"render_mode": _working_render_mode,
		"stats": _working_stats.duplicate(),
		"collision_shape": col_shape,
		"collision_width": float(_working_stats.get("collision_width", 30.0)),
		"collision_height": float(_working_stats.get("collision_height", 30.0)),
	}
	ShipDataManager.save(ship_id, data)


func _on_reset_default() -> void:
	var ship_id: String = ShipRegistry.get_ship_name(_selected_ship).to_lower()
	ShipDataManager.delete(ship_id)
	_select_ship(_selected_ship)


func _apply_right_panel_theme() -> void:
	if not _right_panel:
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeManager.get_color("panel")
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 10
	_right_panel.add_theme_stylebox_override("panel", panel_style)

	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")
	var header_size: int = ThemeManager.get_font_size("font_size_header")
	var accent: Color = ThemeManager.get_color("accent")
	var text_color: Color = ThemeManager.get_color("text")

	# Theme all labels in the panel — VBox may be direct child or inside ScrollContainer
	var first_child: Node = _right_panel.get_child(0) if _right_panel.get_child_count() > 0 else null
	if not first_child:
		return
	var vbox: VBoxContainer = null
	if first_child is VBoxContainer:
		vbox = first_child as VBoxContainer
	elif first_child is ScrollContainer:
		var sc: ScrollContainer = first_child as ScrollContainer
		if sc.get_child_count() > 0:
			vbox = sc.get_child(0) as VBoxContainer
	if not vbox:
		return
	var section_names: Array[String] = ["ATTRIBUTES", "BAR SEGMENTS", "PROPULSION", "SLOTS", "SKIN",
		"ENEMY ATTRIBUTES", "IDENTITY", "HEALTH", "WEAPONS", "AUDIO", "EXPLOSION", "BOSSES"]
	for child in vbox.get_children():
		if child is Label:
			var lbl: Label = child as Label
			if lbl.text in section_names:
				var is_header: bool = lbl.text in ["ATTRIBUTES", "ENEMY ATTRIBUTES", "BOSSES"]
				lbl.add_theme_font_size_override("font_size", header_size if is_header else body_size)
				lbl.add_theme_color_override("font_color", accent)
				if body_font:
					lbl.add_theme_font_override("font", body_font)
				ThemeManager.apply_text_glow(lbl, "header" if is_header else "body")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					var slbl: Label = sub as Label
					slbl.add_theme_font_size_override("font_size", body_size)
					slbl.add_theme_color_override("font_color", text_color)
					if body_font:
						slbl.add_theme_font_override("font", body_font)
				elif sub is LineEdit:
					var sle: LineEdit = sub as LineEdit
					sle.add_theme_font_size_override("font_size", body_size)
					sle.add_theme_color_override("font_color", text_color)
					if body_font:
						sle.add_theme_font_override("font", body_font)
				elif sub is OptionButton:
					var sob: OptionButton = sub as OptionButton
					sob.add_theme_font_size_override("font_size", body_size)
					sob.add_theme_color_override("font_color", text_color)
					if body_font:
						sob.add_theme_font_override("font", body_font)
				elif sub is SpinBox:
					var ssb: SpinBox = sub as SpinBox
					ssb.add_theme_font_size_override("font_size", body_size)
					if body_font:
						ssb.add_theme_font_override("font", body_font)
				elif sub is CheckButton:
					var scb: CheckButton = sub as CheckButton
					scb.add_theme_font_size_override("font_size", body_size)
					scb.add_theme_color_override("font_color", text_color)
					if body_font:
						scb.add_theme_font_override("font", body_font)
		elif child is Button:
			ThemeManager.apply_button_style(child as Button)
		elif child is OptionButton:
			var ob: OptionButton = child as OptionButton
			ob.add_theme_font_size_override("font_size", body_size)
			ob.add_theme_color_override("font_color", text_color)
			if body_font:
				ob.add_theme_font_override("font", body_font)


# ── HUD replica ───────────────────────────────────────────────

func _build_hud_replica() -> void:
	# Compact horizontal bar strip at the bottom — not the full game HUD.
	# 4 bars laid out horizontally: SHLD | HULL | THRM | ELEC
	var vp_size: Vector2 = get_viewport_rect().size

	_hud_replica = Control.new()
	_hud_replica.position = Vector2(LEFT_PANEL_W, vp_size.y - HUD_HEIGHT)
	_hud_replica.size = Vector2(vp_size.x - LEFT_PANEL_W - RIGHT_PANEL_W, HUD_HEIGHT)
	add_child(_hud_replica)

	# Chrome panel background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.WHITE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("base_color", Vector4(0.12, 0.13, 0.18, 1.0))
		mat.set_shader_parameter("divider_y", -1.0)  # No divider
		var accent_color: Color = ThemeManager.get_color("accent")
		mat.set_shader_parameter("divider_color", Vector4(accent_color.r, accent_color.g, accent_color.b, 0.5))
		bg.material = mat
	_hud_replica.add_child(bg)

	# Top border line
	var border_line := ColorRect.new()
	border_line.position = Vector2.ZERO
	border_line.size = Vector2(vp_size.x - LEFT_PANEL_W - RIGHT_PANEL_W, 2)
	var accent: Color = ThemeManager.get_color("accent")
	border_line.color = Color(accent.r, accent.g, accent.b, 0.4)
	_hud_replica.add_child(border_line)

	# HBox for 4 horizontal bars
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_right = -16
	hbox.offset_top = 10
	hbox.offset_bottom = -8
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_replica.add_child(hbox)

	var specs: Array = ThemeManager.get_status_bar_specs()
	var short_names: Dictionary = {
		"SHIELD": "SHLD", "HULL": "HULL", "THERMAL": "THRM", "ELECTRIC": "ELEC"
	}
	_compact_bars.clear()

	for spec in specs:
		var bar_name: String = str(spec["name"])
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(ShipData.DEFAULT_SEGMENTS.get(bar_name, 8))

		# Each bar in a VBox: label on top, horizontal bar below
		var bar_vbox := VBoxContainer.new()
		bar_vbox.add_theme_constant_override("separation", 2)
		bar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(bar_vbox)

		var lbl := Label.new()
		lbl.text = str(short_names.get(bar_name, bar_name))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var body_font: Font = ThemeManager.get_font("font_body")
		var body_size: int = ThemeManager.get_font_size("font_size_body")
		lbl.add_theme_font_size_override("font_size", body_size)
		lbl.add_theme_color_override("font_color", color)
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(lbl, "body")
		bar_vbox.add_child(lbl)

		var bar := ProgressBar.new()
		bar.fill_mode = 0  # FILL_LEFT_TO_RIGHT (horizontal)
		bar.max_value = seg
		bar.value = seg
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 24)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_vbox.add_child(bar)
		ThemeManager.apply_led_bar(bar, color, 1.0, seg, false)

		_compact_bars[bar_name] = {"bar": bar, "label": lbl}
		_compact_bar_segments[bar_name] = seg



func _apply_compact_bar_theme() -> void:
	if _compact_bars.is_empty():
		return
	var specs: Array = ThemeManager.get_status_bar_specs()
	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not _compact_bars.has(bar_name):
			continue
		var entry: Dictionary = _compact_bars[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var lbl: Label = entry["label"]
		lbl.add_theme_font_size_override("font_size", body_size)
		lbl.add_theme_color_override("font_color", color)
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(lbl, "body")
		var bar: ProgressBar = entry["bar"]
		var seg: int = int(_compact_bar_segments.get(bar_name, 8))
		var ratio: float = bar.value / maxf(bar.max_value, 1.0)
		ThemeManager.apply_led_bar(bar, color, ratio, seg, false)


# ── Exhaust Drawing (inner class) ────────────────────────────

class _HitboxOverlay extends Node2D:
	## Draws the collision hitbox shape over the ship preview.
	var viewer: Control

	func _draw() -> void:
		if not viewer:
			return
		var ship_pos: Vector2 = viewer._ship_draw.position
		var col_shape: String = "circle"
		var col_w: float = 30.0
		var col_h: float = 30.0

		if viewer._category == "ENEMIES" and viewer._working_enemy:
			col_shape = viewer._working_enemy.collision_shape
			col_w = viewer._working_enemy.collision_width
			col_h = viewer._working_enemy.collision_height
		elif viewer._category == "PLAYER":
			col_shape = str(viewer._working_stats.get("collision_shape", "circle"))
			col_w = float(viewer._working_stats.get("collision_width", 30.0))
			col_h = float(viewer._working_stats.get("collision_height", 30.0))
		else:
			return

		var outline_color := Color(0.2, 1.0, 0.4, 0.6)
		var fill_color := Color(0.2, 1.0, 0.4, 0.08)

		match col_shape:
			"rectangle":
				var rect := Rect2(ship_pos - Vector2(col_w, col_h) * 0.5, Vector2(col_w, col_h))
				draw_rect(rect, fill_color, true)
				draw_rect(rect, outline_color, false, 1.5)
			"capsule":
				# Draw capsule — vertical when height >= width, horizontal when width > height
				var is_horizontal: bool = col_w > col_h
				var cap_radius: float = minf(col_w, col_h) * 0.5
				var long_half: float = maxf(col_w, col_h) * 0.5
				var body_half: float = maxf(long_half - cap_radius, 0.0)
				if is_horizontal:
					# Horizontal capsule: caps on left/right
					var body_rect := Rect2(ship_pos.x - body_half, ship_pos.y - cap_radius, body_half * 2.0, col_h)
					draw_rect(body_rect, fill_color, true)
					_draw_circle_fill(ship_pos + Vector2(-body_half, 0), cap_radius, fill_color)
					_draw_circle_fill(ship_pos + Vector2(body_half, 0), cap_radius, fill_color)
					_draw_arc_outline(ship_pos + Vector2(-body_half, 0), cap_radius, PI * 0.5, PI * 1.5, outline_color)
					_draw_arc_outline(ship_pos + Vector2(body_half, 0), cap_radius, -PI * 0.5, PI * 0.5, outline_color)
					draw_line(ship_pos + Vector2(-body_half, -cap_radius), ship_pos + Vector2(body_half, -cap_radius), outline_color, 1.5)
					draw_line(ship_pos + Vector2(-body_half, cap_radius), ship_pos + Vector2(body_half, cap_radius), outline_color, 1.5)
				else:
					# Vertical capsule: caps on top/bottom
					var body_rect := Rect2(ship_pos.x - cap_radius, ship_pos.y - body_half, col_w, body_half * 2.0)
					draw_rect(body_rect, fill_color, true)
					_draw_circle_fill(ship_pos + Vector2(0, -body_half), cap_radius, fill_color)
					_draw_circle_fill(ship_pos + Vector2(0, body_half), cap_radius, fill_color)
					_draw_arc_outline(ship_pos + Vector2(0, -body_half), cap_radius, PI, TAU, outline_color)
					_draw_arc_outline(ship_pos + Vector2(0, body_half), cap_radius, 0, PI, outline_color)
					draw_line(ship_pos + Vector2(-cap_radius, -body_half), ship_pos + Vector2(-cap_radius, body_half), outline_color, 1.5)
					draw_line(ship_pos + Vector2(cap_radius, -body_half), ship_pos + Vector2(cap_radius, body_half), outline_color, 1.5)
			_:  # "circle"
				var radius: float = col_w * 0.5
				_draw_circle_fill(ship_pos, radius, fill_color)
				_draw_arc_outline(ship_pos, radius, 0, TAU, outline_color)

	func _draw_circle_fill(center: Vector2, radius: float, color: Color) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		var segments: int = 32
		for i in segments + 1:
			var angle: float = float(i) / float(segments) * TAU
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, color)

	func _draw_arc_outline(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		var segments: int = 32
		var arc_span: float = end_angle - start_angle
		for i in segments + 1:
			var angle: float = start_angle + float(i) / float(segments) * arc_span
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		for i in points.size() - 1:
			draw_line(points[i], points[i + 1], color, 1.5)


class _ExhaustDraw extends Node2D:
	var viewer: Control

	func _draw() -> void:
		if not viewer:
			return
		var particles: Array[Dictionary] = viewer._exhaust_particles
		for p in particles:
			var life: float = p["life"]
			var max_life: float = p["max_life"]
			var t: float = life / max_life
			var pos: Vector2 = p["pos"]
			var sz: float = p["size"]
			var col := Color(1.0, 0.4 * t + 0.1, 0.05, t * 0.8)
			draw_circle(pos, sz * t, col)
			var core := Color(1.0, 0.8, 0.3, t * 0.5)
			draw_circle(pos, sz * t * 0.4, core)


# ── Ship Selector Bar (inner class) ─────────────────────────

class _ShipSelector extends Node2D:
	const PANEL_WIDTH := 200.0
	const SLOT_HEIGHT := 100.0
	const SHIP_COUNT := 9
	const HEADER_HEIGHT := 60.0
	const HUD_H := 110.0
	const SCROLL_SPEED := 30.0
	const SHIP_NAMES: Array[String] = [
		"Switchblade", "Phantom", "Mantis", "Corsair", "Stiletto",
		"Trident", "Orrery", "Dreadnought", "Bastion",
	]

	var viewer: Control
	var render_mode: int = ShipRenderer.RenderMode.NEON
	var category: String = "PLAYER"
	var enemy_ships: Array[ShipData] = []
	var boss_list: Array[BossData] = []
	var scroll_offset: float = 0.0

	var cyan := Color(0.0, 0.9, 1.0)

	func get_slot_at(mouse_y: float) -> int:
		var y_offset: float = mouse_y - HEADER_HEIGHT + scroll_offset
		if y_offset < 0:
			return -1
		var slot_count: int = _get_slot_count()
		var idx: int = int(y_offset / SLOT_HEIGHT)
		if idx < 0 or idx >= slot_count:
			return -1
		return idx

	func scroll_by(amount: float) -> void:
		var vp_h: float = viewer.get_viewport_rect().size.y if viewer else 1080.0
		var visible_h: float = vp_h - HUD_H - HEADER_HEIGHT
		var total_h: float = _get_slot_count() * SLOT_HEIGHT
		var max_scroll: float = maxf(total_h - visible_h, 0.0)
		scroll_offset = clampf(scroll_offset + amount, 0.0, max_scroll)
		queue_redraw()

	func _get_slot_count() -> int:
		if category == "ENEMIES":
			return enemy_ships.size()
		elif category == "BOSSES":
			return boss_list.size()
		return SHIP_COUNT

	func _draw() -> void:
		if not viewer:
			return
		var vp_size: Vector2 = viewer.get_viewport_rect().size
		var panel_h: float = vp_size.y - HUD_H

		# Panel background
		var bg := Color(0.0, 0.0, 0.05, 0.85)
		draw_rect(Rect2(0, 0, PANEL_WIDTH, panel_h), bg)
		# Right edge separator
		draw_line(Vector2(PANEL_WIDTH, 0), Vector2(PANEL_WIDTH, panel_h), cyan * Color(1, 1, 1, 0.3), 1.0)

		# Clip list drawing to the area below the header and above the HUD
		var clip_rect := Rect2(0, HEADER_HEIGHT, PANEL_WIDTH, panel_h - HEADER_HEIGHT)
		draw_set_transform(Vector2(0, -scroll_offset), 0.0, Vector2.ONE)

		# Header area is covered by the level filter dropdown (when visible)
		match category:
			"PLAYER": _draw_player_list()
			"ENEMIES": _draw_enemy_list()
			"BOSSES": _draw_boss_list()

		# Reset transform
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Draw solid rects over the header area and below HUD to mask overflow
		draw_rect(Rect2(0, 0, PANEL_WIDTH, HEADER_HEIGHT), Color(0.0, 0.0, 0.05, 1.0))
		draw_rect(Rect2(0, panel_h, PANEL_WIDTH, HUD_H + 10), Color(0.0, 0.0, 0.05, 1.0))

		# Scroll indicator
		var total_h: float = _get_slot_count() * SLOT_HEIGHT
		var visible_h: float = panel_h - HEADER_HEIGHT
		if total_h > visible_h and total_h > 0.0:
			var bar_h: float = maxf(visible_h * (visible_h / total_h), 20.0)
			var bar_y: float = HEADER_HEIGHT + (visible_h - bar_h) * (scroll_offset / maxf(total_h - visible_h, 1.0))
			draw_rect(Rect2(PANEL_WIDTH - 4, bar_y, 3, bar_h), Color(cyan.r, cyan.g, cyan.b, 0.3))

	func _draw_player_list() -> void:
		for i in range(SHIP_COUNT):
			var slot_y: float = HEADER_HEIGHT + SLOT_HEIGHT * i
			var cy: float = slot_y + SLOT_HEIGHT * 0.4
			var selected: bool = (i == viewer._selected_ship)

			if selected:
				var hl := cyan
				hl.a = 0.12
				draw_rect(Rect2(2, slot_y + 2, PANEL_WIDTH - 4, SLOT_HEIGHT - 4), hl)
				draw_rect(Rect2(2, slot_y + 2, PANEL_WIDTH - 4, SLOT_HEIGHT - 4), Color(cyan.r, cyan.g, cyan.b, 0.4), false, 1.0)

			var origin := Vector2(PANEL_WIDTH * 0.5, cy)
			ShipThumbnails.draw_ship_on(self, i, origin, 1.5, render_mode)

			# Ship name below thumbnail
			var font: Font = ThemeDB.fallback_font
			var name_text: String = SHIP_NAMES[i] if i < SHIP_NAMES.size() else ""
			var font_size: int = 12
			var label_col: Color = cyan if selected else Color(0.5, 0.5, 0.6)
			var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var name_pos := Vector2((PANEL_WIDTH - text_width) * 0.5, slot_y + SLOT_HEIGHT - 10)
			draw_string(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_col)

	func _draw_enemy_list() -> void:
		var font: Font = ThemeDB.fallback_font

		# Enemy ship slots
		for i in range(enemy_ships.size()):
			var slot_y: float = HEADER_HEIGHT + SLOT_HEIGHT * i
			var cy: float = slot_y + SLOT_HEIGHT * 0.4
			var selected: bool = (i == viewer._selected_enemy_index)

			if selected:
				var hl := cyan
				hl.a = 0.12
				draw_rect(Rect2(2, slot_y + 2, PANEL_WIDTH - 4, SLOT_HEIGHT - 4), hl)
				draw_rect(Rect2(2, slot_y + 2, PANEL_WIDTH - 4, SLOT_HEIGHT - 4), Color(cyan.r, cyan.g, cyan.b, 0.4), false, 1.0)

			# Draw enemy thumbnail based on visual_id, using per-ship render mode
			var origin := Vector2(PANEL_WIDTH * 0.5, cy)
			var ship_data: ShipData = enemy_ships[i]
			var ship_mode: int = _render_mode_from_string(ship_data.render_mode)
			ShipThumbnails.draw_enemy_on(self, ship_data.visual_id, origin, ship_mode, 1.8)

			# Enemy name
			var name_text: String = ship_data.display_name
			var font_size: int = 12
			var label_col: Color = cyan if selected else Color(0.5, 0.5, 0.6)
			var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var name_pos := Vector2((PANEL_WIDTH - text_width) * 0.5, slot_y + SLOT_HEIGHT - 10)
			draw_string(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_col)

	static func _render_mode_from_string(mode_str: String) -> int:
		match mode_str:
			"chrome": return ShipRenderer.RenderMode.CHROME
			"neon": return ShipRenderer.RenderMode.NEON
			"void": return ShipRenderer.RenderMode.VOID
			"hivemind": return ShipRenderer.RenderMode.HIVEMIND
			"spore": return ShipRenderer.RenderMode.SPORE
			"ember": return ShipRenderer.RenderMode.EMBER
			"frost": return ShipRenderer.RenderMode.FROST
			"solar": return ShipRenderer.RenderMode.SOLAR
			"sport": return ShipRenderer.RenderMode.SPORT
			"gunmetal": return ShipRenderer.RenderMode.GUNMETAL
			"militia": return ShipRenderer.RenderMode.MILITIA
			"stealth": return ShipRenderer.RenderMode.STEALTH
		return ShipRenderer.RenderMode.NEON

	func _draw_boss_list() -> void:
		var font: Font = ThemeDB.fallback_font
		for i in range(boss_list.size()):
			var slot_y: float = HEADER_HEIGHT + SLOT_HEIGHT * i
			var cy: float = slot_y + SLOT_HEIGHT * 0.4
			var selected: bool = (i == viewer._selected_boss_index)

			if selected:
				var hl := cyan
				hl.a = 0.12
				draw_rect(Rect2(2, slot_y + 2, PANEL_WIDTH - 4, SLOT_HEIGHT - 4), hl)
				draw_rect(Rect2(2, slot_y + 2, PANEL_WIDTH - 4, SLOT_HEIGHT - 4), Color(cyan.r, cyan.g, cyan.b, 0.4), false, 1.0)

			# Draw core ship thumbnail if available
			var boss: BossData = boss_list[i]
			if boss.core_ship_id != "":
				var core_ship: ShipData = ShipDataManager.load_by_id(boss.core_ship_id)
				if core_ship:
					var origin := Vector2(PANEL_WIDTH * 0.5, cy)
					var ship_mode: int = _render_mode_from_string(core_ship.render_mode)
					ShipThumbnails.draw_enemy_on(self, core_ship.visual_id, origin, ship_mode, 1.5)

			# Boss name
			var name_text: String = boss.display_name
			var font_size: int = 12
			var label_col: Color = cyan if selected else Color(0.5, 0.5, 0.6)
			var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var name_pos := Vector2((PANEL_WIDTH - text_width) * 0.5, slot_y + SLOT_HEIGHT - 10)
			draw_string(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_col)
