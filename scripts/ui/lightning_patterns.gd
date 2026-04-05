extends MarginContainer
## Lightning patterns — hull patterns that pulse from dark vents to glowing HDR.
## Each cell shows a ship with animated lighting overlays.

const CELL_W: int = 180
const CELL_H: int = 200
const COLS: int = 6

var _ships: Array[Dictionary] = []
var _ship_index: int = 0
var _ship_label: Label = null
var _grid: GridContainer = null
var _scroll: ScrollContainer = null


func _ready() -> void:
	_init_ships()
	_build_ui()
	_populate_grid()


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
	for child in _grid.get_children():
		child.queue_free()

	var ship_data: Dictionary = _ships[_ship_index]
	for l in _get_light_patterns():
		_grid.add_child(_make_light_cell(l, ship_data))


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	main.add_child(header_row)

	var title := Label.new()
	title.text = "LIGHTNING — hull patterns pulsing from off to glowing yellow"
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

func _make_light_cell(pattern: Dictionary, ship_data: Dictionary) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(CELL_W, CELL_H)
	cell.add_child(frame)

	# Layer 1 — ship viewport (has gleam/bloom from the skin)
	var vpc_ship := SubViewportContainer.new()
	vpc_ship.stretch = true
	vpc_ship.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(vpc_ship)

	var vp_ship := SubViewport.new()
	vp_ship.size = Vector2i(CELL_W, CELL_H)
	vp_ship.transparent_bg = false
	vp_ship.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc_ship.add_child(vp_ship)
	VFXFactory.add_bloom_to_viewport(vp_ship)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.size = Vector2(CELL_W, CELL_H)
	vp_ship.add_child(bg)

	var ship_id: int = ship_data.ship_id as int
	var ship_pos: Vector2 = ship_data.ship_pos as Vector2
	var ship := ShipRenderer.new()
	ship.ship_id = ship_id
	ship.render_mode = ShipRenderer.RenderMode.STEALTH
	ship.position = ship_pos
	vp_ship.add_child(ship)

	# Layer 2 — light-only viewport (transparent bg, own bloom)
	var vpc_light := SubViewportContainer.new()
	vpc_light.stretch = true
	vpc_light.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(vpc_light)

	var vp_light := SubViewport.new()
	vp_light.size = Vector2i(CELL_W, CELL_H)
	vp_light.transparent_bg = true
	vp_light.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc_light.add_child(vp_light)
	VFXFactory.add_bloom_to_viewport(vp_light)

	var hull_poly: PackedVector2Array = ship_data.hull
	var exclusions: Array[PackedVector2Array]
	exclusions.assign(ship_data.exclusions)

	var overlay := _LightOverlay.new()
	overlay.position = ship_pos
	overlay.hull_poly = hull_poly
	overlay.exclusion_polys = exclusions
	overlay.light_shapes = _gen_shapes(pattern)
	vp_light.add_child(overlay)

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
		"vstripes":
			var positions: Array = p.get("positions", [])
			var w: float = p.get("w", 4.0)
			for xc in positions:
				shapes.append(_rect(float(xc) - w * 0.5, -100, float(xc) + w * 0.5, 100))
		"chevrons":
			var ys: Array = p.get("ys", [])
			var hw: float = p.get("w", 3.0) * 0.5
			var spread: float = p.get("spread", 28.0)
			var dy: float = spread * 0.6
			for yc in ys:
				var yf: float = float(yc)
				shapes.append(_thick_line(Vector2(0, yf), Vector2(-spread, yf + dy), hw))
				shapes.append(_thick_line(Vector2(0, yf), Vector2(spread, yf + dy), hw))
		"hbands":
			var bands: Array = p.get("bands", [])
			for b in bands:
				shapes.append(_rect(-100, float(b[0]), 100, float(b[1])))
		"diagonal":
			var angle: float = p.get("angle", 0.6)
			var w: float = p.get("w", 10.0)
			shapes.append(_rotated_rect(0, 0, w * 0.5, 100, angle))
		"cross":
			var w: float = p.get("w", 4.0)
			shapes.append(_rect(-w * 0.5, -100, w * 0.5, 100))
			shapes.append(_rect(-100, -w * 0.5, 100, w * 0.5))
		"diamond_grid":
			var sz: float = p.get("size", 10.0)
			for ix in range(-8, 9):
				for iy in range(-8, 9):
					if (ix + iy) % 2 == 0:
						var cx: float = ix * sz
						var cy: float = iy * sz
						shapes.append(PackedVector2Array([
							Vector2(cx, cy - sz * 0.4),
							Vector2(cx + sz * 0.4, cy),
							Vector2(cx, cy + sz * 0.4),
							Vector2(cx - sz * 0.4, cy),
						]))
		"port_rows":
			var rows: Array = p.get("rows", [])
			var hw: float = p.get("w", 2.0) * 0.5
			var spacing: float = p.get("spacing", 6.0)
			var count: int = p.get("count", 5)
			for row_y in rows:
				var yf: float = float(row_y)
				var total_w: float = (float(count) - 1.0) * spacing
				var start_x: float = -total_w * 0.5
				for i in range(count):
					var cx: float = start_x + float(i) * spacing
					shapes.append(_rect(cx - hw, yf - hw, cx + hw, yf + hw))

	return shapes


