extends Control
## Encounters screen — flight path & formation editor.
## Tab bar at top: PATHS | FORMATIONS. Each tab has its own left panel, canvas, right panel.

const LEFT_PANEL_W := 240.0
const RIGHT_PANEL_W := 200.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0
const WP_RADIUS := 8.0
const HANDLE_RADIUS := 5.0
const HIT_RADIUS := 14.0
const HANDLE_HIT_RADIUS := 12.0
const CURVE_SAMPLES := 40
const PREVIEW_DOT_RADIUS := 6.0
const MAX_UNDO := 50
const TOOLBAR_H := 36.0
const TAB_BAR_H := 32.0

# Tab state
var _active_tab: String = "paths"
var _tab_buttons: Array[Button] = []

# Container references for tab switching
var _paths_container: VBoxContainer  # Toolbar + HSplit for paths tab
var _main_vbox: VBoxContainer  # Main layout container

# Tool modes
enum Tool { DRAW, SELECT, CURVE, ARC }
var _active_tool: int = Tool.DRAW
var _tool_buttons: Array[Button] = []

# ARC tool state (editor-only, not persisted)
var _arc_radius: float = 150.0
var _arc_angle_deg: float = 360.0
var _arc_points: int = 8
var _arc_start_deg: float = 270.0
var _arc_preview_pos: Vector2 = Vector2.ZERO
var _arc_hovering: bool = false

var _vhs_overlay: ColorRect
var _bg: ColorRect

# Path list
var _all_paths: Array[FlightPathData] = []
var _selected_path: FlightPathData = null
var _path_buttons: Array[Button] = []
var _path_list_vbox: VBoxContainer

# Canvas
var _canvas: Control
var _canvas_rect: Rect2  # The scaled screen-boundary rect within the canvas area

# Interaction state
var _selected_wps: Array[int] = []  # Multi-select: list of selected waypoint indices
var _dragging: bool = false
var _drag_type: String = ""  # "group", "ctrl_in", "ctrl_out"
var _drag_index: int = -1  # For handle drags, which wp index
var _drag_start_canvas: Vector2 = Vector2.ZERO  # Mouse pos at drag start (canvas coords)
var _drag_wp_origins: Array[Vector2] = []  # Screen-space positions of all selected wps at drag start
const NUDGE_AMOUNT := 10.0  # Pixels per arrow/WASD press in screen space

# Properties panel
var _right_panel: PanelContainer
var _name_edit: LineEdit
var _arc_radius_spin: SpinBox
var _arc_angle_spin: SpinBox
var _arc_points_spin: SpinBox
var _arc_start_spin: SpinBox

# Preview animation
var _previewing: bool = false
var _preview_progress: float = 0.0  # distance traveled along curve
var _preview_curve: Curve2D
var _preview_time: float = 0.0  # for animating the preview ship

# Undo stack
var _undo_stack: Array[Dictionary] = []  # Array of path snapshots

# ── Formation tab state ────────────────────────────────────────
var _fm_container: HSplitContainer  # Outer HSplit for formations tab
var _fm_built: bool = false
var _all_formations: Array[FormationData] = []
var _selected_formation: FormationData = null
var _fm_buttons: Array[Button] = []
var _fm_list_vbox: VBoxContainer
var _fm_canvas: Control
var _fm_canvas_rect: Rect2
var _fm_right_panel: PanelContainer
var _fm_name_edit: LineEdit
var _fm_grid_size: float = 40.0
var _fm_selected_slots: Array[int] = []
var _fm_dragging: bool = false
var _fm_drag_start: Vector2 = Vector2.ZERO
var _fm_drag_origins: Array[Vector2] = []
var _fm_ship_dropdown: OptionButton


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE

	# Grid background
	_bg = $Background
	ThemeManager.apply_grid_background(_bg)

	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	# Main layout container
	_main_vbox = VBoxContainer.new()
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_vbox)

	_build_tab_bar()
	_build_paths_tab()


func _build_paths_tab() -> void:
	_paths_container = VBoxContainer.new()
	_paths_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paths_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_child(_paths_container)

	_build_toolbar()

	var outer_split := HSplitContainer.new()
	outer_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paths_container.add_child(outer_split)

	_build_left_panel(outer_split)

	var inner_split := HSplitContainer.new()
	inner_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_split.add_child(inner_split)

	_build_canvas(inner_split)
	_build_right_panel(inner_split)

	_load_all_paths()
	if _all_paths.size() > 0:
		_select_path(_all_paths[0])


func _process(delta: float) -> void:
	if _active_tab != "paths":
		return
	if _previewing and _preview_curve and _preview_curve.point_count >= 2:
		var total_len: float = _preview_curve.get_baked_length()
		if total_len <= 0.0:
			_previewing = false
			_canvas.queue_redraw()
			return
		_preview_time += delta
		var speed: float = _get_preview_speed()
		_preview_progress += speed * delta
		if _preview_progress >= total_len:
			_previewing = false
			_preview_progress = 0.0
			_preview_time = 0.0
		_canvas.queue_redraw()


func _get_preview_speed() -> float:
	if not _selected_path:
		return 200.0
	return _selected_path.default_speed


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")
		return
	if _active_tab != "paths":
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			# CTRL+Z undo
			if ke.keycode == KEY_Z and ke.ctrl_pressed:
				_undo()
			# CTRL+A select all waypoints
			elif ke.keycode == KEY_A and ke.ctrl_pressed:
				_select_all_wps()
			# Tool shortcuts and nudge (only when not typing in a LineEdit/SpinBox)
			elif not _is_text_input_focused():
				if ke.keycode == KEY_1:
					_set_tool(Tool.DRAW)
				elif ke.keycode == KEY_2:
					_set_tool(Tool.SELECT)
				elif ke.keycode == KEY_3:
					_set_tool(Tool.CURVE)
				elif ke.keycode == KEY_4:
					_set_tool(Tool.ARC)
				# Arrow keys / WASD nudge selected waypoints
				elif _selected_wps.size() > 0 and _selected_path:
					var nudge := Vector2.ZERO
					match ke.keycode:
						KEY_UP, KEY_W: nudge = Vector2(0, -NUDGE_AMOUNT)
						KEY_DOWN, KEY_S: nudge = Vector2(0, NUDGE_AMOUNT)
						KEY_LEFT, KEY_A: nudge = Vector2(-NUDGE_AMOUNT, 0)
						KEY_RIGHT, KEY_D: nudge = Vector2(NUDGE_AMOUNT, 0)
					if nudge != Vector2.ZERO:
						if ke.shift_pressed:
							nudge *= 5.0
						_nudge_selected(nudge)


func _is_text_input_focused() -> bool:
	var vp: Viewport = get_viewport()
	if not vp:
		return false
	var focused: Control = vp.gui_get_focus_owner()
	return focused is LineEdit or focused is SpinBox


# ── Tab bar ────────────────────────────────────────────────────

func _build_tab_bar() -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = TAB_BAR_H
	bar.add_theme_constant_override("separation", 0)
	_main_vbox.add_child(bar)

	var tabs: Array[String] = ["PATHS", "FORMATIONS"]
	for tab_name in tabs:
		var btn := Button.new()
		btn.text = tab_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = TAB_BAR_H
		var tab_id: String = tab_name.to_lower()
		btn.pressed.connect(func() -> void: _switch_tab(tab_id))
		ThemeManager.apply_button_style(btn)
		bar.add_child(btn)
		_tab_buttons.append(btn)

	_update_tab_buttons()


