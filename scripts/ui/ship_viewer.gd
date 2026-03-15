extends Control
## Visual showcase screen: a hand-drawn synthwave ship with neon glow.

const MOVE_ACCEL := 1200.0
const MOVE_DECEL := 800.0
const MAX_SPEED := 400.0
const BANK_LERP := 6.0

var _velocity := 0.0
var _velocity_y := 0.0
var _bank := 0.0
var _ship_draw: Node2D
var _exhaust_draw: Node2D
var _exhaust_particles: Array[Dictionary] = []
var _exhaust_timer := 0.0


func _ready() -> void:
	ThemeManager.apply_grid_background($Background)
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Create drawing nodes in code (inner classes can't be referenced from .tscn)
	_exhaust_draw = _ExhaustDraw.new()
	_exhaust_draw.viewer = self
	add_child(_exhaust_draw)

	_ship_draw = _ShipDraw.new()
	add_child(_ship_draw)

	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.6)


func _process(delta: float) -> void:
	# Input
	var input_dir := 0.0
	if Input.is_action_pressed("move_left"):
		input_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir += 1.0

	var input_dir_y := 0.0
	if Input.is_action_pressed("move_up"):
		input_dir_y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir_y += 1.0

	# Acceleration / deceleration
	if input_dir != 0.0:
		_velocity = move_toward(_velocity, input_dir * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity = move_toward(_velocity, 0.0, MOVE_DECEL * delta)

	if input_dir_y != 0.0:
		_velocity_y = move_toward(_velocity_y, input_dir_y * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity_y = move_toward(_velocity_y, 0.0, MOVE_DECEL * delta)

	# Move ship
	_ship_draw.position.x += _velocity * delta
	_ship_draw.position.y += _velocity_y * delta
	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position.x = clampf(_ship_draw.position.x, 60.0, vp_size.x - 60.0)
	_ship_draw.position.y = clampf(_ship_draw.position.y, 60.0, vp_size.y - 60.0)

	# Bank based on velocity (no rotation)
	var target_bank: float = -_velocity / MAX_SPEED
	_bank = lerpf(_bank, target_bank, BANK_LERP * delta)
	_ship_draw.bank = _bank
	_ship_draw.queue_redraw()

	# Exhaust particles
	_exhaust_timer += delta
	if _exhaust_timer > 0.016:
		_exhaust_timer = 0.0
		_spawn_exhaust()
	_update_exhaust(delta)
	_exhaust_draw.queue_redraw()


func _spawn_exhaust() -> void:
	var ship_pos: Vector2 = _ship_draw.position
	var s := 1.4
	var x_shift: float = _bank * 2.5 * s
	for offset_x in [-18.0, 18.0]:
		var side_factor: float = signf(offset_x)
		var banked_x: float = offset_x * (1.0 + _bank * side_factor * 0.15) * s + x_shift
		var local_pos := Vector2(banked_x, 32.0 * s)
		var world_pos: Vector2 = ship_pos + local_pos
		_exhaust_particles.append({
			"pos": world_pos,
			"vel": Vector2(randf_range(-15.0, 15.0), randf_range(80.0, 160.0)),
			"life": 1.0,
			"max_life": 1.0,
			"size": randf_range(2.0, 4.5),
		})


func _update_exhaust(delta: float) -> void:
	var i := 0
	while i < _exhaust_particles.size():
		var p: Dictionary = _exhaust_particles[i]
		var life: float = p["life"]
		life -= delta * 1.5
		p["life"] = life
		if life <= 0.0:
			_exhaust_particles.remove_at(i)
			continue
		var vel: Vector2 = p["vel"]
		var pos: Vector2 = p["pos"]
		pos += vel * delta
		p["pos"] = pos
		i += 1


func _on_theme_changed() -> void:
	ThemeManager.apply_grid_background($Background)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ── Ship Drawing (inner class) ───────────────────────────────

class _ShipDraw extends Node2D:
	var hull_color := Color(0.0, 0.9, 1.0)
	var accent_color := Color(1.0, 0.2, 0.6)
	var engine_color := Color(1.0, 0.5, 0.1)
	var canopy_color := Color(0.4, 0.2, 1.0)
	var detail_color := Color(0.0, 1.0, 0.7)
	var bank := 0.0

	func _bank_x(x: float, s: float, intensity: float) -> float:
		## Asymmetrically scale x based on bank. Points on the side you're
		## banking toward shrink (foreshorten), opposite side extends.
		var side_factor: float = signf(x) if x != 0.0 else 0.0
		var scale: float = 1.0 + bank * side_factor * intensity
		return x * scale * s

	func _bank_pt(x: float, y: float, s: float, intensity: float) -> Vector2:
		## Build a banked point: x gets asymmetric scaling + global shift,
		## y just scales normally.
		var x_shift: float = bank * 2.5 * s
		return Vector2(_bank_x(x, s, intensity) + x_shift, y * s)

	func _wing_color(side: float) -> Color:
		## Near wing (same side as bank direction) gets brighter,
		## far wing gets dimmer.
		var col := hull_color
		var boost: float = bank * side * 0.06
		col.a = clampf(col.a + boost, 0.5, 1.0)
		return col

	func _draw() -> void:
		var s := 1.4

		# ── Hull outline (cyan) ──
		var hull: PackedVector2Array = PackedVector2Array([
			_bank_pt(0, -45, s, 0.08),
			_bank_pt(8, -30, s, 0.08),
			_bank_pt(12, -10, s, 0.08),
			_bank_pt(10, 15, s, 0.08),
			_bank_pt(6, 30, s, 0.08),
			_bank_pt(-6, 30, s, 0.08),
			_bank_pt(-10, 15, s, 0.08),
			_bank_pt(-12, -10, s, 0.08),
			_bank_pt(-8, -30, s, 0.08),
		])
		_draw_neon_polygon(hull, hull_color, 2.0 * s)

		# ── Swept wings (cyan) ──
		# Top-down: dipping wing shifts up (recedes), rising wing shifts down (approaches)
		var r_wing_y_shift: float = -bank * 1.5 * s
		var l_wing_y_shift: float = bank * 1.5 * s

		var r_wing: PackedVector2Array = PackedVector2Array([
			_bank_pt(12, -5, s, 0.25) + Vector2(0, r_wing_y_shift),
			_bank_pt(40, 10, s, 0.25) + Vector2(0, r_wing_y_shift),
			_bank_pt(42, 15, s, 0.25) + Vector2(0, r_wing_y_shift),
			_bank_pt(38, 18, s, 0.25) + Vector2(0, r_wing_y_shift),
			_bank_pt(10, 15, s, 0.25) + Vector2(0, r_wing_y_shift),
		])
		_draw_neon_polygon(r_wing, _wing_color(1.0), 1.8 * s)

		var l_wing: PackedVector2Array = PackedVector2Array([
			_bank_pt(-12, -5, s, 0.25) + Vector2(0, l_wing_y_shift),
			_bank_pt(-40, 10, s, 0.25) + Vector2(0, l_wing_y_shift),
			_bank_pt(-42, 15, s, 0.25) + Vector2(0, l_wing_y_shift),
			_bank_pt(-38, 18, s, 0.25) + Vector2(0, l_wing_y_shift),
			_bank_pt(-10, 15, s, 0.25) + Vector2(0, l_wing_y_shift),
		])
		_draw_neon_polygon(l_wing, _wing_color(-1.0), 1.8 * s)

		# ── Wing tip fins ──
		var r_fin: PackedVector2Array = PackedVector2Array([
			_bank_pt(38, 12, s, 0.28) + Vector2(0, r_wing_y_shift),
			_bank_pt(44, 5, s, 0.28) + Vector2(0, r_wing_y_shift),
			_bank_pt(46, 8, s, 0.28) + Vector2(0, r_wing_y_shift),
			_bank_pt(42, 18, s, 0.28) + Vector2(0, r_wing_y_shift),
		])
		_draw_neon_polygon(r_fin, _wing_color(1.0), 1.5 * s)

		var l_fin: PackedVector2Array = PackedVector2Array([
			_bank_pt(-38, 12, s, 0.28) + Vector2(0, l_wing_y_shift),
			_bank_pt(-44, 5, s, 0.28) + Vector2(0, l_wing_y_shift),
			_bank_pt(-46, 8, s, 0.28) + Vector2(0, l_wing_y_shift),
			_bank_pt(-42, 18, s, 0.28) + Vector2(0, l_wing_y_shift),
		])
		_draw_neon_polygon(l_fin, _wing_color(-1.0), 1.5 * s)

		# ── Accent stripes (magenta) ──
		# Center spine
		draw_line(_bank_pt(0, -40, s, 0.08), _bank_pt(0, 25, s, 0.08), accent_color, 1.5 * s, true)
		# Wing accents
		draw_line(
			_bank_pt(14, -2, s, 0.25) + Vector2(0, r_wing_y_shift),
			_bank_pt(36, 12, s, 0.25) + Vector2(0, r_wing_y_shift),
			accent_color, 1.2 * s, true)
		draw_line(
			_bank_pt(-14, -2, s, 0.25) + Vector2(0, l_wing_y_shift),
			_bank_pt(-36, 12, s, 0.25) + Vector2(0, l_wing_y_shift),
			accent_color, 1.2 * s, true)
		# Hull side accents
		draw_line(_bank_pt(6, -25, s, 0.08), _bank_pt(8, 10, s, 0.08), accent_color, 1.0 * s, true)
		draw_line(_bank_pt(-6, -25, s, 0.08), _bank_pt(-8, 10, s, 0.08), accent_color, 1.0 * s, true)

		# ── Cockpit canopy (purple) ──
		# Canopy is on top — shifts opposite to bank (top-down perspective)
		var canopy_x_shift: float = -bank * 1.5 * s
		var canopy: PackedVector2Array = PackedVector2Array([
			_bank_pt(0, -38, s, 0.05) + Vector2(canopy_x_shift, 0),
			_bank_pt(5, -22, s, 0.05) + Vector2(canopy_x_shift, 0),
			_bank_pt(4, -12, s, 0.05) + Vector2(canopy_x_shift, 0),
			_bank_pt(-4, -12, s, 0.05) + Vector2(canopy_x_shift, 0),
			_bank_pt(-5, -22, s, 0.05) + Vector2(canopy_x_shift, 0),
		])
		var canopy_fill := canopy_color
		canopy_fill.a = 0.3
		draw_colored_polygon(canopy, canopy_fill)
		_draw_neon_lines(canopy, canopy_color, 1.2 * s)

		# ── Engine nacelles (orange) ──
		var r_engine: PackedVector2Array = PackedVector2Array([
			_bank_pt(14, 10, s, 0.15),
			_bank_pt(22, 12, s, 0.15),
			_bank_pt(23, 25, s, 0.15),
			_bank_pt(20, 32, s, 0.15),
			_bank_pt(15, 32, s, 0.15),
			_bank_pt(12, 25, s, 0.15),
		])
		_draw_neon_polygon(r_engine, engine_color, 1.5 * s)

		var l_engine: PackedVector2Array = PackedVector2Array([
			_bank_pt(-14, 10, s, 0.15),
			_bank_pt(-22, 12, s, 0.15),
			_bank_pt(-23, 25, s, 0.15),
			_bank_pt(-20, 32, s, 0.15),
			_bank_pt(-15, 32, s, 0.15),
			_bank_pt(-12, 25, s, 0.15),
		])
		_draw_neon_polygon(l_engine, engine_color, 1.5 * s)

		# Engine exhaust cores (bright)
		var exhaust_bright := Color(1.0, 0.8, 0.3, 0.8)
		draw_line(_bank_pt(17, 30, s, 0.15), _bank_pt(17, 35, s, 0.15), exhaust_bright, 3.0 * s, true)
		draw_line(_bank_pt(-17, 30, s, 0.15), _bank_pt(-17, 35, s, 0.15), exhaust_bright, 3.0 * s, true)

		# ── Detail lines (teal) ──
		draw_line(
			_bank_pt(20, 5, s, 0.25) + Vector2(0, r_wing_y_shift),
			_bank_pt(30, 11, s, 0.25) + Vector2(0, r_wing_y_shift),
			detail_color, 0.8 * s, true)
		draw_line(
			_bank_pt(-20, 5, s, 0.25) + Vector2(0, l_wing_y_shift),
			_bank_pt(-30, 11, s, 0.25) + Vector2(0, l_wing_y_shift),
			detail_color, 0.8 * s, true)
		draw_line(_bank_pt(-3, -42, s, 0.08), _bank_pt(3, -42, s, 0.08), detail_color, 0.8 * s, true)
		draw_line(_bank_pt(4, 28, s, 0.08), _bank_pt(-4, 28, s, 0.08), detail_color, 0.8 * s, true)


	func _draw_neon_polygon(points: PackedVector2Array, color: Color, width: float) -> void:
		var glow := color
		glow.a = 0.15
		draw_colored_polygon(points, glow)
		_draw_neon_lines(points, color, width)


	func _draw_neon_lines(points: PackedVector2Array, color: Color, width: float) -> void:
		if points.size() < 2:
			return
		# Outer glow
		var glow_color := color
		glow_color.a = 0.25
		for i in range(points.size()):
			var next_i: int = (i + 1) % points.size()
			draw_line(points[i], points[next_i], glow_color, width * 3.0, true)
		# Mid glow
		glow_color.a = 0.5
		for i in range(points.size()):
			var next_i: int = (i + 1) % points.size()
			draw_line(points[i], points[next_i], glow_color, width * 1.8, true)
		# Bright core
		for i in range(points.size()):
			var next_i: int = (i + 1) % points.size()
			draw_line(points[i], points[next_i], color, width, true)
		# White-hot center
		var white := Color(1, 1, 1, 0.6)
		for i in range(points.size()):
			var next_i: int = (i + 1) % points.size()
			draw_line(points[i], points[next_i], white, width * 0.4, true)


# ── Exhaust Drawing (inner class) ────────────────────────────

class _ExhaustDraw extends Node2D:
	var viewer: Control

	func _draw() -> void:
		if not viewer:
			return
		var particles: Array[Dictionary] = viewer._exhaust_particles
		for p in particles:
			var life: float = p["life"]
			var max_life: float = p["max_life"]
			var t: float = life / max_life
			var pos: Vector2 = p["pos"]
			var sz: float = p["size"]
			# Orange -> red -> dark, fading out
			var col := Color(1.0, 0.4 * t + 0.1, 0.05, t * 0.8)
			draw_circle(pos, sz * t, col)
			# Inner bright core
			var core := Color(1.0, 0.8, 0.3, t * 0.5)
			draw_circle(pos, sz * t * 0.4, core)
