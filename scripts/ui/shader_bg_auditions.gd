extends MarginContainer
## Shader background auditions — pure fragment-shader scrolling backgrounds
## and experimental hybrid/canvas-drawn approaches.

const PREVIEW_HEIGHT: int = 450
const PREVIEW_WIDTH: int = 900
const DOODAD_STRIP_HEIGHT: float = 4000.0

var _tab_shaders_btn: Button
var _tab_experimental_btn: Button
var _shader_content: VBoxContainer
var _experimental_content: VBoxContainer
var _scroll_targets: Array = []  # dicts with {"node": Node2D, "speed": float, "height": float}

const BG_SHADERS: Array = [
	{
		"name": "SYNTHWAVE ETCH GRID",
		"path": "res://assets/shaders/bg_synthwave_pulse.gdshader",
		"category": "Definitively Synthwave",
		"description": "Etching heads draw grid lines with variable speed, sparkle, and HDR white-hot core.",
	},
	{
		"name": "MICROCHIP DIE",
		"path": "res://assets/shaders/bg_circuit_board.gdshader",
		"category": "Tech / Digital",
		"description": "Silicon wafer surface — memory arrays, logic blocks, I/O pads, bus routing. HDR gleam.",
	},
	{
		"name": "BIOLUMINESCENT REEF",
		"path": "res://assets/shaders/bg_bioluminescent_reef.gdshader",
		"category": "Organic / Alien",
		"description": "Deep-sea coral, pulsing glow nodes, soft voronoi blending.",
	},
	{
		"name": "INDUSTRIAL PLATFORM",
		"path": "res://assets/shaders/bg_industrial_platform.gdshader",
		"category": "Surface / Ground",
		"description": "Plates at varying depths, sub-grids, ramps into darkness, equipment, conduits.",
	},
	{
		"name": "LAVA FIELD",
		"path": "res://assets/shaders/bg_lava_field.gdshader",
		"category": "Environmental",
		"description": "Scorched volcanic rock with magma veins. Near-black crust, drifting embers.",
	},
]


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	for target in _scroll_targets:
		var node: Node2D = target["node"] as Node2D
		var speed: float = float(target["speed"])
		var height: float = float(target["height"])
		if node and node.is_inside_tree():
			node.position.y += speed * delta
			if node.position.y > 0.0:
				node.position.y -= height


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# Tab buttons
	var tab_hbox := HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(tab_hbox)

	_tab_shaders_btn = Button.new()
	_tab_shaders_btn.text = "SHADER BACKGROUNDS"
	_tab_shaders_btn.toggle_mode = true
	_tab_shaders_btn.button_pressed = true
	_tab_shaders_btn.pressed.connect(_show_shaders_tab)
	ThemeManager.apply_button_style(_tab_shaders_btn)
	tab_hbox.add_child(_tab_shaders_btn)

	_tab_experimental_btn = Button.new()
	_tab_experimental_btn.text = "EXPERIMENTAL"
	_tab_experimental_btn.toggle_mode = true
	_tab_experimental_btn.pressed.connect(_show_experimental_tab)
	ThemeManager.apply_button_style(_tab_experimental_btn)
	tab_hbox.add_child(_tab_experimental_btn)

	# Wrap content in a scroll container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 16)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	# Shader tab
	_shader_content = VBoxContainer.new()
	_shader_content.add_theme_constant_override("separation", 20)
	_shader_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(_shader_content)

	for shader_def in BG_SHADERS:
		_build_shader_preview(shader_def, _shader_content)

	# Experimental tab
	_experimental_content = VBoxContainer.new()
	_experimental_content.add_theme_constant_override("separation", 20)
	_experimental_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_experimental_content.visible = false
	content_vbox.add_child(_experimental_content)

	_build_experimental_tab()

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	content_vbox.add_child(spacer)


# ═══════════════════════════════════════════════════════════
# EXPERIMENTAL TAB
# ═══════════════════════════════════════════════════════════