func _update_tab_buttons() -> void:
	for i in range(_tab_buttons.size()):
		var tab_id: String = _tab_buttons[i].text.to_lower()
		if tab_id == _active_tab:
			_tab_buttons[i].modulate = Color(1.3, 1.3, 1.6)
		else:
			_tab_buttons[i].modulate = Color(0.6, 0.6, 0.7)


func _switch_tab(tab_id: String) -> void:
	if tab_id == _active_tab:
		return
	_active_tab = tab_id
	_update_tab_buttons()

	if tab_id == "paths":
		if _fm_container:
			_fm_container.visible = false
		_paths_container.visible = true
	elif tab_id == "formations":
		_previewing = false
		_paths_container.visible = false
		if not _fm_built:
			_build_formations_tab()
			_fm_built = true
		else:
			_fm_container.visible = true


# ── Toolbar ────────────────────────────────────────────────────

func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = TOOLBAR_H
	bar.add_theme_constant_override("separation", 6)
	_paths_container.add_child(bar)

	var tool_names: Array[String] = ["1: DRAW", "2: SELECT", "3: CURVE", "4: ARC"]
	for i in range(tool_names.size()):
		var btn := Button.new()
		btn.text = tool_names[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = TOOLBAR_H
		var tool_idx: int = i
		btn.pressed.connect(func() -> void: _set_tool(tool_idx))
		ThemeManager.apply_button_style(btn)
		bar.add_child(btn)
		_tool_buttons.append(btn)

	_update_tool_buttons()


func _set_tool(tool: int) -> void:
	var prev_tool: int = _active_tool
	_active_tool = tool
	_arc_hovering = false
	_update_tool_buttons()
	# Rebuild right panel when switching to/from ARC to show/hide arc params
	if (tool == Tool.ARC) != (prev_tool == Tool.ARC):
		_rebuild_right_panel()


func _update_tool_buttons() -> void:
	for i in range(_tool_buttons.size()):
		if i == _active_tool:
			_tool_buttons[i].modulate = Color(1.3, 1.3, 1.6)
		else:
			_tool_buttons[i].modulate = Color(0.6, 0.6, 0.7)


# ── Undo system ────────────────────────────────────────────────

func _push_undo() -> void:
	if not _selected_path:
		return
	# Deep copy waypoints and segment_speeds
	var snapshot: Dictionary = {
		"waypoints": _deep_copy_waypoints(),
		"segment_speeds": _selected_path.segment_speeds.duplicate(),
	}
	_undo_stack.append(snapshot)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.remove_at(0)


func _undo() -> void:
	if _undo_stack.size() == 0 or not _selected_path:
		return
	var snapshot: Dictionary = _undo_stack.pop_back()
	_selected_path.waypoints = snapshot["waypoints"]
	_selected_path.segment_speeds = snapshot["segment_speeds"]
	_selected_wps.clear()
	_dragging = false
	_save_current()
	_rebuild_right_panel()
	_canvas.queue_redraw()


func _deep_copy_waypoints() -> Array:
	var copy: Array = []
	for wp in _selected_path.waypoints:
		var pos: Array = wp["pos"]
		var ci: Array = wp["ctrl_in"]
		var co: Array = wp["ctrl_out"]
		copy.append({
			"pos": [float(pos[0]), float(pos[1])],
			"ctrl_in": [float(ci[0]), float(ci[1])],
			"ctrl_out": [float(co[0]), float(co[1])],
		})
	return copy


# ── Theme ──────────────────────────────────────────────────────

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
	ThemeManager.apply_grid_background(_bg)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_theme_to_panels()
	for btn in _tab_buttons:
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)
	_update_tab_buttons()
	for btn in _fm_buttons:
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)


func _apply_theme_to_panels() -> void:
	for btn in _path_buttons:
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)
	if _right_panel:
		for child in _right_panel.get_children():
			if child is Button:
				ThemeManager.apply_button_style(child)


# ── Left panel: path list ──────────────────────────────────────

func _build_left_panel(parent: HSplitContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = LEFT_PANEL_W
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "FLIGHT PATHS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(header, "header")
	vbox.add_child(header)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	vbox.add_child(spacer)

	# Scrollable path list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_path_list_vbox = VBoxContainer.new()
	_path_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_path_list_vbox)

	# Buttons at bottom
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_box)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new_path)
	ThemeManager.apply_button_style(new_btn)
	btn_box.add_child(new_btn)

	var dupe_btn := Button.new()
	dupe_btn.text = "DUPE"
	dupe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dupe_btn.pressed.connect(_on_dupe_path)
	ThemeManager.apply_button_style(dupe_btn)
	btn_box.add_child(dupe_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_path)
	ThemeManager.apply_button_style(del_btn)
	btn_box.add_child(del_btn)


func _rebuild_path_list() -> void:
	for child in _path_list_vbox.get_children():
		_path_list_vbox.remove_child(child)
		child.queue_free()
	_path_buttons.clear()

	for fp in _all_paths:
		var btn := Button.new()
		btn.text = fp.display_name if fp.display_name != "" else fp.id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fp_ref: FlightPathData = fp
		btn.pressed.connect(func() -> void: _select_path(fp_ref))
		ThemeManager.apply_button_style(btn)
		_path_list_vbox.add_child(btn)
		_path_buttons.append(btn)

	_highlight_selected_button()


func _highlight_selected_button() -> void:
	for i in range(_path_buttons.size()):
		if i < _all_paths.size() and _all_paths[i] == _selected_path:
			_path_buttons[i].modulate = Color(1.2, 1.2, 1.5)
		else:
			_path_buttons[i].modulate = Color.WHITE


# ── Center: canvas ─────────────────────────────────────────────

func _build_canvas(parent: HSplitContainer) -> void:
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center_vbox)

	var canvas_container := Control.new()
	canvas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_container.clip_contents = true
	canvas_container.mouse_filter = Control.MOUSE_FILTER_STOP
	center_vbox.add_child(canvas_container)

	var drawer := _CanvasDraw.new()
	drawer.screen = self
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_container.add_child(drawer)
	_canvas = drawer

	# Action buttons below canvas
	var btn_bar := HBoxContainer.new()
	btn_bar.custom_minimum_size.y = 36
	btn_bar.add_theme_constant_override("separation", 8)
	center_vbox.add_child(btn_bar)

	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.pressed.connect(_on_play_preview)
	ThemeManager.apply_button_style(play_btn)
	btn_bar.add_child(play_btn)

	var stop_btn := Button.new()
	stop_btn.text = "STOP"
	stop_btn.pressed.connect(_on_stop_preview)
	ThemeManager.apply_button_style(stop_btn)
	btn_bar.add_child(stop_btn)

	var clear_btn := Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.pressed.connect(_on_clear_path)
	ThemeManager.apply_button_style(clear_btn)
	btn_bar.add_child(clear_btn)


func _compute_canvas_rect() -> void:
	var canvas_size: Vector2 = _canvas.size
	var margin := 30.0
	var avail_w: float = canvas_size.x - margin * 2
	var avail_h: float = canvas_size.y - margin * 2 - 50  # room for bottom buttons
	var scale_x: float = avail_w / SCREEN_W
	var scale_y: float = avail_h / SCREEN_H
	var s: float = minf(scale_x, scale_y)
	var rect_w: float = SCREEN_W * s
	var rect_h: float = SCREEN_H * s
	var rx: float = (canvas_size.x - rect_w) * 0.5
	var ry: float = margin
	_canvas_rect = Rect2(rx, ry, rect_w, rect_h)


