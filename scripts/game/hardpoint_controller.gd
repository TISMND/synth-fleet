class_name HardpointController
extends Node2D
## Per-hardpoint controller. Fires projectiles at normalized time positions (0.0–1.0)
## synced to LoopMixer playback. Audio is handled by LoopMixer (mute/unmute).
## Supports aim modes: fixed, sweep (oscillating), track (nearest enemy).
## Supports mirror modes: none, mirror (symmetric), alternate (toggle sides).

signal bar_effect_fired(effects: Dictionary)

var weapon_data: WeaponData = null
var direction_deg: float = 0.0
var aim_mode: String = "fixed"
var sweep_arc_deg: float = 60.0
var sweep_duration: float = 1.0
var mirror_mode: String = "none"
var _projectiles_container: Node2D = null
var _active: bool = false
var _loop_id: String = ""
var _fire_triggers_sorted: Array = []  # Array of [trigger_value, original_index]
var _prev_loop_pos: float = -1.0
var _cached_style: ProjectileStyle = null
var _style_loaded: bool = false
var _cached_beam_style: BeamStyle = null
var _beam_style_loaded: bool = false
var _sweep_time: float = 0.0
var _alternate_flip: bool = false
var _enemies_group: String = "enemies"
var _external_loop: bool = false  # if true, skip loop add/remove
var is_enemy: bool = false  # if true, projectiles use enemy collision layers
var _beam_bar_remaining: float = 0.0  # tracks beam bar-effect duration for continuous emission
var _beam_bar_emit_cooldown: float = 0.0  # throttle emission interval


func setup(weapon: WeaponData, dir_deg: float, proj_container: Node2D, hp_index: int = 0) -> void:
	weapon_data = weapon
	direction_deg = dir_deg
	aim_mode = weapon.aim_mode
	sweep_arc_deg = weapon.sweep_arc_deg
	sweep_duration = weapon.sweep_duration
	mirror_mode = weapon.mirror_mode
	_projectiles_container = proj_container

	# Build unique loop ID for this hardpoint
	_loop_id = weapon.id + "_hp_" + str(hp_index)

	_rebuild_triggers()

	# Register loop with LoopMixer (muted by default).
	# Always call add_loop — it handles duplicates via ref-counting for shared loops.
	if weapon.loop_file_path != "":
		LoopMixer.add_loop(_loop_id, weapon.loop_file_path, "Weapons", 0.0, true)


## Setup from a raw Dictionary (e.g. from weapons_tab editor).
## Uses an externally-managed loop_id — does NOT register/remove loops.
func setup_from_dict(data: Dictionary, proj_container: Node2D, loop_id: String) -> void:
	var w: WeaponData = WeaponData.from_dict(data)
	_external_loop = true
	_loop_id = loop_id
	weapon_data = w
	direction_deg = w.direction_deg
	aim_mode = w.aim_mode
	sweep_arc_deg = w.sweep_arc_deg
	sweep_duration = w.sweep_duration
	mirror_mode = w.mirror_mode
	_projectiles_container = proj_container
	_rebuild_triggers()


## Hot-update weapon params without tearing down the loop.
func update_from_dict(data: Dictionary) -> void:
	var w: WeaponData = WeaponData.from_dict(data)
	weapon_data = w
	direction_deg = w.direction_deg
	aim_mode = w.aim_mode
	sweep_arc_deg = w.sweep_arc_deg
	sweep_duration = w.sweep_duration
	mirror_mode = w.mirror_mode
	_rebuild_triggers()
	_prev_loop_pos = -1.0
	_style_loaded = false
	_cached_style = null
	_beam_style_loaded = false
	_cached_beam_style = null


