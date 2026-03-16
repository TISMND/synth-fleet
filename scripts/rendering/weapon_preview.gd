class_name WeaponPreview
extends Node2D
## Live weapon preview — renders projectiles with full effect stack inside a SubViewport.
## Synced to BeatClock. Used by the Weapon Builder.

var weapon_color: Color = Color.CYAN
var projectile_speed: float = 600.0
var fire_pattern: String = "single"
var motion_config: Dictionary = {"type": "none", "params": {}}
var muzzle_config: Dictionary = {"type": "none", "params": {}}
var shape_config: Dictionary = {"type": "rect", "params": {}}
var trail_config: Dictionary = {"type": "none", "params": {}}
var impact_config: Dictionary = {"type": "none", "params": {}}
var direction_deg: float = 0.0
var loop_file_path: String = ""
var loop_length_bars: int = 2
var fire_triggers: Array = []

var _projectiles: Array = []
var _particles: Array = []
var _preview_active: bool = false
var _viewport_size: Vector2 = Vector2(400, 500)
var _fire_point: Vector2 = Vector2(200, 460)
var _impact_y: float = 40.0
var _next_id: int = 0
var _prev_loop_pos: float = -1.0
var _fire_triggers_sorted: Array = []
var _loop_length_beats: float = 0.0


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
	queue_redraw()


func update_weapon(data: Dictionary) -> void:
	weapon_color = Color(str(data.get("color", "#00FFFF")))
	projectile_speed = float(data.get("projectile_speed", 600.0))
	fire_pattern = str(data.get("fire_pattern", "single"))
	var ep: Dictionary = data.get("effect_profile", {})
	motion_config = ep.get("motion", {"type": "none", "params": {}})
	muzzle_config = ep.get("muzzle", {"type": "none", "params": {}})
	shape_config = ep.get("shape", {"type": "rect", "params": {}})
	trail_config = ep.get("trail", {"type": "none", "params": {}})
	impact_config = ep.get("impact", {"type": "none", "params": {}})
	direction_deg = float(data.get("direction_deg", 0.0))
	loop_file_path = str(data.get("loop_file_path", ""))
	loop_length_bars = int(data.get("loop_length_bars", 2))
	fire_triggers = data.get("fire_triggers", [])
	_fire_triggers_sorted = fire_triggers.duplicate()
	_fire_triggers_sorted.sort()
	_loop_length_beats = float(loop_length_bars * BeatClock.beats_per_measure)
	_prev_loop_pos = -1.0


func _fire_projectiles() -> void:
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

	for i in spawn_points.size():
		var proj: Dictionary = {
			"id": _next_id,
			"pos": spawn_points[i] as Vector2,
			"base_x": (spawn_points[i] as Vector2).x,
			"vel": (directions[i] as Vector2) * projectile_speed,
			"age": 0.0,
			"trail_points": [],
		}
		_projectiles.append(proj)
		_next_id += 1

	_spawn_muzzle_particles(_fire_point)


func _spawn_muzzle_particles(origin: Vector2) -> void:
	var mtype: String = str(muzzle_config.get("type", "none"))
	if mtype == "none":
		return
	var params: Dictionary = muzzle_config.get("params", {})
	var count: int = int(params.get("particle_count", 6))
	var lifetime: float = float(params.get("lifetime", 0.3))
	var spread: float = float(params.get("spread_angle", 360.0))

	for i in count:
		var angle: float = 0.0
		var speed: float = randf_range(80, 200)
		match mtype:
			"radial_burst":
				angle = randf_range(0, TAU)
			"directional_flash":
				angle = -PI / 2.0 + randf_range(-deg_to_rad(spread / 2.0), deg_to_rad(spread / 2.0))
			"ring_pulse":
				angle = TAU * float(i) / float(count)
				speed = 120.0
			"spiral_burst":
				angle = TAU * float(i) / float(count) + float(i) * 0.3
				speed = 100.0 + float(i) * 10.0
			_:
				angle = randf_range(0, TAU)

		_particles.append({
			"pos": origin,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"age": 0.0,
			"lifetime": lifetime,
			"size": randf_range(2.0, 4.0),
			"color": weapon_color,
		})


