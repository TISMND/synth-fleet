class_name WaveManager
extends Node
## Scripted wave sequencer — spawns enemies in waves with configurable counts/stats.
## Also supports LevelData-driven spawning via setup_level().

signal wave_started(wave_index: int, total_waves: int)
signal wave_cleared(wave_index: int, total_waves: int)
signal all_waves_cleared
signal boss_transition_triggered(enc: Dictionary)


var _waves: Array = []
var _enemies_container: Node2D = null
var _current_wave: int = 0
var _enemies_spawned: int = 0
var _enemies_to_spawn: int = 0
var _enemies_alive: int = 0
var _spawn_timer: Timer = null
var _delay_timer: Timer = null

# Player reference for melee enemies
var _player_ref: Node2D = null

# Level-data mode
var _level_data: LevelData = null
var _level_mode: bool = false
var _sorted_encounters: Array[Dictionary] = []
var _next_encounter_idx: int = 0
var _scroll_distance: float = 0.0
var _stagger_queue: Array[Dictionary] = []  # Pending staggered spawns
var _projectiles_container: Node2D = null
var _pre_triggered_encounters: Dictionary = {}  # encounter index -> bool
var shared_renderer: EnemySharedRenderer = null

# Level events (boss transitions, etc.)
var _sorted_events: Array[Dictionary] = []
var _next_event_idx: int = 0

const PRESENCE_LEAD_DISTANCE: float = 160.0  # ~2s at 80px/s scroll speed

const ENEMY_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.5),
	Color(0.5, 1.0, 0.3),
	Color(1.0, 0.8, 0.2),
	Color(0.3, 0.5, 1.0),
	Color(1.0, 0.4, 0.9),
	Color(0.3, 1.0, 0.8),
]


func setup(waves: Array, enemies_container: Node2D, player: Node2D = null, proj_container: Node2D = null) -> void:
	_waves = waves
	_enemies_container = enemies_container
	_player_ref = player
	_projectiles_container = proj_container
	_level_mode = false
	_pre_triggered_encounters.clear()


func setup_level(level: LevelData, enemies_container: Node2D, player: Node2D = null, proj_container: Node2D = null) -> void:
	_player_ref = player
	_level_data = level
	_enemies_container = enemies_container
	_projectiles_container = proj_container
	_level_mode = true
	_scroll_distance = 0.0
	_next_encounter_idx = 0
	_stagger_queue.clear()
	_pre_triggered_encounters.clear()

	# Sort encounters by trigger_y
	_sorted_encounters.clear()
	for enc in level.encounters:
		_sorted_encounters.append(enc.duplicate())
	_sorted_encounters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["trigger_y"]) < float(b["trigger_y"])
	)

	# Sort events by trigger_y
	_sorted_events.clear()
	_next_event_idx = 0
	for ev in level.events:
		_sorted_events.append(ev.duplicate())
	_sorted_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["trigger_y"]) < float(b["trigger_y"])
	)


func advance_scroll(distance: float) -> void:
	if not _level_mode:
		return
	_scroll_distance = distance
	_check_presence_pretriggers()
	_check_encounter_triggers()
	_check_event_triggers()


func _check_presence_pretriggers() -> void:
	var lead_distance: float = _scroll_distance + PRESENCE_LEAD_DISTANCE
	for i in range(_sorted_encounters.size()):
		if _pre_triggered_encounters.has(i):
			continue
		var enc: Dictionary = _sorted_encounters[i]
		var trigger_y: float = float(enc["trigger_y"])
		if trigger_y > lead_distance:
			break  # Sorted by trigger_y, so no more encounters within range
		_pre_triggered_encounters[i] = true


func _check_encounter_triggers() -> void:
	while _next_encounter_idx < _sorted_encounters.size():
		var enc: Dictionary = _sorted_encounters[_next_encounter_idx]
		var trigger_y: float = float(enc["trigger_y"])
		if _scroll_distance >= trigger_y:
			_spawn_encounter(enc)
			_next_encounter_idx += 1
		else:
			break


func _check_event_triggers() -> void:
	while _next_event_idx < _sorted_events.size():
		var ev: Dictionary = _sorted_events[_next_event_idx]
		var trigger_y: float = float(ev["trigger_y"])
		if _scroll_distance >= trigger_y:
			var event_type: String = str(ev.get("event_type", ""))
			if event_type == "boss_transition":
				boss_transition_triggered.emit(ev)
			_next_event_idx += 1
		else:
			break