func _rebuild_triggers() -> void:
	_fire_triggers_sorted = []
	for i in weapon_data.fire_triggers.size():
		_fire_triggers_sorted.append([float(weapon_data.fire_triggers[i]), i])
	_fire_triggers_sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func activate() -> void:
	if _active:
		return
	_active = true
	_prev_loop_pos = -1.0
	var fade_ms: int = _get_fade_in_ms()
	LoopMixer.unmute(_loop_id, fade_ms)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	var fade_ms: int = _get_fade_out_ms()
	LoopMixer.mute(_loop_id, fade_ms)


func _get_fade_in_ms() -> int:
	if not weapon_data or weapon_data.transition_mode != "fade":
		return 0
	return weapon_data.fade_in_ms


func _get_fade_out_ms() -> int:
	if not weapon_data or weapon_data.transition_mode != "fade":
		return 0
	return weapon_data.fade_out_ms


func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()


func is_active() -> bool:
	return _active


func get_loop_id() -> String:
	return _loop_id


func cleanup() -> void:
	if not _external_loop:
		if is_enemy:
			LoopMixer.release_loop(_loop_id, 20000)
		else:
			LoopMixer.remove_loop(_loop_id)


func _process(delta: float) -> void:
	if not _active or not weapon_data or _fire_triggers_sorted.is_empty():
		return

	# Accumulate sweep time
	_sweep_time += delta

	var pos_sec: float = LoopMixer.get_playback_position(_loop_id)
	var duration: float = LoopMixer.get_stream_duration(_loop_id)
	if pos_sec < 0.0 or duration <= 0.0:
		return

	var curr: float = pos_sec / duration  # normalized 0.0–1.0

	# Skip first frame (no previous position to compare)
	if _prev_loop_pos < 0.0:
		_prev_loop_pos = curr
		return

	var prev: float = _prev_loop_pos
	_prev_loop_pos = curr

	# Check each trigger for crossing
	for trigger_pair in _fire_triggers_sorted:
		var t: float = float(trigger_pair[0])
		var trigger_idx: int = int(trigger_pair[1])
		if _trigger_crossed(prev, curr, t):
			_fire(trigger_idx)

	# Continuous beam bar effects — emit full bar effects periodically during beam
	if _beam_bar_remaining > 0.0 and weapon_data and not weapon_data.bar_effects.is_empty():
		_beam_bar_remaining -= delta
		_beam_bar_emit_cooldown -= delta
		if _beam_bar_emit_cooldown <= 0.0:
			_beam_bar_emit_cooldown = 0.25  # emit every 0.25s — fast enough for rolling glow
			bar_effect_fired.emit(weapon_data.bar_effects)


func _trigger_crossed(prev: float, curr: float, trigger: float) -> bool:
	if curr >= prev:
		# Normal case: no wrap-around
		return trigger > prev and trigger <= curr
	else:
		# Wrap-around: loop reset happened
		return trigger > prev or trigger <= curr


func _get_current_direction() -> float:
	match aim_mode:
		"sweep":
			var phase: float = fmod(_sweep_time, sweep_duration) / sweep_duration
			var sweep_offset: float = sin(phase * TAU) * sweep_arc_deg * 0.5
			return direction_deg + sweep_offset
		"track":
			var nearest: Node2D = _find_nearest_enemy()
			if nearest:
				var target_pos: Vector2 = _predict_position(nearest)
				var to_target: Vector2 = target_pos - global_position
				return rad_to_deg(Vector2.UP.angle_to(to_target))
			return direction_deg
		_:  # "fixed"
			return direction_deg


## Beam-specific direction: no lead prediction (beams hit instantly), same sweep.
## When tracking with no enemies, fires straight (0 degrees = up) instead of direction_deg.
## Fixed/sweep include parent rotation so beams follow the ship as it turns.
func _get_beam_direction() -> float:
	var ship_rot_deg: float = 0.0
	if aim_mode != "track":
		ship_rot_deg = rad_to_deg(global_rotation)
	match aim_mode:
		"sweep":
			var phase: float = fmod(_sweep_time, sweep_duration) / sweep_duration
			var sweep_offset: float = sin(phase * TAU) * sweep_arc_deg * 0.5
			return direction_deg + sweep_offset + ship_rot_deg
		"track":
			var nearest: Node2D = _find_nearest_enemy()
			if nearest:
				var to_target: Vector2 = nearest.global_position - global_position
				return rad_to_deg(Vector2.UP.angle_to(to_target))
			return 0.0  # No target — fire straight up
		_:
			return direction_deg + ship_rot_deg


