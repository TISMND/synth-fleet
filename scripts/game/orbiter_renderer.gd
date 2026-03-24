class_name OrbiterRenderer
extends Node2D
## Renders orbiting objects around a center point. Each orbiter tracks its own
## spawn time so batches created by different triggers naturally separate in orbit.

var _style: OrbiterStyle = null
var _orbiters: Array[Dictionary] = []  # [{sprite, trail_sprites, phase, spawn_time, material, ...}]
var _shader_cache: Dictionary = {}
var _shared_texture: ImageTexture = null
var _lifetime: float = 0.0  # 0 = infinite, >0 = seconds before fade-out and removal
var _orbit_radius: float = 80.0  # overridden by device radius
var _pending_removal: Array[int] = []

# Per-orbiter fade durations (set from device data)
var _fade_in_duration: float = 0.0
var _fade_out_duration: float = 0.0


func setup(style: OrbiterStyle) -> void:
	_style = style
	_shared_texture = null


func set_lifetime(seconds: float) -> void:
	_lifetime = seconds


func set_orbit_radius(r: float) -> void:
	_orbit_radius = r


func set_fade_durations(fade_in: float, fade_out: float) -> void:
	_fade_in_duration = maxf(fade_in, 0.0)
	_fade_out_duration = maxf(fade_out, 0.0)


## Spawn a full batch of orbiter_count objects, evenly distributed, all starting
## at 12 o'clock (phase 0 = top). Because spawn_time is now, previous batches
## will be at different orbital positions.
func spawn_batch() -> void:
	if not _style:
		return
	var count: int = _style.orbiter_count
	var now: float = Time.get_ticks_msec() / 1000.0
	for i in range(count):
		_add_orbiter_internal(float(i) / float(count), now)


## Add a single orbiter with explicit phase and spawn_time.
## Used by preview tabs for static display.
func add_orbiter(phase_offset: float = 0.0, custom_spawn_time: float = -1.0) -> void:
	if not _style:
		return
	var spawn_time: float = custom_spawn_time if custom_spawn_time >= 0.0 else Time.get_ticks_msec() / 1000.0
	_add_orbiter_internal(phase_offset, spawn_time)


func remove_all() -> void:
	for orb in _orbiters:
		var s: Sprite2D = orb["sprite"]
		s.queue_free()
		var trails: Array = orb["trail_sprites"]
		for t in trails:
			var ts: Sprite2D = t
			ts.queue_free()
	_orbiters.clear()


func set_style(style: OrbiterStyle) -> void:
	_style = style
	_shared_texture = null
	var old_data: Array[Dictionary] = []
	for orb in _orbiters:
		old_data.append({"phase": float(orb["phase"]), "spawn_time": float(orb["spawn_time"])})
	remove_all()
	for d in old_data:
		_add_orbiter_internal(d["phase"], d["spawn_time"])


func get_orbiter_count() -> int:
	return _orbiters.size()


func pulse(orbiter_index: int = -1) -> void:
	if orbiter_index >= 0 and orbiter_index < _orbiters.size():
		var mat: ShaderMaterial = _orbiters[orbiter_index]["material"]
		mat.set_shader_parameter("pulse_intensity", 1.0)
	else:
		for orb in _orbiters:
			var mat: ShaderMaterial = orb["material"]
			mat.set_shader_parameter("pulse_intensity", 1.0)


