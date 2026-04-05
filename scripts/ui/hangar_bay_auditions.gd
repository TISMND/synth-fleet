extends MarginContainer
## Hangar Bay visual auditions — top-down hangar concepts with textured floors.
## Spot 1 has the player's Stiletto (Chrome), spot 2 has a [+] shop marker.

const VP_SIZE := Vector2i(900, 500)
const SPOT_COUNT: int = 6
const SHIP_ID: int = 4  # Stiletto

const CONCEPTS: Array[Dictionary] = [
	{
		"label": "MILITARY GRID",
		"desc": "Yellow deck markings, numbered bays, industrial floor grid.",
		"floor_shader": "",
		"floor_color": Color(0.06, 0.065, 0.08),
		"line_color": Color(0.7, 0.6, 0.1, 0.7),
		"spot_style": "box",
		"spot_fill": Color(0.04, 0.045, 0.06, 0.8),
		"accent": Color(0.7, 0.6, 0.1),
		"grid_visible": true,
	},
	{
		"label": "TECH BLUEPRINT",
		"desc": "Dashed rectangles, corner ticks, thin blue lines on dark blue.",
		"floor_shader": "",
		"floor_color": Color(0.01, 0.02, 0.06),
		"line_color": Color(0.2, 0.4, 0.8, 0.5),
		"spot_style": "blueprint",
		"spot_fill": Color(0.015, 0.03, 0.07, 0.4),
		"accent": Color(0.3, 0.6, 1.0),
		"grid_visible": true,
	},
	{
		"label": "STEEL PLATING",
		"desc": "Riveted metal panels with brushed texture. Heavy industrial hangar.",
		"floor_shader": "res://assets/shaders/hangar_floor_steel.gdshader",
		"floor_color": Color(0.12, 0.13, 0.15),
		"line_color": Color(0.8, 0.5, 0.1, 0.6),
		"spot_style": "carrier",
		"spot_fill": Color(0.08, 0.08, 0.1, 0.5),
		"accent": Color(0.9, 0.6, 0.1),
		"grid_visible": false,
	},
	{
		"label": "CONCRETE BUNKER",
		"desc": "Rough concrete with expansion joints, oil stains, cracks.",
		"floor_shader": "res://assets/shaders/hangar_floor_concrete.gdshader",
		"floor_color": Color(0.14, 0.14, 0.13),
		"line_color": Color(0.9, 0.9, 0.3, 0.5),
		"spot_style": "box",
		"spot_fill": Color(0.0, 0.0, 0.0, 0.15),
		"accent": Color(0.9, 0.8, 0.2),
		"grid_visible": false,
	},
	{
		"label": "ASPHALT TARMAC",
		"desc": "Dark tarmac runway with faded paint markings, airport feel.",
		"floor_shader": "res://assets/shaders/hangar_floor_asphalt.gdshader",
		"floor_color": Color(0.07, 0.07, 0.08),
		"line_color": Color(0.85, 0.85, 0.8, 0.6),
		"spot_style": "carrier",
		"spot_fill": Color(0.0, 0.0, 0.0, 0.1),
		"accent": Color(0.9, 0.9, 0.85),
		"grid_visible": false,
	},
	{
		"label": "DIAMOND PLATE",
		"desc": "Raised diamond anti-slip steel. Workshop floor, utilitarian.",
		"floor_shader": "res://assets/shaders/hangar_floor_diamond.gdshader",
		"floor_color": Color(0.10, 0.11, 0.13),
		"line_color": Color(0.2, 0.7, 0.9, 0.6),
		"spot_style": "blueprint",
		"spot_fill": Color(0.0, 0.0, 0.0, 0.2),
		"accent": Color(0.3, 0.8, 1.0),
		"grid_visible": false,
	},
	{
		"label": "GRATING DECK",
		"desc": "Open metal grating over dark void. Engineering deck, maintenance bay.",
		"floor_shader": "res://assets/shaders/hangar_floor_grating.gdshader",
		"floor_color": Color(0.15, 0.16, 0.18),
		"line_color": Color(0.9, 0.3, 0.15, 0.7),
		"spot_style": "carrier",
		"spot_fill": Color(0.0, 0.0, 0.0, 0.3),
		"accent": Color(0.9, 0.25, 0.1),
		"grid_visible": false,
	},
]

var _renderers: Array[ShipRenderer] = []


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	for r in _renderers:
		r.time += delta
		r.queue_redraw()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var main_col := VBoxContainer.new()
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_theme_constant_override("separation", 30)
	scroll.add_child(main_col)

	for i in CONCEPTS.size():
		_build_concept(main_col, CONCEPTS[i], i)


