class_name Projectile
extends Area2D
## Projectile fired by hardpoints. Renders shape/motion/trail from effect_profile.

var direction: Vector2 = Vector2.UP
var speed: float = 600.0
var damage: int = 10
var weapon_color: Color = Color.CYAN
var effect_profile: Dictionary = {}

var _age: float = 0.0
var _base_x: float = 0.0
var _trail_points: Array = []
var _trail_particles: Array = []


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 12)
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_base_x = position.x


func _process(delta: float) -> void:
	_age += delta

	# --- Motion ---
	var motion: Dictionary = effect_profile.get("motion", {}) as Dictionary
	var motion_type: String = str(motion.get("type", "none"))
	var mparams: Dictionary = motion.get("params", {}) as Dictionary
	var x_offset: float = 0.0

	match motion_type:
		"sine_wave":
			var amp: float = float(mparams.get("amplitude", 30.0))
			var freq: float = float(mparams.get("frequency", 3.0))
			x_offset = sin(_age * freq * TAU) * amp
		"corkscrew":
			var amp: float = float(mparams.get("amplitude", 20.0))
			var freq: float = float(mparams.get("frequency", 5.0))
			var phase: float = float(mparams.get("phase_offset", 0.0))
			x_offset = sin(_age * freq * TAU + phase) * amp
		"wobble":
			var amp: float = float(mparams.get("amplitude", 10.0))
			var freq: float = float(mparams.get("frequency", 8.0))
			x_offset = sin(_age * freq * TAU) * amp * (1.0 + 0.3 * sin(_age * freq * 3.7))

	position.y += direction.y * speed * delta
	_base_x += direction.x * speed * delta
	position.x = _base_x + x_offset

	# --- Trail particles ---
	_spawn_trail_particle()

	# --- Trail points (for ribbon trails) ---
	_trail_points.append(global_position)
	if _trail_points.size() > 20:
		_trail_points.pop_front()

	# --- Age trail particles ---
	var dead: Array = []
	for p in _trail_particles:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if float(p["age"]) >= float(p["lifetime"]):
			dead.append(p)
	for p in dead:
		_trail_particles.erase(p)

	# --- Off-screen check ---
	if position.y < -50 or position.y > 1130 or position.x < -50 or position.x > 1970:
		_die()
		return

	queue_redraw()


func _draw() -> void:
	# --- Draw trail particles ---
	for p in _trail_particles:
		_draw_trail_particle(p)

	# --- Draw ribbon trail ---
	_draw_ribbon_trail()

	# --- Draw shape ---
	_draw_shape()


func _draw_shape() -> void:
	var shape_cfg: Dictionary = effect_profile.get("shape", {}) as Dictionary
	var stype: String = str(shape_cfg.get("type", "rect"))
	var params: Dictionary = shape_cfg.get("params", {}) as Dictionary
	var glow_w: float = float(params.get("glow_width", 3.0))
	var intensity: float = float(params.get("glow_intensity", 0.8))
	var core_b: float = float(params.get("core_brightness", 1.0))
	var center: Vector2 = Vector2.ZERO

	match stype:
		"rect":
			var w: float = float(params.get("width", 6.0))
			var h: float = float(params.get("height", 12.0))
			_draw_glow_rect(center, w, h, glow_w, intensity, core_b)
		"streak":
			var w: float = float(params.get("width", 3.0))
			var h: float = float(params.get("height", 20.0))
			_draw_glow_rect(center, w, h, glow_w, intensity, core_b)
		"orb":
			var r: float = float(params.get("radius", 4.0))
			_draw_glow_circle(center, r, glow_w, intensity, core_b)
		"diamond":
			var w: float = float(params.get("width", 8.0))
			var h: float = float(params.get("height", 14.0))
			_draw_glow_diamond(center, w, h, glow_w, intensity, core_b)
		"arrow":
			var w: float = float(params.get("width", 8.0))
			var h: float = float(params.get("height", 16.0))
			_draw_glow_arrow(center, w, h, glow_w, intensity, core_b)
		"pulse_orb":
			var r: float = float(params.get("radius", 5.0))
			var pulse: float = 1.0 + 0.3 * sin(_age * 10.0)
			_draw_glow_circle(center, r * pulse, glow_w * pulse, intensity * 1.2, core_b)
		_:
			_draw_glow_rect(center, 6.0, 12.0, glow_w, intensity, core_b)


# --- Glow helpers (ported from WeaponPreview) ---

