class_name ShipFiringPreview
extends Node2D
## Live ship + weapon firing preview. Renders ship neon lines centered in a viewport
## with projectile simulation from the active hardpoint.

var _ship: ShipData = null
var _weapon: WeaponData = null
var _hp_index: int = 0
var _cell_size: float = 4.0
var _viewport_size: Vector2 = Vector2(500, 600)
var _fire_point: Vector2 = Vector2(250, 300)
var _fire_direction: Vector2 = Vector2.UP
var _grid_center: Vector2 = Vector2.ZERO
var _ship_offset: Vector2 = Vector2.ZERO  # center of ship in viewport

# Projectile sim state (lifted from WeaponPreview)
var _projectiles: Array = []
var _fire_accumulator: float = 0.0
var _particles: Array = []
var _preview_active: bool = false
var _next_id: int = 0
var _impact_y: float = 20.0

# Weapon effect configs
var _motion_config: Dictionary = {"type": "none", "params": {}}
var _muzzle_config: Dictionary = {"type": "none", "params": {}}
var _shape_config: Dictionary = {"type": "rect", "params": {}}
var _trail_config: Dictionary = {"type": "none", "params": {}}
var _impact_config: Dictionary = {"type": "none", "params": {}}
var _fire_pattern: String = "single"
var _weapon_color: Color = Color.CYAN


func set_ship(ship: ShipData) -> void:
	_ship = ship
	if _ship:
		_grid_center = Vector2(_ship.grid_size.x / 2.0, _ship.grid_size.y / 2.0)
		_ship_offset = Vector2(_viewport_size.x / 2.0, _viewport_size.y / 2.0)
	queue_redraw()


func set_weapon(weapon: WeaponData, hp_index: int) -> void:
	_weapon = weapon
	_hp_index = hp_index
	if _weapon:
		_weapon_color = Color(_weapon.color)
		_fire_pattern = _weapon.fire_pattern
		var ep: Dictionary = _weapon.effect_profile
		_motion_config = ep.get("motion", {"type": "none", "params": {}})
		_muzzle_config = ep.get("muzzle", {"type": "none", "params": {}})
		_shape_config = ep.get("shape", {"type": "rect", "params": {}})
		_trail_config = ep.get("trail", {"type": "none", "params": {}})
		_impact_config = ep.get("impact", {"type": "none", "params": {}})
	else:
		_weapon_color = Color.CYAN
		_fire_pattern = "single"
		_motion_config = {"type": "none", "params": {}}
		_muzzle_config = {"type": "none", "params": {}}
		_shape_config = {"type": "rect", "params": {}}
		_trail_config = {"type": "none", "params": {}}
		_impact_config = {"type": "none", "params": {}}
	_update_fire_point()
	queue_redraw()


func _update_fire_point() -> void:
	if not _ship or _hp_index < 0 or _hp_index >= _ship.hardpoints.size():
		_fire_point = Vector2(_viewport_size.x / 2.0, _viewport_size.y - 40.0)
		_fire_direction = Vector2.UP
		return
	var hp: Dictionary = _ship.hardpoints[_hp_index]
	var gp: Array = hp.get("grid_pos", [0, 0])
	var dir_deg: float = float(hp.get("direction_deg", 0.0))
	var hp_local: Vector2 = (Vector2(float(gp[0]), float(gp[1])) - _grid_center) * _cell_size
	_fire_point = _ship_offset + hp_local
	var dir_rad: float = deg_to_rad(dir_deg - 90.0)
	_fire_direction = Vector2(cos(dir_rad), sin(dir_rad))


func start() -> void:
	_preview_active = true


func stop() -> void:
	_preview_active = false
	_projectiles.clear()
	_particles.clear()
	queue_redraw()


func fire_once() -> void:
	## Fire a single volley. Called externally by piano roll playback on note hits.
	if _weapon:
		_fire_projectiles()


