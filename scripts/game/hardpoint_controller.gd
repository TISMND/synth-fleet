extends Node2D
## Per-hardpoint controller. Fires projectiles at normalized time positions (0.0–1.0)
## synced to LoopMixer playback. Audio is handled by LoopMixer (mute/unmute).

var weapon_data: WeaponData = null
var direction_deg: float = 0.0
var _projectiles_container: Node2D = null
var _active: bool = false
var _loop_id: String = ""
var _fire_triggers_sorted: Array = []  # Array of [trigger_value, original_index]
var _prev_loop_pos: float = -1.0
var _cached_style: ProjectileStyle = null
var _style_loaded: bool = false


func setup(weapon: WeaponData, dir_deg: float, proj_container: Node2D, hp_index: int = 0) -> void:
	weapon_data = weapon
	direction_deg = dir_deg
	_projectiles_container = proj_container

	# Build unique loop ID for this hardpoint
	_loop_id = weapon.id + "_hp_" + str(hp_index)

	# Sort fire triggers but keep original indices for per-trigger overrides
	_fire_triggers_sorted = []
	for i in weapon.fire_triggers.size():
		_fire_triggers_sorted.append([float(weapon.fire_triggers[i]), i])
	_fire_triggers_sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

	# Register loop with LoopMixer (muted by default)
	if weapon.loop_file_path != "" and not LoopMixer.has_loop(_loop_id):
		LoopMixer.add_loop(_loop_id, weapon.loop_file_path, "Master", 0.0, true)


func activate() -> void:
	if _active:
		return
	_active = true
	_prev_loop_pos = -1.0
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
	if not _active or not weapon_data or _fire_triggers_sorted.is_empty():
		return

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


func _fire(trigger_idx: int = -1) -> void:
	if not weapon_data or not _projectiles_container:
		return
	var dir: Vector2 = Vector2.UP.rotated(deg_to_rad(direction_deg))
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

	_spawn_muzzle_effect(base_pos, trigger_idx)


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
	proj.weapon_color = Color(weapon_data.color)
	proj.effect_profile = weapon_data.effect_profile
	proj.trigger_index = trigger_idx
	if style:
		proj.projectile_style = style
	_projectiles_container.add_child(proj)


func _spawn_beam(pos: Vector2, style: ProjectileStyle) -> void:
	var beam := BeamProjectile.new()
	beam.position = pos
	beam.weapon_color = Color(weapon_data.color)
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
	pulse.weapon_color = Color(weapon_data.color)
	pulse.damage = weapon_data.damage
	pulse.projectile_style = style
	var ap: Dictionary = style.archetype_params
	pulse.expansion_rate = float(ap.get("expansion_rate", 200.0))
	pulse.max_radius = float(ap.get("max_radius", 300.0))
	pulse.lifetime = float(ap.get("lifetime", 1.0))
	pulse.ring_width = float(ap.get("ring_width", 8.0))
	_projectiles_container.add_child(pulse)


func _spawn_muzzle_effect(origin: Vector2, trigger_idx: int = -1) -> void:
	if not weapon_data or weapon_data.effect_profile.is_empty():
		return
	var resolved: Dictionary = EffectLayerRenderer.resolve_layers(weapon_data.effect_profile, trigger_idx)
	var muzzle_layers: Array = resolved.get("muzzle", []) as Array
	if muzzle_layers.is_empty():
		return
	var color: Color = Color(weapon_data.color)

	# Spawn GPU particle muzzle emitters
	for layer in muzzle_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var mtype: String = str(layer_dict.get("type", "none"))
		if mtype == "none":
			continue
		var emitter: GPUParticles2D = VFXFactory.create_muzzle_emitter(layer_dict, color)
		emitter.position = origin
		_projectiles_container.add_child(emitter)
