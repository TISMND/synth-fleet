class_name ShipRenderer
extends Node2D
## Full-size ship renderer with banking, chrome+neon modes, all ships.
## Extracted from ships_screen.gd _ShipDraw for reuse across the codebase.

enum RenderMode { NEON, CHROME, VOID, HIVEMIND, SPORE, EMBER, FROST, SOLAR, SPORT }

const CHROME_DARK := Color(0.12, 0.13, 0.18)
const CHROME_MID := Color(0.35, 0.38, 0.45)
const CHROME_LIGHT := Color(0.65, 0.70, 0.80)
const CHROME_BRIGHT := Color(0.85, 0.88, 0.95)
const CHROME_SPEC := Color(1.0, 1.0, 1.0, 0.9)

# Void palette
const VOID_FILL := Color(0.02, 0.01, 0.05, 0.95)
const VOID_EDGE := Color(0.6, 0.0, 1.0)
const VOID_EDGE_DIM := Color(0.2, 0.0, 0.5, 0.3)

# Hivemind palette
const HIVE_FILL := Color(0.12, 0.06, 0.0)
const HIVE_VEIN := Color(0.1, 1.0, 0.3)
const HIVE_VEIN_DIM := Color(0.05, 0.4, 0.15, 0.4)

# Ember palette (warm neon variant)
const EMBER_HULL := Color(1.0, 0.35, 0.1)
const EMBER_ACCENT := Color(1.0, 0.8, 0.0)
const EMBER_ENGINE := Color(1.0, 0.15, 0.05)
const EMBER_CANOPY := Color(1.0, 0.6, 0.1)
const EMBER_DETAIL := Color(1.0, 0.9, 0.4)

# Frost palette (ice neon variant)
const FROST_HULL := Color(0.6, 0.85, 1.0)
const FROST_ACCENT := Color(0.9, 0.95, 1.0)
const FROST_ENGINE := Color(0.3, 0.6, 1.0)
const FROST_CANOPY := Color(0.7, 0.8, 1.0)
const FROST_DETAIL := Color(0.4, 0.95, 1.0)

# Solar palette (gold neon variant)
const SOLAR_HULL := Color(1.0, 0.85, 0.2)
const SOLAR_ACCENT := Color(1.0, 0.6, 0.0)
const SOLAR_ENGINE := Color(1.0, 0.95, 0.5)
const SOLAR_CANOPY := Color(0.9, 0.7, 0.1)
const SOLAR_DETAIL := Color(1.0, 1.0, 0.6)

# Spore palette
const SPORE_CORE := Color(0.0, 0.8, 0.5, 0.12)
const SPORE_DOT := Color(0.2, 1.0, 0.7)
const SPORE_DOT_ALT := Color(0.8, 0.3, 1.0)

var hull_color := Color(0.0, 0.9, 1.0)
var accent_color := Color(1.0, 0.2, 0.6)
var engine_color := Color(1.0, 0.5, 0.1)
var canopy_color := Color(0.4, 0.2, 1.0)
var detail_color := Color(0.0, 1.0, 0.7)
var bank := 0.0
var ship_id := 0
var render_mode: int = RenderMode.NEON
var time := 0.0
var enemy_visual_id: String = ""
var animate: bool = true
var hit_flash: float = 0.0
var hull_flash_duration: float = 0.12
var hull_blink_speed: float = 6.0
var hull_peak_color := Color(3.0, 3.0, 3.0, 1.0)


func trigger_hull_flash(duration: float = -1.0) -> void:
	if duration > 0.0:
		hull_flash_duration = duration
	hit_flash = hull_flash_duration


func _process(delta: float) -> void:
	# Hull flash modulate (Hard Blink)
	if hit_flash > 0.0:
		hit_flash -= delta
		var t: float = clampf(hit_flash / hull_flash_duration, 0.0, 1.0)
		var on: bool = fmod(t * hull_blink_speed, 2.0) > 1.0
		self_modulate = hull_peak_color if on else Color(1, 1, 1, 1)
		if hit_flash <= 0.0:
			hit_flash = 0.0
			self_modulate = Color(1, 1, 1, 1)
		if not animate:
			queue_redraw()
	if not animate:
		return
	time += delta
	queue_redraw()


func _bx(x: float, s: float, intensity: float) -> float:
	var sf: float = signf(x) if x != 0.0 else 0.0
	return x * (1.0 + bank * sf * intensity) * s

func _bp(x: float, y: float, s: float, intensity: float) -> Vector2:
	return Vector2(_bx(x, s, intensity) + bank * 2.5 * s, y * s)

func _side_color(base: Color, side: float) -> Color:
	var col := base
	col.a = clampf(col.a + bank * side * 0.06, 0.5, 1.0)
	return col

static func get_ship_scale(id: int) -> float:
	match id:
		0: return 1.2
		6: return 1.7
		7: return 1.9
		8: return 1.8
	return 1.4

static func get_engine_offsets(id: int) -> Array[Vector2]:
	match id:
		0: return [Vector2(-3.0, 22.0), Vector2(3.0, 22.0)]
		1: return [Vector2(-5.0, 24.0), Vector2(5.0, 24.0)]
		2: return [Vector2(-8.0, 20.0), Vector2(8.0, 20.0)]
		3: return [Vector2(3.0, 24.0), Vector2(-17.0, 22.0)]
		4: return [Vector2(-4.0, 24.0), Vector2(4.0, 24.0)]
		5: return [Vector2(-13.0, 28.0), Vector2(0.0, 28.0), Vector2(13.0, 28.0)]
		6: return [Vector2(-6.0, 22.0), Vector2(0.0, 24.0), Vector2(6.0, 22.0)]
		7: return [Vector2(-14.0, 40.0), Vector2(-10.0, 40.0), Vector2(-6.0, 40.0), Vector2(-2.0, 40.0), Vector2(2.0, 40.0), Vector2(6.0, 40.0), Vector2(10.0, 40.0), Vector2(14.0, 40.0)]
		8: return [Vector2(-12.0, 34.0), Vector2(-4.0, 34.0), Vector2(4.0, 34.0), Vector2(12.0, 34.0)]
	return [Vector2(0.0, 30.0)]

# ── Dispatch helpers ──

func _poly(points: PackedVector2Array, color: Color, width: float) -> void:
	match render_mode:
		RenderMode.CHROME: _draw_chrome_polygon(points, color, bank)
		RenderMode.VOID: _draw_void_polygon(points, width)
		RenderMode.HIVEMIND: _draw_hivemind_polygon(points, width)
		RenderMode.SPORE: _draw_spore_polygon(points, width)
		_: _draw_neon_polygon(points, color, width)

func _circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	match render_mode:
		RenderMode.CHROME:
			# Chrome needs polygon points for gradient band clipping
			var pts: PackedVector2Array = _make_circle_points(center, radius, 64)
			_draw_chrome_polygon(pts, color, bank)
		RenderMode.VOID: _draw_void_circle(center, radius, width)
		RenderMode.HIVEMIND: _draw_hivemind_circle(center, radius, width)
		RenderMode.SPORE: _draw_spore_circle(center, radius, width)
		_: _draw_neon_circle(center, radius, color, width)

func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	match render_mode:
		RenderMode.CHROME: _draw_chrome_line(a, b, color, width)
		RenderMode.VOID: _draw_void_line(a, b, width)
		RenderMode.HIVEMIND: _draw_hivemind_line(a, b, width)
		RenderMode.SPORE: _draw_spore_line(a, b, width)
		_: _draw_neon_line(a, b, color, width)

## Generate evenly-spaced points around a circle (for use with _poly).
func _make_circle_points(center: Vector2, radius: float, point_count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(point_count):
		var angle: float = TAU * float(i) / float(point_count)
		pts.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	return pts

## Draw an arc that respects render modes (dispatches per-segment through _line).
func _arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float) -> void:
	for i in range(point_count):
		var t0: float = float(i) / float(point_count)
		var t1: float = float(i + 1) / float(point_count)
		var a0: float = lerpf(start_angle, end_angle, t0)
		var a1: float = lerpf(start_angle, end_angle, t1)
		_line(center + Vector2(cos(a0) * radius, sin(a0) * radius), center + Vector2(cos(a1) * radius, sin(a1) * radius), color, width)

func _canopy(points: PackedVector2Array) -> void:
	match render_mode:
		RenderMode.CHROME:
			_draw_chrome_canopy(points, bank)
		RenderMode.VOID:
			draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.95))
			var pulse: float = 0.7 + sin(time * 2.0) * 0.3
			_draw_neon_lines(points, Color(VOID_EDGE.r, VOID_EDGE.g, VOID_EDGE.b, pulse), 1.4)
		RenderMode.HIVEMIND:
			var membrane := Color(0.15, 0.08, 0.0, 0.5)
			draw_colored_polygon(points, membrane)
			var pulse: float = 0.6 + sin(time * 1.5) * 0.4
			_draw_neon_lines(points, Color(HIVE_VEIN.r, HIVE_VEIN.g, HIVE_VEIN.b, pulse), 1.2)
		RenderMode.SPORE:
			draw_colored_polygon(points, Color(SPORE_CORE.r, SPORE_CORE.g, SPORE_CORE.b, 0.2))
			for i in range(points.size()):
				var dot_pulse: float = 0.5 + sin(time * 1.5 + float(i) * 2.3) * 0.5
				draw_circle(points[i], 2.0 * dot_pulse, SPORE_DOT_ALT)
		_:
			var cf := canopy_color
			cf.a = 0.3
			draw_colored_polygon(points, cf)
			_draw_neon_lines(points, canopy_color, 1.2 * 1.4)

func _exhaust_line(a: Vector2, b: Vector2, width: float) -> void:
	match render_mode:
		RenderMode.CHROME:
			var exhaust := Color(1.0, 0.8, 0.3, 0.8)
			_draw_chrome_line(a, b, exhaust, width)
		RenderMode.VOID:
			_draw_neon_line(a, b, Color(0.5, 0.0, 1.0, 0.6), width)
		RenderMode.HIVEMIND:
			_draw_neon_line(a, b, Color(0.2, 1.0, 0.4, 0.7), width)
		RenderMode.SPORE:
			_draw_neon_line(a, b, Color(0.3, 1.0, 0.6, 0.6), width)
		_:
			var exhaust := Color(1.0, 0.8, 0.3, 0.8)
			_draw_neon_line(a, b, exhaust, width)

func _apply_palette() -> void:
	match render_mode:
		RenderMode.EMBER:
			hull_color = EMBER_HULL
			accent_color = EMBER_ACCENT
			engine_color = EMBER_ENGINE
			canopy_color = EMBER_CANOPY
			detail_color = EMBER_DETAIL
		RenderMode.FROST:
			hull_color = FROST_HULL
			accent_color = FROST_ACCENT
			engine_color = FROST_ENGINE
			canopy_color = FROST_CANOPY
			detail_color = FROST_DETAIL
		RenderMode.SOLAR:
			hull_color = SOLAR_HULL
			accent_color = SOLAR_ACCENT
			engine_color = SOLAR_ENGINE
			canopy_color = SOLAR_CANOPY
			detail_color = SOLAR_DETAIL
		RenderMode.SPORT:
			var hue: float = fmod(time * 0.6, 1.0)
			hull_color = Color.from_hsv(hue, 0.9, 1.0)
			accent_color = Color.from_hsv(fmod(hue + 0.3, 1.0), 0.85, 1.0)
			engine_color = Color.from_hsv(fmod(hue + 0.15, 1.0), 0.8, 1.0)
			canopy_color = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 1.0)
			detail_color = Color.from_hsv(fmod(hue + 0.6, 1.0), 0.75, 1.0)
		_:
			hull_color = Color(0.0, 0.9, 1.0)
			accent_color = Color(1.0, 0.2, 0.6)
			engine_color = Color(1.0, 0.5, 0.1)
			canopy_color = Color(0.4, 0.2, 1.0)
			detail_color = Color(0.0, 1.0, 0.7)


func _draw() -> void:
	_apply_palette()
	if ship_id == -1:
		_draw_enemy_ship()
		return
	match ship_id:
		0: _draw_switchblade()
		1: _draw_phantom()
		2: _draw_mantis()
		3: _draw_corsair()
		4: _draw_stiletto()
		5: _draw_trident()
		6: _draw_orrery()
		7: _draw_dreadnought()
		8: _draw_bastion()

# ── Enemy ship drawing ──

func _draw_enemy_ship() -> void:
	match enemy_visual_id:
		"sentinel": _draw_sentinel()
		"dart": _draw_dart()
		"crucible": _draw_crucible()
		"prism": _draw_prism()
		"scythe": _draw_scythe()
		"tesseract": _draw_tesseract()
		"talon": _draw_talon()
		"obelisk": _draw_obelisk()
		"leviathan": _draw_leviathan()
		"marauder": _draw_marauder()
		"ironclad": _draw_ironclad()
		"wraith": _draw_wraith()
		"colossus": _draw_colossus()
		_: _draw_sentinel()  # Default fallback