func _predict_position(target: Node2D) -> Vector2:
	var dist: float = global_position.distance_to(target.global_position)
	var proj_speed: float = weapon_data.projectile_speed if weapon_data else 600.0
	var time_to_hit: float = dist / proj_speed
	# Estimate velocity from enemy's previous position
	if target.has_meta("_prev_pos"):
		var prev: Vector2 = target.get_meta("_prev_pos")
		var dt: float = target.get_meta("_prev_dt")
		if dt > 0.0:
			var vel: Vector2 = (target.global_position - prev) / dt
			return target.global_position + vel * time_to_hit
	return target.global_position


func _find_nearest_enemy() -> Node2D:
	var group: String = "player" if is_enemy else _enemies_group
	var targets: Array[Node] = get_tree().get_nodes_in_group(group)
	var best: Node2D = null
	var best_dist_sq: float = INF
	for node in targets:
		if node is Node2D:
			var target: Node2D = node as Node2D
			var dist_sq: float = global_position.distance_squared_to(target.global_position)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best = target
	return best


func _fire(trigger_idx: int = -1) -> void:
	if not weapon_data or not _projectiles_container:
		return

	# Beams use no-prediction direction; projectiles use prediction
	var current_dir: float = _get_beam_direction() if weapon_data.beam_style_id != "" else _get_current_direction()

	match mirror_mode:
		"mirror":
			# Fire at +dir and -dir (mirrored across up axis)
			_fire_pattern_at(current_dir, trigger_idx)
			if absf(current_dir) > 0.01:
				_fire_pattern_at(-current_dir, trigger_idx)
		"alternate":
			# Alternate between +dir and -dir each trigger
			if _alternate_flip:
				_fire_pattern_at(-current_dir, trigger_idx)
			else:
				_fire_pattern_at(current_dir, trigger_idx)
			_alternate_flip = not _alternate_flip
		_:  # "none"
			_fire_pattern_at(current_dir, trigger_idx)

	_spawn_muzzle_effect(global_position, trigger_idx)

	if weapon_data and not weapon_data.bar_effects.is_empty():
		if weapon_data.beam_style_id != "":
			# Beam: start continuous bar effect emission over beam duration
			_beam_bar_remaining = weapon_data.beam_duration
			_beam_bar_emit_cooldown = 0.0  # emit immediately on first frame
		else:
			# Projectile: one-shot bar effect
			bar_effect_fired.emit(weapon_data.bar_effects)


func _fire_pattern_at(dir_deg: float, trigger_idx: int) -> void:
	# Apply parent rotation for fixed/sweep so projectiles follow hull direction.
	# Track mode already returns global angles, so skip.
	var ship_rot: float = 0.0
	if aim_mode != "track":
		ship_rot = global_rotation
	var dir: Vector2 = Vector2.UP.rotated(ship_rot + deg_to_rad(dir_deg))
	var perp: Vector2 = dir.rotated(deg_to_rad(90.0))
	var base_pos: Vector2 = global_position
	var fp: String = weapon_data.fire_pattern
	if fp == "single":
		_spawn_projectile(base_pos, dir, 1.0, trigger_idx)
	elif fp == "dual":
		_spawn_projectile(base_pos + perp * 20.0, dir, 1.0, trigger_idx)
		_spawn_projectile(base_pos - perp * 20.0, dir, 1.0, trigger_idx)
	elif fp == "spread":
		_spawn_projectile(base_pos, dir, 1.0, trigger_idx)
		_spawn_projectile(base_pos, dir.rotated(deg_to_rad(15.0)), 1.0, trigger_idx)
		_spawn_projectile(base_pos, dir.rotated(deg_to_rad(-15.0)), 1.0, trigger_idx)
	elif fp == "burst":
		_spawn_projectile(base_pos, dir, 1.0, trigger_idx)
		_spawn_projectile(base_pos - dir * 12.0, dir, 1.0, trigger_idx)
		_spawn_projectile(base_pos - dir * 24.0, dir, 1.0, trigger_idx)
	elif fp == "scatter":
		for i in 4:
			var angle_off: float = randf_range(-25.0, 25.0)
			_spawn_projectile(base_pos, dir.rotated(deg_to_rad(angle_off)), 1.0, trigger_idx)
	elif fp == "wave":
		_spawn_projectile(base_pos, dir, 1.0, trigger_idx)
	else:
		_spawn_projectile(base_pos, dir, 1.0, trigger_idx)


