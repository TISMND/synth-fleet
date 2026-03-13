extends Node2D
## Per-hardpoint sequencer. Steps through the piano roll pattern at 1/32-note intervals,
## fires projectiles and plays audio on trigger steps.
## Supports multiple stages (patterns) that can be switched at runtime.

var weapon_data: WeaponData = null
var pattern: Array = []
var loop_length: int = 32
var direction_deg: float = 0.0
var _step: int = 0
var _timer: Timer = null
var _projectiles_container: Node2D = null
var _all_stages: Array = []
var _current_stage: int = -1  # -1 = OFF
var _max_stage: int = -1


func setup(weapon: WeaponData, stages: Array, dir_deg: float, proj_container: Node2D) -> void:
	weapon_data = weapon
	direction_deg = dir_deg
	_projectiles_container = proj_container
	_all_stages = stages.duplicate(true)
	_max_stage = mini(_all_stages.size() - 1, 2)
	# Start OFF — no pattern loaded, no timer


func set_stage(stage_index: int) -> int:
	if stage_index < 0 or stage_index > _max_stage:
		# Go to OFF state
		_current_stage = -1
		pattern = []
		stop_sequencer()
		return -1
	var was_off: bool = _current_stage < 0
	_current_stage = stage_index
	var stage: Dictionary = _all_stages[stage_index]
	pattern = stage.get("pattern", []).duplicate()
	loop_length = int(stage.get("loop_length", 32))
	if pattern.is_empty():
		pattern.resize(loop_length)
		pattern.fill(-1)
	if loop_length <= 0:
		loop_length = pattern.size()
	if was_off:
		# Coming from OFF — start fresh
		_step = 0
		_restart_timer()
	else:
		# Already playing — just swap pattern, keep step and timer in sync
		if _step >= loop_length:
			_step = _step % loop_length
	return _current_stage


func get_stage() -> int:
	return _current_stage


func get_max_stage() -> int:
	return _max_stage


func cycle_stage() -> int:
	if _max_stage < 0:
		return -1
	# -1 → 0 → 1 → 2 → -1, skipping stages beyond _max_stage
	var next: int = _current_stage + 1
	if next > _max_stage:
		next = -1
	return set_stage(next)


func raise_stage() -> int:
	if _current_stage < _max_stage:
		return set_stage(_current_stage + 1)
	return _current_stage


func lower_stage() -> int:
	if _current_stage > -1:
		return set_stage(_current_stage - 1)
	return _current_stage


func _restart_timer() -> void:
	if _timer:
		_timer.stop()
		_timer.queue_free()
		_timer = null
	if pattern.is_empty() or not weapon_data:
		return
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = BeatClock.get_beat_duration() / 8.0
	_timer.timeout.connect(_on_step)
	add_child(_timer)
	_timer.start()
	_on_step()


func start_sequencer() -> void:
	if pattern.is_empty() or not weapon_data:
		return
	_step = 0
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = BeatClock.get_beat_duration() / 8.0
	_timer.timeout.connect(_on_step)
	add_child(_timer)
	_timer.start()
	# Fire first step immediately
	_on_step()


func stop_sequencer() -> void:
	if _timer:
		_timer.stop()


func _on_step() -> void:
	if _step < pattern.size():
		var note: int = int(pattern[_step])
		if note >= 0:
			_fire(note)
	_step = (_step + 1) % loop_length


func _fire(note: int) -> void:
	if not weapon_data or not _projectiles_container:
		return
	# Audio
	if weapon_data.audio_sample_path != "":
		var pitch: float = PianoRoll.get_pitch_scale(note) * weapon_data.audio_pitch
		AudioManager.play_weapon_sound(weapon_data.audio_sample_path, pitch)
	# Direction
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