func _screen_to_canvas(screen_pos: Vector2) -> Vector2:
	return Vector2(
		_canvas_rect.position.x + (screen_pos.x / SCREEN_W) * _canvas_rect.size.x,
		_canvas_rect.position.y + (screen_pos.y / SCREEN_H) * _canvas_rect.size.y,
	)


func _canvas_to_screen(canvas_pos: Vector2) -> Vector2:
	return Vector2(
		((canvas_pos.x - _canvas_rect.position.x) / _canvas_rect.size.x) * SCREEN_W,
		((canvas_pos.y - _canvas_rect.position.y) / _canvas_rect.size.y) * SCREEN_H,
	)


# ── Right panel: properties ────────────────────────────────────

func _build_right_panel(parent: HSplitContainer) -> void:
	_right_panel = PanelContainer.new()
	_right_panel.custom_minimum_size.x = RIGHT_PANEL_W
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_right_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(_right_panel)

	_rebuild_right_panel()


func _rebuild_right_panel() -> void:
	for child in _right_panel.get_children():
		_right_panel.remove_child(child)
		child.queue_free()
	_name_edit = null
	_arc_radius_spin = null
	_arc_angle_spin = null
	_arc_points_spin = null
	_arc_start_spin = null

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	_right_panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "PROPERTIES"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(header, "header")
	vbox.add_child(header)

	if not _selected_path:
		var hint := Label.new()
		hint.text = "No path selected"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(hint)
		return

	# Name
	var name_label := Label.new()
	name_label.text = "NAME"
	ThemeManager.apply_text_glow(name_label, "body")
	vbox.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.text = _selected_path.display_name
	_name_edit.text_changed.connect(_on_name_changed)
	vbox.add_child(_name_edit)

	# Waypoint count info
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var info := Label.new()
	info.text = str(_selected_path.waypoints.size()) + " waypoints"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(info)

	# ARC tool parameters (only when ARC tool is active)
	if _active_tool == Tool.ARC:
		var sep3 := HSeparator.new()
		vbox.add_child(sep3)

		var arc_header := Label.new()
		arc_header.text = "ARC PARAMS"
		arc_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ThemeManager.apply_text_glow(arc_header, "header")
		vbox.add_child(arc_header)

		var rad_label := Label.new()
		rad_label.text = "RADIUS"
		ThemeManager.apply_text_glow(rad_label, "body")
		vbox.add_child(rad_label)
		_arc_radius_spin = SpinBox.new()
		_arc_radius_spin.min_value = 20
		_arc_radius_spin.max_value = 800
		_arc_radius_spin.step = 10
		_arc_radius_spin.value = _arc_radius
		_arc_radius_spin.value_changed.connect(func(v: float) -> void: _arc_radius = v; _canvas.queue_redraw())
		vbox.add_child(_arc_radius_spin)

		var angle_label := Label.new()
		angle_label.text = "ARC ANGLE"
		ThemeManager.apply_text_glow(angle_label, "body")
		vbox.add_child(angle_label)
		_arc_angle_spin = SpinBox.new()
		_arc_angle_spin.min_value = 10
		_arc_angle_spin.max_value = 360
		_arc_angle_spin.step = 10
		_arc_angle_spin.value = _arc_angle_deg
		_arc_angle_spin.value_changed.connect(func(v: float) -> void: _arc_angle_deg = v; _canvas.queue_redraw())
		vbox.add_child(_arc_angle_spin)

		var pts_label := Label.new()
		pts_label.text = "POINTS"
		ThemeManager.apply_text_glow(pts_label, "body")
		vbox.add_child(pts_label)
		_arc_points_spin = SpinBox.new()
		_arc_points_spin.min_value = 3
		_arc_points_spin.max_value = 24
		_arc_points_spin.step = 1
		_arc_points_spin.value = _arc_points
		_arc_points_spin.value_changed.connect(func(v: float) -> void: _arc_points = int(v); _canvas.queue_redraw())
		vbox.add_child(_arc_points_spin)

		var start_label := Label.new()
		start_label.text = "START ANGLE"
		ThemeManager.apply_text_glow(start_label, "body")
		vbox.add_child(start_label)
		_arc_start_spin = SpinBox.new()
		_arc_start_spin.min_value = 0
		_arc_start_spin.max_value = 360
		_arc_start_spin.step = 10
		_arc_start_spin.value = _arc_start_deg
		_arc_start_spin.value_changed.connect(func(v: float) -> void: _arc_start_deg = v; _canvas.queue_redraw())
		vbox.add_child(_arc_start_spin)


# ── Data operations ────────────────────────────────────────────

func _load_all_paths() -> void:
	_all_paths = FlightPathDataManager.load_all()
	_rebuild_path_list()


func _select_path(fp: FlightPathData) -> void:
	_selected_path = fp
	_selected_wps.clear()
	_previewing = false
	_preview_progress = 0.0
	_preview_time = 0.0
	_undo_stack.clear()
	_rebuild_right_panel()
	_rebuild_path_list()
	_canvas.queue_redraw()


func _save_current() -> void:
	if _selected_path:
		FlightPathDataManager.save(_selected_path.id, _selected_path.to_dict())


func _on_new_path() -> void:
	var new_id: String = FlightPathDataManager.generate_id("path")
	var data: Dictionary = {
		"id": new_id,
		"display_name": "New Path",
		"default_speed": 200.0,
		"segment_speeds": {},
		"waypoints": [],
	}
	FlightPathDataManager.save(new_id, data)
	_load_all_paths()
	for fp in _all_paths:
		if fp.id == new_id:
			_select_path(fp)
			break


func _on_delete_path() -> void:
	if not _selected_path:
		return
	FlightPathDataManager.delete(_selected_path.id)
	_selected_path = null
	_load_all_paths()
	if _all_paths.size() > 0:
		_select_path(_all_paths[0])
	else:
		_rebuild_right_panel()
		_canvas.queue_redraw()


func _on_name_changed(new_text: String) -> void:
	if _selected_path:
		_selected_path.display_name = new_text
		_save_current()
		_rebuild_path_list()


func _on_dupe_path() -> void:
	if not _selected_path:
		return
	var new_id: String = FlightPathDataManager.generate_id("path")
	var data: Dictionary = _selected_path.to_dict()
	data["id"] = new_id
	data["display_name"] = _selected_path.display_name + " Copy"
	FlightPathDataManager.save(new_id, data)
	_load_all_paths()
	for fp in _all_paths:
		if fp.id == new_id:
			_select_path(fp)
			break


func _on_play_preview() -> void:
	if not _selected_path or _selected_path.waypoints.size() < 2:
		return
	_preview_curve = _selected_path.to_curve2d()
	_preview_progress = 0.0
	_preview_time = 0.0
	_previewing = true
	_canvas.queue_redraw()


func _on_stop_preview() -> void:
	_previewing = false
	_preview_progress = 0.0
	_preview_time = 0.0
	_canvas.queue_redraw()


func _on_clear_path() -> void:
	if not _selected_path:
		return
	_push_undo()
	_selected_path.waypoints.clear()
	_selected_path.segment_speeds.clear()
	_selected_wps.clear()
	_save_current()
	_rebuild_right_panel()
	_canvas.queue_redraw()


# ── Canvas input handling ──────────────────────────────────────

