extends Control
## Ships screen — configuration and preview.
## Left panel: ship selection. Center: ship preview (WASD movement).
## Right panel: attribute sliders + skin dropdown + save. Bottom: HUD replica.

const SKIN_NAMES: Array[String] = ["CHROME", "NEON", "VOID", "HIVEMIND", "SPORE", "EMBER", "FROST", "SOLAR", "SPORT", "GUNMETAL", "MILITIA", "STEALTH", "BIOLUME", "TOXIC", "CORAL", "ABYSSAL", "BLOODMOON", "PHANTOM", "AURORA"]
const SKIN_KEYS: Array[String] = ["chrome", "neon", "void", "hivemind", "spore", "ember", "frost", "solar", "sport", "gunmetal", "militia", "stealth", "biolume", "toxic", "coral", "abyssal", "bloodmoon", "phantom", "aurora"]

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
var _boss_tab: String = "core"  # "core", "weapons", "health", "hitbox", "destruction", "alignment", "enrage"
var _weapon_preview_controllers: Array = []  # Array of HardpointController for multi-weapon preview
var _weapon_preview_fire_points: Array = []  # Array of Node2D fire points for multi-weapon preview
var _weapon_preview_loop_ids: Array[String] = []  # Loop IDs registered for preview (for guaranteed cleanup)
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
var _bake_viewport: SubViewport = null  # Small bake viewport matching in-game resolution
var _bake_sprite: Sprite2D = null       # Displays bake texture in main viewport
var _weapon_preview_controller: HardpointController = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Ship rendering goes in its own SubViewport with ACES bloom.
	# UI panels (left/right/bottom) stay on root and render on top.
	var svc := SubViewportContainer.new()
	svc.name = "ShipViewportContainer"
	svc.size = Vector2(1920, 1080)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	_ship_viewport = SubViewport.new()
	_ship_viewport.name = "ShipViewport"
	_ship_viewport.size = Vector2i(1920, 1080)
	_ship_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ship_viewport.transparent_bg = false
	svc.add_child(_ship_viewport)
	VFXFactory.add_bloom_to_viewport(_ship_viewport)  # use_hdr_2d + ACES — matches game viewport pipeline

	# Dark background inside SubViewport
	_ship_grid_bg = ColorRect.new()
	_ship_grid_bg.size = Vector2(1920, 1080)
	_ship_grid_bg.z_index = -10
	_ship_grid_bg.color = Color(0.01, 0.01, 0.03, 1.0)
	_ship_viewport.add_child(_ship_grid_bg)

	_exhaust_draw = _ExhaustDraw.new()
	_exhaust_draw.viewer = self
	_ship_viewport.add_child(_exhaust_draw)

	_ship_draw = ShipRenderer.new()
	_ship_viewport.add_child(_ship_draw)

	# Bake viewport for enemy preview — matches EnemySharedRenderer resolution
	_bake_viewport = SubViewport.new()
	_bake_viewport.name = "BakeViewport"
	_bake_viewport.transparent_bg = true
	_bake_viewport.use_hdr_2d = true
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# No WorldEnvironment — raw HDR, same as enemy_shared_renderer bake viewports
	_ship_viewport.add_child(_bake_viewport)

	_bake_sprite = Sprite2D.new()
	_bake_sprite.visible = false
	_ship_viewport.add_child(_bake_sprite)

	_weapon_preview_container = Node2D.new()
	_ship_viewport.add_child(_weapon_preview_container)

	_hitbox_overlay = _HitboxOverlay.new()
	_hitbox_overlay.viewer = self
	_hitbox_overlay.visible = false
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

	var tab_names: Array[String] = ["PLAYER", "ALLIES", "ENEMIES", "BOSSES"]
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
	if _category == "ENEMIES" or _category == "ALLIES":
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
	var enemy_pos := Vector2(cx, cy + sin(_enemy_idle_time * 1.5) * 3.0)
	_ship_draw.bank = 0.0
	_ship_draw.ship_id = -1  # Signal enemy drawing mode
	# Position bake sprite or direct draw
	if _bake_sprite.visible:
		_bake_sprite.position = enemy_pos
	else:
		_ship_draw.position = enemy_pos
	_exhaust_particles.clear()
	_exhaust_draw.queue_redraw()

	# Keep weapon preview fire point synced to ship position
	if _weapon_preview_fire_point and is_instance_valid(_weapon_preview_fire_point):
		_weapon_preview_fire_point.position = enemy_pos + Vector2(0, 20)
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
				elif _category == "ALLIES":
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
		"biolume": mode = ShipRenderer.RenderMode.BIOLUME
		"toxic": mode = ShipRenderer.RenderMode.TOXIC
		"coral": mode = ShipRenderer.RenderMode.CORAL
		"abyssal": mode = ShipRenderer.RenderMode.ABYSSAL
		"bloodmoon": mode = ShipRenderer.RenderMode.BLOODMOON
		"phantom": mode = ShipRenderer.RenderMode.PHANTOM
		"aurora": mode = ShipRenderer.RenderMode.AURORA
	_ship_draw.render_mode = mode
	_ship_selector.render_mode = mode
	# Apply per-ship neon parameters and bake mode for enemies
	if (_category == "ENEMIES" or _category == "ALLIES") and _working_enemy:
		_ship_draw.neon_hdr = _working_enemy.neon_hdr
		_ship_draw.neon_white = _working_enemy.neon_white
		_ship_draw.neon_width = _working_enemy.neon_width
		_enable_bake_mode(_working_enemy.visual_id)
	else:
		_ship_draw.neon_hdr = 1.0
		_ship_draw.neon_white = 0.0
		_ship_draw.neon_width = 1.0
		_disable_bake_mode()
	_ship_draw.queue_redraw()
	_ship_selector.queue_redraw()


func _enable_bake_mode(visual_id: String) -> void:
	## Move ShipRenderer into bake viewport at in-game resolution, display via Sprite2D.
	var bake_size: int = EnemySharedRenderer.get_bake_size(visual_id)
	_bake_viewport.size = Vector2i(bake_size, bake_size)
	# Reparent ship_draw into bake viewport if not already there
	if _ship_draw.get_parent() != _bake_viewport:
		_ship_draw.get_parent().remove_child(_ship_draw)
		_bake_viewport.add_child(_ship_draw)
	_ship_draw.position = Vector2(bake_size / 2.0, bake_size / 2.0)
	# Show bake sprite, hide direct draw
	_bake_sprite.texture = _bake_viewport.get_texture()
	_bake_sprite.visible = true