func _get_style() -> ProjectileStyle:
	if not _style_loaded:
		_style_loaded = true
		if weapon_data.projectile_style_id != "":
			_cached_style = ProjectileStyleManager.load_by_id(weapon_data.projectile_style_id)
	return _cached_style


func _get_beam_style() -> BeamStyle:
	if not _beam_style_loaded:
		_beam_style_loaded = true
		if weapon_data.beam_style_id != "":
			_cached_beam_style = BeamStyleManager.load_by_id(weapon_data.beam_style_id)
	return _cached_beam_style


func _spawn_projectile(pos: Vector2, dir: Vector2, speed_mult: float = 1.0, trigger_idx: int = -1) -> void:
	# Beam dispatch via beam_style_id
	if weapon_data.beam_style_id != "":
		var bstyle: BeamStyle = _get_beam_style()
		_spawn_beam_v2(pos, dir, bstyle)
		return

	var style: ProjectileStyle = _get_style()

	# Standard bullet (with or without style)
	var proj := Projectile.new()
	proj.position = pos
	proj.direction = dir
	proj.speed = weapon_data.projectile_speed * speed_mult
	proj.damage = weapon_data.damage
	proj.effect_profile = weapon_data.effect_profile
	proj.trigger_index = trigger_idx
	proj.pierce_count = weapon_data.pierce_count
	proj.splash_enabled = weapon_data.splash_enabled
	proj.splash_radius = weapon_data.splash_radius
	proj.skips_shields = weapon_data.skips_shields
	if style:
		proj.projectile_style = style
		proj.weapon_color = style.color
	else:
		proj.weapon_color = Color.CYAN
	proj.is_enemy = is_enemy
	_projectiles_container.add_child(proj)


func _spawn_beam_v2(pos: Vector2, dir: Vector2, bstyle: BeamStyle) -> void:
	var beam := BeamProjectile.new()
	beam.position = pos
	beam.weapon_color = bstyle.color if bstyle else Color.CYAN
	beam.damage_per_tick = weapon_data.beam_dps
	beam.beam_duration = weapon_data.beam_duration
	beam.beam_transition_time = weapon_data.beam_transition_time
	beam.appearance_mode = bstyle.appearance_mode if bstyle else "flow_in"
	beam.beam_width = bstyle.beam_width if bstyle else 16.0
	beam.beam_style = bstyle
	beam.skips_shields = weapon_data.skips_shields
	beam.passthrough = weapon_data.beam_passthrough
	beam.track_node = self  # beam follows hardpoint position
	beam.is_enemy = is_enemy
	# Rotate beam to match firing direction (Vector2.UP = 0 rotation)
	beam.rotation = Vector2.UP.angle_to(dir)
	# Beam continuously follows current direction (tracks parent rotation for all aim modes)
	beam.set_direction_source(_get_beam_direction)
	# Calculate beam length — full screen or style-defined
	var beam_length: float = bstyle.max_length if bstyle else 400.0
	if bstyle and bstyle.full_screen_length:
		# Direction can change (sweep, track, or parent rotation) — use viewport diagonal
		var vp_size: Vector2 = Vector2(1920, 1080)
		if get_viewport():
			vp_size = Vector2(get_viewport().get_visible_rect().size)
		beam_length = vp_size.length() + 200.0
	beam.max_length = beam_length
	_projectiles_container.add_child(beam)