func _process(delta: float) -> void:
	if not _style or _orbiters.is_empty():
		return

	var time: float = Time.get_ticks_msec() / 1000.0
	_pending_removal.clear()

	for idx in range(_orbiters.size()):
		var orb_val: Variant = _orbiters[idx]
		if not orb_val is Dictionary:
			_pending_removal.append(idx)
			continue
		var orb: Dictionary = orb_val as Dictionary
		var phase: float = float(orb["phase"])
		var spawn_time: float = float(orb["spawn_time"])
		var elapsed: float = time - spawn_time

		# Per-orbiter alpha: fade in, sustain, fade out
		var life_alpha: float = 1.0

		# Fade in
		if _fade_in_duration > 0.0 and elapsed < _fade_in_duration:
			life_alpha = elapsed / _fade_in_duration

		# Lifetime expiry and fade out
		if _lifetime > 0.0:
			if elapsed >= _lifetime:
				_pending_removal.append(idx)
				continue
			if _fade_out_duration > 0.0:
				var fade_out_start: float = _lifetime - _fade_out_duration
				if elapsed > fade_out_start:
					life_alpha = minf(life_alpha, 1.0 - (elapsed - fade_out_start) / _fade_out_duration)

		# Angle based on elapsed time since spawn
		# Phase 0 = 12 o'clock = -PI/2 (top of circle)
		var angle: float = -TAU * 0.25 + (elapsed * _style.orbit_speed * TAU * float(_style.orbit_direction)) + phase * TAU

		# Radial wobble
		var radius: float = _orbit_radius
		if _style.wobble_amount > 0.0:
			radius += sin(elapsed * _style.wobble_speed * TAU) * _style.wobble_amount

		var pos := Vector2(cos(angle), sin(angle)) * radius

		var sprite: Sprite2D = orb["sprite"]
		sprite.position = pos
		sprite.modulate.a = life_alpha

		# Self-rotation
		if _style.spin_speed != 0.0:
			sprite.rotation = elapsed * _style.spin_speed

		# Trail: record positions at intervals for visible spacing
		var trail_sprites: Array = orb["trail_sprites"]
		if trail_sprites.size() > 0:
			var tick: float = float(orb["trail_tick"]) + delta
			var interval: float = 0.04
			var prev_positions: Array = orb["prev_positions"]
			if tick >= interval:
				tick = 0.0
				prev_positions.insert(0, pos)
				while prev_positions.size() > trail_sprites.size():
					prev_positions.pop_back()
			orb["trail_tick"] = tick
			for i in range(trail_sprites.size()):
				var ts: Sprite2D = trail_sprites[i]
				if i < prev_positions.size():
					var tpos: Vector2 = prev_positions[i]
					ts.position = tpos
					ts.rotation = sprite.rotation
				else:
					ts.position = pos
				ts.modulate.a = pow(_style.trail_fade, float(i + 1)) * life_alpha

		# Decay pulse
		var mat: ShaderMaterial = orb.get("material") as ShaderMaterial
		if mat:
			var pulse_val: float = float(mat.get_shader_parameter("pulse_intensity"))
			if pulse_val > 0.0:
				pulse_val = maxf(0.0, pulse_val - delta * 3.0)
				mat.set_shader_parameter("pulse_intensity", pulse_val)

	# Remove expired orbiters (iterate in reverse to keep indices valid)
	for i in range(_pending_removal.size() - 1, -1, -1):
		var rm_idx: int = _pending_removal[i]
		_remove_orbiter_at(rm_idx)


func _remove_orbiter_at(idx: int) -> void:
	if idx < 0 or idx >= _orbiters.size():
		return
	var orb_val: Variant = _orbiters[idx]
	if not orb_val is Dictionary:
		_orbiters.remove_at(idx)
		return
	var orb: Dictionary = orb_val as Dictionary
	var s: Sprite2D = orb["sprite"]
	s.queue_free()
	var trails: Array = orb["trail_sprites"]
	for t in trails:
		var ts: Sprite2D = t
		ts.queue_free()
	_orbiters.remove_at(idx)


func _add_orbiter_internal(phase_offset: float, spawn_time: float) -> void:
	var mat: ShaderMaterial = _create_material()
	var tex: ImageTexture = _get_shared_texture()

	# Main sprite
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.material = mat
	add_child(sprite)

	# Trail afterimages
	var trail_sprites: Array[Sprite2D] = []
	for i in range(_style.trail_length):
		var trail := Sprite2D.new()
		trail.texture = tex
		trail.material = _create_material()
		trail.modulate.a = pow(_style.trail_fade, float(i + 1))
		trail.scale = Vector2.ONE * (1.0 - float(i + 1) * 0.05)
		add_child(trail)
		trail_sprites.append(trail)

	_orbiters.append({
		"sprite": sprite,
		"trail_sprites": trail_sprites,
		"phase": phase_offset,
		"spawn_time": spawn_time,
		"material": mat,
		"trail_tick": 0.0,
		"prev_positions": [] as Array[Vector2],
	})


func _get_shared_texture() -> ImageTexture:
	if _shared_texture:
		return _shared_texture
	var tex_size: int = maxi(int(ceilf(_style.size * 2.5)), 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_shared_texture = ImageTexture.create_from_image(img)
	return _shared_texture


func _create_material() -> ShaderMaterial:
	var shader: Shader = _get_orbiter_shader(_style.shader)
	if not shader:
		shader = _get_orbiter_shader("glow")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("orb_color", _style.color)
	mat.set_shader_parameter("brightness", _style.glow_intensity)
	mat.set_shader_parameter("shape_type", OrbiterStyle.shape_to_index(_style.shape))
	mat.set_shader_parameter("pulse_intensity", 0.0)
	mat.set_shader_parameter("animation_speed", 1.0)
	for param_name in _style.shader_params:
		mat.set_shader_parameter(param_name, float(_style.shader_params[param_name]))
	return mat


func _get_orbiter_shader(shader_name: String) -> Shader:
	if _shader_cache.has(shader_name):
		return _shader_cache[shader_name] as Shader
	var path: String = "res://assets/shaders/orbiter_" + shader_name + ".gdshader"
	var shader: Shader = load(path) as Shader
	if shader:
		_shader_cache[shader_name] = shader
	return shader