func _build_concept(parent: VBoxContainer, def: Dictionary, idx: int) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var hfont: Font = ThemeManager.get_font("font_header")

	var title := Label.new()
	title.text = def["label"] as String
	ThemeManager.apply_text_glow(title, "header")
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		title.add_theme_font_override("font", hfont)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	section.add_child(title)

	var desc := Label.new()
	desc.text = def["desc"] as String
	ThemeManager.apply_text_glow(desc, "body")
	desc.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	section.add_child(desc)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(center)

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(VP_SIZE.x, VP_SIZE.y)
	center.add_child(frame)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = VP_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	# Floor — shader or flat color
	var floor_shader_path: String = def["floor_shader"] as String
	var floor_rect := ColorRect.new()
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	if floor_shader_path != "":
		floor_rect.color = Color.WHITE
		var shader: Shader = load(floor_shader_path) as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			floor_rect.material = mat
	else:
		floor_rect.color = def["floor_color"] as Color
	vp.add_child(floor_rect)

	# Hangar drawing layer (markings, spots)
	var hangar := Control.new()
	hangar.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(hangar)

	var spot_style: String = def["spot_style"] as String
	var line_col: Color = def["line_color"] as Color
	var spot_fill: Color = def["spot_fill"] as Color
	var accent: Color = def["accent"] as Color
	var grid_vis: bool = bool(def["grid_visible"])

	hangar.draw.connect(func() -> void:
		_draw_hangar(hangar, spot_style, line_col, spot_fill, accent, grid_vis)
	)
	hangar.queue_redraw()

	# Ship in first spot
	var spot_positions: Array[Vector2] = _get_spot_positions()
	var ship := ShipRenderer.new()
	ship.ship_id = GameState.current_ship_index
	ship.render_mode = ShipRenderer.RenderMode.CHROME
	ship.animate = true
	ship.position = spot_positions[0]
	ship.scale = Vector2(0.8, 0.8)
	vp.add_child(ship)
	_renderers.append(ship)

	# Plus sign marker in second spot
	var plus_marker := Control.new()
	plus_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus_marker.draw.connect(func() -> void:
		_draw_plus_marker(plus_marker, spot_positions[1], accent)
	)
	vp.add_child(plus_marker)


func _get_spot_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var cols: int = 3
	var rows: int = 2
	var spacing_x: float = 260.0
	var spacing_y: float = 200.0
	var start_x: float = (VP_SIZE.x - (cols - 1) * spacing_x) / 2.0
	var start_y: float = (VP_SIZE.y - (rows - 1) * spacing_y) / 2.0
	for row in rows:
		for col in cols:
			positions.append(Vector2(
				start_x + col * spacing_x,
				start_y + row * spacing_y,
			))
	return positions


