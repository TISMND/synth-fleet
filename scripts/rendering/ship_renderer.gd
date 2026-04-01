class_name ShipRenderer
extends Node2D
## Full-size ship renderer with banking, chrome+neon modes, all ships.
## Extracted from ships_screen.gd _ShipDraw for reuse across the codebase.

enum RenderMode { NEON, CHROME, VOID, HIVEMIND, SPORE, EMBER, FROST, SOLAR, SPORT, GUNMETAL, MILITIA, STEALTH }

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

# Gunmetal palette (dark steel, no color accents)
const GUNMETAL_HULL := Color(0.2, 0.22, 0.25)
const GUNMETAL_ACCENT := Color(0.35, 0.37, 0.4)
const GUNMETAL_ENGINE := Color(0.7, 0.5, 0.2)
const GUNMETAL_CANOPY := Color(0.1, 0.12, 0.16)
const GUNMETAL_DETAIL := Color(0.45, 0.47, 0.5)

# Militia palette (dark army green)
const MILITIA_HULL := Color(0.12, 0.18, 0.08)
const MILITIA_ACCENT := Color(0.22, 0.28, 0.14)
const MILITIA_ENGINE := Color(0.7, 0.5, 0.15)
const MILITIA_CANOPY := Color(0.08, 0.1, 0.05)
const MILITIA_DETAIL := Color(0.3, 0.35, 0.2)

# Stealth palette (matte black + blood red)
const STEALTH_HULL := Color(0.1, 0.1, 0.12)
const STEALTH_ACCENT := Color(0.7, 0.05, 0.05)
const STEALTH_ENGINE := Color(0.5, 0.08, 0.03)
const STEALTH_CANOPY := Color(0.06, 0.06, 0.08)
const STEALTH_DETAIL := Color(0.3, 0.08, 0.08)

# Spore palette
const SPORE_CORE := Color(0.0, 0.8, 0.5, 0.12)
const SPORE_DOT := Color(0.2, 1.0, 0.7)
const SPORE_DOT_ALT := Color(0.8, 0.3, 1.0)

var hull_color := Color(0.0, 0.9, 1.0)
var accent_color := Color(1.0, 0.2, 0.6)
var engine_color := Color(1.0, 0.5, 0.1)
var canopy_color := Color(0.4, 0.2, 1.0)
var detail_color := Color(0.0, 1.0, 0.7)
# Tintable chrome band colors — overridden per-skin in _apply_palette()
var _chrome_dark := CHROME_DARK
var _chrome_mid := CHROME_MID
var _chrome_light := CHROME_LIGHT
var _chrome_bright := CHROME_BRIGHT
var bank := 0.0
var ship_id := 0
var render_mode: int = RenderMode.NEON
var time := 0.0
var enemy_visual_id: String = ""
var animate: bool = true
var hit_flash: float = 0.0
var hull_flash_duration: float = 0.1
var hull_blink_speed: float = 8.0
var hull_flash_opacity: float = 0.5
var show_hardpoint_marker: bool = false  # Editor-only: draw crosshair at weapon fire origin
var hardpoint_marker_offsets: Array = []  # Array of [x, y] — empty draws at center only
var _flash_material: ShaderMaterial = null

const _FLASH_SHADER_CODE := "shader_type canvas_item;
uniform float flash_mix : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.rgb = mix(col.rgb, vec3(1.0), flash_mix);
	COLOR = col;
}"


func _ready() -> void:
	var shader := Shader.new()
	shader.code = _FLASH_SHADER_CODE
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	material = _flash_material


func trigger_hull_flash(duration: float = -1.0) -> void:
	if duration > 0.0:
		hull_flash_duration = duration
	hit_flash = hull_flash_duration


func _process(delta: float) -> void:
	# Hull flash (white blink, shader-masked to ship shape)
	if hit_flash > 0.0:
		hit_flash -= delta
		var t: float = clampf(hit_flash / maxf(hull_flash_duration, 0.001), 0.0, 1.0)
		var on: bool = fmod(t * hull_blink_speed, 2.0) > 1.0
		_flash_material.set_shader_parameter("flash_mix", hull_flash_opacity if on else 0.0)
		if hit_flash <= 0.0:
			hit_flash = 0.0
			_flash_material.set_shader_parameter("flash_mix", 0.0)
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
	if _is_chrome_based():
		_draw_chrome_polygon(points, color, bank)
		return
	match render_mode:
		RenderMode.VOID: _draw_void_polygon(points, width)
		RenderMode.HIVEMIND: _draw_hivemind_polygon(points, width)
		RenderMode.SPORE: _draw_spore_polygon(points, width)
		RenderMode.GUNMETAL: _draw_gunmetal_polygon(points, color, width)
		RenderMode.MILITIA: _draw_militia_polygon(points, width)
		RenderMode.STEALTH: _draw_stealth_polygon(points, width)
		_: _draw_neon_polygon(points, color, width)

func _circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	if _is_chrome_based():
		var pts: PackedVector2Array = _make_circle_points(center, radius, 64)
		_draw_chrome_polygon(pts, color, bank)
		return
	match render_mode:
		RenderMode.VOID: _draw_void_circle(center, radius, width)
		RenderMode.HIVEMIND: _draw_hivemind_circle(center, radius, width)
		RenderMode.SPORE: _draw_spore_circle(center, radius, width)
		RenderMode.GUNMETAL:
			var pts: PackedVector2Array = _make_circle_points(center, radius, 48)
			_draw_gunmetal_polygon(pts, color, width)
		RenderMode.MILITIA:
			var pts: PackedVector2Array = _make_circle_points(center, radius, 48)
			_draw_militia_polygon(pts, width)
		RenderMode.STEALTH:
			var pts: PackedVector2Array = _make_circle_points(center, radius, 48)
			_draw_stealth_polygon(pts, width)
		_: _draw_neon_circle(center, radius, color, width)

func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if _is_chrome_based():
		_draw_chrome_line(a, b, color, width)
		return
	match render_mode:
		RenderMode.VOID: _draw_void_line(a, b, width)
		RenderMode.HIVEMIND: _draw_hivemind_line(a, b, width)
		RenderMode.SPORE: _draw_spore_line(a, b, width)
		RenderMode.GUNMETAL: _draw_gunmetal_line(a, b, color, width)
		RenderMode.MILITIA: _draw_militia_line(a, b, width)
		RenderMode.STEALTH: _draw_stealth_line(a, b, width)
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
		RenderMode.CHROME, RenderMode.GUNMETAL, RenderMode.MILITIA, RenderMode.STEALTH:
			_draw_chrome_canopy(points, bank)
			return
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
				var dot_pulse: float = 0.5 + sin(time * 1.2 + float(i) * 2.3) * 0.5
				var dot_blend: float = sin(time * 0.3 + float(i) * 1.4) * 0.5 + 0.5
				draw_circle(points[i], 2.0 * dot_pulse, SPORE_DOT.lerp(SPORE_DOT_ALT, dot_blend))
		_:
			var cf := canopy_color
			cf.a = 0.3
			draw_colored_polygon(points, cf)
			_draw_neon_lines(points, canopy_color, 1.2 * 1.4)

func _exhaust_line(a: Vector2, b: Vector2, width: float) -> void:
	match render_mode:
		RenderMode.CHROME, RenderMode.GUNMETAL, RenderMode.MILITIA, RenderMode.STEALTH:
			_draw_chrome_line(a, b, engine_color, width)
			return
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
			var hue: float = fmod(time * 0.15, 1.0)
			hull_color = Color.from_hsv(hue, 0.9, 1.0)
			accent_color = Color.from_hsv(fmod(hue + 0.3, 1.0), 0.85, 1.0)
			engine_color = Color.from_hsv(fmod(hue + 0.15, 1.0), 0.8, 1.0)
			canopy_color = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 1.0)
			detail_color = Color.from_hsv(fmod(hue + 0.6, 1.0), 0.75, 1.0)
		RenderMode.GUNMETAL:
			hull_color = GUNMETAL_HULL
			accent_color = GUNMETAL_ACCENT
			engine_color = GUNMETAL_ENGINE
			canopy_color = GUNMETAL_CANOPY
			detail_color = GUNMETAL_DETAIL
			_chrome_dark = Color(0.08, 0.09, 0.1)
			_chrome_mid = Color(0.18, 0.19, 0.22)
			_chrome_light = Color(0.3, 0.32, 0.36)
			_chrome_bright = Color(0.42, 0.44, 0.48)
		RenderMode.MILITIA:
			hull_color = MILITIA_HULL
			accent_color = MILITIA_ACCENT
			engine_color = MILITIA_ENGINE
			canopy_color = MILITIA_CANOPY
			detail_color = MILITIA_DETAIL
			_chrome_dark = Color(0.06, 0.08, 0.04)
			_chrome_mid = Color(0.12, 0.16, 0.08)
			_chrome_light = Color(0.2, 0.25, 0.14)
			_chrome_bright = Color(0.28, 0.32, 0.18)
		RenderMode.STEALTH:
			hull_color = STEALTH_HULL
			accent_color = STEALTH_ACCENT
			engine_color = STEALTH_ENGINE
			canopy_color = STEALTH_CANOPY
			detail_color = STEALTH_DETAIL
			_chrome_dark = Color(0.04, 0.04, 0.05)
			_chrome_mid = Color(0.09, 0.09, 0.11)
			_chrome_light = Color(0.14, 0.14, 0.17)
			_chrome_bright = Color(0.20, 0.20, 0.24)
		_:
			hull_color = Color(0.0, 0.9, 1.0)
			accent_color = Color(1.0, 0.2, 0.6)
			engine_color = Color(1.0, 0.5, 0.1)
			canopy_color = Color(0.4, 0.2, 1.0)
			detail_color = Color(0.0, 1.0, 0.7)
			_chrome_dark = CHROME_DARK
			_chrome_mid = CHROME_MID
			_chrome_light = CHROME_LIGHT
			_chrome_bright = CHROME_BRIGHT


func _is_chrome_based() -> bool:
	return render_mode == RenderMode.CHROME


func _draw() -> void:
	_apply_palette()
	if ship_id == -1:
		_draw_enemy_ship()
	else:
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

	if show_hardpoint_marker:
		_draw_hardpoint_marker()

func _draw_hardpoint_marker() -> void:
	## Editor-only crosshairs at weapon fire origins.
	var offsets: Array = hardpoint_marker_offsets
	if offsets.size() == 0:
		offsets = [[0, 0]]
	for offset in offsets:
		var ox: float = float(offset[0]) if offset is Array and offset.size() >= 1 else 0.0
		var oy: float = float(offset[1]) if offset is Array and offset.size() >= 2 else 0.0
		var c := Vector2(ox, oy)
		_draw_single_hardpoint_marker(c)

