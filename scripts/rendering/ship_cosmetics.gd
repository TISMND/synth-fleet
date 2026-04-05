class_name ShipCosmetics
extends RefCounted
## Shared cosmetic overlay system for ally/NPC ships — paint and light patterns.
## Used by both the Ships Screen editor preview and the runtime NpcShip spawn path
## so editor and in-game renderings stay identical (per CLAUDE.md preview = game reality).


# ── Hull geometry lookup ──────────────────────────────────────────
## Returns { hull: PackedVector2Array, exclusions: Array[PackedVector2Array] } or {}.
static func get_hull_geometry(visual_id: String) -> Dictionary:
	match visual_id:
		"dreadnought": return _cargo_hull_geometry()
		_: return {}


static func _cargo_hull_geometry() -> Dictionary:
	var s := 1.9
	var hull := PackedVector2Array([
		Vector2(-4 * s, -48 * s), Vector2(4 * s, -48 * s),
		Vector2(16 * s, -40 * s), Vector2(20 * s, -26 * s),
		Vector2(20 * s, 26 * s), Vector2(18 * s, 36 * s),
		Vector2(16 * s, 42 * s), Vector2(-16 * s, 42 * s),
		Vector2(-18 * s, 36 * s), Vector2(-20 * s, 26 * s),
		Vector2(-20 * s, -26 * s), Vector2(-16 * s, -40 * s),
	])
	var exclusions: Array[PackedVector2Array] = []
	exclusions.append(PackedVector2Array([
		Vector2(-8 * s, -42 * s), Vector2(8 * s, -42 * s),
		Vector2(10 * s, -32 * s), Vector2(-10 * s, -32 * s),
	]))
	exclusions.append(thick_line(Vector2(0, -30 * s), Vector2(0, 38 * s), 2.5 * s))
	for y in [-20, -10, 0, 12, 24, 34]:
		exclusions.append(thick_line(Vector2(-18 * s, y * s), Vector2(18 * s, y * s), 1.5 * s))
	exclusions.append(PackedVector2Array([
		Vector2(20 * s, -8 * s), Vector2(26 * s, -6 * s),
		Vector2(26 * s, 8 * s), Vector2(20 * s, 10 * s),
	]))
	exclusions.append(PackedVector2Array([
		Vector2(-20 * s, -8 * s), Vector2(-26 * s, -6 * s),
		Vector2(-26 * s, 8 * s), Vector2(-20 * s, 10 * s),
	]))
	for ex in [-14, -10, -6, -2, 2, 6, 10, 14]:
		exclusions.append(thick_line(Vector2(ex * s, 40 * s), Vector2(ex * s, 48 * s), 2.0 * s))
	return {hull = hull, exclusions = exclusions}


# ── Polygon primitives ────────────────────────────────────────────

static func thick_line(a: Vector2, b: Vector2, hw: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	return PackedVector2Array([a + n * hw, b + n * hw, b - n * hw, a - n * hw])


static func rect(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x1, y1), Vector2(x2, y1), Vector2(x2, y2), Vector2(x1, y2)])


static func rotated_rect(cx: float, cy: float, hw: float, hh: float, angle: float) -> PackedVector2Array:
	var ca := cos(angle)
	var sa := sin(angle)
	var pts := PackedVector2Array()
	for c in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
		pts.append(Vector2(cx + c.x * ca - c.y * sa, cy + c.x * sa + c.y * ca))
	return pts


# ── Pattern shape generation ──────────────────────────────────────

