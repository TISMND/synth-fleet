class_name WeaponPreview
extends Node2D
## Live weapon preview — renders projectiles with full effect stack inside a SubViewport.
## Synced to LoopMixer playback. Uses EffectLayerRenderer for composable layers.
## Uses HDR colors for bloom and GPU particles for muzzle/impact.

var weapon_color: Color = Color.CYAN
var projectile_speed: float = 600.0
var fire_pattern: String = "single"
var effect_profile: Dictionary = {}
var direction_deg: float = 0.0
var loop_file_path: String = ""
var loop_length_bars: int = 2
var fire_triggers: Array = []
var projectile_style_id: String = ""
var _cached_style: ProjectileStyle = null

var _projectiles: Array = []
var _particles: Array = []
var _preview_active: bool = false
var _viewport_size: Vector2 = Vector2(400, 500)
var _fire_point: Vector2 = Vector2(200, 460)
var _impact_y: float = 40.0
var _next_id: int = 0
var _prev_loop_pos: float = -1.0
var _fire_triggers_sorted: Array = []  # Array of [trigger_value, original_index]
var _loop_id: String = ""
var _resolved_defaults: Dictionary = {}  # Pre-resolved default layers
var _shader_sprites: Dictionary = {}  # proj_id -> Sprite2D


func _ready() -> void:
	_fire_point = Vector2(_viewport_size.x / 2.0, _viewport_size.y - 40.0)
	_impact_y = 40.0


func start() -> void:
	_preview_active = true
	_prev_loop_pos = -1.0


func stop() -> void:
	_preview_active = false
	_projectiles.clear()
	_particles.clear()
	for sprite in _shader_sprites.values():
		if is_instance_valid(sprite):
			sprite.queue_free()
	_shader_sprites.clear()
	queue_redraw()


func set_loop_id(id: String) -> void:
	_loop_id = id


func update_weapon(data: Dictionary) -> void:
	projectile_speed = float(data.get("projectile_speed", 600.0))
	fire_pattern = str(data.get("fire_pattern", "single"))
	effect_profile = data.get("effect_profile", {})
	direction_deg = float(data.get("direction_deg", 0.0))
	loop_file_path = str(data.get("loop_file_path", ""))
	loop_length_bars = int(data.get("loop_length_bars", 2))
	fire_triggers = data.get("fire_triggers", [])
	var new_style_id: String = str(data.get("projectile_style_id", ""))
	if new_style_id != projectile_style_id:
		projectile_style_id = new_style_id
		if projectile_style_id != "":
			_cached_style = ProjectileStyleManager.load_by_id(projectile_style_id)
		else:
			_cached_style = null
	# Color from style, fallback to cyan
	if _cached_style:
		weapon_color = _cached_style.color
	else:
		weapon_color = Color.CYAN
	# Sort triggers preserving original indices
	_fire_triggers_sorted = []
	for i in fire_triggers.size():
		_fire_triggers_sorted.append([float(fire_triggers[i]), i])
	_fire_triggers_sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_prev_loop_pos = -1.0
	# Pre-resolve default layers
	_resolved_defaults = EffectLayerRenderer.resolve_layers(effect_profile, -1)


