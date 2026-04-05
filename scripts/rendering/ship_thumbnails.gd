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
	var o: Vector2 = at_origin
	var ctx := _DrawCtx.new(ci, mode, scale, at_origin)
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
static func draw_enemy_on(ci: CanvasItem, visual_id: String, at_origin: Vector2, mode: int, scale: float = 1.0) -> void:
	var o: Vector2 = at_origin
	var ctx := _DrawCtx.new(ci, mode, scale, at_origin)
	match visual_id:
		"sentinel": ctx.draw_sentinel(o)
		"dart": ctx.draw_dart(o)
		"crucible": ctx.draw_crucible(o)
		"prism": ctx.draw_prism(o)
		"scythe": ctx.draw_scythe(o)
		"tesseract": ctx.draw_tesseract(o)
		"talon": ctx.draw_talon(o)
		"obelisk": ctx.draw_obelisk(o)
		"ironclad": ctx.draw_ironclad(o)
		"colossus": ctx.draw_colossus(o)
		"leviathan": ctx.draw_leviathan(o)
		"marauder": ctx.draw_marauder(o)
		"wraith": ctx.draw_wraith(o)
		"archon_core": ctx.draw_archon_core(o)
		"archon_wing_l": ctx.draw_archon_wing(o, -1.0)
		"archon_wing_r": ctx.draw_archon_wing(o, 1.0)
		"archon_turret": ctx.draw_archon_turret(o)
		"shard": ctx.draw_shard(o)
		"monolith": ctx.draw_monolith(o)
		"nexus": ctx.draw_nexus(o)
		"pylon": ctx.draw_pylon(o)
		"aegis": ctx.draw_aegis(o)
		"helix": ctx.draw_helix(o)
		"conduit": ctx.draw_conduit(o)
		"spore": ctx.draw_spore(o)
		"polyp": ctx.draw_polyp(o)
		"lamprey": ctx.draw_lamprey(o)
		"anemone": ctx.draw_anemone(o)
		"nautilus": ctx.draw_nautilus(o)
		"behemoth": ctx.draw_behemoth(o)
		"mycelia": ctx.draw_mycelia(o)
		"dreadnought": ctx.draw_dreadnought(o)
		_: ctx.draw_sentinel(o)

## Draw a sentinel enemy thumbnail on any CanvasItem.
static func draw_sentinel_on(ci: CanvasItem, at_origin: Vector2, mode: int) -> void:
	var ctx := _DrawCtx.new(ci, mode)
	ctx.draw_sentinel(at_origin)


# ── Internal draw context — holds CanvasItem ref + render mode for static calls ──