static func gen_shapes(pattern_name: String) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	match pattern_name:
		"CENTER STRIPE": shapes.append(rect(-3, -100, 3, 100))
		"WIDE BAND": shapes.append(rect(-9, -100, 9, 100))
		"TRIPLE LINE":
			for x in [-14, 0, 14]:
				shapes.append(rect(x - 1.5, -100, x + 1.5, 100))
		"NOSE CAP": shapes.append(rect(-100, -50, 100, -20))
		"TAIL BAND": shapes.append(rect(-100, 15, 100, 35))
		"THREE BANDS":
			for b in [[-45, -32], [-6, 6], [20, 32]]:
				shapes.append(rect(-100, b[0], 100, b[1]))
		"DIAG LEFT": shapes.append(rotated_rect(0, 0, 13, 100, -0.4))
		"DIAG RIGHT": shapes.append(rotated_rect(0, 0, 13, 100, 0.4))
		"CHEVRON":
			shapes.append(thick_line(Vector2(0, -20), Vector2(-38, -20 + 38 * 0.6), 4))
			shapes.append(thick_line(Vector2(0, -20), Vector2(38, -20 + 38 * 0.6), 4))
		"WING CHECK":
			var sz := 6.0
			var wing_left := rect(-100, -100, -10, 100)
			var wing_right := rect(10, -100, 100, 100)
			for ix in range(-10, 11):
				for iy in range(-12, 12):
					if (ix + iy) % 2 == 0:
						var tile := rect(ix * sz, iy * sz, (ix + 1) * sz, (iy + 1) * sz)
						for lp in Geometry2D.intersect_polygons(tile, wing_left):
							shapes.append(lp)
						for rp in Geometry2D.intersect_polygons(tile, wing_right):
							shapes.append(rp)
		"WING TIPS":
			shapes.append(rect(-100, -100, -15, 100))
			shapes.append(rect(15, -100, 100, 100))
		"WEDGE":
			shapes.append(PackedVector2Array([
				Vector2(-35, -50), Vector2(35, -50), Vector2(6, 0), Vector2(-6, 0)]))
		"STARBURST":
			for i in range(8):
				var a: float = float(i) / 8.0 * TAU
				shapes.append(thick_line(Vector2.ZERO, Vector2(cos(a) * 60, sin(a) * 60), 2.0))
		"FULL NOSE": shapes.append(rect(-100, -91, 100, -50))
		"FULL BELLY": shapes.append(rect(-100, -19, 100, 27))
		"FULL STERN": shapes.append(rect(-100, 46, 100, 80))
		"TOP HALF": shapes.append(rect(-100, -100, 100, -8))
		"BOTTOM HALF": shapes.append(rect(-100, -8, 100, 100))
		"SLATS x6":
			for i in range(6):
				var y: float = lerpf(-80, 70, float(i) / 5.0)
				shapes.append(rect(-100, y - 3, 100, y + 3))
		"SLATS x10":
			for i in range(10):
				var y: float = lerpf(-85, 76, float(i) / 9.0)
				shapes.append(rect(-100, y - 2, 100, y + 2))
		"SLATS x16":
			for i in range(16):
				var y: float = lerpf(-85, 76, float(i) / 15.0)
				shapes.append(rect(-100, y - 1.5, 100, y + 1.5))
		"WIDE SLATS":
			for i in range(4):
				var y: float = lerpf(-70, 60, float(i) / 3.0)
				shapes.append(rect(-100, y - 6, 100, y + 6))
		"CENTER SPINE": shapes.append(rect(-8, -100, 8, 100))
		"PORT/STARBOARD":
			shapes.append(rect(-32, -100, -22, 100))
			shapes.append(rect(22, -100, 32, 100))
		"TRIPLE STRIPE":
			for x in [-24, 0, 24]:
				shapes.append(rect(x - 3, -100, x + 3, 100))
		"CHECKERBOARD":
			var sz := 13.0
			for ix in range(-10, 11):
				for iy in range(-10, 11):
					if (ix + iy) % 2 == 0:
						shapes.append(rect(ix * sz, iy * sz, (ix + 1) * sz, (iy + 1) * sz))
		"CROSS":
			shapes.append(rect(-7, -100, 7, 100))
			shapes.append(rect(-100, -7, 100, 7))
		"SIDE PANELS":
			shapes.append(rect(-100, -100, -4, 100))
			shapes.append(rect(4, -100, 100, 100))
		"ARMOR PLATES":
			for i in range(6):
				var y: float = -30 + float(i) * 12
				shapes.append(rect(-100, y - 1.5, 100, y + 1.5))
		"TWIN RACING":
			shapes.append(rect(-10, -100, -6, 100))
			shapes.append(rect(6, -100, 10, 100))
		"DOUBLE CHEVRON":
			for yc in [-15, 8]:
				shapes.append(thick_line(Vector2(0, yc), Vector2(-26, yc + 26 * 0.6), 2))
				shapes.append(thick_line(Vector2(0, yc), Vector2(26, yc + 26 * 0.6), 2))
		"STACKED V":
			for yc in [-28, -14, 0, 14]:
				shapes.append(thick_line(Vector2(0, yc), Vector2(-20, yc + 20 * 0.6), 1.5))
				shapes.append(thick_line(Vector2(0, yc), Vector2(20, yc + 20 * 0.6), 1.5))
		"TIGHT CHEVRONS":
			for yc in [-20, -10, 0, 10, 20]:
				shapes.append(thick_line(Vector2(0, yc), Vector2(-16, yc + 16 * 0.6), 1))
				shapes.append(thick_line(Vector2(0, yc), Vector2(16, yc + 16 * 0.6), 1))
		"NAV LIGHTS":
			for yv in [-57, -19, 19, 57]:
				shapes.append(rect(-38.5, yv - 3.5, -31.5, yv + 3.5))
				shapes.append(rect(31.5, yv - 3.5, 38.5, yv + 3.5))
		"RUNNING LIGHTS":
			for yv in [-68, -46, -23, 0, 23, 46, 68]:
				shapes.append(rect(-37.5, yv - 2.5, -32.5, yv + 2.5))
				shapes.append(rect(32.5, yv - 2.5, 37.5, yv + 2.5))
		"CORNER MARKS":
			for corner in [[-30, -76, -1, -1], [30, -76, 1, -1], [-30, 72, -1, 1], [30, 72, 1, 1]]:
				var cx: float = corner[0]
				var cy: float = corner[1]
				var sx: float = corner[2]
				var sy: float = corner[3]
				shapes.append(rect(cx, cy, cx + sx * 14, cy + 3.5 * sy))
				shapes.append(rect(cx, cy, cx + 3.5 * sx, cy + sy * 14))
		"BRIDGE SPOTS":
			for pos in [[-23, -72], [23, -72], [0, -84]]:
				shapes.append(rect(pos[0] - 3.5, pos[1] - 3.5, pos[0] + 3.5, pos[1] + 3.5))
		"DOCKING LIGHTS":
			for pos in [[-35, -38], [35, -38], [-35, 38], [35, 38], [-35, 0], [35, 0]]:
				shapes.append(rect(pos[0] - 4, pos[1] - 4, pos[0] + 4, pos[1] + 4))
		"SIGNAL ARRAY":
			for pos in [[0, -84], [-35, -57], [35, -57], [-35, 0], [35, 0], [-35, 57], [35, 57], [0, 76]]:
				shapes.append(rect(pos[0] - 2.5, pos[1] - 2.5, pos[0] + 2.5, pos[1] + 2.5))
		"DECK LINES":
			for b in [[-53, -49], [-8, -4], [42, 46]]:
				shapes.append(rect(-100, b[0], 100, b[1]))
		"HULL GLOW":
			for b in [[-84, -80], [-38, -34], [4, 8], [46, 50], [72, 76]]:
				shapes.append(rect(-100, b[0], 100, b[1]))
		"PORT WINDOWS":
			for row_y in [-30, -8, 15, 38]:
				var hw := 1.75
				var total_w: float = 3.0 * 13.0
				var start_x: float = -total_w * 0.5
				for i in range(4):
					var cx: float = start_x + float(i) * 13.0
					shapes.append(rect(cx - hw, row_y - hw, cx + hw, row_y + hw))
		"CABIN LIGHTS":
			for row_y in [-42, -19, 4, 27, 49]:
				var hw := 1.25
				var total_w: float = 4.0 * 11.0
				var start_x: float = -total_w * 0.5
				for i in range(5):
					var cx: float = start_x + float(i) * 11.0
					shapes.append(rect(cx - hw, row_y - hw, cx + hw, row_y + hw))
		"WIDE RACING":
			shapes.append(rect(-15, -100, -9, 100))
			shapes.append(rect(9, -100, 15, 100))
		"TRIPLE BAND":
			for b in [[-35, -30], [-3, 3], [28, 33]]:
				shapes.append(rect(-100, b[0], 100, b[1]))
		"QUAD STRIPES":
			for x in [-15, -5, 5, 15]:
				shapes.append(rect(x - 1.25, -100, x + 1.25, 100))
	return shapes


