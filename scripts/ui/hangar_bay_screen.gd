extends Control
## Hangar Bay screen — left: top-down hangar preview, right: ship selection grid.
## Top two rows: player ships (paginated). Third row: support ships (separate pagination).

var _vhs_overlay: ColorRect

# ── Hangar preview ──
var _hangar_viewport: SubViewport
var _hangar_drawing: Control
var _ship_renderers: Array[ShipRenderer] = []

# ── Ship grid (player ships) ──
var _ship_page: int = 0
var _ship_slots: Array[Control] = []
var _ship_slot_renderers: Array = []  # Array of ShipRenderer or null
const SHIPS_PER_PAGE: int = 6  # 2 rows x 3 cols
const SHIP_SLOT_SIZE := Vector2(140, 140)

# ── Support ships ──
var _support_page: int = 0
var _support_slots: Array[Control] = []
const SUPPORTS_PER_PAGE: int = 3  # 1 row x 3 cols

# ── Hangar layout ──
const HANGAR_VP_SIZE := Vector2i(800, 700)
const HANGAR_SPOT_W: float = 120.0
const HANGAR_SPOT_H: float = 140.0

# Colors: military grid pattern, blueprint colors
const FLOOR_COLOR := Color(0.01, 0.02, 0.06)
const LINE_COLOR := Color(0.2, 0.4, 0.8, 0.5)
const SPOT_FILL := Color(0.015, 0.03, 0.07, 0.4)
const ACCENT := Color(0.3, 0.6, 1.0)
const GRID_SPACING: float = 40.0


func _ready() -> void:
	SynthwaveBgSetup.setup(self)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_build_layout()


func _process(delta: float) -> void:
	for r in _ship_renderers:
		r.time += delta
		r.queue_redraw()
	for r in _ship_slot_renderers:
		if r is ShipRenderer:
			r.time += delta
			r.queue_redraw()


func _build_layout() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ── Left: Hangar preview ──
	var left_panel := MarginContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.2
	left_panel.add_theme_constant_override("margin_left", 40)
	left_panel.add_theme_constant_override("margin_top", 30)
	left_panel.add_theme_constant_override("margin_right", 20)
	left_panel.add_theme_constant_override("margin_bottom", 30)
	hbox.add_child(left_panel)
	_build_hangar_preview(left_panel)

	# ── Right: Ship selection ──
	var right_panel := MarginContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.8
	right_panel.add_theme_constant_override("margin_left", 20)
	right_panel.add_theme_constant_override("margin_top", 30)
	right_panel.add_theme_constant_override("margin_right", 40)
	right_panel.add_theme_constant_override("margin_bottom", 30)
	hbox.add_child(right_panel)
	_build_ship_selection(right_panel)


func _build_hangar_preview(parent: MarginContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	parent.add_child(col)

	# Title
	var hfont: Font = ThemeManager.get_font("font_header")
	var title := Label.new()
	title.text = "HANGAR BAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(title, "header")
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		title.add_theme_font_override("font", hfont)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	col.add_child(title)

	# Viewport container
	var frame := Control.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(frame)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(vpc)

	_hangar_viewport = SubViewport.new()
	_hangar_viewport.transparent_bg = false
	_hangar_viewport.size = HANGAR_VP_SIZE
	_hangar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_hangar_viewport)
	VFXFactory.add_bloom_to_viewport(_hangar_viewport)

	# Floor
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hangar_viewport.add_child(floor_rect)

	# Hangar markings
	_hangar_drawing = Control.new()
	_hangar_drawing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hangar_viewport.add_child(_hangar_drawing)
	_hangar_drawing.draw.connect(_draw_hangar)

	# Ship in first spot
	var spots: Array[Vector2] = _get_hangar_spots()
	var ship := ShipRenderer.new()
	ship.ship_id = GameState.current_ship_index
	ship.render_mode = ShipRenderer.RenderMode.CHROME
	ship.animate = true
	ship.position = spots[0]
	ship.scale = Vector2(0.8, 0.8)
	_hangar_viewport.add_child(ship)
	_ship_renderers.append(ship)

	# Plus marker on second spot
	var plus_overlay := Control.new()
	plus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus_overlay.draw.connect(func() -> void:
		_draw_plus_marker(plus_overlay, spots[1], ACCENT)
	)
	_hangar_viewport.add_child(plus_overlay)

	# Back button at bottom
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.custom_minimum_size = Vector2(160, 40)
	ThemeManager.apply_button_style(back_btn)
	back_btn.pressed.connect(_on_back)
	col.add_child(back_btn)


