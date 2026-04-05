extends Control
## Hangar Bay screen — unified top-down blueprint view of all ships.
## Top 2 rows: player ship bays. Divider. Bottom row: support ship bays.
## Right side: placeholder interface panel.

var _vhs_overlay: ColorRect

# ── Hangar viewport ──
var _hangar_viewport: SubViewport
var _hangar_drawing: Control
var _ship_renderers: Array[ShipRenderer] = []

# ── Layout constants ──
const HANGAR_VP_SIZE := Vector2i(1000, 900)
const PLAYER_COLS: int = 4
const PLAYER_ROWS: int = 2
const SUPPORT_COLS: int = 4
const SPOT_W: float = 120.0
const SPOT_H: float = 140.0
const SPACING_X: float = 200.0
const SPACING_Y: float = 180.0
const PLAYER_TOP: float = 80.0
const SUPPORT_GAP: float = 60.0  # extra gap between player and support rows

# Colors: military grid pattern, blueprint colors
const FLOOR_COLOR := Color(0.01, 0.02, 0.06)
const LINE_COLOR := Color(0.2, 0.4, 0.8, 0.5)
const SPOT_FILL := Color(0.015, 0.03, 0.07, 0.4)
const ACCENT := Color(0.3, 0.6, 1.0)
const GRID_SPACING: float = 40.0
const DIVIDER_COLOR := Color(0.2, 0.4, 0.8, 0.25)


func _ready() -> void:
	SynthwaveBgSetup.setup(self)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_build_layout()


func _process(delta: float) -> void:
	for r in _ship_renderers:
		r.time += delta
		r.queue_redraw()


func _build_layout() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ── Left: Hangar viewport (bulk of screen) ──
	var left_panel := MarginContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.4
	left_panel.add_theme_constant_override("margin_left", 30)
	left_panel.add_theme_constant_override("margin_top", 20)
	left_panel.add_theme_constant_override("margin_right", 15)
	left_panel.add_theme_constant_override("margin_bottom", 20)
	hbox.add_child(left_panel)
	_build_hangar(left_panel)

	# ── Right: Interface placeholder ──
	var right_panel := MarginContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.6
	right_panel.add_theme_constant_override("margin_left", 15)
	right_panel.add_theme_constant_override("margin_top", 20)
	right_panel.add_theme_constant_override("margin_right", 30)
	right_panel.add_theme_constant_override("margin_bottom", 20)
	hbox.add_child(right_panel)
	_build_right_panel(right_panel)


func _build_hangar(parent: MarginContainer) -> void:
	var frame := Control.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)

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

	# Floor fills entire viewport
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hangar_viewport.add_child(floor_rect)

	# Hangar markings (grid, spots, labels, divider)
	_hangar_drawing = Control.new()
	_hangar_drawing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hangar_viewport.add_child(_hangar_drawing)
	_hangar_drawing.draw.connect(_draw_hangar)

	# Place ships in bays
	_place_ships()


func _build_right_panel(parent: MarginContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	parent.add_child(col)

	var hfont: Font = ThemeManager.get_font("font_header")

	# Placeholder title
	var title := Label.new()
	title.text = "SHIP DETAILS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(title, "header")
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		title.add_theme_font_override("font", hfont)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	col.add_child(title)

	# Placeholder info area
	var info := Label.new()
	info.text = "Select a ship bay to view details.\n\nStats, loadout, and upgrades\nwill appear here."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3))
	info.add_theme_font_size_override("font_size", 14)
	col.add_child(info)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.custom_minimum_size = Vector2(160, 40)
	ThemeManager.apply_button_style(back_btn)
	back_btn.pressed.connect(_on_back)
	col.add_child(back_btn)


# ── Spot positions ──

func _get_player_spots() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var total_w: float = (PLAYER_COLS - 1) * SPACING_X
	var start_x: float = (HANGAR_VP_SIZE.x - total_w) / 2.0
	for row in PLAYER_ROWS:
		for col_idx in PLAYER_COLS:
			positions.append(Vector2(
				start_x + col_idx * SPACING_X,
				PLAYER_TOP + row * SPACING_Y,
			))
	return positions


func _get_support_spots() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var total_w: float = (SUPPORT_COLS - 1) * SPACING_X
	var start_x: float = (HANGAR_VP_SIZE.x - total_w) / 2.0
	var support_top: float = PLAYER_TOP + PLAYER_ROWS * SPACING_Y + SUPPORT_GAP
	for col_idx in SUPPORT_COLS:
		positions.append(Vector2(
			start_x + col_idx * SPACING_X,
			support_top,
		))
	return positions