func _draw_sentinel() -> void:
	var s := 1.6
	var r: float = 20.0 * s
	var glow_col := hull_color
	var inner_col := accent_color
	var detail := detail_color

	# Outer circle body
	_circle(Vector2.ZERO, r, glow_col, 1.8 * s)

	# Inner spinning hexagon
	var hex_pts := PackedVector2Array()
	var hex_r: float = 12.0 * s
	var spin: float = time * 0.8
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0 + spin
		hex_pts.append(Vector2(cos(angle) * hex_r, sin(angle) * hex_r))
	_poly(hex_pts, inner_col, 1.2 * s)

	# Inner spinning triangle (counter-rotation)
	var tri_pts := PackedVector2Array()
	var tri_r: float = 8.0 * s
	var tri_spin: float = -time * 1.2
	for i in range(3):
		var angle: float = TAU * float(i) / 3.0 + tri_spin
		tri_pts.append(Vector2(cos(angle) * tri_r, sin(angle) * tri_r))
	_poly(tri_pts, detail, 1.0 * s)

	# Cross-hairs / sensor lines
	var line_len: float = r * 1.15
	_line(Vector2(0, -line_len), Vector2(0, -r * 0.6), glow_col, 0.8 * s)
	_line(Vector2(0, r * 0.6), Vector2(0, line_len), glow_col, 0.8 * s)
	_line(Vector2(-line_len, 0), Vector2(-r * 0.6, 0), glow_col, 0.8 * s)
	_line(Vector2(r * 0.6, 0), Vector2(line_len, 0), glow_col, 0.8 * s)

	# Pulsing center core
	var pulse: float = 0.6 + sin(time * 3.0) * 0.4
	var core_r: float = 3.0 * s * pulse
	var core_col := Color(1.0, 1.0, 1.0, 0.8 * pulse)
	draw_circle(Vector2.ZERO, core_r + 2.0, Color(glow_col.r, glow_col.g, glow_col.b, 0.3 * pulse))
	draw_circle(Vector2.ZERO, core_r, core_col)

func _draw_dart() -> void:
	var s := 1.0
	# Narrow arrowhead facing downward (+Y = forward)
	var body := PackedVector2Array([
		Vector2(0 * s, 18 * s),
		Vector2(8 * s, -4 * s),
		Vector2(5 * s, -16 * s),
		Vector2(0 * s, -12 * s),
		Vector2(-5 * s, -16 * s),
		Vector2(-8 * s, -4 * s),
	])
	_poly(body, hull_color, 1.4 * s)

	# Wingtip accent lines — fast pulse
	var pulse: float = 0.5 + sin(time * 4.0) * 0.5
	var tip_col := accent_color
	tip_col.a = pulse
	_line(Vector2(8 * s, -4 * s), Vector2(12 * s, 2 * s), tip_col, 1.0 * s)
	_line(Vector2(-8 * s, -4 * s), Vector2(-12 * s, 2 * s), tip_col, 1.0 * s)

	# Spine detail
	_line(Vector2(0 * s, 14 * s), Vector2(0 * s, -10 * s), detail_color, 0.7 * s)

	# Single engine glow at rear (top of screen)
	var eng_pulse: float = 0.7 + sin(time * 6.0) * 0.3
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	draw_circle(Vector2(0, -14 * s), 3.0 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.3 * eng_pulse))
	draw_circle(Vector2(0, -14 * s), 1.8 * s, eng_col)

func _draw_crucible() -> void:
	var s := 1.8
	# Wide flat hexagon body
	var hex := PackedVector2Array([
		Vector2(0 * s, -16 * s),
		Vector2(14 * s, -8 * s),
		Vector2(14 * s, 8 * s),
		Vector2(0 * s, 16 * s),
		Vector2(-14 * s, 8 * s),
		Vector2(-14 * s, -8 * s),
	])
	_poly(hex, hull_color, 2.0 * s)

	# Engine nacelles on sides
	var r_nac := PackedVector2Array([
		Vector2(14 * s, -4 * s),
		Vector2(20 * s, -6 * s),
		Vector2(20 * s, 10 * s),
		Vector2(14 * s, 8 * s),
	])
	_poly(r_nac, hull_color, 1.5 * s)
	var l_nac := PackedVector2Array([
		Vector2(-14 * s, -4 * s),
		Vector2(-20 * s, -6 * s),
		Vector2(-20 * s, 10 * s),
		Vector2(-14 * s, 8 * s),
	])
	_poly(l_nac, hull_color, 1.5 * s)

	# Inner rotating cross detail
	var spin: float = time * 0.5
	for i in range(4):
		var angle: float = spin + TAU * float(i) / 4.0
		var end := Vector2(cos(angle) * 8.0 * s, sin(angle) * 8.0 * s)
		_line(Vector2.ZERO, end, detail_color, 1.0 * s)

	# Weapon pylon lines extending forward
	_line(Vector2(6 * s, -16 * s), Vector2(4 * s, -24 * s), accent_color, 1.2 * s)
	_line(Vector2(-6 * s, -16 * s), Vector2(-4 * s, -24 * s), accent_color, 1.2 * s)

	# Nacelle engine glow
	var eng_pulse: float = 0.6 + sin(time * 3.0) * 0.4
	draw_circle(Vector2(17 * s, 10 * s), 2.5 * s, Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse))
	draw_circle(Vector2(-17 * s, 10 * s), 2.5 * s, Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse))

func _draw_prism() -> void:
	var s := 1.4
	# 3 equilateral triangles rotating different directions
	var radii: Array[float] = [16.0, 12.0, 7.0]
	var speeds: Array[float] = [0.6, -0.9, 1.4]
	var colors: Array[Color] = [hull_color, accent_color, detail_color]
	var widths: Array[float] = [1.8, 1.4, 1.0]

	for t_idx in range(3):
		var tri := PackedVector2Array()
		var r: float = radii[t_idx] * s
		var spin: float = time * speeds[t_idx]
		for i in range(3):
			var angle: float = TAU * float(i) / 3.0 + spin
			tri.append(Vector2(cos(angle) * r, sin(angle) * r))
		_poly(tri, colors[t_idx], widths[t_idx] * s)

	# Pulsing core circle
	var pulse: float = 0.5 + sin(time * 2.5) * 0.5
	var core_r: float = 3.0 * s * (0.8 + pulse * 0.4)
	draw_circle(Vector2.ZERO, core_r + 2.0, Color(hull_color.r, hull_color.g, hull_color.b, 0.3 * pulse))
	draw_circle(Vector2.ZERO, core_r, Color(1.0, 1.0, 1.0, 0.7 * pulse))

func _draw_scythe() -> void:
	var s := 1.3
	# Curved crescent blade — rotated 90° CCW so blade sweeps horizontally
	var blade := PackedVector2Array()
	var arc_points := 10
	var breath: float = sin(time * 1.5) * 2.0
	var rot: float = -PI * 0.5  # Rotate so U-shape opens downward
	# Outer arc (wider)
	for i in range(arc_points):
		var t: float = float(i) / float(arc_points - 1)
		var angle: float = -PI * 0.6 + t * PI * 1.2 + rot
		var r: float = (18.0 + breath * (1.0 - abs(t - 0.5) * 2.0)) * s
		blade.append(Vector2(cos(angle) * r, sin(angle) * r))
	# Inner arc (return path, narrower)
	for i in range(arc_points - 1, -1, -1):
		var t: float = float(i) / float(arc_points - 1)
		var angle: float = -PI * 0.6 + t * PI * 1.2 + rot
		var r: float = 10.0 * s
		blade.append(Vector2(cos(angle) * r, sin(angle) * r))
	_poly(blade, hull_color, 1.6 * s)

	# Inner edge accent line
	var inner_r: float = 11.0 * s
	var arc_start: float = -PI * 0.6 + rot
	var arc_end: float = -PI * 0.6 + PI * 1.2 + rot
	_arc(Vector2.ZERO, inner_r, arc_start, arc_end, 16, detail_color, 0.8 * s)

	# Cockpit pod near top of curve
	var cockpit := PackedVector2Array([
		Vector2(-3 * s, -4 * s),
		Vector2(3 * s, -4 * s),
		Vector2(4 * s, 3 * s),
		Vector2(-4 * s, 3 * s),
	])
	_poly(cockpit, accent_color, 1.2 * s)

	# Engine glow behind cockpit
	draw_circle(Vector2(0, 5 * s), 2.0 * s, Color(engine_color.r, engine_color.g, engine_color.b, 0.6 + sin(time * 4.0) * 0.3))

func _draw_tesseract() -> void:
	var s := 1.6
	# 3 concentric axis-aligned squares pulsing on offset sine waves
	var sizes: Array[float] = [16.0, 11.0, 6.0]
	var phases: Array[float] = [0.0, 2.1, 4.2]
	var colors: Array[Color] = [hull_color, accent_color, detail_color]
	var widths: Array[float] = [2.0, 1.6, 1.2]

	var square_corners: Array[Array] = []
	for sq_idx in range(3):
		var pulse: float = sizes[sq_idx] + sin(time * 1.2 + phases[sq_idx]) * 2.0
		var half: float = pulse * s
		var sq := PackedVector2Array([
			Vector2(-half, -half),
			Vector2(half, -half),
			Vector2(half, half),
			Vector2(-half, half),
		])
		_poly(sq, colors[sq_idx], widths[sq_idx] * s)
		square_corners.append([
			Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half),
		])

	# Hypercube wireframe: connect corners of outer to inner squares
	if square_corners.size() >= 3:
		for i in range(4):
			var outer: Vector2 = square_corners[0][i]
			var inner: Vector2 = square_corners[2][i]
			var wire_col := detail_color
			wire_col.a = 0.5 + sin(time * 2.0 + float(i)) * 0.3
			_line(outer, inner, wire_col, 0.8 * s)

	# Pulsing core
	var core_pulse: float = 0.5 + sin(time * 1.8) * 0.5
	var core_r: float = 2.5 * s * (0.8 + core_pulse * 0.4)
	draw_circle(Vector2.ZERO, core_r + 3.0, Color(hull_color.r, hull_color.g, hull_color.b, 0.25 * core_pulse))
	draw_circle(Vector2.ZERO, core_r, Color(1.0, 1.0, 1.0, 0.8 * core_pulse))

func _draw_talon() -> void:
	var s := 1.3
	# Twin parallel boom polygons (P-38 style, facing down)
	var r_boom := PackedVector2Array([
		Vector2(6 * s, 20 * s),
		Vector2(10 * s, 20 * s),
		Vector2(11 * s, -14 * s),
		Vector2(5 * s, -14 * s),
	])
	_poly(r_boom, hull_color, 1.6 * s)
	var l_boom := PackedVector2Array([
		Vector2(-6 * s, 20 * s),
		Vector2(-10 * s, 20 * s),
		Vector2(-11 * s, -14 * s),
		Vector2(-5 * s, -14 * s),
	])
	_poly(l_boom, hull_color, 1.6 * s)

	# Connecting crossbar wing
	var wing := PackedVector2Array([
		Vector2(-12 * s, 2 * s),
		Vector2(12 * s, 2 * s),
		Vector2(14 * s, -2 * s),
		Vector2(-14 * s, -2 * s),
	])
	_poly(wing, hull_color, 1.4 * s)

	# Forward weapon pod diamond between boom noses (now at bottom)
	var pod := PackedVector2Array([
		Vector2(0 * s, 26 * s),
		Vector2(4 * s, 20 * s),
		Vector2(0 * s, 14 * s),
		Vector2(-4 * s, 20 * s),
	])
	_poly(pod, accent_color, 1.2 * s)

	# Panel seam lines on booms
	_line(Vector2(8 * s, 16 * s), Vector2(8 * s, -10 * s), detail_color, 0.6 * s)
	_line(Vector2(-8 * s, 16 * s), Vector2(-8 * s, -10 * s), detail_color, 0.6 * s)
	# Cross seams
	_line(Vector2(5 * s, 4 * s), Vector2(11 * s, 4 * s), detail_color, 0.5 * s)
	_line(Vector2(-5 * s, 4 * s), Vector2(-11 * s, 4 * s), detail_color, 0.5 * s)

	# Engine flicker (now at top = rear)
	var flicker: float = 0.5 + sin(time * 5.0) * 0.3 + sin(time * 7.3) * 0.2
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, flicker)
	draw_circle(Vector2(8 * s, -14 * s), 2.5 * s, eng_col)
	draw_circle(Vector2(-8 * s, -14 * s), 2.5 * s, eng_col)