func _draw_single_hardpoint_marker(c: Vector2) -> void:
	var arm: float = 10.0
	var gap: float = 3.0
	var col := Color(1.0, 0.3, 0.2, 0.9)
	var thin_col := Color(1.0, 0.3, 0.2, 0.4)
	# Crosshair arms with center gap
	draw_line(c + Vector2(0, -arm), c + Vector2(0, -gap), col, 1.5)
	draw_line(c + Vector2(0, gap), c + Vector2(0, arm), col, 1.5)
	draw_line(c + Vector2(-arm, 0), c + Vector2(-gap, 0), col, 1.5)
	draw_line(c + Vector2(gap, 0), c + Vector2(arm, 0), col, 1.5)
	# Diamond reticle
	var dr: float = 6.0
	draw_line(c + Vector2(0, -dr), c + Vector2(dr, 0), thin_col, 1.0)
	draw_line(c + Vector2(dr, 0), c + Vector2(0, dr), thin_col, 1.0)
	draw_line(c + Vector2(0, dr), c + Vector2(-dr, 0), thin_col, 1.0)
	draw_line(c + Vector2(-dr, 0), c + Vector2(0, -dr), thin_col, 1.0)
	# Center dot
	draw_circle(c, 1.5, col)


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
		"monolith": _draw_monolith()
		"nexus": _draw_nexus()
		"pylon": _draw_pylon()
		"aegis": _draw_aegis()
		"helix": _draw_helix()
		"shard": _draw_shard()
		"conduit": _draw_conduit()
		"archon_core": _draw_archon_core()
		"archon_wing_l": _draw_archon_wing(-1.0)
		"archon_wing_r": _draw_archon_wing(1.0)
		"archon_turret": _draw_archon_turret()
		"dreadnought": _draw_dreadnought()
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

func _draw_shard() -> void:
	var s := 1.0
	# Sleek diamond hull — tall and narrow
	var diamond := PackedVector2Array([
		Vector2(0, 16 * s),      # Nose (bottom = forward for enemies)
		Vector2(7 * s, 0),       # Right flank
		Vector2(0, -14 * s),     # Tail
		Vector2(-7 * s, 0),      # Left flank
	])
	_poly(diamond, hull_color, 1.4 * s)

	# Inner accent diamond (slightly inset)
	var inner := PackedVector2Array([
		Vector2(0, 10 * s),
		Vector2(4 * s, 0),
		Vector2(0, -9 * s),
		Vector2(-4 * s, 0),
	])
	_poly(inner, accent_color, 0.8 * s)

	# Rotating square core — the spinning guts
	var spin: float = time * 1.6
	var core_r: float = 3.5 * s
	var sq := PackedVector2Array()
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + spin
		sq.append(Vector2(cos(angle) * core_r, sin(angle) * core_r))
	_poly(sq, detail_color, 1.0 * s)

	# Pulsing center pip
	var pulse: float = 0.5 + sin(time * 5.0) * 0.5
	var pip_col := Color(1.0, 1.0, 1.0, 0.7 * pulse)
	draw_circle(Vector2.ZERO, 1.5 * s, pip_col)

	# Tiny engine flicker at tail
	var eng_pulse: float = 0.6 + sin(time * 7.0) * 0.4
	var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, eng_pulse)
	draw_circle(Vector2(0, -12 * s), 2.0 * s, Color(eng_col.r, eng_col.g, eng_col.b, 0.25 * eng_pulse))
	draw_circle(Vector2(0, -12 * s), 1.2 * s, eng_col)

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
	# Organic jellyfish — dome cap pointing forward (+Y), tentacles trailing behind (-Y)
	var s := 3.2
	var breath: float = sin(time * 1.2) * 0.08
	var dome_r: float = 16.0 * s
	var dome_base_y: float = 4.0 * s  # flat opening where tentacles attach

	# Bell dome — semicircle with rounded cap forward (+Y)
	var dome := PackedVector2Array()
	for i in range(17):
		var angle: float = PI + PI * float(i) / 16.0  # PI to TAU = right-to-left across bottom
		dome.append(Vector2(cos(angle) * dome_r, dome_base_y + sin(angle) * dome_r * -0.7))
	_poly(dome, hull_color, 2.0 * s)

	# Internal organ glow — inside the bell (between base and cap)
	var organ_pulse: float = 0.3 + sin(time * 1.8) * 0.2
	draw_circle(Vector2(-4 * s, dome_base_y + 6 * s), 5.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, organ_pulse * 0.4))
	draw_circle(Vector2(3 * s, dome_base_y + 10 * s), 4.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, organ_pulse * 0.5))
	draw_circle(Vector2(-1 * s, dome_base_y + 14 * s), 3.0 * s, Color(detail_color.r, detail_color.g, detail_color.b, organ_pulse * 0.6))

	# Bioluminescent vein lines inside bell
	for i in range(5):
		var vx: float = lerpf(-12.0, 12.0, float(i) / 4.0) * s
		var vein_wave: float = sin(time * 1.5 + float(i) * 0.8) * 2.0 * s
		var vein_alpha: float = 0.2 + sin(time * 2.0 + float(i)) * 0.15
		_line(
			Vector2(vx + vein_wave, dome_base_y + 4 * s),
			Vector2(vx * 0.7 + vein_wave * 0.5, dome_base_y + 16 * s),
			Color(detail_color.r, detail_color.g, detail_color.b, vein_alpha), 0.6 * s
		)

	# Trailing tentacles — trail behind (-Y), fast propulsion wave
	var tentacle_count: int = 7
	for t in range(tentacle_count):
		var tx: float = lerpf(-14.0, 14.0, float(t) / float(tentacle_count - 1)) * s
		var phase: float = float(t) * 0.9 + time * 4.0
		var length: float = (20.0 + sin(time * 0.7 + float(t)) * 4.0) * s
		var seg_count: int = 8
		var prev := Vector2(tx, dome_base_y)
		for seg in range(1, seg_count + 1):
			var frac: float = float(seg) / float(seg_count)
			var wave_x: float = sin(phase + frac * 4.0) * (4.0 + frac * 6.0) * s * (1.0 + breath)
			var ny: float = dome_base_y - frac * length
			var curr := Vector2(tx + wave_x, ny)
			var seg_alpha: float = 1.0 - frac * 0.6
			var w: float = (1.4 - frac * 0.8) * s
			_line(prev, curr, Color(hull_color.r, hull_color.g, hull_color.b, seg_alpha), w)
			prev = curr
		# Tentacle tip glow
		var tip_pulse: float = 0.4 + sin(time * 3.0 + float(t) * 1.3) * 0.4
		draw_circle(prev, 1.5 * s, Color(accent_color.r, accent_color.g, accent_color.b, tip_pulse))

	# Bell rim highlight — along the flat opening edge
	for i in range(16):
		var angle: float = PI + PI * float(i) / 15.0
		var rim_pulse: float = 0.3 + sin(time * 2.0 + float(i) * 0.5) * 0.3
		var pt := Vector2(cos(angle) * dome_r, dome_base_y)
		draw_circle(pt, 1.2 * s, Color(detail_color.r, detail_color.g, detail_color.b, rim_pulse))


func _draw_marauder() -> void:
	# Geometric — rotating concentric pentagons with orbiting satellites
	var s := 3.0
	var outer_r: float = 18.0 * s
	var mid_r: float = 11.0 * s
	var inner_r: float = 5.0 * s

	# Outer pentagon — slow rotation
	var spin1: float = time * 0.3
	var outer_pts := PackedVector2Array()
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + spin1
		outer_pts.append(Vector2(cos(angle) * outer_r, sin(angle) * outer_r))
	_poly(outer_pts, hull_color, 1.8 * s)

	# Mid pentagon — counter-rotation, slightly faster
	var spin2: float = -time * 0.55
	var mid_pts := PackedVector2Array()
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + spin2
		mid_pts.append(Vector2(cos(angle) * mid_r, sin(angle) * mid_r))
	_poly(mid_pts, accent_color, 1.4 * s)

	# Inner pentagon — fast rotation
	var spin3: float = time * 0.9
	var inner_pts := PackedVector2Array()
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + spin3
		inner_pts.append(Vector2(cos(angle) * inner_r, sin(angle) * inner_r))
	_poly(inner_pts, detail_color, 1.2 * s)

	# Connecting spokes — outer vertices to mid vertices (animated alpha)
	for i in range(5):
		var spoke_alpha: float = 0.2 + sin(time * 1.5 + float(i) * 1.2) * 0.2
		_line(outer_pts[i], mid_pts[i], Color(detail_color.r, detail_color.g, detail_color.b, spoke_alpha), 0.6 * s)

	# Orbiting satellite nodes — 3 nodes at different orbital speeds
	for sat in range(3):
		var orbit_r: float = (22.0 + float(sat) * 3.0) * s
		var orbit_speed: float = 0.7 + float(sat) * 0.35
		var orbit_angle: float = time * orbit_speed + float(sat) * TAU / 3.0
		var sat_pos := Vector2(cos(orbit_angle) * orbit_r, sin(orbit_angle) * orbit_r)
		var sat_pulse: float = 0.5 + sin(time * 3.0 + float(sat) * 2.0) * 0.4

		# Satellite body — small triangle
		var sat_pts := PackedVector2Array()
		var sat_r: float = 3.0 * s
		for i in range(3):
			var a: float = TAU * float(i) / 3.0 + orbit_angle * 2.0
			sat_pts.append(sat_pos + Vector2(cos(a) * sat_r, sin(a) * sat_r))
		_poly(sat_pts, accent_color, 1.0 * s)

		# Tether line to center
		_line(Vector2.ZERO, sat_pos, Color(hull_color.r, hull_color.g, hull_color.b, 0.15), 0.4 * s)

		# Satellite glow
		draw_circle(sat_pos, 2.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, sat_pulse * 0.5))

	# Center core — pulsing
	var core_pulse: float = 0.6 + sin(time * 2.5) * 0.4
	draw_circle(Vector2.ZERO, 3.5 * s, Color(detail_color.r, detail_color.g, detail_color.b, 0.3 * core_pulse))
	draw_circle(Vector2.ZERO, 2.0 * s, Color(1.0, 1.0, 1.0, 0.8 * core_pulse))