func _handle_canvas_input(event: InputEvent) -> void:
	if not _selected_path:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				match _active_tool:
					Tool.DRAW:
						_tool_draw_click(mb.position, mb.shift_pressed)
					Tool.SELECT:
						_tool_select_click(mb.position, mb.shift_pressed)
					Tool.CURVE:
						_tool_curve_click(mb.position)
					Tool.ARC:
						_tool_arc_click(mb.position)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				# Right-click delete works in any mode
				_on_canvas_right_click(mb.position)
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT and _dragging:
				_dragging = false
				_save_current()
				_rebuild_right_panel()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging:
			_on_canvas_drag(mm.position)
		elif _active_tool == Tool.ARC:
			_arc_preview_pos = mm.position
			_arc_hovering = _canvas_rect.has_point(mm.position)
			_canvas.queue_redraw()


# ── DRAW tool: click to add waypoints ──────────────────────────

func _tool_draw_click(pos: Vector2, prepend: bool = false) -> void:
	if _canvas_rect.has_point(pos):
		_push_undo()
		var screen_pos: Vector2 = _canvas_to_screen(pos)
		screen_pos.x = clampf(screen_pos.x, 0, SCREEN_W)
		screen_pos.y = clampf(screen_pos.y, 0, SCREEN_H)
		if prepend:
			_selected_path.waypoints.insert(0, {
				"pos": [screen_pos.x, screen_pos.y],
				"ctrl_in": [0.0, 0.0],
				"ctrl_out": [0.0, 0.0],
			})
			# Shift segment speed keys up by 1
			var new_speeds: Dictionary = {}
			for key in _selected_path.segment_speeds:
				new_speeds[str(int(key) + 1)] = _selected_path.segment_speeds[key]
			_selected_path.segment_speeds = new_speeds
			_selected_wps = [0]
		else:
			_selected_path.add_waypoint(screen_pos)
			_selected_wps = [_selected_path.waypoints.size() - 1]
		_save_current()
		_rebuild_right_panel()
		_canvas.queue_redraw()


# ── SELECT tool: drag waypoints ───────────────────────────────

func _tool_select_click(pos: Vector2, shift_held: bool = false) -> void:
	# Check waypoint hit
	for i in range(_selected_path.waypoints.size()):
		var wp_canvas: Vector2 = _screen_to_canvas(_selected_path.get_waypoint_pos(i))
		if pos.distance_to(wp_canvas) < HIT_RADIUS:
			if shift_held:
				# Shift+click: toggle waypoint in/out of selection
				if i in _selected_wps:
					_selected_wps.erase(i)
				else:
					_selected_wps.append(i)
			else:
				# Plain click on unselected wp: select only it
				# Plain click on already-selected wp: keep group (start drag)
				if i not in _selected_wps:
					_selected_wps = [i]
			# Start group drag
			if i in _selected_wps:
				_push_undo()
				_dragging = true
				_drag_type = "group"
				_drag_start_canvas = pos
				_drag_wp_origins.clear()
				for idx in _selected_wps:
					_drag_wp_origins.append(_selected_path.get_waypoint_pos(idx))
			_canvas.queue_redraw()
			return

	# Click empty space → deselect all (unless shift held)
	if not shift_held:
		_selected_wps.clear()
	_canvas.queue_redraw()


# ── CURVE tool: drag bezier handles ────────────────────────────

func _tool_curve_click(pos: Vector2) -> void:
	# First check if clicking near any waypoint's handles (all waypoints, not just selected)
	for i in range(_selected_path.waypoints.size()):
		var wp_pos: Vector2 = _selected_path.get_waypoint_pos(i)
		var co: Vector2 = _selected_path.get_waypoint_ctrl_out(i)
		var ci: Vector2 = _selected_path.get_waypoint_ctrl_in(i)

		var co_canvas: Vector2 = _screen_to_canvas(wp_pos + co)
		if pos.distance_to(co_canvas) < HANDLE_HIT_RADIUS:
			_push_undo()
			_selected_wps = [i]
			_dragging = true
			_drag_type = "ctrl_out"
			_drag_index = i
			_canvas.queue_redraw()
			return

		var ci_canvas: Vector2 = _screen_to_canvas(wp_pos + ci)
		if pos.distance_to(ci_canvas) < HANDLE_HIT_RADIUS:
			_push_undo()
			_selected_wps = [i]
			_dragging = true
			_drag_type = "ctrl_in"
			_drag_index = i
			_canvas.queue_redraw()
			return

	# If no handle hit, check if clicking near a waypoint → select it to show its handles
	for i in range(_selected_path.waypoints.size()):
		var wp_canvas: Vector2 = _screen_to_canvas(_selected_path.get_waypoint_pos(i))
		if pos.distance_to(wp_canvas) < HIT_RADIUS:
			_selected_wps = [i]
			_canvas.queue_redraw()
			return


# ── ARC tool: stamp arc waypoints ──────────────────────────────

func _tool_arc_click(pos: Vector2) -> void:
	if not _canvas_rect.has_point(pos):
		return
	_push_undo()
	var center: Vector2 = _canvas_to_screen(pos)
	var n: int = _arc_points
	var radius: float = _arc_radius
	var arc_rad: float = deg_to_rad(_arc_angle_deg)
	var start_rad: float = deg_to_rad(_arc_start_deg)
	var is_full_circle: bool = absf(_arc_angle_deg - 360.0) < 0.01

	var segment_angle: float = arc_rad / float(n) if is_full_circle else arc_rad / float(n - 1)
	var k: float = (4.0 / 3.0) * tan(segment_angle / 4.0) * radius

	for i in range(n):
		var t: float = float(i) / float(n) if is_full_circle else float(i) / float(n - 1)
		var a: float = start_rad + t * arc_rad
		var wp_pos: Vector2 = center + Vector2(cos(a), sin(a)) * radius
		var tangent: Vector2 = Vector2(-sin(a), cos(a))
		var ctrl_in: Vector2 = -tangent * k
		var ctrl_out: Vector2 = tangent * k

		# For non-full arcs, zero out outer handles at endpoints
		if not is_full_circle:
			if i == 0:
				ctrl_in = Vector2.ZERO
			if i == n - 1:
				ctrl_out = Vector2.ZERO

		_selected_path.waypoints.append({
			"pos": [wp_pos.x, wp_pos.y],
			"ctrl_in": [ctrl_in.x, ctrl_in.y],
			"ctrl_out": [ctrl_out.x, ctrl_out.y],
		})

	_selected_wps.clear()
	_save_current()
	_rebuild_right_panel()
	_canvas.queue_redraw()
	# Auto-switch to SELECT tool
	_set_tool(Tool.SELECT)


