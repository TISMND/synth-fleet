extends Node2D
## Per-hardpoint controller. Fires projectiles at beat positions defined by weapon's fire_triggers.
## Audio is handled by LoopMixer (mute/unmute), not per-shot playback.

var weapon_data: WeaponData = null
var direction_deg: float = 0.0
var _projectiles_container: Node2D = null
var _active: bool = false
var _loop_id: String = ""
var _loop_length_beats: float = 0.0
var _fire_triggers_sorted: Array = []
var _prev_loop_pos: float = -1.0


func setup(weapon: WeaponData, dir_deg: float, proj_container: Node2D, hp_index: int = 0) -> void:
	weapon_data = weapon
	direction_deg = dir_deg
	_projectiles_container = proj_container

	# Build unique loop ID for this hardpoint
	_loop_id = weapon.id + "_hp_" + str(hp_index)

	# Calculate loop length in beats
	_loop_length_beats = float(weapon.loop_length_bars) * float(BeatClock.beats_per_measure)

	# Sort fire triggers
	_fire_triggers_sorted = weapon.fire_triggers.duplicate()
	_fire_triggers_sorted.sort()

	# Register loop with LoopMixer (muted by default)
	if weapon.loop_file_path != "" and not LoopMixer.has_loop(_loop_id):
		LoopMixer.add_loop(_loop_id, weapon.loop_file_path, "Master", 0.0, true)


func activate() -> void:
	if _active:
		return
	_active = true
	_prev_loop_pos = BeatClock.get_loop_beat_position(_loop_length_beats) if _loop_length_beats > 0.0 else 0.0
	LoopMixer.unmute(_loop_id)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	LoopMixer.mute(_loop_id)


func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()


func is_active() -> bool:
	return _active


func cleanup() -> void:
	LoopMixer.remove_loop(_loop_id)


func _process(_delta: float) -> void:
	if not _active or not weapon_data or _loop_length_beats <= 0.0 or _fire_triggers_sorted.is_empty():
		return

	var curr: float = BeatClock.get_loop_beat_position(_loop_length_beats)

	# Skip first frame (no previous position to compare)
	if _prev_loop_pos < 0.0:
		_prev_loop_pos = curr
		return

	var prev: float = _prev_loop_pos
	_prev_loop_pos = curr

	# Check each trigger for crossing
	for trigger in _fire_triggers_sorted:
		var t: float = float(trigger)
		if _trigger_crossed(prev, curr, t):
			_fire()


func _trigger_crossed(prev: float, curr: float, trigger: float) -> bool:
	if curr >= prev:
		# Normal case: no wrap-around
		return trigger > prev and trigger <= curr
	else:
		# Wrap-around: loop reset happened
		return trigger > prev or trigger <= curr


func _fire() -> void:
	if not weapon_data or not _projectiles_container:
		return
	var dir: Vector2 = Vector2.UP.rotated(deg_to_rad(direction_deg))
	var perp: Vector2 = dir.rotated(deg_to_rad(90.0))
	var base_pos: Vector2 = global_position
	var fp: String = weapon_data.fire_pattern
	if fp == "single":
		_spawn_projectile(base_pos, dir)
	elif fp == "dual":
		_spawn_projectile(base_pos + perp * 20.0, dir)
		_spawn_projectile(base_pos - perp * 20.0, dir)
	elif fp == "spread":
		_spawn_projectile(base_pos, dir)
		_spawn_projectile(base_pos, dir.rotated(deg_to_rad(15.0)))
		_spawn_projectile(base_pos, dir.rotated(deg_to_rad(-15.0)))
	elif fp == "burst":
		_spawn_projectile(base_pos, dir)
		_spawn_projectile(base_pos - dir * 12.0, dir)
		_spawn_projectile(base_pos - dir * 24.0, dir)
	elif fp == "scatter":
		for i in 4:
			var angle_off: float = randf_range(-25.0, 25.0)
			_spawn_projectile(base_pos, dir.rotated(deg_to_rad(angle_off)))
	elif fp == "wave":
		_spawn_projectile(base_pos, dir)
	elif fp == "beam":
		_spawn_projectile(base_pos, dir, 3.0)
	else:
		_spawn_projectile(base_pos, dir)

	_spawn_muzzle_effect(base_pos)


func _spawn_projectile(pos: Vector2, dir: Vector2, speed_mult: float = 1.0) -> void:
	var proj := Projectile.new()
	proj.position = pos
	proj.direction = dir
	proj.speed = weapon_data.projectile_speed * speed_mult
	proj.damage = weapon_data.damage
	proj.weapon_color = Color(weapon_data.color)
	proj.effect_profile = weapon_data.effect_profile
	_projectiles_container.add_child(proj)


func _spawn_muzzle_effect(origin: Vector2) -> void:
	if not weapon_data or weapon_data.effect_profile.is_empty():
		return
	var muzzle: Dictionary = weapon_data.effect_profile.get("muzzle", {}) as Dictionary
	var mtype: String = str(muzzle.get("type", "none"))
	if mtype == "none":
		return
	var params: Dictionary = muzzle.get("params", {}) as Dictionary
	var count: int = int(params.get("particle_count", 6))
	var lifetime: float = float(params.get("lifetime", 0.3))
	var spread: float = float(params.get("spread_angle", 360.0))
	var color: Color = Color(weapon_data.color)

	var particles: Array = []
	for i in count:
		var angle: float = 0.0
		var spd: float = randf_range(80, 200)
		match mtype:
			"radial_burst":
				angle = randf_range(0, TAU)
			"directional_flash":
				angle = -PI / 2.0 + randf_range(-deg_to_rad(spread / 2.0), deg_to_rad(spread / 2.0))
			"ring_pulse":
				angle = TAU * float(i) / float(count)
				spd = 120.0
			"spiral_burst":
				angle = TAU * float(i) / float(count) + float(i) * 0.3
				spd = 100.0 + float(i) * 10.0
			_:
				angle = randf_range(0, TAU)

		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"age": 0.0,
			"lifetime": lifetime,
			"size": randf_range(2.0, 4.0),
			"color": color,
		})

	var fx: EffectParticles = EffectParticles.new()
	fx.position = origin
	fx.setup(particles, color)
	_projectiles_container.add_child(fx)
