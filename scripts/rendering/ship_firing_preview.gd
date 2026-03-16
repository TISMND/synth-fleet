class_name ShipFiringPreview
extends Node2D
## Live ship + weapon firing preview. Renders ship neon lines centered in a viewport
## with projectile simulation from the active hardpoint.
## Uses EffectLayerRenderer for composable effect layers.

var _ship: ShipData = null
var _weapon: WeaponData = null
var _hp_index: int = 0
var _cell_size: float = 4.0
var _viewport_size: Vector2 = Vector2(500, 600)
var _fire_point: Vector2 = Vector2(250, 300)
var _fire_direction: Vector2 = Vector2.UP
var _grid_center: Vector2 = Vector2.ZERO
var _ship_offset: Vector2 = Vector2.ZERO  # center of ship in viewport

# Projectile sim state
var _projectiles: Array = []
var _fire_accumulator: float = 0.0
var _particles: Array = []
var _preview_active: bool = false
var _next_id: int = 0
var _impact_y: float = 20.0

# Weapon state
var _fire_pattern: String = "single"
var _weapon_color: Color = Color.CYAN
var _resolved_layers: Dictionary = {}


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
		_resolved_layers = EffectLayerRenderer.resolve_layers(_weapon.effect_profile, -1)
	else:
		_weapon_color = Color.CYAN
		_fire_pattern = "single"
		_resolved_layers = {}
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
		var proj_resolved: Dictionary = proj.get("resolved_layers", _resolved_layers) as Dictionary

		# Motion (summed from all motion layers)
		var motion_layers: Array = proj_resolved.get("motion", []) as Array
		var x_offset: float = EffectLayerRenderer.compute_motion_offset(motion_layers, age)

		var vel: Vector2 = proj["vel"]
		var base_pos: Vector2 = proj["base_pos"]
		proj["pos"] = base_pos + vel * age + _fire_direction.orthogonal() * x_offset

		# Trail particles (from all trail layers)
		var trail_layers: Array = proj_resolved.get("trail", []) as Array
		var trail_particles: Array = proj["trail_particles"]
		EffectLayerRenderer.spawn_trail_particles(trail_layers, proj["pos"] as Vector2, _weapon_color, trail_particles)

		var trail_pts: Array = proj["trail_points"]
		var trail_pos: Vector2 = proj["pos"]
		trail_pts.append(trail_pos)
		if trail_pts.size() > 20:
			trail_pts.pop_front()

		# Beat FX
		var beat_fx_layers: Array = proj_resolved.get("beat_fx", []) as Array
		if not beat_fx_layers.is_empty():
			var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(beat_fx_layers, _weapon_color, age, delta)
			var sparkles: Array = fx_result.get("sparkle_particles", []) as Array
			var beat_fx_particles: Array = proj["beat_fx_particles"]
			for sparkle in sparkles:
				var s: Dictionary = sparkle as Dictionary
				s["pos"] = (s["pos"] as Vector2) + (proj["pos"] as Vector2)
				beat_fx_particles.append(s)

		# Age particles
		_age_particle_list(trail_particles, delta)
		_age_particle_list(proj["beat_fx_particles"] as Array, delta)

		var pos: Vector2 = proj["pos"]
		if pos.y < _impact_y or pos.y > _viewport_size.y or pos.x < 0 or pos.x > _viewport_size.x:
			# Impact
			var impact_layers: Array = proj_resolved.get("impact", []) as Array
			if not impact_layers.is_empty():
				var impact_particles: Array = EffectLayerRenderer.spawn_impact_stack(impact_layers, _weapon_color)
				for p in impact_particles:
					p["pos"] = (p["pos"] as Vector2) + pos
				_particles.append_array(impact_particles)
			to_remove.append(proj)

	for proj in to_remove:
		_projectiles.erase(proj)

	# Update loose particles
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
			"trail_particles": [],
			"beat_fx_particles": [],
			"resolved_layers": _resolved_layers,
		}
		_projectiles.append(proj)
		_next_id += 1

	# Muzzle from all muzzle layers
	var muzzle_layers: Array = _resolved_layers.get("muzzle", []) as Array
	if not muzzle_layers.is_empty():
		var muzzle_particles: Array = EffectLayerRenderer.spawn_muzzle_stack(muzzle_layers, _fire_point, _weapon_color)
		_particles.append_array(muzzle_particles)


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

	# 5. Particles
	for p in _particles:
		_draw_particle_glow(p)


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
	var age: float = float(proj["age"])
	var proj_resolved: Dictionary = proj.get("resolved_layers", _resolved_layers) as Dictionary

	# Draw per-projectile trail particles
	var trail_particles: Array = proj["trail_particles"]
	for p in trail_particles:
		_draw_particle_glow(p)

	# Draw beat fx particles
	var beat_fx_particles: Array = proj["beat_fx_particles"]
	for p in beat_fx_particles:
		_draw_particle_glow(p)

	# Draw ribbon trails
	var trail_layers: Array = proj_resolved.get("trail", []) as Array
	var trail_pts: Array = proj["trail_points"]
	if trail_pts.size() >= 2:
		EffectLayerRenderer.draw_ribbon_trails(self, trail_layers, trail_pts, _weapon_color, Vector2.ZERO)

	# Beat FX scale
	var beat_fx_layers: Array = proj_resolved.get("beat_fx", []) as Array
	var scale_mult: float = 1.0
	if not beat_fx_layers.is_empty():
		var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(beat_fx_layers, _weapon_color, age, 0.0)
		scale_mult = float(fx_result.get("scale_mult", 1.0))

	# Draw shape stack
	var shape_layers: Array = proj_resolved.get("shape", []) as Array
	if scale_mult != 1.0:
		draw_set_transform(pos, 0.0, Vector2(scale_mult, scale_mult))
		EffectLayerRenderer.draw_shape_stack(self, Vector2.ZERO, shape_layers, _weapon_color, age)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		EffectLayerRenderer.draw_shape_stack(self, pos, shape_layers, _weapon_color, age)


func _draw_particle_glow(p: Dictionary) -> void:
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