func _draw_obelisk() -> void:
	var s := 1.7
	var rot: float = time * 0.3

	# Tall narrow rectangle rotating slowly
	var hw: float = 6.0 * s  # half width
	var hh: float = 20.0 * s  # half height
	var corners: Array[Vector2] = [
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, hh), Vector2(-hw, hh),
	]
	# Rotate corners
	var rotated := PackedVector2Array()
	for c in corners:
		var rx: float = c.x * cos(rot) - c.y * sin(rot)
		var ry: float = c.x * sin(rot) + c.y * cos(rot)
		rotated.append(Vector2(rx, ry))
	_poly(rotated, hull_color, 2.0 * s)

	# Horizontal scan line sweeping inside
	var scan_t: float = fmod(time * 0.6, 1.0)
	var scan_y: float = -hh + scan_t * hh * 2.0
	# Rotate scan line endpoints
	var scan_hw: float = hw * 0.8
	var sl: Vector2 = Vector2(-scan_hw, scan_y)
	var sr: Vector2 = Vector2(scan_hw, scan_y)
	var sl_r := Vector2(sl.x * cos(rot) - sl.y * sin(rot), sl.x * sin(rot) + sl.y * cos(rot))
	var sr_r := Vector2(sr.x * cos(rot) - sr.y * sin(rot), sr.x * sin(rot) + sr.y * cos(rot))
	var scan_alpha: float = 0.6 + sin(scan_t * PI) * 0.4
	_line(sl_r, sr_r, Color(accent_color.r, accent_color.g, accent_color.b, scan_alpha), 1.0 * s)

	# Corner accent circles
	for i in range(4):
		var cp: Vector2 = rotated[i]
		draw_circle(cp, 2.5 * s, Color(detail_color.r, detail_color.g, detail_color.b, 0.7))

	# Afterimage ghost at slightly earlier rotation
	var ghost_rot: float = rot - 0.15
	var ghost := PackedVector2Array()
	for c in corners:
		var rx: float = c.x * cos(ghost_rot) - c.y * sin(ghost_rot)
		var ry: float = c.x * sin(ghost_rot) + c.y * cos(ghost_rot)
		ghost.append(Vector2(rx, ry))
	var ghost_col := Color(hull_color.r, hull_color.g, hull_color.b, 0.15)
	if render_mode == RenderMode.CHROME:
		draw_colored_polygon(ghost, ghost_col)
	else:
		draw_colored_polygon(ghost, ghost_col)
		var edge_ghost := Color(hull_color.r, hull_color.g, hull_color.b, 0.2)
		for i in range(ghost.size()):
			var ni: int = (i + 1) % ghost.size()
			draw_line(ghost[i], ghost[ni], edge_ghost, 0.8 * s, true)

	# Pulsing center
	var pulse: float = 0.5 + sin(time * 1.5) * 0.5
	draw_circle(Vector2.ZERO, 3.0 * s, Color(1.0, 1.0, 1.0, 0.4 * pulse))

# ── Large enemy ships ──

func _draw_leviathan() -> void:
	var s := 3.2
	# Main hull — wide blocky carrier body, slightly asymmetric
	# +Y = forward (downward on screen), -Y = aft (top of screen)
	var hull := PackedVector2Array([
		Vector2(-18 * s, 22 * s),   # port bow
		Vector2(-8 * s, 28 * s),    # forward port
		Vector2(10 * s, 28 * s),    # forward starboard
		Vector2(20 * s, 20 * s),    # starboard bow
		Vector2(22 * s, 0 * s),     # starboard mid
		Vector2(20 * s, -20 * s),   # starboard stern
		Vector2(8 * s, -26 * s),    # aft starboard
		Vector2(-10 * s, -26 * s),  # aft port
		Vector2(-20 * s, -18 * s),  # port stern
		Vector2(-22 * s, 2 * s),    # port mid
	])
	_poly(hull, hull_color, 2.0 * s)

	# Bridge tower — offset to starboard side (asymmetric)
	var bridge := PackedVector2Array([
		Vector2(10 * s, 18 * s),
		Vector2(17 * s, 16 * s),
		Vector2(18 * s, 6 * s),
		Vector2(14 * s, 4 * s),
		Vector2(10 * s, 6 * s),
	])
	_poly(bridge, accent_color, 1.6 * s)

	# Bridge viewport slit
	_line(Vector2(11 * s, 14 * s), Vector2(16 * s, 12 * s), detail_color, 0.8 * s)

	# Hangar bay slit on port side
	var hangar_pulse: float = 0.4 + sin(time * 1.5) * 0.3
	var hangar_col := Color(accent_color.r, accent_color.g, accent_color.b, hangar_pulse)
	_line(Vector2(-16 * s, 4 * s), Vector2(-16 * s, -10 * s), hangar_col, 1.4 * s)
	_line(Vector2(-14 * s, 4 * s), Vector2(-14 * s, -10 * s), hangar_col, 1.0 * s)

	# Hull panel seams
	_line(Vector2(-6 * s, 24 * s), Vector2(-6 * s, -22 * s), detail_color, 0.5 * s)
	_line(Vector2(4 * s, 26 * s), Vector2(4 * s, -24 * s), detail_color, 0.5 * s)
	_line(Vector2(-18 * s, -6 * s), Vector2(18 * s, -6 * s), detail_color, 0.4 * s)

	# Weapon sponsons — small bumps along the sides
	for y_off in [12.0, 0.0, -12.0]:
		_line(Vector2(22 * s, y_off * s), Vector2(26 * s, (y_off + 1) * s), hull_color, 1.0 * s)
	_line(Vector2(-22 * s, 8 * s), Vector2(-26 * s, 9 * s), hull_color, 1.0 * s)
	_line(Vector2(-22 * s, -14 * s), Vector2(-26 * s, -13 * s), hull_color, 1.0 * s)

	# Engine bank — 4 engines across the stern (top of screen = aft)
	var eng_pulse: float = 0.5 + sin(time * 4.0) * 0.3 + sin(time * 6.5) * 0.2
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	for x_off in [-7.0, -2.0, 3.0, 8.0]:
		draw_circle(Vector2(x_off * s, -26 * s), 2.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.3 * eng_pulse))
		draw_circle(Vector2(x_off * s, -26 * s), 1.5 * s, eng_col)

	# Pulsing forward sensor (bottom of screen = bow)
	var sensor_pulse: float = 0.6 + sin(time * 2.0) * 0.4
	draw_circle(Vector2(1 * s, 26 * s), 2.0 * s, Color(detail_color.r, detail_color.g, detail_color.b, sensor_pulse))


func _draw_marauder() -> void:
	var s := 3.0
	# Aggressive forward-heavy gunship with offset weapon clusters
	# +Y = forward (downward on screen), -Y = aft (top of screen)
	var hull := PackedVector2Array([
		Vector2(-4 * s, 26 * s),    # nose port
		Vector2(6 * s, 26 * s),     # nose starboard (wider — asymmetric)
		Vector2(18 * s, 14 * s),    # starboard cheek
		Vector2(16 * s, -8 * s),    # starboard mid
		Vector2(12 * s, -22 * s),   # starboard aft
		Vector2(-10 * s, -22 * s),  # port aft
		Vector2(-14 * s, -8 * s),   # port mid
		Vector2(-16 * s, 12 * s),   # port cheek
	])
	_poly(hull, hull_color, 2.0 * s)

	# Port weapon pylon — extends forward and outward
	var port_pylon := PackedVector2Array([
		Vector2(-16 * s, 12 * s),
		Vector2(-22 * s, 18 * s),
		Vector2(-20 * s, 22 * s),
		Vector2(-14 * s, 16 * s),
	])
	_poly(port_pylon, hull_color, 1.6 * s)

	# Starboard weapon cluster — heavier, 2 barrels
	var stbd_pylon := PackedVector2Array([
		Vector2(18 * s, 14 * s),
		Vector2(24 * s, 20 * s),
		Vector2(26 * s, 18 * s),
		Vector2(22 * s, 10 * s),
	])
	_poly(stbd_pylon, hull_color, 1.6 * s)
	# Second starboard barrel stub
	_line(Vector2(22 * s, 14 * s), Vector2(26 * s, 22 * s), accent_color, 1.2 * s)

	# Cockpit canopy — offset slightly starboard
	var cockpit := PackedVector2Array([
		Vector2(2 * s, 20 * s),
		Vector2(8 * s, 18 * s),
		Vector2(8 * s, 12 * s),
		Vector2(2 * s, 14 * s),
	])
	_poly(cockpit, accent_color, 1.2 * s)

	# Armored spine running aft
	_line(Vector2(1 * s, 22 * s), Vector2(1 * s, -18 * s), detail_color, 0.8 * s)

	# Port hull gash / battle scar detail
	_line(Vector2(-10 * s, 4 * s), Vector2(-6 * s, -4 * s), detail_color, 0.6 * s)
	_line(Vector2(-12 * s, 0 * s), Vector2(-8 * s, -6 * s), detail_color, 0.5 * s)

	# Cross panel seams
	_line(Vector2(-14 * s, 2 * s), Vector2(16 * s, 2 * s), detail_color, 0.4 * s)
	_line(Vector2(-10 * s, -14 * s), Vector2(12 * s, -14 * s), detail_color, 0.4 * s)

	# Engines — 3, asymmetric placement (top of screen = aft)
	var eng_pulse: float = 0.5 + sin(time * 5.0) * 0.3 + sin(time * 8.0) * 0.2
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	draw_circle(Vector2(-6 * s, -22 * s), 3.0 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.3 * eng_pulse))
	draw_circle(Vector2(-6 * s, -22 * s), 1.8 * s, eng_col)
	draw_circle(Vector2(4 * s, -22 * s), 3.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.35 * eng_pulse))
	draw_circle(Vector2(4 * s, -22 * s), 2.0 * s, eng_col)
	draw_circle(Vector2(10 * s, -21 * s), 2.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.25 * eng_pulse))
	draw_circle(Vector2(10 * s, -21 * s), 1.4 * s, eng_col)

	# Weapon pylon tip glow (bottom of screen = forward)
	var wpn_pulse: float = 0.4 + sin(time * 3.0) * 0.4
	draw_circle(Vector2(-20 * s, 22 * s), 2.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, wpn_pulse))
	draw_circle(Vector2(25 * s, 21 * s), 2.5 * s, Color(accent_color.r, accent_color.g, accent_color.b, wpn_pulse))


func _draw_ironclad() -> void:
	var s := 3.4
	# Armored battleship — boxy, heavy, with turret bumps and shield dome
	# +Y = forward (downward on screen), -Y = aft (top of screen)
	var hull := PackedVector2Array([
		Vector2(-6 * s, 28 * s),    # bow port
		Vector2(6 * s, 28 * s),     # bow starboard
		Vector2(16 * s, 18 * s),    # starboard forward angle
		Vector2(18 * s, 6 * s),     # starboard upper
		Vector2(18 * s, -18 * s),   # starboard aft
		Vector2(14 * s, -24 * s),   # starboard stern angle
		Vector2(-14 * s, -24 * s),  # port stern angle
		Vector2(-18 * s, -18 * s),  # port aft
		Vector2(-18 * s, 6 * s),    # port upper
		Vector2(-16 * s, 18 * s),   # port forward angle
	])
	_poly(hull, hull_color, 2.2 * s)

	# Armor plate lines — heavy horizontal bands
	for y_off in [14.0, 4.0, -6.0, -16.0]:
		_line(Vector2(-17 * s, y_off * s), Vector2(17 * s, y_off * s), detail_color, 0.6 * s)

	# Forward turret barbette (raised bump) — near bow
	var fwd_turret := PackedVector2Array([
		Vector2(-5 * s, 20 * s),
		Vector2(5 * s, 20 * s),
		Vector2(6 * s, 14 * s),
		Vector2(-6 * s, 14 * s),
	])
	_poly(fwd_turret, accent_color, 1.4 * s)
	# Turret barrel — extends forward past bow
	_line(Vector2(0 * s, 20 * s), Vector2(0 * s, 28 * s), accent_color, 1.2 * s)

	# Aft turret — slightly offset to port (asymmetric)
	var aft_turret := PackedVector2Array([
		Vector2(-8 * s, -10 * s),
		Vector2(-2 * s, -10 * s),
		Vector2(-1 * s, -16 * s),
		Vector2(-9 * s, -16 * s),
	])
	_poly(aft_turret, accent_color, 1.2 * s)
	_line(Vector2(-5 * s, -10 * s), Vector2(-5 * s, -4 * s), accent_color, 1.0 * s)

	# Shield generator dome — center-starboard
	var shield_pulse: float = 0.3 + sin(time * 1.8) * 0.3
	var dome_col := Color(detail_color.r, detail_color.g, detail_color.b, shield_pulse)
	draw_circle(Vector2(4 * s, -2 * s), 6.0 * s, Color(dome_col.r, dome_col.g, dome_col.b, 0.15 * shield_pulse))
	draw_circle(Vector2(4 * s, -2 * s), 4.0 * s, Color(dome_col.r, dome_col.g, dome_col.b, 0.3 * shield_pulse))
	draw_circle(Vector2(4 * s, -2 * s), 2.0 * s, dome_col)

	# Side armor sponsons
	var r_sponson := PackedVector2Array([
		Vector2(18 * s, 2 * s),
		Vector2(22 * s, 4 * s),
		Vector2(22 * s, -8 * s),
		Vector2(18 * s, -10 * s),
	])
	_poly(r_sponson, hull_color, 1.4 * s)
	var l_sponson := PackedVector2Array([
		Vector2(-18 * s, -4 * s),
		Vector2(-22 * s, -2 * s),
		Vector2(-22 * s, -14 * s),
		Vector2(-18 * s, -16 * s),
	])
	_poly(l_sponson, hull_color, 1.4 * s)

	# Vertical keel line
	_line(Vector2(0 * s, 26 * s), Vector2(0 * s, -22 * s), detail_color, 0.5 * s)

	# Engine bank — 3 heavy engines (top of screen = aft)
	var eng_pulse: float = 0.5 + sin(time * 3.5) * 0.3 + sin(time * 5.5) * 0.2
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	for x_off in [-8.0, 0.0, 8.0]:
		draw_circle(Vector2(x_off * s, -24 * s), 3.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.3 * eng_pulse))
		draw_circle(Vector2(x_off * s, -24 * s), 2.0 * s, eng_col)


