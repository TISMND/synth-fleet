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
var _ship_selector: Node2D
var _selected_ship := 0
var _vhs_overlay: ColorRect


func _ready() -> void:
	ThemeManager.apply_grid_background($Background)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_exhaust_draw = _ExhaustDraw.new()
	_exhaust_draw.viewer = self
	add_child(_exhaust_draw)

	_ship_draw = _ShipDraw.new()
	add_child(_ship_draw)

	_ship_selector = _ShipSelector.new()
	_ship_selector.viewer = self
	add_child(_ship_selector)

	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.5)


func _process(delta: float) -> void:
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

	if input_dir != 0.0:
		_velocity = move_toward(_velocity, input_dir * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity = move_toward(_velocity, 0.0, MOVE_DECEL * delta)

	if input_dir_y != 0.0:
		_velocity_y = move_toward(_velocity_y, input_dir_y * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity_y = move_toward(_velocity_y, 0.0, MOVE_DECEL * delta)

	_ship_draw.position.x += _velocity * delta
	_ship_draw.position.y += _velocity_y * delta
	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position.x = clampf(_ship_draw.position.x, 60.0, vp_size.x - 60.0)
	_ship_draw.position.y = clampf(_ship_draw.position.y, 60.0, vp_size.y - 60.0)

	var target_bank: float = -_velocity / MAX_SPEED
	_bank = lerpf(_bank, target_bank, BANK_LERP * delta)
	_ship_draw.bank = _bank
	_ship_draw.ship_id = _selected_ship
	_ship_draw.queue_redraw()

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
	var engines: Array[Vector2] = _ShipDraw.get_engine_offsets(_selected_ship)
	for eng in engines:
		var ex: float = eng.x
		var ey: float = eng.y
		var side_factor: float = signf(ex) if ex != 0.0 else 0.0
		var banked_x: float = ex * (1.0 + _bank * side_factor * 0.15) * s + x_shift
		var local_pos := Vector2(banked_x, ey * s)
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


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_grid_background($Background)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var vp_size: Vector2 = get_viewport_rect().size
			var bar_y: float = vp_size.y - _ShipSelector.BAR_HEIGHT
			if mb.position.y >= bar_y:
				var slot: int = _ship_selector.get_slot_at(mb.position.x, vp_size.x)
				if slot >= 0 and slot < _ShipSelector.SHIP_COUNT:
					_selected_ship = slot
					_exhaust_particles.clear()
					_ship_selector.queue_redraw()


# ── Ship Drawing (inner class) ───────────────────────────────

class _ShipDraw extends Node2D:
	var hull_color := Color(0.0, 0.9, 1.0)
	var accent_color := Color(1.0, 0.2, 0.6)
	var engine_color := Color(1.0, 0.5, 0.1)
	var canopy_color := Color(0.4, 0.2, 1.0)
	var detail_color := Color(0.0, 1.0, 0.7)
	var bank := 0.0
	var ship_id := 0

	func _bx(x: float, s: float, intensity: float) -> float:
		var sf: float = signf(x) if x != 0.0 else 0.0
		return x * (1.0 + bank * sf * intensity) * s

	func _bp(x: float, y: float, s: float, intensity: float) -> Vector2:
		return Vector2(_bx(x, s, intensity) + bank * 2.5 * s, y * s)

	func _side_color(base: Color, side: float) -> Color:
		var col := base
		col.a = clampf(col.a + bank * side * 0.06, 0.5, 1.0)
		return col

	static func get_engine_offsets(id: int) -> Array[Vector2]:
		match id:
			0: return [Vector2(-8.0, 30.0), Vector2(0.0, 30.0), Vector2(8.0, 30.0)]
			1: return [Vector2(0.0, 32.0)]
			2: return [Vector2(-8.0, 20.0), Vector2(8.0, 20.0)]
			3: return [Vector2(-14.0, 34.0), Vector2(-6.0, 34.0), Vector2(6.0, 34.0), Vector2(14.0, 34.0)]
			4: return [Vector2(-4.0, 24.0), Vector2(4.0, 24.0)]
			5: return [Vector2(-13.0, 28.0), Vector2(0.0, 28.0), Vector2(13.0, 28.0)]
		return [Vector2(0.0, 30.0)]

	func _draw() -> void:
		match ship_id:
			0: _draw_hammerhead()
			1: _draw_needle()
			2: _draw_mantis()
			3: _draw_bulwark()
			4: _draw_stiletto()
			5: _draw_trident()

	# ── Ship 0: Hammerhead — wide hulking gunship ──
	func _draw_hammerhead() -> void:
		var s := 1.4
		var ry: float = -bank * 1.5 * s
		var ly: float = bank * 1.5 * s

		# Wide flat hull
		var hull := PackedVector2Array([
			_bp(0, -30, s, 0.08), _bp(14, -22, s, 0.08),
			_bp(18, -5, s, 0.08), _bp(16, 20, s, 0.08),
			_bp(10, 28, s, 0.08), _bp(-10, 28, s, 0.08),
			_bp(-16, 20, s, 0.08), _bp(-18, -5, s, 0.08),
			_bp(-14, -22, s, 0.08),
		])
		_draw_neon_polygon(hull, hull_color, 2.0 * s)

		# Right weapon pod
		var rp := PackedVector2Array([
			_bp(18, -8, s, 0.2) + Vector2(0, ry),
			_bp(28, -4, s, 0.2) + Vector2(0, ry),
			_bp(30, 8, s, 0.2) + Vector2(0, ry),
			_bp(26, 14, s, 0.2) + Vector2(0, ry),
			_bp(18, 10, s, 0.2) + Vector2(0, ry),
		])
		_draw_neon_polygon(rp, _side_color(hull_color, 1.0), 1.5 * s)
		# Left weapon pod
		var lp := PackedVector2Array([
			_bp(-18, -8, s, 0.2) + Vector2(0, ly),
			_bp(-28, -4, s, 0.2) + Vector2(0, ly),
			_bp(-30, 8, s, 0.2) + Vector2(0, ly),
			_bp(-26, 14, s, 0.2) + Vector2(0, ly),
			_bp(-18, 10, s, 0.2) + Vector2(0, ly),
		])
		_draw_neon_polygon(lp, _side_color(hull_color, -1.0), 1.5 * s)

		# Gun barrels
		_draw_neon_line(_bp(24, -4, s, 0.2) + Vector2(0, ry), _bp(24, -14, s, 0.2) + Vector2(0, ry), accent_color, 1.2 * s)
		_draw_neon_line(_bp(-24, -4, s, 0.2) + Vector2(0, ly), _bp(-24, -14, s, 0.2) + Vector2(0, ly), accent_color, 1.2 * s)

		# Wide visor canopy
		var cx: float = -bank * 1.5 * s
		var can := PackedVector2Array([
			_bp(-8, -18, s, 0.05) + Vector2(cx, 0),
			_bp(8, -18, s, 0.05) + Vector2(cx, 0),
			_bp(6, -10, s, 0.05) + Vector2(cx, 0),
			_bp(-6, -10, s, 0.05) + Vector2(cx, 0),
		])
		var cf := canopy_color
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_draw_neon_lines(can, canopy_color, 1.2 * s)

		# Armor plate detail lines
		_draw_neon_line(_bp(-14, -2, s, 0.08), _bp(14, -2, s, 0.08), detail_color, 0.8 * s)
		_draw_neon_line(_bp(-14, 12, s, 0.08), _bp(14, 12, s, 0.08), detail_color, 0.8 * s)

		# Triple engines
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		_draw_neon_line(_bp(-8, 26, s, 0.12), _bp(-8, 33, s, 0.12), exhaust, 3.0 * s)
		_draw_neon_line(_bp(0, 26, s, 0.12), _bp(0, 33, s, 0.12), exhaust, 3.0 * s)
		_draw_neon_line(_bp(8, 26, s, 0.12), _bp(8, 33, s, 0.12), exhaust, 3.0 * s)

	# ── Ship 1: Needle — sleek wingless dart ──
	func _draw_needle() -> void:
		var s := 1.4

		# Long thin body
		var hull := PackedVector2Array([
			_bp(0, -42, s, 0.08), _bp(4, -28, s, 0.08),
			_bp(7, -8, s, 0.08), _bp(7, 18, s, 0.08),
			_bp(5, 30, s, 0.08), _bp(-5, 30, s, 0.08),
			_bp(-7, 18, s, 0.08), _bp(-7, -8, s, 0.08),
			_bp(-4, -28, s, 0.08),
		])
		_draw_neon_polygon(hull, hull_color, 2.0 * s)

		# Right rear stabilizer fin
		var ry: float = -bank * 1.0 * s
		var ly: float = bank * 1.0 * s
		var rf := PackedVector2Array([
			_bp(7, 18, s, 0.2) + Vector2(0, ry),
			_bp(16, 24, s, 0.2) + Vector2(0, ry),
			_bp(14, 30, s, 0.2) + Vector2(0, ry),
			_bp(7, 26, s, 0.2) + Vector2(0, ry),
		])
		_draw_neon_polygon(rf, _side_color(detail_color, 1.0), 1.5 * s)
		# Left rear stabilizer fin
		var lf := PackedVector2Array([
			_bp(-7, 18, s, 0.2) + Vector2(0, ly),
			_bp(-16, 24, s, 0.2) + Vector2(0, ly),
			_bp(-14, 30, s, 0.2) + Vector2(0, ly),
			_bp(-7, 26, s, 0.2) + Vector2(0, ly),
		])
		_draw_neon_polygon(lf, _side_color(detail_color, -1.0), 1.5 * s)

		# Spine accent
		_draw_neon_line(_bp(0, -38, s, 0.08), _bp(0, 28, s, 0.08), accent_color, 1.2 * s)

		# Long narrow canopy
		var cx: float = -bank * 1.5 * s
		var can := PackedVector2Array([
			_bp(0, -36, s, 0.05) + Vector2(cx, 0),
			_bp(3, -20, s, 0.05) + Vector2(cx, 0),
			_bp(2, -8, s, 0.05) + Vector2(cx, 0),
			_bp(-2, -8, s, 0.05) + Vector2(cx, 0),
			_bp(-3, -20, s, 0.05) + Vector2(cx, 0),
		])
		var cf := canopy_color
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_draw_neon_lines(can, canopy_color, 1.2 * s)

		# Side detail lines
		_draw_neon_line(_bp(5, -20, s, 0.08), _bp(6, 10, s, 0.08), detail_color, 0.8 * s)
		_draw_neon_line(_bp(-5, -20, s, 0.08), _bp(-6, 10, s, 0.08), detail_color, 0.8 * s)

		# Single large engine
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		_draw_neon_line(_bp(0, 28, s, 0.08), _bp(0, 38, s, 0.08), exhaust, 4.0 * s)

	# ── Ship 2: Mantis — flying wing ──
	func _draw_mantis() -> void:
		var s := 1.4
		var ry: float = -bank * 1.5 * s
		var ly: float = bank * 1.5 * s

		# Right half of chevron wing
		var r_wing := PackedVector2Array([
			_bp(0, -28, s, 0.08),
			_bp(10, -14, s, 0.25) + Vector2(0, ry),
			_bp(44, 8, s, 0.25) + Vector2(0, ry),
			_bp(40, 14, s, 0.25) + Vector2(0, ry),
			_bp(14, 10, s, 0.2) + Vector2(0, ry * 0.5),
			_bp(8, 18, s, 0.08),
			_bp(0, 18, s, 0.08),
		])
		_draw_neon_polygon(r_wing, _side_color(hull_color, 1.0), 1.8 * s)

		# Left half of chevron wing
		var l_wing := PackedVector2Array([
			_bp(0, -28, s, 0.08),
			_bp(-10, -14, s, 0.25) + Vector2(0, ly),
			_bp(-44, 8, s, 0.25) + Vector2(0, ly),
			_bp(-40, 14, s, 0.25) + Vector2(0, ly),
			_bp(-14, 10, s, 0.2) + Vector2(0, ly * 0.5),
			_bp(-8, 18, s, 0.08),
			_bp(0, 18, s, 0.08),
		])
		_draw_neon_polygon(l_wing, _side_color(hull_color, -1.0), 1.8 * s)

		# Center spine accent
		_draw_neon_line(_bp(0, -24, s, 0.08), _bp(0, 14, s, 0.08), accent_color, 1.5 * s)

		# Wing edge accents
		_draw_neon_line(
			_bp(12, -10, s, 0.25) + Vector2(0, ry),
			_bp(38, 8, s, 0.25) + Vector2(0, ry),
			detail_color, 0.8 * s)
		_draw_neon_line(
			_bp(-12, -10, s, 0.25) + Vector2(0, ly),
			_bp(-38, 8, s, 0.25) + Vector2(0, ly),
			detail_color, 0.8 * s)

		# Small bubble canopy
		var cx: float = -bank * 1.0 * s
		var can := PackedVector2Array([
			_bp(0, -20, s, 0.05) + Vector2(cx, 0),
			_bp(4, -10, s, 0.05) + Vector2(cx, 0),
			_bp(-4, -10, s, 0.05) + Vector2(cx, 0),
		])
		var cf := canopy_color
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_draw_neon_lines(can, canopy_color, 1.2 * s)

		# Two buried engines
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		_draw_neon_line(_bp(8, 16, s, 0.1), _bp(8, 24, s, 0.1), exhaust, 2.5 * s)
		_draw_neon_line(_bp(-8, 16, s, 0.1), _bp(-8, 24, s, 0.1), exhaust, 2.5 * s)

	# ── Ship 3: Bulwark — heavy armored carrier ──
	func _draw_bulwark() -> void:
		var s := 1.4

		# Big blocky hull
		var hull := PackedVector2Array([
			_bp(-5, -38, s, 0.06), _bp(5, -38, s, 0.06),
			_bp(18, -28, s, 0.06), _bp(22, -12, s, 0.06),
			_bp(22, 24, s, 0.06), _bp(18, 34, s, 0.06),
			_bp(-18, 34, s, 0.06), _bp(-22, 24, s, 0.06),
			_bp(-22, -12, s, 0.06), _bp(-18, -28, s, 0.06),
		])
		_draw_neon_polygon(hull, hull_color, 2.0 * s)

		# Armor plate lines
		_draw_neon_line(_bp(-20, -8, s, 0.06), _bp(20, -8, s, 0.06), detail_color, 0.8 * s)
		_draw_neon_line(_bp(-20, 8, s, 0.06), _bp(20, 8, s, 0.06), detail_color, 0.8 * s)
		_draw_neon_line(_bp(-18, 22, s, 0.06), _bp(18, 22, s, 0.06), detail_color, 0.8 * s)

		# Side turret bumps
		var ry: float = -bank * 1.0 * s
		var ly: float = bank * 1.0 * s
		_draw_neon_line(_bp(22, -2, s, 0.12) + Vector2(0, ry), _bp(28, -2, s, 0.12) + Vector2(0, ry), accent_color, 1.5 * s)
		_draw_neon_line(_bp(22, 4, s, 0.12) + Vector2(0, ry), _bp(28, 4, s, 0.12) + Vector2(0, ry), accent_color, 1.5 * s)
		_draw_neon_line(_bp(-22, -2, s, 0.12) + Vector2(0, ly), _bp(-28, -2, s, 0.12) + Vector2(0, ly), accent_color, 1.5 * s)
		_draw_neon_line(_bp(-22, 4, s, 0.12) + Vector2(0, ly), _bp(-28, 4, s, 0.12) + Vector2(0, ly), accent_color, 1.5 * s)

		# Bridge canopy — wide rectangular
		var cx: float = -bank * 1.5 * s
		var can := PackedVector2Array([
			_bp(-8, -32, s, 0.04) + Vector2(cx, 0),
			_bp(8, -32, s, 0.04) + Vector2(cx, 0),
			_bp(10, -20, s, 0.04) + Vector2(cx, 0),
			_bp(-10, -20, s, 0.04) + Vector2(cx, 0),
		])
		var cf := canopy_color
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_draw_neon_lines(can, canopy_color, 1.2 * s)

		# Spine accent
		_draw_neon_line(_bp(0, -18, s, 0.06), _bp(0, 30, s, 0.06), accent_color, 1.0 * s)

		# Four engines
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		_draw_neon_line(_bp(-14, 32, s, 0.1), _bp(-14, 40, s, 0.1), exhaust, 2.5 * s)
		_draw_neon_line(_bp(-6, 32, s, 0.1), _bp(-6, 40, s, 0.1), exhaust, 2.5 * s)
		_draw_neon_line(_bp(6, 32, s, 0.1), _bp(6, 40, s, 0.1), exhaust, 2.5 * s)
		_draw_neon_line(_bp(14, 32, s, 0.1), _bp(14, 40, s, 0.1), exhaust, 2.5 * s)

	# ── Ship 4: Stiletto — angular stealth ──
	func _draw_stiletto() -> void:
		var s := 1.4

		# Diamond faceted body
		var hull := PackedVector2Array([
			_bp(0, -35, s, 0.1),
			_bp(14, -12, s, 0.15),
			_bp(28, 4, s, 0.2),
			_bp(22, 14, s, 0.18),
			_bp(10, 24, s, 0.1),
			_bp(-10, 24, s, 0.1),
			_bp(-22, 14, s, 0.18),
			_bp(-28, 4, s, 0.2),
			_bp(-14, -12, s, 0.15),
		])
		_draw_neon_polygon(hull, hull_color, 2.0 * s)

		# Facet edge lines
		_draw_neon_line(_bp(0, -32, s, 0.1), _bp(14, -12, s, 0.15), detail_color, 0.8 * s)
		_draw_neon_line(_bp(0, -32, s, 0.1), _bp(-14, -12, s, 0.15), detail_color, 0.8 * s)
		_draw_neon_line(_bp(14, -12, s, 0.15), _bp(10, 24, s, 0.1), detail_color, 0.8 * s)
		_draw_neon_line(_bp(-14, -12, s, 0.15), _bp(-10, 24, s, 0.1), detail_color, 0.8 * s)
		# Cross facet
		_draw_neon_line(_bp(-14, -12, s, 0.15), _bp(14, -12, s, 0.15), detail_color, 0.6 * s)

		# Angular canopy slit
		var cx: float = -bank * 1.2 * s
		var can := PackedVector2Array([
			_bp(0, -28, s, 0.05) + Vector2(cx, 0),
			_bp(7, -14, s, 0.05) + Vector2(cx, 0),
			_bp(5, -6, s, 0.05) + Vector2(cx, 0),
			_bp(-5, -6, s, 0.05) + Vector2(cx, 0),
			_bp(-7, -14, s, 0.05) + Vector2(cx, 0),
		])
		var cf := canopy_color
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_draw_neon_lines(can, canopy_color, 1.2 * s)

		# Spine
		_draw_neon_line(_bp(0, -6, s, 0.1), _bp(0, 20, s, 0.1), accent_color, 1.2 * s)

		# Twin tight engines
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		_draw_neon_line(_bp(-4, 22, s, 0.08), _bp(-4, 30, s, 0.08), exhaust, 3.0 * s)
		_draw_neon_line(_bp(4, 22, s, 0.08), _bp(4, 30, s, 0.08), exhaust, 3.0 * s)

	# ── Ship 5: Trident — triple-engine racer ──
	func _draw_trident() -> void:
		var s := 1.4
		var ry: float = -bank * 1.2 * s
		var ly: float = bank * 1.2 * s

		# Slim fuselage
		var hull := PackedVector2Array([
			_bp(0, -40, s, 0.08), _bp(6, -24, s, 0.08),
			_bp(8, -6, s, 0.08), _bp(9, 16, s, 0.08),
			_bp(7, 28, s, 0.08), _bp(-7, 28, s, 0.08),
			_bp(-9, 16, s, 0.08), _bp(-8, -6, s, 0.08),
			_bp(-6, -24, s, 0.08),
		])
		_draw_neon_polygon(hull, hull_color, 2.0 * s)

		# Right canard
		var rc := PackedVector2Array([
			_bp(6, -18, s, 0.2) + Vector2(0, ry * 0.5),
			_bp(18, -14, s, 0.2) + Vector2(0, ry),
			_bp(16, -8, s, 0.2) + Vector2(0, ry),
			_bp(6, -12, s, 0.2) + Vector2(0, ry * 0.5),
		])
		_draw_neon_polygon(rc, _side_color(detail_color, 1.0), 1.2 * s)
		# Left canard
		var lc := PackedVector2Array([
			_bp(-6, -18, s, 0.2) + Vector2(0, ly * 0.5),
			_bp(-18, -14, s, 0.2) + Vector2(0, ly),
			_bp(-16, -8, s, 0.2) + Vector2(0, ly),
			_bp(-6, -12, s, 0.2) + Vector2(0, ly * 0.5),
		])
		_draw_neon_polygon(lc, _side_color(detail_color, -1.0), 1.2 * s)

		# Right engine nacelle
		var re := PackedVector2Array([
			_bp(9, 12, s, 0.18) + Vector2(0, ry * 0.3),
			_bp(16, 14, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(18, 28, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(14, 30, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(9, 24, s, 0.18) + Vector2(0, ry * 0.3),
		])
		_draw_neon_polygon(re, _side_color(hull_color, 1.0), 1.5 * s)
		# Left engine nacelle
		var le := PackedVector2Array([
			_bp(-9, 12, s, 0.18) + Vector2(0, ly * 0.3),
			_bp(-16, 14, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-18, 28, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-14, 30, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-9, 24, s, 0.18) + Vector2(0, ly * 0.3),
		])
		_draw_neon_polygon(le, _side_color(hull_color, -1.0), 1.5 * s)

		# Canopy
		var cx: float = -bank * 1.0 * s
		var can := PackedVector2Array([
			_bp(0, -34, s, 0.05) + Vector2(cx, 0),
			_bp(4, -20, s, 0.05) + Vector2(cx, 0),
			_bp(-4, -20, s, 0.05) + Vector2(cx, 0),
		])
		var cf := canopy_color
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_draw_neon_lines(can, canopy_color, 1.2 * s)

		# Spine
		_draw_neon_line(_bp(0, -20, s, 0.08), _bp(0, 24, s, 0.08), accent_color, 1.0 * s)

		# Three engine exhausts
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		_draw_neon_line(_bp(0, 26, s, 0.08), _bp(0, 34, s, 0.08), exhaust, 3.0 * s)
		_draw_neon_line(
			_bp(15, 28, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(15, 35, s, 0.18) + Vector2(0, ry * 0.5),
			exhaust, 2.5 * s)
		_draw_neon_line(
			_bp(-15, 28, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-15, 35, s, 0.18) + Vector2(0, ly * 0.5),
			exhaust, 2.5 * s)

	# ── Neon drawing helpers ──

	func _draw_neon_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		var gc := color
		gc.a = 0.25
		draw_line(a, b, gc, width * 3.0, true)
		draw_circle(a, width * 1.5, gc)
		draw_circle(b, width * 1.5, gc)
		gc.a = 0.5
		draw_line(a, b, gc, width * 1.8, true)
		draw_circle(a, width * 0.9, gc)
		draw_circle(b, width * 0.9, gc)
		draw_line(a, b, color, width, true)
		draw_circle(a, width * 0.5, color)
		draw_circle(b, width * 0.5, color)
		var w := Color(1, 1, 1, 0.6)
		draw_line(a, b, w, width * 0.4, true)
		draw_circle(a, width * 0.2, w)
		draw_circle(b, width * 0.2, w)

	func _draw_neon_polygon(points: PackedVector2Array, color: Color, width: float) -> void:
		var glow := color
		glow.a = 0.15
		draw_colored_polygon(points, glow)
		_draw_neon_lines(points, color, width)

	func _draw_neon_lines(points: PackedVector2Array, color: Color, width: float) -> void:
		if points.size() < 2:
			return
		var gc := color
		# Outer glow
		gc.a = 0.25
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], gc, width * 3.0, true)
		for pt in points:
			draw_circle(pt, width * 1.5, gc)
		# Mid glow
		gc.a = 0.5
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], gc, width * 1.8, true)
		for pt in points:
			draw_circle(pt, width * 0.9, gc)
		# Bright core
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], color, width, true)
		for pt in points:
			draw_circle(pt, width * 0.5, color)
		# White-hot center
		var white := Color(1, 1, 1, 0.6)
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], white, width * 0.4, true)
		for pt in points:
			draw_circle(pt, width * 0.2, white)


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
			var col := Color(1.0, 0.4 * t + 0.1, 0.05, t * 0.8)
			draw_circle(pos, sz * t, col)
			var core := Color(1.0, 0.8, 0.3, t * 0.5)
			draw_circle(pos, sz * t * 0.4, core)