func _draw_hangar(canvas: Control, style: String, line_col: Color, fill_col: Color, accent: Color, grid: bool) -> void:
	var positions: Array[Vector2] = _get_spot_positions()
	var spot_w: float = 120.0
	var spot_h: float = 140.0

	if grid:
		var grid_col := Color(line_col.r, line_col.g, line_col.b, 0.08)
		var spacing: float = 40.0
		var x: float = 0.0
		while x < VP_SIZE.x:
			canvas.draw_line(Vector2(x, 0), Vector2(x, VP_SIZE.y), grid_col, 1.0)
			x += spacing
		var y: float = 0.0
		while y < VP_SIZE.y:
			canvas.draw_line(Vector2(0, y), Vector2(VP_SIZE.x, y), grid_col, 1.0)
			y += spacing

	for i in positions.size():
		var pos: Vector2 = positions[i]
		var rect := Rect2(pos.x - spot_w / 2, pos.y - spot_h / 2, spot_w, spot_h)

		match style:
			"box":
				canvas.draw_rect(rect, fill_col)
				canvas.draw_rect(rect, line_col, false, 2.0)
				var dash_y: float = rect.position.y
				while dash_y < rect.end.y:
					var end_y: float = minf(dash_y + 8.0, rect.end.y)
					canvas.draw_line(Vector2(pos.x, dash_y), Vector2(pos.x, end_y), Color(line_col.r, line_col.g, line_col.b, 0.3), 1.0)
					dash_y += 16.0
				var font: Font = ThemeManager.get_font("font_header")
				if font:
					canvas.draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 16), "%02d" % [i + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)

			"blueprint":
				_draw_dashed_rect(canvas, rect, line_col, 1.0, 6.0, 4.0)
				var tick: float = 12.0
				var tcol := Color(line_col.r, line_col.g, line_col.b, 0.8)
				canvas.draw_line(rect.position, rect.position + Vector2(tick, 0), tcol, 1.5)
				canvas.draw_line(rect.position, rect.position + Vector2(0, tick), tcol, 1.5)
				canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - tick, rect.position.y), tcol, 1.5)
				canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + tick), tcol, 1.5)
				canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + tick, rect.end.y), tcol, 1.5)
				canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - tick), tcol, 1.5)
				canvas.draw_line(rect.end, rect.end - Vector2(tick, 0), tcol, 1.5)
				canvas.draw_line(rect.end, rect.end - Vector2(0, tick), tcol, 1.5)
				canvas.draw_line(pos + Vector2(-6, 0), pos + Vector2(6, 0), Color(accent.r, accent.g, accent.b, 0.3), 1.0)
				canvas.draw_line(pos + Vector2(0, -6), pos + Vector2(0, 6), Color(accent.r, accent.g, accent.b, 0.3), 1.0)
				var font: Font = ThemeManager.get_font("font_body")
				if font:
					canvas.draw_string(font, Vector2(rect.position.x, rect.position.y - 4), "BAY-%02d" % [i + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(accent.r, accent.g, accent.b, 0.6))

			"carrier":
				canvas.draw_rect(rect, fill_col)
				canvas.draw_rect(rect, line_col, false, 3.0)
				var stripe_w: float = 10.0
				var sx: float = rect.position.x
				var stripe_h: float = 6.0
				while sx < rect.end.x:
					var sw: float = minf(stripe_w, rect.end.x - sx)
					canvas.draw_rect(Rect2(sx, rect.position.y, sw, stripe_h), Color(line_col.r, line_col.g, line_col.b, 0.4))
					sx += stripe_w * 2.0
				var rail_offset: float = 20.0
				canvas.draw_line(Vector2(pos.x - rail_offset, rect.position.y), Vector2(pos.x - rail_offset, rect.end.y), Color(0.5, 0.5, 0.6, 0.3), 2.0)
				canvas.draw_line(Vector2(pos.x + rail_offset, rect.position.y), Vector2(pos.x + rail_offset, rect.end.y), Color(0.5, 0.5, 0.6, 0.3), 2.0)
				var arrow_y: float = rect.position.y + 20.0
				canvas.draw_line(Vector2(pos.x, arrow_y), Vector2(pos.x - 8, arrow_y + 10), Color(accent.r, accent.g, accent.b, 0.5), 2.0)
				canvas.draw_line(Vector2(pos.x, arrow_y), Vector2(pos.x + 8, arrow_y + 10), Color(accent.r, accent.g, accent.b, 0.5), 2.0)

	var mid_y: float = VP_SIZE.y / 2.0
	canvas.draw_line(Vector2(40, mid_y), Vector2(VP_SIZE.x - 40, mid_y), Color(line_col.r, line_col.g, line_col.b, 0.15), 1.0)


func _draw_dashed_rect(canvas: Control, rect: Rect2, col: Color, width: float, dash: float, gap: float) -> void:
	_draw_dashed_line(canvas, rect.position, Vector2(rect.end.x, rect.position.y), col, width, dash, gap)
	_draw_dashed_line(canvas, Vector2(rect.end.x, rect.position.y), rect.end, col, width, dash, gap)
	_draw_dashed_line(canvas, rect.end, Vector2(rect.position.x, rect.end.y), col, width, dash, gap)
	_draw_dashed_line(canvas, Vector2(rect.position.x, rect.end.y), rect.position, col, width, dash, gap)


func _draw_dashed_line(canvas: Control, from: Vector2, to: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var dir: Vector2 = (to - from)
	var length: float = dir.length()
	if length < 0.01:
		return
	dir = dir / length
	var p: float = 0.0
	while p < length:
		var e: float = minf(p + dash, length)
		canvas.draw_line(from + dir * p, from + dir * e, col, width)
		p = e + gap


func _draw_plus_marker(canvas: Control, pos: Vector2, accent: Color) -> void:
	var half: float = 30.0
	var blen: float = 10.0
	var bcol := Color(accent.r, accent.g, accent.b, 0.7)
	var bw: float = 2.0

	canvas.draw_line(Vector2(pos.x - half, pos.y - half), Vector2(pos.x - half + blen, pos.y - half), bcol, bw)
	canvas.draw_line(Vector2(pos.x - half, pos.y - half), Vector2(pos.x - half, pos.y - half + blen), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y - half), Vector2(pos.x + half - blen, pos.y - half), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y - half), Vector2(pos.x + half, pos.y - half + blen), bcol, bw)
	canvas.draw_line(Vector2(pos.x - half, pos.y + half), Vector2(pos.x - half + blen, pos.y + half), bcol, bw)
	canvas.draw_line(Vector2(pos.x - half, pos.y + half), Vector2(pos.x - half, pos.y + half - blen), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y + half), Vector2(pos.x + half - blen, pos.y + half), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y + half), Vector2(pos.x + half, pos.y + half - blen), bcol, bw)

	var plus_size: float = 14.0
	var plus_w: float = 3.0
	canvas.draw_line(Vector2(pos.x - plus_size, pos.y), Vector2(pos.x + plus_size, pos.y), accent, plus_w)
	canvas.draw_line(Vector2(pos.x, pos.y - plus_size), Vector2(pos.x, pos.y + plus_size), accent, plus_w)