func _get_divider_y() -> float:
	var player_bottom: float = PLAYER_TOP + (PLAYER_ROWS - 1) * SPACING_Y + SPOT_H / 2.0
	var support_top: float = PLAYER_TOP + PLAYER_ROWS * SPACING_Y + SUPPORT_GAP - SPOT_H / 2.0
	return (player_bottom + support_top) / 2.0


# ── Place ships ──

func _place_ships() -> void:
	var player_spots: Array[Vector2] = _get_player_spots()
	var support_spots: Array[Vector2] = _get_support_spots()

	# Player's current ship in bay 01
	var ship := ShipRenderer.new()
	ship.ship_id = GameState.current_ship_index
	ship.render_mode = ShipRenderer.RenderMode.CHROME
	ship.animate = true
	ship.position = player_spots[0]
	ship.scale = Vector2(0.7, 0.7)
	_hangar_viewport.add_child(ship)
	_ship_renderers.append(ship)

	# Plus marker on bay 02 (ship store)
	var plus_overlay := Control.new()
	plus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var spot2: Vector2 = player_spots[1]
	plus_overlay.draw.connect(func() -> void:
		_draw_plus_marker(plus_overlay, spot2, ACCENT)
	)
	_hangar_viewport.add_child(plus_overlay)

	# Cargo ship placeholder in support bay 01
	var cargo_overlay := Control.new()
	cargo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sup_spot: Vector2 = support_spots[0]
	cargo_overlay.draw.connect(func() -> void:
		_draw_cargo_placeholder(cargo_overlay, sup_spot)
	)
	_hangar_viewport.add_child(cargo_overlay)


# ── Hangar drawing ──

func _draw_hangar() -> void:
	# Floor grid fills entire viewport
	var grid_col := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.08)
	var x: float = 0.0
	while x < HANGAR_VP_SIZE.x:
		_hangar_drawing.draw_line(Vector2(x, 0), Vector2(x, HANGAR_VP_SIZE.y), grid_col, 1.0)
		x += GRID_SPACING
	var y: float = 0.0
	while y < HANGAR_VP_SIZE.y:
		_hangar_drawing.draw_line(Vector2(0, y), Vector2(HANGAR_VP_SIZE.x, y), grid_col, 1.0)
		y += GRID_SPACING

	var hfont: Font = ThemeManager.get_font("font_header")
	var bfont: Font = ThemeManager.get_font("font_body")

	# "YOUR SHIPS" label top-left
	if hfont:
		_hangar_drawing.draw_string(hfont, Vector2(20, 35), "YOUR SHIPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)

	# Player spots
	var player_spots: Array[Vector2] = _get_player_spots()
	for i in player_spots.size():
		_draw_bay(player_spots[i], i + 1)

	# Divider line between player and support rows
	var div_y: float = _get_divider_y()
	_hangar_drawing.draw_line(Vector2(20, div_y), Vector2(HANGAR_VP_SIZE.x - 20, div_y), DIVIDER_COLOR, 1.0)

	# "SUPPORT" label
	if hfont:
		var support_label_y: float = div_y + 20
		_hangar_drawing.draw_string(hfont, Vector2(20, support_label_y), "SUPPORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6))

	# Support spots
	var support_spots: Array[Vector2] = _get_support_spots()
	for i in support_spots.size():
		_draw_bay(support_spots[i], i + 1 + player_spots.size())


func _draw_bay(pos: Vector2, bay_num: int) -> void:
	var rect := Rect2(pos.x - SPOT_W / 2, pos.y - SPOT_H / 2, SPOT_W, SPOT_H)

	# Fill and border
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
		_hangar_drawing.draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 16), "%02d" % bay_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACCENT)


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


func _draw_cargo_placeholder(canvas: Control, pos: Vector2) -> void:
	# Draw a simple cargo ship silhouette placeholder
	var col := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	# Boxy hull outline
	var hw: float = 20.0
	var hh: float = 30.0
	canvas.draw_rect(Rect2(pos.x - hw, pos.y - hh, hw * 2, hh * 2), Color(col.r, col.g, col.b, 0.1))
	canvas.draw_rect(Rect2(pos.x - hw, pos.y - hh, hw * 2, hh * 2), col, false, 1.5)
	# Cargo bay lines
	canvas.draw_line(Vector2(pos.x - hw + 4, pos.y - 8), Vector2(pos.x + hw - 4, pos.y - 8), Color(col.r, col.g, col.b, 0.2), 1.0)
	canvas.draw_line(Vector2(pos.x - hw + 4, pos.y + 8), Vector2(pos.x + hw - 4, pos.y + 8), Color(col.r, col.g, col.b, 0.2), 1.0)
	# Label
	var font: Font = ThemeManager.get_font("font_body")
	if font:
		canvas.draw_string(font, Vector2(pos.x - 22, pos.y + hh + 16), "CARGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


# ── Utility ──

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