func _spawn_impact_particles(origin: Vector2) -> void:
	var itype: String = str(impact_config.get("type", "none"))
	if itype == "none":
		return
	var params: Dictionary = impact_config.get("params", {})
	var count: int = int(params.get("particle_count", 8))
	var lifetime: float = float(params.get("lifetime", 0.4))
	var radius: float = float(params.get("radius", 20.0))

	for i in count:
		var angle: float = TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		var speed: float = radius / lifetime

		match itype:
			"ring_expand":
				speed = radius / lifetime * 1.5
			"shatter_lines":
				angle = randf_range(0, TAU)
				speed = randf_range(radius / lifetime * 0.5, radius / lifetime * 1.5)
			"nova_flash":
				speed = radius / lifetime * 2.0
			"ripple":
				speed = radius / lifetime * 0.8

		_particles.append({
			"pos": origin,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"age": 0.0,
			"lifetime": lifetime,
			"size": randf_range(2.0, 5.0),
			"color": weapon_color,
		})


func _process(delta: float) -> void:
	if not _preview_active:
		return

	# Fire at exact beat positions, matching HardpointController logic
	if not _fire_triggers_sorted.is_empty() and _loop_length_beats > 0.0:
		var curr: float = BeatClock.get_loop_beat_position(_loop_length_beats)
		if _prev_loop_pos < 0.0:
			_prev_loop_pos = curr
		else:
			var prev: float = _prev_loop_pos
			_prev_loop_pos = curr
			for trigger in _fire_triggers_sorted:
				var t: float = float(trigger)
				if curr >= prev:
					if t > prev and t <= curr:
						_fire_projectiles()
				else:
					if t > prev or t <= curr:
						_fire_projectiles()

	# Update projectiles
	var to_remove: Array = []
	for proj in _projectiles:
		proj["age"] = float(proj["age"]) + delta
		var age: float = float(proj["age"])

		# Apply motion
		var motion_type: String = str(motion_config.get("type", "none"))
		var mparams: Dictionary = motion_config.get("params", {})
		var x_offset: float = 0.0

		match motion_type:
			"sine_wave":
				var amp: float = float(mparams.get("amplitude", 30.0))
				var freq: float = float(mparams.get("frequency", 3.0))
				x_offset = sin(age * freq * TAU) * amp
			"corkscrew":
				var amp: float = float(mparams.get("amplitude", 20.0))
				var freq: float = float(mparams.get("frequency", 5.0))
				var phase: float = float(mparams.get("phase_offset", 0.0))
				x_offset = sin(age * freq * TAU + phase) * amp
			"wobble":
				var amp: float = float(mparams.get("amplitude", 10.0))
				var freq: float = float(mparams.get("frequency", 8.0))
				x_offset = sin(age * freq * TAU) * amp * (1.0 + 0.3 * sin(age * freq * 3.7))

		var vel: Vector2 = proj["vel"]
		var current_pos: Vector2 = proj["pos"]
		proj["pos"] = Vector2(float(proj["base_x"]) + x_offset + vel.x * age, current_pos.y + vel.y * delta)

		# Spawn trail particles
		_spawn_trail_particle(proj)

		# Store trail point for ribbon trails
		var trail_pts: Array = proj["trail_points"]
		var trail_pos: Vector2 = proj["pos"]
		trail_pts.append(trail_pos)
		if trail_pts.size() > 20:
			trail_pts.pop_front()

		# Check if off screen (any edge)
		var pos: Vector2 = proj["pos"]
		if pos.y < _impact_y or pos.y > _viewport_size.y + 10.0 or pos.x < -10.0 or pos.x > _viewport_size.x + 10.0:
			_spawn_impact_particles(pos)
			to_remove.append(proj)

	for proj in to_remove:
		_projectiles.erase(proj)

	# Update particles
	var dead_particles: Array = []
	for p in _particles:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if float(p["age"]) >= float(p["lifetime"]):
			dead_particles.append(p)

	for p in dead_particles:
		_particles.erase(p)

	queue_redraw()