func _process(delta: float) -> void:
	if not _preview_active:
		return

	# Update projectiles
	var to_remove: Array = []
	for proj in _projectiles:
		proj["age"] = float(proj["age"]) + delta
		var age: float = float(proj["age"])

		var motion_type: String = str(_motion_config.get("type", "none"))
		var mparams: Dictionary = _motion_config.get("params", {})
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
		var base_pos: Vector2 = proj["base_pos"]
		proj["pos"] = base_pos + vel * age + _fire_direction.orthogonal() * x_offset

		_spawn_trail_particle(proj)

		var trail_pts: Array = proj["trail_points"]
		var trail_pos: Vector2 = proj["pos"]
		trail_pts.append(trail_pos)
		if trail_pts.size() > 20:
			trail_pts.pop_front()

		var pos: Vector2 = proj["pos"]
		if pos.y < _impact_y or pos.y > _viewport_size.y or pos.x < 0 or pos.x > _viewport_size.x:
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


func _fire_projectiles() -> void:
	var spawn_points: Array = []
	var directions: Array = []
	var speed: float = _weapon.projectile_speed if _weapon else 600.0

	match _fire_pattern:
		"single":
			spawn_points.append(_fire_point)
			directions.append(_fire_direction)
		"dual":
			var perp: Vector2 = _fire_direction.orthogonal() * 15.0
			spawn_points.append(_fire_point - perp)
			spawn_points.append(_fire_point + perp)
			directions.append(_fire_direction)
			directions.append(_fire_direction)
		"burst":
			for i in 3:
				spawn_points.append(_fire_point)
				directions.append(_fire_direction)
		"spread":
			for angle_deg in [-20.0, -10.0, 0.0, 10.0, 20.0]:
				spawn_points.append(_fire_point)
				directions.append(_fire_direction.rotated(deg_to_rad(angle_deg)))
		"wave":
			var perp: Vector2 = _fire_direction.orthogonal() * 20.0
			spawn_points.append(_fire_point - perp)
			spawn_points.append(_fire_point)
			spawn_points.append(_fire_point + perp)
			directions.append(_fire_direction)
			directions.append(_fire_direction)
			directions.append(_fire_direction)
		"scatter":
			for i in 4:
				var perp: Vector2 = _fire_direction.orthogonal() * randf_range(-10, 10)
				spawn_points.append(_fire_point + perp)
				directions.append(_fire_direction.rotated(deg_to_rad(randf_range(-15, 15))))
		_:
			spawn_points.append(_fire_point)
			directions.append(_fire_direction)

	for i in spawn_points.size():
		var sp: Vector2 = spawn_points[i]
		var dir: Vector2 = directions[i]
		var proj: Dictionary = {
			"id": _next_id,
			"pos": sp,
			"base_pos": sp,
			"vel": dir * speed,
			"age": 0.0,
			"trail_points": [],
		}
		_projectiles.append(proj)
		_next_id += 1

	_spawn_muzzle_particles(_fire_point)


func _spawn_muzzle_particles(origin: Vector2) -> void:
	var mtype: String = str(_muzzle_config.get("type", "none"))
	if mtype == "none":
		return
	var params: Dictionary = _muzzle_config.get("params", {})
	var count: int = int(params.get("particle_count", 6))
	var lifetime: float = float(params.get("lifetime", 0.3))
	var spread: float = float(params.get("spread_angle", 360.0))

	for i in count:
		var angle: float = 0.0
		var spd: float = randf_range(80, 200)
		match mtype:
			"radial_burst":
				angle = randf_range(0, TAU)
			"directional_flash":
				angle = _fire_direction.angle() + randf_range(-deg_to_rad(spread / 2.0), deg_to_rad(spread / 2.0))
			"ring_pulse":
				angle = TAU * float(i) / float(count)
				spd = 120.0
			"spiral_burst":
				angle = TAU * float(i) / float(count) + float(i) * 0.3
				spd = 100.0 + float(i) * 10.0
			_:
				angle = randf_range(0, TAU)

		_particles.append({
			"pos": origin,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"age": 0.0,
			"lifetime": lifetime,
			"size": randf_range(2.0, 4.0),
			"color": _weapon_color,
		})