func _disable_bake_mode() -> void:
	## Move ShipRenderer back to main viewport for direct rendering.
	if _ship_draw.get_parent() != _ship_viewport:
		_ship_draw.get_parent().remove_child(_ship_draw)
		_ship_viewport.add_child(_ship_draw)
	_bake_sprite.visible = false


func _get_ship_display_pos() -> Vector2:
	## Get the ship's display position in the main viewport, regardless of bake mode.
	if _bake_sprite.visible:
		return _bake_sprite.position
	return _ship_draw.position


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
	elif _category == "ALLIES":
		_level_dropdown.visible = false
		if _ship_draw:
			_ship_draw.visible = true
		if _hud_replica:
			_hud_replica.visible = false
		var ally_ships: Array[ShipData] = ShipDataManager.load_all_by_type("ally")
		_filtered_enemy_ships = ally_ships
		_ship_selector.enemy_ships = _filtered_enemy_ships
		if ally_ships.size() > 0:
			_select_enemy(0)
		else:
			_selected_enemy_index = -1
			_working_enemy = null
			_rebuild_right_panel()
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
	var tab_names: Array[String] = ["PLAYER", "ALLIES", "ENEMIES", "BOSSES"]
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
	# Show hitbox overlay for boss parts
	if _hitbox_overlay:
		_hitbox_overlay.visible = false
		_hitbox_overlay.queue_redraw()
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
			r.neon_hdr = core_ship.neon_hdr
			r.neon_white = core_ship.neon_white
			r.neon_width = core_ship.neon_width
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
		r.neon_hdr = seg_ship.neon_hdr
		r.neon_white = seg_ship.neon_white
		r.neon_width = seg_ship.neon_width
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
	_add_slider_row(vbox, "field_slots", "FIELDS", 0, 1, 1)
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
	var direct_keys: Array[String] = ["explosion_size", "collision_width", "collision_height",
		"neon_hdr", "neon_white", "neon_width"]
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		var val: float = 0.0
		if key in direct_keys:
			val = float(_working_enemy.get(key))
		else:
			val = float(_working_enemy.stats.get(key, slider.min_value))
		slider.value = val
		if slider.step < 0.1:
			_slider_labels[key].text = "%.2f" % val
		elif slider.step < 1.0:
			_slider_labels[key].text = str(snapped(val, 0.1))
		else:
			_slider_labels[key].text = str(int(val))
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

	_add_slider_row(vbox, "shield_hp", "SHD", 0, 400, 5)
	_add_slider_row(vbox, "hull_hp", "HULL", 10, 1000, 5)

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

	# ── NEON RENDERING ──
	_add_section_spacer(vbox)
	var neon_label := Label.new()
	neon_label.text = "NEON RENDERING"
	neon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(neon_label)

	_add_slider_row(vbox, "neon_hdr", "HDR", 0.0, 4.0, 0.01)
	_add_slider_row(vbox, "neon_white", "WHITE", 0.0, 1.0, 0.01)
	_add_slider_row(vbox, "neon_width", "WIDTH", 0.01, 0.5, 0.005)

	if _working_enemy:
		_updating_sliders = true
		if _sliders.has("neon_hdr"):
			(_sliders["neon_hdr"] as HSlider).value = _working_enemy.neon_hdr
		if _sliders.has("neon_white"):
			(_sliders["neon_white"] as HSlider).value = _working_enemy.neon_white
		if _sliders.has("neon_width"):
			(_sliders["neon_width"] as HSlider).value = _working_enemy.neon_width
		_updating_sliders = false

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

	if not _working_boss:
		var hint := Label.new()
		hint.text = "Select a boss"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(hint)
		return

	# Tab bar — multi-row
	var tab_names: Array[String] = ["CORE", "WEAPONS", "HEALTH", "HITBOX", "DESTRUCTION", "ALIGNMENT", "ENRAGE", "GLOW"]
	var row1_names: Array[String] = ["CORE", "WEAPONS", "HEALTH", "HITBOX"]
	var row2_names: Array[String] = ["DESTRUCTION", "ALIGNMENT", "ENRAGE", "GLOW"]

	var tab_grid := VBoxContainer.new()
	tab_grid.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_grid)

	for row_names in [row1_names, row2_names]:
		var tab_row := HBoxContainer.new()
		tab_row.add_theme_constant_override("separation", 4)
		tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
		tab_grid.add_child(tab_row)
		for tab_name: String in row_names:
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
		"weapons": _build_boss_weapons_tab(vbox)
		"health": _build_boss_health_tab(vbox)
		"hitbox": _build_boss_hitbox_tab(vbox)
		"destruction": _build_boss_destruction_tab(vbox)
		"alignment": _build_boss_alignment_tab(vbox)
		"enrage": _build_boss_enrage_tab(vbox)
		"glow": _build_boss_glow_tab(vbox)

	# Spacer + buttons
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

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

	# ── SEGMENTS ──
	var seg_header := Label.new()
	seg_header.text = "SEGMENTS"
	seg_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(seg_header)

	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var seg_lbl := Label.new()
		seg_lbl.text = "Seg %d" % i
		seg_lbl.custom_minimum_size.x = 40
		row.add_child(seg_lbl)

		var seg_dd := OptionButton.new()
		seg_dd.clip_text = true
		seg_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg_dd.add_item("(none)")
		var seg_selected: int = 0
		for j in range(all_enemies.size()):
			var s: ShipData = all_enemies[j]
			var elabel: String = s.display_name if s.display_name != "" else s.id
			seg_dd.add_item(elabel)
			seg_dd.set_item_metadata(j + 1, s.id)
			if s.id == seg_ship_id:
				seg_selected = j + 1
		seg_dd.selected = seg_selected
		var captured_i: int = i
		seg_dd.item_selected.connect(func(idx: int) -> void:
			if not _working_boss or captured_i >= _working_boss.segments.size():
				return
			var s: Dictionary = _working_boss.segments[captured_i] as Dictionary
			if idx == 0:
				s["ship_id"] = ""
				s["weapon_overrides"] = []
			else:
				s["ship_id"] = str(seg_dd.get_item_metadata(idx))
				s["weapon_overrides"] = []
			_working_boss.segments[captured_i] = s
			_update_boss_preview()
			_rebuild_right_panel()
		)
		row.add_child(seg_dd)

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
			_update_boss_preview()
			_rebuild_right_panel()
	)
	btn_row.add_child(add_btn)
	ThemeManager.apply_button_style(add_btn)

	if _working_boss.segments.size() > 0:
		var rem_btn := Button.new()
		rem_btn.text = "REMOVE LAST"
		rem_btn.pressed.connect(func() -> void:
			if _working_boss and _working_boss.segments.size() > 0:
				# Clean up required_segment_destroys references
				var last_idx: int = _working_boss.segments.size() - 1
				_working_boss.required_segment_destroys.erase(last_idx)
				_working_boss.segments.remove_at(last_idx)
				_update_boss_preview()
				_rebuild_right_panel()
		)
		btn_row.add_child(rem_btn)
		ThemeManager.apply_button_style(rem_btn)

	_add_section_spacer(vbox)

	# ── DETACH CONFIG (per segment) ──
	if _working_boss.segments.size() > 0:
		var detach_header := Label.new()
		detach_header.text = "DETACH"
		detach_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(detach_header)

		for i in range(_working_boss.segments.size()):
			var seg: Dictionary = _working_boss.segments[i] as Dictionary
			var can_detach: bool = bool(seg.get("can_detach", false))

			var seg_label := Label.new()
			seg_label.text = "Segment %d" % i
			seg_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			vbox.add_child(seg_label)

			var detach_check := CheckButton.new()
			detach_check.text = "Can Detach"
			detach_check.button_pressed = can_detach
			var captured_i2: int = i
			detach_check.toggled.connect(func(pressed: bool) -> void:
				if _working_boss and captured_i2 < _working_boss.segments.size():
					var s: Dictionary = _working_boss.segments[captured_i2] as Dictionary
					s["can_detach"] = pressed
					_working_boss.segments[captured_i2] = s
					_rebuild_right_panel()
			)
			vbox.add_child(detach_check)

			if can_detach:
				var reattach_check := CheckButton.new()
				reattach_check.text = "Reattach after path"
				reattach_check.button_pressed = bool(seg.get("reattach", true))
				reattach_check.toggled.connect(func(pressed: bool) -> void:
					if _working_boss and captured_i2 < _working_boss.segments.size():
						var s: Dictionary = _working_boss.segments[captured_i2] as Dictionary
						s["reattach"] = pressed
						_working_boss.segments[captured_i2] = s
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
					if _working_boss and captured_i2 < _working_boss.segments.size():
						var s: Dictionary = _working_boss.segments[captured_i2] as Dictionary
						s["detach_speed"] = val
						_working_boss.segments[captured_i2] = s
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
					if _working_boss and captured_i2 < _working_boss.segments.size():
						var s: Dictionary = _working_boss.segments[captured_i2] as Dictionary
						s["detach_hp_threshold"] = val
						_working_boss.segments[captured_i2] = s
				)


