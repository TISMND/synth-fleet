extends Node2D
## Per-hardpoint sequencer. Steps through the piano roll pattern at 1/32-note intervals,
## fires projectiles and plays audio on trigger steps.

var weapon_data: WeaponData = null
var pattern: Array = []
var loop_length: int = 32
var direction_deg: float = 0.0
var _step: int = 0
var _timer: Timer = null
var _projectiles_container: Node2D = null


func setup(weapon: WeaponData, stages: Array, dir_deg: float, proj_container: Node2D) -> void:
	weapon_data = weapon
	direction_deg = dir_deg
	_projectiles_container = proj_container
	if stages.size() > 0:
		var stage: Dictionary = stages[0]
		pattern = stage.get("pattern", [])
		loop_length = int(stage.get("loop_length", 32))
	if pattern.is_empty():
		pattern.resize(loop_length)
		pattern.fill(-1)
	if loop_length <= 0:
		loop_length = pattern.size()


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
		_spawn_projectile(base_pos, dir, false)
	elif fp == "dual":
		_spawn_projectile(base_pos + perp * 20.0, dir, false)
		_spawn_projectile(base_pos - perp * 20.0, dir, false)
	elif fp == "spread":
		_spawn_projectile(base_pos, dir, false)
		_spawn_projectile(base_pos, dir.rotated(deg_to_rad(15.0)), false)
		_spawn_projectile(base_pos, dir.rotated(deg_to_rad(-15.0)), false)
	elif fp == "burst":
		_spawn_projectile(base_pos, dir, false)
		_spawn_projectile(base_pos - dir * 12.0, dir, false)
		_spawn_projectile(base_pos - dir * 24.0, dir, false)
	elif fp == "scatter":
		for i in 4:
			var angle_off: float = randf_range(-25.0, 25.0)
			_spawn_projectile(base_pos, dir.rotated(deg_to_rad(angle_off)), false)
	elif fp == "wave":
		_spawn_projectile(base_pos, dir, true)
	elif fp == "beam":
		_spawn_projectile(base_pos, dir, false, 3.0)
	else:
		_spawn_projectile(base_pos, dir, false)


func _spawn_projectile(pos: Vector2, dir: Vector2, wave: bool, speed_mult: float = 1.0) -> void:
	var proj := Projectile.new()
	proj.position = pos
	proj.direction = dir
	proj.speed = weapon_data.projectile_speed * speed_mult
	proj.damage = weapon_data.damage
	proj.weapon_color = Color(weapon_data.color)
	proj.is_wave = wave
	_projectiles_container.add_child(proj)