class _DrawCtx:
	var ci: CanvasItem
	var mode: int
	var sc: float  # extra scale multiplier applied relative to origin
	var origin: Vector2  # reference point for scaling

	var cyan := Color(0.0, 0.9, 1.0)
	var magenta := Color(1.0, 0.2, 0.6)
	var orange := Color(1.0, 0.5, 0.1)
	var purple := Color(0.4, 0.2, 1.0)
	var teal := Color(0.0, 1.0, 0.7)
	var _chrome_dark := ShipRenderer.CHROME_DARK
	var _chrome_mid := ShipRenderer.CHROME_MID
	var _chrome_bright := ShipRenderer.CHROME_BRIGHT

	func _init(canvas_item: CanvasItem, render_mode: int, scale: float = 1.0, at_origin: Vector2 = Vector2.ZERO) -> void:
		ci = canvas_item
		mode = render_mode
		sc = scale
		origin = at_origin
		# Apply palette overrides for neon variants
		match mode:
			ShipRenderer.RenderMode.EMBER:
				cyan = ShipRenderer.EMBER_HULL
				magenta = ShipRenderer.EMBER_ACCENT
				orange = ShipRenderer.EMBER_ENGINE
				purple = ShipRenderer.EMBER_CANOPY
				teal = ShipRenderer.EMBER_DETAIL
			ShipRenderer.RenderMode.FROST:
				cyan = ShipRenderer.FROST_HULL
				magenta = ShipRenderer.FROST_ACCENT
				orange = ShipRenderer.FROST_ENGINE
				purple = ShipRenderer.FROST_CANOPY
				teal = ShipRenderer.FROST_DETAIL
			ShipRenderer.RenderMode.SOLAR:
				cyan = ShipRenderer.SOLAR_HULL
				magenta = ShipRenderer.SOLAR_ACCENT
				orange = ShipRenderer.SOLAR_ENGINE
				purple = ShipRenderer.SOLAR_CANOPY
				teal = ShipRenderer.SOLAR_DETAIL
			ShipRenderer.RenderMode.SPORT:
				# Static thumbnail uses a vivid green/magenta combo
				cyan = Color(0.0, 1.0, 0.5)
				magenta = Color(1.0, 0.0, 0.8)
				orange = Color(1.0, 0.8, 0.0)
				purple = Color(0.5, 0.0, 1.0)
				teal = Color(0.0, 0.8, 1.0)
			ShipRenderer.RenderMode.GUNMETAL:
				cyan = ShipRenderer.GUNMETAL_HULL
				magenta = ShipRenderer.GUNMETAL_ACCENT
				orange = ShipRenderer.GUNMETAL_ENGINE
				purple = ShipRenderer.GUNMETAL_CANOPY
				teal = ShipRenderer.GUNMETAL_DETAIL
				_chrome_dark = Color(0.08, 0.09, 0.1)
				_chrome_mid = Color(0.18, 0.19, 0.22)
				_chrome_bright = Color(0.42, 0.44, 0.48)
			ShipRenderer.RenderMode.MILITIA:
				cyan = ShipRenderer.MILITIA_HULL
				magenta = ShipRenderer.MILITIA_ACCENT
				orange = ShipRenderer.MILITIA_ENGINE
				purple = ShipRenderer.MILITIA_CANOPY
				teal = ShipRenderer.MILITIA_DETAIL
				_chrome_dark = Color(0.06, 0.08, 0.04)
				_chrome_mid = Color(0.12, 0.16, 0.08)
				_chrome_bright = Color(0.28, 0.32, 0.18)
			ShipRenderer.RenderMode.STEALTH:
				cyan = ShipRenderer.STEALTH_HULL
				magenta = ShipRenderer.STEALTH_ACCENT
				orange = ShipRenderer.STEALTH_ENGINE
				purple = ShipRenderer.STEALTH_CANOPY
				teal = ShipRenderer.STEALTH_DETAIL
				_chrome_dark = Color(0.04, 0.04, 0.05)
				_chrome_mid = Color(0.09, 0.09, 0.11)
				_chrome_bright = Color(0.20, 0.20, 0.24)

	func _scale_pts(points: PackedVector2Array) -> PackedVector2Array:
		if sc == 1.0:
			return points
		var out := PackedVector2Array()
		out.resize(points.size())
		for i in range(points.size()):
			out[i] = origin + (points[i] - origin) * sc
		return out

	func _sp(p: Vector2) -> Vector2:
		return origin + (p - origin) * sc if sc != 1.0 else p

	func mc(center: Vector2, radius: float, color: Color) -> void:
		ci.draw_circle(_sp(center), radius * sc, color)

	func mpoly(points: PackedVector2Array, color: Color) -> void:
		ci.draw_colored_polygon(_scale_pts(points), color)

	func mp(points: PackedVector2Array, color: Color, w: float) -> void:
		var scaled: PackedVector2Array = _scale_pts(points)
		var sw: float = w * sc
		match mode:
			ShipRenderer.RenderMode.CHROME: mp_chrome(scaled, sw)
			ShipRenderer.RenderMode.VOID: mp_void(scaled, sw)
			ShipRenderer.RenderMode.HIVEMIND: mp_hivemind(scaled, sw)
			ShipRenderer.RenderMode.SPORE: mp_spore(scaled, sw)
			ShipRenderer.RenderMode.GUNMETAL: mp_gunmetal(scaled, sw)
			ShipRenderer.RenderMode.MILITIA: mp_militia(scaled, sw)
			ShipRenderer.RenderMode.STEALTH: mp_stealth(scaled, sw)
			_: mp_neon(scaled, color, sw)

	func ml(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		var sa: Vector2 = _sp(a)
		var sb: Vector2 = _sp(b)
		var sw: float = w * sc
		match mode:
			ShipRenderer.RenderMode.CHROME: ml_chrome(sa, sb, sw)
			ShipRenderer.RenderMode.VOID: ml_void(sa, sb, sw)
			ShipRenderer.RenderMode.HIVEMIND: ml_hivemind(sa, sb, sw)
			ShipRenderer.RenderMode.SPORE: ml_spore(sa, sb, sw)
			ShipRenderer.RenderMode.GUNMETAL: ml_gunmetal(sa, sb, sw)
			ShipRenderer.RenderMode.MILITIA: ml_militia(sa, sb, sw)
			ShipRenderer.RenderMode.STEALTH: ml_stealth(sa, sb, sw)
			_: ml_neon(sa, sb, color, sw)

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
		ci.draw_colored_polygon(points, _chrome_mid)
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
				var edge_col: Color = _chrome_dark.lerp(_chrome_bright, t)
				edge_col.a = 0.8
				ci.draw_line(points[j], points[nj], edge_col, w, true)

	func ml_chrome(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, _chrome_mid, w * 1.2, true)
		ci.draw_line(a, b, _chrome_bright, w * 0.6, true)

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

	# ── Gunmetal thumbnail helpers ──

	func mp_gunmetal(points: PackedVector2Array, w: float) -> void:
		if points.size() < 3:
			return
		ci.draw_colored_polygon(points, ShipRenderer.GUNMETAL_HULL)
		# Dark heavy border
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], Color(0.08, 0.08, 0.1), w * 1.6, true)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], ShipRenderer.GUNMETAL_DETAIL, w * 0.5, true)
		# Rivet dots
		for pt in points:
			ci.draw_circle(pt, w * 0.5, Color(0.5, 0.52, 0.55))

	func ml_gunmetal(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, Color(0.08, 0.08, 0.1), w * 1.4, true)
		ci.draw_line(a, b, ShipRenderer.GUNMETAL_ACCENT, w, true)
		ci.draw_circle(a, w * 0.5, Color(0.5, 0.52, 0.55))
		ci.draw_circle(b, w * 0.5, Color(0.5, 0.52, 0.55))

	# ── Militia thumbnail helpers ──

	func mp_militia(points: PackedVector2Array, w: float) -> void:
		if points.size() < 3:
			return
		ci.draw_colored_polygon(points, ShipRenderer.MILITIA_HULL)
		# Hard stencil edges
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], Color(0.1, 0.1, 0.05), w * 1.3, true)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], ShipRenderer.MILITIA_DETAIL, w * 0.4, true)

	func ml_militia(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, Color(0.1, 0.1, 0.05), w * 1.3, true)
		ci.draw_line(a, b, ShipRenderer.MILITIA_ACCENT, w, true)

	# ── Stealth thumbnail helpers ──

	func mp_stealth(points: PackedVector2Array, w: float) -> void:
		if points.size() < 3:
			return
		ci.draw_colored_polygon(points, ShipRenderer.STEALTH_HULL)
		# Near-invisible edges with faint catch-light
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], Color(0.02, 0.02, 0.03), w * 1.0, true)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			ci.draw_line(points[j], points[nj], Color(0.2, 0.2, 0.24, 0.4), w * 0.3, true)

	func ml_stealth(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, Color(0.02, 0.02, 0.03), w * 1.0, true)
		ci.draw_line(a, b, ShipRenderer.STEALTH_DETAIL, w * 0.4, true)

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
			mpoly(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.3
			mpoly(can, cf)
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
			mpoly(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.25
			mpoly(can, cf)
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
			mpoly(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.25
			mpoly(can, cf)
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
		mc(o, 2.0, cyan)

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
		mc(o + Vector2(0, -14) * s, 1.5, orange)

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
		mc(o, 2.0, teal)

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
		mc(o, 2.0, Color(1.0, 1.0, 1.0, 0.7))

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
		mc(o, 1.5, Color(1.0, 1.0, 1.0, 0.7))

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
		mc(o + Vector2(8, -12) * s, 1.5, orange)
		mc(o + Vector2(-8, -12) * s, 1.5, orange)

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
			mc(o + corner, 1.5, teal)

	func draw_ironclad(o: Vector2) -> void:
		var s := 0.35
		# Cuttlefish — torpedo mantle with side fins and front tendrils
		var mantle := PackedVector2Array()
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			var rx: float = 8.0 * s
			var ry: float = 16.0 * s
			var y_raw: float = sin(angle)
			if y_raw < 0.0:
				rx *= (1.0 + y_raw * 0.5)
			mantle.append(o + Vector2(cos(angle) * rx, y_raw * ry))
		mp(mantle, cyan, 0.8)
		# Side fins — wavy outline
		for side_val in [-1.0, 1.0]:
			var fin := PackedVector2Array()
			for i in range(8):
				var frac: float = float(i) / 7.0
				var fy: float = lerpf(12.0, -12.0, frac) * s
				var fw: float = sin(frac * PI) * 10.0 * s
				fin.append(o + Vector2(side_val * (7.0 * s + fw), fy))
			# Return along body edge
			for i in range(7, -1, -1):
				var frac: float = float(i) / 7.0
				var fy: float = lerpf(12.0, -12.0, frac) * s
				fin.append(o + Vector2(side_val * 7.0 * s, fy))
			mp(fin, cyan, 0.5)
		# Cuttlebone line
		ml(o + Vector2(0, 12) * s, o + Vector2(0, -12) * s, teal, 0.4)
		# Front tendrils
		for side_val in [-1.0, 1.0]:
			for t in range(3):
				var bx: float = side_val * (1.5 + float(t) * 1.5) * s
				ml(o + Vector2(bx, 16) * s, o + Vector2(bx + side_val * 2.0 * s, 24 * s), magenta, 0.4)
		# Eyes
		mc(o + Vector2(-6, 6) * s, 1.8 * s, teal)
		mc(o + Vector2(6, 6) * s, 1.8 * s, teal)

	func draw_colossus(o: Vector2) -> void:
		var s := 0.30
		# Eldritch eye creature — blobby body, central eye, radiating tendrils
		var body := PackedVector2Array()
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			var r: float = 18.0 * s + sin(angle * 3.0) * 3.0 * s
			body.append(o + Vector2(cos(angle) * r, sin(angle) * r))
		mp(body, cyan, 0.8)
		# Inner membrane ring
		var membrane := PackedVector2Array()
		for i in range(12):
			var angle: float = TAU * float(i) / 12.0
			var r: float = 10.0 * s
			membrane.append(o + Vector2(cos(angle) * r, sin(angle) * r))
		mp(membrane, Color(magenta.r, magenta.g, magenta.b, 0.3), 0.4)
		# Central eye
		mc(o, 5.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.4))
		mc(o, 3.0 * s, Color(0.0, 0.0, 0.0, 0.8))
		mc(o + Vector2(1, -1) * s, 1.0 * s, Color(1.0, 1.0, 1.0, 0.8))
		# Radiating tendrils
		for i in range(9):
			var angle: float = TAU * float(i) / 9.0
			var base_pt: Vector2 = o + Vector2(cos(angle) * 16.0 * s, sin(angle) * 16.0 * s)
			var tip: Vector2 = o + Vector2(cos(angle) * 30.0 * s, sin(angle) * 30.0 * s)
			ml(base_pt, tip, cyan, 0.5)
			mc(tip, 1.2 * s, teal)

	func draw_leviathan(o: Vector2) -> void:
		var s := 0.30
		# Jellyfish — dome cap forward (+Y), tentacles trailing behind (-Y)
		var dome := PackedVector2Array()
		var dome_r: float = 16.0 * s
		for i in range(13):
			var angle: float = PI * float(i) / 12.0  # 0 to PI = top semicircle
			dome.append(o + Vector2(cos(angle) * dome_r, 4.0 * s + sin(angle) * dome_r * 0.7))
		mp(dome, cyan, 0.8)
		# Organ glow inside bell
		mc(o + Vector2(-3, 14) * s, 3.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.3))
		mc(o + Vector2(2, 10) * s, 2.5 * s, Color(teal.r, teal.g, teal.b, 0.4))
		# Trailing tentacles
		for t in range(5):
			var tx: float = lerpf(-12.0, 12.0, float(t) / 4.0) * s
			var base_pt: Vector2 = o + Vector2(tx, 4.0 * s)
			var tip: Vector2 = o + Vector2(tx + sin(float(t) * 1.5) * 4.0 * s, -20.0 * s)
			ml(base_pt, tip, cyan, 0.5)
			mc(tip, 1.0 * s, magenta)
		# Bell rim dots
		for i in range(8):
			var angle: float = PI * float(i) / 7.0
			var pt: Vector2 = o + Vector2(cos(angle) * dome_r, 4.0 * s)
			mc(pt, 1.0 * s, teal)

	func draw_marauder(o: Vector2) -> void:
		var s := 0.35
		# Concentric pentagons with orbiting satellites
		for ring in range(3):
			var ring_r: float = (18.0 - float(ring) * 6.0) * s
			var ring_col: Color = cyan if ring == 0 else (magenta if ring == 1 else teal)
			var pts := PackedVector2Array()
			for i in range(5):
				var angle: float = TAU * float(i) / 5.0 + float(ring) * 0.3
				pts.append(o + Vector2(cos(angle) * ring_r, sin(angle) * ring_r))
			mp(pts, ring_col, 0.6 + float(ring) * 0.1)
		# Spokes connecting outer to mid
		for i in range(5):
			var a_out: float = TAU * float(i) / 5.0
			var a_mid: float = TAU * float(i) / 5.0 + 0.3
			var p1: Vector2 = o + Vector2(cos(a_out) * 18.0 * s, sin(a_out) * 18.0 * s)
			var p2: Vector2 = o + Vector2(cos(a_mid) * 12.0 * s, sin(a_mid) * 12.0 * s)
			ml(p1, p2, Color(teal.r, teal.g, teal.b, 0.3), 0.3)
		# Orbiting satellites — 3 small triangles
		for sat in range(3):
			var orbit_angle: float = TAU * float(sat) / 3.0
			var sat_pos: Vector2 = o + Vector2(cos(orbit_angle) * 24.0 * s, sin(orbit_angle) * 24.0 * s)
			var tri := PackedVector2Array()
			for i in range(3):
				var a: float = TAU * float(i) / 3.0
				tri.append(sat_pos + Vector2(cos(a) * 3.0 * s, sin(a) * 3.0 * s))
			mp(tri, magenta, 0.4)
			ml(o, sat_pos, Color(cyan.r, cyan.g, cyan.b, 0.15), 0.2)
		# Center core
		mc(o, 2.0 * s, Color(1.0, 1.0, 1.0, 0.7))

	func draw_wraith(o: Vector2) -> void:
		var s := 0.35
		# Phase-shifting diamond lattice — nested diamonds with node dots
		for ring in range(4):
			var ring_r: float = (6.0 + float(ring) * 6.0) * s
			var ring_col: Color
			if ring == 0:
				ring_col = teal
			elif ring % 2 == 0:
				ring_col = magenta
			else:
				ring_col = cyan
			ring_col.a = 0.4 + float(3 - ring) * 0.15
			var diamond := PackedVector2Array()
			for i in range(4):
				var angle: float = TAU * float(i) / 4.0 + float(ring) * 0.15
				diamond.append(o + Vector2(cos(angle) * ring_r, sin(angle) * ring_r))
			mp(diamond, ring_col, 0.5 + float(ring) * 0.1)
			# Corner node dots
			for i in range(4):
				var angle: float = TAU * float(i) / 4.0 + float(ring) * 0.15
				var pt: Vector2 = o + Vector2(cos(angle) * ring_r, sin(angle) * ring_r)
				mc(pt, 1.0 * s, teal)
		# Cross-lattice connections
		for i in range(4):
			var a: float = TAU * float(i) / 4.0
			var inner_pt: Vector2 = o + Vector2(cos(a) * 6.0 * s, sin(a) * 6.0 * s)
			var outer_pt: Vector2 = o + Vector2(cos(a + 0.45) * 24.0 * s, sin(a + 0.45) * 24.0 * s)
			ml(inner_pt, outer_pt, Color(magenta.r, magenta.g, magenta.b, 0.15), 0.3)
		# Dark center void
		mc(o, 3.0 * s, Color(0.0, 0.0, 0.0, 0.5))
		mc(o, 1.5 * s, Color(1.0, 1.0, 1.0, 0.7))

	func draw_archon_core(o: Vector2) -> void:
		var s := 0.30
		# Wide inverted-U arch
		var hw: float = 22.0 * s
		var hh: float = 16.0 * s
		var arch := PackedVector2Array()
		arch.append(o + Vector2(-hw, hh * 0.4))
		arch.append(o + Vector2(-hw, -hh * 0.3))
		for i in range(9):
			var t: float = float(i) / 8.0
			var angle: float = PI + t * PI
			arch.append(o + Vector2(cos(angle) * hw, sin(angle) * hh * 0.7 - hh * 0.5))
		arch.append(o + Vector2(hw, -hh * 0.3))
		arch.append(o + Vector2(hw, hh * 0.4))
		mp(arch, cyan, 0.8)
		# Inner cavity cutout hint
		var inner_hw: float = 14.0 * s
		for i in range(7):
			var t: float = float(i) / 6.0
			var angle: float = PI + t * PI
			var px: float = cos(angle) * inner_hw
			var py: float = sin(angle) * 10.0 * s - hh * 0.3
			mc(o + Vector2(px, py), 0.8 * s, Color(magenta.r, magenta.g, magenta.b, 0.3))
		# Crown diamond
		mc(o + Vector2(0, -hh * 0.85), 2.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.6))

	func draw_archon_wing(o: Vector2, side: float = 1.0) -> void:
		var s := 0.18
		var reach: float = 36.0 * s
		var hook: float = 28.0 * s
		var wing := PackedVector2Array()
		for i in range(9):
			var t: float = float(i) / 8.0
			var x: float = side * reach * (1.0 - (1.0 - t) * (1.0 - t))
			var ht: float = clampf((t - 0.5) / 0.5, 0.0, 1.0)
			var y: float = -4.0 * s + ht * ht * hook
			wing.append(o + Vector2(x, y))
		mp(wing, cyan, 0.5)
		mc(o + Vector2(side * reach * 0.95, hook * 0.7), 1.2 * s, teal)

	func draw_archon_turret(o: Vector2) -> void:
		var s := 0.25
		var base := PackedVector2Array()
		for i in range(8):
			var angle: float = TAU * float(i) / 8.0
			base.append(o + Vector2(cos(angle) * 8.0 * s, sin(angle) * 8.0 * s))
		mp(base, cyan, 0.6)
		mc(o, 3.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.5))
		ml(o, o + Vector2(0, 12.0 * s), teal, 0.5)
		mc(o + Vector2(0, 12.0 * s), 1.0 * s, teal)

	# ── Geometric enemies (missing thumbnails) ──

	func draw_shard(o: Vector2) -> void:
		var s := 0.5
		# Sleek diamond hull
		var diamond := PackedVector2Array([
			o + Vector2(0, 16) * s, o + Vector2(7, 0) * s,
			o + Vector2(0, -14) * s, o + Vector2(-7, 0) * s,
		])
		mp(diamond, cyan, 0.8)
		# Inner accent diamond
		var inner := PackedVector2Array([
			o + Vector2(0, 10) * s, o + Vector2(4, 0) * s,
			o + Vector2(0, -9) * s, o + Vector2(-4, 0) * s,
		])
		mp(inner, magenta, 0.6)
		# Core square
		var core_r: float = 3.5 * s
		var sq := PackedVector2Array()
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0
			sq.append(o + Vector2(cos(angle) * core_r, sin(angle) * core_r))
		mp(sq, teal, 0.5)
		mc(o, 1.5, cyan)

	func draw_monolith(o: Vector2) -> void:
		var s := 0.22
		var hw: float = 12.0 * s
		var hh: float = 28.0 * s
		# Tall chamfered slab
		var body := PackedVector2Array([
			o + Vector2(-hw + 3.0 * s, -hh), o + Vector2(hw - 3.0 * s, -hh),
			o + Vector2(hw, -hh + 3.0 * s), o + Vector2(hw, hh - 3.0 * s),
			o + Vector2(hw - 3.0 * s, hh), o + Vector2(-hw + 3.0 * s, hh),
			o + Vector2(-hw, hh - 3.0 * s), o + Vector2(-hw, -hh + 3.0 * s),
		])
		mp(body, cyan, 0.8)
		# Gear outlines at 3 positions
		for gi in range(3):
			var gy: float = (-16.0 + float(gi) * 16.0) * s
			var gr: float = (6.0 + float(gi % 2) * 2.0) * s
			var teeth: int = 8 + gi * 2
			var gear := PackedVector2Array()
			for t in range(teeth * 2):
				var angle: float = TAU * float(t) / float(teeth * 2)
				var tooth_r: float = gr if t % 2 == 0 else gr * 0.7
				gear.append(o + Vector2(cos(angle) * tooth_r, gy + sin(angle) * tooth_r))
			mp(gear, magenta, 0.5)
		# Center diamond
		var dr: float = 5.0 * s
		var diamond := PackedVector2Array([
			o + Vector2(0, dr * 1.3), o + Vector2(dr, 0),
			o + Vector2(0, -dr * 1.3), o + Vector2(-dr, 0),
		])
		mp(diamond, magenta, 0.7)
		mc(o, 1.5, cyan)

	func draw_nexus(o: Vector2) -> void:
		var s := 0.25
		var r_fwd: float = 18.0 * s
		var r_aft: float = 12.0 * s
		var r_side: float = 10.0 * s
		# Diamond hull
		var hull := PackedVector2Array([
			o + Vector2(0, r_fwd), o + Vector2(r_side, 0),
			o + Vector2(0, -r_aft), o + Vector2(-r_side, 0),
		])
		mp(hull, cyan, 0.8)
		# Internal hexagons
		var hex_positions: Array[Vector2] = [
			Vector2(0, 4.0), Vector2(0, -3.0),
			Vector2(5.0, 1.0), Vector2(-5.0, 1.0),
		]
		for hi in range(hex_positions.size()):
			var hpos: Vector2 = hex_positions[hi] * s
			var hr: float = 2.5 * s
			var hex := PackedVector2Array()
			for vi in range(6):
				var angle: float = TAU * float(vi) / 6.0
				hex.append(o + hpos + Vector2(cos(angle) * hr, sin(angle) * hr))
			mp(hex, Color(magenta.r, magenta.g, magenta.b, 0.4), 0.5)
		# Forward tip diamond
		var tip_r: float = 2.5 * s
		var tip := PackedVector2Array([
			o + Vector2(0, r_fwd - 1.0 * s), o + Vector2(tip_r, r_fwd - 5.0 * s),
			o + Vector2(0, r_fwd - 9.0 * s), o + Vector2(-tip_r, r_fwd - 5.0 * s),
		])
		mp(tip, magenta, 0.6)
		mc(o, 1.5, cyan)

	func draw_pylon(o: Vector2) -> void:
		var s := 0.2
		var hw: float = 6.0 * s
		var hh: float = 30.0 * s
		# Central spine
		ml(o + Vector2(0, -hh + 8.0 * s), o + Vector2(0, hh - 8.0 * s), magenta, 0.5)
		# Side rails
		ml(o + Vector2(-hw, -hh + 4.0 * s), o + Vector2(-hw, hh - 4.0 * s), cyan, 0.5)
		ml(o + Vector2(hw, -hh + 4.0 * s), o + Vector2(hw, hh - 4.0 * s), cyan, 0.5)
		# Top/bottom caps
		ml(o + Vector2(-hw, -hh + 4.0 * s), o + Vector2(0, -hh), cyan, 0.6)
		ml(o + Vector2(hw, -hh + 4.0 * s), o + Vector2(0, -hh), cyan, 0.6)
		ml(o + Vector2(-hw, hh - 4.0 * s), o + Vector2(0, hh), cyan, 0.6)
		ml(o + Vector2(hw, hh - 4.0 * s), o + Vector2(0, hh), cyan, 0.6)
		# Diamond nodes along spine
		for ni in range(5):
			var ny: float = lerpf(-hh + 8.0 * s, hh - 8.0 * s, float(ni) / 4.0)
			var nr: float = 3.0 * s
			var diamond := PackedVector2Array([
				o + Vector2(0, ny + nr * 1.4), o + Vector2(nr, ny),
				o + Vector2(0, ny - nr * 1.4), o + Vector2(-nr, ny),
			])
			mp(diamond, magenta, 0.6)
			# Struts to rails
			ml(o + Vector2(-hw, ny), o + Vector2(-nr, ny), Color(teal.r, teal.g, teal.b, 0.3), 0.3)
			ml(o + Vector2(hw, ny), o + Vector2(nr, ny), Color(teal.r, teal.g, teal.b, 0.3), 0.3)

	func draw_aegis(o: Vector2) -> void:
		var s := 0.3
		# Angular wedge hull
		var hull := PackedVector2Array([
			o + Vector2(0, 28.0) * s, o + Vector2(8.0, 18.0) * s,
			o + Vector2(12.0, 4.0) * s, o + Vector2(14.0, -8.0) * s,
			o + Vector2(12.0, -20.0) * s, o + Vector2(6.0, -24.0) * s,
			o + Vector2(-6.0, -24.0) * s, o + Vector2(-12.0, -20.0) * s,
			o + Vector2(-14.0, -8.0) * s, o + Vector2(-12.0, 4.0) * s,
			o + Vector2(-8.0, 18.0) * s,
		])
		mp(hull, cyan, 0.8)
		# Armor seams
		ml(o + Vector2(-10.0, 0) * s, o + Vector2(10.0, 0) * s, teal, 0.3)
		ml(o + Vector2(-12.0, -10.0) * s, o + Vector2(12.0, -10.0) * s, teal, 0.3)
		# Bridge canopy diamond
		var bridge := PackedVector2Array([
			o + Vector2(0, 16.0) * s, o + Vector2(3.5, 11.0) * s,
			o + Vector2(0, 6.0) * s, o + Vector2(-3.5, 11.0) * s,
		])
		mp(bridge, purple, 0.6)
		# Wing weapon pods
		for side_x in [-1.0, 1.0]:
			var pod_x: float = side_x * 14.0 * s
			mc(o + Vector2(pod_x, -8.0 * s), 2.0 * s, magenta)
		# Engine nozzles
		for ei in range(3):
			var ex: float = (-4.0 + float(ei) * 4.0) * s
			mc(o + Vector2(ex, -24.0 * s), 1.5 * s, orange)

	func draw_helix(o: Vector2) -> void:
		var s := 0.25
		var core_r: float = 5.0 * s
		# Central diamond core
		var diamond := PackedVector2Array([
			o + Vector2(0, core_r * 1.5), o + Vector2(core_r, 0),
			o + Vector2(0, -core_r * 1.5), o + Vector2(-core_r, 0),
		])
		mp(diamond, magenta, 0.6)
		# Two spiral arms (static snapshot)
		var arm_length: float = 20.0 * s
		var seg_count: int = 16
		for arm in range(2):
			var arm_phase: float = float(arm) * PI
			var prev: Vector2 = o
			for seg_idx in range(1, seg_count + 1):
				var t: float = float(seg_idx) / float(seg_count)
				var y_pos: float = lerpf(-arm_length, arm_length, t)
				var envelope: float = sin(t * PI)
				var spiral_r: float = (8.0 + envelope * 6.0) * s
				var angle: float = arm_phase + t * 2.5 * TAU
				var x_pos: float = cos(angle) * spiral_r
				var curr: Vector2 = o + Vector2(x_pos, y_pos)
				ml(prev, curr, Color(cyan.r, cyan.g, cyan.b, 0.3 + envelope * 0.4), 0.4)
				prev = curr
		mc(o, 1.5, cyan)

	func draw_conduit(o: Vector2) -> void:
		var s := 0.2
		var hw: float = 9.0 * s
		var hh: float = 28.0 * s
		# Tube walls
		ml(o + Vector2(-hw, -hh), o + Vector2(-hw, hh), cyan, 0.7)
		ml(o + Vector2(hw, -hh), o + Vector2(hw, hh), cyan, 0.7)
		# End caps (simple lines)
		ml(o + Vector2(-hw, -hh), o + Vector2(hw, -hh), cyan, 0.5)
		ml(o + Vector2(-hw, hh), o + Vector2(hw, hh), cyan, 0.5)
		# Cross-ribs
		for ri in range(7):
			var ry: float = lerpf(-hh + 4.0 * s, hh - 4.0 * s, float(ri) / 6.0)
			ml(o + Vector2(-hw, ry), o + Vector2(hw, ry), Color(teal.r, teal.g, teal.b, 0.2), 0.3)
		# Central spine
		ml(o + Vector2(0, -hh + 2.0 * s), o + Vector2(0, hh - 2.0 * s), Color(magenta.r, magenta.g, magenta.b, 0.4), 0.4)
		# Forward diamond emitter
		var dr: float = 4.0 * s
		var diamond := PackedVector2Array([
			o + Vector2(0, hh + dr * 0.5), o + Vector2(dr, hh - dr * 0.8),
			o + Vector2(0, hh - dr * 2.0), o + Vector2(-dr, hh - dr * 0.8),
		])
		mp(diamond, magenta, 0.6)

	# ── Lifeform enemies ──

	func draw_spore(o: Vector2) -> void:
		var s := 0.5
		# Small pulsing body
		mc(o, 5.0 * s, cyan)
		mc(o, 3.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.4))
		mc(o, 1.5 * s, magenta)
		# 3 trailing flagella (static wave)
		for i in range(3):
			var base_angle: float = -PI * 0.5 + float(i - 1) * 0.4
			var prev: Vector2 = o + Vector2(cos(base_angle) * 5.0 * s, sin(base_angle) * 5.0 * s)
			for seg_idx in range(1, 6):
				var frac: float = float(seg_idx) / 5.0
				var wave: float = sin(frac * 4.0 + float(i) * 1.5) * (1.0 + frac * 2.0) * s
				var ny: float = prev.y - 3.0 * s
				var curr := Vector2(prev.x + wave, ny)
				ml(prev, curr, Color(cyan.r, cyan.g, cyan.b, 0.6 - frac * 0.3), 0.4)
				prev = curr

	func draw_polyp(o: Vector2) -> void:
		var s := 0.55
		# Cup body
		var cup := PackedVector2Array([
			o + Vector2(-5.0, -6.0) * s, o + Vector2(-3.0, 6.0) * s,
			o + Vector2(3.0, 6.0) * s, o + Vector2(5.0, -6.0) * s,
		])
		mp(cup, cyan, 0.7)
		# Crown of 5 tentacles
		for i in range(5):
			var spread: float = (float(i) - 2.0) / 2.0
			var base_x: float = spread * 4.0 * s
			var prev: Vector2 = o + Vector2(base_x, -6.0 * s)
			for seg_idx in range(1, 5):
				var frac: float = float(seg_idx) / 4.0
				var wave: float = sin(frac * 3.0 + float(i) * 0.9) * (1.0 + frac * 2.0) * s
				var ny: float = -6.0 * s - frac * 8.0 * s
				var curr: Vector2 = o + Vector2(base_x + wave, ny)
				ml(prev, curr, Color(magenta.r, magenta.g, magenta.b, 0.7 - frac * 0.3), 0.4)
				prev = curr
			mc(prev, 0.5 * s, magenta)

	func draw_lamprey(o: Vector2) -> void:
		var s := 0.35
		var seg_count: int = 12
		var body_len: float = 20.0 * s
		# Sinuous body segments (static S-curve)
		var spine: Array[Vector2] = []
		for i in range(seg_count + 1):
			var frac: float = float(i) / float(seg_count)
			var y: float = lerpf(body_len * 0.5, -body_len * 0.5, frac)
			var wave: float = sin(frac * 5.0) * (1.0 + frac * 2.0) * s
			spine.append(o + Vector2(wave, y))
		for i in range(seg_count):
			var frac: float = float(i) / float(seg_count)
			var width: float = (3.0 + sin(frac * PI) * 2.0) * s
			if frac < 0.15:
				width = lerpf(4.0 * s, width, frac / 0.15)
			var seg_pts := PackedVector2Array([
				spine[i] + Vector2(-width, 0), spine[i] + Vector2(width, 0),
				spine[i + 1] + Vector2(width * 0.95, 0), spine[i + 1] + Vector2(-width * 0.95, 0),
			])
			mp(seg_pts, Color(cyan.r, cyan.g, cyan.b, 0.8 - frac * 0.2), 0.5)
		# Mouth arc at head
		mc(spine[0], 3.0 * s, magenta)
		mc(spine[0], 1.5 * s, Color(0.0, 0.0, 0.0, 0.7))

	func draw_anemone(o: Vector2) -> void:
		var s := 0.4
		var dome_r: float = 10.0 * s
		# Dome body
		var dome := PackedVector2Array()
		for i in range(12):
			var frac: float = float(i) / 11.0
			var angle: float = PI * frac
			dome.append(o + Vector2(cos(angle) * dome_r, -sin(angle) * dome_r * 0.7))
		dome.append(o + Vector2(-dome_r, 0))
		mp(dome, cyan, 0.7)
		# Dense tentacle forest hanging down
		for i in range(9):
			var spread: float = (float(i) - 4.0) / 4.0
			var base_x: float = spread * 8.0 * s
			var prev: Vector2 = o + Vector2(base_x, 1.0 * s)
			var length: float = (6.0 + sin(float(i) * 1.7) * 3.0) * s
			for seg_idx in range(1, 6):
				var frac: float = float(seg_idx) / 5.0
				var wave: float = sin(frac * 3.0 + float(i) * 0.8) * (0.8 + frac * 1.5) * s
				var ny: float = 1.0 * s + frac * length
				var curr: Vector2 = o + Vector2(base_x + wave, ny)
				var t_col: Color = magenta if i % 3 == 0 else cyan
				ml(prev, curr, Color(t_col.r, t_col.g, t_col.b, 0.6 - frac * 0.3), 0.4)
				prev = curr

	func draw_nautilus(o: Vector2) -> void:
		var s := 0.4
		# Shell circle
		mc(o, 9.0 * s, cyan)
		mc(o, 6.0 * s, Color(teal.r, teal.g, teal.b, 0.2))
		# Spiral hint — arc segments
		var prev_pt: Vector2 = o
		for i in range(20):
			var frac: float = float(i) / 20.0
			var angle: float = frac * TAU * 2.0
			var r: float = (1.5 + frac * 6.0) * s
			var pt: Vector2 = o + Vector2(cos(angle) * r, sin(angle) * r * 0.9)
			if i > 0:
				ml(prev_pt, pt, Color(cyan.r, cyan.g, cyan.b, 0.3 + frac * 0.4), 0.3 + frac * 0.3)
			prev_pt = pt
		# Chamber lines
		for i in range(6):
			var angle: float = float(i) * TAU / 6.0
			var inner: Vector2 = o + Vector2(cos(angle) * 3.0 * s, sin(angle) * 3.0 * s)
			var outer: Vector2 = o + Vector2(cos(angle) * 8.0 * s, sin(angle) * 8.0 * s)
			ml(inner, outer, Color(teal.r, teal.g, teal.b, 0.2), 0.3)
		# Eye
		mc(o + Vector2(3.0 * s, -3.0 * s), 1.2 * s, magenta)
		# Tentacles trailing down
		for i in range(4):
			var base_x: float = (float(i) - 1.5) * 2.0 * s
			var prev: Vector2 = o + Vector2(base_x, 9.0 * s)
			for seg_idx in range(1, 5):
				var frac: float = float(seg_idx) / 4.0
				var wave: float = sin(frac * 3.0 + float(i) * 1.3) * (1.0 + frac * 2.0) * s
				var ny: float = 9.0 * s + frac * 8.0 * s
				var curr: Vector2 = o + Vector2(base_x + wave, ny)
				ml(prev, curr, Color(magenta.r, magenta.g, magenta.b, 0.6 - frac * 0.2), 0.3)
				prev = curr

	func draw_behemoth(o: Vector2) -> void:
		var s := 0.25
		# Large bumpy shell
		var shell := PackedVector2Array()
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			var bump: float = (sin(angle * 5.0) * 3.0 + sin(angle * 3.0) * 2.0) * s
			var r: float = 16.0 * s + bump
			shell.append(o + Vector2(cos(angle) * r, sin(angle) * r * 1.1))
		mp(shell, cyan, 0.8)
		# Shell plate lines
		for i in range(7):
			var angle: float = TAU * float(i) / 7.0 + 0.2
			var inner: Vector2 = o + Vector2(cos(angle) * 6.0 * s, sin(angle) * 6.0 * s * 1.1)
			var outer: Vector2 = o + Vector2(cos(angle) * 14.0 * s, sin(angle) * 14.0 * s * 1.1)
			ml(inner, outer, Color(teal.r, teal.g, teal.b, 0.3), 0.4)
		# Organic gaps between plates
		for i in range(7):
			var angle: float = TAU * float(i) / 7.0 + 0.2 + TAU / 14.0
			var gap_r: float = 10.0 * s
			mc(o + Vector2(cos(angle) * gap_r, sin(angle) * gap_r * 1.1), 1.5 * s, Color(magenta.r, magenta.g, magenta.b, 0.4))
		# Central eye cluster
		mc(o, 1.8 * s, magenta)
		mc(o + Vector2(-2.0 * s, -1.0 * s), 1.0 * s, magenta)
		mc(o + Vector2(2.0 * s, -1.0 * s), 1.0 * s, magenta)
		# 6 short legs
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0
			var bump: float = (sin(angle * 5.0) * 3.0 + sin(angle * 3.0) * 2.0) * s
			var edge_r: float = 16.0 * s + bump
			var base: Vector2 = o + Vector2(cos(angle) * edge_r, sin(angle) * edge_r * 1.1)
			var outward := Vector2(cos(angle), sin(angle) * 1.1).normalized()
			var foot: Vector2 = base + outward * 5.0 * s
			ml(base, foot, cyan, 0.4)

	func draw_mycelia(o: Vector2) -> void:
		var s := 0.25
		# Central lumpy spore cap
		var cap := PackedVector2Array()
		for i in range(12):
			var angle: float = TAU * float(i) / 12.0
			var r: float = (7.0 + sin(angle * 4.0) * 1.5) * s
			cap.append(o + Vector2(cos(angle) * r, sin(angle) * r))
		mp(cap, cyan, 0.6)
		# Spore spots
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + 0.3
			var spot_pos: Vector2 = o + Vector2(cos(angle) * 5.0 * s, sin(angle) * 5.0 * s)
			mc(spot_pos, 1.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.2))
		# 6 branching hyphae
		for i in range(6):
			var base_angle: float = TAU * float(i) / 6.0
			var branch_len: float = 12.0 * s
			var seg_count: int = 6
			var prev: Vector2 = o + Vector2(cos(base_angle) * 6.0 * s, sin(base_angle) * 6.0 * s)
			for seg_idx in range(1, seg_count + 1):
				var frac: float = float(seg_idx) / float(seg_count)
				var forward := Vector2(cos(base_angle), sin(base_angle))
				var tangent := Vector2(-forward.y, forward.x)
				var wave: float = sin(frac * 3.0 + float(i) * 1.7) * 1.5 * s
				var curr: Vector2 = prev + forward * (branch_len / float(seg_count)) + tangent * wave * 0.2
				ml(prev, curr, Color(cyan.r, cyan.g, cyan.b, 0.6 - frac * 0.15), 0.4)
				prev = curr
				# Sub-branch at midpoint
				if seg_idx == 3:
					var sub_angle: float = base_angle + 0.5
					var sub_prev: Vector2 = curr
					for sub_seg in range(1, 4):
						var sf: float = float(sub_seg) / 3.0
						var sub_fwd := Vector2(cos(sub_angle), sin(sub_angle))
						var sub_curr: Vector2 = sub_prev + sub_fwd * 3.0 * s
						ml(sub_prev, sub_curr, Color(cyan.r, cyan.g, cyan.b, 0.4 - sf * 0.1), 0.3)
						sub_prev = sub_curr
					mc(sub_prev, 0.8 * s, Color(magenta.r, magenta.g, magenta.b, 0.3))
			# Branch tip
			mc(prev, 1.0 * s, Color(magenta.r, magenta.g, magenta.b, 0.4))
