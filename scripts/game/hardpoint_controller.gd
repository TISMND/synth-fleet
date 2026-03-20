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
var _sweep_time: float = 0.0
var _alternate_flip: bool = false
var _enemies_group: String = "enemies"
var _external_loop: bool = false  # if true, skip loop add/remove


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

	# Register loop with LoopMixer (muted by default)
	if weapon.loop_file_path != "" and not LoopMixer.has_loop(_loop_id):
		LoopMixer.add_loop(_loop_id, weapon.loop_file_path, "Master", 0.0, true)


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
	var fade_ms: int = _get_audio_fade_ms()
	LoopMixer.unmute(_loop_id, fade_ms)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	var fade_ms: int = _get_audio_fade_ms()
	LoopMixer.mute(_loop_id, fade_ms)


func _get_audio_fade_ms() -> int:
	if not weapon_data:
		return 0
	if weapon_data.transition_mode == "fade":
		return weapon_data.transition_ms
	return 0


func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()


func is_active() -> bool:
	return _active


func cleanup() -> void:
	if not _external_loop:
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
	var enemies: Array[Node] = get_tree().get_nodes_in_group(_enemies_group)
	var best: Node2D = null
	var best_dist_sq: float = INF
	for node in enemies:
		if node is Node2D:
			var enemy: Node2D = node as Node2D
			var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best = enemy
	return best


func _fire(trigger_idx: int = -1) -> void:
	if not weapon_data or not _projectiles_container:
		return

	var current_dir: float = _get_current_direction()

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
		bar_effect_fired.emit(weapon_data.bar_effects)


func _fire_pattern_at(dir_deg: float, trigger_idx: int) -> void:
	var dir: Vector2 = Vector2.UP.rotated(deg_to_rad(dir_deg))
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
	elif fp == "beam":
		_spawn_projectile(base_pos, dir, 3.0, trigger_idx)
	else:
		_spawn_projectile(base_pos, dir, 1.0, trigger_idx)


func _get_style() -> ProjectileStyle:
	if not _style_loaded:
		_style_loaded = true
		if weapon_data.projectile_style_id != "":
			_cached_style = ProjectileStyleManager.load_by_id(weapon_data.projectile_style_id)
	return _cached_style


func _spawn_projectile(pos: Vector2, dir: Vector2, speed_mult: float = 1.0, trigger_idx: int = -1) -> void:
	var style: ProjectileStyle = _get_style()

	# Branch on archetype
	if style and style.archetype == "beam":
		_spawn_beam(pos, style)
		return
	elif style and style.archetype == "pulse_wave":
		_spawn_pulse_wave(pos, style)
		return

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
	if style:
		proj.projectile_style = style
		proj.weapon_color = style.color
	else:
		proj.weapon_color = Color.CYAN
	_projectiles_container.add_child(proj)


func _spawn_beam(pos: Vector2, style: ProjectileStyle) -> void:
	var beam := BeamProjectile.new()
	beam.position = pos
	beam.weapon_color = style.color
	beam.damage_per_tick = float(weapon_data.damage)
	beam.projectile_style = style
	var ap: Dictionary = style.archetype_params
	beam.beam_duration = float(ap.get("beam_duration", 0.3))
	beam.max_length = float(ap.get("max_length", 400.0))
	beam.beam_width = float(ap.get("width", 16.0))
	_projectiles_container.add_child(beam)


func _spawn_pulse_wave(pos: Vector2, style: ProjectileStyle) -> void:
	var pulse := PulseWaveProjectile.new()
	pulse.position = pos
	pulse.weapon_color = style.color
	pulse.damage = weapon_data.damage
	pulse.projectile_style = style
	var ap: Dictionary = style.archetype_params
	pulse.expansion_rate = float(ap.get("expansion_rate", 200.0))
	pulse.max_radius = float(ap.get("max_radius", 300.0))
	pulse.lifetime = float(ap.get("lifetime", 1.0))
	pulse.ring_width = float(ap.get("ring_width", 8.0))
	_projectiles_container.add_child(pulse)


func _spawn_muzzle_effect(origin: Vector2, trigger_idx: int = -1) -> void:
	if not weapon_data:
		return
	var style: ProjectileStyle = _get_style()
	# Use weapon's effect_profile; fall back to projectile style's effect_profile
	var profile: Dictionary = weapon_data.effect_profile
	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	if defaults.is_empty() and style and not style.effect_profile.is_empty():
		profile = style.effect_profile
	if profile.is_empty() or (profile.get("defaults", {}) as Dictionary).is_empty():
		return
	var resolved: Dictionary = EffectLayerRenderer.resolve_layers(profile, trigger_idx)
	var muzzle_layers: Array = resolved.get("muzzle", []) as Array
	if muzzle_layers.is_empty():
		return
	var color: Color = style.color if style else Color.CYAN

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
		_projectiles_container.add_child(emitter)