func _build_ship_selection(parent: MarginContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	parent.add_child(col)

	var hfont: Font = ThemeManager.get_font("font_header")

	# ── Player ships section ──
	var ships_header := HBoxContainer.new()
	ships_header.add_theme_constant_override("separation", 12)
	col.add_child(ships_header)

	var ships_title := Label.new()
	ships_title.text = "YOUR FLEET"
	ships_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_text_glow(ships_title, "header")
	ships_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		ships_title.add_theme_font_override("font", hfont)
	ships_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	ships_header.add_child(ships_title)

	var ships_left := Button.new()
	ships_left.text = "\u25C1"
	ships_left.custom_minimum_size = Vector2(40, 30)
	ThemeManager.apply_button_style(ships_left)
	ships_left.pressed.connect(func() -> void: _page_ships(-1))
	ships_header.add_child(ships_left)

	var ships_right := Button.new()
	ships_right.text = "\u25B7"
	ships_right.custom_minimum_size = Vector2(40, 30)
	ThemeManager.apply_button_style(ships_right)
	ships_right.pressed.connect(func() -> void: _page_ships(1))
	ships_header.add_child(ships_right)

	# 2 rows x 3 cols grid for player ships
	var ship_grid := GridContainer.new()
	ship_grid.columns = 3
	ship_grid.add_theme_constant_override("h_separation", 12)
	ship_grid.add_theme_constant_override("v_separation", 12)
	ship_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(ship_grid)

	for i in SHIPS_PER_PAGE:
		var slot := _create_ship_slot(ship_grid)
		_ship_slots.append(slot)
		_ship_slot_renderers.append(null)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	# ── Separator ──
	var sep := ColorRect.new()
	sep.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2)
	sep.custom_minimum_size = Vector2(0, 1)
	col.add_child(sep)

	# ── Support ships section ──
	var support_header := HBoxContainer.new()
	support_header.add_theme_constant_override("separation", 12)
	col.add_child(support_header)

	var support_title := Label.new()
	support_title.text = "SUPPORT SHIPS"
	support_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_text_glow(support_title, "header")
	support_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		support_title.add_theme_font_override("font", hfont)
	support_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	support_header.add_child(support_title)

	var sup_left := Button.new()
	sup_left.text = "\u25C1"
	sup_left.custom_minimum_size = Vector2(40, 30)
	ThemeManager.apply_button_style(sup_left)
	sup_left.pressed.connect(func() -> void: _page_support(-1))
	support_header.add_child(sup_left)

	var sup_right := Button.new()
	sup_right.text = "\u25B7"
	sup_right.custom_minimum_size = Vector2(40, 30)
	ThemeManager.apply_button_style(sup_right)
	sup_right.pressed.connect(func() -> void: _page_support(1))
	support_header.add_child(sup_right)

	# 1 row x 3 cols for support ships
	var support_grid := GridContainer.new()
	support_grid.columns = 3
	support_grid.add_theme_constant_override("h_separation", 12)
	support_grid.add_theme_constant_override("v_separation", 12)
	support_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(support_grid)

	for i in SUPPORTS_PER_PAGE:
		var slot := _create_ship_slot(support_grid)
		_support_slots.append(slot)

	# Bottom spacer
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 20)
	col.add_child(bottom_spacer)

	# Populate initial page
	_refresh_ship_slots()
	_refresh_support_slots()


func _create_ship_slot(parent: GridContainer) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = SHIP_SLOT_SIZE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slot)

	# Border
	var border := ColorRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.color = Color(0.0, 0.0, 0.0, 0.0)
	slot.add_child(border)

	# Draw the slot border
	var draw_ctrl := Control.new()
	draw_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(draw_ctrl)
	draw_ctrl.draw.connect(func() -> void:
		_draw_slot_border(draw_ctrl)
	)

	return slot