func _draw_ironclad() -> void:
	# Cuttlefish-inspired — torpedo body with rippling side fins and front tendrils
	var s := 3.4

	# Central mantle — tapered oval, pointed aft, rounded forward
	var mantle := PackedVector2Array()
	var mantle_pts: int = 20
	for i in range(mantle_pts):
		var angle: float = TAU * float(i) / float(mantle_pts)
		# Elongated vertically, narrower horizontally, tapered toward -Y (aft)
		var rx: float = 8.0 * s
		var ry: float = 16.0 * s
		# Taper the aft end narrower
		var y_raw: float = sin(angle)
		if y_raw < 0.0:
			rx *= (1.0 + y_raw * 0.5)  # narrows toward aft
		mantle.append(Vector2(cos(angle) * rx, y_raw * ry))
	_poly(mantle, hull_color, 2.0 * s)

	# Rippling side fins — undulating wave traveling front-to-back along each side
	for side in [-1.0, 1.0]:
		var fin_segs: int = 14
		var prev_fin := Vector2(side * 7.5 * s, 14.0 * s)
		for seg in range(1, fin_segs + 1):
			var frac: float = float(seg) / float(fin_segs)
			var fy: float = lerpf(14.0, -14.0, frac) * s
			# Traveling wave — ripples move from front to back
			var wave: float = sin(time * 4.0 - frac * 6.0) * (4.0 + sin(frac * PI) * 4.0) * s
			# Fin width peaks at mid-body, tapers at both ends
			var fin_width: float = sin(frac * PI) * 10.0 * s
			var fx: float = side * (7.5 * s + fin_width + wave * 0.5)
			var curr_fin := Vector2(fx, fy)
			var fin_alpha: float = 0.6 + sin(frac * PI) * 0.3
			_line(prev_fin, curr_fin, Color(hull_color.r, hull_color.g, hull_color.b, fin_alpha), 1.2 * s)
			prev_fin = curr_fin
			# Fin membrane — connecting line back to body edge
			if seg % 2 == 0:
				var body_x: float = side * 7.5 * s * (1.0 - absf(lerpf(-1.0, 1.0, frac)) * 0.3)
				_line(Vector2(body_x, fy), curr_fin, Color(detail_color.r, detail_color.g, detail_color.b, 0.15), 0.4 * s)

	# Chromatophore patterns — color-shifting spots along the mantle
	for i in range(6):
		var spot_y: float = lerpf(10.0, -10.0, float(i) / 5.0) * s
		for side in [-1.0, 1.0]:
			var spot_x: float = side * (2.0 + sin(float(i) * 1.5) * 2.0) * s
			# Color shifts between accent and detail over time
			var shift: float = sin(time * 1.5 + float(i) * 0.9 + side) * 0.5 + 0.5
			var spot_col := Color(
				lerpf(accent_color.r, detail_color.r, shift),
				lerpf(accent_color.g, detail_color.g, shift),
				lerpf(accent_color.b, detail_color.b, shift)
			)
			var spot_pulse: float = 0.2 + sin(time * 2.5 + float(i) * 1.2) * 0.2
			draw_circle(Vector2(spot_x, spot_y), 1.8 * s, Color(spot_col.r, spot_col.g, spot_col.b, spot_pulse))

	# Internal cuttlebone line — faint central structure
	var bone_alpha: float = 0.2 + sin(time * 0.8) * 0.1
	_line(Vector2(0, 12.0 * s), Vector2(0, -12.0 * s), Color(detail_color.r, detail_color.g, detail_color.b, bone_alpha), 0.8 * s)
	for i in range(5):
		var by: float = lerpf(10.0, -10.0, float(i) / 4.0) * s
		var bw: float = (4.0 - absf(lerpf(-1.0, 1.0, float(i) / 4.0)) * 2.0) * s
		_line(Vector2(-bw, by), Vector2(bw, by), Color(detail_color.r, detail_color.g, detail_color.b, bone_alpha * 0.7), 0.4 * s)

	# Front tendrils — 4 pairs, short, animated
	var tendril_pairs: int = 4
	for t in range(tendril_pairs):
		var spread: float = (float(t) + 0.5) / float(tendril_pairs)  # 0.125 to 0.875
		for side in [-1.0, 1.0]:
			var base_x: float = side * spread * 6.0 * s
			var base_y: float = 16.0 * s
			var phase: float = time * 3.5 + float(t) * 1.2 + side * 0.7
			var seg_count: int = 5
			var prev := Vector2(base_x, base_y)
			for seg in range(1, seg_count + 1):
				var frac: float = float(seg) / float(seg_count)
				var wave_x: float = sin(phase + frac * 3.0) * (1.0 + frac * 2.5) * s * side
				var ny: float = base_y + frac * 12.0 * s
				var curr := Vector2(base_x + wave_x, ny)
				var seg_alpha: float = 0.8 - frac * 0.4
				var tw: float = (1.0 - frac * 0.6) * s
				_line(prev, curr, Color(accent_color.r, accent_color.g, accent_color.b, seg_alpha), tw)
				prev = curr

	# Eyes — large, set back on mantle sides
	for side in [-1.0, 1.0]:
		var eye_pos := Vector2(side * 6.5 * s, 6.0 * s)
		draw_circle(eye_pos, 3.0 * s, Color(hull_color.r, hull_color.g, hull_color.b, 0.5))
		draw_circle(eye_pos, 2.0 * s, Color(detail_color.r, detail_color.g, detail_color.b, 0.4))
		# W-shaped cuttlefish pupil — two dots
		var pupil_spread: float = 0.8 * s
		draw_circle(eye_pos + Vector2(-pupil_spread * 0.5, 0), 0.8 * s, Color(0.0, 0.0, 0.0, 0.9))
		draw_circle(eye_pos + Vector2(pupil_spread * 0.5, 0), 0.8 * s, Color(0.0, 0.0, 0.0, 0.9))


func _draw_wraith() -> void:
	# Geometric — phase-shifting diamond lattice, parts fade in/out
	var s := 3.0
	var phase_cycle: float = fmod(time * 0.4, 1.0)

	# Diamond lattice — 4 nested diamonds at different rotations
	for ring in range(4):
		var ring_r: float = (6.0 + float(ring) * 6.0) * s
		var ring_spin: float = time * (0.2 + float(ring) * 0.15) * (1.0 if ring % 2 == 0 else -1.0)
		# Phase visibility — each ring fades in/out at different times
		var ring_phase: float = fmod(phase_cycle + float(ring) * 0.25, 1.0)
		var ring_alpha: float = 0.3 + sin(ring_phase * TAU) * 0.35 + 0.35

		var diamond := PackedVector2Array()
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0 + ring_spin
			diamond.append(Vector2(cos(angle) * ring_r, sin(angle) * ring_r))

		var ring_col: Color
		if ring == 0:
			ring_col = detail_color
		elif ring % 2 == 0:
			ring_col = accent_color
		else:
			ring_col = hull_color
		ring_col.a = ring_alpha
		_poly(diamond, ring_col, (1.0 + float(ring) * 0.2) * s)

		# Vertex nodes — glow dots at diamond corners
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0 + ring_spin
			var pt := Vector2(cos(angle) * ring_r, sin(angle) * ring_r)
			var node_pulse: float = 0.3 + sin(time * 3.0 + float(ring) * 1.5 + float(i) * 1.0) * 0.4
			draw_circle(pt, 1.5 * s, Color(detail_color.r, detail_color.g, detail_color.b, node_pulse * ring_alpha))

	# Phase-shift streaks — ghostly afterimages trailing behind each ring
	for streak in range(3):
		var streak_delay: float = float(streak + 1) * 0.12
		var streak_alpha: float = 0.08 - float(streak) * 0.025
		var streak_r: float = 18.0 * s
		var streak_spin: float = time * 0.35 - streak_delay
		var streak_pts := PackedVector2Array()
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0 + streak_spin
			streak_pts.append(Vector2(cos(angle) * streak_r, sin(angle) * streak_r))
		_poly(streak_pts, Color(hull_color.r, hull_color.g, hull_color.b, streak_alpha), 0.8 * s)

	# Cross-lattice connections — lines connecting rings at matching angles
	for i in range(4):
		var base_angle: float = TAU * float(i) / 4.0
		var inner := Vector2(cos(base_angle + time * 0.2) * 6.0 * s, sin(base_angle + time * 0.2) * 6.0 * s)
		var outer := Vector2(cos(base_angle + time * 0.5) * 24.0 * s, sin(base_angle + time * 0.5) * 24.0 * s)
		var conn_alpha: float = 0.1 + sin(time * 2.0 + float(i) * 1.5) * 0.1
		_line(inner, outer, Color(accent_color.r, accent_color.g, accent_color.b, conn_alpha), 0.4 * s)

	# Central void — pulsing dark/bright core
	var core_breath: float = sin(time * 1.5)
	var core_bright: float = 0.5 + core_breath * 0.4
	draw_circle(Vector2.ZERO, 4.0 * s, Color(0.0, 0.0, 0.0, 0.6))
	draw_circle(Vector2.ZERO, 2.5 * s, Color(accent_color.r, accent_color.g, accent_color.b, core_bright * 0.4))
	draw_circle(Vector2.ZERO, 1.2 * s, Color(1.0, 1.0, 1.0, core_bright))