func _fire_projectiles(trigger_idx: int = -1) -> void:
	var spawn_points: Array = []
	var directions: Array = []
	var base_dir: Vector2 = Vector2.UP.rotated(deg_to_rad(direction_deg))

	match fire_pattern:
		"single":
			spawn_points.append(_fire_point)
			directions.append(base_dir)
		"dual":
			spawn_points.append(_fire_point + Vector2(-15, 0))
			spawn_points.append(_fire_point + Vector2(15, 0))
			directions.append(base_dir)
			directions.append(base_dir)
		"burst":
			for i in 3:
				spawn_points.append(_fire_point)
				directions.append(base_dir)
		"spread":
			for angle_off in [-20.0, -10.0, 0.0, 10.0, 20.0]:
				spawn_points.append(_fire_point)
				directions.append(base_dir.rotated(deg_to_rad(angle_off)))
		"wave":
			spawn_points.append(_fire_point + Vector2(-20, 0))
			spawn_points.append(_fire_point)
			spawn_points.append(_fire_point + Vector2(20, 0))
			directions.append(base_dir)
			directions.append(base_dir)
			directions.append(base_dir)
		"scatter":
			for i in 4:
				spawn_points.append(_fire_point + Vector2(randf_range(-10, 10), 0))
				var scatter_angle: float = randf_range(-15, 15)
				directions.append(base_dir.rotated(deg_to_rad(scatter_angle)))
		"beam":
			spawn_points.append(_fire_point)
			directions.append(base_dir)
		_:
			spawn_points.append(_fire_point)
			directions.append(base_dir)

	# Resolve layers for this trigger
	var resolved: Dictionary = EffectLayerRenderer.resolve_layers(effect_profile, trigger_idx)

	# Check if using ProjectileStyle or shader shapes
	var shape_layers: Array = resolved.get("shape", []) as Array
	var uses_style: bool = _cached_style != null
	var uses_shader: bool = not uses_style and EffectLayerRenderer.has_shader_shape(shape_layers)

	for i in spawn_points.size():
		var proj: Dictionary = {
			"id": _next_id,
			"pos": spawn_points[i] as Vector2,
			"base_x": (spawn_points[i] as Vector2).x,
			"vel": (directions[i] as Vector2) * projectile_speed,
			"age": 0.0,
			"trail_points": [],
			"trail_particles": [],
			"beat_fx_particles": [],
			"resolved_layers": resolved,
			"trigger_index": trigger_idx,
		}
		_projectiles.append(proj)

		# Create styled sprite or shader sprite
		if uses_style:
			var sprite: Sprite2D = VFXFactory.create_styled_sprite(_cached_style, weapon_color)
			if sprite:
				sprite.position = proj["pos"] as Vector2
				add_child(sprite)
				_shader_sprites[_next_id] = sprite
		elif uses_shader:
			for layer in shape_layers:
				var layer_dict: Dictionary = layer as Dictionary
				var stype: String = str(layer_dict.get("type", "rect"))
				if stype in EffectLayerRenderer.SHADER_SHAPES:
					var params: Dictionary = layer_dict.get("params", {}) as Dictionary
					var w: float = float(params.get("width", 24.0))
					var h: float = float(params.get("height", 32.0))
					var sprite: Sprite2D = VFXFactory.create_shader_sprite(stype, weapon_color, w, h)
					if sprite:
						sprite.position = proj["pos"] as Vector2
						add_child(sprite)
						_shader_sprites[_next_id] = sprite
					break

		_next_id += 1

	# Spawn GPU muzzle emitters
	var muzzle_layers: Array = resolved.get("muzzle", []) as Array
	for layer in muzzle_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var mtype: String = str(layer_dict.get("type", "none"))
		if mtype == "none":
			continue
		var muzzle_color: Color = _get_layer_color(layer_dict, weapon_color)
		var emitter: GPUParticles2D = VFXFactory.create_muzzle_emitter(layer_dict, muzzle_color)
		emitter.position = _fire_point
		add_child(emitter)


func _spawn_impact(origin: Vector2, resolved: Dictionary) -> void:
	var impact_layers: Array = resolved.get("impact", []) as Array
	for layer in impact_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var itype: String = str(layer_dict.get("type", "none"))
		if itype == "none":
			continue
		var impact_color: Color = _get_layer_color(layer_dict, weapon_color)
		var emitter: GPUParticles2D = VFXFactory.create_impact_emitter(layer_dict, impact_color)
		emitter.position = origin
		add_child(emitter)


func _process(delta: float) -> void:
	if not _preview_active:
		return

	# Fire at normalized time positions, synced to LoopMixer playback
	if not _fire_triggers_sorted.is_empty() and _loop_id != "":
		var pos_sec: float = LoopMixer.get_playback_position(_loop_id)
		var duration: float = LoopMixer.get_stream_duration(_loop_id)
		if pos_sec >= 0.0 and duration > 0.0:
			var curr: float = pos_sec / duration
			if _prev_loop_pos < 0.0:
				_prev_loop_pos = curr
			else:
				var prev: float = _prev_loop_pos
				_prev_loop_pos = curr
				for trigger_pair in _fire_triggers_sorted:
					var t: float = float(trigger_pair[0])
					var trigger_idx: int = int(trigger_pair[1])
					if curr >= prev:
						if t > prev and t <= curr:
							_fire_projectiles(trigger_idx)
					else:
						if t > prev or t <= curr:
							_fire_projectiles(trigger_idx)

	# Update projectiles
	var to_remove: Array = []
	for proj in _projectiles:
		proj["age"] = float(proj["age"]) + delta
		var age: float = float(proj["age"])
		var resolved: Dictionary = proj["resolved_layers"] as Dictionary

		# Apply motion (summed from all motion layers)
		var motion_layers: Array = resolved.get("motion", []) as Array
		var x_offset: float = EffectLayerRenderer.compute_motion_offset(motion_layers, age)

		var vel: Vector2 = proj["vel"]
		var current_pos: Vector2 = proj["pos"]
		proj["pos"] = Vector2(float(proj["base_x"]) + x_offset + vel.x * age, current_pos.y + vel.y * delta)

		# Update shader sprite position
		var proj_id: int = int(proj["id"])
		if _shader_sprites.has(proj_id):
			var sprite: Sprite2D = _shader_sprites[proj_id]
			if is_instance_valid(sprite):
				sprite.position = proj["pos"] as Vector2

		# Store trail point for ribbon trails
		var trail_pts: Array = proj["trail_points"]
		var trail_pos: Vector2 = proj["pos"]
		trail_pts.append(trail_pos)
		if trail_pts.size() > 20:
			trail_pts.pop_front()

		# Beat FX evaluation
		var beat_fx_layers: Array = resolved.get("beat_fx", []) as Array
		if not beat_fx_layers.is_empty():
			var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(beat_fx_layers, weapon_color, age, delta)
			var sparkles: Array = fx_result.get("sparkle_particles", []) as Array
			var beat_fx_particles: Array = proj["beat_fx_particles"]
			for sparkle in sparkles:
				var s: Dictionary = sparkle as Dictionary
				s["pos"] = (s["pos"] as Vector2) + (proj["pos"] as Vector2)
				beat_fx_particles.append(s)

		# Age beat_fx particles
		_age_particle_list(proj["beat_fx_particles"] as Array, delta)

		# Check if off screen (any edge)
		var pos: Vector2 = proj["pos"]
		if pos.y < _impact_y or pos.y > _viewport_size.y + 10.0 or pos.x < -10.0 or pos.x > _viewport_size.x + 10.0:
			_spawn_impact(pos, resolved)
			to_remove.append(proj)

	for proj in to_remove:
		var proj_id: int = int(proj["id"])
		if _shader_sprites.has(proj_id):
			var sprite: Sprite2D = _shader_sprites[proj_id]
			if is_instance_valid(sprite):
				sprite.queue_free()
			_shader_sprites.erase(proj_id)
		_projectiles.erase(proj)

	# Update loose particles (legacy, for beat_fx sparkles)
	_age_particle_list(_particles, delta)

	queue_redraw()