func _spawn_trail_particle(proj: Dictionary) -> void:
	var ttype: String = str(trail_config.get("type", "none"))
	if ttype == "none":
		return
	var params: Dictionary = trail_config.get("params", {})
	var pos: Vector2 = proj["pos"]

	match ttype:
		"particle":
			if randf() < 0.6:
				_particles.append({
					"pos": pos + Vector2(randf_range(-3, 3), randf_range(0, 5)),
					"vel": Vector2(randf_range(-20, 20), randf_range(20, 60)),
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.2)),
					"size": randf_range(1.0, 3.0),
					"color": weapon_color,
				})
		"sparkle":
			if randf() < 0.5:
				_particles.append({
					"pos": pos + Vector2(randf_range(-8, 8), randf_range(-2, 6)),
					"vel": Vector2(randf_range(-40, 40), randf_range(10, 40)),
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.25)),
					"size": randf_range(1.0, 2.5),
					"color": weapon_color,
				})
		"afterimage":
			if randf() < 0.3:
				_particles.append({
					"pos": pos,
					"vel": Vector2.ZERO,
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.15)),
					"size": 4.0,
					"color": weapon_color,
				})


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

	# Draw ribbon trails
	for proj in _projectiles:
		_draw_ribbon_trail(proj)

	# Draw particles
	for p in _particles:
		_draw_particle(p)


func _draw_projectile(proj: Dictionary) -> void:
	var pos: Vector2 = proj["pos"]
	var stype: String = str(shape_config.get("type", "rect"))
	var params: Dictionary = shape_config.get("params", {})
	var glow_w: float = float(params.get("glow_width", 3.0))
	var intensity: float = float(params.get("glow_intensity", 0.8))
	var core_b: float = float(params.get("core_brightness", 1.0))

	match stype:
		"rect":
			var w: float = float(params.get("width", 6.0))
			var h: float = float(params.get("height", 12.0))
			_draw_glow_rect(pos, w, h, glow_w, intensity, core_b)
		"streak":
			var w: float = float(params.get("width", 3.0))
			var h: float = float(params.get("height", 20.0))
			_draw_glow_rect(pos, w, h, glow_w, intensity, core_b)
		"orb":
			var r: float = float(params.get("radius", 4.0))
			_draw_glow_circle(pos, r, glow_w, intensity, core_b)
		"diamond":
			var w: float = float(params.get("width", 8.0))
			var h: float = float(params.get("height", 14.0))
			_draw_glow_diamond(pos, w, h, glow_w, intensity, core_b)
		"arrow":
			var w: float = float(params.get("width", 8.0))
			var h: float = float(params.get("height", 16.0))
			_draw_glow_arrow(pos, w, h, glow_w, intensity, core_b)
		"pulse_orb":
			var r: float = float(params.get("radius", 5.0))
			var pulse: float = 1.0 + 0.3 * sin(float(proj["age"]) * 10.0)
			_draw_glow_circle(pos, r * pulse, glow_w * pulse, intensity * 1.2, core_b)
		_:
			_draw_glow_rect(pos, 6.0, 12.0, glow_w, intensity, core_b)


func _draw_glow_rect(center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float) -> void:
	# Glow layers (outer to inner)
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gw: float = glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		var glow_rect: Rect2 = Rect2(center.x - w / 2.0 - gw, center.y - h / 2.0 - gw, w + gw * 2, h + gw * 2)
		draw_rect(glow_rect, Color(weapon_color, alpha))
	# Core
	var core_rect: Rect2 = Rect2(center.x - w / 2.0, center.y - h / 2.0, w, h)
	draw_rect(core_rect, weapon_color)
	# Bright center
	var inner: Rect2 = Rect2(center.x - w / 4.0, center.y - h / 4.0, w / 2.0, h / 2.0)
	draw_rect(inner, Color(1, 1, 1, core_b * 0.8))