func _compute_arc_preview_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var n: int = _arc_points
	var radius: float = _arc_radius
	var arc_rad: float = deg_to_rad(_arc_angle_deg)
	var start_rad: float = deg_to_rad(_arc_start_deg)
	var is_full_circle: bool = absf(_arc_angle_deg - 360.0) < 0.01
	var segment_angle: float = arc_rad / float(n) if is_full_circle else arc_rad / float(n - 1)
	var k: float = (4.0 / 3.0) * tan(segment_angle / 4.0) * radius
	var samples_per_seg := 16

	# Build waypoint data
	var wps: Array[Dictionary] = []
	for i in range(n):
		var t: float = float(i) / float(n) if is_full_circle else float(i) / float(n - 1)
		var a: float = start_rad + t * arc_rad
		var wp_pos := Vector2(cos(a), sin(a)) * radius
		var tangent := Vector2(-sin(a), cos(a))
		var ci: Vector2 = -tangent * k
		var co: Vector2 = tangent * k
		if not is_full_circle:
			if i == 0:
				ci = Vector2.ZERO
			if i == n - 1:
				co = Vector2.ZERO
		wps.append({"pos": wp_pos, "ci": ci, "co": co})

	var seg_count: int = n if is_full_circle else n - 1
	for i in range(seg_count):
		var i_next: int = (i + 1) % n
		var p0: Vector2 = wps[i]["pos"]
		var p0_out: Vector2 = p0 + wps[i]["co"]
		var p1: Vector2 = wps[i_next]["pos"]
		var p1_in: Vector2 = p1 + wps[i_next]["ci"]
		for j in range(samples_per_seg):
			var st: float = float(j) / float(samples_per_seg)
			points.append(p0.bezier_interpolate(p0_out, p1_in, p1, st))
		if i == seg_count - 1:
			points.append(p1)

	return points


func _on_canvas_right_click(pos: Vector2) -> void:
	for i in range(_selected_path.waypoints.size()):
		var wp_canvas: Vector2 = _screen_to_canvas(_selected_path.get_waypoint_pos(i))
		if pos.distance_to(wp_canvas) < HIT_RADIUS:
			_push_undo()
			_selected_path.remove_waypoint(i)
			# Update selection indices after removal
			var new_sel: Array[int] = []
			for idx in _selected_wps:
				if idx < i:
					new_sel.append(idx)
				elif idx > i:
					new_sel.append(idx - 1)
			_selected_wps = new_sel
			_save_current()
			_rebuild_right_panel()
			_canvas.queue_redraw()
			return


func _on_canvas_drag(pos: Vector2) -> void:
	if _drag_type == "group":
		# Move all selected waypoints by the same delta
		var delta_screen: Vector2 = _canvas_to_screen(pos) - _canvas_to_screen(_drag_start_canvas)
		for j in range(_selected_wps.size()):
			var idx: int = _selected_wps[j]
			if idx < _selected_path.waypoints.size():
				var new_pos: Vector2 = _drag_wp_origins[j] + delta_screen
				new_pos.x = clampf(new_pos.x, 0, SCREEN_W)
				new_pos.y = clampf(new_pos.y, 0, SCREEN_H)
				_selected_path.set_waypoint_pos(idx, new_pos)
	elif _drag_type == "ctrl_in":
		if _drag_index >= 0 and _drag_index < _selected_path.waypoints.size():
			var screen_pos: Vector2 = _canvas_to_screen(pos)
			var wp_pos: Vector2 = _selected_path.get_waypoint_pos(_drag_index)
			_selected_path.set_waypoint_ctrl_in(_drag_index, screen_pos - wp_pos)
	elif _drag_type == "ctrl_out":
		if _drag_index >= 0 and _drag_index < _selected_path.waypoints.size():
			var screen_pos: Vector2 = _canvas_to_screen(pos)
			var wp_pos: Vector2 = _selected_path.get_waypoint_pos(_drag_index)
			_selected_path.set_waypoint_ctrl_out(_drag_index, screen_pos - wp_pos)
	_canvas.queue_redraw()


func _select_all_wps() -> void:
	if not _selected_path:
		return
	_selected_wps.clear()
	for i in range(_selected_path.waypoints.size()):
		_selected_wps.append(i)
	_canvas.queue_redraw()


func _nudge_selected(delta: Vector2) -> void:
	if not _selected_path or _selected_wps.size() == 0:
		return
	_push_undo()
	for idx in _selected_wps:
		if idx < _selected_path.waypoints.size():
			var pos: Vector2 = _selected_path.get_waypoint_pos(idx)
			pos.x = clampf(pos.x + delta.x, 0, SCREEN_W)
			pos.y = clampf(pos.y + delta.y, 0, SCREEN_H)
			_selected_path.set_waypoint_pos(idx, pos)
	_save_current()
	_canvas.queue_redraw()


# ══════════════════════════════════════════════════════════════
# ── FORMATIONS TAB ────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════

func _build_formations_tab() -> void:
	_fm_container = HSplitContainer.new()
	_fm_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fm_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_child(_fm_container)

	_build_fm_left_panel()

	var inner_split := HSplitContainer.new()
	inner_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fm_container.add_child(inner_split)

	_build_fm_canvas(inner_split)
	_build_fm_right_panel(inner_split)

	_load_all_formations()
	if _all_formations.size() > 0:
		_select_formation(_all_formations[0])


func _build_fm_left_panel() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = LEFT_PANEL_W
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	_fm_container.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "FORMATIONS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(header, "header")
	vbox.add_child(header)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	vbox.add_child(spacer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_fm_list_vbox = VBoxContainer.new()
	_fm_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fm_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_fm_list_vbox)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_box)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new_formation)
	ThemeManager.apply_button_style(new_btn)
	btn_box.add_child(new_btn)

	var dupe_btn := Button.new()
	dupe_btn.text = "DUPE"
	dupe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dupe_btn.pressed.connect(_on_dupe_formation)
	ThemeManager.apply_button_style(dupe_btn)
	btn_box.add_child(dupe_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_formation)
	ThemeManager.apply_button_style(del_btn)
	btn_box.add_child(del_btn)


func _build_fm_canvas(parent: HSplitContainer) -> void:
	var canvas_container := Control.new()
	canvas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_container.clip_contents = true
	canvas_container.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(canvas_container)

	var drawer := _FmCanvasDraw.new()
	drawer.screen = self
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_container.add_child(drawer)
	_fm_canvas = drawer


func _compute_fm_canvas_rect() -> void:
	var canvas_size: Vector2 = _fm_canvas.size
	var margin := 30.0
	var avail_w: float = canvas_size.x - margin * 2
	var avail_h: float = canvas_size.y - margin * 2
	# Formation canvas represents a 600×600 pixel area centered
	var fm_area := 600.0
	var s: float = minf(avail_w / fm_area, avail_h / fm_area)
	var rect_w: float = fm_area * s
	var rect_h: float = fm_area * s
	var rx: float = (canvas_size.x - rect_w) * 0.5
	var ry: float = (canvas_size.y - rect_h) * 0.5
	_fm_canvas_rect = Rect2(rx, ry, rect_w, rect_h)


func _fm_offset_to_canvas(offset: Vector2) -> Vector2:
	# offset is relative to formation center, in pixels (-300..300 range maps to canvas rect)
	var center: Vector2 = _fm_canvas_rect.position + _fm_canvas_rect.size * 0.5
	var scale: float = _fm_canvas_rect.size.x / 600.0
	return center + offset * scale


func _fm_canvas_to_offset(canvas_pos: Vector2) -> Vector2:
	var center: Vector2 = _fm_canvas_rect.position + _fm_canvas_rect.size * 0.5
	var scale: float = _fm_canvas_rect.size.x / 600.0
	return (canvas_pos - center) / scale


func _fm_snap_offset(offset: Vector2) -> Vector2:
	var g: float = _fm_grid_size
	return Vector2(roundf(offset.x / g) * g, roundf(offset.y / g) * g)


func _build_fm_right_panel(parent: HSplitContainer) -> void:
	_fm_right_panel = PanelContainer.new()
	_fm_right_panel.custom_minimum_size.x = RIGHT_PANEL_W
	_fm_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_fm_right_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(_fm_right_panel)
	_rebuild_fm_right_panel()