# ── Overlay node classes ──────────────────────────────────────────

class PaintOverlay extends Node2D:
	var hull_poly: PackedVector2Array
	var exclusion_polys: Array[PackedVector2Array] = []
	var paint_shapes: Array[PackedVector2Array] = []
	var paint_color: Color = Color(0.85, 0.08, 0.08, 0.92)

	func _draw() -> void:
		for shape in paint_shapes:
			var current: Array[PackedVector2Array] = []
			var hull_clipped := Geometry2D.intersect_polygons(shape, hull_poly)
			for hp in hull_clipped:
				current.append(hp)
			for excl in exclusion_polys:
				var next_arr: Array[PackedVector2Array] = []
				for poly in current:
					var clipped := Geometry2D.clip_polygons(poly, excl)
					for cp in clipped:
						next_arr.append(cp)
				current = next_arr
			for fpoly in current:
				draw_colored_polygon(fpoly, paint_color)


class LightOverlay extends Node2D:
	var hull_poly: PackedVector2Array
	var exclusion_polys: Array[PackedVector2Array] = []
	var light_shapes: Array[PackedVector2Array] = []
	var light_color: Color = Color(1.0, 0.85, 0.12)
	var _time: float = 0.0
	var _clipped_polys: Array[PackedVector2Array] = []

	const PULSE_PERIOD: float = 1.8
	const HDR_MULT: float = 2.5
	const VENT_COLOR := Color(0.02, 0.02, 0.03, 1.0)

	func _ready() -> void:
		for shape in light_shapes:
			var current: Array[PackedVector2Array] = []
			var hull_clipped := Geometry2D.intersect_polygons(shape, hull_poly)
			for hp in hull_clipped:
				current.append(hp)
			for excl in exclusion_polys:
				var next_arr: Array[PackedVector2Array] = []
				for poly in current:
					var clipped := Geometry2D.clip_polygons(poly, excl)
					for cp in clipped:
						next_arr.append(cp)
				current = next_arr
			for fpoly in current:
				_clipped_polys.append(fpoly)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for poly in _clipped_polys:
			draw_colored_polygon(poly, VENT_COLOR)
		var phase: float = fmod(_time, PULSE_PERIOD) / PULSE_PERIOD
		var intensity: float = (sin(phase * TAU - PI * 0.5) + 1.0) * 0.5
		if intensity < 0.01:
			return
		var hdr: float = intensity * HDR_MULT
		var col := Color(light_color.r * hdr, light_color.g * hdr, light_color.b * hdr, intensity * 0.95)
		for poly in _clipped_polys:
			draw_colored_polygon(poly, col)