func _draw_glow_rect(center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gw: float = glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		var glow_rect: Rect2 = Rect2(center.x - w / 2.0 - gw, center.y - h / 2.0 - gw, w + gw * 2, h + gw * 2)
		draw_rect(glow_rect, Color(weapon_color, alpha))
	draw_rect(Rect2(center.x - w / 2.0, center.y - h / 2.0, w, h), weapon_color)
	draw_rect(Rect2(center.x - w / 4.0, center.y - h / 4.0, w / 2.0, h / 2.0), Color(1, 1, 1, core_b * 0.8))


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
	for i in range(2, 0, -1):
		var t: float = float(i) / 2.0
		var scale_f: float = 1.0 + (glow_w / maxf(w, h)) * t
		var glow_pts: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_pts.append(center + (p - center) * scale_f)
		var alpha: float = intensity * (1.0 - t) * 0.3
		draw_colored_polygon(glow_pts, Color(weapon_color, alpha))
	draw_colored_polygon(points, weapon_color)
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


# --- Trail rendering ---

func _spawn_trail_particle() -> void:
	var trail: Dictionary = effect_profile.get("trail", {}) as Dictionary
	var ttype: String = str(trail.get("type", "none"))
	if ttype == "none" or ttype == "ribbon" or ttype == "sine_ribbon":
		return
	var params: Dictionary = trail.get("params", {}) as Dictionary
	var pos: Vector2 = global_position

	match ttype:
		"particle":
			if randf() < 0.6:
				_trail_particles.append({
					"pos": pos + Vector2(randf_range(-3, 3), randf_range(0, 5)),
					"vel": Vector2(randf_range(-20, 20), randf_range(20, 60)),
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.2)),
					"size": randf_range(1.0, 3.0),
					"color": weapon_color,
				})
		"sparkle":
			if randf() < 0.5:
				_trail_particles.append({
					"pos": pos + Vector2(randf_range(-8, 8), randf_range(-2, 6)),
					"vel": Vector2(randf_range(-40, 40), randf_range(10, 40)),
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.25)),
					"size": randf_range(1.0, 2.5),
					"color": weapon_color,
				})
		"afterimage":
			if randf() < 0.3:
				_trail_particles.append({
					"pos": pos,
					"vel": Vector2.ZERO,
					"age": 0.0,
					"lifetime": float(params.get("lifetime", 0.15)),
					"size": 4.0,
					"color": weapon_color,
				})


func _draw_trail_particle(p: Dictionary) -> void:
	var age: float = float(p["age"])
	var lifetime: float = float(p["lifetime"])
	if age >= lifetime:
		return
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	var alpha: float = (1.0 - t) * 0.8
	var sz: float = float(p["size"]) * (1.0 - t * 0.5)
	# Convert global trail particle pos to local
	var pos: Vector2 = (p["pos"] as Vector2) - global_position
	var col: Color = p["color"] as Color
	draw_circle(pos, sz * 2.0, Color(col, alpha * 0.2))
	draw_circle(pos, sz, Color(col, alpha))
	draw_circle(pos, sz * 0.4, Color(1, 1, 1, alpha * 0.6))


func _draw_ribbon_trail() -> void:
	var trail: Dictionary = effect_profile.get("trail", {}) as Dictionary
	var ttype: String = str(trail.get("type", "none"))
	if ttype != "ribbon" and ttype != "sine_ribbon":
		return
	if _trail_points.size() < 2:
		return
	var params: Dictionary = trail.get("params", {}) as Dictionary
	var width_start: float = float(params.get("width_start", 4.0))
	var width_end: float = float(params.get("width_end", 0.0))
	var count: int = _trail_points.size()

	for i in range(count - 1):
		var t: float = float(i) / float(count - 1)
		# Convert global trail points to local
		var from_pt: Vector2 = (_trail_points[i] as Vector2) - global_position
		var to_pt: Vector2 = (_trail_points[i + 1] as Vector2) - global_position

		if ttype == "sine_ribbon":
			var amp: float = float(params.get("amplitude", 5.0))
			var freq: float = float(params.get("frequency", 4.0))
			var offset: float = sin(float(i) * freq * 0.5) * amp * (1.0 - t)
			from_pt.x += offset
			to_pt.x += offset

		var w: float = lerpf(width_end, width_start, t)
		var alpha: float = t * 0.7
		draw_line(from_pt, to_pt, Color(weapon_color, alpha), maxf(w, 1.0))


# --- Death / Impact ---

func _die() -> void:
	_spawn_impact_effect()
	queue_free()


func _spawn_impact_effect() -> void:
	var impact: Dictionary = effect_profile.get("impact", {}) as Dictionary
	var itype: String = str(impact.get("type", "none"))
	if itype == "none":
		return
	var params: Dictionary = impact.get("params", {}) as Dictionary
	var count: int = int(params.get("particle_count", 8))
	var lifetime: float = float(params.get("lifetime", 0.4))
	var radius: float = float(params.get("radius", 20.0))

	var particles: Array = []
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

		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"age": 0.0,
			"lifetime": lifetime,
			"size": randf_range(2.0, 5.0),
			"color": weapon_color,
		})

	var container: Node2D = get_parent()
	if container:
		var fx: EffectParticles = EffectParticles.new()
		fx.position = global_position
		fx.setup(particles, weapon_color)
		container.add_child(fx)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	_die()