func _rebuild_fm_right_panel() -> void:
	for child in _fm_right_panel.get_children():
		_fm_right_panel.remove_child(child)
		child.queue_free()
	_fm_name_edit = null
	_fm_ship_dropdown = null

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	_fm_right_panel.add_child(vbox)

	var header := Label.new()
	header.text = "PROPERTIES"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(header, "header")
	vbox.add_child(header)

	if not _selected_formation:
		var hint := Label.new()
		hint.text = "No formation selected"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(hint)
		return

	# Name
	var name_label := Label.new()
	name_label.text = "NAME"
	ThemeManager.apply_text_glow(name_label, "body")
	vbox.add_child(name_label)

	_fm_name_edit = LineEdit.new()
	_fm_name_edit.text = _selected_formation.display_name
	_fm_name_edit.text_changed.connect(_on_fm_name_changed)
	vbox.add_child(_fm_name_edit)

	# Slot count
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var info := Label.new()
	info.text = str(_selected_formation.slots.size()) + " slots"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(info)

	# Grid size
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var grid_label := Label.new()
	grid_label.text = "GRID SIZE"
	ThemeManager.apply_text_glow(grid_label, "body")
	vbox.add_child(grid_label)

	var grid_box := HBoxContainer.new()
	grid_box.add_theme_constant_override("separation", 4)
	vbox.add_child(grid_box)
	for gs in [20.0, 40.0, 80.0]:
		var btn := Button.new()
		btn.text = str(int(gs))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gs_val: float = gs
		btn.pressed.connect(func() -> void:
			_fm_grid_size = gs_val
			_rebuild_fm_right_panel()
			_fm_canvas.queue_redraw()
		)
		ThemeManager.apply_button_style(btn)
		if absf(_fm_grid_size - gs) < 0.1:
			btn.modulate = Color(1.3, 1.3, 1.6)
		else:
			btn.modulate = Color(0.6, 0.6, 0.7)
		grid_box.add_child(btn)

	# Selected slot ship_id
	if _fm_selected_slots.size() > 0:
		var sep3 := HSeparator.new()
		vbox.add_child(sep3)

		var ship_label := Label.new()
		ship_label.text = "SLOT SHIP"
		ThemeManager.apply_text_glow(ship_label, "body")
		vbox.add_child(ship_label)

		_fm_ship_dropdown = OptionButton.new()
		var enemy_ships: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
		var current_ship_id: String = _selected_formation.get_slot_ship_id(_fm_selected_slots[0])
		var select_idx := 0
		for i in range(enemy_ships.size()):
			var ship: ShipData = enemy_ships[i]
			var label: String = ship.display_name if ship.display_name != "" else ship.id
			_fm_ship_dropdown.add_item(label, i)
			_fm_ship_dropdown.set_item_metadata(i, ship.id)
			if ship.id == current_ship_id:
				select_idx = i
		if enemy_ships.size() > 0:
			_fm_ship_dropdown.select(select_idx)
		_fm_ship_dropdown.item_selected.connect(_on_fm_ship_selected)
		vbox.add_child(_fm_ship_dropdown)


# ── Formation data operations ─────────────────────────────────

func _load_all_formations() -> void:
	_all_formations = FormationDataManager.load_all()
	_rebuild_fm_list()


func _rebuild_fm_list() -> void:
	for child in _fm_list_vbox.get_children():
		_fm_list_vbox.remove_child(child)
		child.queue_free()
	_fm_buttons.clear()

	for fm in _all_formations:
		var btn := Button.new()
		btn.text = fm.display_name if fm.display_name != "" else fm.id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fm_ref: FormationData = fm
		btn.pressed.connect(func() -> void: _select_formation(fm_ref))
		ThemeManager.apply_button_style(btn)
		_fm_list_vbox.add_child(btn)
		_fm_buttons.append(btn)

	_highlight_fm_selected_button()


func _highlight_fm_selected_button() -> void:
	for i in range(_fm_buttons.size()):
		if i < _all_formations.size() and _all_formations[i] == _selected_formation:
			_fm_buttons[i].modulate = Color(1.2, 1.2, 1.5)
		else:
			_fm_buttons[i].modulate = Color.WHITE


func _select_formation(fm: FormationData) -> void:
	_selected_formation = fm
	_fm_selected_slots.clear()
	_fm_dragging = false
	_rebuild_fm_right_panel()
	_rebuild_fm_list()
	_fm_canvas.queue_redraw()


func _save_current_formation() -> void:
	if _selected_formation:
		FormationDataManager.save(_selected_formation.id, _selected_formation.to_dict())


func _on_new_formation() -> void:
	var new_id: String = FormationDataManager.generate_id("formation")
	var data: Dictionary = {
		"id": new_id,
		"display_name": "New Formation",
		"slots": [],
	}
	FormationDataManager.save(new_id, data)
	_load_all_formations()
	for fm in _all_formations:
		if fm.id == new_id:
			_select_formation(fm)
			break


func _on_dupe_formation() -> void:
	if not _selected_formation:
		return
	var new_id: String = FormationDataManager.generate_id("formation")
	var data: Dictionary = _selected_formation.to_dict()
	data["id"] = new_id
	data["display_name"] = _selected_formation.display_name + " Copy"
	FormationDataManager.save(new_id, data)
	_load_all_formations()
	for fm in _all_formations:
		if fm.id == new_id:
			_select_formation(fm)
			break


func _on_delete_formation() -> void:
	if not _selected_formation:
		return
	FormationDataManager.delete(_selected_formation.id)
	_selected_formation = null
	_load_all_formations()
	if _all_formations.size() > 0:
		_select_formation(_all_formations[0])
	else:
		_rebuild_fm_right_panel()
		_fm_canvas.queue_redraw()


func _on_fm_name_changed(new_text: String) -> void:
	if _selected_formation:
		_selected_formation.display_name = new_text
		_save_current_formation()
		_rebuild_fm_list()


func _on_fm_ship_selected(index: int) -> void:
	if not _selected_formation or not _fm_ship_dropdown:
		return
	var ship_id: String = str(_fm_ship_dropdown.get_item_metadata(index))
	for slot_idx in _fm_selected_slots:
		if slot_idx < _selected_formation.slots.size():
			_selected_formation.slots[slot_idx]["ship_id"] = ship_id
	_save_current_formation()
	_fm_canvas.queue_redraw()


# ── Formation canvas input ────────────────────────────────────

func _handle_fm_canvas_input(event: InputEvent) -> void:
	if not _selected_formation:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_fm_canvas_left_click(mb.position, mb.shift_pressed)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_fm_canvas_right_click(mb.position)
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT and _fm_dragging:
				_fm_dragging = false
				_save_current_formation()
				_rebuild_fm_right_panel()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _fm_dragging:
			_fm_canvas_drag(mm.position)