func _draw_glow_circle(center: Vector2, r: float, glow_w: float, intensity: float, core_b: float) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gr: float = r + glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		draw_circle(center, gr, Color(weapon_color, alpha))
	draw_circle(center, r, weapon_color)
	draw_circle(center, r * 0.5, Color(1, 1, 1, core_b * 0.8))


func _draw_glow_diamond(center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(0, h / 2.0),
		center + Vector2(-w / 2.0, 0),
	])
	# Glow
	for i in range(2, 0, -1):
		var t: float = float(i) / 2.0
		var scale_f: float = 1.0 + (glow_w / maxf(w, h)) * t
		var glow_pts: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_pts.append(center + (p - center) * scale_f)
		var alpha: float = intensity * (1.0 - t) * 0.3
		draw_colored_polygon(glow_pts, Color(weapon_color, alpha))
	draw_colored_polygon(points, weapon_color)
	# Core highlight
	var inner_pts: PackedVector2Array = PackedVector2Array()
	for p in points:
		inner_pts.append(center + (p - center) * 0.4)
	draw_colored_polygon(inner_pts, Color(1, 1, 1, core_b * 0.6))


func _draw_glow_arrow(center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(w / 4.0, 0),
		center + Vector2(w / 4.0, h / 2.0),
		center + Vector2(-w / 4.0, h / 2.0),
		center + Vector2(-w / 4.0, 0),
		center + Vector2(-w / 2.0, 0),
	])
	for i in range(2, 0, -1):
		var t: float = float(i) / 2.0
		var scale_f: float = 1.0 + (glow_w / maxf(w, h)) * t
		var glow_pts: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_pts.append(center + (p - center) * scale_f)
		var alpha: float = intensity * (1.0 - t) * 0.3
		draw_colored_polygon(glow_pts, Color(weapon_color, alpha))
	draw_colored_polygon(points, weapon_color)


func _draw_ribbon_trail(proj: Dictionary) -> void:
	var ttype: String = str(trail_config.get("type", "none"))
	if ttype != "ribbon" and ttype != "sine_ribbon":
		return
	var params: Dictionary = trail_config.get("params", {})
	var trail_pts: Array = proj["trail_points"]
	if trail_pts.size() < 2:
		return

	var width_start: float = float(params.get("width_start", 4.0))
	var width_end: float = float(params.get("width_end", 0.0))
	var count: int = trail_pts.size()

	for i in range(count - 1):
		var t: float = float(i) / float(count - 1)
		var from_pt: Vector2 = trail_pts[i]
		var to_pt: Vector2 = trail_pts[i + 1]

		if ttype == "sine_ribbon":
			var amp: float = float(params.get("amplitude", 5.0))
			var freq: float = float(params.get("frequency", 4.0))
			var offset: float = sin(float(i) * freq * 0.5) * amp * (1.0 - t)
			from_pt.x += offset
			to_pt.x += offset

		var w: float = lerpf(width_end, width_start, t)
		var alpha: float = t * 0.7
		draw_line(from_pt, to_pt, Color(weapon_color, alpha), maxf(w, 1.0))


func _draw_particle(p: Dictionary) -> void:
	var age: float = float(p["age"])
	var lifetime: float = float(p["lifetime"])
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	var alpha: float = (1.0 - t) * 0.8
	var sz: float = float(p["size"]) * (1.0 - t * 0.5)
	var pos: Vector2 = p["pos"]
	var col: Color = p["color"]

	# Glow
	draw_circle(pos, sz * 2.0, Color(col, alpha * 0.2))
	draw_circle(pos, sz, Color(col, alpha))
	draw_circle(pos, sz * 0.4, Color(1, 1, 1, alpha * 0.6))
