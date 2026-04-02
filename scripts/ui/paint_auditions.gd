extends MarginContainer
## Paint pattern auditions — grid of hull paint patterns on a static Stiletto (STEALTH skin).

const CELL_W: int = 180
const CELL_H: int = 200
const COLS: int = 6
const SHIP_POS := Vector2(90.0, 105.0)
const PAINT_COL := Color(0.85, 0.08, 0.08, 0.92)

var _hull: PackedVector2Array
var _exclusions: Array[PackedVector2Array] = []
var _viewports: Array[SubViewport] = []


func _ready() -> void:
	var s := 1.4
	_hull = PackedVector2Array([
		Vector2(0, -35 * s), Vector2(14 * s, -12 * s), Vector2(28 * s, 4 * s),
		Vector2(22 * s, 14 * s), Vector2(10 * s, 24 * s), Vector2(-10 * s, 24 * s),
		Vector2(-22 * s, 14 * s), Vector2(-28 * s, 4 * s), Vector2(-14 * s, -12 * s),
	])

	# Canopy
	_exclusions.append(PackedVector2Array([
		Vector2(0, -28 * s), Vector2(7 * s, -14 * s), Vector2(5 * s, -6 * s),
		Vector2(-5 * s, -6 * s), Vector2(-7 * s, -14 * s),
	]))

	# Detail lines (TERTIARY) — facet edges, generous hw for clean cutout
	var dhw := 2.0
	_exclusions.append(_thick_line(Vector2(0, -32 * s), Vector2(14 * s, -12 * s), dhw))
	_exclusions.append(_thick_line(Vector2(0, -32 * s), Vector2(-14 * s, -12 * s), dhw))
	_exclusions.append(_thick_line(Vector2(14 * s, -12 * s), Vector2(10 * s, 24 * s), dhw))
	_exclusions.append(_thick_line(Vector2(-14 * s, -12 * s), Vector2(-10 * s, 24 * s), dhw))
	_exclusions.append(_thick_line(Vector2(-14 * s, -12 * s), Vector2(-7 * s, -12 * s), dhw))
	_exclusions.append(_thick_line(Vector2(7 * s, -12 * s), Vector2(14 * s, -12 * s), dhw))

	# Accent line (SECONDARY) — spine
	_exclusions.append(_thick_line(Vector2(0, -6 * s), Vector2(0, 20 * s), 2.5))

	# Engine exhausts
	_exclusions.append(_thick_line(Vector2(-4 * s, 22 * s), Vector2(-4 * s, 30 * s), 3.0))
	_exclusions.append(_thick_line(Vector2(4 * s, 22 * s), Vector2(4 * s, 30 * s), 3.0))
	_build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	for vp in _viewports:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "PAINT PATTERNS — Stiletto (STEALTH skin)    Red = painted area"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for p in _get_patterns():
		grid.add_child(_make_cell(p))


func _make_cell(pattern: Dictionary) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(CELL_W, CELL_H)
	cell.add_child(vpc)

	var vp := SubViewport.new()
	vp.size = Vector2i(CELL_W, CELL_H)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	_viewports.append(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.size = Vector2(CELL_W, CELL_H)
	vp.add_child(bg)

	var ship := ShipRenderer.new()
	ship.ship_id = 4
	ship.render_mode = ShipRenderer.RenderMode.STEALTH
	ship.position = SHIP_POS
	vp.add_child(ship)

	var overlay := _PaintOverlay.new()
	overlay.position = SHIP_POS
	overlay.hull_poly = _hull
	overlay.exclusion_polys = _exclusions
	overlay.paint_shapes = _gen_shapes(pattern)
	overlay.z_index = 2
	vp.add_child(overlay)

	var lbl := Label.new()
	lbl.text = String(pattern.name)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size.x = CELL_W
	lbl.add_theme_font_size_override("font_size", 11)
	ThemeManager.apply_text_glow(lbl, "body")
	cell.add_child(lbl)

	return cell


# ── Shape helpers ──────────────────────────────────────────────────────

func _rect(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x1, y1), Vector2(x2, y1), Vector2(x2, y2), Vector2(x1, y2),
	])


func _rotated_rect(cx: float, cy: float, hw: float, hh: float, angle: float) -> PackedVector2Array:
	var ca := cos(angle)
	var sa := sin(angle)
	var pts := PackedVector2Array()
	for c in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
		pts.append(Vector2(cx + c.x * ca - c.y * sa, cy + c.x * sa + c.y * ca))
	return pts