# ── Ship Selector Bar (inner class) ─────────────────────────

class _ShipSelector extends Node2D:
	const BAR_HEIGHT := 110.0
	const SLOT_WIDTH := 100.0
	const SHIP_COUNT := 6

	var viewer: Control

	var cyan := Color(0.0, 0.9, 1.0)
	var magenta := Color(1.0, 0.2, 0.6)
	var orange := Color(1.0, 0.5, 0.1)
	var purple := Color(0.4, 0.2, 1.0)
	var teal := Color(0.0, 1.0, 0.7)

	func get_slot_at(mouse_x: float, vp_w: float) -> int:
		var total_w: float = SLOT_WIDTH * SHIP_COUNT
		var start_x: float = (vp_w - total_w) * 0.5
		if mouse_x < start_x or mouse_x > start_x + total_w:
			return -1
		return int((mouse_x - start_x) / SLOT_WIDTH)

	func _draw() -> void:
		if not viewer:
			return
		var vp_size: Vector2 = viewer.get_viewport_rect().size
		var bar_y: float = vp_size.y - BAR_HEIGHT

		var bg := Color(0.0, 0.0, 0.05, 0.85)
		draw_rect(Rect2(0, bar_y, vp_size.x, BAR_HEIGHT), bg)
		draw_line(Vector2(0, bar_y), Vector2(vp_size.x, bar_y), cyan * Color(1, 1, 1, 0.3), 1.0)

		var total_w: float = SLOT_WIDTH * SHIP_COUNT
		var start_x: float = (vp_size.x - total_w) * 0.5
		var center_y: float = bar_y + 48.0

		for i in range(SHIP_COUNT):
			var cx: float = start_x + SLOT_WIDTH * i + SLOT_WIDTH * 0.5
			var selected: bool = (i == viewer._selected_ship)

			if selected:
				var hl := cyan
				hl.a = 0.12
				draw_rect(Rect2(cx - SLOT_WIDTH * 0.5 + 2, bar_y + 2, SLOT_WIDTH - 4, BAR_HEIGHT - 4), hl)
				draw_rect(Rect2(cx - SLOT_WIDTH * 0.5 + 2, bar_y + 2, SLOT_WIDTH - 4, BAR_HEIGHT - 4), Color(cyan.r, cyan.g, cyan.b, 0.4), false, 1.0)

			var origin := Vector2(cx, center_y)
			match i:
				0: _draw_hammerhead(origin)
				1: _draw_needle(origin)
				2: _draw_mantis(origin)
				3: _draw_bulwark(origin)
				4: _draw_stiletto(origin)
				5: _draw_trident(origin)

			var label_pos := Vector2(cx - 3, bar_y + BAR_HEIGHT - 10)
			var label_col: Color = cyan if selected else Color(0.5, 0.5, 0.6)
			_draw_number(label_pos, i + 1, label_col)

	func _mp(points: PackedVector2Array, color: Color, w: float) -> void:
		var fill := color
		fill.a = 0.12
		draw_colored_polygon(points, fill)
		var gc := color
		gc.a = 0.3
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			draw_line(points[j], points[nj], gc, w * 2.0, true)
		for pt in points:
			draw_circle(pt, w, gc)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			draw_line(points[j], points[nj], color, w, true)
		for pt in points:
			draw_circle(pt, w * 0.5, color)

	func _ml(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		var gc := color
		gc.a = 0.3
		draw_line(a, b, gc, w * 2.0, true)
		draw_circle(a, w, gc)
		draw_circle(b, w, gc)
		draw_line(a, b, color, w, true)
		draw_circle(a, w * 0.5, color)
		draw_circle(b, w * 0.5, color)

	func _draw_number(pos: Vector2, num: int, color: Color) -> void:
		var sw := 3.0
		var h := 4.0
		var p: Vector2 = pos
		var segs: Array[bool] = []
		match num:
			1: segs = [false, true, true, false, false, false, false]
			2: segs = [true, true, false, true, true, false, true]
			3: segs = [true, true, true, true, false, false, true]
			4: segs = [false, true, true, false, false, true, true]
			5: segs = [true, false, true, true, false, true, true]
			6: segs = [true, false, true, true, true, true, true]
		if segs.size() < 7:
			return
		if segs[0]: draw_line(p + Vector2(-sw, -h), p + Vector2(sw, -h), color, 1.0, true)
		if segs[1]: draw_line(p + Vector2(sw, -h), p + Vector2(sw, 0), color, 1.0, true)
		if segs[2]: draw_line(p + Vector2(sw, 0), p + Vector2(sw, h), color, 1.0, true)
		if segs[3]: draw_line(p + Vector2(sw, h), p + Vector2(-sw, h), color, 1.0, true)
		if segs[4]: draw_line(p + Vector2(-sw, h), p + Vector2(-sw, 0), color, 1.0, true)
		if segs[5]: draw_line(p + Vector2(-sw, 0), p + Vector2(-sw, -h), color, 1.0, true)
		if segs[6]: draw_line(p + Vector2(-sw, 0), p + Vector2(sw, 0), color, 1.0, true)

	# ── Mini ship thumbnails ──

	func _draw_hammerhead(o: Vector2) -> void:
		var s := 0.45
		var hull := PackedVector2Array([
			o + Vector2(0, -30) * s, o + Vector2(14, -22) * s,
			o + Vector2(18, -5) * s, o + Vector2(16, 20) * s,
			o + Vector2(10, 28) * s, o + Vector2(-10, 28) * s,
			o + Vector2(-16, 20) * s, o + Vector2(-18, -5) * s,
			o + Vector2(-14, -22) * s,
		])
		_mp(hull, cyan, 1.0)
		var rp := PackedVector2Array([
			o + Vector2(18, -8) * s, o + Vector2(28, -4) * s,
			o + Vector2(30, 8) * s, o + Vector2(26, 14) * s,
			o + Vector2(18, 10) * s,
		])
		_mp(rp, cyan, 0.8)
		var lp := PackedVector2Array([
			o + Vector2(-18, -8) * s, o + Vector2(-28, -4) * s,
			o + Vector2(-30, 8) * s, o + Vector2(-26, 14) * s,
			o + Vector2(-18, 10) * s,
		])
		_mp(lp, cyan, 0.8)
		_ml(o + Vector2(24, -4) * s, o + Vector2(24, -12) * s, magenta, 1.0)
		_ml(o + Vector2(-24, -4) * s, o + Vector2(-24, -12) * s, magenta, 1.0)
		var can := PackedVector2Array([
			o + Vector2(-8, -18) * s, o + Vector2(8, -18) * s,
			o + Vector2(6, -10) * s, o + Vector2(-6, -10) * s,
		])
		var cf := purple
		cf.a = 0.25
		draw_colored_polygon(can, cf)
		_ml(o + Vector2(-8, 26) * s, o + Vector2(-8, 33) * s, orange, 1.5)
		_ml(o + Vector2(0, 26) * s, o + Vector2(0, 33) * s, orange, 1.5)
		_ml(o + Vector2(8, 26) * s, o + Vector2(8, 33) * s, orange, 1.5)

	func _draw_needle(o: Vector2) -> void:
		var s := 0.5
		var hull := PackedVector2Array([
			o + Vector2(0, -38) * s, o + Vector2(4, -25) * s,
			o + Vector2(6, -5) * s, o + Vector2(6, 20) * s,
			o + Vector2(4, 30) * s, o + Vector2(-4, 30) * s,
			o + Vector2(-6, 20) * s, o + Vector2(-6, -5) * s,
			o + Vector2(-4, -25) * s,
		])
		_mp(hull, cyan, 1.0)
		var rf := PackedVector2Array([
			o + Vector2(6, 18) * s, o + Vector2(14, 24) * s,
			o + Vector2(12, 28) * s, o + Vector2(6, 25) * s,
		])
		_mp(rf, teal, 0.8)
		var lf := PackedVector2Array([
			o + Vector2(-6, 18) * s, o + Vector2(-14, 24) * s,
			o + Vector2(-12, 28) * s, o + Vector2(-6, 25) * s,
		])
		_mp(lf, teal, 0.8)
		_ml(o + Vector2(0, -34) * s, o + Vector2(0, 28) * s, magenta, 0.8)
		var can := PackedVector2Array([
			o + Vector2(0, -32) * s, o + Vector2(3, -18) * s,
			o + Vector2(2, -8) * s, o + Vector2(-2, -8) * s, o + Vector2(-3, -18) * s,
		])
		var cf := purple
		cf.a = 0.25
		draw_colored_polygon(can, cf)
		_ml(o + Vector2(0, 28) * s, o + Vector2(0, 36) * s, orange, 2.5)

	func _draw_mantis(o: Vector2) -> void:
		var s := 0.42
		var wing := PackedVector2Array([
			o + Vector2(0, -25) * s, o + Vector2(10, -12) * s,
			o + Vector2(42, 8) * s, o + Vector2(38, 14) * s,
			o + Vector2(14, 10) * s, o + Vector2(8, 18) * s,
			o + Vector2(-8, 18) * s, o + Vector2(-14, 10) * s,
			o + Vector2(-38, 14) * s, o + Vector2(-42, 8) * s,
			o + Vector2(-10, -12) * s,
		])
		_mp(wing, cyan, 1.0)
		_ml(o + Vector2(0, -20) * s, o + Vector2(0, 14) * s, magenta, 0.8)
		var can := PackedVector2Array([
			o + Vector2(0, -18) * s, o + Vector2(4, -8) * s,
			o + Vector2(-4, -8) * s,
		])
		var cf := purple
		cf.a = 0.3
		draw_colored_polygon(can, cf)
		_ml(o + Vector2(8, 16) * s, o + Vector2(8, 22) * s, orange, 1.2)
		_ml(o + Vector2(-8, 16) * s, o + Vector2(-8, 22) * s, orange, 1.2)
		_ml(o + Vector2(12, -8) * s, o + Vector2(36, 8) * s, teal, 0.6)
		_ml(o + Vector2(-12, -8) * s, o + Vector2(-36, 8) * s, teal, 0.6)

	func _draw_bulwark(o: Vector2) -> void:
		var s := 0.4
		var hull := PackedVector2Array([
			o + Vector2(-4, -35) * s, o + Vector2(4, -35) * s,
			o + Vector2(16, -25) * s, o + Vector2(20, -10) * s,
			o + Vector2(20, 22) * s, o + Vector2(16, 32) * s,
			o + Vector2(-16, 32) * s, o + Vector2(-20, 22) * s,
			o + Vector2(-20, -10) * s, o + Vector2(-16, -25) * s,
		])
		_mp(hull, cyan, 1.0)
		_ml(o + Vector2(-18, -5) * s, o + Vector2(18, -5) * s, teal, 0.6)
		_ml(o + Vector2(-18, 10) * s, o + Vector2(18, 10) * s, teal, 0.6)
		_ml(o + Vector2(-16, 22) * s, o + Vector2(16, 22) * s, teal, 0.6)
		var can := PackedVector2Array([
			o + Vector2(-6, -28) * s, o + Vector2(6, -28) * s,
			o + Vector2(8, -18) * s, o + Vector2(-8, -18) * s,
		])
		var cf := purple
		cf.a = 0.25
		draw_colored_polygon(can, cf)
		_ml(o + Vector2(-14, 30) * s, o + Vector2(-14, 38) * s, orange, 1.3)
		_ml(o + Vector2(-6, 30) * s, o + Vector2(-6, 38) * s, orange, 1.3)
		_ml(o + Vector2(6, 30) * s, o + Vector2(6, 38) * s, orange, 1.3)
		_ml(o + Vector2(14, 30) * s, o + Vector2(14, 38) * s, orange, 1.3)
		_ml(o + Vector2(20, 0) * s, o + Vector2(26, 0) * s, magenta, 1.0)
		_ml(o + Vector2(-20, 0) * s, o + Vector2(-26, 0) * s, magenta, 1.0)

	func _draw_stiletto(o: Vector2) -> void:
		var s := 0.5
		var hull := PackedVector2Array([
			o + Vector2(0, -32) * s, o + Vector2(12, -10) * s,
			o + Vector2(26, 4) * s, o + Vector2(20, 12) * s,
			o + Vector2(8, 22) * s, o + Vector2(-8, 22) * s,
			o + Vector2(-20, 12) * s, o + Vector2(-26, 4) * s,
			o + Vector2(-12, -10) * s,
		])
		_mp(hull, cyan, 1.0)
		_ml(o + Vector2(0, -28) * s, o + Vector2(12, -10) * s, teal, 0.6)
		_ml(o + Vector2(0, -28) * s, o + Vector2(-12, -10) * s, teal, 0.6)
		_ml(o + Vector2(12, -10) * s, o + Vector2(8, 22) * s, teal, 0.6)
		_ml(o + Vector2(-12, -10) * s, o + Vector2(-8, 22) * s, teal, 0.6)
		var can := PackedVector2Array([
			o + Vector2(0, -24) * s, o + Vector2(6, -12) * s,
			o + Vector2(4, -6) * s, o + Vector2(-4, -6) * s, o + Vector2(-6, -12) * s,
		])
		var cf := purple
		cf.a = 0.25
		draw_colored_polygon(can, cf)
		_ml(o + Vector2(0, -6) * s, o + Vector2(0, 18) * s, magenta, 0.8)
		_ml(o + Vector2(-4, 20) * s, o + Vector2(-4, 27) * s, orange, 1.5)
		_ml(o + Vector2(4, 20) * s, o + Vector2(4, 27) * s, orange, 1.5)

	func _draw_trident(o: Vector2) -> void:
		var s := 0.48
		var hull := PackedVector2Array([
			o + Vector2(0, -36) * s, o + Vector2(5, -22) * s,
			o + Vector2(7, -5) * s, o + Vector2(8, 15) * s,
			o + Vector2(6, 26) * s, o + Vector2(-6, 26) * s,
			o + Vector2(-8, 15) * s, o + Vector2(-7, -5) * s,
			o + Vector2(-5, -22) * s,
		])
		_mp(hull, cyan, 1.0)
		var rc := PackedVector2Array([
			o + Vector2(5, -16) * s, o + Vector2(16, -12) * s,
			o + Vector2(14, -8) * s, o + Vector2(5, -10) * s,
		])
		_mp(rc, teal, 0.7)
		var lc := PackedVector2Array([
			o + Vector2(-5, -16) * s, o + Vector2(-16, -12) * s,
			o + Vector2(-14, -8) * s, o + Vector2(-5, -10) * s,
		])
		_mp(lc, teal, 0.7)
		var re := PackedVector2Array([
			o + Vector2(8, 12) * s, o + Vector2(14, 14) * s,
			o + Vector2(16, 26) * s, o + Vector2(12, 28) * s, o + Vector2(8, 22) * s,
		])
		_mp(re, cyan, 0.7)
		var le := PackedVector2Array([
			o + Vector2(-8, 12) * s, o + Vector2(-14, 14) * s,
			o + Vector2(-16, 26) * s, o + Vector2(-12, 28) * s, o + Vector2(-8, 22) * s,
		])
		_mp(le, cyan, 0.7)
		var can := PackedVector2Array([
			o + Vector2(0, -30) * s, o + Vector2(3, -18) * s,
			o + Vector2(-3, -18) * s,
		])
		var cf := purple
		cf.a = 0.25
		draw_colored_polygon(can, cf)
		_ml(o + Vector2(0, -18) * s, o + Vector2(0, 22) * s, magenta, 0.7)
		_ml(o + Vector2(0, 24) * s, o + Vector2(0, 32) * s, orange, 1.5)
		_ml(o + Vector2(13, 26) * s, o + Vector2(13, 33) * s, orange, 1.2)
		_ml(o + Vector2(-13, 26) * s, o + Vector2(-13, 33) * s, orange, 1.2)