func _draw_colossus() -> void:
	# Organic — massive eye/maw creature with radiating tendrils, breathing
	var s := 3.6
	var breath: float = sin(time * 0.8)
	var breath_scale: float = 1.0 + breath * 0.05

	# Main body mass — irregular blobby shape (breathing)
	var body := PackedVector2Array()
	var body_pts: int = 20
	for i in range(body_pts):
		var angle: float = TAU * float(i) / float(body_pts)
		var base_r: float = 18.0 * s
		# Organic wobble — different lobes
		var wobble: float = sin(angle * 3.0 + time * 0.5) * 3.0 * s
		var wobble2: float = cos(angle * 2.0 - time * 0.3) * 2.0 * s
		var r: float = (base_r + wobble + wobble2) * breath_scale
		body.append(Vector2(cos(angle) * r, sin(angle) * r))
	_poly(body, hull_color, 2.2 * s)

	# Inner membrane layers — pulsing translucent rings
	for ring in range(3):
		var ring_r: float = (12.0 - float(ring) * 3.5) * s * breath_scale
		var ring_alpha: float = 0.1 + float(ring) * 0.05 + sin(time * 1.5 + float(ring)) * 0.05
		var membrane := PackedVector2Array()
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			var mr: float = ring_r + sin(angle * 4.0 + time * (1.0 + float(ring) * 0.3)) * 1.5 * s
			membrane.append(Vector2(cos(angle) * mr, sin(angle) * mr))
		_poly(membrane, Color(accent_color.r, accent_color.g, accent_color.b, ring_alpha), 0.8 * s)

	# Central eye / maw — layered concentric circles
	var eye_r: float = 8.0 * s
	var iris_r: float = 5.0 * s * (0.9 + sin(time * 2.0) * 0.1)
	var pupil_r: float = 2.5 * s * (0.8 + sin(time * 1.5 + 0.5) * 0.2)

	# Eye socket glow
	draw_circle(Vector2.ZERO, eye_r + 2.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, 0.15))
	# Iris — colored ring
	draw_arc(Vector2.ZERO, iris_r, 0.0, TAU, 64, accent_color, 2.5 * s, true)
	draw_arc(Vector2.ZERO, iris_r * 0.7, 0.0, TAU, 64, Color(accent_color.r, accent_color.g, accent_color.b, 0.5), 1.5 * s, true)
	# Pupil
	draw_circle(Vector2.ZERO, pupil_r, Color(0.0, 0.0, 0.0, 0.9))
	# Pupil glint
	var glint_offset := Vector2(sin(time * 0.7) * 1.0 * s, cos(time * 0.9) * 0.8 * s)
	draw_circle(glint_offset, 1.0 * s, Color(1.0, 1.0, 1.0, 0.8))

	# Radiating tendrils — organic, sinuous, variable length
	var tendril_count: int = 9
	for t in range(tendril_count):
		var base_angle: float = TAU * float(t) / float(tendril_count) + sin(time * 0.3) * 0.05
		var tendril_len: float = (22.0 + sin(time * 0.6 + float(t) * 0.7) * 6.0) * s
		var seg_count: int = 10
		var phase: float = float(t) * 1.1 + time * 1.8

		var prev := Vector2(cos(base_angle) * 16.0 * s * breath_scale, sin(base_angle) * 16.0 * s * breath_scale)
		for seg in range(1, seg_count + 1):
			var frac: float = float(seg) / float(seg_count)
			var wave: float = sin(phase + frac * 4.0) * (2.0 + frac * 5.0) * s
			# Perpendicular wave offset
			var tangent := Vector2(-sin(base_angle), cos(base_angle))
			var radial := Vector2(cos(base_angle), sin(base_angle))
			var dist: float = 16.0 * s * breath_scale + frac * tendril_len
			var curr: Vector2 = radial * dist + tangent * wave

			var seg_alpha: float = 1.0 - frac * 0.7
			var w: float = (2.0 - frac * 1.4) * s
			_line(prev, curr, Color(hull_color.r, hull_color.g, hull_color.b, seg_alpha), w)
			prev = curr

		# Tendril tip — pulsing node
		var tip_pulse: float = 0.3 + sin(time * 2.5 + float(t) * 0.9) * 0.4
		draw_circle(prev, 2.0 * s, Color(detail_color.r, detail_color.g, detail_color.b, tip_pulse))

	# Vein network — short connecting lines between nearby tendril bases
	for t in range(tendril_count):
		var a1: float = TAU * float(t) / float(tendril_count)
		var a2: float = TAU * float((t + 1) % tendril_count) / float(tendril_count)
		var p1 := Vector2(cos(a1) * 17.0 * s, sin(a1) * 17.0 * s)
		var p2 := Vector2(cos(a2) * 17.0 * s, sin(a2) * 17.0 * s)
		var vein_alpha: float = 0.15 + sin(time * 1.2 + float(t) * 0.8) * 0.1
		_line(p1, p2, Color(detail_color.r, detail_color.g, detail_color.b, vein_alpha), 0.5 * s)

func _draw_monolith() -> void:
	# Elongated slab with internal geometric machinery — rotating gears, sliding bars.
	# Diamond focal point at center for beam weapons.
	var s := 3.0
	var hw: float = 12.0 * s  # half width
	var hh: float = 28.0 * s  # half height (tall)
	var breath: float = sin(time * 0.9) * 0.03

	# Outer slab body — tall rectangle with chamfered corners
	var body := PackedVector2Array([
		Vector2(-hw + 3.0 * s, -hh),
		Vector2(hw - 3.0 * s, -hh),
		Vector2(hw, -hh + 3.0 * s),
		Vector2(hw, hh - 3.0 * s),
		Vector2(hw - 3.0 * s, hh),
		Vector2(-hw + 3.0 * s, hh),
		Vector2(-hw, hh - 3.0 * s),
		Vector2(-hw, -hh + 3.0 * s),
	])
	_poly(body, hull_color, 2.0 * s)

	# Internal gear wheels — 3 stacked, contra-rotating
	var gear_positions: Array[float] = [-16.0, 0.0, 16.0]
	var gear_radii: Array[float] = [6.0, 8.0, 6.0]
	var gear_teeth: Array[int] = [8, 10, 8]
	var gear_dirs: Array[float] = [1.0, -1.0, 1.0]
	for gi in range(3):
		var gy: float = gear_positions[gi] * s * (1.0 + breath)
		var gr: float = gear_radii[gi] * s
		var teeth: int = gear_teeth[gi]
		var spin: float = time * 1.5 * gear_dirs[gi]
		# Gear outline with teeth
		var gear := PackedVector2Array()
		for t in range(teeth * 2):
			var angle: float = TAU * float(t) / float(teeth * 2) + spin
			var tr: float = gr if t % 2 == 0 else gr * 0.7
			gear.append(Vector2(cos(angle) * tr, gy + sin(angle) * tr))
		_poly(gear, accent_color, 1.0 * s)
		# Axle
		draw_circle(Vector2(0, gy), 2.0 * s, Color(detail_color.r, detail_color.g, detail_color.b, 0.6))

	# Sliding horizontal bars — oscillate left/right at different phases
	for bi in range(5):
		var by: float = (-20.0 + float(bi) * 10.0) * s
		var slide: float = sin(time * 2.0 + float(bi) * 1.3) * 4.0 * s
		var bar_alpha: float = 0.25 + sin(time * 1.5 + float(bi)) * 0.1
		_line(
			Vector2(-hw + 2.0 * s + slide, by),
			Vector2(hw - 2.0 * s + slide, by),
			Color(detail_color.r, detail_color.g, detail_color.b, bar_alpha), 0.6 * s
		)

	# Diamond focal point — center, pulsing, beam emitter
	var dp: float = 0.7 + sin(time * 2.5) * 0.3
	var diamond_r: float = 5.0 * s
	var diamond := PackedVector2Array([
		Vector2(0, diamond_r * 1.3),   # forward tip
		Vector2(diamond_r, 0),
		Vector2(0, -diamond_r * 1.3),
		Vector2(-diamond_r, 0),
	])
	_poly(diamond, Color(accent_color.r, accent_color.g, accent_color.b, dp), 1.5 * s)
	draw_circle(Vector2.ZERO, 2.5 * s, Color(1.0, 1.0, 1.0, dp * 0.8))

	# Edge channel lights
	for side in [-1.0, 1.0]:
		for li in range(6):
			var ly: float = (-22.0 + float(li) * 9.0) * s
			var lx: float = side * (hw - 1.5 * s)
			var lit: float = fmod(time * 3.0 + float(li) * 0.4, 1.0)
			var la: float = 0.2 + lit * 0.5 if lit < 0.3 else 0.1
			draw_circle(Vector2(lx, ly), 1.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, la))


func _draw_nexus() -> void:
	# Diamond-shaped body with internal churning hexagonal lattice.
	# Clear beam focal point at forward diamond tip.
	var s := 3.2
	var r_fwd: float = 30.0 * s   # forward reach (long)
	var r_aft: float = 20.0 * s   # aft reach
	var r_side: float = 16.0 * s  # side width

	# Outer diamond hull
	var hull := PackedVector2Array([
		Vector2(0, r_fwd),         # forward tip (down = +Y)
		Vector2(r_side, 0),        # right
		Vector2(0, -r_aft),        # aft
		Vector2(-r_side, 0),       # left
	])
	_poly(hull, hull_color, 2.2 * s)

	# Internal hexagonal lattice — rotating mesh of small hexagons
	var hex_count: int = 7
	var hex_positions: Array[Vector2] = [
		Vector2(0, 12.0), Vector2(0, -4.0), Vector2(0, -16.0),
		Vector2(8.0, 4.0), Vector2(-8.0, 4.0),
		Vector2(6.0, -10.0), Vector2(-6.0, -10.0),
	]
	for hi in range(hex_count):
		var hpos: Vector2 = hex_positions[hi] * s
		var hr: float = (3.5 + sin(time * 1.2 + float(hi) * 0.9) * 0.8) * s
		var hspin: float = time * (0.8 + float(hi) * 0.2) * (1.0 if hi % 2 == 0 else -1.0)
		var hex := PackedVector2Array()
		for vi in range(6):
			var angle: float = TAU * float(vi) / 6.0 + hspin
			hex.append(hpos + Vector2(cos(angle) * hr, sin(angle) * hr))
		var ha: float = 0.3 + sin(time * 2.0 + float(hi) * 1.4) * 0.2
		_poly(hex, Color(accent_color.r, accent_color.g, accent_color.b, ha), 0.8 * s)

	# Connecting lattice lines between adjacent hexagons
	var connections: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(0, 4),
		Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5), Vector2i(1, 6),
		Vector2i(2, 5), Vector2i(2, 6),
	]
	for conn in connections:
		var ca: float = 0.1 + sin(time * 1.8 + float(conn.x) * 0.7) * 0.08
		_line(
			hex_positions[conn.x] * s, hex_positions[conn.y] * s,
			Color(detail_color.r, detail_color.g, detail_color.b, ca), 0.4 * s
		)

	# Forward diamond tip — beam focal, bright pulsing
	var tip_pulse: float = 0.6 + sin(time * 3.0) * 0.4
	var tip_diamond := PackedVector2Array([
		Vector2(0, r_fwd - 2.0 * s),
		Vector2(4.0 * s, r_fwd - 10.0 * s),
		Vector2(0, r_fwd - 18.0 * s),
		Vector2(-4.0 * s, r_fwd - 10.0 * s),
	])
	_poly(tip_diamond, Color(accent_color.r, accent_color.g, accent_color.b, tip_pulse), 1.2 * s)
	draw_circle(Vector2(0, r_fwd - 10.0 * s), 2.0 * s, Color(1.0, 1.0, 1.0, tip_pulse * 0.9))

	# Aft glow
	var eng_f: float = 0.4 + sin(time * 4.5) * 0.3
	draw_circle(Vector2(0, -r_aft + 4.0 * s), 3.0 * s, Color(engine_color.r, engine_color.g, engine_color.b, eng_f))