func _build_boss_weapons_tab(vbox: VBoxContainer) -> void:
	## Dedicated weapons tab — labeled dropdowns for every hardpoint on core + all segments.
	# ── CORE WEAPONS ──
	if _working_boss.core_ship_id != "":
		var core_label := Label.new()
		core_label.text = "CORE"
		core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		core_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		vbox.add_child(core_label)
		_build_weapon_overrides_section(vbox, _working_boss.core_ship_id, _working_boss.core_weapon_overrides, func(overrides: Array) -> void:
			if _working_boss:
				_working_boss.core_weapon_overrides = overrides
		)
		_add_section_spacer(vbox)

	# ── SEGMENT WEAPONS ──
	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		if seg_ship_id == "":
			continue
		var ship: ShipData = ShipDataManager.load_by_id(seg_ship_id)
		var seg_name: String = ship.display_name if ship and ship.display_name != "" else seg_ship_id
		var seg_label := Label.new()
		seg_label.text = "SEGMENT %d — %s" % [i, seg_name]
		seg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seg_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		vbox.add_child(seg_label)
		var seg_overrides: Array = seg.get("weapon_overrides", []) as Array
		var captured_i: int = i
		_build_weapon_overrides_section(vbox, seg_ship_id, seg_overrides, func(new_overrides: Array) -> void:
			if _working_boss and captured_i < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[captured_i] as Dictionary
				s["weapon_overrides"] = new_overrides
				_working_boss.segments[captured_i] = s
		)
		_add_section_spacer(vbox)

	# ── PREVIEW ALL WEAPONS ──
	var preview_btn := Button.new()
	preview_btn.text = "PREVIEW ALL WEAPONS"
	preview_btn.custom_minimum_size = Vector2(0, 34)
	preview_btn.pressed.connect(func() -> void:
		if _weapon_preview_active:
			_stop_boss_weapon_preview_all()
			preview_btn.text = "PREVIEW ALL WEAPONS"
		else:
			_start_boss_weapon_preview_all()
			preview_btn.text = "STOP"
	)
	ThemeManager.apply_button_style(preview_btn)
	vbox.add_child(preview_btn)


func _build_boss_health_tab(vbox: VBoxContainer) -> void:
	## Dedicated health tab — hull/shield sliders for core + all segments.
	var parts: Array[Dictionary] = _get_boss_parts_with_labels()
	for part in parts:
		var ship_id: String = part["ship_id"]
		var label_text: String = part["label"]
		var ship: ShipData = ShipDataManager.load_by_id(ship_id)
		if not ship:
			continue

		var part_label := Label.new()
		part_label.text = label_text
		part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		part_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		vbox.add_child(part_label)

		var hull_hp: float = float(ship.stats.get("hull_hp", 50))
		var shield_hp: float = float(ship.stats.get("shield_hp", 0))
		var captured_id: String = ship_id

		# Hull
		var hull_row := HBoxContainer.new()
		hull_row.add_theme_constant_override("separation", 6)
		vbox.add_child(hull_row)
		var hull_lbl := Label.new()
		hull_lbl.text = "HULL"
		hull_lbl.custom_minimum_size.x = 40
		hull_row.add_child(hull_lbl)
		var hull_slider := HSlider.new()
		hull_slider.min_value = 10
		hull_slider.max_value = 1000
		hull_slider.step = 5
		hull_slider.value = hull_hp
		hull_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hull_row.add_child(hull_slider)
		var hull_val := Label.new()
		hull_val.text = str(int(hull_hp))
		hull_val.custom_minimum_size.x = 40
		hull_row.add_child(hull_val)
		hull_slider.value_changed.connect(func(val: float) -> void:
			hull_val.text = str(int(val))
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.stats["hull_hp"] = val
				ShipDataManager.save(captured_id, s.to_dict())
		)

		# Shield
		var shd_row := HBoxContainer.new()
		shd_row.add_theme_constant_override("separation", 6)
		vbox.add_child(shd_row)
		var shd_lbl := Label.new()
		shd_lbl.text = "SHD"
		shd_lbl.custom_minimum_size.x = 40
		shd_row.add_child(shd_lbl)
		var shd_slider := HSlider.new()
		shd_slider.min_value = 0
		shd_slider.max_value = 500
		shd_slider.step = 5
		shd_slider.value = shield_hp
		shd_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shd_row.add_child(shd_slider)
		var shd_val := Label.new()
		shd_val.text = str(int(shield_hp))
		shd_val.custom_minimum_size.x = 40
		shd_row.add_child(shd_val)
		shd_slider.value_changed.connect(func(val: float) -> void:
			shd_val.text = str(int(val))
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.stats["shield_hp"] = val
				ShipDataManager.save(captured_id, s.to_dict())
		)

		_add_section_spacer(vbox)