func _draw_wraith() -> void:
	var s := 3.0
	# Sleek stealth destroyer — angular, low-profile, off-center sensor fin
	# +Y = forward (downward on screen), -Y = aft (top of screen)
	var hull := PackedVector2Array([
		Vector2(0 * s, 30 * s),     # nose
		Vector2(8 * s, 22 * s),     # starboard forward
		Vector2(14 * s, 8 * s),     # starboard shoulder
		Vector2(16 * s, -6 * s),    # starboard widest
		Vector2(12 * s, -20 * s),   # starboard aft
		Vector2(4 * s, -24 * s),    # aft starboard
		Vector2(-6 * s, -24 * s),   # aft port
		Vector2(-12 * s, -18 * s),  # port aft
		Vector2(-14 * s, -4 * s),   # port widest
		Vector2(-12 * s, 10 * s),   # port shoulder
		Vector2(-6 * s, 24 * s),    # port forward
	])
	_poly(hull, hull_color, 1.8 * s)

	# Sensor fin — tall, offset to port (asymmetric signature element)
	var fin := PackedVector2Array([
		Vector2(-8 * s, 16 * s),
		Vector2(-6 * s, 20 * s),
		Vector2(-4 * s, 16 * s),
		Vector2(-4 * s, 4 * s),
		Vector2(-8 * s, 2 * s),
	])
	_poly(fin, accent_color, 1.2 * s)

	# Sensor sweep line on the fin — animated
	var sweep_t: float = fmod(time * 0.8, 1.0)
	var sweep_y: float = lerpf(18.0, 4.0, sweep_t) * s
	var sweep_alpha: float = 0.5 + sin(sweep_t * PI) * 0.5
	_line(Vector2(-8 * s, sweep_y), Vector2(-4 * s, sweep_y), Color(detail_color.r, detail_color.g, detail_color.b, sweep_alpha), 0.8 * s)

	# Angular wing stubs — swept back (toward -Y)
	var r_wing := PackedVector2Array([
		Vector2(14 * s, 4 * s),
		Vector2(22 * s, -2 * s),
		Vector2(20 * s, -6 * s),
		Vector2(14 * s, -4 * s),
	])
	_poly(r_wing, hull_color, 1.4 * s)
	var l_wing := PackedVector2Array([
		Vector2(-12 * s, 2 * s),
		Vector2(-18 * s, -4 * s),
		Vector2(-16 * s, -8 * s),
		Vector2(-12 * s, -6 * s),
	])
	_poly(l_wing, hull_color, 1.4 * s)

	# Cockpit slit — narrow viewport near nose
	_line(Vector2(-2 * s, 22 * s), Vector2(4 * s, 20 * s), accent_color, 0.9 * s)

	# Hull seam lines — angled for stealth look
	_line(Vector2(0 * s, 28 * s), Vector2(4 * s, 0 * s), detail_color, 0.4 * s)
	_line(Vector2(4 * s, 0 * s), Vector2(2 * s, -22 * s), detail_color, 0.4 * s)
	_line(Vector2(-10 * s, -6 * s), Vector2(14 * s, -2 * s), detail_color, 0.4 * s)

	# Recessed engines — low signature, 2 flush-mounted (top of screen = aft)
	var eng_pulse: float = 0.3 + sin(time * 4.5) * 0.2 + sin(time * 7.0) * 0.15
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	draw_circle(Vector2(-2 * s, -23 * s), 2.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.2 * eng_pulse))
	draw_circle(Vector2(-2 * s, -23 * s), 1.2 * s, eng_col)
	draw_circle(Vector2(6 * s, -23 * s), 2.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.2 * eng_pulse))
	draw_circle(Vector2(6 * s, -23 * s), 1.2 * s, eng_col)

	# Wingtip running lights — dim flicker
	var light_pulse: float = 0.3 + sin(time * 2.5) * 0.3
	draw_circle(Vector2(21 * s, -4 * s), 1.5 * s, Color(accent_color.r, accent_color.g, accent_color.b, light_pulse))
	draw_circle(Vector2(-17 * s, -6 * s), 1.5 * s, Color(accent_color.r, accent_color.g, accent_color.b, light_pulse * 0.7))


func _draw_colossus() -> void:
	var s := 3.6
	# Massive dreadnought — multi-section hull, command bridge, gun batteries
	# +Y = forward (downward on screen), -Y = aft (top of screen)
	# Forward section — armored prow (bottom of screen)
	var prow := PackedVector2Array([
		Vector2(-4 * s, 32 * s),
		Vector2(4 * s, 32 * s),
		Vector2(12 * s, 22 * s),
		Vector2(12 * s, 14 * s),
		Vector2(-12 * s, 14 * s),
		Vector2(-12 * s, 22 * s),
	])
	_poly(prow, hull_color, 2.0 * s)

	# Mid section — wider main body
	var midsection := PackedVector2Array([
		Vector2(-16 * s, 14 * s),
		Vector2(16 * s, 14 * s),
		Vector2(20 * s, 4 * s),
		Vector2(20 * s, -12 * s),
		Vector2(16 * s, -18 * s),
		Vector2(-16 * s, -18 * s),
		Vector2(-20 * s, -12 * s),
		Vector2(-20 * s, 4 * s),
	])
	_poly(midsection, hull_color, 2.2 * s)

	# Aft section — engine block (top of screen)
	var aft := PackedVector2Array([
		Vector2(-14 * s, -18 * s),
		Vector2(14 * s, -18 * s),
		Vector2(16 * s, -28 * s),
		Vector2(-16 * s, -28 * s),
	])
	_poly(aft, hull_color, 2.0 * s)

	# Section divider lines
	_line(Vector2(-16 * s, 14 * s), Vector2(16 * s, 14 * s), accent_color, 1.0 * s)
	_line(Vector2(-16 * s, -18 * s), Vector2(16 * s, -18 * s), accent_color, 1.0 * s)

	# Command bridge — raised structure, offset slightly starboard
	var bridge := PackedVector2Array([
		Vector2(2 * s, 10 * s),
		Vector2(12 * s, 8 * s),
		Vector2(14 * s, 0 * s),
		Vector2(10 * s, -4 * s),
		Vector2(2 * s, -2 * s),
	])
	_poly(bridge, accent_color, 1.6 * s)
	# Bridge viewport
	_line(Vector2(4 * s, 8 * s), Vector2(10 * s, 6 * s), detail_color, 0.8 * s)

	# Port gun battery — 2 barrel turret (barrels point forward = +Y)
	var port_gun := PackedVector2Array([
		Vector2(-16 * s, 6 * s),
		Vector2(-12 * s, 8 * s),
		Vector2(-10 * s, 4 * s),
		Vector2(-14 * s, 2 * s),
	])
	_poly(port_gun, accent_color, 1.2 * s)
	_line(Vector2(-14 * s, 8 * s), Vector2(-18 * s, 14 * s), accent_color, 1.0 * s)
	_line(Vector2(-12 * s, 7 * s), Vector2(-16 * s, 13 * s), accent_color, 1.0 * s)

	# Starboard gun battery — single heavy barrel
	var stbd_gun := PackedVector2Array([
		Vector2(16 * s, -6 * s),
		Vector2(20 * s, -4 * s),
		Vector2(22 * s, -8 * s),
		Vector2(18 * s, -10 * s),
	])
	_poly(stbd_gun, accent_color, 1.2 * s)
	_line(Vector2(20 * s, -5 * s), Vector2(24 * s, 1 * s), accent_color, 1.2 * s)

	# Hull panel detail — vertical and diagonal seams
	_line(Vector2(0 * s, 30 * s), Vector2(0 * s, -26 * s), detail_color, 0.5 * s)
	_line(Vector2(-8 * s, 22 * s), Vector2(-8 * s, -16 * s), detail_color, 0.4 * s)
	_line(Vector2(8 * s, 22 * s), Vector2(8 * s, -16 * s), detail_color, 0.4 * s)

	# Armor plate cross-hatching on prow
	_line(Vector2(-8 * s, 20 * s), Vector2(8 * s, 18 * s), detail_color, 0.4 * s)
	_line(Vector2(-10 * s, 16 * s), Vector2(10 * s, 16 * s), detail_color, 0.4 * s)

	# Engine bank — 5 engines, heavy output (top of screen = aft)
	var eng_pulse: float = 0.5 + sin(time * 3.0) * 0.25 + sin(time * 5.0) * 0.15 + sin(time * 9.0) * 0.1
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	for x_off in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		draw_circle(Vector2(x_off * s, -28 * s), 3.5 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.3 * eng_pulse))
		draw_circle(Vector2(x_off * s, -28 * s), 2.0 * s, eng_col)

	# Gun battery glow — slow pulse
	var wpn_pulse: float = 0.3 + sin(time * 2.0) * 0.3
	draw_circle(Vector2(-17 * s, 13 * s), 2.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, wpn_pulse))
	draw_circle(Vector2(23 * s, 0 * s), 2.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, wpn_pulse))

	# Pulsing command bridge light
	var cmd_pulse: float = 0.5 + sin(time * 1.5) * 0.5
	draw_circle(Vector2(8 * s, 2 * s), 2.0 * s, Color(1.0, 1.0, 1.0, 0.4 * cmd_pulse))

# ── Chrome drawing helpers ──

func _draw_chrome_polygon(points: PackedVector2Array, tint_color: Color, bk: float) -> void:
	if points.size() < 3:
		return
	# Dark base fill
	draw_colored_polygon(points, CHROME_DARK)

	# Compute bounding box for horizontal gradient bands
	var min_y := points[0].y
	var max_y := points[0].y
	var min_x := points[0].x
	var max_x := points[0].x
	for pt in points:
		min_y = minf(min_y, pt.y)
		max_y = maxf(max_y, pt.y)
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
	var height: float = max_y - min_y
	var width: float = max_x - min_x
	if height < 0.5 or width < 0.5:
		return

	# Horizontal gradient bands — bottom dark, top bright (overhead light)
	var band_colors: Array[Color] = [
		CHROME_DARK.lerp(CHROME_MID, 0.3),
		CHROME_MID,
		CHROME_LIGHT,
		CHROME_BRIGHT,
	]
	var band_count: int = band_colors.size()
	for i in range(band_count):
		var t0: float = float(i) / float(band_count)
		var t1: float = float(i + 1) / float(band_count)
		var y0: float = max_y - t0 * height  # bottom to top
		var y1: float = max_y - t1 * height
		var band_rect := PackedVector2Array([
			Vector2(min_x - 5.0, y0),
			Vector2(max_x + 5.0, y0),
			Vector2(max_x + 5.0, y1),
			Vector2(min_x - 5.0, y1),
		])
		var clipped: Array = Geometry2D.intersect_polygons(points, band_rect)
		for clip_idx in range(clipped.size()):
			var clip_poly: PackedVector2Array = clipped[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, band_colors[i])

	# Bank-reactive left/right shading — brighten facing side
	var center_x: float = (min_x + max_x) * 0.5
	var left_rect := PackedVector2Array([
		Vector2(min_x - 5.0, min_y - 5.0),
		Vector2(center_x, min_y - 5.0),
		Vector2(center_x, max_y + 5.0),
		Vector2(min_x - 5.0, max_y + 5.0),
	])
	var right_rect := PackedVector2Array([
		Vector2(center_x, min_y - 5.0),
		Vector2(max_x + 5.0, min_y - 5.0),
		Vector2(max_x + 5.0, max_y + 5.0),
		Vector2(center_x, max_y + 5.0),
	])

	# When banking right (bk < 0), left side faces us = brighter
	var left_alpha: float = clampf(-bk * 0.15, -0.08, 0.15)
	var right_alpha: float = clampf(bk * 0.15, -0.08, 0.15)
	if left_alpha > 0.01:
		var left_clips: Array = Geometry2D.intersect_polygons(points, left_rect)
		for clip_idx in range(left_clips.size()):
			var clip_poly: PackedVector2Array = left_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, left_alpha))
	elif left_alpha < -0.01:
		var left_clips: Array = Geometry2D.intersect_polygons(points, left_rect)
		for clip_idx in range(left_clips.size()):
			var clip_poly: PackedVector2Array = left_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(0.0, 0.0, 0.0, -left_alpha))
	if right_alpha > 0.01:
		var right_clips: Array = Geometry2D.intersect_polygons(points, right_rect)
		for clip_idx in range(right_clips.size()):
			var clip_poly: PackedVector2Array = right_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, right_alpha))
	elif right_alpha < -0.01:
		var right_clips: Array = Geometry2D.intersect_polygons(points, right_rect)
		for clip_idx in range(right_clips.size()):
			var clip_poly: PackedVector2Array = right_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(0.0, 0.0, 0.0, -right_alpha))

	# Specular highlight — soft gradient gleam that slides with bank
	var spec_x: float = center_x + bk * width * 0.4 + sin(time * 0.8) * width * 0.05
	var spec_brightness: float = 0.9 + sin(time * 1.2) * 0.1
	# Draw multiple overlapping strips from wide/faint to narrow/bright
	var gleam_layers: Array[Array] = [
		[width * 0.22, 0.06],   # widest, faintest
		[width * 0.14, 0.12],
		[width * 0.08, 0.20],
		[width * 0.03, 0.35],   # narrowest, brightest
	]
	for layer in gleam_layers:
		var half_w: float = layer[0]
		var alpha: float = layer[1] * spec_brightness
		var strip := PackedVector2Array([
			Vector2(spec_x - half_w, min_y - 5.0),
			Vector2(spec_x + half_w, min_y - 5.0),
			Vector2(spec_x + half_w, max_y + 5.0),
			Vector2(spec_x - half_w, max_y + 5.0),
		])
		var strip_clips: Array = Geometry2D.intersect_polygons(points, strip)
		for clip_idx in range(strip_clips.size()):
			var clip_poly: PackedVector2Array = strip_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, alpha))

	# Subtle color tint overlay from original weapon color
	var tint := tint_color
	tint.a = 0.08
	draw_colored_polygon(points, tint)

	# Chrome edges — hard rim lighting
	_draw_chrome_edges(points, bk)