## Calculate beam length needed to exit the viewport from pos along dir, with generous padding.
func _calc_full_screen_length(pos: Vector2, dir: Vector2) -> float:
	# Viewport rect (1920x1080 per project.godot, but read dynamically)
	var vp_size: Vector2 = Vector2(1920, 1080)
	if get_viewport():
		vp_size = Vector2(get_viewport().get_visible_rect().size)
	# Ray-box intersection: find distance from pos along dir to exit the viewport
	# dir points in the beam's travel direction (typically upward-ish)
	# We test against all 4 edges and pick the nearest positive intersection
	var best_dist: float = 9999.0
	# Top edge (y = 0)
	if dir.y < -0.001:
		var t: float = -pos.y / dir.y
		if t > 0.0:
			best_dist = minf(best_dist, t)
	# Bottom edge (y = vp_size.y)
	if dir.y > 0.001:
		var t: float = (vp_size.y - pos.y) / dir.y
		if t > 0.0:
			best_dist = minf(best_dist, t)
	# Left edge (x = 0)
	if dir.x < -0.001:
		var t: float = -pos.x / dir.x
		if t > 0.0:
			best_dist = minf(best_dist, t)
	# Right edge (x = vp_size.x)
	if dir.x > 0.001:
		var t: float = (vp_size.x - pos.x) / dir.x
		if t > 0.0:
			best_dist = minf(best_dist, t)
	# Add generous padding so the beam never reveals its end
	return best_dist + 200.0


func _spawn_muzzle_effect(origin: Vector2, trigger_idx: int = -1) -> void:
	if not weapon_data:
		return
	var style: ProjectileStyle = _get_style()
	# Use weapon's effect_profile; fall back to projectile style or beam style effect_profile
	var profile: Dictionary = weapon_data.effect_profile
	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	if defaults.is_empty() and style and not style.effect_profile.is_empty():
		profile = style.effect_profile
	if defaults.is_empty() and weapon_data.beam_style_id != "":
		var bstyle: BeamStyle = _get_beam_style()
		if bstyle and not bstyle.effect_profile.is_empty():
			profile = bstyle.effect_profile
	if profile.is_empty() or (profile.get("defaults", {}) as Dictionary).is_empty():
		return
	var resolved: Dictionary = EffectLayerRenderer.resolve_layers(profile, trigger_idx)
	var muzzle_layers: Array = resolved.get("muzzle", []) as Array
	if muzzle_layers.is_empty():
		return
	var color: Color = Color.CYAN
	if style:
		color = style.color
	elif weapon_data.beam_style_id != "":
		var bstyle2: BeamStyle = _get_beam_style()
		if bstyle2:
			color = bstyle2.color

	# Spawn GPU particle muzzle emitters
	for layer in muzzle_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var mtype: String = str(layer_dict.get("type", "none"))
		if mtype == "none":
			continue
		# Use per-layer color if present, otherwise fallback
		var layer_color: Color = EffectLayerRenderer.get_layer_color(layer_dict, color)
		var emitter: GPUParticles2D = VFXFactory.create_muzzle_emitter(layer_dict, layer_color)
		emitter.position = origin
		# Rotate muzzle to match hull direction
		# Enemies base direction is PI (downward); add hull rotation on top
		if is_enemy:
			emitter.rotation = PI + global_rotation
		elif global_rotation != 0.0:
			emitter.rotation = global_rotation
		_projectiles_container.add_child(emitter)