func _spawn_encounter(enc: Dictionary) -> void:
	if not _enemies_container:
		return

	# Boss encounter — spawn entire boss composition
	var boss_id: String = str(enc.get("boss_id", ""))
	if boss_id != "":
		_spawn_boss_encounter(enc, boss_id)
		return

	var path_id: String = str(enc.get("path_id", ""))
	var formation_id: String = str(enc.get("formation_id", ""))
	var ship_id: String = str(enc.get("ship_id", "enemy_1"))
	var speed: float = float(enc.get("speed", 200.0))
	var count: int = int(enc.get("count", 1))
	var spacing: float = float(enc.get("spacing", 200.0))
	var x_offset: float = float(enc.get("x_offset", 0.0))
	var enc_is_melee: bool = bool(enc.get("is_melee", false))
	var enc_turn_speed: float = float(enc.get("turn_speed", 90.0))
	var enc_weapons_active: bool = bool(enc.get("weapons_active", true))

	# Load path (skip for melee encounters)
	var curve: Curve2D = null
	if not enc_is_melee and path_id != "":
		var fp: FlightPathData = FlightPathDataManager.load_by_id(path_id)
		if fp:
			curve = fp.to_curve2d()
		else:
			push_warning("WaveManager: flight path '%s' not found" % path_id)

	# Build slot list: either from formation or single ship
	var slots: Array[Dictionary] = []
	if formation_id != "":
		var fm: FormationData = FormationDataManager.load_by_id(formation_id)
		if not fm:
			push_warning("WaveManager: formation '%s' not found" % formation_id)
		if fm:
			for slot in fm.slots:
				var off: Array = slot.get("offset", [0, 0])
				slots.append({
					"offset": Vector2(float(off[0]), float(off[1])),
					"ship_id": ship_id,
				})
	if slots.size() == 0:
		# Single ship mode
		slots.append({"offset": Vector2.ZERO, "ship_id": ship_id})

	# Spawn count copies, staggered by spacing (converted to time delay)
	for copy_idx in range(count):
		var delay: float = float(copy_idx) * spacing / maxf(speed, 1.0)
		for slot in slots:
			var spawn_data: Dictionary = {
				"curve": curve,
				"speed": speed,
				"offset": slot["offset"],
				"origin": Vector2(x_offset, 0),
				"ship_id": str(slot["ship_id"]),
				"delay": delay,
				"rotate_with_path": bool(enc.get("rotate_with_path", false)),
				"is_melee": enc_is_melee,
				"turn_speed": enc_turn_speed,
				"weapons_active": enc_weapons_active,
			}
			if delay <= 0.0:
				_do_spawn_enemy(spawn_data)
			else:
				_stagger_queue.append(spawn_data)
				_start_stagger_timer(delay, spawn_data)