func _spawn_impact_particles(origin: Vector2) -> void:
	var itype: String = str(_impact_config.get("type", "none"))
	if itype == "none":
		return
	var params: Dictionary = _impact_config.get("params", {})
	var count: int = int(params.get("particle_count", 8))
	var lifetime: float = float(params.get("lifetime", 0.4))
	var radius: float = float(params.get("radius", 20.0))

	for i in count:
		var angle: float = TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		var spd: float = radius / lifetime
		match itype:
			"ring_expand":
				spd = radius / lifetime * 1.5
			"shatter_lines":
				angle = randf_range(0, TAU)
				spd = randf_range(radius / lifetime * 0.5, radius / lifetime * 1.5)
			"nova_flash":
				spd = radius / lifetime * 2.0
			"ripple":
				spd = radius / lifetime * 0.8
		_particles.append({
			"pos": origin,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"age": 0.0,
			"lifetime": lifetime,
			"size": randf_range(2.0, 5.0),
			"color": _weapon_color,
		})


func _spawn_trail_particle(proj: Dictionary) -> void:
	var ttype: String = str(_trail_config.get("type", "none"))
	if ttype == "none":
		return
	var params: Dictionary = _trail_config.get("params", {})
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
					"color": _weapon_color,
				})
		"sparkle":
			if randf() < 0.5:
				_particles.append({
					"pos": pos + Vector2(randf_range(-8, 8), randf_range(-2, 6)),
					"vel": Vector2(randf_range(-40, 40), randf_range(10, 40)),
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.25)),
					"size": randf_range(1.0, 2.5),
					"color": _weapon_color,
				})
		"afterimage":
			if randf() < 0.3:
				_particles.append({
					"pos": pos,
					"vel": Vector2.ZERO,
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.15)),
					"size": 4.0,
					"color": _weapon_color,
				})


# ── Drawing ──────────────────────────────────────────────────

func _draw() -> void:
	# 1. Dark background
	draw_rect(Rect2(Vector2.ZERO, _viewport_size), Color(0.02, 0.02, 0.05, 1.0))

	# Subtle grid
	var grid_color: Color = Color(0.1, 0.1, 0.15, 0.3)
	for x in range(0, int(_viewport_size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, _viewport_size.y), grid_color, 1.0)
	for y in range(0, int(_viewport_size.y), 40):
		draw_line(Vector2(0, y), Vector2(_viewport_size.x, y), grid_color, 1.0)

	# 2. Ship neon lines
	if _ship:
		for line_data in _ship.lines:
			var from_arr: Array = line_data["from"]
			var to_arr: Array = line_data["to"]
			var col_hex: String = str(line_data.get("color", "#00FFFF"))
			var col: Color = Color(col_hex)
			var a: Vector2 = _ship_offset + (Vector2(float(from_arr[0]), float(from_arr[1])) - _grid_center) * _cell_size
			var b: Vector2 = _ship_offset + (Vector2(float(to_arr[0]), float(to_arr[1])) - _grid_center) * _cell_size
			_draw_neon_line(a, b, col)

		# 3. Hardpoint markers
		for i in _ship.hardpoints.size():
			var hp: Dictionary = _ship.hardpoints[i]
			var gp: Array = hp.get("grid_pos", [0, 0])
			var pos: Vector2 = _ship_offset + (Vector2(float(gp[0]), float(gp[1])) - _grid_center) * _cell_size
			if i == _hp_index:
				draw_circle(pos, 5.0, Color(1.0, 0.9, 0.3, 0.6))
				draw_circle(pos, 3.0, Color(1.0, 0.7, 0.2, 1.0))
			else:
				draw_circle(pos, 3.0, Color(1.0, 0.7, 0.2, 0.4))

	# 4. Projectiles + trails
	for proj in _projectiles:
		_draw_projectile(proj)
	for proj in _projectiles:
		_draw_ribbon_trail(proj)

	# 5. Particles
	for p in _particles:
		_draw_particle(p)