func _draw_chrome_edges(points: PackedVector2Array, bk: float) -> void:
	if points.size() < 2:
		return
	var light_dir := Vector2(bk * 0.7, -1.0).normalized()
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var a: Vector2 = points[i]
		var b: Vector2 = points[ni]
		var edge_dir: Vector2 = (b - a).normalized()
		var edge_normal := Vector2(-edge_dir.y, edge_dir.x)
		var facing: float = edge_normal.dot(light_dir)
		var brightness: float = clampf(facing * 0.5 + 0.5, 0.15, 1.0)
		var edge_col := CHROME_DARK.lerp(CHROME_SPEC, brightness)
		edge_col.a = 0.6 + brightness * 0.4
		draw_line(a, b, edge_col, 1.5, true)

func _draw_chrome_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# Shadow offset
	var perp: Vector2 = (b - a).normalized()
	perp = Vector2(-perp.y, perp.x)
	var shadow_off: Vector2 = perp * 1.0
	draw_line(a + shadow_off, b + shadow_off, CHROME_DARK, width * 1.2, true)
	# Bright highlight offset
	draw_line(a - shadow_off, b - shadow_off, CHROME_BRIGHT, width * 0.8, true)
	# Core mid-tone with color tint
	var mid := CHROME_MID.lerp(color, 0.15)
	draw_line(a, b, mid, width, true)
	# Hot specular center
	var spec_brightness: float = 0.9 + sin(time * 1.2) * 0.1
	var spec := CHROME_SPEC
	spec.a = 0.4 * spec_brightness
	draw_line(a, b, spec, width * 0.3, true)

func _draw_chrome_canopy(points: PackedVector2Array, bk: float) -> void:
	if points.size() < 3:
		return
	# Dark blue-tinted glass fill
	var glass := Color(0.05, 0.08, 0.2, 0.85)
	draw_colored_polygon(points, glass)
	# Bright rim on canopy edges
	_draw_chrome_edges(points, bk)

# ── Ship 0: Switchblade — V-scissors opening forward ──
func _draw_switchblade() -> void:
	var s := 1.2
	var ry: float = -bank * 1.6 * s
	var ly: float = bank * 1.6 * s

	# Right blade — thick geometric slab, sharp angles
	var r_blade := PackedVector2Array([
		_bp(3, 16, s, 0.1),
		_bp(4, 4, s, 0.15) + Vector2(0, ry * 0.1),
		_bp(10, -14, s, 0.22) + Vector2(0, ry * 0.4),
		_bp(16, -32, s, 0.26) + Vector2(0, ry * 0.8),
		_bp(22, -36, s, 0.28) + Vector2(0, ry),
		_bp(20, -24, s, 0.26) + Vector2(0, ry * 0.8),
		_bp(16, -8, s, 0.2) + Vector2(0, ry * 0.4),
		_bp(12, 6, s, 0.15) + Vector2(0, ry * 0.15),
		_bp(8, 16, s, 0.1),
	])
	_poly(r_blade, _side_color(hull_color, 1.0), 1.5 * s)

	# Left blade — mirror
	var l_blade := PackedVector2Array([
		_bp(-3, 16, s, 0.1),
		_bp(-4, 4, s, 0.15) + Vector2(0, ly * 0.1),
		_bp(-10, -14, s, 0.22) + Vector2(0, ly * 0.4),
		_bp(-16, -32, s, 0.26) + Vector2(0, ly * 0.8),
		_bp(-22, -36, s, 0.28) + Vector2(0, ly),
		_bp(-20, -24, s, 0.26) + Vector2(0, ly * 0.8),
		_bp(-16, -8, s, 0.2) + Vector2(0, ly * 0.4),
		_bp(-12, 6, s, 0.15) + Vector2(0, ly * 0.15),
		_bp(-8, 16, s, 0.1),
	])
	_poly(l_blade, _side_color(hull_color, -1.0), 1.5 * s)

	# Central diamond hub at rear
	var hub := PackedVector2Array([
		_bp(0, 2, s, 0.06),
		_bp(7, 14, s, 0.06),
		_bp(0, 24, s, 0.06),
		_bp(-7, 14, s, 0.06),
	])
	_poly(hub, hull_color, 1.8 * s)

	# Diamond canopy in hub
	var cx: float = -bank * 1.0 * s
	var can := PackedVector2Array([
		_bp(0, 6, s, 0.04) + Vector2(cx, 0),
		_bp(4, 12, s, 0.04) + Vector2(cx, 0),
		_bp(0, 18, s, 0.04) + Vector2(cx, 0),
		_bp(-4, 12, s, 0.04) + Vector2(cx, 0),
	])
	_canopy(can)

	# Blade spine accents (center ridge of each blade)
	_line(
		_bp(6, 10, s, 0.12) + Vector2(0, ry * 0.1),
		_bp(18, -28, s, 0.24) + Vector2(0, ry * 0.8),
		detail_color, 0.8 * s)
	_line(
		_bp(-6, 10, s, 0.12) + Vector2(0, ly * 0.1),
		_bp(-18, -28, s, 0.24) + Vector2(0, ly * 0.8),
		detail_color, 0.8 * s)
	# Cross-brace between blades
	_line(
		_bp(8, -4, s, 0.18) + Vector2(0, ry * 0.25),
		_bp(-8, -4, s, 0.18) + Vector2(0, ly * 0.25),
		detail_color, 0.6 * s)

	# Spine through hub
	_line(_bp(0, 6, s, 0.06), _bp(0, 20, s, 0.06), accent_color, 1.0 * s)

	# Twin engines at base of hub
	_exhaust_line(_bp(-3, 22, s, 0.06), _bp(-3, 28, s, 0.06), 2.5 * s)
	_exhaust_line(_bp(3, 22, s, 0.06), _bp(3, 28, s, 0.06), 2.5 * s)