func _draw_pylon() -> void:
	# Very tall narrow structure with multiple diamond nodes along its length.
	# Each node is a potential hardpoint mirror. Energy flows between nodes.
	var s := 2.8
	var hw: float = 6.0 * s
	var hh: float = 36.0 * s  # extremely tall

	# Central spine
	_line(Vector2(0, -hh), Vector2(0, hh), hull_color, 1.5 * s)
	# Side rails
	_line(Vector2(-hw, -hh + 4.0 * s), Vector2(-hw, hh - 4.0 * s), hull_color, 1.0 * s)
	_line(Vector2(hw, -hh + 4.0 * s), Vector2(hw, hh - 4.0 * s), hull_color, 1.0 * s)
	# Top/bottom caps
	_line(Vector2(-hw, -hh + 4.0 * s), Vector2(0, -hh), hull_color, 1.2 * s)
	_line(Vector2(hw, -hh + 4.0 * s), Vector2(0, -hh), hull_color, 1.2 * s)
	_line(Vector2(-hw, hh - 4.0 * s), Vector2(0, hh), hull_color, 1.2 * s)
	_line(Vector2(hw, hh - 4.0 * s), Vector2(0, hh), hull_color, 1.2 * s)

	# Diamond nodes — 5 evenly spaced along the spine
	var node_count: int = 5
	for ni in range(node_count):
		var ny: float = lerpf(-hh + 8.0 * s, hh - 8.0 * s, float(ni) / float(node_count - 1))
		var nr: float = (3.5 + sin(time * 1.5 + float(ni) * 1.2) * 1.0) * s
		var node_diamond := PackedVector2Array([
			Vector2(0, ny + nr * 1.4),
			Vector2(nr, ny),
			Vector2(0, ny - nr * 1.4),
			Vector2(-nr, ny),
		])
		var np: float = 0.5 + sin(time * 2.0 + float(ni) * 0.8) * 0.3
		_poly(node_diamond, Color(accent_color.r, accent_color.g, accent_color.b, np), 1.2 * s)
		draw_circle(Vector2(0, ny), 1.5 * s, Color(1.0, 1.0, 1.0, np * 0.7))

		# Cross-struts to side rails
		var strut_a: float = 0.2 + sin(time * 1.2 + float(ni) * 0.6) * 0.15
		_line(Vector2(-hw, ny), Vector2(-nr, ny), Color(detail_color.r, detail_color.g, detail_color.b, strut_a), 0.6 * s)
		_line(Vector2(hw, ny), Vector2(nr, ny), Color(detail_color.r, detail_color.g, detail_color.b, strut_a), 0.6 * s)

	# Energy flow between nodes — traveling pulse dots, alternating directions
	for ni in range(node_count - 1):
		var y0: float = lerpf(-hh + 8.0 * s, hh - 8.0 * s, float(ni) / float(node_count - 1))
		var y1: float = lerpf(-hh + 8.0 * s, hh - 8.0 * s, float(ni + 1) / float(node_count - 1))
		# Forward pulse (y0 → y1)
		var pulse_fwd: float = fmod(time * 1.5 + float(ni) * 0.5, 1.0)
		var fwd_y: float = lerpf(y0, y1, pulse_fwd)
		var fwd_a: float = sin(pulse_fwd * PI) * 0.8
		draw_circle(Vector2(-1.5 * s, fwd_y), 1.2 * s, Color(accent_color.r, accent_color.g, accent_color.b, fwd_a))
		# Return pulse (y1 → y0, offset timing)
		var pulse_rev: float = fmod(time * 1.5 + float(ni) * 0.5 + 0.5, 1.0)
		var rev_y: float = lerpf(y1, y0, pulse_rev)
		var rev_a: float = sin(pulse_rev * PI) * 0.6
		draw_circle(Vector2(1.5 * s, rev_y), 1.0 * s, Color(detail_color.r, detail_color.g, detail_color.b, rev_a))


func _draw_aegis() -> void:
	# Ship-like attempt — angular hull with bridge, engines, plating. Still neon/geometric.
	var s := 2.6
	# Main hull — angular wedge pointing forward (+Y)
	var hull := PackedVector2Array([
		Vector2(0, 28.0 * s),          # nose
		Vector2(8.0 * s, 18.0 * s),    # forward cheek R
		Vector2(12.0 * s, 4.0 * s),    # mid hull R
		Vector2(14.0 * s, -8.0 * s),   # aft hull R (widest)
		Vector2(12.0 * s, -20.0 * s),  # engine fairing R
		Vector2(6.0 * s, -24.0 * s),   # stern R
		Vector2(-6.0 * s, -24.0 * s),  # stern L
		Vector2(-12.0 * s, -20.0 * s), # engine fairing L
		Vector2(-14.0 * s, -8.0 * s),  # aft hull L
		Vector2(-12.0 * s, 4.0 * s),   # mid hull L
		Vector2(-8.0 * s, 18.0 * s),   # forward cheek L
	])
	_poly(hull, hull_color, 2.0 * s)

	# Armor plating seams
	_line(Vector2(-10.0 * s, 0), Vector2(10.0 * s, 0), detail_color, 0.6 * s)
	_line(Vector2(-12.0 * s, -10.0 * s), Vector2(12.0 * s, -10.0 * s), detail_color, 0.5 * s)
	_line(Vector2(0, 28.0 * s), Vector2(0, -20.0 * s), Color(detail_color, 0.3), 0.4 * s)

	# Bridge canopy — small diamond near front
	var bridge := PackedVector2Array([
		Vector2(0, 16.0 * s),
		Vector2(3.5 * s, 11.0 * s),
		Vector2(0, 6.0 * s),
		Vector2(-3.5 * s, 11.0 * s),
	])
	_poly(bridge, canopy_color, 1.2 * s)
	# Bridge glow
	var bg: float = 0.4 + sin(time * 1.5) * 0.2
	draw_circle(Vector2(0, 11.0 * s), 2.0 * s, Color(canopy_color.r, canopy_color.g, canopy_color.b, bg))

	# Wing weapon pods — small diamonds at widest points
	for side in [-1.0, 1.0]:
		var pod_x: float = side * 14.0 * s
		var pod := PackedVector2Array([
			Vector2(pod_x, -4.0 * s),
			Vector2(pod_x + side * 4.0 * s, -8.0 * s),
			Vector2(pod_x, -12.0 * s),
			Vector2(pod_x - side * 2.0 * s, -8.0 * s),
		])
		_poly(pod, accent_color, 1.0 * s)

	# Engine banks — 3 nozzles at stern
	var eng_positions: Array[float] = [-4.0, 0.0, 4.0]
	for ei in range(3):
		var ex: float = eng_positions[ei] * s
		var flicker: float = 0.5 + sin(time * 5.0 + float(ei) * 2.0) * 0.3 + sin(time * 8.0 + float(ei)) * 0.15
		var eng_col := Color(engine_color.r, engine_color.g, engine_color.b, flicker)
		draw_circle(Vector2(ex, -24.0 * s), 2.5 * s, eng_col)
		# Exhaust trail
		var trail_len: float = (4.0 + flicker * 3.0) * s
		_line(Vector2(ex, -24.0 * s), Vector2(ex, -24.0 * s - trail_len),
			Color(engine_color.r, engine_color.g, engine_color.b, flicker * 0.5), 1.5 * s)

	# Nose focal diamond for beam
	var nose_p: float = 0.6 + sin(time * 2.5) * 0.3
	draw_circle(Vector2(0, 26.0 * s), 2.0 * s, Color(accent_color.r, accent_color.g, accent_color.b, nose_p))


func _draw_helix() -> void:
	# Two elongated arms spiraling around a central axis with diamond core.
	# Arms churn/rotate continuously. Very alien.
	var s := 3.0
	var core_r: float = 5.0 * s
	var arm_length: float = 28.0 * s
	var arm_count: int = 2
	var coils: float = 2.5  # number of spiral wraps
	var seg_count: int = 24

	# Central diamond core — beam focal point
	var core_pulse: float = 0.6 + sin(time * 2.0) * 0.4
	var core_diamond := PackedVector2Array([
		Vector2(0, core_r * 1.5),
		Vector2(core_r, 0),
		Vector2(0, -core_r * 1.5),
		Vector2(-core_r, 0),
	])
	_poly(core_diamond, Color(accent_color.r, accent_color.g, accent_color.b, core_pulse), 1.5 * s)
	draw_circle(Vector2.ZERO, 2.0 * s, Color(1.0, 1.0, 1.0, core_pulse * 0.8))

	# Spiral arms — two helices offset by PI
	for arm in range(arm_count):
		var arm_phase: float = float(arm) * PI + time * 1.2
		var prev := Vector2.ZERO
		for seg in range(seg_count + 1):
			var t: float = float(seg) / float(seg_count)
			var y_pos: float = lerpf(-arm_length, arm_length, t)
			# Spiral radius increases from center, narrows at tips
			var envelope: float = sin(t * PI)  # 0 at ends, 1 at middle
			var spiral_r: float = (8.0 + envelope * 6.0) * s
			var angle: float = arm_phase + t * coils * TAU
			var x_pos: float = cos(angle) * spiral_r
			var curr := Vector2(x_pos, y_pos)

			if seg > 0:
				var seg_alpha: float = 0.3 + envelope * 0.5
				var w: float = (1.0 + envelope * 1.2) * s
				_line(prev, curr, Color(hull_color.r, hull_color.g, hull_color.b, seg_alpha), w)

			# Nodes at quarter-turn intervals
			if seg > 0 and seg < seg_count and seg % 6 == 0:
				var node_a: float = 0.3 + sin(time * 2.5 + float(seg)) * 0.3
				draw_circle(curr, 1.5 * s, Color(detail_color.r, detail_color.g, detail_color.b, node_a))

			prev = curr

	# Cross-braces connecting the two arms at a few points
	for bi in range(5):
		var bt: float = 0.15 + float(bi) * 0.175
		var by: float = lerpf(-arm_length, arm_length, bt)
		var envelope: float = sin(bt * PI)
		var spiral_r: float = (8.0 + envelope * 6.0) * s
		var angle1: float = time * 1.2 + bt * coils * TAU
		var angle2: float = PI + time * 1.2 + bt * coils * TAU
		var p1 := Vector2(cos(angle1) * spiral_r, by)
		var p2 := Vector2(cos(angle2) * spiral_r, by)
		var ba: float = 0.12 + sin(time * 1.5 + float(bi)) * 0.08
		_line(p1, p2, Color(detail_color.r, detail_color.g, detail_color.b, ba), 0.4 * s)