func _fm_canvas_left_click(pos: Vector2, shift_held: bool) -> void:
	# Check slot hit
	for i in range(_selected_formation.slots.size()):
		var slot_canvas: Vector2 = _fm_offset_to_canvas(_selected_formation.get_slot_offset(i))
		if pos.distance_to(slot_canvas) < HIT_RADIUS:
			if shift_held:
				if i in _fm_selected_slots:
					_fm_selected_slots.erase(i)
				else:
					_fm_selected_slots.append(i)
			else:
				if i not in _fm_selected_slots:
					_fm_selected_slots = [i]
			# Start drag
			if i in _fm_selected_slots:
				_fm_dragging = true
				_fm_drag_start = pos
				_fm_drag_origins.clear()
				for idx in _fm_selected_slots:
					_fm_drag_origins.append(_selected_formation.get_slot_offset(idx))
			_rebuild_fm_right_panel()
			_fm_canvas.queue_redraw()
			return

	# Click empty space → place new slot (or deselect)
	if _fm_canvas_rect.has_point(pos):
		if shift_held:
			_fm_selected_slots.clear()
			_rebuild_fm_right_panel()
			_fm_canvas.queue_redraw()
			return
		var offset: Vector2 = _fm_canvas_to_offset(pos)
		offset = _fm_snap_offset(offset)
		_selected_formation.slots.append({
			"offset": [offset.x, offset.y],
			"ship_id": "",
		})
		_fm_selected_slots = [_selected_formation.slots.size() - 1]
		_save_current_formation()
		_rebuild_fm_right_panel()
		_fm_canvas.queue_redraw()
	else:
		_fm_selected_slots.clear()
		_rebuild_fm_right_panel()
		_fm_canvas.queue_redraw()


func _fm_canvas_right_click(pos: Vector2) -> void:
	for i in range(_selected_formation.slots.size()):
		var slot_canvas: Vector2 = _fm_offset_to_canvas(_selected_formation.get_slot_offset(i))
		if pos.distance_to(slot_canvas) < HIT_RADIUS:
			_selected_formation.slots.remove_at(i)
			var new_sel: Array[int] = []
			for idx in _fm_selected_slots:
				if idx < i:
					new_sel.append(idx)
				elif idx > i:
					new_sel.append(idx - 1)
			_fm_selected_slots = new_sel
			_save_current_formation()
			_rebuild_fm_right_panel()
			_fm_canvas.queue_redraw()
			return


func _fm_canvas_drag(pos: Vector2) -> void:
	var delta: Vector2 = _fm_canvas_to_offset(pos) - _fm_canvas_to_offset(_fm_drag_start)
	for j in range(_fm_selected_slots.size()):
		var idx: int = _fm_selected_slots[j]
		if idx < _selected_formation.slots.size():
			var new_off: Vector2 = _fm_snap_offset(_fm_drag_origins[j] + delta)
			_selected_formation.slots[idx]["offset"] = [new_off.x, new_off.y]
	_fm_canvas.queue_redraw()


# ── Formation canvas drawing (inner class) ────────────────────

class _FmCanvasDraw extends Control:
	var screen: Control

	func _draw() -> void:
		if not screen:
			return
		var s: Control = screen
		s._compute_fm_canvas_rect()
		var rect: Rect2 = s._fm_canvas_rect

		# Background
		draw_rect(rect, Color(0.08, 0.08, 0.14, 0.3), true)
		draw_rect(rect, Color(0.15, 0.15, 0.25, 0.5), false, 2.0)

		# Grid
		var grid_size: float = s._fm_grid_size
		var scale: float = rect.size.x / 600.0
		var grid_px: float = grid_size * scale
		var center: Vector2 = rect.position + rect.size * 0.5

		# Draw grid lines
		var half_count: int = int(300.0 / grid_size) + 1
		for i in range(-half_count, half_count + 1):
			var offset: float = float(i) * grid_px
			# Vertical
			var vx: float = center.x + offset
			if vx >= rect.position.x and vx <= rect.position.x + rect.size.x:
				var alpha: float = 0.15 if i != 0 else 0.4
				draw_line(Vector2(vx, rect.position.y), Vector2(vx, rect.position.y + rect.size.y), Color(0.3, 0.3, 0.5, alpha), 1.0)
			# Horizontal
			var vy: float = center.y + offset
			if vy >= rect.position.y and vy <= rect.position.y + rect.size.y:
				var alpha: float = 0.15 if i != 0 else 0.4
				draw_line(Vector2(rect.position.x, vy), Vector2(rect.position.x + rect.size.x, vy), Color(0.3, 0.3, 0.5, alpha), 1.0)

		# Center crosshair
		draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), Color(1.0, 1.0, 1.0, 0.4), 1.0)
		draw_line(center + Vector2(0, -12), center + Vector2(0, 12), Color(1.0, 1.0, 1.0, 0.4), 1.0)

		if not s._selected_formation:
			return

		# Draw slots
		var fm: FormationData = s._selected_formation
		for i in range(fm.slots.size()):
			var slot_canvas: Vector2 = s._fm_offset_to_canvas(fm.get_slot_offset(i))
			var is_selected: bool = (i in s._fm_selected_slots)

			# Diamond shape
			var sz: float = 10.0
			var points := PackedVector2Array([
				slot_canvas + Vector2(0, -sz),
				slot_canvas + Vector2(sz * 0.7, 0),
				slot_canvas + Vector2(0, sz),
				slot_canvas + Vector2(-sz * 0.7, 0),
			])

			# Color based on selection
			var color := Color(0.4, 0.85, 1.0)
			if is_selected:
				color = Color(1.0, 1.0, 0.3)
			# Glow
			for g in range(2, 0, -1):
				var t: float = float(g) / 2.0
				var glow_scale: float = 1.0 + t * 0.5
				var glow_pts := PackedVector2Array()
				for p in points:
					glow_pts.append(slot_canvas + (p - slot_canvas) * glow_scale)
				draw_colored_polygon(glow_pts, Color(color, (1.0 - t) * 0.2))
			draw_colored_polygon(points, color)

			# Index label
			var font: Font = ThemeDB.fallback_font
			draw_string(font, slot_canvas + Vector2(-3, -14), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.8, 0.8, 0.9, 0.7))

	func _gui_input(event: InputEvent) -> void:
		if screen:
			screen._handle_fm_canvas_input(event)
			if event is InputEventMouseButton:
				accept_event()
			elif event is InputEventMouseMotion and screen._fm_dragging:
				accept_event()


# ── Path canvas drawing (inner class) ─────────────────────────