# ── Ship 1: Phantom — smooth curved stealth fighter ──
func _draw_phantom() -> void:
	var s := 1.4
	var ry: float = -bank * 1.0 * s
	var ly: float = bank * 1.0 * s

	# Smooth teardrop hull (many vertices for curves)
	var hull := PackedVector2Array([
		_bp(0, -36, s, 0.06), _bp(6, -28, s, 0.06),
		_bp(10, -16, s, 0.08), _bp(14, -4, s, 0.08),
		_bp(16, 8, s, 0.08), _bp(12, 20, s, 0.08),
		_bp(6, 26, s, 0.06), _bp(-6, 26, s, 0.06),
		_bp(-12, 20, s, 0.08), _bp(-16, 8, s, 0.08),
		_bp(-14, -4, s, 0.08), _bp(-10, -16, s, 0.08),
		_bp(-6, -28, s, 0.06),
	])
	_poly(hull, hull_color, 2.0 * s)

	# Subtle blended wing stubs
	var rw := PackedVector2Array([
		_bp(14, -2, s, 0.18) + Vector2(0, ry * 0.4),
		_bp(22, 4, s, 0.18) + Vector2(0, ry),
		_bp(20, 10, s, 0.18) + Vector2(0, ry),
		_bp(14, 8, s, 0.18) + Vector2(0, ry * 0.4),
	])
	_poly(rw, _side_color(hull_color, 1.0), 1.2 * s)
	var lw := PackedVector2Array([
		_bp(-14, -2, s, 0.18) + Vector2(0, ly * 0.4),
		_bp(-22, 4, s, 0.18) + Vector2(0, ly),
		_bp(-20, 10, s, 0.18) + Vector2(0, ly),
		_bp(-14, 8, s, 0.18) + Vector2(0, ly * 0.4),
	])
	_poly(lw, _side_color(hull_color, -1.0), 1.2 * s)

	# Recessed elongated canopy
	var cx: float = -bank * 1.2 * s
	var can := PackedVector2Array([
		_bp(0, -30, s, 0.04) + Vector2(cx, 0),
		_bp(4, -18, s, 0.04) + Vector2(cx, 0),
		_bp(3, -8, s, 0.04) + Vector2(cx, 0),
		_bp(-3, -8, s, 0.04) + Vector2(cx, 0),
		_bp(-4, -18, s, 0.04) + Vector2(cx, 0),
	])
	_canopy(can)

	# Flowing contour lines
	_line(_bp(8, -22, s, 0.06), _bp(14, 2, s, 0.08), detail_color, 0.7 * s)
	_line(_bp(-8, -22, s, 0.06), _bp(-14, 2, s, 0.08), detail_color, 0.7 * s)
	_line(_bp(12, 10, s, 0.08), _bp(6, 22, s, 0.06), detail_color, 0.7 * s)
	_line(_bp(-12, 10, s, 0.08), _bp(-6, 22, s, 0.06), detail_color, 0.7 * s)

	# Spine accent
	_line(_bp(0, -6, s, 0.06), _bp(0, 22, s, 0.06), accent_color, 1.0 * s)

	# Twin buried engines
	_exhaust_line(_bp(-5, 24, s, 0.06), _bp(-5, 32, s, 0.06), 3.0 * s)
	_exhaust_line(_bp(5, 24, s, 0.06), _bp(5, 32, s, 0.06), 3.0 * s)

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
	_poly(r_wing, _side_color(hull_color, 1.0), 1.8 * s)

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
	_poly(l_wing, _side_color(hull_color, -1.0), 1.8 * s)

	# Center spine accent
	_line(_bp(0, -24, s, 0.08), _bp(0, 14, s, 0.08), accent_color, 1.5 * s)

	# Wing edge accents
	_line(
		_bp(12, -10, s, 0.25) + Vector2(0, ry),
		_bp(38, 8, s, 0.25) + Vector2(0, ry),
		detail_color, 0.8 * s)
	_line(
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
	_canopy(can)

	# Two buried engines
	_exhaust_line(_bp(8, 16, s, 0.1), _bp(8, 24, s, 0.1), 2.5 * s)
	_exhaust_line(_bp(-8, 16, s, 0.1), _bp(-8, 24, s, 0.1), 2.5 * s)

# ── Ship 3: Corsair — asymmetric: blade-wing + engine pod ──
func _draw_corsair() -> void:
	var s := 1.4
	var ry: float = -bank * 1.4 * s
	var ly: float = bank * 1.4 * s

	# Main fuselage
	var hull := PackedVector2Array([
		_bp(-2, -34, s, 0.08), _bp(6, -22, s, 0.08),
		_bp(7, -4, s, 0.1), _bp(7, 16, s, 0.1),
		_bp(5, 26, s, 0.08), _bp(-7, 26, s, 0.08),
		_bp(-9, 16, s, 0.1), _bp(-9, -4, s, 0.1),
		_bp(-7, -22, s, 0.08),
	])
	_poly(hull, hull_color, 2.0 * s)

	# Right: thin swept blade-wing with gun
	var r_blade := PackedVector2Array([
		_bp(7, -8, s, 0.22) + Vector2(0, ry * 0.2),
		_bp(16, -16, s, 0.25) + Vector2(0, ry * 0.6),
		_bp(26, -12, s, 0.25) + Vector2(0, ry),
		_bp(24, -4, s, 0.25) + Vector2(0, ry),
		_bp(14, -2, s, 0.22) + Vector2(0, ry * 0.5),
		_bp(7, 2, s, 0.22) + Vector2(0, ry * 0.2),
	])
	_poly(r_blade, _side_color(hull_color, 1.0), 1.5 * s)

	# Gun barrel extending forward from blade tip
	_line(
		_bp(24, -12, s, 0.25) + Vector2(0, ry),
		_bp(26, -24, s, 0.25) + Vector2(0, ry),
		accent_color, 1.2 * s)

	# Blade edge accent
	_line(
		_bp(10, -12, s, 0.22) + Vector2(0, ry * 0.4),
		_bp(24, -8, s, 0.25) + Vector2(0, ry),
		detail_color, 0.7 * s)

	# Left: chunky engine nacelle/pod
	var l_pod := PackedVector2Array([
		_bp(-9, 0, s, 0.16) + Vector2(0, ly * 0.2),
		_bp(-16, -2, s, 0.18) + Vector2(0, ly * 0.5),
		_bp(-20, 4, s, 0.18) + Vector2(0, ly),
		_bp(-20, 18, s, 0.18) + Vector2(0, ly),
		_bp(-16, 24, s, 0.18) + Vector2(0, ly * 0.8),
		_bp(-9, 20, s, 0.16) + Vector2(0, ly * 0.2),
	])
	_poly(l_pod, _side_color(hull_color, -1.0), 1.5 * s)

	# Pod armor detail
	_line(
		_bp(-14, 2, s, 0.18) + Vector2(0, ly * 0.5),
		_bp(-14, 20, s, 0.18) + Vector2(0, ly * 0.7),
		detail_color, 0.7 * s)
	_line(
		_bp(-18, 8, s, 0.18) + Vector2(0, ly * 0.8),
		_bp(-12, 8, s, 0.18) + Vector2(0, ly * 0.4),
		detail_color, 0.6 * s)

	# Canopy
	var cx: float = -bank * 1.2 * s
	var can := PackedVector2Array([
		_bp(-1, -28, s, 0.04) + Vector2(cx, 0),
		_bp(4, -16, s, 0.04) + Vector2(cx, 0),
		_bp(2, -8, s, 0.04) + Vector2(cx, 0),
		_bp(-4, -8, s, 0.04) + Vector2(cx, 0),
		_bp(-5, -16, s, 0.04) + Vector2(cx, 0),
	])
	_canopy(can)

	# Spine
	_line(_bp(0, -6, s, 0.08), _bp(0, 22, s, 0.08), accent_color, 1.0 * s)

	# Main engine + pod engine (asymmetric exhaust)
	_exhaust_line(_bp(3, 24, s, 0.08), _bp(3, 32, s, 0.08), 3.0 * s)
	_exhaust_line(
		_bp(-17, 22, s, 0.18) + Vector2(0, ly * 0.8),
		_bp(-17, 30, s, 0.18) + Vector2(0, ly * 0.8),
		3.0 * s)

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
	_poly(hull, hull_color, 2.0 * s)

	# Facet edge lines
	_line(_bp(0, -32, s, 0.1), _bp(14, -12, s, 0.15), detail_color, 0.8 * s)
	_line(_bp(0, -32, s, 0.1), _bp(-14, -12, s, 0.15), detail_color, 0.8 * s)
	_line(_bp(14, -12, s, 0.15), _bp(10, 24, s, 0.1), detail_color, 0.8 * s)
	_line(_bp(-14, -12, s, 0.15), _bp(-10, 24, s, 0.1), detail_color, 0.8 * s)
	# Cross facet
	_line(_bp(-14, -12, s, 0.15), _bp(14, -12, s, 0.15), detail_color, 0.6 * s)

	# Angular canopy slit
	var cx: float = -bank * 1.2 * s
	var can := PackedVector2Array([
		_bp(0, -28, s, 0.05) + Vector2(cx, 0),
		_bp(7, -14, s, 0.05) + Vector2(cx, 0),
		_bp(5, -6, s, 0.05) + Vector2(cx, 0),
		_bp(-5, -6, s, 0.05) + Vector2(cx, 0),
		_bp(-7, -14, s, 0.05) + Vector2(cx, 0),
	])
	_canopy(can)

	# Spine
	_line(_bp(0, -6, s, 0.1), _bp(0, 20, s, 0.1), accent_color, 1.2 * s)

	# Twin tight engines
	_exhaust_line(_bp(-4, 22, s, 0.08), _bp(-4, 30, s, 0.08), 3.0 * s)
	_exhaust_line(_bp(4, 22, s, 0.08), _bp(4, 30, s, 0.08), 3.0 * s)

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
	_poly(hull, hull_color, 2.0 * s)

	# Right blade-fin — long swept forward prong
	var rf_main := PackedVector2Array([
		_bp(6, -20, s, 0.15) + Vector2(0, ry * 0.3),
		_bp(14, -26, s, 0.15) + Vector2(0, ry * 0.6),
		_bp(28, -38, s, 0.15) + Vector2(0, ry * 0.9),
		_bp(34, -44, s, 0.15) + Vector2(0, ry),
		_bp(30, -36, s, 0.15) + Vector2(0, ry * 0.9),
		_bp(22, -22, s, 0.15) + Vector2(0, ry * 0.7),
		_bp(18, -12, s, 0.15) + Vector2(0, ry * 0.5),
		_bp(12, -6, s, 0.15) + Vector2(0, ry * 0.4),
		_bp(8, -8, s, 0.15) + Vector2(0, ry * 0.3),
	])
	_poly(rf_main, _side_color(hull_color, 1.0), 1.5 * s)
	# Right fin trailing edge / winglet
	var rf_wing := PackedVector2Array([
		_bp(18, -12, s, 0.15) + Vector2(0, ry * 0.5),
		_bp(26, -10, s, 0.15) + Vector2(0, ry * 0.7),
		_bp(30, -16, s, 0.15) + Vector2(0, ry * 0.8),
		_bp(22, -22, s, 0.15) + Vector2(0, ry * 0.7),
	])
	_poly(rf_wing, _side_color(detail_color, 1.0), 1.0 * s)
	# Right fin structural strut
	_line(_bp(8, -14, s, 0.15) + Vector2(0, ry * 0.3), _bp(30, -38, s, 0.15) + Vector2(0, ry * 0.9), accent_color, 0.8 * s)
	# Right fin tip accent
	_line(_bp(32, -42, s, 0.15) + Vector2(0, ry), _bp(36, -46, s, 0.15) + Vector2(0, ry), accent_color, 1.2 * s)

	# Left blade-fin — mirror
	var lf_main := PackedVector2Array([
		_bp(-6, -20, s, 0.15) + Vector2(0, ly * 0.3),
		_bp(-14, -26, s, 0.15) + Vector2(0, ly * 0.6),
		_bp(-28, -38, s, 0.15) + Vector2(0, ly * 0.9),
		_bp(-34, -44, s, 0.15) + Vector2(0, ly),
		_bp(-30, -36, s, 0.15) + Vector2(0, ly * 0.9),
		_bp(-22, -22, s, 0.15) + Vector2(0, ly * 0.7),
		_bp(-18, -12, s, 0.15) + Vector2(0, ly * 0.5),
		_bp(-12, -6, s, 0.15) + Vector2(0, ly * 0.4),
		_bp(-8, -8, s, 0.15) + Vector2(0, ly * 0.3),
	])
	_poly(lf_main, _side_color(hull_color, -1.0), 1.5 * s)
	# Left fin trailing edge / winglet
	var lf_wing := PackedVector2Array([
		_bp(-18, -12, s, 0.15) + Vector2(0, ly * 0.5),
		_bp(-26, -10, s, 0.15) + Vector2(0, ly * 0.7),
		_bp(-30, -16, s, 0.15) + Vector2(0, ly * 0.8),
		_bp(-22, -22, s, 0.15) + Vector2(0, ly * 0.7),
	])
	_poly(lf_wing, _side_color(detail_color, -1.0), 1.0 * s)
	# Left fin structural strut
	_line(_bp(-8, -14, s, 0.15) + Vector2(0, ly * 0.3), _bp(-30, -38, s, 0.15) + Vector2(0, ly * 0.9), accent_color, 0.8 * s)
	# Left fin tip accent
	_line(_bp(-32, -42, s, 0.15) + Vector2(0, ly), _bp(-36, -46, s, 0.15) + Vector2(0, ly), accent_color, 1.2 * s)

	# Right engine nacelle
	var re := PackedVector2Array([
		_bp(9, 12, s, 0.18) + Vector2(0, ry * 0.3),
		_bp(16, 14, s, 0.18) + Vector2(0, ry * 0.5),
		_bp(18, 28, s, 0.18) + Vector2(0, ry * 0.5),
		_bp(14, 30, s, 0.18) + Vector2(0, ry * 0.5),
		_bp(9, 24, s, 0.18) + Vector2(0, ry * 0.3),
	])
	_poly(re, _side_color(hull_color, 1.0), 1.5 * s)
	# Left engine nacelle
	var le := PackedVector2Array([
		_bp(-9, 12, s, 0.18) + Vector2(0, ly * 0.3),
		_bp(-16, 14, s, 0.18) + Vector2(0, ly * 0.5),
		_bp(-18, 28, s, 0.18) + Vector2(0, ly * 0.5),
		_bp(-14, 30, s, 0.18) + Vector2(0, ly * 0.5),
		_bp(-9, 24, s, 0.18) + Vector2(0, ly * 0.3),
	])
	_poly(le, _side_color(hull_color, -1.0), 1.5 * s)

	# Canopy
	var cx: float = -bank * 1.0 * s
	var can := PackedVector2Array([
		_bp(0, -34, s, 0.05) + Vector2(cx, 0),
		_bp(4, -20, s, 0.05) + Vector2(cx, 0),
		_bp(-4, -20, s, 0.05) + Vector2(cx, 0),
	])
	_canopy(can)

	# Spine
	_line(_bp(0, -20, s, 0.08), _bp(0, 24, s, 0.08), accent_color, 1.0 * s)

	# Three engine exhausts
	_exhaust_line(_bp(0, 26, s, 0.08), _bp(0, 34, s, 0.08), 3.0 * s)
	_exhaust_line(
		_bp(15, 28, s, 0.18) + Vector2(0, ry * 0.5),
		_bp(15, 35, s, 0.18) + Vector2(0, ry * 0.5),
		2.5 * s)
	_exhaust_line(
		_bp(-15, 28, s, 0.18) + Vector2(0, ly * 0.5),
		_bp(-15, 35, s, 0.18) + Vector2(0, ly * 0.5),
		2.5 * s)

# ── Ship 6: Orrery — circular science vessel ──
func _draw_orrery() -> void:
	var s := 1.7
	var ry: float = -bank * 1.0 * s
	var ly: float = bank * 1.0 * s

	# Central dodecagonal core (r≈14)
	var core := PackedVector2Array([
		_bp(0, -14, s, 0.04), _bp(7, -12, s, 0.04),
		_bp(12, -7, s, 0.04), _bp(14, 0, s, 0.04),
		_bp(12, 7, s, 0.04), _bp(7, 12, s, 0.04),
		_bp(0, 14, s, 0.04), _bp(-7, 12, s, 0.04),
		_bp(-12, 7, s, 0.04), _bp(-14, 0, s, 0.04),
		_bp(-12, -7, s, 0.04), _bp(-7, -12, s, 0.04),
	])
	_poly(core, hull_color, 2.0 * s)

	# Right outer arc (thick crescent wrapping the right side)
	var r_arc := PackedVector2Array([
		_bp(18, -18, s, 0.1) + Vector2(0, ry * 0.2),
		_bp(22, -20, s, 0.1) + Vector2(0, ry * 0.3),
		_bp(27, -16, s, 0.1) + Vector2(0, ry * 0.4),
		_bp(30, -8, s, 0.1) + Vector2(0, ry * 0.5),
		_bp(32, 0, s, 0.1) + Vector2(0, ry * 0.6),
		_bp(30, 8, s, 0.1) + Vector2(0, ry * 0.5),
		_bp(27, 16, s, 0.1) + Vector2(0, ry * 0.4),
		_bp(22, 20, s, 0.1) + Vector2(0, ry * 0.3),
		_bp(18, 18, s, 0.1) + Vector2(0, ry * 0.2),
		_bp(20, 12, s, 0.1) + Vector2(0, ry * 0.3),
		_bp(24, 0, s, 0.1) + Vector2(0, ry * 0.5),
		_bp(20, -12, s, 0.1) + Vector2(0, ry * 0.3),
	])
	_poly(r_arc, _side_color(hull_color, 1.0), 1.5 * s)

	# Left outer arc (mirror)
	var l_arc := PackedVector2Array([
		_bp(-18, -18, s, 0.1) + Vector2(0, ly * 0.2),
		_bp(-22, -20, s, 0.1) + Vector2(0, ly * 0.3),
		_bp(-27, -16, s, 0.1) + Vector2(0, ly * 0.4),
		_bp(-30, -8, s, 0.1) + Vector2(0, ly * 0.5),
		_bp(-32, 0, s, 0.1) + Vector2(0, ly * 0.6),
		_bp(-30, 8, s, 0.1) + Vector2(0, ly * 0.5),
		_bp(-27, 16, s, 0.1) + Vector2(0, ly * 0.4),
		_bp(-22, 20, s, 0.1) + Vector2(0, ly * 0.3),
		_bp(-18, 18, s, 0.1) + Vector2(0, ly * 0.2),
		_bp(-20, 12, s, 0.1) + Vector2(0, ly * 0.3),
		_bp(-24, 0, s, 0.1) + Vector2(0, ly * 0.5),
		_bp(-20, -12, s, 0.1) + Vector2(0, ly * 0.3),
	])
	_poly(l_arc, _side_color(hull_color, -1.0), 1.5 * s)

	# Scaffolding struts — core to arcs (4 per side)
	_line(_bp(12, -7, s, 0.04), _bp(18, -18, s, 0.1) + Vector2(0, ry * 0.2), detail_color, 0.8 * s)
	_line(_bp(14, 0, s, 0.04), _bp(24, 0, s, 0.1) + Vector2(0, ry * 0.5), detail_color, 0.8 * s)
	_line(_bp(12, 7, s, 0.04), _bp(18, 18, s, 0.1) + Vector2(0, ry * 0.2), detail_color, 0.8 * s)
	_line(_bp(7, 12, s, 0.04), _bp(20, 12, s, 0.1) + Vector2(0, ry * 0.3), detail_color, 0.6 * s)
	_line(_bp(-12, -7, s, 0.04), _bp(-18, -18, s, 0.1) + Vector2(0, ly * 0.2), detail_color, 0.8 * s)
	_line(_bp(-14, 0, s, 0.04), _bp(-24, 0, s, 0.1) + Vector2(0, ly * 0.5), detail_color, 0.8 * s)
	_line(_bp(-12, 7, s, 0.04), _bp(-18, 18, s, 0.1) + Vector2(0, ly * 0.2), detail_color, 0.8 * s)
	_line(_bp(-7, 12, s, 0.04), _bp(-20, 12, s, 0.1) + Vector2(0, ly * 0.3), detail_color, 0.6 * s)

	# Forward sensor boom
	_line(_bp(0, -14, s, 0.04), _bp(0, -22, s, 0.04), accent_color, 1.2 * s)
	# Sensor dish at tip (small triangle)
	var dish := PackedVector2Array([
		_bp(0, -24, s, 0.04),
		_bp(5, -20, s, 0.04),
		_bp(-5, -20, s, 0.04),
	])
	_poly(dish, accent_color, 1.0 * s)

	# Core ring detail — cross lines through center
	_line(_bp(-10, 0, s, 0.04), _bp(10, 0, s, 0.04), detail_color, 0.6 * s)
	_line(_bp(0, -10, s, 0.04), _bp(0, 10, s, 0.04), detail_color, 0.6 * s)

	# Canopy (small window on core top face)
	var cx: float = -bank * 1.0 * s
	var can := PackedVector2Array([
		_bp(-4, -10, s, 0.03) + Vector2(cx, 0),
		_bp(4, -10, s, 0.03) + Vector2(cx, 0),
		_bp(3, -4, s, 0.03) + Vector2(cx, 0),
		_bp(-3, -4, s, 0.03) + Vector2(cx, 0),
	])
	_canopy(can)

	# Rear engine mount (small polygon below core)
	var eng_mount := PackedVector2Array([
		_bp(-8, 14, s, 0.04),
		_bp(8, 14, s, 0.04),
		_bp(10, 20, s, 0.04),
		_bp(6, 26, s, 0.04),
		_bp(-6, 26, s, 0.04),
		_bp(-10, 20, s, 0.04),
	])
	_poly(eng_mount, hull_color, 1.5 * s)

	# Three engines
	_exhaust_line(_bp(-6, 24, s, 0.04), _bp(-6, 32, s, 0.04), 2.5 * s)
	_exhaust_line(_bp(0, 26, s, 0.04), _bp(0, 34, s, 0.04), 2.5 * s)
	_exhaust_line(_bp(6, 24, s, 0.04), _bp(6, 32, s, 0.04), 2.5 * s)

# ── Ship 7: Dreadnought — massive capital ship ──
func _draw_dreadnought() -> void:
	var s := 1.9
	var ry: float = -bank * 0.8 * s
	var ly: float = bank * 0.8 * s

	# Elongated rectangular hull
	var hull := PackedVector2Array([
		_bp(-4, -48, s, 0.04), _bp(4, -48, s, 0.04),
		_bp(16, -40, s, 0.04), _bp(20, -26, s, 0.04),
		_bp(20, 26, s, 0.04), _bp(18, 36, s, 0.04),
		_bp(16, 42, s, 0.04), _bp(-16, 42, s, 0.04),
		_bp(-18, 36, s, 0.04), _bp(-20, 26, s, 0.04),
		_bp(-20, -26, s, 0.04), _bp(-16, -40, s, 0.04),
	])
	_poly(hull, hull_color, 2.4 * s)

	# Right hangar bay (recessed panel)
	var rhb := PackedVector2Array([
		_bp(20, -8, s, 0.08) + Vector2(0, ry * 0.2),
		_bp(26, -6, s, 0.08) + Vector2(0, ry * 0.4),
		_bp(26, 8, s, 0.08) + Vector2(0, ry * 0.4),
		_bp(20, 10, s, 0.08) + Vector2(0, ry * 0.2),
	])
	_poly(rhb, _side_color(detail_color, 1.0), 1.0 * s)
	# Left hangar bay
	var lhb := PackedVector2Array([
		_bp(-20, -8, s, 0.08) + Vector2(0, ly * 0.2),
		_bp(-26, -6, s, 0.08) + Vector2(0, ly * 0.4),
		_bp(-26, 8, s, 0.08) + Vector2(0, ly * 0.4),
		_bp(-20, 10, s, 0.08) + Vector2(0, ly * 0.2),
	])
	_poly(lhb, _side_color(detail_color, -1.0), 1.0 * s)

	# Triple turret bumps per side (small lines)
	_line(_bp(20, -22, s, 0.06) + Vector2(0, ry * 0.2), _bp(26, -22, s, 0.06) + Vector2(0, ry * 0.3), accent_color, 1.0 * s)
	_line(_bp(20, -16, s, 0.06) + Vector2(0, ry * 0.2), _bp(26, -16, s, 0.06) + Vector2(0, ry * 0.3), accent_color, 1.0 * s)
	_line(_bp(20, 18, s, 0.06) + Vector2(0, ry * 0.2), _bp(26, 18, s, 0.06) + Vector2(0, ry * 0.3), accent_color, 1.0 * s)
	_line(_bp(-20, -22, s, 0.06) + Vector2(0, ly * 0.2), _bp(-26, -22, s, 0.06) + Vector2(0, ly * 0.3), accent_color, 1.0 * s)
	_line(_bp(-20, -16, s, 0.06) + Vector2(0, ly * 0.2), _bp(-26, -16, s, 0.06) + Vector2(0, ly * 0.3), accent_color, 1.0 * s)
	_line(_bp(-20, 18, s, 0.06) + Vector2(0, ly * 0.2), _bp(-26, 18, s, 0.06) + Vector2(0, ly * 0.3), accent_color, 1.0 * s)

	# Many armor plate lines
	_line(_bp(-18, -20, s, 0.04), _bp(18, -20, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-18, -10, s, 0.04), _bp(18, -10, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-18, 0, s, 0.04), _bp(18, 0, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-18, 12, s, 0.04), _bp(18, 12, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-18, 24, s, 0.04), _bp(18, 24, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-16, 34, s, 0.04), _bp(16, 34, s, 0.04), detail_color, 0.7 * s)

	# Command bridge canopy
	var cx: float = -bank * 1.5 * s
	var can := PackedVector2Array([
		_bp(-8, -42, s, 0.02) + Vector2(cx, 0),
		_bp(8, -42, s, 0.02) + Vector2(cx, 0),
		_bp(10, -32, s, 0.02) + Vector2(cx, 0),
		_bp(-10, -32, s, 0.02) + Vector2(cx, 0),
	])
	_canopy(can)

	# Spine accent
	_line(_bp(0, -30, s, 0.04), _bp(0, 38, s, 0.04), accent_color, 1.2 * s)

	# Eight engines
	_exhaust_line(_bp(-14, 40, s, 0.04), _bp(-14, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(-10, 40, s, 0.04), _bp(-10, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(-6, 40, s, 0.04), _bp(-6, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(-2, 40, s, 0.04), _bp(-2, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(2, 40, s, 0.04), _bp(2, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(6, 40, s, 0.04), _bp(6, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(10, 40, s, 0.04), _bp(10, 48, s, 0.04), 1.8 * s)
	_exhaust_line(_bp(14, 40, s, 0.04), _bp(14, 48, s, 0.04), 1.8 * s)

# ── Ship 8: Bastion — stepped blocky capital ship (Sears Tower silhouette) ──
func _draw_bastion() -> void:
	var s := 1.8
	var ry: float = -bank * 0.9 * s
	var ly: float = bank * 0.9 * s

	# TIER 1 (rear/widest) — full-width engine section
	var tier1 := PackedVector2Array([
		_bp(-28, 10, s, 0.04), _bp(28, 10, s, 0.04),
		_bp(28, 44, s, 0.04), _bp(-28, 44, s, 0.04),
	])
	_poly(tier1, hull_color, 2.2 * s)

	# TIER 2 (mid) — steps in from tier 1
	var tier2 := PackedVector2Array([
		_bp(-22, -14, s, 0.04), _bp(22, -14, s, 0.04),
		_bp(22, 12, s, 0.04), _bp(-22, 12, s, 0.04),
	])
	_poly(tier2, hull_color, 2.2 * s)

	# TIER 3 (upper-mid) — narrower still
	var tier3 := PackedVector2Array([
		_bp(-16, -34, s, 0.04), _bp(16, -34, s, 0.04),
		_bp(16, -12, s, 0.04), _bp(-16, -12, s, 0.04),
	])
	_poly(tier3, hull_color, 2.2 * s)

	# TIER 4 (bridge/prow) — blunt narrow top
	var tier4 := PackedVector2Array([
		_bp(-10, -48, s, 0.04), _bp(10, -48, s, 0.04),
		_bp(10, -32, s, 0.04), _bp(-10, -32, s, 0.04),
	])
	_poly(tier4, hull_color, 2.0 * s)

	# Right side blocks — sponson pods on the wide tiers
	# Tier 1 right pod
	var r_pod1 := PackedVector2Array([
		_bp(28, 16, s, 0.06) + Vector2(0, ry * 0.2),
		_bp(36, 16, s, 0.06) + Vector2(0, ry * 0.4),
		_bp(36, 38, s, 0.06) + Vector2(0, ry * 0.4),
		_bp(28, 38, s, 0.06) + Vector2(0, ry * 0.2),
	])
	_poly(r_pod1, _side_color(hull_color, 1.0), 1.8 * s)
	# Tier 2 right pod (shorter)
	var r_pod2 := PackedVector2Array([
		_bp(22, -10, s, 0.06) + Vector2(0, ry * 0.2),
		_bp(28, -10, s, 0.06) + Vector2(0, ry * 0.3),
		_bp(28, 6, s, 0.06) + Vector2(0, ry * 0.3),
		_bp(22, 6, s, 0.06) + Vector2(0, ry * 0.2),
	])
	_poly(r_pod2, _side_color(hull_color, 1.0), 1.5 * s)

	# Left side blocks
	var l_pod1 := PackedVector2Array([
		_bp(-28, 16, s, 0.06) + Vector2(0, ly * 0.2),
		_bp(-36, 16, s, 0.06) + Vector2(0, ly * 0.4),
		_bp(-36, 38, s, 0.06) + Vector2(0, ly * 0.4),
		_bp(-28, 38, s, 0.06) + Vector2(0, ly * 0.2),
	])
	_poly(l_pod1, _side_color(hull_color, -1.0), 1.8 * s)
	var l_pod2 := PackedVector2Array([
		_bp(-22, -10, s, 0.06) + Vector2(0, ly * 0.2),
		_bp(-28, -10, s, 0.06) + Vector2(0, ly * 0.3),
		_bp(-28, 6, s, 0.06) + Vector2(0, ly * 0.3),
		_bp(-22, 6, s, 0.06) + Vector2(0, ly * 0.2),
	])
	_poly(l_pod2, _side_color(hull_color, -1.0), 1.5 * s)

	# Step ledge accents — horizontal lines where tiers step in
	_line(_bp(-28, 10, s, 0.04), _bp(28, 10, s, 0.04), accent_color, 1.0 * s)
	_line(_bp(-22, -14, s, 0.04), _bp(22, -14, s, 0.04), accent_color, 1.0 * s)
	_line(_bp(-16, -34, s, 0.04), _bp(16, -34, s, 0.04), accent_color, 0.9 * s)

	# Vertical step edges (right side silhouette)
	_line(_bp(28, 10, s, 0.04), _bp(22, 10, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(22, -14, s, 0.04), _bp(16, -14, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(16, -34, s, 0.04), _bp(10, -34, s, 0.04), detail_color, 0.7 * s)
	# Left side
	_line(_bp(-28, 10, s, 0.04), _bp(-22, 10, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-22, -14, s, 0.04), _bp(-16, -14, s, 0.04), detail_color, 0.7 * s)
	_line(_bp(-16, -34, s, 0.04), _bp(-10, -34, s, 0.04), detail_color, 0.7 * s)

	# Armor plate lines within tiers
	_line(_bp(-28, 24, s, 0.04), _bp(28, 24, s, 0.04), detail_color, 0.6 * s)
	_line(_bp(-28, 36, s, 0.04), _bp(28, 36, s, 0.04), detail_color, 0.6 * s)
	_line(_bp(-22, -4, s, 0.04), _bp(22, -4, s, 0.04), detail_color, 0.5 * s)
	_line(_bp(-16, -24, s, 0.04), _bp(16, -24, s, 0.04), detail_color, 0.5 * s)

	# Vertical structural ribs down center
	_line(_bp(-5, -46, s, 0.04), _bp(-5, 42, s, 0.04), detail_color, 0.4 * s)
	_line(_bp(5, -46, s, 0.04), _bp(5, 42, s, 0.04), detail_color, 0.4 * s)

	# Spine accent — doubled
	_line(_bp(-2, -44, s, 0.04), _bp(-2, 40, s, 0.04), accent_color, 0.8 * s)
	_line(_bp(2, -44, s, 0.04), _bp(2, 40, s, 0.04), accent_color, 0.8 * s)

	# Bridge canopy on tier 4
	var cx: float = -bank * 1.2 * s
	var can := PackedVector2Array([
		_bp(-5, -46, s, 0.03) + Vector2(cx, 0),
		_bp(5, -46, s, 0.03) + Vector2(cx, 0),
		_bp(6, -38, s, 0.03) + Vector2(cx, 0),
		_bp(-6, -38, s, 0.03) + Vector2(cx, 0),
	])
	_canopy(can)

	# Pod panel seams
	_line(_bp(30, 24, s, 0.06) + Vector2(0, ry * 0.3), _bp(34, 24, s, 0.06) + Vector2(0, ry * 0.4), detail_color, 0.4 * s)
	_line(_bp(30, 30, s, 0.06) + Vector2(0, ry * 0.3), _bp(34, 30, s, 0.06) + Vector2(0, ry * 0.4), detail_color, 0.4 * s)
	_line(_bp(-30, 24, s, 0.06) + Vector2(0, ly * 0.3), _bp(-34, 24, s, 0.06) + Vector2(0, ly * 0.4), detail_color, 0.4 * s)
	_line(_bp(-30, 30, s, 0.06) + Vector2(0, ly * 0.3), _bp(-34, 30, s, 0.06) + Vector2(0, ly * 0.4), detail_color, 0.4 * s)

	# Antenna stubs on tier 2 pods
	_line(_bp(28, -8, s, 0.06) + Vector2(0, ry * 0.3), _bp(30, -14, s, 0.06) + Vector2(0, ry * 0.4), detail_color, 0.5 * s)
	_line(_bp(-28, -8, s, 0.06) + Vector2(0, ly * 0.3), _bp(-30, -14, s, 0.06) + Vector2(0, ly * 0.4), detail_color, 0.5 * s)

	# Vent grates on tier 1 rear
	_line(_bp(-12, 38, s, 0.04), _bp(-8, 38, s, 0.04), detail_color, 0.4 * s)
	_line(_bp(-12, 41, s, 0.04), _bp(-8, 41, s, 0.04), detail_color, 0.4 * s)
	_line(_bp(8, 38, s, 0.04), _bp(12, 38, s, 0.04), detail_color, 0.4 * s)
	_line(_bp(8, 41, s, 0.04), _bp(12, 41, s, 0.04), detail_color, 0.4 * s)

	# Six heavy engines across the wide rear
	_exhaust_line(_bp(-22, 44, s, 0.04), _bp(-22, 52, s, 0.04), 2.8 * s)
	_exhaust_line(_bp(-14, 44, s, 0.04), _bp(-14, 52, s, 0.04), 2.8 * s)
	_exhaust_line(_bp(-6, 44, s, 0.04), _bp(-6, 52, s, 0.04), 2.8 * s)
	_exhaust_line(_bp(6, 44, s, 0.04), _bp(6, 52, s, 0.04), 2.8 * s)
	_exhaust_line(_bp(14, 44, s, 0.04), _bp(14, 52, s, 0.04), 2.8 * s)
	_exhaust_line(_bp(22, 44, s, 0.04), _bp(22, 52, s, 0.04), 2.8 * s)

# ── Void draw helpers ──

func _draw_void_polygon(points: PackedVector2Array, width: float) -> void:
	draw_colored_polygon(points, VOID_FILL)
	# Dim outer edge glow
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], VOID_EDGE_DIM, width * 2.5, true)
	# Per-edge shimmer hue-shifting violet<->blue
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var shimmer: float = sin(time * 0.4 + float(i) * 0.7) * 0.5 + 0.5
		var edge_col := Color(
			lerpf(VOID_EDGE.r, 0.2, shimmer),
			lerpf(VOID_EDGE.g, 0.0, shimmer),
			lerpf(VOID_EDGE.b, 1.0, shimmer)
		)
		draw_line(points[i], points[ni], edge_col, width, true)
	# Faint white flicker core
	var flicker: float = 0.2 + sin(time * 1.8) * 0.15
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], Color(1, 1, 1, flicker), width * 0.3, true)

func _draw_void_line(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, VOID_EDGE_DIM, width * 2.5, true)
	draw_line(a, b, VOID_EDGE, width, true)
	draw_line(a, b, Color(1, 1, 1, 0.15), width * 0.3, true)

# ── Hivemind draw helpers ──

func _draw_hivemind_polygon(points: PackedVector2Array, width: float) -> void:
	# Dark amber fill
	draw_colored_polygon(points, HIVE_FILL)
	# Breathing amber overlay
	var breath: float = sin(time * 1.2) * 0.08
	draw_colored_polygon(points, Color(0.2, 0.1, 0.0, 0.15 + breath))
	# Dim green vein underglow
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], HIVE_VEIN_DIM, width * 2.0, true)
	# Bright green veins with per-edge phase offset
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var pulse: float = 0.5 + sin(time * 1.2 + float(i) * 1.1) * 0.5
		var vein_col := Color(HIVE_VEIN.r, HIVE_VEIN.g, HIVE_VEIN.b, pulse)
		draw_line(points[i], points[ni], vein_col, width, true)
	# Bright vertex junction dots
	for pt in points:
		draw_circle(pt, width * 1.2, HIVE_VEIN)

func _draw_hivemind_line(a: Vector2, b: Vector2, width: float) -> void:
	# Dim underglow
	draw_line(a, b, HIVE_VEIN_DIM, width * 2.0, true)
	# Pulsing bright green
	var pulse: float = 0.5 + sin(time * 1.2) * 0.5
	draw_line(a, b, Color(HIVE_VEIN.r, HIVE_VEIN.g, HIVE_VEIN.b, pulse), width, true)
	# Endpoint node circles
	draw_circle(a, width * 1.0, HIVE_VEIN)
	draw_circle(b, width * 1.0, HIVE_VEIN)

# ── Phase draw helpers ──

# ── Spore draw helpers ──

func _draw_spore_polygon(points: PackedVector2Array, width: float) -> void:
	# Ghostly teal fill
	draw_colored_polygon(points, SPORE_CORE)
	# Faint continuous underglow
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], Color(SPORE_DOT.r, SPORE_DOT.g, SPORE_DOT.b, 0.15), width * 2.0, true)
	# Alternating edge segments swap visibility
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var vis: int = (i + int(time * 2.4)) % 2
		var seg_col: Color = SPORE_DOT if vis == 0 else SPORE_DOT_ALT
		seg_col.a = 0.7
		draw_line(points[i], points[ni], seg_col, width, true)
	# Pulsing vertex dots
	for i in range(points.size()):
		var dot_pulse: float = 0.4 + sin(time * 4.5 + float(i) * 2.3) * 0.4
		draw_circle(points[i], width * 1.0 * dot_pulse + 1.0, SPORE_DOT)
	# Wandering highlight orbiting centroid
	if points.size() >= 3:
		var centroid := Vector2.ZERO
		for pt in points:
			centroid += pt
		centroid /= float(points.size())
		var wander := centroid + Vector2(cos(time * 0.7) * 6.0, sin(time * 0.9) * 6.0)
		draw_circle(wander, 3.0, Color(1, 1, 1, 0.3 + sin(time * 2.0) * 0.2))

func _draw_spore_line(a: Vector2, b: Vector2, width: float) -> void:
	# Faint underglow
	draw_line(a, b, Color(SPORE_DOT.r, SPORE_DOT.g, SPORE_DOT.b, 0.2), width * 2.0, true)
	# Bright endpoint node circles
	draw_circle(a, width * 0.8, SPORE_DOT)
	draw_circle(b, width * 0.8, SPORE_DOT)
	# Purple midpoint dot
	var mid: Vector2 = (a + b) * 0.5
	draw_circle(mid, width * 0.6, SPORE_DOT_ALT)

# ── Neon drawing helpers ──

func _draw_neon_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var gc := color
	gc.a = 0.25
	draw_line(a, b, gc, width * 3.0, true)
	gc.a = 0.5
	draw_line(a, b, gc, width * 1.8, true)
	draw_line(a, b, color, width, true)
	var w := Color(1, 1, 1, 0.6)
	draw_line(a, b, w, width * 0.4, true)
	# Vertex glow caps — fill pizza-slice gaps at endpoints
	for pt in [a, b]:
		draw_circle(pt, width * 1.5, Color(color.r, color.g, color.b, 0.25))
		draw_circle(pt, width * 0.9, Color(color.r, color.g, color.b, 0.5))
		draw_circle(pt, width * 0.5, color)
		draw_circle(pt, width * 0.2, Color(1, 1, 1, 0.6))

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
	# Mid glow
	gc.a = 0.5
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], gc, width * 1.8, true)
	# Bright core
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], color, width, true)
	# White-hot center
	var white := Color(1, 1, 1, 0.6)
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], white, width * 0.4, true)
	# Vertex glow caps — fill pizza-slice gaps at corners
	for pt in points:
		draw_circle(pt, width * 1.5, Color(color.r, color.g, color.b, 0.25))
		draw_circle(pt, width * 0.9, Color(color.r, color.g, color.b, 0.5))
		draw_circle(pt, width * 0.5, color)
		draw_circle(pt, width * 0.2, Color(1, 1, 1, 0.6))