func _age_particle_list(particles: Array, delta: float) -> void:
	var dead: Array = []
	for p in particles:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if float(p["age"]) >= float(p["lifetime"]):
			dead.append(p)
	for p in dead:
		particles.erase(p)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, _viewport_size), Color(0.02, 0.02, 0.05, 1.0))

	# Subtle grid
	var grid_color: Color = Color(0.1, 0.1, 0.15, 0.3)
	for x in range(0, int(_viewport_size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, _viewport_size.y), grid_color, 1.0)
	for y in range(0, int(_viewport_size.y), 40):
		draw_line(Vector2(0, y), Vector2(_viewport_size.x, y), grid_color, 1.0)

	# Fire point indicator
	draw_circle(_fire_point, 3.0, Color(weapon_color, 0.4))

	# Draw projectiles
	for proj in _projectiles:
		_draw_projectile(proj)

	# Draw loose particles (beat_fx sparkles)
	for p in _particles:
		_draw_particle_hdr(p)


func _draw_projectile(proj: Dictionary) -> void:
	var pos: Vector2 = proj["pos"]
	var age: float = float(proj["age"])
	var resolved: Dictionary = proj["resolved_layers"] as Dictionary

	# Draw beat fx particles
	var beat_fx_particles: Array = proj["beat_fx_particles"]
	for p in beat_fx_particles:
		_draw_particle_hdr(p)

	# Draw ribbon trails
	var trail_layers: Array = resolved.get("trail", []) as Array
	var trail_pts: Array = proj["trail_points"]
	if trail_pts.size() >= 2:
		# For preview, trail points are in local space already — pass zero offset
		EffectLayerRenderer.draw_ribbon_trails(self, trail_layers, trail_pts, weapon_color, Vector2.ZERO)

	# Beat FX scale
	var beat_fx_layers: Array = resolved.get("beat_fx", []) as Array
	var scale_mult: float = 1.0
	if not beat_fx_layers.is_empty():
		var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(beat_fx_layers, weapon_color, age, 0.0)
		scale_mult = float(fx_result.get("scale_mult", 1.0))

	# Draw shape stack
	if scale_mult != 1.0:
		draw_set_transform(pos, 0.0, Vector2(scale_mult, scale_mult))
		EffectLayerRenderer.draw_shape_stack(
			self, Vector2.ZERO,
			resolved.get("shape", []) as Array,
			weapon_color, age
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		EffectLayerRenderer.draw_shape_stack(
			self, pos,
			resolved.get("shape", []) as Array,
			weapon_color, age
		)


func _draw_particle_hdr(p: Dictionary) -> void:
	var age: float = float(p["age"])
	var lifetime: float = float(p["lifetime"])
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	var alpha: float = (1.0 - t) * 0.8
	var sz: float = float(p["size"]) * (1.0 - t * 0.5)
	var pos: Vector2 = p["pos"]
	var col: Color = p["color"]
	# HDR glow
	draw_circle(pos, sz * 2.0, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, alpha * 0.3))
	draw_circle(pos, sz, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, alpha))
	draw_circle(pos, sz * 0.4, Color(2.0, 2.0, 2.0, alpha * 0.6))


func _get_layer_color(layer_dict: Dictionary, fallback: Color) -> Color:
	if layer_dict.has("color"):
		var c: Array = layer_dict["color"] as Array
		if c.size() >= 3:
			var a: float = float(c[3]) if c.size() >= 4 else 1.0
			return Color(float(c[0]), float(c[1]), float(c[2]), a)
	return fallback