func _build_boss_hitbox_tab(vbox: VBoxContainer) -> void:
	## Dedicated hitbox tab — shape/W/H for core + all segments.
	var parts: Array[Dictionary] = _get_boss_parts_with_labels()
	for part in parts:
		var ship_id: String = part["ship_id"]
		var label_text: String = part["label"]
		var ship: ShipData = ShipDataManager.load_by_id(ship_id)
		if not ship:
			continue

		var part_label := Label.new()
		part_label.text = label_text
		part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		part_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		vbox.add_child(part_label)

		var captured_id: String = ship_id

		# Shape
		var shape_hbox := HBoxContainer.new()
		shape_hbox.add_theme_constant_override("separation", 6)
		vbox.add_child(shape_hbox)
		var shape_lbl := Label.new()
		shape_lbl.text = "SHAPE"
		shape_lbl.custom_minimum_size.x = 50
		shape_hbox.add_child(shape_lbl)
		var shape_dd := OptionButton.new()
		shape_dd.clip_text = true
		shape_dd.add_item("Circle", 0)
		shape_dd.add_item("Rectangle", 1)
		shape_dd.add_item("Capsule", 2)
		match ship.collision_shape:
			"rectangle": shape_dd.selected = 1
			"capsule": shape_dd.selected = 2
			_: shape_dd.selected = 0
		shape_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shape_dd.item_selected.connect(func(idx: int) -> void:
			var shapes: Array[String] = ["circle", "rectangle", "capsule"]
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.collision_shape = shapes[idx]
				ShipDataManager.save(captured_id, s.to_dict())
			if _hitbox_overlay:
				_hitbox_overlay.queue_redraw()
		)
		shape_hbox.add_child(shape_dd)

		# Width
		var w_row := HBoxContainer.new()
		w_row.add_theme_constant_override("separation", 6)
		vbox.add_child(w_row)
		var w_lbl := Label.new()
		w_lbl.text = "W"
		w_lbl.custom_minimum_size.x = 50
		w_row.add_child(w_lbl)
		var w_slider := HSlider.new()
		w_slider.min_value = 6
		w_slider.max_value = 400
		w_slider.step = 2
		w_slider.value = ship.collision_width
		w_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_row.add_child(w_slider)
		var w_val := Label.new()
		w_val.text = str(int(ship.collision_width))
		w_val.custom_minimum_size.x = 40
		w_row.add_child(w_val)
		w_slider.value_changed.connect(func(val: float) -> void:
			w_val.text = str(int(val))
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.collision_width = val
				ShipDataManager.save(captured_id, s.to_dict())
			if _hitbox_overlay:
				_hitbox_overlay.queue_redraw()
		)

		# Height
		var h_row := HBoxContainer.new()
		h_row.add_theme_constant_override("separation", 6)
		vbox.add_child(h_row)
		var h_lbl := Label.new()
		h_lbl.text = "H"
		h_lbl.custom_minimum_size.x = 50
		h_row.add_child(h_lbl)
		var h_slider := HSlider.new()
		h_slider.min_value = 6
		h_slider.max_value = 400
		h_slider.step = 2
		h_slider.value = ship.collision_height
		h_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_row.add_child(h_slider)
		var h_val := Label.new()
		h_val.text = str(int(ship.collision_height))
		h_val.custom_minimum_size.x = 40
		h_row.add_child(h_val)
		h_slider.value_changed.connect(func(val: float) -> void:
			h_val.text = str(int(val))
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.collision_height = val
				ShipDataManager.save(captured_id, s.to_dict())
			if _hitbox_overlay:
				_hitbox_overlay.queue_redraw()
		)

		_add_section_spacer(vbox)


func _build_boss_destruction_tab(vbox: VBoxContainer) -> void:
	## Checkboxes for which segments must be destroyed before core is vulnerable.
	var header := Label.new()
	header.text = "DESTROY BEFORE CORE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var hint := Label.new()
	hint.text = "Check segments that must be destroyed\nbefore the core takes damage."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	_add_section_spacer(vbox)

	if _working_boss.segments.size() == 0:
		var none_label := Label.new()
		none_label.text = "No segments added yet."
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(none_label)
		return

	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		var ship: ShipData = ShipDataManager.load_by_id(seg_ship_id) if seg_ship_id != "" else null
		var seg_name: String = ship.display_name if ship and ship.display_name != "" else seg_ship_id
		if seg_name == "":
			seg_name = "(no ship)"

		var check := CheckButton.new()
		check.text = "Segment %d — %s" % [i, seg_name]
		check.button_pressed = _working_boss.required_segment_destroys.has(i)
		var captured_i: int = i
		check.toggled.connect(func(pressed: bool) -> void:
			if not _working_boss:
				return
			if pressed and not _working_boss.required_segment_destroys.has(captured_i):
				_working_boss.required_segment_destroys.append(captured_i)
			elif not pressed:
				_working_boss.required_segment_destroys.erase(captured_i)
			# Derive boolean for backward compat
			_working_boss.core_immune_until_segments_dead = _working_boss.required_segment_destroys.size() > 0
		)
		vbox.add_child(check)