# ── Pattern definitions ──

func _get_light_patterns() -> Array[Dictionary]:
	var pats: Array[Dictionary] = []
	pats.append({name = "TWIN RACING", type = "vstripes", params = {positions = [-8, 8], w = 4.0}})
	pats.append({name = "DOUBLE CHEVRON", type = "chevrons", params = {ys = [-15, 8], w = 4.0, spread = 26.0}})
	pats.append({name = "STACKED V", type = "chevrons", params = {ys = [-28, -14, 0, 14], w = 3.0, spread = 20.0}})
	pats.append({name = "TIGHT CHEVRONS", type = "chevrons", params = {ys = [-20, -10, 0, 10, 20], w = 2.0, spread = 16.0}})
	pats.append({name = "DECK LIGHTS", type = "hbands", params = {bands = [[-30, -26], [-8, -4], [14, 18], [30, 34]]}})
	pats.append({name = "X CROSS", type = "cross", params = {w = 4.0}})
	pats.append({name = "DIAG SWEEP", type = "diagonal", params = {angle = 0.5, w = 8.0}})
	pats.append({name = "DIAMOND GRID", type = "diamond_grid", params = {size = 10.0}})
	pats.append({name = "PORT ROWS", type = "port_rows", params = {rows = [-25, -10, 5, 20], w = 3.0, spacing = 8.0, count = 4}})
	pats.append({name = "WIDE RACING", type = "vstripes", params = {positions = [-12, 12], w = 6.0}})
	pats.append({name = "TRIPLE BAND", type = "hbands", params = {bands = [[-35, -30], [-3, 3], [28, 33]]}})
	pats.append({name = "QUAD STRIPES", type = "vstripes", params = {positions = [-15, -5, 5, 15], w = 2.5}})
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
	exclusions.append(PackedVector2Array([
		Vector2(0, -28 * s), Vector2(7 * s, -14 * s), Vector2(5 * s, -6 * s),
		Vector2(-5 * s, -6 * s), Vector2(-7 * s, -14 * s),
	]))
	var dhw := 2.0
	for td in [
		[Vector2(0, -32 * s), Vector2(14 * s, -12 * s)],
		[Vector2(0, -32 * s), Vector2(-14 * s, -12 * s)],
		[Vector2(14 * s, -12 * s), Vector2(10 * s, 24 * s)],
		[Vector2(-14 * s, -12 * s), Vector2(-10 * s, 24 * s)],
		[Vector2(-14 * s, -12 * s), Vector2(-7 * s, -12 * s)],
		[Vector2(7 * s, -12 * s), Vector2(14 * s, -12 * s)],
	] as Array[Array]:
		exclusions.append(_thick_line(td[0] as Vector2, td[1] as Vector2, dhw))
	exclusions.append(_thick_line(Vector2(0, -6 * s), Vector2(0, 20 * s), 2.5))
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
	exclusions.append(PackedVector2Array([
		Vector2(-8 * s, -42 * s), Vector2(8 * s, -42 * s),
		Vector2(10 * s, -32 * s), Vector2(-10 * s, -32 * s),
	]))
	exclusions.append(_thick_line(Vector2(0, -30 * s), Vector2(0, 38 * s), 2.5))
	for y in [-20, -10, 0, 12, 24, 34]:
		exclusions.append(_thick_line(Vector2(-18 * s, y * s), Vector2(18 * s, y * s), 1.5))
	exclusions.append(PackedVector2Array([
		Vector2(20 * s, -8 * s), Vector2(26 * s, -6 * s),
		Vector2(26 * s, 8 * s), Vector2(20 * s, 10 * s),
	]))
	exclusions.append(PackedVector2Array([
		Vector2(-20 * s, -8 * s), Vector2(-26 * s, -6 * s),
		Vector2(-26 * s, 8 * s), Vector2(-20 * s, 10 * s),
	]))
	for ex in [-14, -10, -6, -2, 2, 6, 10, 14]:
		exclusions.append(_thick_line(Vector2(ex * s, 40 * s), Vector2(ex * s, 48 * s), 2.0))

	return {
		display_name = "CARGO SHIP",
		ship_id = 7,
		hull = hull,
		exclusions = exclusions,
		ship_pos = Vector2(90.0, 100.0),
	}


# ── Lighting overlay node (animated pulse) ──

class _LightOverlay extends Node2D:
	var hull_poly: PackedVector2Array
	var exclusion_polys: Array[PackedVector2Array] = []
	var light_shapes: Array[PackedVector2Array] = []
	var _time: float = 0.0
	var _clipped_polys: Array[PackedVector2Array] = []

	const PULSE_PERIOD: float = 1.8
	const YELLOW := Color(1.0, 0.85, 0.12)
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
		var col := Color(YELLOW.r * hdr, YELLOW.g * hdr, YELLOW.b * hdr, intensity * 0.95)

		for poly in _clipped_polys:
			draw_colored_polygon(poly, col)