func _draw_conduit() -> void:
	# Long tubular form with internal segments that pulse and shift.
	# Diamond emitter at front. Segments flow through the tube.
	var s := 2.8
	var hw: float = 9.0 * s
	var hh: float = 32.0 * s
	var seg_count: int = 10

	# Outer tube walls — two parallel lines with end caps
	_line(Vector2(-hw, -hh), Vector2(-hw, hh), hull_color, 1.8 * s)
	_line(Vector2(hw, -hh), Vector2(hw, hh), hull_color, 1.8 * s)
	# Rounded end caps
	_arc(Vector2(0, -hh), hw, PI, TAU, 8, hull_color, 1.8 * s)
	_arc(Vector2(0, hh), hw, 0, PI, 8, hull_color, 1.8 * s)

	# Internal flowing segments — rectangles that slide through the tube
	for si in range(seg_count):
		# Each segment scrolls along the tube length, wrapping
		var seg_phase: float = fmod(time * 0.8 + float(si) / float(seg_count), 1.0)
		var seg_y: float = lerpf(-hh + 4.0 * s, hh - 4.0 * s, seg_phase)
		var seg_h: float = (3.0 + sin(time * 1.5 + float(si) * 2.0) * 1.5) * s
		var seg_w: float = (hw - 2.0 * s) * (0.6 + sin(time * 2.0 + float(si) * 0.7) * 0.3)

		# Segment rectangle
		var seg_alpha: float = 0.15 + sin(seg_phase * PI) * 0.25  # brightest in middle
		var seg_col := Color(accent_color.r, accent_color.g, accent_color.b, seg_alpha)
		var seg_rect := PackedVector2Array([
			Vector2(-seg_w, seg_y - seg_h),
			Vector2(seg_w, seg_y - seg_h),
			Vector2(seg_w, seg_y + seg_h),
			Vector2(-seg_w, seg_y + seg_h),
		])
		_poly(seg_rect, seg_col, 0.6 * s)

	# Cross-ribs — structural dividers
	for ri in range(7):
		var ry: float = lerpf(-hh + 6.0 * s, hh - 6.0 * s, float(ri) / 6.0)
		var rib_a: float = 0.15 + sin(time * 0.8 + float(ri) * 1.1) * 0.08
		_line(Vector2(-hw, ry), Vector2(hw, ry), Color(detail_color.r, detail_color.g, detail_color.b, rib_a), 0.5 * s)

	# Central channel energy — pulsing line along the spine
	var channel_a: float = 0.3 + sin(time * 2.0) * 0.2
	_line(Vector2(0, -hh + 4.0 * s), Vector2(0, hh - 4.0 * s),
		Color(accent_color.r, accent_color.g, accent_color.b, channel_a), 0.8 * s)

	# Forward diamond emitter
	var dp: float = 0.6 + sin(time * 2.5) * 0.4
	var diamond_y: float = hh - 2.0 * s
	var dr: float = 4.5 * s
	var diamond := PackedVector2Array([
		Vector2(0, diamond_y + dr * 1.3),
		Vector2(dr, diamond_y),
		Vector2(0, diamond_y - dr * 1.3),
		Vector2(-dr, diamond_y),
	])
	_poly(diamond, Color(accent_color.r, accent_color.g, accent_color.b, dp), 1.3 * s)
	draw_circle(Vector2(0, diamond_y), 2.0 * s, Color(1.0, 1.0, 1.0, dp * 0.8))

	# Aft exhaust
	var eng_f: float = 0.4 + sin(time * 5.0) * 0.3
	draw_circle(Vector2(0, -hh - 1.0 * s), 3.0 * s, Color(engine_color.r, engine_color.g, engine_color.b, eng_f))


# ── Chrome drawing helpers ──

func _draw_chrome_polygon(points: PackedVector2Array, tint_color: Color, bk: float) -> void:
	if points.size() < 3:
		return
	# Dark base fill
	draw_colored_polygon(points, _chrome_dark)

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
		_chrome_dark.lerp(_chrome_mid, 0.3),
		_chrome_mid,
		_chrome_light,
		_chrome_bright,
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
		var edge_col := _chrome_dark.lerp(CHROME_SPEC, brightness)
		edge_col.a = 0.6 + brightness * 0.4
		draw_line(a, b, edge_col, 1.5, true)

func _draw_chrome_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# Shadow offset
	var perp: Vector2 = (b - a).normalized()
	perp = Vector2(-perp.y, perp.x)
	var shadow_off: Vector2 = perp * 1.0
	draw_line(a + shadow_off, b + shadow_off, _chrome_dark, width * 1.2, true)
	# Bright highlight offset
	draw_line(a - shadow_off, b - shadow_off, _chrome_bright, width * 0.8, true)
	# Core mid-tone with color tint
	var mid := _chrome_mid.lerp(color, 0.15)
	draw_line(a, b, mid, width, true)
	# Hot specular center
	var spec_brightness: float = 0.9 + sin(time * 1.2) * 0.1
	var spec := CHROME_SPEC
	spec.a = 0.4 * spec_brightness
	draw_line(a, b, spec, width * 0.3, true)

func _draw_chrome_canopy(points: PackedVector2Array, bk: float) -> void:
	if points.size() < 3:
		return
	# Glass fill — tinted by canopy_color for military skins
	var glass := Color(canopy_color.r, canopy_color.g, canopy_color.b, 0.85)
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
	# Edge segments — slow smooth fade between teal and purple
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var blend: float = sin(time * 0.4 + float(i) * 0.9) * 0.5 + 0.5
		var seg_col: Color = SPORE_DOT.lerp(SPORE_DOT_ALT, blend)
		seg_col.a = 0.7
		draw_line(points[i], points[ni], seg_col, width, true)
	# Pulsing vertex dots — slow fade between colors
	for i in range(points.size()):
		var dot_pulse: float = 0.4 + sin(time * 1.2 + float(i) * 2.3) * 0.4
		var dot_blend: float = sin(time * 0.3 + float(i) * 1.4) * 0.5 + 0.5
		draw_circle(points[i], width * 1.0 * dot_pulse + 1.0, SPORE_DOT.lerp(SPORE_DOT_ALT, dot_blend))
	# Wandering highlight orbiting centroid
	if points.size() >= 3:
		var centroid := Vector2.ZERO
		for pt in points:
			centroid += pt
		centroid /= float(points.size())
		var wander := centroid + Vector2(cos(time * 0.7) * 6.0, sin(time * 0.9) * 6.0)
		draw_circle(wander, 3.0, Color(1, 1, 1, 0.3 + sin(time * 2.0) * 0.2))

func _draw_spore_line(a: Vector2, b: Vector2, width: float) -> void:
	# Faint underglow — slow color fade
	var line_blend: float = sin(time * 0.35) * 0.5 + 0.5
	var line_col: Color = SPORE_DOT.lerp(SPORE_DOT_ALT, line_blend)
	draw_line(a, b, Color(line_col.r, line_col.g, line_col.b, 0.2), width * 2.0, true)
	# Endpoint node circles — slow fade
	var end_blend: float = sin(time * 0.3 + 1.0) * 0.5 + 0.5
	var end_col: Color = SPORE_DOT.lerp(SPORE_DOT_ALT, end_blend)
	draw_circle(a, width * 0.8, end_col)
	draw_circle(b, width * 0.8, end_col)
	# Midpoint dot — offset phase
	var mid: Vector2 = (a + b) * 0.5
	var mid_blend: float = sin(time * 0.3 + 2.5) * 0.5 + 0.5
	draw_circle(mid, width * 0.6, SPORE_DOT.lerp(SPORE_DOT_ALT, mid_blend))

# ── Gunmetal draw helpers (matte steel + racing stripes + rivet dots) ──

func _draw_gunmetal_polygon(points: PackedVector2Array, _color: Color, width: float) -> void:
	if points.size() < 3:
		return
	# Flat matte steel fill
	draw_colored_polygon(points, GUNMETAL_HULL)

	# Bounding box
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
	var bwidth: float = max_x - min_x
	if height < 1.0 or bwidth < 1.0:
		return

	# Diagonal racing stripes — bold accent color
	var stripe_spacing: float = 18.0
	var stripe_w: float = 5.0
	var _center_x: float = (min_x + max_x) * 0.5
	var y_start: float = min_y - bwidth  # start above to cover diagonal
	var y_pos: float = y_start
	while y_pos < max_y + bwidth:
		var stripe := PackedVector2Array([
			Vector2(min_x - 5.0, y_pos),
			Vector2(max_x + 5.0, y_pos + bwidth * 0.6),
			Vector2(max_x + 5.0, y_pos + bwidth * 0.6 + stripe_w),
			Vector2(min_x - 5.0, y_pos + stripe_w),
		])
		var clipped: Array = Geometry2D.intersect_polygons(points, stripe)
		for clip_idx in range(clipped.size()):
			var clip_poly: PackedVector2Array = clipped[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(GUNMETAL_ACCENT.r, GUNMETAL_ACCENT.g, GUNMETAL_ACCENT.b, 0.5))
		y_pos += stripe_spacing

	# Subtle top-to-bottom gradient overlay for depth
	var grad_rect := PackedVector2Array([
		Vector2(min_x - 5.0, min_y),
		Vector2(max_x + 5.0, min_y),
		Vector2(max_x + 5.0, min_y + height * 0.4),
		Vector2(min_x - 5.0, min_y + height * 0.4),
	])
	var grad_clips: Array = Geometry2D.intersect_polygons(points, grad_rect)
	for clip_idx in range(grad_clips.size()):
		var clip_poly: PackedVector2Array = grad_clips[clip_idx]
		if clip_poly.size() >= 3:
			draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, 0.06))

	# Hard panel edges — thick dark outlines
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], Color(0.08, 0.08, 0.1), width * 1.8, true)
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], GUNMETAL_DETAIL, width * 0.6, true)
	# Rivet dots at vertices
	for pt in points:
		draw_circle(pt, width * 0.7, Color(0.5, 0.52, 0.55))
		draw_circle(pt, width * 0.35, Color(0.25, 0.26, 0.28))

func _draw_gunmetal_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# Dark border + bright core + rivet endpoints
	draw_line(a, b, Color(0.08, 0.08, 0.1), width * 1.6, true)
	draw_line(a, b, color, width, true)
	draw_line(a, b, GUNMETAL_DETAIL, width * 0.4, true)
	for pt in [a, b]:
		draw_circle(pt, width * 0.8, Color(0.5, 0.52, 0.55))
		draw_circle(pt, width * 0.4, Color(0.25, 0.26, 0.28))


# ── Militia draw helpers (camo patches + stencil edges) ──

func _draw_militia_polygon(points: PackedVector2Array, width: float) -> void:
	if points.size() < 3:
		return
	# Dark army green fill
	draw_colored_polygon(points, MILITIA_HULL)

	# Hard stencil-style edges — flat, no glow, military crisp
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], Color(0.1, 0.1, 0.05), width * 1.5, true)
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], MILITIA_DETAIL, width * 0.5, true)

func _draw_militia_line(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, Color(0.1, 0.1, 0.05), width * 1.4, true)
	draw_line(a, b, MILITIA_ACCENT, width, true)
	draw_line(a, b, MILITIA_DETAIL, width * 0.3, true)


# ── Stealth draw helpers (near-black + angular facets + red heat glow) ──

func _draw_stealth_polygon(points: PackedVector2Array, width: float) -> void:
	if points.size() < 3:
		return
	# Near-black matte fill
	draw_colored_polygon(points, STEALTH_HULL)

	var min_y := points[0].y
	var max_y := points[0].y
	for pt in points:
		min_y = minf(min_y, pt.y)
		max_y = maxf(max_y, pt.y)
	var _height: float = max_y - min_y

	# Angular facet shading — per-edge brightness based on edge angle
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var edge_dir: Vector2 = (points[ni] - points[i]).normalized()
		var facing: float = absf(edge_dir.x) * 0.6 + absf(edge_dir.y) * 0.4
		# Facet fill — thin strip along each edge, brightness varies
		var inward: Vector2 = Vector2(-edge_dir.y, edge_dir.x) * 3.0
		var facet := PackedVector2Array([points[i], points[ni], points[ni] + inward, points[i] + inward])
		var facet_clips: Array = Geometry2D.intersect_polygons(points, facet)
		var facet_bright: float = 0.04 + facing * 0.08
		for clip_idx in range(facet_clips.size()):
			var clip_poly: PackedVector2Array = facet_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, facet_bright))

	# Razor-sharp edges — very thin, dark with faint catch-light
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		draw_line(points[i], points[ni], Color(0.02, 0.02, 0.03), width * 1.2, true)
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var edge_dir: Vector2 = (points[ni] - points[i]).normalized()
		var catch_val: float = absf(edge_dir.x) * 0.5
		if catch_val > 0.15:
			draw_line(points[i], points[ni], Color(0.25, 0.25, 0.3, catch_val * 0.5), width * 0.4, true)