func _start_stagger_timer(delay: float, spawn_data: Dictionary) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = delay
	timer.timeout.connect(func() -> void:
		_do_spawn_enemy(spawn_data)
		_stagger_queue.erase(spawn_data)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()


func _do_spawn_enemy(spawn_data: Dictionary) -> void:
	if not _enemies_container:
		return
	var enemy := Enemy.new()
	var curve_val: Variant = spawn_data.get("curve")
	if curve_val is Curve2D:
		enemy.path_curve = curve_val as Curve2D
	enemy.path_speed = float(spawn_data.get("speed", 200.0))
	var offset_val: Variant = spawn_data.get("offset")
	if offset_val is Vector2:
		enemy.path_offset = offset_val as Vector2
	var origin_val: Variant = spawn_data.get("origin")
	if origin_val is Vector2:
		enemy.path_origin = origin_val as Vector2
	var sid: String = str(spawn_data.get("ship_id", ""))
	if sid != "":
		var ship: ShipData = ShipDataManager.load_by_id(sid)
		if ship:
			enemy.health = int(ship.stats.get("hull_hp", 30))
			enemy.shield = int(ship.stats.get("shield_hp", 0))
			enemy.enemy_color = ENEMY_COLORS[sid.hash() % ENEMY_COLORS.size()]
			enemy.visual_id = ship.visual_id if ship.visual_id != "" else "sentinel"
			enemy.render_mode_str = ship.render_mode if ship.render_mode != "" else "neon"
			enemy.grid_size = ship.grid_size
			enemy.ship_id = sid
			# Pass weapon data for EnemyWeaponController
			if ship.type == "enemy" and ship.weapon_id != "":
				enemy.ship_data_ref = ship
				enemy.player_ref = _player_ref
				enemy.projectiles_container = _projectiles_container
		else:
			enemy.health = 30
			enemy.enemy_color = ENEMY_COLORS[sid.hash() % ENEMY_COLORS.size()]
	else:
		enemy.health = 30
		enemy.enemy_color = ENEMY_COLORS[randi() % ENEMY_COLORS.size()]

	enemy.shared_renderer = shared_renderer
	enemy.rotate_with_path = bool(spawn_data.get("rotate_with_path", false))

	# Weapons active flag from encounter data
	enemy.weapons_active = bool(spawn_data.get("weapons_active", true))

	# Melee mode
	var spawn_is_melee: bool = bool(spawn_data.get("is_melee", false))
	if spawn_is_melee:
		enemy.is_melee = true
		enemy.melee_speed = float(spawn_data.get("speed", 200.0))
		enemy.melee_turn_speed = float(spawn_data.get("turn_speed", 90.0))
		if is_instance_valid(_player_ref):
			enemy.set_melee_target(_player_ref)

	# Position at start of curve if path-following, melee at top with offset, otherwise random drift
	if spawn_is_melee:
		var melee_off: Vector2 = enemy.path_offset
		var melee_orig: Vector2 = enemy.path_origin
		enemy.position = Vector2(960.0 + melee_orig.x + melee_off.x, -30.0 + melee_off.y)
	elif enemy.path_curve != null and enemy.path_curve.point_count >= 2:
		var start_pos: Vector2 = enemy.path_curve.sample_baked(0.0)
		var spawn_pos: Vector2 = start_pos + enemy.path_offset + enemy.path_origin
		# Ensure path-following enemies start off-screen (safe margin for large sprites)
		if spawn_pos.y > -200.0:
			enemy.path_origin.y -= (spawn_pos.y + 200.0)
		enemy.position = start_pos + enemy.path_offset + enemy.path_origin
	else:
		enemy.position = Vector2(randf_range(100.0, 1820.0), -30.0)
		enemy.drift_speed = float(spawn_data.get("speed", 100.0))

	enemy.tree_exiting.connect(_on_enemy_exited, CONNECT_ONE_SHOT)
	_enemies_container.add_child(enemy)
	GameState.level_stats["enemies_total"] = int(GameState.level_stats.get("enemies_total", 0)) + 1


func _spawn_boss_encounter(enc: Dictionary, boss_id: String) -> void:
	var boss: BossData = BossDataManager.load_by_id(boss_id)
	if not boss:
		push_warning("WaveManager: boss '%s' not found" % boss_id)
		return

	var x_offset: float = float(enc.get("x_offset", 0.0))
	var spawn_x: float = 960.0 + x_offset
	var spawn_y: float = -300.0  # Start well above screen — large bosses with segments need headroom
	var strafe_speed: float = float(enc.get("speed", 80.0))
	var enc_weapons_active: bool = bool(enc.get("weapons_active", true))

	# Spawn core enemy
	var core_enemy: Enemy = _make_boss_part(boss.core_ship_id, Vector2(spawn_x, spawn_y), enc_weapons_active)
	if not core_enemy:
		push_warning("WaveManager: boss core ship '%s' not found" % boss.core_ship_id)
		return

	core_enemy.is_boss_strafe = true
	core_enemy.boss_strafe_y = 200.0
	core_enemy.boss_strafe_speed = strafe_speed
	core_enemy.boss_strafe_width = 300.0

	# Apply per-hardpoint weapon overrides for core
	if boss.core_weapon_overrides.size() > 0:
		core_enemy.weapon_overrides = boss.core_weapon_overrides

	core_enemy.set_meta("boss_part", true)
	core_enemy.tree_exiting.connect(_on_enemy_exited, CONNECT_ONE_SHOT)
	_enemies_container.add_child(core_enemy)

	# Spawn segments
	for seg_dict in boss.segments:
		var sd: Dictionary = seg_dict as Dictionary
		var seg_ship_id: String = str(sd.get("ship_id", ""))
		if seg_ship_id == "":
			continue
		var offset_arr: Array = sd.get("offset", [0.0, 0.0]) as Array
		var ox: float = float(offset_arr[0]) if offset_arr.size() > 0 else 0.0
		var oy: float = float(offset_arr[1]) if offset_arr.size() > 1 else 0.0
		var seg_offset := Vector2(ox, oy)

		var seg_enemy: Enemy = _make_boss_part(seg_ship_id, Vector2(spawn_x + ox, spawn_y + oy), enc_weapons_active)
		if not seg_enemy:
			continue

		# Apply per-hardpoint weapon overrides for segment
		var seg_weapon_ovr: Array = sd.get("weapon_overrides", []) as Array
		if seg_weapon_ovr.size() > 0:
			seg_enemy.weapon_overrides = seg_weapon_ovr

		# Link segment to core
		seg_enemy.boss_core = core_enemy
		seg_enemy.boss_segment_offset = seg_offset
		core_enemy.boss_segments.append(seg_enemy)

		seg_enemy.set_meta("boss_part", true)
		seg_enemy.tree_exiting.connect(_on_enemy_exited, CONNECT_ONE_SHOT)
		_enemies_container.add_child(seg_enemy)

	# Set immunity on core if configured
	if boss.core_immune_until_segments_dead and core_enemy.boss_segments.size() > 0:
		core_enemy.is_boss_immune = true

	# Store boss data reference for enrage trigger
	core_enemy._boss_data_ref = boss


func _make_boss_part(ship_id: String, pos: Vector2, weapons_active: bool) -> Enemy:
	var ship: ShipData = ShipDataManager.load_by_id(ship_id)
	if not ship:
		return null

	var enemy := Enemy.new()
	enemy.health = int(ship.stats.get("hull_hp", 30))
	enemy.shield = int(ship.stats.get("shield_hp", 0))
	enemy.enemy_color = ENEMY_COLORS[ship_id.hash() % ENEMY_COLORS.size()]
	enemy.visual_id = ship.visual_id if ship.visual_id != "" else "sentinel"
	enemy.render_mode_str = ship.render_mode if ship.render_mode != "" else "neon"
	enemy.grid_size = ship.grid_size
	enemy.ship_id = ship_id
	enemy.weapons_active = weapons_active
	enemy.shared_renderer = shared_renderer
	enemy.position = pos

	# Always set refs for boss parts — weapon may come from overrides, not ship.weapon_id
	enemy.ship_data_ref = ship
	enemy.player_ref = _player_ref
	enemy.projectiles_container = _projectiles_container

	return enemy


func start() -> void:
	_current_wave = 0
	_start_wave(0)


func stop() -> void:
	if _spawn_timer:
		_spawn_timer.stop()
	if _delay_timer:
		_delay_timer.stop()


func _start_wave(index: int) -> void:
	if index >= _waves.size():
		all_waves_cleared.emit()
		return

	_current_wave = index
	var wave: Dictionary = _waves[index]
	_enemies_to_spawn = int(wave.get("count", 5))
	_enemies_spawned = 0
	_enemies_alive = 0

	wave_started.emit(index, _waves.size())

	var interval: float = float(wave.get("spawn_interval", 1.0))

	if _spawn_timer:
		_spawn_timer.queue_free()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = interval
	_spawn_timer.timeout.connect(_on_spawn)
	add_child(_spawn_timer)
	_spawn_timer.start()


func _on_spawn() -> void:
	if not _enemies_container:
		return

	var wave: Dictionary = _waves[_current_wave]
	var health_val: int = int(wave.get("health", 30))
	var speed_min: float = float(wave.get("speed_min", 80.0))
	var speed_max: float = float(wave.get("speed_max", 150.0))

	var enemy := Enemy.new()
	enemy.shared_renderer = shared_renderer
	enemy.position = Vector2(randf_range(100.0, 1820.0), -30.0)
	enemy.drift_speed = randf_range(speed_min, speed_max)
	enemy.health = health_val
	enemy.enemy_color = ENEMY_COLORS[randi() % ENEMY_COLORS.size()]
	enemy.tree_exiting.connect(_on_enemy_exited, CONNECT_ONE_SHOT)
	_enemies_container.add_child(enemy)

	_enemies_spawned += 1
	_enemies_alive += 1

	if _enemies_spawned >= _enemies_to_spawn:
		_spawn_timer.stop()


func _on_enemy_exited() -> void:
	if _level_mode:
		return  # Level mode doesn't track wave completion via enemy counts
	_enemies_alive -= 1
	if _enemies_alive <= 0 and _enemies_spawned >= _enemies_to_spawn:
		_on_wave_complete()


func _on_wave_complete() -> void:
	wave_cleared.emit(_current_wave, _waves.size())

	var wave: Dictionary = _waves[_current_wave]
	var delay: float = float(wave.get("delay_after", 2.0))

	var next_index: int = _current_wave + 1
	if next_index >= _waves.size():
		# Small delay before signaling all cleared
		if _delay_timer:
			_delay_timer.queue_free()
		_delay_timer = Timer.new()
		_delay_timer.one_shot = true
		_delay_timer.wait_time = delay
		_delay_timer.timeout.connect(func() -> void:
			all_waves_cleared.emit()
		)
		add_child(_delay_timer)
		_delay_timer.start()
		return

	if _delay_timer:
		_delay_timer.queue_free()
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.wait_time = delay
	_delay_timer.timeout.connect(_start_wave.bind(next_index))
	add_child(_delay_timer)
	_delay_timer.start()