func _draw_neon_line(a: Vector2, b: Vector2, col: Color) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var w: float = 2.0 + 6.0 * t
		var alpha: float = (1.0 - t) * 0.3
		draw_line(a, b, Color(col, alpha), w)
	draw_line(a, b, col, 2.0)
	draw_line(a, b, Color(1, 1, 1, 0.6), 1.0)


func _draw_projectile(proj: Dictionary) -> void:
	var pos: Vector2 = proj["pos"]
	var stype: String = str(_shape_config.get("type", "rect"))
	var params: Dictionary = _shape_config.get("params", {})
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
		"pulse_orb":
			var r: float = float(params.get("radius", 5.0))
			var pulse: float = 1.0 + 0.3 * sin(float(proj["age"]) * 10.0)
			_draw_glow_circle(pos, r * pulse, glow_w * pulse, intensity * 1.2, core_b)
		_:
			_draw_glow_rect(pos, 6.0, 12.0, glow_w, intensity, core_b)


func _draw_glow_rect(center: Vector2, w: float, h: float, glow_w: float, intensity: float, _core_b: float) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gw: float = glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		var glow_rect: Rect2 = Rect2(center.x - w / 2.0 - gw, center.y - h / 2.0 - gw, w + gw * 2, h + gw * 2)
		draw_rect(glow_rect, Color(_weapon_color, alpha))
	draw_rect(Rect2(center.x - w / 2.0, center.y - h / 2.0, w, h), _weapon_color)
	draw_rect(Rect2(center.x - w / 4.0, center.y - h / 4.0, w / 2.0, h / 2.0), Color(1, 1, 1, _core_b * 0.8))


func _draw_glow_circle(center: Vector2, r: float, glow_w: float, intensity: float, core_b: float) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gr: float = r + glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		draw_circle(center, gr, Color(_weapon_color, alpha))
	draw_circle(center, r, _weapon_color)
	draw_circle(center, r * 0.5, Color(1, 1, 1, core_b * 0.8))


func _draw_glow_diamond(center: Vector2, w: float, h: float, glow_w: float, intensity: float, _core_b: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(0, h / 2.0),
		center + Vector2(-w / 2.0, 0),
	])
	for i in range(2, 0, -1):
		var t: float = float(i) / 2.0
		var scale_f: float = 1.0 + (glow_w / maxf(w, h)) * t
		var glow_pts: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_pts.append(center + (p - center) * scale_f)
		var alpha: float = intensity * (1.0 - t) * 0.3
		draw_colored_polygon(glow_pts, Color(_weapon_color, alpha))
	draw_colored_polygon(points, _weapon_color)


func _draw_ribbon_trail(proj: Dictionary) -> void:
	var ttype: String = str(_trail_config.get("type", "none"))
	if ttype != "ribbon" and ttype != "sine_ribbon":
		return
	var params: Dictionary = _trail_config.get("params", {})
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
			var off: float = sin(float(i) * freq * 0.5) * amp * (1.0 - t)
			from_pt.x += off
			to_pt.x += off

		var w: float = lerpf(width_end, width_start, t)
		var alpha: float = t * 0.7
		draw_line(from_pt, to_pt, Color(_weapon_color, alpha), maxf(w, 1.0))


func _draw_particle(p: Dictionary) -> void:
	var age: float = float(p["age"])
	var lifetime: float = float(p["lifetime"])
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	var alpha: float = (1.0 - t) * 0.8
	var sz: float = float(p["size"]) * (1.0 - t * 0.5)
	var pos: Vector2 = p["pos"]
	var col: Color = p["color"]
	draw_circle(pos, sz * 2.0, Color(col, alpha * 0.2))
	draw_circle(pos, sz, Color(col, alpha))
	draw_circle(pos, sz * 0.4, Color(1, 1, 1, alpha * 0.6))