func _thick_line(a: Vector2, b: Vector2, hw: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	return PackedVector2Array([a + n * hw, b + n * hw, b - n * hw, a - n * hw])


# ── Pattern shape generators ──────────────────────────────────────────

func _gen_shapes(pattern: Dictionary) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	var t: String = pattern.type
	var p: Dictionary = pattern.get("params", {})

	match t:
		"vstripe":
			var xc: float = p.get("x", 0.0)
			var w: float = p.get("w", 6.0)
			shapes.append(_rect(xc - w * 0.5, -60, xc + w * 0.5, 60))

		"vstripes":
			var positions: Array = p.get("positions", [])
			var w: float = p.get("w", 4.0)
			for xc in positions:
				shapes.append(_rect(float(xc) - w * 0.5, -60, float(xc) + w * 0.5, 60))

		"hband":
			var y1: float = p.get("y1", -10.0)
			var y2: float = p.get("y2", 10.0)
			shapes.append(_rect(-60, y1, 60, y2))

		"hbands":
			var bands: Array = p.get("bands", [])
			for b in bands:
				shapes.append(_rect(-60, float(b[0]), 60, float(b[1])))

		"diagonal":
			var angle: float = p.get("angle", 0.6)
			var w: float = p.get("w", 10.0)
			shapes.append(_rotated_rect(0, 0, w * 0.5, 80, angle))

		"chevron":
			var y: float = p.get("y", 0.0)
			var hw: float = p.get("w", 4.0) * 0.5
			var spread: float = p.get("spread", 30.0)
			var dy: float = spread * 0.6
			shapes.append(_thick_line(Vector2(0, y), Vector2(-spread, y + dy), hw))
			shapes.append(_thick_line(Vector2(0, y), Vector2(spread, y + dy), hw))

		"chevrons":
			var ys: Array = p.get("ys", [])
			var hw: float = p.get("w", 3.0) * 0.5
			var spread: float = p.get("spread", 28.0)
			var dy: float = spread * 0.6
			for yc in ys:
				var yf: float = float(yc)
				shapes.append(_thick_line(Vector2(0, yf), Vector2(-spread, yf + dy), hw))
				shapes.append(_thick_line(Vector2(0, yf), Vector2(spread, yf + dy), hw))

		"wing_check":
			# Fine checker only on the outer wing areas
			var sz: float = p.get("size", 6.0)
			var wing_left := _rect(-60, -60, -10, 60)
			var wing_right := _rect(10, -60, 60, 60)
			for ix in range(-7, 8):
				for iy in range(-9, 7):
					if (ix + iy) % 2 == 0:
						var tile := _rect(ix * sz, iy * sz, (ix + 1) * sz, (iy + 1) * sz)
						# Clip tile to left wing region
						var left_clip := Geometry2D.intersect_polygons(tile, wing_left)
						for lp in left_clip:
							shapes.append(lp)
						# Clip tile to right wing region
						var right_clip := Geometry2D.intersect_polygons(tile, wing_right)
						for rp in right_clip:
							shapes.append(rp)

		"wing_tips":
			shapes.append(_rect(-60, -60, -15, 60))
			shapes.append(_rect(15, -60, 60, 60))

		"wedge":
			shapes.append(PackedVector2Array([
				Vector2(-35, -50), Vector2(35, -50), Vector2(6, 0), Vector2(-6, 0),
			]))

		"starburst":
			for i in range(8):
				var a: float = float(i) / 8.0 * TAU
				shapes.append(_thick_line(Vector2.ZERO, Vector2(cos(a) * 45, sin(a) * 45), 2.0))

	return shapes


# ── Pattern definitions ────────────────────────────────────────────────

func _get_patterns() -> Array[Dictionary]:
	var pats: Array[Dictionary] = []

	pats.append({name = "CENTER STRIPE", type = "vstripe", params = {x = 0.0, w = 6.0}})
	pats.append({name = "WIDE BAND", type = "vstripe", params = {x = 0.0, w = 18.0}})
	pats.append({name = "TWIN RACING", type = "vstripes", params = {positions = [-8, 8], w = 4.0}})
	pats.append({name = "TRIPLE LINE", type = "vstripes", params = {positions = [-14, 0, 14], w = 3.0}})
	pats.append({name = "NOSE CAP", type = "hband", params = {y1 = -50.0, y2 = -20.0}})
	pats.append({name = "TAIL BAND", type = "hband", params = {y1 = 15.0, y2 = 35.0}})
	pats.append({name = "THREE BANDS", type = "hbands", params = {bands = [[-45, -32], [-6, 6], [20, 32]]}})
	pats.append({name = "DIAG LEFT", type = "diagonal", params = {angle = -0.6, w = 10.0}})
	pats.append({name = "DIAG RIGHT", type = "diagonal", params = {angle = 0.6, w = 10.0}})
	pats.append({name = "CHEVRON", type = "chevron", params = {y = -5.0, w = 5.0, spread = 32.0}})
	pats.append({name = "DOUBLE CHEVRON", type = "chevrons", params = {ys = [-15, 8], w = 4.0, spread = 26.0}})
	pats.append({name = "STACKED V", type = "chevrons", params = {ys = [-28, -14, 0, 14], w = 3.0, spread = 20.0}})
	pats.append({name = "TIGHT CHEVRONS", type = "chevrons", params = {ys = [-20, -10, 0, 10, 20], w = 2.0, spread = 16.0}})
	pats.append({name = "WING CHECK", type = "wing_check", params = {size = 6.0}})
	pats.append({name = "WING TIPS", type = "wing_tips"})
	pats.append({name = "WEDGE", type = "wedge"})
	pats.append({name = "STARBURST", type = "starburst"})

	return pats


# ── Paint overlay node ─────────────────────────────────────────────────

class _PaintOverlay extends Node2D:
	var hull_poly: PackedVector2Array
	var exclusion_polys: Array[PackedVector2Array] = []
	var paint_shapes: Array[PackedVector2Array] = []

	func _draw() -> void:
		var col := Color(0.85, 0.08, 0.08, 0.92)
		for shape in paint_shapes:
			# Clip to hull first
			var current: Array[PackedVector2Array] = []
			var hull_clipped := Geometry2D.intersect_polygons(shape, hull_poly)
			for hp in hull_clipped:
				current.append(hp)
			# Cut out each exclusion zone (canopy, detail lines, accent, engines)
			for excl in exclusion_polys:
				var next: Array[PackedVector2Array] = []
				for poly in current:
					var clipped := Geometry2D.clip_polygons(poly, excl)
					for cp in clipped:
						next.append(cp)
				current = next
			for fpoly in current:
				draw_colored_polygon(fpoly, col)