func _draw_stealth_line(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, Color(0.02, 0.02, 0.03), width * 1.2, true)
	draw_line(a, b, STEALTH_DETAIL, width * 0.5, true)


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
	# Arc segments — slow smooth fade between teal and purple
	var arc_steps: int = 24
	var arc_len: float = TAU / float(arc_steps)
	for i in range(arc_steps):
		var a0: float = arc_len * float(i)
		var blend: float = sin(time * 0.4 + float(i) * 0.9) * 0.5 + 0.5
		var seg_col: Color = SPORE_DOT.lerp(SPORE_DOT_ALT, blend)
		seg_col.a = 0.7
		draw_arc(center, radius, a0, a0 + arc_len * 1.1, 8, seg_col, width, true)
	# Wandering highlight
	var wander: Vector2 = center + Vector2(cos(time * 0.7) * 6.0, sin(time * 0.9) * 6.0)
	draw_circle(wander, 3.0, Color(1, 1, 1, 0.3 + sin(time * 2.0) * 0.2))


# ── Boss: Archon (Geometric Arch) ──────────────────────────────

func _draw_archon_core() -> void:
	var s := 7.0
	var hw: float = 20.0 * s
	var band_h: float = 10.0 * s
	var crown_y: float = -14.0 * s

	# Main slab — angular with sharp beveled edges
	var body := PackedVector2Array([
		Vector2(-hw + 4.0 * s, crown_y - 3.0 * s),   # top-left point
		Vector2(hw - 4.0 * s, crown_y - 3.0 * s),     # top-right point
		Vector2(hw + 2.0 * s, crown_y + 2.0 * s),     # right upper notch
		Vector2(hw + 4.0 * s, crown_y + band_h * 0.5), # right spike
		Vector2(hw + 2.0 * s, crown_y + band_h - 2.0 * s),
		Vector2(hw - 4.0 * s, crown_y + band_h + 1.0 * s),  # bottom-right point
		Vector2(-hw + 4.0 * s, crown_y + band_h + 1.0 * s), # bottom-left point
		Vector2(-hw - 2.0 * s, crown_y + band_h - 2.0 * s),
		Vector2(-hw - 4.0 * s, crown_y + band_h * 0.5), # left spike
		Vector2(-hw - 2.0 * s, crown_y + 2.0 * s),
	])
	_poly(body, hull_color, 3.0 * s)

	# Dorsal ridge — red diamonds along the top edge, corners facing outward
	var ridge_color := Color(1.0, 0.15, 0.1)
	var ridge_y: float = crown_y - 3.0 * s  # top edge of main slab
	var ridge_count: int = 9
	var ridge_x_start: float = -hw + 6.0 * s
	var ridge_x_end: float = hw - 6.0 * s
	var ridge_r: float = 2.8 * s  # diamond radius
	for ri in range(ridge_count):
		var rt: float = float(ri) / float(ridge_count - 1)
		var rx: float = lerpf(ridge_x_start, ridge_x_end, rt)
		# Outward-facing diamond — tall vertically, point extends above the hull
		var rdiamond := PackedVector2Array([
			Vector2(rx, ridge_y - ridge_r * 1.4),  # top point (outward)
			Vector2(rx + ridge_r * 0.7, ridge_y),   # right
			Vector2(rx, ridge_y + ridge_r * 0.6),   # bottom (into hull)
			Vector2(rx - ridge_r * 0.7, ridge_y),   # left
		])
		_poly(rdiamond, ridge_color, 1.2 * s)

	# Red corner spurs — larger diamonds at the top corners, angled outward
	for corner_side in [-1.0, 1.0]:
		var cx: float = corner_side * (hw - 4.0 * s)
		var cy: float = crown_y - 3.0 * s
		var corner_r: float = 4.0 * s
		var corner_diamond := PackedVector2Array([
			Vector2(cx, cy - corner_r * 1.2),                  # top (outward)
			Vector2(cx + corner_side * corner_r * 1.0, cy),    # outer side
			Vector2(cx, cy + corner_r * 0.5),                  # bottom (into hull)
			Vector2(cx - corner_side * corner_r * 0.6, cy),    # inner side
		])
		_poly(corner_diamond, ridge_color, 1.8 * s)

	# V-cut armor seams — angular lines across the face
	var mid_y: float = crown_y + band_h * 0.5
	_line(Vector2(-hw + 2.0 * s, mid_y - 1.5 * s), Vector2(0, mid_y - 3.0 * s), detail_color, 0.7 * s)
	_line(Vector2(0, mid_y - 3.0 * s), Vector2(hw - 2.0 * s, mid_y - 1.5 * s), detail_color, 0.7 * s)
	_line(Vector2(-hw + 2.0 * s, mid_y + 1.5 * s), Vector2(0, mid_y + 3.0 * s), detail_color, 0.7 * s)
	_line(Vector2(0, mid_y + 3.0 * s), Vector2(hw - 2.0 * s, mid_y + 1.5 * s), detail_color, 0.7 * s)

	# Spinning inner triangles — angular machinery visible through the hull
	for gi in range(3):
		var gx: float = (-10.0 + float(gi) * 10.0) * s
		var gr: float = 3.5 * s
		var spin: float = time * (1.2 + float(gi) * 0.4) * (1.0 if gi % 2 == 0 else -1.0)
		var tri := PackedVector2Array()
		for vi in range(3):
			var angle: float = TAU * float(vi) / 3.0 + spin
			tri.append(Vector2(gx + cos(angle) * gr, mid_y + sin(angle) * gr))
		_poly(tri, Color(accent_color.r, accent_color.g, accent_color.b, 0.5), 0.8 * s)

	# Pulsing diamond energy nodes along the channel
	var phase: float = time * 2.5
	for i in range(12):
		var t: float = float(i) / 11.0
		var px: float = lerpf(-hw + 5.0 * s, hw - 5.0 * s, t)
		var pulse: float = sin(phase + t * 8.0) * 0.5 + 0.5
		var nr: float = 1.2 * s
		var nd := PackedVector2Array([
			Vector2(px, mid_y - nr), Vector2(px + nr, mid_y),
			Vector2(px, mid_y + nr), Vector2(px - nr, mid_y),
		])
		_poly(nd, Color(accent_color.r, accent_color.g, accent_color.b, 0.15 + pulse * 0.45), 0.5 * s)

	# Angular end caps — arrow-shaped reinforcements
	for side_val in [-1.0, 1.0]:
		var ex: float = side_val * (hw - 2.0 * s)
		var cap := PackedVector2Array([
			Vector2(ex, crown_y + 2.0 * s),
			Vector2(ex + side_val * 3.0 * s, mid_y),
			Vector2(ex, crown_y + band_h - 2.0 * s),
		])
		_poly(cap, accent_color, 1.0 * s)

	# Central bay — angular trapezoid housing
	var bay_top: float = crown_y + band_h + 1.0 * s
	var bay_bot: float = bay_top + 10.0 * s
	var bay := PackedVector2Array([
		Vector2(-8.0 * s, bay_top),
		Vector2(8.0 * s, bay_top),
		Vector2(5.0 * s, bay_bot),
		Vector2(-5.0 * s, bay_bot),
	])
	_poly(bay, hull_color, 2.0 * s)
	# Bay diamond emitter
	var bay_pulse: float = 0.3 + sin(time * 1.8) * 0.25
	var bay_cy: float = bay_top + 5.0 * s
	var br: float = 3.5 * s
	var bay_diamond := PackedVector2Array([
		Vector2(0, bay_cy - br), Vector2(br, bay_cy),
		Vector2(0, bay_cy + br), Vector2(-br, bay_cy),
	])
	_poly(bay_diamond, Color(engine_color.r, engine_color.g, engine_color.b, bay_pulse), 1.2 * s)

	# Crown nexus — sharp diamond with rotating inner cross
	var crown_pulse: float = 0.5 + sin(time * 2.0) * 0.3
	var cp := Vector2(0, crown_y - 5.0 * s)
	var dr: float = 5.0 * s
	var diamond := PackedVector2Array([
		cp + Vector2(0, -dr * 1.3), cp + Vector2(dr, 0),
		cp + Vector2(0, dr * 1.3), cp + Vector2(-dr, 0),
	])
	_poly(diamond, Color(accent_color.r, accent_color.g, accent_color.b, crown_pulse), 2.0 * s)
	# Spinning cross inside the diamond
	var cross_spin: float = time * 1.5
	var cr: float = 3.0 * s
	for ci in range(4):
		var angle: float = TAU * float(ci) / 4.0 + cross_spin
		_line(cp, cp + Vector2(cos(angle) * cr, sin(angle) * cr), Color(1.0, 1.0, 1.0, crown_pulse * 0.6), 0.8 * s)

	# Integrated turret — drawn at former segment offset (-2, -71)
	_draw_archon_turret_inline(Vector2(-2.0, -71.0))