# ── Circle draw helpers (native primitives instead of polygon approximation) ──

func _draw_neon_circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	# Fill
	var glow := color
	glow.a = 0.15
	draw_circle(center, radius, glow)
	# Outer glow arc
	var gc := color
	gc.a = 0.25
	draw_arc(center, radius, 0.0, TAU, 128, gc, width * 3.0, true)
	# Mid glow
	gc.a = 0.5
	draw_arc(center, radius, 0.0, TAU, 128, gc, width * 1.8, true)
	# Bright core
	draw_arc(center, radius, 0.0, TAU, 128, color, width, true)
	# White-hot center
	draw_arc(center, radius, 0.0, TAU, 128, Color(1, 1, 1, 0.6), width * 0.4, true)

func _draw_void_circle(center: Vector2, radius: float, width: float) -> void:
	draw_circle(center, radius, VOID_FILL)
	# Dim outer edge glow
	draw_arc(center, radius, 0.0, TAU, 128, VOID_EDGE_DIM, width * 2.5, true)
	# Shimmer — animate hue shift around the ring
	var arc_steps: int = 32
	var arc_len: float = TAU / float(arc_steps)
	for i in range(arc_steps):
		var a0: float = arc_len * float(i)
		var shimmer: float = sin(time * 0.4 + float(i) * 0.7) * 0.5 + 0.5
		var edge_col := Color(
			lerpf(VOID_EDGE.r, 0.2, shimmer),
			lerpf(VOID_EDGE.g, 0.0, shimmer),
			lerpf(VOID_EDGE.b, 1.0, shimmer)
		)
		draw_arc(center, radius, a0, a0 + arc_len * 1.1, 8, edge_col, width, true)
	# Faint white flicker core
	var flicker: float = 0.2 + sin(time * 1.8) * 0.15
	draw_arc(center, radius, 0.0, TAU, 128, Color(1, 1, 1, flicker), width * 0.3, true)