func _build_boss_alignment_tab(vbox: VBoxContainer) -> void:
	## Offset tweaking for segments and collision offsets.
	if _working_boss.segments.size() == 0:
		var none_label := Label.new()
		none_label.text = "No segments to align."
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(none_label)
		return

	# ── SEGMENT POSITIONS ──
	var pos_header := Label.new()
	pos_header.text = "SEGMENT POSITIONS"
	pos_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pos_header)

	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		var ship: ShipData = ShipDataManager.load_by_id(seg_ship_id) if seg_ship_id != "" else null
		var seg_name: String = ship.display_name if ship and ship.display_name != "" else seg_ship_id
		if seg_name == "":
			seg_name = "(no ship)"

		var seg_label := Label.new()
		seg_label.text = "Segment %d — %s" % [i, seg_name]
		seg_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		vbox.add_child(seg_label)

		var offset_arr: Array = seg.get("offset", [0.0, 0.0]) as Array
		var ox: float = float(offset_arr[0]) if offset_arr.size() > 0 else 0.0
		var oy: float = float(offset_arr[1]) if offset_arr.size() > 1 else 0.0
		var captured_i: int = i

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
			if _working_boss and captured_i < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[captured_i] as Dictionary
				var off: Array = s.get("offset", [0.0, 0.0]) as Array
				s["offset"] = [val, float(off[1]) if off.size() > 1 else 0.0]
				_working_boss.segments[captured_i] = s
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
			if _working_boss and captured_i < _working_boss.segments.size():
				var s: Dictionary = _working_boss.segments[captured_i] as Dictionary
				var off: Array = s.get("offset", [0.0, 0.0]) as Array
				s["offset"] = [float(off[0]) if off.size() > 0 else 0.0, val]
				_working_boss.segments[captured_i] = s
				_update_boss_preview()
		)

		_add_section_spacer(vbox)

	# ── COLLISION OFFSETS ──
	var col_header := Label.new()
	col_header.text = "COLLISION OFFSETS"
	col_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(col_header)

	var parts: Array[Dictionary] = _get_boss_parts_with_labels()
	for part in parts:
		var ship_id: String = part["ship_id"]
		var label_text: String = part["label"]
		var ship: ShipData = ShipDataManager.load_by_id(ship_id)
		if not ship:
			continue

		var part_label := Label.new()
		part_label.text = label_text
		part_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		vbox.add_child(part_label)

		var captured_id: String = ship_id

		# Offset X
		var ox_row := HBoxContainer.new()
		ox_row.add_theme_constant_override("separation", 6)
		vbox.add_child(ox_row)
		var ox_lbl := Label.new()
		ox_lbl.text = "OX"
		ox_lbl.custom_minimum_size.x = 30
		ox_row.add_child(ox_lbl)
		var ox_slider := HSlider.new()
		ox_slider.min_value = -200
		ox_slider.max_value = 200
		ox_slider.step = 1
		ox_slider.value = ship.collision_offset_x
		ox_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ox_row.add_child(ox_slider)
		var ox_val := Label.new()
		ox_val.text = str(int(ship.collision_offset_x))
		ox_val.custom_minimum_size.x = 40
		ox_row.add_child(ox_val)
		ox_slider.value_changed.connect(func(val: float) -> void:
			ox_val.text = str(int(val))
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.collision_offset_x = val
				ShipDataManager.save(captured_id, s.to_dict())
			if _hitbox_overlay:
				_hitbox_overlay.queue_redraw()
		)

		# Offset Y
		var oy_row := HBoxContainer.new()
		oy_row.add_theme_constant_override("separation", 6)
		vbox.add_child(oy_row)
		var oy_lbl := Label.new()
		oy_lbl.text = "OY"
		oy_lbl.custom_minimum_size.x = 30
		oy_row.add_child(oy_lbl)
		var oy_slider := HSlider.new()
		oy_slider.min_value = -200
		oy_slider.max_value = 200
		oy_slider.step = 1
		oy_slider.value = ship.collision_offset_y
		oy_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		oy_row.add_child(oy_slider)
		var oy_val := Label.new()
		oy_val.text = str(int(ship.collision_offset_y))
		oy_val.custom_minimum_size.x = 40
		oy_row.add_child(oy_val)
		oy_slider.value_changed.connect(func(val: float) -> void:
			oy_val.text = str(int(val))
			var s: ShipData = ShipDataManager.load_by_id(captured_id)
			if s:
				s.collision_offset_y = val
				ShipDataManager.save(captured_id, s.to_dict())
			if _hitbox_overlay:
				_hitbox_overlay.queue_redraw()
		)

		_add_section_spacer(vbox)


func _get_boss_parts_with_labels() -> Array[Dictionary]:
	## Returns an array of {ship_id, label} for core + all segments with assigned ships.
	var parts: Array[Dictionary] = []
	if _working_boss.core_ship_id != "":
		var core_ship: ShipData = ShipDataManager.load_by_id(_working_boss.core_ship_id)
		var core_name: String = core_ship.display_name if core_ship and core_ship.display_name != "" else _working_boss.core_ship_id
		parts.append({"ship_id": _working_boss.core_ship_id, "label": "CORE — %s" % core_name})
	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		if seg_ship_id == "":
			continue
		var ship: ShipData = ShipDataManager.load_by_id(seg_ship_id)
		var seg_name: String = ship.display_name if ship and ship.display_name != "" else seg_ship_id
		parts.append({"ship_id": seg_ship_id, "label": "SEG %d — %s" % [i, seg_name]})
	return parts