func _draw_slot_border(ctrl: Control) -> void:
	var rect := Rect2(Vector2.ZERO, ctrl.size)
	# Dark fill
	ctrl.draw_rect(rect, Color(0.01, 0.015, 0.04, 0.8))
	# Blueprint-style dashed border
	var col := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.4)
	_draw_dashed_rect_on(ctrl, rect, col, 1.0, 5.0, 3.0)
	# Corner ticks
	var tick: float = 8.0
	var tcol := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	ctrl.draw_line(rect.position, rect.position + Vector2(tick, 0), tcol, 1.5)
	ctrl.draw_line(rect.position, rect.position + Vector2(0, tick), tcol, 1.5)
	ctrl.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - tick, rect.position.y), tcol, 1.5)
	ctrl.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + tick), tcol, 1.5)
	ctrl.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + tick, rect.end.y), tcol, 1.5)
	ctrl.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - tick), tcol, 1.5)
	ctrl.draw_line(rect.end, rect.end - Vector2(tick, 0), tcol, 1.5)
	ctrl.draw_line(rect.end, rect.end - Vector2(0, tick), tcol, 1.5)
	# "EMPTY" label
	var font: Font = ThemeManager.get_font("font_body")
	if font:
		var center: Vector2 = rect.size / 2.0
		ctrl.draw_string(font, Vector2(center.x - 18, center.y + 4), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2))


func _refresh_ship_slots() -> void:
	# Clear existing renderers from slots
	for i in _ship_slots.size():
		if _ship_slot_renderers[i] is ShipRenderer:
			var old_r: ShipRenderer = _ship_slot_renderers[i] as ShipRenderer
			old_r.queue_free()
			_ship_slot_renderers[i] = null

	var start: int = _ship_page * SHIPS_PER_PAGE
	for i in SHIPS_PER_PAGE:
		var ship_idx: int = start + i
		var slot: Control = _ship_slots[i]

		# Only the Stiletto (index 4) is owned for now
		if ship_idx == GameState.current_ship_index:
			# Add a SubViewport for the ship preview
			var vpc := SubViewportContainer.new()
			vpc.stretch = true
			vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
			vpc.offset_left = 4
			vpc.offset_top = 4
			vpc.offset_right = -4
			vpc.offset_bottom = -4
			slot.add_child(vpc)

			var vp := SubViewport.new()
			vp.transparent_bg = true
			vp.size = Vector2i(int(SHIP_SLOT_SIZE.x), int(SHIP_SLOT_SIZE.y))
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vpc.add_child(vp)

			var renderer := ShipRenderer.new()
			renderer.ship_id = ship_idx
			renderer.render_mode = ShipRenderer.RenderMode.CHROME
			renderer.animate = true
			renderer.position = Vector2(SHIP_SLOT_SIZE.x / 2.0, SHIP_SLOT_SIZE.y / 2.0)
			renderer.scale = Vector2(0.5, 0.5)
			vp.add_child(renderer)

			_ship_slot_renderers[i] = renderer

			# Name label
			var name_label := Label.new()
			name_label.text = ShipRegistry.get_ship_name(ship_idx)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			name_label.offset_top = -20
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", ACCENT)
			slot.add_child(name_label)


func _refresh_support_slots() -> void:
	# Support ships: just cargo placeholder in slot 0 for now
	# No actual cargo ship renderer exists yet, so show a placeholder label
	for i in _support_slots.size():
		var slot: Control = _support_slots[i]
		if i == 0 and _support_page == 0:
			var label := Label.new()
			label.text = "CARGO\nSHIP"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5))
			slot.add_child(label)


func _page_ships(direction: int) -> void:
	var total_pages: int = ceili(float(ShipRegistry.SHIP_NAMES.size()) / SHIPS_PER_PAGE)
	_ship_page = (_ship_page + direction) % total_pages
	if _ship_page < 0:
		_ship_page += total_pages
	# Clear and rebuild slots
	for slot in _ship_slots:
		# Remove dynamically added children (keep first 2: border bg + draw ctrl)
		while slot.get_child_count() > 2:
			slot.get_child(slot.get_child_count() - 1).queue_free()
	_ship_slot_renderers.clear()
	for i in SHIPS_PER_PAGE:
		_ship_slot_renderers.append(null)
	call_deferred("_refresh_ship_slots")


