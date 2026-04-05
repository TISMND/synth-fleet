extends MarginContainer
## Paint patterns — flat color overlays on hull panels per ship.
## Each cell shows a static ship with a colored paint overlay pattern.

const CELL_W: int = 180
const CELL_H: int = 200
const COLS: int = 6

# Ship definitions: [display_name, ship_id, hull_poly, exclusions, ship_pos]
var _ships: Array[Dictionary] = []
var _ship_index: int = 0
var _ship_label: Label = null
var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _static_viewports: Array[SubViewport] = []


func _ready() -> void:
	_init_ships()
	_build_ui()
	_populate_grid()
	await get_tree().process_frame
	await get_tree().process_frame
	for vp in _static_viewports:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _init_ships() -> void:
	_ships.append(_make_stiletto_data())
	_ships.append(_make_cargo_data())


func _cycle_ship(dir: int) -> void:
	_ship_index = (_ship_index + dir + _ships.size()) % _ships.size()
	if _ship_label:
		_ship_label.text = _ships[_ship_index].display_name as String
	_populate_grid()


func _populate_grid() -> void:
	if not _grid:
		return
	# Clear old cells
	for child in _grid.get_children():
		child.queue_free()
	_static_viewports.clear()

	var ship_data: Dictionary = _ships[_ship_index]
	for p in _get_paint_patterns():
		_grid.add_child(_make_paint_cell(p, ship_data))

	# Let viewports render 2 frames then freeze
	await get_tree().process_frame
	await get_tree().process_frame
	for vp in _static_viewports:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	# Header with ship selector
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	main.add_child(header_row)

	var title := Label.new()
	title.text = "PAINT — flat color on hull panels    (excludes canopy, structure, trim)"
	ThemeManager.apply_text_glow(title, "header")
	header_row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var ship_row := HBoxContainer.new()
	ship_row.add_theme_constant_override("separation", 8)
	header_row.add_child(ship_row)

	var ship_prefix := Label.new()
	ship_prefix.text = "SHIP:"
	ThemeManager.apply_text_glow(ship_prefix, "body")
	ship_row.add_child(ship_prefix)

	var prev_btn := Button.new()
	prev_btn.text = "< 1"
	prev_btn.pressed.connect(func() -> void: _cycle_ship(-1))
	ThemeManager.apply_button_style(prev_btn)
	ship_row.add_child(prev_btn)

	_ship_label = Label.new()
	_ship_label.text = _ships[0].display_name as String
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_label.custom_minimum_size.x = 140
	ThemeManager.apply_text_glow(_ship_label, "header")
	ship_row.add_child(_ship_label)

	var next_btn := Button.new()
	next_btn.text = "2 >"
	next_btn.pressed.connect(func() -> void: _cycle_ship(1))
	ThemeManager.apply_button_style(next_btn)
	ship_row.add_child(next_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_1:
			_cycle_ship(-1)
		elif ke.keycode == KEY_2:
			_cycle_ship(1)


# ── Cell builder ──

func _make_paint_cell(pattern: Dictionary, ship_data: Dictionary) -> VBoxContainer:
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
	_static_viewports.append(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.size = Vector2(CELL_W, CELL_H)
	vp.add_child(bg)

	var ship_id: int = ship_data.ship_id as int
	var ship_pos: Vector2 = ship_data.ship_pos as Vector2
	var ship := ShipRenderer.new()
	ship.ship_id = ship_id
	ship.render_mode = ShipRenderer.RenderMode.STEALTH
	ship.position = ship_pos
	vp.add_child(ship)

	var hull_poly: PackedVector2Array = ship_data.hull
	var exclusions: Array[PackedVector2Array]
	exclusions.assign(ship_data.exclusions)

	var overlay := _PaintOverlay.new()
	overlay.position = ship_pos
	overlay.hull_poly = hull_poly
	overlay.exclusion_polys = exclusions
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


# ── Shape helpers ──

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


func _gen_shapes(pattern: Dictionary) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	var t: String = pattern.type
	var p: Dictionary = pattern.get("params", {})

	match t:
		"vstripe":
			var xc: float = p.get("x", 0.0)
			var w: float = p.get("w", 6.0)
			shapes.append(_rect(xc - w * 0.5, -100, xc + w * 0.5, 100))
		"vstripes":
			var positions: Array = p.get("positions", [])
			var w: float = p.get("w", 4.0)
			for xc in positions:
				shapes.append(_rect(float(xc) - w * 0.5, -100, float(xc) + w * 0.5, 100))
		"hband":
			var y1: float = p.get("y1", -10.0)
			var y2: float = p.get("y2", 10.0)
			shapes.append(_rect(-100, y1, 100, y2))
		"hbands":
			var bands: Array = p.get("bands", [])
			for b in bands:
				shapes.append(_rect(-100, float(b[0]), 100, float(b[1])))
		"diagonal":
			var angle: float = p.get("angle", 0.6)
			var w: float = p.get("w", 10.0)
			shapes.append(_rotated_rect(0, 0, w * 0.5, 100, angle))
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
			var sz: float = p.get("size", 6.0)
			var wing_left := _rect(-100, -100, -10, 100)
			var wing_right := _rect(10, -100, 100, 100)
			for ix in range(-10, 11):
				for iy in range(-12, 12):
					if (ix + iy) % 2 == 0:
						var tile := _rect(ix * sz, iy * sz, (ix + 1) * sz, (iy + 1) * sz)
						var left_clip := Geometry2D.intersect_polygons(tile, wing_left)
						for lp in left_clip:
							shapes.append(lp)
						var right_clip := Geometry2D.intersect_polygons(tile, wing_right)
						for rp in right_clip:
							shapes.append(rp)
		"wing_tips":
			shapes.append(_rect(-100, -100, -15, 100))
			shapes.append(_rect(15, -100, 100, 100))
		"wedge":
			shapes.append(PackedVector2Array([
				Vector2(-35, -50), Vector2(35, -50), Vector2(6, 0), Vector2(-6, 0),
			]))
		"starburst":
			for i in range(8):
				var a: float = float(i) / 8.0 * TAU
				shapes.append(_thick_line(Vector2.ZERO, Vector2(cos(a) * 60, sin(a) * 60), 2.0))
		"side_panels":
			var inset: float = p.get("inset", 8.0)
			var gap: float = p.get("gap", 4.0)
			shapes.append(_rect(-100, -100, -gap, 100))
			shapes.append(_rect(gap, -100, 100, 100))
		"armor_plates":
			var spacing: float = p.get("spacing", 12.0)
			var hw: float = p.get("w", 3.0) * 0.5
			var count: int = p.get("count", 6)
			var start_y: float = -float(count) * spacing * 0.5
			for i in range(count):
				var y: float = start_y + float(i) * spacing
				shapes.append(_rect(-100, y - hw, 100, y + hw))
		"cross":
			var w: float = p.get("w", 6.0)
			shapes.append(_rect(-w * 0.5, -100, w * 0.5, 100))
			shapes.append(_rect(-100, -w * 0.5, 100, w * 0.5))

	return shapes


# ── Pattern definitions ──

func _get_paint_patterns() -> Array[Dictionary]:
	var pats: Array[Dictionary] = []
	pats.append({name = "CENTER STRIPE", type = "vstripe", params = {x = 0.0, w = 6.0}})
	pats.append({name = "WIDE BAND", type = "vstripe", params = {x = 0.0, w = 18.0}})
	pats.append({name = "TRIPLE LINE", type = "vstripes", params = {positions = [-14, 0, 14], w = 3.0}})
	pats.append({name = "NOSE CAP", type = "hband", params = {y1 = -50.0, y2 = -20.0}})
	pats.append({name = "TAIL BAND", type = "hband", params = {y1 = 15.0, y2 = 35.0}})
	pats.append({name = "THREE BANDS", type = "hbands", params = {bands = [[-45, -32], [-6, 6], [20, 32]]}})
	pats.append({name = "DIAG LEFT", type = "diagonal", params = {angle = -0.6, w = 10.0}})
	pats.append({name = "DIAG RIGHT", type = "diagonal", params = {angle = 0.6, w = 10.0}})
	pats.append({name = "CHEVRON", type = "chevron", params = {y = -5.0, w = 5.0, spread = 32.0}})
	pats.append({name = "WING CHECK", type = "wing_check", params = {size = 6.0}})
	pats.append({name = "WING TIPS", type = "wing_tips"})
	pats.append({name = "WEDGE", type = "wedge"})
	pats.append({name = "STARBURST", type = "starburst"})
	pats.append({name = "SIDE PANELS", type = "side_panels", params = {gap = 4.0}})
	pats.append({name = "ARMOR PLATES", type = "armor_plates", params = {spacing = 12.0, w = 3.0, count = 6}})
	pats.append({name = "CROSS", type = "cross", params = {w = 6.0}})
	return pats


# ── Ship geometry data ──

func _make_stiletto_data() -> Dictionary:
	var s := 1.4
	var hull := PackedVector2Array([
		Vector2(0, -35 * s), Vector2(14 * s, -12 * s), Vector2(28 * s, 4 * s),
		Vector2(22 * s, 14 * s), Vector2(10 * s, 24 * s), Vector2(-10 * s, 24 * s),
		Vector2(-22 * s, 14 * s), Vector2(-28 * s, 4 * s), Vector2(-14 * s, -12 * s),
	])
	var exclusions: Array[PackedVector2Array] = []
	# Canopy
	exclusions.append(PackedVector2Array([
		Vector2(0, -28 * s), Vector2(7 * s, -14 * s), Vector2(5 * s, -6 * s),
		Vector2(-5 * s, -6 * s), Vector2(-7 * s, -14 * s),
	]))
	var dhw := 2.0
	# Trim lines (facet edges)
	for td in [
		[Vector2(0, -32 * s), Vector2(14 * s, -12 * s)],
		[Vector2(0, -32 * s), Vector2(-14 * s, -12 * s)],
		[Vector2(14 * s, -12 * s), Vector2(10 * s, 24 * s)],
		[Vector2(-14 * s, -12 * s), Vector2(-10 * s, 24 * s)],
		[Vector2(-14 * s, -12 * s), Vector2(-7 * s, -12 * s)],
		[Vector2(7 * s, -12 * s), Vector2(14 * s, -12 * s)],
	] as Array[Array]:
		exclusions.append(_thick_line(td[0] as Vector2, td[1] as Vector2, dhw))
	# Spine
	exclusions.append(_thick_line(Vector2(0, -6 * s), Vector2(0, 20 * s), 2.5))
	# Engines
	exclusions.append(_thick_line(Vector2(-4 * s, 22 * s), Vector2(-4 * s, 30 * s), 3.0))
	exclusions.append(_thick_line(Vector2(4 * s, 22 * s), Vector2(4 * s, 30 * s), 3.0))

	return {
		display_name = "STILETTO",
		ship_id = 4,
		hull = hull,
		exclusions = exclusions,
		ship_pos = Vector2(90.0, 105.0),
	}


func _make_cargo_data() -> Dictionary:
	# Simplified static hull polygon matching _draw_dreadnought at s=1.9
	# but scaled down to fit in cells. We use a smaller s for the overlay.
	var s := 1.0
	var hull := PackedVector2Array([
		Vector2(-4 * s, -48 * s), Vector2(4 * s, -48 * s),
		Vector2(16 * s, -40 * s), Vector2(20 * s, -26 * s),
		Vector2(20 * s, 26 * s), Vector2(18 * s, 36 * s),
		Vector2(16 * s, 42 * s), Vector2(-16 * s, 42 * s),
		Vector2(-18 * s, 36 * s), Vector2(-20 * s, 26 * s),
		Vector2(-20 * s, -26 * s), Vector2(-16 * s, -40 * s),
	])
	var exclusions: Array[PackedVector2Array] = []
	# Bridge canopy
	exclusions.append(PackedVector2Array([
		Vector2(-8 * s, -42 * s), Vector2(8 * s, -42 * s),
		Vector2(10 * s, -32 * s), Vector2(-10 * s, -32 * s),
	]))
	# Spine accent
	exclusions.append(_thick_line(Vector2(0, -30 * s), Vector2(0, 38 * s), 2.5))
	# Armor plate lines (horizontal detail lines)
	for y in [-20, -10, 0, 12, 24, 34]:
		exclusions.append(_thick_line(Vector2(-18 * s, y * s), Vector2(18 * s, y * s), 1.5))
	# Right hangar bay
	exclusions.append(PackedVector2Array([
		Vector2(20 * s, -8 * s), Vector2(26 * s, -6 * s),
		Vector2(26 * s, 8 * s), Vector2(20 * s, 10 * s),
	]))
	# Left hangar bay
	exclusions.append(PackedVector2Array([
		Vector2(-20 * s, -8 * s), Vector2(-26 * s, -6 * s),
		Vector2(-26 * s, 8 * s), Vector2(-20 * s, 10 * s),
	]))
	# Engines (8 of them)
	for ex in [-14, -10, -6, -2, 2, 6, 10, 14]:
		exclusions.append(_thick_line(Vector2(ex * s, 40 * s), Vector2(ex * s, 48 * s), 2.0))

	return {
		display_name = "CARGO SHIP",
		ship_id = 7,
		hull = hull,
		exclusions = exclusions,
		ship_pos = Vector2(90.0, 100.0),
	}


# ── Paint overlay node (static) ──

class _PaintOverlay extends Node2D:
	var hull_poly: PackedVector2Array
	var exclusion_polys: Array[PackedVector2Array] = []
	var paint_shapes: Array[PackedVector2Array] = []

	func _draw() -> void:
		var col := Color(0.85, 0.08, 0.08, 0.92)
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
				draw_colored_polygon(fpoly, col)