func _start_boss_weapon_preview_all() -> void:
	## Start weapon preview for ALL boss parts — fires every weapon simultaneously.
	_stop_boss_weapon_preview_all()
	_weapon_preview_active = true

	var vp_size: Vector2 = get_viewport_rect().size
	var center := Vector2(
		LEFT_PANEL_W + (vp_size.x - LEFT_PANEL_W - RIGHT_PANEL_W) * 0.5,
		(vp_size.y - HUD_HEIGHT) * 0.5
	)

	# Collect all (ship_id, weapon_overrides, offset) tuples
	var weapon_parts: Array[Dictionary] = []
	if _working_boss.core_ship_id != "":
		weapon_parts.append({"ship_id": _working_boss.core_ship_id, "overrides": _working_boss.core_weapon_overrides, "offset": Vector2.ZERO})
	for i in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[i] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		if seg_ship_id == "":
			continue
		var offset_arr: Array = seg.get("offset", [0.0, 0.0]) as Array
		var off := Vector2(float(offset_arr[0]) if offset_arr.size() > 0 else 0.0, float(offset_arr[1]) if offset_arr.size() > 1 else 0.0)
		weapon_parts.append({"ship_id": seg_ship_id, "overrides": seg.get("weapon_overrides", []) as Array, "offset": off})

	for part in weapon_parts:
		var ship: ShipData = ShipDataManager.load_by_id(part["ship_id"])
		if not ship:
			continue
		var overrides: Array = part["overrides"] as Array
		var offset: Vector2 = part["offset"] as Vector2

		# Determine hardpoint offsets — empty means single center hardpoint
		var hp_offsets: Array = ship.hardpoint_offsets
		if hp_offsets.size() == 0:
			hp_offsets = [[0, 0]]

		# Build override lookup
		var override_map: Dictionary = {}
		for ovr in overrides:
			var d: Dictionary = ovr as Dictionary
			override_map[int(d.get("hardpoint_index", 0))] = str(d.get("weapon_id", ""))

		for hp_idx in range(hp_offsets.size()):
			var weapon_id: String = str(override_map.get(hp_idx, ""))
			if weapon_id == "":
				weapon_id = ship.weapon_id
			if weapon_id == "":
				continue
			var weapon: WeaponData = WeaponDataManager.load_by_id(weapon_id)
			if not weapon:
				continue

			# Apply individual hardpoint offset from ship data
			var hp_off: Variant = hp_offsets[hp_idx]
			var hp_ox: float = float(hp_off[0]) if hp_off is Array and hp_off.size() >= 1 else 0.0
			var hp_oy: float = float(hp_off[1]) if hp_off is Array and hp_off.size() >= 2 else 0.0

			var fire_point := Node2D.new()
			fire_point.position = center + offset + Vector2(hp_ox, hp_oy)
			_ship_viewport.add_child(fire_point)
			_weapon_preview_fire_points.append(fire_point)

			var controller := HardpointController.new()
			controller.is_enemy = true
			fire_point.add_child(controller)
			controller.setup(weapon, 180.0 + weapon.direction_deg, _weapon_preview_container, hp_idx)
			var loop_id: String = controller.get_loop_id()
			if loop_id != "":
				_weapon_preview_loop_ids.append(loop_id)
			controller.activate()
			_weapon_preview_controllers.append(controller)

	# Start only preview loops (not every loop in LoopMixer)
	for lid in _weapon_preview_loop_ids:
		LoopMixer.start_loop(lid)


func _stop_boss_weapon_preview_all() -> void:
	_weapon_preview_active = false
	# Force-remove loops first — guaranteed cleanup even if controllers are already freed
	for lid in _weapon_preview_loop_ids:
		LoopMixer.remove_loop(lid)
	_weapon_preview_loop_ids.clear()
	for controller: HardpointController in _weapon_preview_controllers:
		if controller and is_instance_valid(controller):
			controller.cleanup()
	_weapon_preview_controllers.clear()
	for fp: Node2D in _weapon_preview_fire_points:
		if fp and is_instance_valid(fp):
			fp.queue_free()
	_weapon_preview_fire_points.clear()
	if _weapon_preview_container:
		for child in _weapon_preview_container.get_children():
			child.queue_free()