func _page_support(direction: int) -> void:
	# Only 1 page for now
	pass


# ── Hangar drawing ──

func _get_hangar_spots() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var cols: int = 3
	var rows: int = 3
	var spacing_x: float = 220.0
	var spacing_y: float = 200.0
	var start_x: float = (HANGAR_VP_SIZE.x - (cols - 1) * spacing_x) / 2.0
	var start_y: float = (HANGAR_VP_SIZE.y - (rows - 1) * spacing_y) / 2.0
	for row in rows:
		for col in cols:
			positions.append(Vector2(
				start_x + col * spacing_x,
				start_y + row * spacing_y,
			))
	return positions


func _draw_hangar() -> void:
	var positions: Array[Vector2] = _get_hangar_spots()

	# Floor grid (military grid pattern)
	var grid_col := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.08)
	var x: float = 0.0
	while x < HANGAR_VP_SIZE.x:
		_hangar_drawing.draw_line(Vector2(x, 0), Vector2(x, HANGAR_VP_SIZE.y), grid_col, 1.0)
		x += GRID_SPACING
	var y: float = 0.0
	while y < HANGAR_VP_SIZE.y:
		_hangar_drawing.draw_line(Vector2(0, y), Vector2(HANGAR_VP_SIZE.x, y), grid_col, 1.0)
		y += GRID_SPACING

	# Spots (military box style with blueprint colors)
	for i in positions.size():
		var pos: Vector2 = positions[i]
		var rect := Rect2(pos.x - HANGAR_SPOT_W / 2, pos.y - HANGAR_SPOT_H / 2, HANGAR_SPOT_W, HANGAR_SPOT_H)

		_hangar_drawing.draw_rect(rect, SPOT_FILL)
		_hangar_drawing.draw_rect(rect, LINE_COLOR, false, 2.0)

		# Dashed center line
		var dash_y: float = rect.position.y
		while dash_y < rect.end.y:
			var end_y: float = minf(dash_y + 8.0, rect.end.y)
			_hangar_drawing.draw_line(Vector2(pos.x, dash_y), Vector2(pos.x, end_y), Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.2), 1.0)
			dash_y += 16.0

		# Bay number
		var font: Font = ThemeManager.get_font("font_header")
		if font:
			_hangar_drawing.draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 16), "%02d" % [i + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)

	# Row dividers
	for row_i in 2:
		var div_y: float = (positions[row_i * 3].y + positions[(row_i + 1) * 3].y) / 2.0
		_hangar_drawing.draw_line(Vector2(30, div_y), Vector2(HANGAR_VP_SIZE.x - 30, div_y), Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.12), 1.0)


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


func _draw_dashed_rect_on(ctrl: Control, rect: Rect2, col: Color, width: float, dash: float, gap: float) -> void:
	_draw_dashed_line_on(ctrl, rect.position, Vector2(rect.end.x, rect.position.y), col, width, dash, gap)
	_draw_dashed_line_on(ctrl, Vector2(rect.end.x, rect.position.y), rect.end, col, width, dash, gap)
	_draw_dashed_line_on(ctrl, rect.end, Vector2(rect.position.x, rect.end.y), col, width, dash, gap)
	_draw_dashed_line_on(ctrl, Vector2(rect.position.x, rect.end.y), rect.position, col, width, dash, gap)


func _draw_dashed_line_on(ctrl: Control, from: Vector2, to: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var dir: Vector2 = (to - from)
	var length: float = dir.length()
	if length < 0.01:
		return
	dir = dir / length
	var p: float = 0.0
	while p < length:
		var e: float = minf(p + dash, length)
		ctrl.draw_line(from + dir * p, from + dir * e, col, width)
		p = e + gap


# ── Navigation ──

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mission_prep_menu.tscn")


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