# ── Convenience: attach overlays for a ship ──────────────────────
## Spawns and configures overlays for the given visual_id + patterns.
## Returns [paint_overlay_or_null, light_overlay_or_null] for caller to position/parent.
static func build_overlays(
	visual_id: String,
	paint_pattern: String, paint_color: Color,
	light_pattern: String, light_color: Color,
) -> Array[Node2D]:
	var result: Array[Node2D] = [null, null]
	var hull_data: Dictionary = get_hull_geometry(visual_id)
	if hull_data.is_empty():
		return result
	var hull_poly: PackedVector2Array = hull_data.hull
	var exclusions: Array[PackedVector2Array]
	exclusions.assign(hull_data.exclusions)

	if paint_pattern != "":
		var shapes: Array[PackedVector2Array] = gen_shapes(paint_pattern)
		if shapes.size() > 0:
			var po := PaintOverlay.new()
			po.hull_poly = hull_poly
			po.exclusion_polys = exclusions
			po.paint_shapes = shapes
			po.paint_color = paint_color
			result[0] = po

	if light_pattern != "":
		var shapes2: Array[PackedVector2Array] = gen_shapes(light_pattern)
		if shapes2.size() > 0:
			var lo := LightOverlay.new()
			lo.hull_poly = hull_poly
			lo.exclusion_polys = exclusions
			lo.light_shapes = shapes2
			lo.light_color = light_color
			result[1] = lo

	return result