func _draw_archon_turret_inline(offset: Vector2) -> void:
	## Turret visual folded into core — rotating squares, barrel, targeting reticle.
	var ts := 3.0

	# Outer base — sharp square, slowly rotating
	var base_r: float = 10.0 * ts
	var base := PackedVector2Array()
	var base_spin: float = time * 0.2
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + base_spin + PI * 0.25
		base.append(offset + Vector2(cos(angle) * base_r, sin(angle) * base_r))
	_poly(base, hull_color, 2.0 * ts)

	# Inner diamond — contra-rotating
	var inner_r: float = 7.0 * ts
	var inner := PackedVector2Array()
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 - time * 0.5
		inner.append(offset + Vector2(cos(angle) * inner_r, sin(angle) * inner_r))
	_poly(inner, accent_color, 1.5 * ts)

	# Spinning triangle
	var tri_r: float = 4.5 * ts
	var tri := PackedVector2Array()
	for i in range(3):
		var angle: float = TAU * float(i) / 3.0 + time * 0.8
		tri.append(offset + Vector2(cos(angle) * tri_r, sin(angle) * tri_r))
	_poly(tri, detail_color, 1.0 * ts)

	# Sharp cross at center
	var tcr: float = 8.5 * ts
	_line(offset + Vector2(-tcr, 0), offset + Vector2(tcr, 0), Color(detail_color.r, detail_color.g, detail_color.b, 0.25), 0.5 * ts)
	_line(offset + Vector2(0, -tcr), offset + Vector2(0, tcr), Color(detail_color.r, detail_color.g, detail_color.b, 0.25), 0.5 * ts)

	# Central core — pulsing diamond
	var core_pulse: float = 0.5 + sin(time * 3.0) * 0.3
	var tcore_r: float = 2.5 * ts
	var tcore_d := PackedVector2Array([
		offset + Vector2(0, -tcore_r), offset + Vector2(tcore_r, 0),
		offset + Vector2(0, tcore_r), offset + Vector2(-tcore_r, 0),
	])
	_poly(tcore_d, Color(1.0, 1.0, 1.0, core_pulse * 0.8), 1.0 * ts)

	# Barrel housing — angular trapezoid pointing forward (down)
	var barrel := PackedVector2Array([
		offset + Vector2(-3.0 * ts, -1.0 * ts), offset + Vector2(3.0 * ts, -1.0 * ts),
		offset + Vector2(2.0 * ts, 14.0 * ts), offset + Vector2(-2.0 * ts, 14.0 * ts),
	])
	_poly(barrel, hull_color, 1.2 * ts)


func _draw_archon_wing(side: float) -> void:
	## Angular sweeping wing with sharp edges and spinning inner machinery.
	var s := 5.0
	var seg_count: int = 16
	var total_reach: float = 38.0 * s
	var hook_depth: float = 32.0 * s
	var wing_width: float = 7.0 * s

	# Build wing centerline path
	var path_pts: Array[Vector2] = []
	for i in range(seg_count + 1):
		var t: float = float(i) / float(seg_count)
		var x: float = side * total_reach * (1.0 - (1.0 - t) * (1.0 - t))
		var hook_t: float = clampf((t - 0.45) / 0.55, 0.0, 1.0)
		var y: float = -10.0 * s + hook_t * hook_t * hook_depth
		path_pts.append(Vector2(x, y))

	# Build thick wing polygon
	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	for i in range(path_pts.size()):
		var t: float = float(i) / float(seg_count)
		var pt: Vector2 = path_pts[i]
		var w: float = wing_width * lerpf(1.0, 0.5, t)
		var perp := Vector2(0, 1)
		if i > 0:
			var tangent: Vector2 = (path_pts[i] - path_pts[i - 1]).normalized()
			perp = Vector2(-tangent.y, tangent.x)
		outer_pts.append(pt - perp * w)
		inner_pts.append(pt + perp * w)

	var wing := PackedVector2Array()
	for pt in outer_pts:
		wing.append(pt)
	for i in range(inner_pts.size() - 1, -1, -1):
		wing.append(inner_pts[i])
	_poly(wing, hull_color, 2.5 * s)

	# Angled structural ribs — V-shaped cross-beams instead of straight
	for ri in range(7):
		var t: float = (float(ri) + 1.0) / 8.0
		var idx: int = int(t * float(seg_count))
		var pt: Vector2 = path_pts[idx]
		var w: float = wing_width * lerpf(1.0, 0.5, t)
		var perp := Vector2(0, 1)
		if idx > 0:
			var tangent: Vector2 = (path_pts[idx] - path_pts[idx - 1]).normalized()
			perp = Vector2(-tangent.y, tangent.x)
		var offset := Vector2(side * 2.0 * s, 0)
		_line(pt - perp * w, pt + offset, detail_color, 0.7 * s)
		_line(pt + offset, pt + perp * w, detail_color, 0.7 * s)

	# Armored spine — angular segmented line
	for i in range(path_pts.size() - 1):
		if i % 2 == 0:
			_line(path_pts[i], path_pts[i + 1], accent_color, 1.0 * s)

	# Spinning diamond greebles at regular intervals along the wing
	for gi in range(4):
		var t: float = 0.12 + float(gi) * 0.2
		var idx: int = int(t * float(seg_count))
		var pt: Vector2 = path_pts[idx]
		var gr: float = 2.5 * s
		var spin: float = time * (1.5 + float(gi) * 0.3) * (1.0 if gi % 2 == 0 else -1.0)
		var greeble := PackedVector2Array()
		for vi in range(4):
			var angle: float = TAU * float(vi) / 4.0 + spin
			greeble.append(pt + Vector2(cos(angle) * gr, sin(angle) * gr))
		_poly(greeble, Color(accent_color.r, accent_color.g, accent_color.b, 0.4), 0.6 * s)

	# Outer cannon mount — angular diamond housing at the hooked tip
	var tip_t: float = 0.85
	var tip_idx: int = int(tip_t * float(seg_count))
	var tip_pt: Vector2 = path_pts[tip_idx]
	var cannon_pulse: float = 0.4 + sin(time * 2.5) * 0.3
	var cw: float = 5.0 * s
	var cannon_diamond := PackedVector2Array([
		tip_pt + Vector2(0, -cw), tip_pt + Vector2(cw, 0),
		tip_pt + Vector2(0, cw), tip_pt + Vector2(-cw, 0),
	])
	_poly(cannon_diamond, Color(engine_color.r, engine_color.g, engine_color.b, cannon_pulse), 1.5 * s)
	# Spinning triangle inside cannon
	var cspin: float = time * 2.0
	var ct := PackedVector2Array()
	for vi in range(3):
		var angle: float = TAU * float(vi) / 3.0 + cspin
		ct.append(tip_pt + Vector2(cos(angle) * 3.0 * s, sin(angle) * 3.0 * s))
	_poly(ct, Color(hull_color.r, hull_color.g, hull_color.b, 0.6), 0.8 * s)

	# Inner turret mount — mid-wing diamond platform
	var mid_t: float = 0.35
	var mid_idx: int = int(mid_t * float(seg_count))
	var mid_pt: Vector2 = path_pts[mid_idx]
	var mr: float = 3.5 * s
	var mid_diamond := PackedVector2Array([
		mid_pt + Vector2(0, -mr), mid_pt + Vector2(mr, 0),
		mid_pt + Vector2(0, mr), mid_pt + Vector2(-mr, 0),
	])
	_poly(mid_diamond, Color(accent_color.r, accent_color.g, accent_color.b, 0.5), 0.8 * s)

	# Traveling edge diamonds — sharp indicators
	for ni in range(8):
		var t: float = (float(ni) + 0.5) / 8.0
		var idx: int = int(t * float(seg_count))
		var pt: Vector2 = path_pts[idx]
		var w: float = wing_width * lerpf(1.0, 0.5, t)
		var perp := Vector2(0, 1)
		if idx > 0:
			var tangent: Vector2 = (path_pts[idx] - path_pts[idx - 1]).normalized()
			perp = Vector2(-tangent.y, tangent.x)
		var glow: float = fmod(time * 2.5 + float(ni) * 0.4, 1.0)
		var la: float = 0.55 if glow < 0.2 else 0.12
		var ep: Vector2 = pt - perp * w
		var er: float = 1.3 * s
		var edge_d := PackedVector2Array([
			ep + Vector2(0, -er), ep + Vector2(er, 0),
			ep + Vector2(0, er), ep + Vector2(-er, 0),
		])
		_poly(edge_d, Color(accent_color.r, accent_color.g, accent_color.b, la), 0.4 * s)


func _draw_archon_turret() -> void:
	var s := 3.0

	# Outer base — sharp square, slowly rotating
	var base_r: float = 10.0 * s
	var base := PackedVector2Array()
	var base_spin: float = time * 0.2
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + base_spin + PI * 0.25
		base.append(Vector2(cos(angle) * base_r, sin(angle) * base_r))
	_poly(base, hull_color, 2.0 * s)

	# Inner diamond — contra-rotating
	var inner_r: float = 7.0 * s
	var inner := PackedVector2Array()
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 - time * 0.5
		inner.append(Vector2(cos(angle) * inner_r, sin(angle) * inner_r))
	_poly(inner, accent_color, 1.5 * s)

	# Spinning triangle inside that
	var tri_r: float = 4.5 * s
	var tri := PackedVector2Array()
	for i in range(3):
		var angle: float = TAU * float(i) / 3.0 + time * 0.8
		tri.append(Vector2(cos(angle) * tri_r, sin(angle) * tri_r))
	_poly(tri, detail_color, 1.0 * s)

	# Sharp cross at center — static frame
	var cr: float = 8.5 * s
	_line(Vector2(-cr, 0), Vector2(cr, 0), Color(detail_color.r, detail_color.g, detail_color.b, 0.25), 0.5 * s)
	_line(Vector2(0, -cr), Vector2(0, cr), Color(detail_color.r, detail_color.g, detail_color.b, 0.25), 0.5 * s)

	# Central core — pulsing diamond
	var core_pulse: float = 0.5 + sin(time * 3.0) * 0.3
	var core_r: float = 2.5 * s
	var core_d := PackedVector2Array([
		Vector2(0, -core_r), Vector2(core_r, 0),
		Vector2(0, core_r), Vector2(-core_r, 0),
	])
	_poly(core_d, Color(1.0, 1.0, 1.0, core_pulse * 0.8), 1.0 * s)

	# Barrel housing — angular trapezoid pointing forward (down)
	var barrel := PackedVector2Array([
		Vector2(-3.0 * s, -1.0 * s), Vector2(3.0 * s, -1.0 * s),
		Vector2(2.0 * s, 14.0 * s), Vector2(-2.0 * s, 14.0 * s),
	])
	_poly(barrel, hull_color, 1.2 * s)

	# Aiming indicator — glowing line from barrel tip
	var aim_len: float = 24.0 * s
	var aim_pulse: float = 0.3 + sin(time * 4.0) * 0.2
	var aim_start := Vector2(0, 14.0 * s)
	var aim_end := Vector2(0, aim_len)
	_line(aim_start, aim_end, Color(engine_color.r, engine_color.g, engine_color.b, aim_pulse), 1.5 * s)
	# Targeting reticle — diamond instead of circle
	var tr: float = 3.5 * s
	var reticle := PackedVector2Array([
		aim_end + Vector2(0, -tr), aim_end + Vector2(tr, 0),
		aim_end + Vector2(0, tr), aim_end + Vector2(-tr, 0),
	])
	_poly(reticle, Color(engine_color.r, engine_color.g, engine_color.b, aim_pulse * 1.5), 0.8 * s)
	# Crosshair arms
	var ch: float = 5.0 * s
	_line(aim_end + Vector2(-ch, 0), aim_end + Vector2(ch, 0), Color(engine_color.r, engine_color.g, engine_color.b, aim_pulse), 0.8 * s)
	_line(aim_end + Vector2(0, -ch), aim_end + Vector2(0, ch), Color(engine_color.r, engine_color.g, engine_color.b, aim_pulse), 0.8 * s)