func _build_weapon_overrides_section(vbox: VBoxContainer, ship_id: String, overrides: Array, on_change: Callable) -> void:
	## Builds per-hardpoint weapon dropdown rows for a given enemy ship.
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

	# Build override lookups
	var override_map: Dictionary = {}
	var lead_map: Dictionary = {}
	for ovr in overrides:
		var d: Dictionary = ovr as Dictionary
		var hp_idx: int = int(d.get("hardpoint_index", 0))
		override_map[hp_idx] = str(d.get("weapon_id", ""))
		lead_map[hp_idx] = float(d.get("audio_lead_sec", 0.0))

	for hp_idx in range(hp_count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "Slot %d" % hp_idx
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

		# Audio lead spinner
		var lead_spin := SpinBox.new()
		lead_spin.min_value = 0.0
		lead_spin.max_value = 30.0
		lead_spin.step = 0.5
		lead_spin.suffix = "s"
		lead_spin.custom_minimum_size.x = 70
		lead_spin.tooltip_text = "Audio lead (seconds before boss arrival)"
		lead_spin.value = float(lead_map.get(hp_idx, 0.0))

		dd.item_selected.connect(func(item_idx: int) -> void:
			if not _working_boss:
				return
			var new_overrides: Array = []
			for existing in overrides:
				var ed: Dictionary = existing as Dictionary
				if int(ed.get("hardpoint_index", -1)) != captured_idx:
					new_overrides.append(existing)
			if item_idx > 0:
				new_overrides.append({
					"hardpoint_index": captured_idx,
					"weapon_id": str(dd.get_item_metadata(item_idx)),
					"audio_lead_sec": lead_spin.value,
				})
			on_change.call(new_overrides)
		)
		lead_spin.value_changed.connect(func(_v: float) -> void:
			if not _working_boss:
				return
			var new_overrides: Array = []
			for existing in overrides:
				var ed: Dictionary = existing as Dictionary
				if int(ed.get("hardpoint_index", -1)) != captured_idx:
					new_overrides.append(existing)
			if dd.selected > 0:
				new_overrides.append({
					"hardpoint_index": captured_idx,
					"weapon_id": str(dd.get_item_metadata(dd.selected)),
					"audio_lead_sec": lead_spin.value,
				})
			on_change.call(new_overrides)
		)
		row.add_child(dd)
		row.add_child(lead_spin)


func _build_boss_glow_tab(vbox: VBoxContainer) -> void:
	var glow_label := Label.new()
	glow_label.text = "GLOW SETTINGS"
	glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(glow_label)

	if not _working_boss:
		return

	# Collect all unique ship IDs used by this boss
	var part_ids: Array[Array] = []  # [label, ship_id]
	if _working_boss.core_ship_id != "":
		part_ids.append(["CORE", _working_boss.core_ship_id])
	for si in range(_working_boss.segments.size()):
		var seg: Dictionary = _working_boss.segments[si] as Dictionary
		var seg_ship_id: String = str(seg.get("ship_id", ""))
		if seg_ship_id != "":
			var seg_label: String = str(seg.get("label", "Segment %d" % si))
			# Skip duplicates
			var found := false
			for existing in part_ids:
				if existing[1] == seg_ship_id:
					found = true
					break
			if not found:
				part_ids.append([seg_label.to_upper(), seg_ship_id])

	for part in part_ids:
		var plabel: String = part[0] as String
		var pid: String = part[1] as String
		var ship: ShipData = ShipDataManager.load_by_id(pid)
		if not ship:
			continue

		_add_section_spacer(vbox)
		var part_header := Label.new()
		part_header.text = plabel + " (" + pid + ")"
		part_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		part_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		vbox.add_child(part_header)

		# HDR slider
		var hdr_key: String = "boss_glow_hdr_" + pid
		_add_slider_row(vbox, hdr_key, "HDR", 0.0, 4.0, 0.01)
		# WHITE slider
		var white_key: String = "boss_glow_white_" + pid
		_add_slider_row(vbox, white_key, "WHITE", 0.0, 1.0, 0.01)
		# WIDTH slider
		var width_key: String = "boss_glow_width_" + pid
		_add_slider_row(vbox, width_key, "WIDTH", 0.01, 0.5, 0.005)

		# Set initial values
		_updating_sliders = true
		if _sliders.has(hdr_key):
			(_sliders[hdr_key] as HSlider).value = ship.neon_hdr
		if _sliders.has(white_key):
			(_sliders[white_key] as HSlider).value = ship.neon_white
		if _sliders.has(width_key):
			(_sliders[width_key] as HSlider).value = ship.neon_width
		_updating_sliders = false

		# Connect change handlers that save directly to the part's ShipData
		var captured_pid: String = pid
		if _sliders.has(hdr_key):
			(_sliders[hdr_key] as HSlider).value_changed.connect(func(v: float) -> void:
				_on_boss_glow_changed(captured_pid, "neon_hdr", v)
			)
		if _sliders.has(white_key):
			(_sliders[white_key] as HSlider).value_changed.connect(func(v: float) -> void:
				_on_boss_glow_changed(captured_pid, "neon_white", v)
			)
		if _sliders.has(width_key):
			(_sliders[width_key] as HSlider).value_changed.connect(func(v: float) -> void:
				_on_boss_glow_changed(captured_pid, "neon_width", v)
			)


func _on_boss_glow_changed(ship_id: String, prop: String, value: float) -> void:
	if _updating_sliders:
		return
	var ship: ShipData = ShipDataManager.load_by_id(ship_id)
	if not ship:
		return
	ship.set(prop, value)
	ShipDataManager.save(ship_id, ship.to_dict())
	# Update all boss preview renderers that use this ship_id
	for node in _boss_preview_nodes:
		if is_instance_valid(node) and node is ShipRenderer:
			var r: ShipRenderer = node as ShipRenderer
			# Check if this renderer uses the changed ship
			var vid: String = ship.visual_id if ship.visual_id != "" else "sentinel"
			if r.enemy_visual_id == vid:
				if prop == "neon_hdr": r.neon_hdr = value
				elif prop == "neon_white": r.neon_white = value
				elif prop == "neon_width": r.neon_width = value


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
	if (_category == "ENEMIES" or _category == "ALLIES") and _working_enemy:
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
	# Boss glow sliders are handled by dedicated callbacks
	if key.begins_with("boss_glow_"):
		return

	var slider: HSlider = _sliders.get(key)
	if slider and slider.step < 0.1:
		_slider_labels[key].text = "%.2f" % value
	elif slider and slider.step < 1.0:
		_slider_labels[key].text = str(snapped(value, 0.1))
	else:
		_slider_labels[key].text = str(int(value))

	if (_category == "ENEMIES" or _category == "ALLIES") and _working_enemy:
		if key == "explosion_size":
			_working_enemy.explosion_size = value
		elif key == "collision_width":
			_working_enemy.collision_width = value
			_hitbox_overlay.queue_redraw()
		elif key == "collision_height":
			_working_enemy.collision_height = value
			_hitbox_overlay.queue_redraw()
		elif key == "neon_hdr":
			_working_enemy.neon_hdr = value
			if _ship_draw: _ship_draw.neon_hdr = value
		elif key == "neon_white":
			_working_enemy.neon_white = value
			if _ship_draw: _ship_draw.neon_white = value
		elif key == "neon_width":
			_working_enemy.neon_width = value
			if _ship_draw: _ship_draw.neon_width = value
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
	if (_category == "ENEMIES" or _category == "ALLIES") and _working_enemy:
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
	_weapon_preview_fire_point.position = _get_ship_display_pos() + Vector2(0, 20)
	_ship_viewport.add_child(_weapon_preview_fire_point)

	# Create HardpointController — same system as player/enemy gameplay
	_weapon_preview_controller = HardpointController.new()
	_weapon_preview_controller.is_enemy = true  # enemy collision layers
	_weapon_preview_fire_point.add_child(_weapon_preview_controller)
	_weapon_preview_controller.setup(weapon, 180.0 + weapon.direction_deg, _weapon_preview_container)

	# Start playback and activate (unmute loop)
	var lid: String = _weapon_preview_controller.get_loop_id()
	if lid != "":
		LoopMixer.start_loop(lid)
	_weapon_preview_controller.activate()


func _stop_weapon_preview() -> void:
	_weapon_preview_active = false
	if _weapon_preview_btn:
		_weapon_preview_btn.text = "PREVIEW"

	# Cleanup single controller (enemy editor)
	if _weapon_preview_controller:
		var lid: String = _weapon_preview_controller.get_loop_id()
		if lid != "":
			LoopMixer.remove_loop(lid)
		_weapon_preview_controller.cleanup()
		_weapon_preview_controller = null

	# Remove single fire point (enemy editor)
	if _weapon_preview_fire_point and is_instance_valid(_weapon_preview_fire_point):
		_weapon_preview_fire_point.queue_free()
		_weapon_preview_fire_point = null

	# Cleanup boss multi-weapon preview
	_stop_boss_weapon_preview_all()

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
	explosion.position = _get_ship_display_pos()
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
		var ship_pos: Vector2 = viewer._get_ship_display_pos()
		var col_shape: String = "circle"
		var col_w: float = 30.0
		var col_h: float = 30.0

		if viewer._category == "BOSSES" and viewer._working_boss:
			_draw_boss_hitboxes()
			return
		elif viewer._category == "ENEMIES" and viewer._working_enemy:
			col_shape = viewer._working_enemy.collision_shape
			col_w = viewer._working_enemy.collision_width
			col_h = viewer._working_enemy.collision_height
			if "collision_offset_x" in viewer._working_enemy:
				ship_pos += Vector2(viewer._working_enemy.collision_offset_x, viewer._working_enemy.collision_offset_y)
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

	func _draw_boss_hitboxes() -> void:
		var boss: BossData = viewer._working_boss
		if not boss:
			return
		# Collect all ship IDs with their preview positions
		var parts: Array[Dictionary] = []
		# Core
		if boss.core_ship_id != "":
			var vp_size: Vector2 = viewer.get_viewport_rect().size
			var center := Vector2(
				viewer.LEFT_PANEL_W + (vp_size.x - viewer.LEFT_PANEL_W - viewer.RIGHT_PANEL_W) * 0.5,
				(vp_size.y - viewer.HUD_HEIGHT) * 0.5
			)
			parts.append({"ship_id": boss.core_ship_id, "pos": center})
			# Segments
			for seg in boss.segments:
				var sd: Dictionary = seg as Dictionary
				var seg_sid: String = str(sd.get("ship_id", ""))
				if seg_sid == "":
					continue
				var offset_arr: Array = sd.get("offset", [0.0, 0.0]) as Array
				var ox: float = float(offset_arr[0]) if offset_arr.size() > 0 else 0.0
				var oy: float = float(offset_arr[1]) if offset_arr.size() > 1 else 0.0
				parts.append({"ship_id": seg_sid, "pos": center + Vector2(ox, oy)})

		var outline_color := Color(0.2, 1.0, 0.4, 0.6)
		var fill_color := Color(0.2, 1.0, 0.4, 0.08)

		for part in parts:
			var ship: ShipData = ShipDataManager.load_by_id(str(part["ship_id"]))
			if not ship:
				continue
			var col_ox: float = float(ship.collision_offset_x) if "collision_offset_x" in ship else 0.0
			var col_oy: float = float(ship.collision_offset_y) if "collision_offset_y" in ship else 0.0
			var pos: Vector2 = (part["pos"] as Vector2) + Vector2(col_ox, col_oy)
			var cs: String = ship.collision_shape
			var cw: float = ship.collision_width
			var ch: float = ship.collision_height
			match cs:
				"rectangle":
					var rect := Rect2(pos - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
					draw_rect(rect, fill_color, true)
					draw_rect(rect, outline_color, false, 1.5)
				"capsule":
					var is_horiz: bool = cw > ch
					var cap_r: float = minf(cw, ch) * 0.5
					var long_h: float = maxf(cw, ch) * 0.5
					var body_h: float = maxf(long_h - cap_r, 0.0)
					if is_horiz:
						var body_rect := Rect2(pos.x - body_h, pos.y - cap_r, body_h * 2.0, ch)
						draw_rect(body_rect, fill_color, true)
						_draw_circle_fill(pos + Vector2(-body_h, 0), cap_r, fill_color)
						_draw_circle_fill(pos + Vector2(body_h, 0), cap_r, fill_color)
						_draw_arc_outline(pos + Vector2(-body_h, 0), cap_r, PI * 0.5, PI * 1.5, outline_color)
						_draw_arc_outline(pos + Vector2(body_h, 0), cap_r, -PI * 0.5, PI * 0.5, outline_color)
						draw_line(pos + Vector2(-body_h, -cap_r), pos + Vector2(body_h, -cap_r), outline_color, 1.5)
						draw_line(pos + Vector2(-body_h, cap_r), pos + Vector2(body_h, cap_r), outline_color, 1.5)
					else:
						var body_rect := Rect2(pos.x - cap_r, pos.y - body_h, cw, body_h * 2.0)
						draw_rect(body_rect, fill_color, true)
						_draw_circle_fill(pos + Vector2(0, -body_h), cap_r, fill_color)
						_draw_circle_fill(pos + Vector2(0, body_h), cap_r, fill_color)
						_draw_arc_outline(pos + Vector2(0, -body_h), cap_r, PI, TAU, outline_color)
						_draw_arc_outline(pos + Vector2(0, body_h), cap_r, 0, PI, outline_color)
						draw_line(pos + Vector2(-cap_r, -body_h), pos + Vector2(-cap_r, body_h), outline_color, 1.5)
						draw_line(pos + Vector2(cap_r, -body_h), pos + Vector2(cap_r, body_h), outline_color, 1.5)
				_:
					var radius: float = cw * 0.5
					_draw_circle_fill(pos, radius, fill_color)
					_draw_arc_outline(pos, radius, 0, TAU, outline_color)


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
		"Trident", "Orrery", "Cargo Ship", "Bastion",
	]
	# Registry indices that are allies (not selectable as player ships)
	const ALLY_INDICES: Array[int] = [7]

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
		# For PLAYER category, map visual slot index to registry index
		if category == "PLAYER":
			var player_indices: Array[int] = _get_player_indices()
			if idx < player_indices.size():
				return player_indices[idx]
			return -1
		return idx

	func scroll_by(amount: float) -> void:
		var vp_h: float = viewer.get_viewport_rect().size.y if viewer else 1080.0
		var visible_h: float = vp_h - HUD_H - HEADER_HEIGHT
		var total_h: float = _get_slot_count() * SLOT_HEIGHT
		var max_scroll: float = maxf(total_h - visible_h, 0.0)
		scroll_offset = clampf(scroll_offset + amount, 0.0, max_scroll)
		queue_redraw()

	func _get_player_indices() -> Array[int]:
		var indices: Array[int] = []
		for i in range(SHIP_COUNT):
			if i not in ALLY_INDICES:
				indices.append(i)
		return indices

	func _get_slot_count() -> int:
		if category == "ENEMIES" or category == "ALLIES":
			return enemy_ships.size()
		elif category == "BOSSES":
			return boss_list.size()
		return _get_player_indices().size()

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
			"ALLIES": _draw_enemy_list()
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
		var player_indices: Array[int] = _get_player_indices()
		for slot_idx in range(player_indices.size()):
			var i: int = player_indices[slot_idx]
			var slot_y: float = HEADER_HEIGHT + SLOT_HEIGHT * slot_idx
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
			"biolume": return ShipRenderer.RenderMode.BIOLUME
			"toxic": return ShipRenderer.RenderMode.TOXIC
			"coral": return ShipRenderer.RenderMode.CORAL
			"abyssal": return ShipRenderer.RenderMode.ABYSSAL
			"bloodmoon": return ShipRenderer.RenderMode.BLOODMOON
			"phantom": return ShipRenderer.RenderMode.PHANTOM
			"aurora": return ShipRenderer.RenderMode.AURORA
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
