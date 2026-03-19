class_name ShipThumbnails
extends Control
## Standalone ship thumbnail renderer. Draws any of the 9 ships at a given origin.
## Uses ShipRenderer for constants and render mode enum.

var ship_index: int = 0
var origin: Vector2 = Vector2.ZERO
var render_mode: int = ShipRenderer.RenderMode.CHROME
var draw_scale: float = 1.0

# Neon palette
var cyan := Color(0.0, 0.9, 1.0)
var magenta := Color(1.0, 0.2, 0.6)
var orange := Color(1.0, 0.5, 0.1)
var purple := Color(0.4, 0.2, 1.0)
var teal := Color(0.0, 1.0, 0.7)


func _draw() -> void:
	draw_ship_on(self, ship_index, origin, draw_scale, render_mode)


## Static API: draw a ship thumbnail on any CanvasItem.
static func draw_ship_on(ci: CanvasItem, index: int, at_origin: Vector2,
		scale: float, mode: int) -> void:
	ci.draw_set_transform(at_origin, 0, Vector2(scale, scale))
	var o: Vector2 = Vector2.ZERO
	var ctx := _DrawCtx.new(ci, mode)
	match index:
		0: ctx.draw_switchblade(o)
		1: ctx.draw_phantom(o)
		2: ctx.draw_mantis(o)
		3: ctx.draw_corsair(o)
		4: ctx.draw_stiletto(o)
		5: ctx.draw_trident(o)
		6: ctx.draw_orrery(o)
		7: ctx.draw_dreadnought(o)
		8: ctx.draw_bastion(o)


## Draw any enemy thumbnail on any CanvasItem, dispatched by visual_id.
static func draw_enemy_on(ci: CanvasItem, visual_id: String, at_origin: Vector2, mode: int) -> void:
	var ctx := _DrawCtx.new(ci, mode)
	match visual_id:
		"sentinel": ctx.draw_sentinel(at_origin)
		"dart": ctx.draw_dart(at_origin)
		"crucible": ctx.draw_crucible(at_origin)
		"prism": ctx.draw_prism(at_origin)
		"scythe": ctx.draw_scythe(at_origin)
		"tesseract": ctx.draw_tesseract(at_origin)
		"talon": ctx.draw_talon(at_origin)
		"obelisk": ctx.draw_obelisk(at_origin)
		_: ctx.draw_sentinel(at_origin)

## Draw a sentinel enemy thumbnail on any CanvasItem.
static func draw_sentinel_on(ci: CanvasItem, at_origin: Vector2, mode: int) -> void:
	var ctx := _DrawCtx.new(ci, mode)
	ctx.draw_sentinel(at_origin)


# ── Internal draw context — holds CanvasItem ref + render mode for static calls ──