func _build_experimental_tab() -> void:
	var intro := Label.new()
	intro.text = "Testing 'handcrafted without handcrafting' — firm places, not patterns."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0)
	_experimental_content.add_child(intro)

	# ── Experiment 1: City shader + canvas doodads on top ──
	_build_section_label("HYBRID: CITY SHADER + DOODADS", _experimental_content)
	var hybrid_desc := Label.new()
	hybrid_desc.text = "City district shader as base layer + Node2D doodads drawn on top.\nTests whether sprite objects can look like they belong on a procedural background."
	hybrid_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hybrid_desc.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0)
	_experimental_content.add_child(hybrid_desc)
	_build_hybrid_city_preview(_experimental_content)

	# ── Experiment 2: Pure canvas-drawn city ──
	_build_section_label("PURE CANVAS DRAW", _experimental_content)
	var canvas_desc := Label.new()
	canvas_desc.text = "Entire city drawn with Godot's _draw() API — each building individually placed.\nNo shader. Tests whether hand-drawn style looks more 'crafted' than shader generation."
	canvas_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas_desc.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0)
	_experimental_content.add_child(canvas_desc)
	_build_canvas_city_preview(_experimental_content)


func _build_hybrid_city_preview(parent: VBoxContainer) -> void:
	var border := _make_preview_border()
	parent.add_child(border)

	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(svc)

	var vp := SubViewport.new()
	vp.size = Vector2i(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	svc.add_child(vp)

	# Base: city shader
	var bg_rect := ColorRect.new()
	bg_rect.size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	var shader: Shader = load("res://assets/shaders/bg_city_district.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		bg_rect.material = mat
	vp.add_child(bg_rect)

	# Doodad layer — scrolls matching shader TIME-based scroll
	var doodad_layer := _CityDoodads.new()
	doodad_layer.strip_height = DOODAD_STRIP_HEIGHT
	doodad_layer.viewport_width = PREVIEW_WIDTH
	doodad_layer.position.y = -DOODAD_STRIP_HEIGHT + PREVIEW_HEIGHT
	vp.add_child(doodad_layer)

	_scroll_targets.append({
		"node": doodad_layer,
		"speed": 30.0,  # match shader scroll_speed default
		"height": DOODAD_STRIP_HEIGHT,
	})


func _build_canvas_city_preview(parent: VBoxContainer) -> void:
	var border := _make_preview_border()
	parent.add_child(border)

	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(svc)

	var vp := SubViewport.new()
	vp.size = Vector2i(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	svc.add_child(vp)

	# Dark background
	var bg := ColorRect.new()
	bg.size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	bg.color = Color(0.02, 0.02, 0.03)
	vp.add_child(bg)

	# Canvas city — draws everything in _draw()
	var city := _CanvasCity.new()
	city.strip_height = DOODAD_STRIP_HEIGHT
	city.viewport_width = PREVIEW_WIDTH
	city.position.y = -DOODAD_STRIP_HEIGHT + PREVIEW_HEIGHT
	vp.add_child(city)

	_scroll_targets.append({
		"node": city,
		"speed": 30.0,
		"height": DOODAD_STRIP_HEIGHT,
	})


# ═══════════════════════════════════════════════════════════
# DOODAD LAYER — drawn on top of city shader
# ═══════════════════════════════════════════════════════════

class _CityDoodads extends Node2D:
	var strip_height: float = 4000.0
	var viewport_width: float = 900.0
	## City grid constants — must match shader defaults
	var _ave_sp: float = 280.0
	var _ave_w: float = 22.0
	var _st_subs: float = 3.0
	var _st_w: float = 12.0
	var _sw_w: float = 3.0  # sidewalk

	var _doodads: Array = []  # {pos: Vector2, type: int, hash: float, size: float}

	func _ready() -> void:
		_generate_doodads()

	func _hash(p: Vector2) -> float:
		var v: float = sin(p.x * 127.1 + p.y * 311.7) * 43758.5453
		return v - floor(v)

	func _generate_doodads() -> void:
		var block_interior = _ave_sp - _ave_w - _sw_w * 2.0
		var st_sp: float = block_interior / _st_subs
		var plot_area: float = st_sp - _st_w - 4.0

		# Walk the city grid and place doodads at building centers
		var ave_cols: int = int(viewport_width / _ave_sp) + 2
		var ave_rows: int = int(strip_height / _ave_sp) + 2

		for ay in range(ave_rows):
			for ax in range(ave_cols):
				var ave_origin := Vector2(
					float(ax) * _ave_sp + _ave_w * 0.5 + _sw_w,
					float(ay) * _ave_sp + _ave_w * 0.5 + _sw_w
				)
				# Sub-blocks within this avenue block
				for sy in range(int(_st_subs)):
					for sx in range(int(_st_subs)):
						var plot_origin := ave_origin + Vector2(
							float(sx) * st_sp + _st_w * 0.5 + 2.0,
							float(sy) * st_sp + _st_w * 0.5 + 2.0
						)
						var cell_id := Vector2(float(ax * 10 + sx), float(ay * 10 + sy))
						var h: float = _hash(cell_id)
						var h2: float = _hash(cell_id + Vector2(7.0, 13.0))

						# Skip parks/parking/some buildings (match shader block_type logic roughly)
						if h > 0.82:
							continue  # park or parking

						# Only place doodads on ~40% of buildings
						if h2 < 0.6:
							continue

						var center := plot_origin + Vector2(plot_area * 0.5, plot_area * 0.5)
						var doodad_type: int = int(h2 * 6.0)  # 0-5
						_doodads.append({
							"pos": center,
							"type": doodad_type,
							"hash": h2,
							"size": plot_area * 0.3 + h * plot_area * 0.2,
						})

	func _draw() -> void:
		for d in _doodads:
			var p: Vector2 = d["pos"]
			var t: int = d["type"]
			var h: float = d["hash"]
			var s: float = d["size"]

			match t:
				0:
					_draw_water_tower(p, s * 0.4)
				1:
					_draw_satellite_dish(p, s * 0.5)
				2:
					_draw_ac_cluster(p, s * 0.6)
				3:
					_draw_antenna(p, s * 0.8)
				4:
					_draw_solar_panels(p, s * 0.7)
				5:
					_draw_rooftop_garden(p, s * 0.5, h)

	func _draw_water_tower(center: Vector2, radius: float) -> void:
		var r: float = max(radius, 3.0)
		var leg_h: float = r * 0.6
		var tank_color := Color(0.18, 0.17, 0.16)
		var leg_color := Color(0.12, 0.11, 0.1)
		draw_line(center + Vector2(-r * 0.6, leg_h), center + Vector2(r * 0.3, -leg_h * 0.3), leg_color, 1.0)
		draw_line(center + Vector2(r * 0.6, leg_h), center + Vector2(-r * 0.3, -leg_h * 0.3), leg_color, 1.0)
		draw_circle(center - Vector2(0, leg_h * 0.3), r, tank_color)
		draw_arc(center - Vector2(0, leg_h * 0.3), r * 0.7, 0, TAU, 12, Color(0.22, 0.21, 0.2), 0.8)

	func _draw_satellite_dish(center: Vector2, radius: float) -> void:
		var r: float = max(radius, 3.0)
		var dish_color := Color(0.2, 0.2, 0.22)
		draw_arc(center, r, -0.3, PI + 0.3, 16, dish_color, 1.5)
		draw_line(center, center + Vector2(r * 0.4, -r * 0.6), Color(0.15, 0.15, 0.16), 1.0)
		draw_circle(center, r * 0.2, Color(0.13, 0.13, 0.14))

	func _draw_ac_cluster(center: Vector2, size: float) -> void:
		var s: float = max(size, 4.0)
		var unit_color := Color(0.16, 0.17, 0.18)
		var vent_color := Color(0.1, 0.1, 0.11)
		for i in range(3):
			var offset := Vector2((float(i) - 1.0) * s * 0.45, 0.0)
			var r := Rect2(center + offset - Vector2(s * 0.18, s * 0.15), Vector2(s * 0.36, s * 0.3))
			draw_rect(r, unit_color)
			draw_circle(center + offset, s * 0.08, vent_color)

	func _draw_antenna(center: Vector2, height: float) -> void:
		var h: float = max(height, 5.0)
		var pole_color := Color(0.2, 0.18, 0.16)
		var wire_color := Color(0.15, 0.14, 0.13, 0.7)
		draw_line(center + Vector2(0, h * 0.4), center - Vector2(0, h * 0.4), pole_color, 1.5)
		for i in range(3):
			var y_off: float = -h * 0.1 + float(i) * h * 0.2
			var bar_w: float = h * 0.25 - float(i) * h * 0.05
			draw_line(center + Vector2(-bar_w, y_off), center + Vector2(bar_w, y_off), wire_color, 0.8)
		draw_circle(center - Vector2(0, h * 0.4), 1.5, Color(0.8, 0.1, 0.1, 0.8))

	func _draw_solar_panels(center: Vector2, size: float) -> void:
		var s: float = max(size, 4.0)
		var panel_color := Color(0.05, 0.07, 0.15)
		var frame_color := Color(0.12, 0.12, 0.14)
		var pw: float = s * 0.28
		var ph: float = s * 0.18
		for py in range(3):
			for px in range(2):
				var offset := Vector2(
					(float(px) - 0.5) * (pw + 1.5),
					(float(py) - 1.0) * (ph + 1.5)
				)
				var r := Rect2(center + offset - Vector2(pw * 0.5, ph * 0.5), Vector2(pw, ph))
				draw_rect(r, panel_color)
				draw_rect(r, frame_color, false, 0.5)

	func _draw_rooftop_garden(center: Vector2, size: float, seed: float) -> void:
		var s: float = max(size, 4.0)
		var planter_color := Color(0.08, 0.06, 0.04)
		var green_color := Color(0.04, 0.1, 0.04)
		var r := Rect2(center - Vector2(s * 0.4, s * 0.3), Vector2(s * 0.8, s * 0.6))
		draw_rect(r, planter_color)
		var inner := Rect2(r.position + Vector2(1.5, 1.5), r.size - Vector2(3.0, 3.0))
		draw_rect(inner, green_color)
		draw_circle(center + Vector2(-s * 0.15, -s * 0.05), s * 0.08, Color(0.03, 0.12, 0.03))
		draw_circle(center + Vector2(s * 0.12, s * 0.08), s * 0.06, Color(0.04, 0.09, 0.03))


# ═══════════════════════════════════════════════════════════
# CANVAS CITY — everything drawn with _draw(), no shader
# ═══════════════════════════════════════════════════════════

class _CanvasCity extends Node2D:
	var strip_height: float = 4000.0
	var viewport_width: float = 900.0
	var _buildings: Array = []  # pre-generated building data

	func _ready() -> void:
		_generate_city()

	func _hash(p: Vector2) -> float:
		var v: float = sin(p.x * 127.1 + p.y * 311.7) * 43758.5453
		return v - floor(v)

	func _generate_city() -> void:
		var ave_sp: float = 200.0
		var ave_w: float = 18.0
		var st_w: float = 8.0
		var sw_w: float = 3.0

		var cols: int = int(viewport_width / ave_sp) + 1
		var rows: int = int(strip_height / ave_sp) + 1

		for row in range(rows):
			for col in range(cols):
				var block_x: float = float(col) * ave_sp + ave_w * 0.5
				var block_y: float = float(row) * ave_sp + ave_w * 0.5
				var block_w: float = ave_sp - ave_w
				var block_h: float = ave_sp - ave_w
				var block_id := Vector2(float(col), float(row))
				var bh: float = _hash(block_id)

				# Block type
				if bh > 0.9:
					_buildings.append({
						"rect": Rect2(block_x + sw_w, block_y + sw_w, block_w - sw_w * 2, block_h - sw_w * 2),
						"type": "park",
						"hash": bh,
					})
					continue
				if bh > 0.85:
					_buildings.append({
						"rect": Rect2(block_x + sw_w, block_y + sw_w, block_w - sw_w * 2, block_h - sw_w * 2),
						"type": "parking",
						"hash": bh,
					})
					continue

				# Subdivide block into buildings
				var subdiv_x: int = 2 + int(_hash(block_id + Vector2(3.0, 0.0)) * 3.0)
				var subdiv_y: int = 2 + int(_hash(block_id + Vector2(0.0, 3.0)) * 3.0)
				var plot_w: float = (block_w - sw_w * 2) / float(subdiv_x)
				var plot_h: float = (block_h - sw_w * 2) / float(subdiv_y)

				for py in range(subdiv_y):
					for px in range(subdiv_x):
						var plot_id := Vector2(float(col * 10 + px), float(row * 10 + py))
						var ph: float = _hash(plot_id)
						var ph2: float = _hash(plot_id + Vector2(11.0, 7.0))

						if ph < 0.12:
							continue  # empty lot

						var setback: float = 1.5 + ph * 2.0
						var bx: float = block_x + sw_w + float(px) * plot_w + setback
						var by: float = block_y + sw_w + float(py) * plot_h + setback
						var bw: float = plot_w - setback * 2.0
						var bht: float = plot_h - setback * 2.0

						if ph > 0.8 and px < subdiv_x - 1:
							bw += plot_w - setback

						_buildings.append({
							"rect": Rect2(bx, by, max(bw, 4.0), max(bht, 4.0)),
							"type": "building",
							"hash": ph,
							"hash2": ph2,
							"shade": 0.06 + ph * 0.08,
							"has_doodad": ph2 > 0.55,
							"doodad_type": int(ph2 * 5.0),
						})

	func _draw() -> void:
		var road_col := Color(0.035, 0.035, 0.045)
		var sidewalk_col := Color(0.065, 0.065, 0.075)
		var marking_col := Color(0.12, 0.12, 0.09, 0.5)
		var park_col := Color(0.02, 0.055, 0.025)
		var parking_col := Color(0.05, 0.05, 0.06)
		var window_col := Color(0.18, 0.15, 0.07, 0.6)

		# Full background = road
		draw_rect(Rect2(0, 0, viewport_width, strip_height), road_col)

		var ave_sp: float = 200.0
		var ave_w: float = 18.0
		var sw_w: float = 3.0
		var cols: int = int(viewport_width / ave_sp) + 1
		var rows: int = int(strip_height / ave_sp) + 1

		# Draw sidewalks (full block outlines)
		for row in range(rows):
			for col in range(cols):
				var bx: float = float(col) * ave_sp + ave_w * 0.5 - sw_w
				var by: float = float(row) * ave_sp + ave_w * 0.5 - sw_w
				var bw: float = ave_sp - ave_w + sw_w * 2
				draw_rect(Rect2(bx, by, bw, bw), sidewalk_col)

		# Road markings (dashed center lines on avenues)
		for col in range(cols + 1):
			var x: float = float(col) * ave_sp
			var dash_y: float = 0.0
			while dash_y < strip_height:
				draw_line(Vector2(x, dash_y), Vector2(x, dash_y + 10.0), marking_col, 1.0)
				dash_y += 18.0
		for row in range(rows + 1):
			var y: float = float(row) * ave_sp
			var dash_x: float = 0.0
			while dash_x < viewport_width:
				draw_line(Vector2(dash_x, y), Vector2(dash_x + 10.0, y), marking_col, 1.0)
				dash_x += 18.0

		# Draw buildings, parks, parking lots
		for bdata in _buildings:
			var r: Rect2 = bdata["rect"]
			var btype: String = str(bdata["type"])

			if btype == "park":
				draw_rect(r, park_col)
				var tree_sp: float = 16.0
				var tx: float = r.position.x + 8.0
				while tx < r.position.x + r.size.x - 4.0:
					var ty: float = r.position.y + 8.0
					while ty < r.position.y + r.size.y - 4.0:
						var th: float = _hash(Vector2(tx, ty))
						if th > 0.35:
							draw_circle(Vector2(tx, ty), 2.5 + th * 2.0, Color(0.03, 0.08 + th * 0.04, 0.025))
						ty += tree_sp
					tx += tree_sp
				draw_line(
					Vector2(r.position.x + r.size.x * 0.5, r.position.y),
					Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y),
					Color(0.055, 0.05, 0.045), 2.5
				)
				continue

			if btype == "parking":
				draw_rect(r, parking_col)
				var line_x: float = r.position.x + 6.0
				while line_x < r.position.x + r.size.x - 4.0:
					draw_line(
						Vector2(line_x, r.position.y + 3.0),
						Vector2(line_x, r.position.y + r.size.y - 3.0),
						Color(0.08, 0.08, 0.07), 0.5
					)
					line_x += 7.0
				continue

			# Building
			var shade: float = float(bdata["shade"])
			var bldg_col := Color(shade, shade, shade * 1.1)
			draw_rect(r, bldg_col)

			draw_line(r.position, r.position + Vector2(r.size.x, 0), Color(shade * 1.4, shade * 1.4, shade * 1.5), 0.8)
			draw_line(r.position, r.position + Vector2(0, r.size.y), Color(shade * 1.3, shade * 1.3, shade * 1.4), 0.5)
			draw_line(r.position + Vector2(r.size.x, 0), r.position + r.size, Color(shade * 0.5, shade * 0.5, shade * 0.6), 0.8)
			draw_line(r.position + Vector2(0, r.size.y), r.position + r.size, Color(shade * 0.6, shade * 0.6, shade * 0.7), 0.5)

			if r.size.x > 8.0 and r.size.y > 8.0:
				var win_sp: float = 4.0
				var wx: float = r.position.x + 2.5
				while wx < r.position.x + r.size.x - 2.0:
					var wy: float = r.position.y + 2.5
					while wy < r.position.y + r.size.y - 2.0:
						var wh: float = _hash(Vector2(wx * 3.1, wy * 7.3))
						if wh > 0.55:
							var brightness: float = 0.3 + wh * 0.7
							draw_rect(Rect2(wx, wy, 1.5, 1.5),
								Color(window_col.r * brightness, window_col.g * brightness, window_col.b * brightness, window_col.a))
						wy += win_sp
					wx += win_sp

			var has_doodad: bool = bdata.get("has_doodad", false)
			if has_doodad and r.size.x > 12.0 and r.size.y > 12.0:
				var dt: int = int(bdata.get("doodad_type", 0))
				var cx: float = r.position.x + r.size.x * 0.5
				var cy: float = r.position.y + r.size.y * 0.5
				var detail_col := Color(shade * 0.7, shade * 0.7, shade * 0.75)
				match dt:
					0:  # AC unit
						draw_rect(Rect2(cx - 3, cy - 2, 6, 4), detail_col)
						draw_circle(Vector2(cx, cy), 1.5, Color(shade * 0.5, shade * 0.5, shade * 0.55))
					1:  # Antenna
						draw_line(Vector2(cx, cy + 4), Vector2(cx, cy - 6), detail_col, 1.0)
						draw_circle(Vector2(cx, cy - 6), 1.0, Color(0.6, 0.1, 0.1, 0.7))
					2:  # Stairwell access
						draw_rect(Rect2(cx - 4, cy - 3, 8, 6), Color(shade * 0.6, shade * 0.6, shade * 0.65))
						draw_rect(Rect2(cx - 1, cy, 2, 3), Color(shade * 0.4, shade * 0.4, shade * 0.45))
					3:  # Solar panels
						for sp in range(2):
							draw_rect(Rect2(cx - 5 + float(sp) * 6, cy - 2, 4, 4),
								Color(0.04, 0.05, 0.12))
					4:  # Vent pipes
						draw_circle(Vector2(cx - 3, cy), 1.5, detail_col)
						draw_circle(Vector2(cx + 3, cy - 1), 1.2, detail_col)


# ═══════════════════════════════════════════════════════════
# SHARED UI HELPERS
# ═══════════════════════════════════════════════════════════

func _build_section_label(text: String, parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)
	ThemeManager.apply_text_glow(lbl, "header")


func _make_preview_border() -> PanelContainer:
	var border := PanelContainer.new()
	border.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.3, 0.3, 0.4, 0.6)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	border.add_theme_stylebox_override("panel", style)
	return border


func _build_shader_preview(shader_def: Dictionary, parent: VBoxContainer) -> void:
	var name_str: String = str(shader_def["name"])
	var category_str: String = str(shader_def["category"])
	var desc_str: String = str(shader_def["description"])
	var shader_path: String = str(shader_def["path"])

	var header_label := Label.new()
	header_label.text = category_str + "  —  " + name_str
	parent.add_child(header_label)
	ThemeManager.apply_text_glow(header_label, "header")

	var desc_label := Label.new()
	desc_label.text = desc_str
	parent.add_child(desc_label)

	var border := _make_preview_border()
	parent.add_child(border)

	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(preview)

	var shader: Shader = load(shader_path) as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		preview.material = mat


func _show_shaders_tab() -> void:
	_tab_shaders_btn.button_pressed = true
	_tab_experimental_btn.button_pressed = false
	_shader_content.visible = true
	_experimental_content.visible = false


func _show_experimental_tab() -> void:
	_tab_shaders_btn.button_pressed = false
	_tab_experimental_btn.button_pressed = true
	_shader_content.visible = false
	_experimental_content.visible = true
