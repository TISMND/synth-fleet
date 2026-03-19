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


## Draw a sentinel enemy thumbnail on any CanvasItem.
static func draw_sentinel_on(ci: CanvasItem, at_origin: Vector2, mode: int) -> void:
	var ctx := _DrawCtx.new(ci, mode)
	var s := 0.5
	var r: float = 16.0 * s
	var cyan_col := Color(0.0, 0.9, 1.0)
	var magenta_col := Color(1.0, 0.2, 0.6)
	# Circle body
	var circle_pts := PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		circle_pts.append(at_origin + Vector2(cos(angle) * r, sin(angle) * r))
	ctx.mp(circle_pts, cyan_col, 0.8)
	# Inner hexagon
	var hex_pts := PackedVector2Array()
	var hex_r: float = 9.0 * s
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0
		hex_pts.append(at_origin + Vector2(cos(angle) * hex_r, sin(angle) * hex_r))
	ctx.mp(hex_pts, magenta_col, 0.6)
	# Center dot
	ci.draw_circle(at_origin, 2.0, cyan_col)


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
		if mode == ShipRenderer.RenderMode.CHROME:
			mp_chrome(points, w)
		else:
			mp_neon(points, color, w)

	func ml(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		if mode == ShipRenderer.RenderMode.CHROME:
			ml_chrome(a, b, w)
		else:
			ml_neon(a, b, color, w)

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