class _DrawCtx:
	var ci: CanvasItem
	var mode: int

	var cyan := Color(0.0, 0.9, 1.0)
	var magenta := Color(1.0, 0.2, 0.6)
	var orange := Color(1.0, 0.5, 0.1)
	var purple := Color(0.4, 0.2, 1.0)
	var teal := Color(0.0, 1.0, 0.7)

	func _init(canvas_item: CanvasItem, render_mode: int) -> void:
		ci = canvas_item
		mode = render_mode

	func mp(points: PackedVector2Array, color: Color, w: float) -> void:
		match mode:
			ShipRenderer.RenderMode.CHROME: mp_chrome(points, w)
			ShipRenderer.RenderMode.VOID: mp_void(points, w)
			ShipRenderer.RenderMode.HIVEMIND: mp_hivemind(points, w)
			ShipRenderer.RenderMode.PHASE: mp_phase(points, color, w)
			ShipRenderer.RenderMode.RIFT: mp_rift(points, w)
			ShipRenderer.RenderMode.SPORE: mp_spore(points, w)
			_: mp_neon(points, color, w)

	func ml(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		match mode:
			ShipRenderer.RenderMode.CHROME: ml_chrome(a, b, w)
			ShipRenderer.RenderMode.VOID: ml_void(a, b, w)
			ShipRenderer.RenderMode.HIVEMIND: ml_hivemind(a, b, w)
			ShipRenderer.RenderMode.PHASE: ml_phase(a, b, color, w)
			ShipRenderer.RenderMode.RIFT: ml_rift(a, b, w)
			ShipRenderer.RenderMode.SPORE: ml_spore(a, b, w)
			_: ml_neon(a, b, color, w)

	func mp_neon(points: PackedVector2Array, color: Color, w: float) -> void:
		var fill := color
		fill.a = 0.12
		ci.draw_colored_polygon(points, fill)
		var gc := color
		gc.a = 0.3
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], gc, w * 2.0, true)
		for pt in points:
			ci.draw_circle(pt, w, gc)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], color, w, true)
		for pt in points:
			ci.draw_circle(pt, w * 0.5, color)

	func ml_neon(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		var gc := color
		gc.a = 0.3
		ci.draw_line(a, b, gc, w * 2.0, true)
		ci.draw_circle(a, w, gc)
		ci.draw_circle(b, w, gc)
		ci.draw_line(a, b, color, w, true)
		ci.draw_circle(a, w * 0.5, color)
		ci.draw_circle(b, w * 0.5, color)

	func mp_chrome(points: PackedVector2Array, w: float) -> void:
		if points.size() < 3:
			return
		ci.draw_colored_polygon(points, ShipRenderer.CHROME_MID)
		var min_y := points[0].y
		var max_y := points[0].y
		for pt in points:
			min_y = minf(min_y, pt.y)
			max_y = maxf(max_y, pt.y)
		var height: float = max_y - min_y
		if height > 1.0:
			for j in range(points.size()):
				var nj: int = (j + 1) % points.size()
				var mid_y: float = (points[j].y + points[nj].y) * 0.5
				var t: float = 1.0 - (mid_y - min_y) / height
				var edge_col: Color = ShipRenderer.CHROME_DARK.lerp(ShipRenderer.CHROME_BRIGHT, t)
				edge_col.a = 0.8
				ci.draw_line(points[j], points[nj], edge_col, w, true)

	func ml_chrome(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, ShipRenderer.CHROME_MID, w * 1.2, true)
		ci.draw_line(a, b, ShipRenderer.CHROME_BRIGHT, w * 0.6, true)

	# ── Void thumbnail helpers ──

	func mp_void(points: PackedVector2Array, w: float) -> void:
		ci.draw_colored_polygon(points, ShipRenderer.VOID_FILL)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], ShipRenderer.VOID_EDGE, w, true)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], Color(1, 1, 1, 0.15), w * 0.3, true)

	func ml_void(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, ShipRenderer.VOID_EDGE_DIM, w * 2.0, true)
		ci.draw_line(a, b, ShipRenderer.VOID_EDGE, w, true)

	# ── Hivemind thumbnail helpers ──

	func mp_hivemind(points: PackedVector2Array, w: float) -> void:
		ci.draw_colored_polygon(points, ShipRenderer.HIVE_FILL)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], ShipRenderer.HIVE_VEIN, w, true)
		for pt in points:
			ci.draw_circle(pt, w * 1.0, ShipRenderer.HIVE_VEIN)

	func ml_hivemind(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, ShipRenderer.HIVE_VEIN_DIM, w * 1.5, true)
		ci.draw_line(a, b, ShipRenderer.HIVE_VEIN, w, true)
		ci.draw_circle(a, w * 0.8, ShipRenderer.HIVE_VEIN)
		ci.draw_circle(b, w * 0.8, ShipRenderer.HIVE_VEIN)

	# ── Phase thumbnail helpers ──

	func mp_phase(points: PackedVector2Array, color: Color, w: float) -> void:
		ci.draw_colored_polygon(points, Color(1, 0, 0, 0.08))
		ci.draw_colored_polygon(points, Color(0, 1, 0, 0.08))
		ci.draw_colored_polygon(points, Color(0, 0, 1, 0.08))
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], color, w, true)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], Color(1, 1, 1, 0.3), w * 0.4, true)

	func ml_phase(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		ci.draw_line(a, b, Color(1, 0.2, 0.2, 0.3), w, true)
		ci.draw_line(a, b, Color(0.2, 0.2, 1, 0.3), w, true)
		ci.draw_line(a, b, color, w * 0.6, true)

	# ── Rift thumbnail helpers ──

	func mp_rift(points: PackedVector2Array, w: float) -> void:
		ci.draw_colored_polygon(points, Color(ShipRenderer.RIFT_GLOW.r, ShipRenderer.RIFT_GLOW.g, ShipRenderer.RIFT_GLOW.b, 0.2))
		if points.size() >= 3:
			var centroid := Vector2.ZERO
			for pt in points:
				centroid += pt
			centroid /= float(points.size())
			var inset := PackedVector2Array()
			for pt in points:
				inset.append(pt.lerp(centroid, 0.08))
			ci.draw_colored_polygon(inset, ShipRenderer.RIFT_DARK)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], ShipRenderer.RIFT_GLOW, w, true)

	func ml_rift(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, Color(ShipRenderer.RIFT_GLOW.r, ShipRenderer.RIFT_GLOW.g, ShipRenderer.RIFT_GLOW.b, 0.4), w * 1.5, true)
		ci.draw_line(a, b, ShipRenderer.RIFT_GLOW, w, true)

	# ── Spore thumbnail helpers ──

	func mp_spore(points: PackedVector2Array, w: float) -> void:
		ci.draw_colored_polygon(points, ShipRenderer.SPORE_CORE)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			var seg_col: Color = ShipRenderer.SPORE_DOT if j % 2 == 0 else ShipRenderer.SPORE_DOT_ALT
			seg_col.a = 0.7
			ci.draw_line(points[j], points[nj], seg_col, w, true)
		for pt in points:
			ci.draw_circle(pt, w * 0.8, ShipRenderer.SPORE_DOT)

	func ml_spore(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, Color(ShipRenderer.SPORE_DOT.r, ShipRenderer.SPORE_DOT.g, ShipRenderer.SPORE_DOT.b, 0.3), w * 1.5, true)
		ci.draw_circle(a, w * 0.6, ShipRenderer.SPORE_DOT)
		ci.draw_circle(b, w * 0.6, ShipRenderer.SPORE_DOT)
		var mid: Vector2 = (a + b) * 0.5
		ci.draw_circle(mid, w * 0.4, ShipRenderer.SPORE_DOT_ALT)

	# ── Mini ship thumbnails ──

	func draw_switchblade(o: Vector2) -> void:
		var s := 0.36
		var rb := PackedVector2Array([
			o + Vector2(3, 16) * s, o + Vector2(4, 4) * s,
			o + Vector2(10, -14) * s, o + Vector2(16, -32) * s,
			o + Vector2(22, -36) * s, o + Vector2(20, -24) * s,
			o + Vector2(16, -8) * s, o + Vector2(12, 6) * s,
			o + Vector2(8, 16) * s,
		])
		mp(rb, cyan, 0.7)
		var lb := PackedVector2Array([
			o + Vector2(-3, 16) * s, o + Vector2(-4, 4) * s,
			o + Vector2(-10, -14) * s, o + Vector2(-16, -32) * s,
			o + Vector2(-22, -36) * s, o + Vector2(-20, -24) * s,
			o + Vector2(-16, -8) * s, o + Vector2(-12, 6) * s,
			o + Vector2(-8, 16) * s,
		])
		mp(lb, cyan, 0.7)
		var hub := PackedVector2Array([
			o + Vector2(0, 2) * s, o + Vector2(7, 14) * s,
			o + Vector2(0, 24) * s, o + Vector2(-7, 14) * s,
		])
		mp(hub, cyan, 0.8)
		ml(o + Vector2(-3, 22) * s, o + Vector2(-3, 28) * s, orange, 0.8)
		ml(o + Vector2(3, 22) * s, o + Vector2(3, 28) * s, orange, 0.8)

	func draw_phantom(o: Vector2) -> void:
		var s := 0.42
		var hull := PackedVector2Array([
			o + Vector2(0, -36) * s, o + Vector2(6, -28) * s,
			o + Vector2(10, -16) * s, o + Vector2(14, -4) * s,
			o + Vector2(16, 8) * s, o + Vector2(12, 20) * s,
			o + Vector2(6, 26) * s, o + Vector2(-6, 26) * s,
			o + Vector2(-12, 20) * s, o + Vector2(-16, 8) * s,
			o + Vector2(-14, -4) * s, o + Vector2(-10, -16) * s,
			o + Vector2(-6, -28) * s,
		])
		mp(hull, cyan, 0.8)
		var rw := PackedVector2Array([
			o + Vector2(14, -2) * s, o + Vector2(22, 4) * s,
			o + Vector2(20, 10) * s, o + Vector2(14, 8) * s,
		])
		mp(rw, cyan, 0.6)
		var lw := PackedVector2Array([
			o + Vector2(-14, -2) * s, o + Vector2(-22, 4) * s,
			o + Vector2(-20, 10) * s, o + Vector2(-14, 8) * s,
		])
		mp(lw, cyan, 0.6)
		ml(o + Vector2(8, -22) * s, o + Vector2(14, 2) * s, teal, 0.5)
		ml(o + Vector2(-8, -22) * s, o + Vector2(-14, 2) * s, teal, 0.5)
		ml(o + Vector2(0, -6) * s, o + Vector2(0, 22) * s, magenta, 0.6)
		ml(o + Vector2(-5, 24) * s, o + Vector2(-5, 32) * s, orange, 1.2)
		ml(o + Vector2(5, 24) * s, o + Vector2(5, 32) * s, orange, 1.2)

	func draw_mantis(o: Vector2) -> void:
		var s := 0.42
		var wing := PackedVector2Array([
			o + Vector2(0, -25) * s, o + Vector2(10, -12) * s,
			o + Vector2(42, 8) * s, o + Vector2(38, 14) * s,
			o + Vector2(14, 10) * s, o + Vector2(8, 18) * s,
			o + Vector2(-8, 18) * s, o + Vector2(-14, 10) * s,
			o + Vector2(-38, 14) * s, o + Vector2(-42, 8) * s,
			o + Vector2(-10, -12) * s,
		])
		mp(wing, cyan, 1.0)
		ml(o + Vector2(0, -20) * s, o + Vector2(0, 14) * s, magenta, 0.8)
		var can := PackedVector2Array([
			o + Vector2(0, -18) * s, o + Vector2(4, -8) * s,
			o + Vector2(-4, -8) * s,
		])
		if mode == ShipRenderer.RenderMode.CHROME:
			ci.draw_colored_polygon(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.3
			ci.draw_colored_polygon(can, cf)
		ml(o + Vector2(8, 16) * s, o + Vector2(8, 22) * s, orange, 1.2)
		ml(o + Vector2(-8, 16) * s, o + Vector2(-8, 22) * s, orange, 1.2)
		ml(o + Vector2(12, -8) * s, o + Vector2(36, 8) * s, teal, 0.6)
		ml(o + Vector2(-12, -8) * s, o + Vector2(-36, 8) * s, teal, 0.6)

	func draw_corsair(o: Vector2) -> void:
		var s := 0.40
		var hull := PackedVector2Array([
			o + Vector2(-2, -34) * s, o + Vector2(6, -22) * s,
			o + Vector2(7, -4) * s, o + Vector2(7, 16) * s,
			o + Vector2(5, 26) * s, o + Vector2(-7, 26) * s,
			o + Vector2(-9, 16) * s, o + Vector2(-9, -4) * s,
			o + Vector2(-7, -22) * s,
		])
		mp(hull, cyan, 0.8)
		var rb := PackedVector2Array([
			o + Vector2(7, -8) * s, o + Vector2(16, -16) * s,
			o + Vector2(26, -12) * s, o + Vector2(24, -4) * s,
			o + Vector2(14, -2) * s, o + Vector2(7, 2) * s,
		])
		mp(rb, cyan, 0.7)
		var lp := PackedVector2Array([
			o + Vector2(-9, 0) * s, o + Vector2(-16, -2) * s,
			o + Vector2(-20, 4) * s, o + Vector2(-20, 18) * s,
			o + Vector2(-16, 24) * s, o + Vector2(-9, 20) * s,
		])
		mp(lp, teal, 0.6)
		ml(o + Vector2(24, -12) * s, o + Vector2(26, -22) * s, magenta, 0.7)
		ml(o + Vector2(0, -6) * s, o + Vector2(0, 22) * s, magenta, 0.5)
		ml(o + Vector2(3, 24) * s, o + Vector2(3, 32) * s, orange, 1.0)
		ml(o + Vector2(-17, 22) * s, o + Vector2(-17, 30) * s, orange, 1.0)

	func draw_stiletto(o: Vector2) -> void:
		var s := 0.5
		var hull := PackedVector2Array([
			o + Vector2(0, -32) * s, o + Vector2(12, -10) * s,
			o + Vector2(26, 4) * s, o + Vector2(20, 12) * s,
			o + Vector2(8, 22) * s, o + Vector2(-8, 22) * s,
			o + Vector2(-20, 12) * s, o + Vector2(-26, 4) * s,
			o + Vector2(-12, -10) * s,
		])
		mp(hull, cyan, 1.0)
		ml(o + Vector2(0, -28) * s, o + Vector2(12, -10) * s, teal, 0.6)
		ml(o + Vector2(0, -28) * s, o + Vector2(-12, -10) * s, teal, 0.6)
		ml(o + Vector2(12, -10) * s, o + Vector2(8, 22) * s, teal, 0.6)
		ml(o + Vector2(-12, -10) * s, o + Vector2(-8, 22) * s, teal, 0.6)
		var can := PackedVector2Array([
			o + Vector2(0, -24) * s, o + Vector2(6, -12) * s,
			o + Vector2(4, -6) * s, o + Vector2(-4, -6) * s, o + Vector2(-6, -12) * s,
		])
		if mode == ShipRenderer.RenderMode.CHROME:
			ci.draw_colored_polygon(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.25
			ci.draw_colored_polygon(can, cf)
		ml(o + Vector2(0, -6) * s, o + Vector2(0, 18) * s, magenta, 0.8)
		ml(o + Vector2(-4, 20) * s, o + Vector2(-4, 27) * s, orange, 1.5)
		ml(o + Vector2(4, 20) * s, o + Vector2(4, 27) * s, orange, 1.5)

	func draw_trident(o: Vector2) -> void:
		var s := 0.48
		var hull := PackedVector2Array([
			o + Vector2(0, -36) * s, o + Vector2(5, -22) * s,
			o + Vector2(7, -5) * s, o + Vector2(8, 15) * s,
			o + Vector2(6, 26) * s, o + Vector2(-6, 26) * s,
			o + Vector2(-8, 15) * s, o + Vector2(-7, -5) * s,
			o + Vector2(-5, -22) * s,
		])
		mp(hull, cyan, 1.0)
		var rf := PackedVector2Array([
			o + Vector2(5, -18) * s, o + Vector2(12, -24) * s,
			o + Vector2(26, -36) * s, o + Vector2(30, -40) * s,
			o + Vector2(24, -30) * s, o + Vector2(16, -14) * s,
			o + Vector2(10, -6) * s, o + Vector2(6, -8) * s,
		])
		mp(rf, cyan, 0.7)
		ml(o + Vector2(16, -14) * s, o + Vector2(22, -10) * s, teal, 0.5)
		ml(o + Vector2(6, -14) * s, o + Vector2(26, -36) * s, magenta, 0.4)
		var lf := PackedVector2Array([
			o + Vector2(-5, -18) * s, o + Vector2(-12, -24) * s,
			o + Vector2(-26, -36) * s, o + Vector2(-30, -40) * s,
			o + Vector2(-24, -30) * s, o + Vector2(-16, -14) * s,
			o + Vector2(-10, -6) * s, o + Vector2(-6, -8) * s,
		])
		mp(lf, cyan, 0.7)
		ml(o + Vector2(-16, -14) * s, o + Vector2(-22, -10) * s, teal, 0.5)
		ml(o + Vector2(-6, -14) * s, o + Vector2(-26, -36) * s, magenta, 0.4)
		var re := PackedVector2Array([
			o + Vector2(8, 12) * s, o + Vector2(14, 14) * s,
			o + Vector2(16, 26) * s, o + Vector2(12, 28) * s, o + Vector2(8, 22) * s,
		])
		mp(re, cyan, 0.7)
		var le := PackedVector2Array([
			o + Vector2(-8, 12) * s, o + Vector2(-14, 14) * s,
			o + Vector2(-16, 26) * s, o + Vector2(-12, 28) * s, o + Vector2(-8, 22) * s,
		])
		mp(le, cyan, 0.7)
		var can := PackedVector2Array([
			o + Vector2(0, -30) * s, o + Vector2(3, -18) * s,
			o + Vector2(-3, -18) * s,
		])
		if mode == ShipRenderer.RenderMode.CHROME:
			ci.draw_colored_polygon(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.25
			ci.draw_colored_polygon(can, cf)
		ml(o + Vector2(0, -18) * s, o + Vector2(0, 22) * s, magenta, 0.7)
		ml(o + Vector2(0, 24) * s, o + Vector2(0, 32) * s, orange, 1.5)
		ml(o + Vector2(13, 26) * s, o + Vector2(13, 33) * s, orange, 1.2)
		ml(o + Vector2(-13, 26) * s, o + Vector2(-13, 33) * s, orange, 1.2)

	func draw_orrery(o: Vector2) -> void:
		var s := 0.32
		var core := PackedVector2Array([
			o + Vector2(0, -14) * s, o + Vector2(7, -12) * s,
			o + Vector2(12, -7) * s, o + Vector2(14, 0) * s,
			o + Vector2(12, 7) * s, o + Vector2(7, 12) * s,
			o + Vector2(0, 14) * s, o + Vector2(-7, 12) * s,
			o + Vector2(-12, 7) * s, o + Vector2(-14, 0) * s,
			o + Vector2(-12, -7) * s, o + Vector2(-7, -12) * s,
		])
		mp(core, cyan, 0.8)
		var ra := PackedVector2Array([
			o + Vector2(18, -18) * s, o + Vector2(27, -16) * s,
			o + Vector2(32, 0) * s, o + Vector2(27, 16) * s,
			o + Vector2(18, 18) * s, o + Vector2(20, 12) * s,
			o + Vector2(24, 0) * s, o + Vector2(20, -12) * s,
		])
		mp(ra, cyan, 0.6)
		var la := PackedVector2Array([
			o + Vector2(-18, -18) * s, o + Vector2(-27, -16) * s,
			o + Vector2(-32, 0) * s, o + Vector2(-27, 16) * s,
			o + Vector2(-18, 18) * s, o + Vector2(-20, 12) * s,
			o + Vector2(-24, 0) * s, o + Vector2(-20, -12) * s,
		])
		mp(la, cyan, 0.6)
		ml(o + Vector2(14, 0) * s, o + Vector2(24, 0) * s, teal, 0.5)
		ml(o + Vector2(-14, 0) * s, o + Vector2(-24, 0) * s, teal, 0.5)
		ml(o + Vector2(12, -7) * s, o + Vector2(18, -18) * s, teal, 0.4)
		ml(o + Vector2(-12, -7) * s, o + Vector2(-18, -18) * s, teal, 0.4)
		ml(o + Vector2(0, -14) * s, o + Vector2(0, -22) * s, magenta, 0.6)
		ml(o + Vector2(-6, 24) * s, o + Vector2(-6, 32) * s, orange, 0.8)
		ml(o + Vector2(0, 26) * s, o + Vector2(0, 34) * s, orange, 0.8)
		ml(o + Vector2(6, 24) * s, o + Vector2(6, 32) * s, orange, 0.8)

	func draw_dreadnought(o: Vector2) -> void:
		var s := 0.28
		var hull := PackedVector2Array([
			o + Vector2(-4, -48) * s, o + Vector2(4, -48) * s,
			o + Vector2(16, -40) * s, o + Vector2(20, -26) * s,
			o + Vector2(20, 26) * s, o + Vector2(18, 36) * s,
			o + Vector2(16, 42) * s, o + Vector2(-16, 42) * s,
			o + Vector2(-18, 36) * s, o + Vector2(-20, 26) * s,
			o + Vector2(-20, -26) * s, o + Vector2(-16, -40) * s,
		])
		mp(hull, cyan, 0.8)
		var rhb := PackedVector2Array([
			o + Vector2(20, -8) * s, o + Vector2(26, -6) * s,
			o + Vector2(26, 8) * s, o + Vector2(20, 10) * s,
		])
		mp(rhb, teal, 0.5)
		var lhb := PackedVector2Array([
			o + Vector2(-20, -8) * s, o + Vector2(-26, -6) * s,
			o + Vector2(-26, 8) * s, o + Vector2(-20, 10) * s,
		])
		mp(lhb, teal, 0.5)
		ml(o + Vector2(20, -22) * s, o + Vector2(26, -22) * s, magenta, 0.6)
		ml(o + Vector2(-20, -22) * s, o + Vector2(-26, -22) * s, magenta, 0.6)
		ml(o + Vector2(20, 18) * s, o + Vector2(26, 18) * s, magenta, 0.6)
		ml(o + Vector2(-20, 18) * s, o + Vector2(-26, 18) * s, magenta, 0.6)
		ml(o + Vector2(-18, -10) * s, o + Vector2(18, -10) * s, teal, 0.3)
		ml(o + Vector2(-18, 0) * s, o + Vector2(18, 0) * s, teal, 0.3)
		ml(o + Vector2(-18, 12) * s, o + Vector2(18, 12) * s, teal, 0.3)
		ml(o + Vector2(0, -30) * s, o + Vector2(0, 38) * s, magenta, 0.5)
		ml(o + Vector2(-12, 40) * s, o + Vector2(-12, 48) * s, orange, 0.6)
		ml(o + Vector2(-6, 40) * s, o + Vector2(-6, 48) * s, orange, 0.6)
		ml(o + Vector2(0, 40) * s, o + Vector2(0, 48) * s, orange, 0.6)
		ml(o + Vector2(6, 40) * s, o + Vector2(6, 48) * s, orange, 0.6)
		ml(o + Vector2(12, 40) * s, o + Vector2(12, 48) * s, orange, 0.6)

	func draw_bastion(o: Vector2) -> void:
		var s := 0.30
		var t1 := PackedVector2Array([
			o + Vector2(-28, 10) * s, o + Vector2(28, 10) * s,
			o + Vector2(28, 44) * s, o + Vector2(-28, 44) * s,
		])
		mp(t1, cyan, 0.8)
		var t2 := PackedVector2Array([
			o + Vector2(-22, -14) * s, o + Vector2(22, -14) * s,
			o + Vector2(22, 12) * s, o + Vector2(-22, 12) * s,
		])
		mp(t2, cyan, 0.7)
		var t3 := PackedVector2Array([
			o + Vector2(-16, -34) * s, o + Vector2(16, -34) * s,
			o + Vector2(16, -12) * s, o + Vector2(-16, -12) * s,
		])
		mp(t3, cyan, 0.7)
		var t4 := PackedVector2Array([
			o + Vector2(-10, -48) * s, o + Vector2(10, -48) * s,
			o + Vector2(10, -32) * s, o + Vector2(-10, -32) * s,
		])
		mp(t4, cyan, 0.6)
		ml(o + Vector2(-28, 10) * s, o + Vector2(28, 10) * s, magenta, 0.5)
		ml(o + Vector2(-22, -14) * s, o + Vector2(22, -14) * s, magenta, 0.5)
		ml(o + Vector2(-16, -34) * s, o + Vector2(16, -34) * s, magenta, 0.4)
		ml(o + Vector2(-28, 24) * s, o + Vector2(28, 24) * s, teal, 0.3)
		ml(o + Vector2(-28, 36) * s, o + Vector2(28, 36) * s, teal, 0.3)
		ml(o + Vector2(-2, -44) * s, o + Vector2(-2, 40) * s, magenta, 0.3)
		ml(o + Vector2(2, -44) * s, o + Vector2(2, 40) * s, magenta, 0.3)
		ml(o + Vector2(-20, 44) * s, o + Vector2(-20, 52) * s, orange, 0.8)
		ml(o + Vector2(-12, 44) * s, o + Vector2(-12, 52) * s, orange, 0.8)
		ml(o + Vector2(-4, 44) * s, o + Vector2(-4, 52) * s, orange, 0.8)
		ml(o + Vector2(4, 44) * s, o + Vector2(4, 52) * s, orange, 0.8)
		ml(o + Vector2(12, 44) * s, o + Vector2(12, 52) * s, orange, 0.8)
		ml(o + Vector2(20, 44) * s, o + Vector2(20, 52) * s, orange, 0.8)

	# ── Enemy ship thumbnails ──

	func draw_sentinel(o: Vector2) -> void:
		var s := 0.5
		var r: float = 16.0 * s
		# Circle body
		var circle_pts := PackedVector2Array()
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			circle_pts.append(o + Vector2(cos(angle) * r, sin(angle) * r))
		mp(circle_pts, cyan, 0.8)
		# Inner hexagon
		var hex_pts := PackedVector2Array()
		var hex_r: float = 9.0 * s
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0
			hex_pts.append(o + Vector2(cos(angle) * hex_r, sin(angle) * hex_r))
		mp(hex_pts, magenta, 0.6)
		# Center dot
		ci.draw_circle(o, 2.0, cyan)

	func draw_dart(o: Vector2) -> void:
		var s := 0.5
		# Narrow arrowhead facing down
		var body := PackedVector2Array([
			o + Vector2(0, 18) * s,
			o + Vector2(8, -4) * s,
			o + Vector2(5, -16) * s,
			o + Vector2(0, -12) * s,
			o + Vector2(-5, -16) * s,
			o + Vector2(-8, -4) * s,
		])
		mp(body, cyan, 0.7)
		ml(o + Vector2(8, -4) * s, o + Vector2(12, 2) * s, magenta, 0.5)
		ml(o + Vector2(-8, -4) * s, o + Vector2(-12, 2) * s, magenta, 0.5)
		ml(o + Vector2(0, 14) * s, o + Vector2(0, -10) * s, teal, 0.4)
		ci.draw_circle(o + Vector2(0, -14) * s, 1.5, orange)

	func draw_crucible(o: Vector2) -> void:
		var s := 0.4
		# Wide hexagon
		var hex := PackedVector2Array([
			o + Vector2(0, -16) * s, o + Vector2(14, -8) * s,
			o + Vector2(14, 8) * s, o + Vector2(0, 16) * s,
			o + Vector2(-14, 8) * s, o + Vector2(-14, -8) * s,
		])
		mp(hex, cyan, 0.8)
		# Side nacelles
		var rn := PackedVector2Array([
			o + Vector2(14, -4) * s, o + Vector2(20, -6) * s,
			o + Vector2(20, 10) * s, o + Vector2(14, 8) * s,
		])
		mp(rn, cyan, 0.6)
		var ln := PackedVector2Array([
			o + Vector2(-14, -4) * s, o + Vector2(-20, -6) * s,
			o + Vector2(-20, 10) * s, o + Vector2(-14, 8) * s,
		])
		mp(ln, cyan, 0.6)
		# Forward pylons
		ml(o + Vector2(4, -16) * s, o + Vector2(3, -24) * s, magenta, 0.6)
		ml(o + Vector2(-4, -16) * s, o + Vector2(-3, -24) * s, magenta, 0.6)
		ci.draw_circle(o, 2.0, teal)

	func draw_prism(o: Vector2) -> void:
		var s := 0.45
		# 3 static triangles at different angles
		var radii: Array[float] = [14.0, 10.0, 6.0]
		var offsets: Array[float] = [0.0, 0.5, 1.2]
		var cols: Array[Color] = [cyan, magenta, teal]
		var wids: Array[float] = [0.8, 0.6, 0.5]
		for t_idx in range(3):
			var tri := PackedVector2Array()
			var r: float = radii[t_idx] * s
			for i in range(3):
				var angle: float = TAU * float(i) / 3.0 + offsets[t_idx]
				tri.append(o + Vector2(cos(angle) * r, sin(angle) * r))
			mp(tri, cols[t_idx], wids[t_idx])
		ci.draw_circle(o, 2.0, Color(1.0, 1.0, 1.0, 0.7))

	func draw_scythe(o: Vector2) -> void:
		var s := 0.45
		# Crescent blade — U opens downward
		var blade := PackedVector2Array()
		var rot: float = -PI * 0.5
		var pts := 8
		for i in range(pts):
			var t: float = float(i) / float(pts - 1)
			var angle: float = -PI * 0.6 + t * PI * 1.2 + rot
			var r: float = 16.0 * s
			blade.append(o + Vector2(cos(angle) * r, sin(angle) * r))
		for i in range(pts - 1, -1, -1):
			var t: float = float(i) / float(pts - 1)
			var angle: float = -PI * 0.6 + t * PI * 1.2 + rot
			var r: float = 9.0 * s
			blade.append(o + Vector2(cos(angle) * r, sin(angle) * r))
		mp(blade, cyan, 0.7)
		# Cockpit
		var cp := PackedVector2Array([
			o + Vector2(3, -2) * s, o + Vector2(3, 2) * s,
			o + Vector2(-2, 3) * s, o + Vector2(-2, -3) * s,
		])
		mp(cp, magenta, 0.5)

	func draw_tesseract(o: Vector2) -> void:
		var s := 0.45
		# 3 nested squares
		var sizes: Array[float] = [14.0, 10.0, 5.5]
		var cols: Array[Color] = [cyan, magenta, teal]
		var wids: Array[float] = [0.8, 0.6, 0.5]
		for sq_idx in range(3):
			var h: float = sizes[sq_idx] * s
			var sq := PackedVector2Array([
				o + Vector2(-h, -h), o + Vector2(h, -h),
				o + Vector2(h, h), o + Vector2(-h, h),
			])
			mp(sq, cols[sq_idx], wids[sq_idx])
		# Corner wireframe lines
		var oh: float = sizes[0] * s
		var ih: float = sizes[2] * s
		ml(o + Vector2(-oh, -oh), o + Vector2(-ih, -ih), teal, 0.3)
		ml(o + Vector2(oh, -oh), o + Vector2(ih, -ih), teal, 0.3)
		ml(o + Vector2(oh, oh), o + Vector2(ih, ih), teal, 0.3)
		ml(o + Vector2(-oh, oh), o + Vector2(-ih, ih), teal, 0.3)
		ci.draw_circle(o, 1.5, Color(1.0, 1.0, 1.0, 0.7))

	func draw_talon(o: Vector2) -> void:
		var s := 0.45
		# Twin booms facing down
		var rb := PackedVector2Array([
			o + Vector2(6, 18) * s, o + Vector2(10, 18) * s,
			o + Vector2(11, -12) * s, o + Vector2(5, -12) * s,
		])
		mp(rb, cyan, 0.7)
		var lb := PackedVector2Array([
			o + Vector2(-6, 18) * s, o + Vector2(-10, 18) * s,
			o + Vector2(-11, -12) * s, o + Vector2(-5, -12) * s,
		])
		mp(lb, cyan, 0.7)
		# Crossbar wing
		var wing := PackedVector2Array([
			o + Vector2(-12, 2) * s, o + Vector2(12, 2) * s,
			o + Vector2(13, -2) * s, o + Vector2(-13, -2) * s,
		])
		mp(wing, cyan, 0.6)
		# Weapon pod diamond
		var pod := PackedVector2Array([
			o + Vector2(0, 24) * s, o + Vector2(3, 18) * s,
			o + Vector2(0, 12) * s, o + Vector2(-3, 18) * s,
		])
		mp(pod, magenta, 0.5)
		ci.draw_circle(o + Vector2(8, -12) * s, 1.5, orange)
		ci.draw_circle(o + Vector2(-8, -12) * s, 1.5, orange)

	func draw_obelisk(o: Vector2) -> void:
		var s := 0.45
		# Tall narrow rectangle (static, no rotation in thumbnail)
		var hw: float = 5.0 * s
		var hh: float = 16.0 * s
		var rect := PackedVector2Array([
			o + Vector2(-hw, -hh), o + Vector2(hw, -hh),
			o + Vector2(hw, hh), o + Vector2(-hw, hh),
		])
		mp(rect, cyan, 0.8)
		# Scan line
		ml(o + Vector2(-hw * 0.7, 0), o + Vector2(hw * 0.7, 0), magenta, 0.5)
		# Corner dots
		for corner in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
			ci.draw_circle(o + corner, 1.5, teal)