class _CanvasDraw extends Control:
	const _CURVE_SAMPLES := 40
	const _WP_RADIUS := 8.0
	const _HANDLE_RADIUS := 5.0
	const _PREVIEW_DOT_RADIUS := 6.0

	var screen: Control  # Reference to EncountersScreen

	func _draw() -> void:
		if not screen:
			return
		var s: Control = screen
		s._compute_canvas_rect()

		# Screen boundary
		var rect: Rect2 = s._canvas_rect
		draw_rect(rect, Color(0.08, 0.08, 0.14, 0.3), true)
		draw_rect(rect, Color(0.15, 0.15, 0.25, 0.5), false, 2.0)

		if not s._selected_path:
			return

		var path: FlightPathData = s._selected_path
		var wp_count: int = path.waypoints.size()

		# Draw bezier segments
		if wp_count >= 2:
			for i in range(wp_count - 1):
				var seg_p0: Vector2 = path.get_waypoint_pos(i)
				var seg_p0_out: Vector2 = seg_p0 + path.get_waypoint_ctrl_out(i)
				var seg_p1: Vector2 = path.get_waypoint_pos(i + 1)
				var seg_p1_in: Vector2 = seg_p1 + path.get_waypoint_ctrl_in(i + 1)
				var points: PackedVector2Array = PackedVector2Array()
				for j in range(_CURVE_SAMPLES):
					var t: float = float(j) / float(_CURVE_SAMPLES - 1)
					var pt: Vector2 = seg_p0.bezier_interpolate(seg_p0_out, seg_p1_in, seg_p1, t)
					points.append(s._screen_to_canvas(pt))

				draw_polyline(points, Color(0.3, 0.8, 1.0, 0.8), 2.0, true)

		# Draw direction arrows along segments
		if wp_count >= 2:
			for i in range(wp_count - 1):
				var sp0: Vector2 = path.get_waypoint_pos(i)
				var sp0_out: Vector2 = sp0 + path.get_waypoint_ctrl_out(i)
				var sp1: Vector2 = path.get_waypoint_pos(i + 1)
				var sp1_in: Vector2 = sp1 + path.get_waypoint_ctrl_in(i + 1)
				var mid: Vector2 = sp0.bezier_interpolate(sp0_out, sp1_in, sp1, 0.5)
				var mid_next: Vector2 = sp0.bezier_interpolate(sp0_out, sp1_in, sp1, 0.52)
				var dir: Vector2 = (mid_next - mid).normalized()
				var arrow_pos: Vector2 = s._screen_to_canvas(mid)
				var arrow_size := 8.0
				var perp := Vector2(-dir.y, dir.x)
				var tip: Vector2 = arrow_pos + dir * arrow_size
				var left_pt: Vector2 = arrow_pos - dir * arrow_size * 0.5 + perp * arrow_size * 0.5
				var right_pt: Vector2 = arrow_pos - dir * arrow_size * 0.5 - perp * arrow_size * 0.5
				draw_colored_polygon(
					PackedVector2Array([tip, left_pt, right_pt]),
					Color(0.3, 0.8, 1.0, 0.6)
				)

		# Draw control handles
		# In CURVE mode: show handles on ALL waypoints so you can see the full picture.
		# In SELECT mode: show handles on selected waypoints only.
		var show_all_handles: bool = (s._active_tool == 2)  # Tool.CURVE
		for i in range(wp_count):
			var is_selected: bool = (i in s._selected_wps)
			var show: bool = show_all_handles or is_selected
			if not show:
				continue
			var wp_pos: Vector2 = path.get_waypoint_pos(i)
			var wp_canvas: Vector2 = s._screen_to_canvas(wp_pos)
			var ci: Vector2 = path.get_waypoint_ctrl_in(i)
			var co: Vector2 = path.get_waypoint_ctrl_out(i)
			var alpha: float = 1.0 if is_selected else 0.4

			var ci_canvas: Vector2 = s._screen_to_canvas(wp_pos + ci)
			draw_line(wp_canvas, ci_canvas, Color(1.0, 0.4, 0.4, 0.7 * alpha), 1.0)
			draw_circle(ci_canvas, _HANDLE_RADIUS, Color(1.0, 0.3, 0.3, 0.9 * alpha))

			var co_canvas: Vector2 = s._screen_to_canvas(wp_pos + co)
			draw_line(wp_canvas, co_canvas, Color(0.3, 1.0, 0.3, 0.7 * alpha), 1.0)
			draw_circle(co_canvas, _HANDLE_RADIUS, Color(0.3, 1.0, 0.3, 0.9 * alpha))

		# Draw waypoints
		for i in range(wp_count):
			var wp_canvas: Vector2 = s._screen_to_canvas(path.get_waypoint_pos(i))
			var color := Color(0.4, 0.85, 1.0)
			if i in s._selected_wps:
				color = Color(1.0, 1.0, 0.3)
			draw_circle(wp_canvas, _WP_RADIUS, color)
			# Index label
			var font: Font = ThemeDB.fallback_font
			draw_string(font, wp_canvas + Vector2(-3, -12), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.8, 0.8, 0.9, 0.7))

		# ARC tool ghost preview
		if s._active_tool == 3 and s._arc_hovering:  # Tool.ARC
			var arc_pts: PackedVector2Array = s._compute_arc_preview_points()
			if arc_pts.size() >= 2:
				var center_screen: Vector2 = s._canvas_to_screen(s._arc_preview_pos)
				var transformed := PackedVector2Array()
				for pt in arc_pts:
					transformed.append(s._screen_to_canvas(pt + center_screen))
				draw_polyline(transformed, Color(0.4, 1.0, 0.6, 0.4), 2.0, true)

				# Draw waypoint dots — first=green, last=red, middle=dim
				var n: int = s._arc_points
				var arc_rad_val: float = deg_to_rad(s._arc_angle_deg)
				var start_rad_val: float = deg_to_rad(s._arc_start_deg)
				var is_full: bool = absf(s._arc_angle_deg - 360.0) < 0.01
				var first_canvas := Vector2.ZERO
				var last_canvas := Vector2.ZERO
				for i in range(n):
					var t_val: float = float(i) / float(n) if is_full else float(i) / float(n - 1)
					var a: float = start_rad_val + t_val * arc_rad_val
					var dot_pos: Vector2 = center_screen + Vector2(cos(a), sin(a)) * s._arc_radius
					var dot_canvas: Vector2 = s._screen_to_canvas(dot_pos)
					if i == 0:
						first_canvas = dot_canvas
						draw_circle(dot_canvas, 6.0, Color(0.2, 1.0, 0.3, 0.8))
						# "S" label for start
						var fnt: Font = ThemeDB.fallback_font
						draw_string(fnt, dot_canvas + Vector2(-4, -10), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.2, 1.0, 0.3, 0.9))
					elif i == n - 1:
						last_canvas = dot_canvas
						draw_circle(dot_canvas, 6.0, Color(1.0, 0.3, 0.2, 0.8))
						# "E" label for end
						var fnt2: Font = ThemeDB.fallback_font
						draw_string(fnt2, dot_canvas + Vector2(-4, -10), "E", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1.0, 0.3, 0.2, 0.9))
					else:
						draw_circle(dot_canvas, 4.0, Color(0.4, 1.0, 0.6, 0.5))

				# Draw dashed gap line between last and first waypoint
				if is_full and first_canvas != Vector2.ZERO and last_canvas != Vector2.ZERO:
					var gap_len: float = first_canvas.distance_to(last_canvas)
					var dash_size := 6.0
					var gap_dir: Vector2 = (first_canvas - last_canvas).normalized()
					var steps: int = maxi(int(gap_len / dash_size), 1)
					for i in range(0, steps, 2):
						var a_pt: Vector2 = last_canvas + gap_dir * dash_size * float(i)
						var b_pt: Vector2 = last_canvas + gap_dir * dash_size * float(mini(i + 1, steps))
						draw_line(a_pt, b_pt, Color(1.0, 0.6, 0.2, 0.4), 1.5)

		# Preview ship/dot
		if s._previewing and s._preview_curve and s._preview_curve.point_count >= 2:
			var total_len: float = s._preview_curve.get_baked_length()
			if total_len > 0.0:
				var clamped: float = clampf(s._preview_progress, 0.0, total_len)
				var pos: Vector2 = s._preview_curve.sample_baked(clamped)
				var pos_canvas: Vector2 = s._screen_to_canvas(pos)

				draw_circle(pos_canvas, _PREVIEW_DOT_RADIUS, Color(1.0, 0.5, 0.0, 1.0))
				draw_arc(pos_canvas, _PREVIEW_DOT_RADIUS + 3, 0, TAU, 24, Color(1.0, 0.5, 0.0, 0.4), 2.0)


	func _gui_input(event: InputEvent) -> void:
		if screen:
			screen._handle_canvas_input(event)
			if event is InputEventMouseButton:
				accept_event()
			elif event is InputEventMouseMotion and screen._dragging:
				accept_event()