func _draw_hivemind_circle(center: Vector2, radius: float, width: float) -> void:
	# Dark amber fill
	draw_circle(center, radius, HIVE_FILL)
	# Breathing amber overlay
	var breath: float = sin(time * 1.2) * 0.08
	draw_circle(center, radius, Color(0.2, 0.1, 0.0, 0.15 + breath))
	# Dim green vein underglow
	draw_arc(center, radius, 0.0, TAU, 128, HIVE_VEIN_DIM, width * 2.0, true)
	# Pulsing green veins — segmented arcs with phase offset
	var arc_steps: int = 24
	var arc_len: float = TAU / float(arc_steps)
	for i in range(arc_steps):
		var a0: float = arc_len * float(i)
		var pulse: float = 0.5 + sin(time * 1.2 + float(i) * 1.1) * 0.5
		var vein_col := Color(HIVE_VEIN.r, HIVE_VEIN.g, HIVE_VEIN.b, pulse)
		draw_arc(center, radius, a0, a0 + arc_len * 1.1, 8, vein_col, width, true)

func _draw_spore_circle(center: Vector2, radius: float, width: float) -> void:
	# Ghostly teal fill
	draw_circle(center, radius, SPORE_CORE)
	# Faint continuous underglow
	draw_arc(center, radius, 0.0, TAU, 128, Color(SPORE_DOT.r, SPORE_DOT.g, SPORE_DOT.b, 0.15), width * 2.0, true)
	# Alternating arc segments swap visibility
	var arc_steps: int = 24
	var arc_len: float = TAU / float(arc_steps)
	for i in range(arc_steps):
		var a0: float = arc_len * float(i)
		var vis: int = (i + int(time * 2.4)) % 2
		var seg_col: Color = SPORE_DOT if vis == 0 else SPORE_DOT_ALT
		seg_col.a = 0.7
		draw_arc(center, radius, a0, a0 + arc_len * 1.1, 8, seg_col, width, true)
	# Wandering highlight
	var wander: Vector2 = center + Vector2(cos(time * 0.7) * 6.0, sin(time * 0.9) * 6.0)
	draw_circle(wander, 3.0, Color(1, 1, 1, 0.3 + sin(time * 2.0) * 0.2))
