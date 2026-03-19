extends Control
## Level editor screen — compose levels by placing encounters on a scrollable vertical map.
## Left panel: level list + properties. Center: scrollable map. Right panel: encounter properties.

const LEFT_PANEL_W := 240.0
const RIGHT_PANEL_W := 220.0
const SCREEN_W := 1920.0
const MAP_MARGIN := 60.0  # Margin on each side of the map strip within the canvas
const ENCOUNTER_HIT_RADIUS := 40.0
const GRID_SPACING := 500.0  # Horizontal grid lines every N pixels of level space

var _vhs_overlay: ColorRect
var _bg: ColorRect

# Level list
var _all_levels: Array[LevelData] = []
var _selected_level: LevelData = null
var _level_buttons: Array[Button] = []
var _level_list_vbox: VBoxContainer

# Level properties (left panel)
var _name_edit: LineEdit
var _bpm_spin: SpinBox
var _speed_spin: SpinBox
var _length_spin: SpinBox

# Map canvas
var _map_canvas: Control
var _scroll_offset: float = 0.0  # Current scroll position in level-space pixels
var _map_dragging: bool = false
var _map_drag_start_y: float = 0.0
var _map_drag_scroll_start: float = 0.0

# Encounter state
var _selected_encounter_idx: int = -1
var _encounter_dragging: bool = false
var _encounter_drag_start: Vector2 = Vector2.ZERO
var _encounter_drag_origin_y: float = 0.0
var _encounter_drag_origin_x: float = 0.0

# Right panel
var _right_panel: PanelContainer
var _right_panel_vbox: VBoxContainer  # Persistent outer container — never rebuilt
var _right_content: VBoxContainer     # Inner content — rebuilt on selection change

# Cached data for dropdowns
var _cached_path_ids: Array[String] = []
var _cached_path_names: Array[String] = []
var _cached_formation_ids: Array[String] = []
var _cached_formation_names: Array[String] = []
var _cached_ship_ids: Array[String] = []
var _cached_ship_names: Array[String] = []
var _ship_id_to_name: Dictionary = {}
var _formation_id_to_name: Dictionary = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE

	_bg = $Background
	ThemeManager.apply_grid_background(_bg)

	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_cache_dropdown_data()

	var outer_split := HSplitContainer.new()
	outer_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer_split)

	_build_left_panel(outer_split)

	var inner_split := HSplitContainer.new()
	inner_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_split.add_child(inner_split)

	_build_map_canvas(inner_split)
	_build_right_panel(inner_split)

	_load_all_levels()
	if _all_levels.size() > 0:
		_select_level(_all_levels[0])


func _cache_dropdown_data() -> void:
	_cached_path_ids.clear()
	_cached_path_names.clear()
	var paths: Array[FlightPathData] = FlightPathDataManager.load_all()
	for fp in paths:
		_cached_path_ids.append(fp.id)
		_cached_path_names.append(fp.display_name if fp.display_name != "" else fp.id)

	_cached_formation_ids.clear()
	_cached_formation_names.clear()
	_formation_id_to_name.clear()
	var formations: Array[FormationData] = FormationDataManager.load_all()
	for fm in formations:
		_cached_formation_ids.append(fm.id)
		var fm_name: String = fm.display_name if fm.display_name != "" else fm.id
		_cached_formation_names.append(fm_name)
		_formation_id_to_name[fm.id] = fm_name

	_cached_ship_ids.clear()
	_cached_ship_names.clear()
	_ship_id_to_name.clear()
	var ships: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	for s in ships:
		_cached_ship_ids.append(s.id)
		var name: String = s.display_name if s.display_name != "" else s.id
		_cached_ship_names.append(name)
		_ship_id_to_name[s.id] = name


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")
		return


func _is_text_input_focused() -> bool:
	var vp: Viewport = get_viewport()
	if not vp:
		return false
	var focused: Control = vp.gui_get_focus_owner()
	return focused is LineEdit or focused is SpinBox


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


# ── Left panel ─────────────────────────────────────────────────

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
	header.text = "LEVELS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(header, "header")
	vbox.add_child(header)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	vbox.add_child(spacer)

	# Scrollable level list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 150
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_level_list_vbox = VBoxContainer.new()
	_level_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_level_list_vbox)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_box)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new_level)
	ThemeManager.apply_button_style(new_btn)
	btn_box.add_child(new_btn)

	var dupe_btn := Button.new()
	dupe_btn.text = "DUPE"
	dupe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dupe_btn.pressed.connect(_on_dupe_level)
	ThemeManager.apply_button_style(dupe_btn)
	btn_box.add_child(dupe_btn)

	var del_btn := Button.new()
	del_btn.text = "DEL"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_level)
	ThemeManager.apply_button_style(del_btn)
	btn_box.add_child(del_btn)

	# Level properties section
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var props_header := Label.new()
	props_header.text = "LEVEL PROPS"
	props_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(props_header, "header")
	vbox.add_child(props_header)

	# Name
	var name_label := Label.new()
	name_label.text = "NAME"
	ThemeManager.apply_text_glow(name_label, "body")
	vbox.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(_on_level_name_changed)
	vbox.add_child(_name_edit)

	# BPM
	var bpm_label := Label.new()
	bpm_label.text = "BPM"
	ThemeManager.apply_text_glow(bpm_label, "body")
	vbox.add_child(bpm_label)
	_bpm_spin = SpinBox.new()
	_bpm_spin.min_value = 60
	_bpm_spin.max_value = 200
	_bpm_spin.step = 1
	_bpm_spin.value = 110
	_bpm_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level:
			_selected_level.bpm = v
			_save_current_level()
	)
	vbox.add_child(_bpm_spin)

	# Scroll Speed
	var speed_label := Label.new()
	speed_label.text = "SCROLL SPEED"
	ThemeManager.apply_text_glow(speed_label, "body")
	vbox.add_child(speed_label)
	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 20
	_speed_spin.max_value = 300
	_speed_spin.step = 10
	_speed_spin.value = 80
	_speed_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level:
			_selected_level.scroll_speed = v
			_save_current_level()
	)
	vbox.add_child(_speed_spin)

	# Level Length
	var len_label := Label.new()
	len_label.text = "LENGTH (px)"
	ThemeManager.apply_text_glow(len_label, "body")
	vbox.add_child(len_label)
	_length_spin = SpinBox.new()
	_length_spin.min_value = 2000
	_length_spin.max_value = 50000
	_length_spin.step = 500
	_length_spin.value = 10000
	_length_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level:
			_selected_level.level_length = v
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	vbox.add_child(_length_spin)

	# Play button
	var play_sep := HSeparator.new()
	vbox.add_child(play_sep)

	var play_btn := Button.new()
	play_btn.text = "PLAY LEVEL"
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_play_level)
	ThemeManager.apply_button_style(play_btn)
	vbox.add_child(play_btn)


func _on_play_level() -> void:
	if not _selected_level:
		return
	_save_current_level()
	GameState.current_level_id = _selected_level.id
	GameState.return_scene = "res://scenes/ui/level_editor.tscn"
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _rebuild_level_list() -> void:
	for child in _level_list_vbox.get_children():
		_level_list_vbox.remove_child(child)
		child.queue_free()
	_level_buttons.clear()

	for lv in _all_levels:
		var btn := Button.new()
		btn.text = lv.display_name if lv.display_name != "" else lv.id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lv_ref: LevelData = lv
		btn.pressed.connect(func() -> void: _select_level(lv_ref))
		ThemeManager.apply_button_style(btn)
		_level_list_vbox.add_child(btn)
		_level_buttons.append(btn)

	_highlight_selected_level()


func _highlight_selected_level() -> void:
	for i in range(_level_buttons.size()):
		if i < _all_levels.size() and _all_levels[i] == _selected_level:
			_level_buttons[i].modulate = Color(1.2, 1.2, 1.5)
		else:
			_level_buttons[i].modulate = Color.WHITE


func _update_level_props_ui() -> void:
	if _selected_level:
		_name_edit.text = _selected_level.display_name
		_bpm_spin.value = _selected_level.bpm
		_speed_spin.value = _selected_level.scroll_speed
		_length_spin.value = _selected_level.level_length
	else:
		_name_edit.text = ""
		_bpm_spin.value = 110
		_speed_spin.value = 80
		_length_spin.value = 10000


# ── Map canvas ─────────────────────────────────────────────────

func _build_map_canvas(parent: HSplitContainer) -> void:
	var canvas_container := Control.new()
	canvas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_container.clip_contents = true
	canvas_container.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(canvas_container)

	var drawer := _MapCanvasDraw.new()
	drawer.screen = self
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_container.add_child(drawer)
	_map_canvas = drawer


func _get_map_rect() -> Rect2:
	# The map strip fills most of the canvas width with margins on each side
	var canvas_size: Vector2 = _map_canvas.size
	var map_w: float = canvas_size.x - MAP_MARGIN * 2.0
	return Rect2(MAP_MARGIN, 0, map_w, canvas_size.y)


func _level_y_to_canvas_y(level_y: float) -> float:
	# Convert level-space Y (trigger_y) to canvas Y, accounting for scroll.
	# Flipped: high trigger_y (late encounters) at top, low trigger_y (early) at bottom,
	# matching the player's bottom-to-top travel direction.
	if not _selected_level:
		return 0.0
	var canvas_h: float = _map_canvas.size.y
	var level_len: float = _selected_level.level_length
	var scale: float = canvas_h / maxf(level_len, 1.0) * 3.0  # Show ~1/3 of level at a time
	return canvas_h - (level_y - _scroll_offset) * scale


func _canvas_y_to_level_y(canvas_y: float) -> float:
	if not _selected_level:
		return 0.0
	var canvas_h: float = _map_canvas.size.y
	var level_len: float = _selected_level.level_length
	var scale: float = canvas_h / maxf(level_len, 1.0) * 3.0
	return (canvas_h - canvas_y) / scale + _scroll_offset


func _level_x_to_canvas_x(x_offset: float) -> float:
	var map_rect: Rect2 = _get_map_rect()
	# x_offset is relative to screen center (960). Map center = map_rect center.
	var map_center_x: float = map_rect.position.x + map_rect.size.x * 0.5
	var scale: float = map_rect.size.x / SCREEN_W
	return map_center_x + x_offset * scale


func _canvas_x_to_level_x(canvas_x: float) -> float:
	var map_rect: Rect2 = _get_map_rect()
	var map_center_x: float = map_rect.position.x + map_rect.size.x * 0.5
	var scale: float = map_rect.size.x / SCREEN_W
	return (canvas_x - map_center_x) / scale


func _handle_map_input(event: InputEvent) -> void:
	if not _selected_level:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_map_left_click(mb.position)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_map_right_click(mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				var step: float = 2500.0 if mb.shift_pressed else 500.0
				_scroll_offset = minf(_scroll_offset + step, maxf(_selected_level.level_length - 500.0, 0.0))
				_map_canvas.queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var step: float = 2500.0 if mb.shift_pressed else 500.0
				_scroll_offset = maxf(_scroll_offset - step, 0.0)
				_map_canvas.queue_redraw()
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if _encounter_dragging:
					_encounter_dragging = false
					_save_current_level()
					_rebuild_right_panel_content()
				elif _map_dragging:
					_map_dragging = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _encounter_dragging and _selected_encounter_idx >= 0:
			var enc: Dictionary = _selected_level.encounters[_selected_encounter_idx]
			var delta_y: float = _canvas_y_to_level_y(mm.position.y) - _canvas_y_to_level_y(_encounter_drag_start.y)
			enc["trigger_y"] = maxf(_encounter_drag_origin_y + delta_y, 0.0)
			var delta_x: float = _canvas_x_to_level_x(mm.position.x) - _canvas_x_to_level_x(_encounter_drag_start.x)
			enc["x_offset"] = _encounter_drag_origin_x + delta_x
			_map_canvas.queue_redraw()
		elif _map_dragging:
			var delta: float = mm.position.y - _map_drag_start_y
			var canvas_h: float = _map_canvas.size.y
			var level_len: float = _selected_level.level_length
			var scale: float = canvas_h / maxf(level_len, 1.0) * 3.0
			_scroll_offset = clampf(_map_drag_scroll_start + delta / scale, 0.0, maxf(level_len - 500.0, 0.0))
			_map_canvas.queue_redraw()


func _map_left_click(pos: Vector2) -> void:
	# Check encounter hit
	for i in range(_selected_level.encounters.size()):
		var enc: Dictionary = _selected_level.encounters[i]
		var enc_canvas_y: float = _level_y_to_canvas_y(float(enc["trigger_y"]))
		var enc_canvas_x: float = _level_x_to_canvas_x(float(enc["x_offset"]))
		if Vector2(enc_canvas_x, enc_canvas_y).distance_to(pos) < ENCOUNTER_HIT_RADIUS:
			_selected_encounter_idx = i
			_encounter_dragging = true
			_encounter_drag_start = pos
			_encounter_drag_origin_y = float(enc["trigger_y"])
			_encounter_drag_origin_x = float(enc["x_offset"])
			_rebuild_right_panel_content()
			_map_canvas.queue_redraw()
			return

	# Click empty space on map → place new encounter
	var map_rect: Rect2 = _get_map_rect()
	if map_rect.has_point(pos):
		var trigger_y: float = _canvas_y_to_level_y(pos.y)
		var x_offset: float = _canvas_x_to_level_x(pos.x)
		if trigger_y >= 0.0 and trigger_y <= _selected_level.level_length:
			var enc: Dictionary = {
				"path_id": _cached_path_ids[0] if _cached_path_ids.size() > 0 else "",
				"formation_id": "",
				"ship_id": _cached_ship_ids[0] if _cached_ship_ids.size() > 0 else "enemy_1",
				"speed": 200.0,
				"count": 1,
				"spacing": 200.0,
				"trigger_y": trigger_y,
				"x_offset": x_offset,
			}
			_selected_level.encounters.append(enc)
			_selected_encounter_idx = _selected_level.encounters.size() - 1
			_save_current_level()
			_rebuild_right_panel_content()
			_map_canvas.queue_redraw()
			return

	# Click outside map → start drag-scroll or deselect
	_selected_encounter_idx = -1
	_map_dragging = true
	_map_drag_start_y = pos.y
	_map_drag_scroll_start = _scroll_offset
	_rebuild_right_panel_content()
	_map_canvas.queue_redraw()


func _map_right_click(pos: Vector2) -> void:
	# Right-click encounter to delete
	for i in range(_selected_level.encounters.size()):
		var enc: Dictionary = _selected_level.encounters[i]
		var enc_canvas_y: float = _level_y_to_canvas_y(float(enc["trigger_y"]))
		var enc_canvas_x: float = _level_x_to_canvas_x(float(enc["x_offset"]))
		if Vector2(enc_canvas_x, enc_canvas_y).distance_to(pos) < ENCOUNTER_HIT_RADIUS:
			_selected_level.encounters.remove_at(i)
			if _selected_encounter_idx == i:
				_selected_encounter_idx = -1
			elif _selected_encounter_idx > i:
				_selected_encounter_idx -= 1
			_save_current_level()
			_rebuild_right_panel_content()
			_map_canvas.queue_redraw()
			return


# ── Right panel: encounter properties ─────────────────────────

func _build_right_panel(parent: HSplitContainer) -> void:
	_right_panel = PanelContainer.new()
	_right_panel.custom_minimum_size.x = RIGHT_PANEL_W
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_right_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(_right_panel)

	# Persistent outer vbox — never destroyed, anchors the panel width
	_right_panel_vbox = VBoxContainer.new()
	_right_panel_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel_vbox.custom_minimum_size.x = RIGHT_PANEL_W - 16
	_right_panel_vbox.add_theme_constant_override("separation", 6)
	_right_panel.add_child(_right_panel_vbox)

	var header := Label.new()
	header.text = "ENCOUNTER"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size.x = RIGHT_PANEL_W - 16
	ThemeManager.apply_text_glow(header, "header")
	_right_panel_vbox.add_child(header)

	_right_content = VBoxContainer.new()
	_right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_content.add_theme_constant_override("separation", 6)
	_right_panel_vbox.add_child(_right_content)

	_rebuild_right_panel_content()


func _rebuild_right_panel_content() -> void:
	for child in _right_content.get_children():
		_right_content.remove_child(child)
		child.queue_free()

	if not _selected_level or _selected_encounter_idx < 0 or _selected_encounter_idx >= _selected_level.encounters.size():
		var hint := Label.new()
		hint.text = "Click map to place"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_right_content.add_child(hint)
		return

	var enc: Dictionary = _selected_level.encounters[_selected_encounter_idx]
	var enc_idx: int = _selected_encounter_idx

	# Path dropdown
	var path_label := Label.new()
	path_label.text = "PATH"
	ThemeManager.apply_text_glow(path_label, "body")
	_right_content.add_child(path_label)

	var path_dropdown := OptionButton.new()
	var current_path_id: String = str(enc.get("path_id", ""))
	var path_select := 0
	for i in range(_cached_path_ids.size()):
		path_dropdown.add_item(_cached_path_names[i], i)
		path_dropdown.set_item_metadata(i, _cached_path_ids[i])
		if _cached_path_ids[i] == current_path_id:
			path_select = i
	if _cached_path_ids.size() > 0:
		path_dropdown.select(path_select)
	path_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["path_id"] = str(path_dropdown.get_item_metadata(idx))
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_right_content.add_child(path_dropdown)

	# Formation dropdown
	var sep1 := HSeparator.new()
	_right_content.add_child(sep1)

	var fm_label := Label.new()
	fm_label.text = "FORMATION"
	ThemeManager.apply_text_glow(fm_label, "body")
	_right_content.add_child(fm_label)

	var fm_dropdown := OptionButton.new()
	fm_dropdown.add_item("(none - single ship)", 0)
	fm_dropdown.set_item_metadata(0, "")
	var current_fm_id: String = str(enc.get("formation_id", ""))
	var fm_select := 0
	for i in range(_cached_formation_ids.size()):
		fm_dropdown.add_item(_cached_formation_names[i], i + 1)
		fm_dropdown.set_item_metadata(i + 1, _cached_formation_ids[i])
		if _cached_formation_ids[i] == current_fm_id:
			fm_select = i + 1
	fm_dropdown.select(fm_select)
	fm_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["formation_id"] = str(fm_dropdown.get_item_metadata(idx))
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_right_content.add_child(fm_dropdown)

	# Ship dropdown (for single-ship mode)
	var ship_label := Label.new()
	ship_label.text = "SHIP (single)"
	ThemeManager.apply_text_glow(ship_label, "body")
	_right_content.add_child(ship_label)

	var ship_dropdown := OptionButton.new()
	var current_ship_id: String = str(enc.get("ship_id", ""))
	var ship_select := 0
	for i in range(_cached_ship_ids.size()):
		ship_dropdown.add_item(_cached_ship_names[i], i)
		ship_dropdown.set_item_metadata(i, _cached_ship_ids[i])
		if _cached_ship_ids[i] == current_ship_id:
			ship_select = i
	if _cached_ship_ids.size() > 0:
		ship_dropdown.select(ship_select)
	ship_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["ship_id"] = str(ship_dropdown.get_item_metadata(idx))
			_save_current_level()
	)
	_right_content.add_child(ship_dropdown)

	# Speed
	var sep2 := HSeparator.new()
	_right_content.add_child(sep2)

	var speed_label := Label.new()
	speed_label.text = "SPEED"
	ThemeManager.apply_text_glow(speed_label, "body")
	_right_content.add_child(speed_label)
	var speed_spin := SpinBox.new()
	speed_spin.min_value = 50
	speed_spin.max_value = 1000
	speed_spin.step = 10
	speed_spin.value = float(enc.get("speed", 200.0))
	speed_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["speed"] = v
			_save_current_level()
	)
	_right_content.add_child(speed_spin)

	# Count
	var count_label := Label.new()
	count_label.text = "COUNT"
	ThemeManager.apply_text_glow(count_label, "body")
	_right_content.add_child(count_label)
	var count_spin := SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 20
	count_spin.step = 1
	count_spin.value = int(enc.get("count", 1))
	count_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["count"] = int(v)
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_right_content.add_child(count_spin)

	# Spacing
	var spacing_label := Label.new()
	spacing_label.text = "SPACING"
	ThemeManager.apply_text_glow(spacing_label, "body")
	_right_content.add_child(spacing_label)
	var spacing_spin := SpinBox.new()
	spacing_spin.min_value = 50
	spacing_spin.max_value = 2000
	spacing_spin.step = 50
	spacing_spin.value = float(enc.get("spacing", 200.0))
	spacing_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["spacing"] = v
			_save_current_level()
	)
	_right_content.add_child(spacing_spin)

	# Action buttons
	var sep3 := HSeparator.new()
	_right_content.add_child(sep3)

	var center_btn := Button.new()
	center_btn.text = "CENTER"
	center_btn.pressed.connect(func() -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters[enc_idx]["x_offset"] = 0.0
			_save_current_level()
			_rebuild_right_panel_content()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(center_btn)
	_right_content.add_child(center_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE ENCOUNTER"
	del_btn.pressed.connect(func() -> void:
		if _selected_level and enc_idx < _selected_level.encounters.size():
			_selected_level.encounters.remove_at(enc_idx)
			_selected_encounter_idx = -1
			_save_current_level()
			_rebuild_right_panel_content()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(del_btn)
	_right_content.add_child(del_btn)


# ── Data operations ────────────────────────────────────────────

func _load_all_levels() -> void:
	_all_levels = LevelDataManager.load_all()
	_rebuild_level_list()


func _select_level(lv: LevelData) -> void:
	_selected_level = lv
	_selected_encounter_idx = -1
	_scroll_offset = 0.0
	_update_level_props_ui()
	_rebuild_level_list()
	_rebuild_right_panel_content()
	_map_canvas.queue_redraw()


func _save_current_level() -> void:
	if _selected_level:
		LevelDataManager.save(_selected_level.id, _selected_level.to_dict())


func _on_new_level() -> void:
	var new_id: String = LevelDataManager.generate_id("level")
	var data: Dictionary = {
		"id": new_id,
		"display_name": "New Level",
		"bpm": 110.0,
		"scroll_speed": 80.0,
		"level_length": 10000.0,
		"encounters": [],
	}
	LevelDataManager.save(new_id, data)
	_load_all_levels()
	for lv in _all_levels:
		if lv.id == new_id:
			_select_level(lv)
			break


func _on_dupe_level() -> void:
	if not _selected_level:
		return
	var new_id: String = LevelDataManager.generate_id("level")
	var data: Dictionary = _selected_level.to_dict()
	data["id"] = new_id
	data["display_name"] = _selected_level.display_name + " Copy"
	LevelDataManager.save(new_id, data)
	_load_all_levels()
	for lv in _all_levels:
		if lv.id == new_id:
			_select_level(lv)
			break


func _on_delete_level() -> void:
	if not _selected_level:
		return
	LevelDataManager.delete(_selected_level.id)
	_selected_level = null
	_load_all_levels()
	if _all_levels.size() > 0:
		_select_level(_all_levels[0])
	else:
		_update_level_props_ui()
		_rebuild_right_panel_content()
		_map_canvas.queue_redraw()


func _on_level_name_changed(new_text: String) -> void:
	if _selected_level:
		_selected_level.display_name = new_text
		_save_current_level()
		_rebuild_level_list()


# ── Map canvas drawing (inner class) ──────────────────────────

class _MapCanvasDraw extends Control:
	var screen: Control

	func _draw() -> void:
		if not screen:
			return
		var s: Control = screen

		# Map background strip
		var map_rect: Rect2 = s._get_map_rect()
		draw_rect(map_rect, Color(0.06, 0.06, 0.12, 0.5), true)
		draw_rect(map_rect, Color(0.15, 0.15, 0.25, 0.5), false, 2.0)

		if not s._selected_level:
			return

		var level: LevelData = s._selected_level

		# Grid lines + Y labels
		var grid_y: float = 0.0
		while grid_y <= level.level_length:
			var cy: float = s._level_y_to_canvas_y(grid_y)
			if cy >= -20 and cy <= size.y + 20:
				draw_line(Vector2(map_rect.position.x, cy), Vector2(map_rect.position.x + map_rect.size.x, cy), Color(0.3, 0.3, 0.5, 0.2), 1.0)
				var font: Font = ThemeDB.fallback_font
				draw_string(font, Vector2(map_rect.position.x + 4, cy - 3), str(int(grid_y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.4, 0.6, 0.6))
			grid_y += 500.0

		# Scroll position indicator (narrow bar on left edge)
		var canvas_h: float = size.y
		var scroll_ratio: float = s._scroll_offset / maxf(level.level_length, 1.0)
		var view_ratio: float = clampf(1.0 / 3.0, 0.05, 1.0)
		var bar_x: float = map_rect.position.x - 8
		var bar_h: float = canvas_h * view_ratio
		var bar_y: float = (1.0 - scroll_ratio) * (canvas_h - bar_h)
		draw_rect(Rect2(bar_x, bar_y, 4, bar_h), Color(0.4, 0.8, 1.0, 0.5), true)

		# Y position readout
		var font2: Font = ThemeDB.fallback_font
		draw_string(font2, Vector2(bar_x - 40, bar_y + bar_h * 0.5 + 4), str(int(s._scroll_offset)), HORIZONTAL_ALIGNMENT_RIGHT, 44, 10, Color(0.5, 0.7, 1.0, 0.7))

		# Draw encounter markers
		for i in range(level.encounters.size()):
			var enc: Dictionary = level.encounters[i]
			var cy: float = s._level_y_to_canvas_y(float(enc["trigger_y"]))
			var cx: float = s._level_x_to_canvas_x(float(enc["x_offset"]))

			if cy < -30 or cy > canvas_h + 30:
				continue

			var is_selected: bool = (i == s._selected_encounter_idx)
			var color := Color(1.0, 0.5, 0.2) if is_selected else Color(0.4, 0.8, 1.0)

			# Diamond marker (doubled size)
			var sz: float = 16.0
			var points := PackedVector2Array([
				Vector2(cx, cy - sz),
				Vector2(cx + sz * 0.7, cy),
				Vector2(cx, cy + sz),
				Vector2(cx - sz * 0.7, cy),
			])

			# Glow
			if is_selected:
				for g in range(3, 0, -1):
					var t: float = float(g) / 3.0
					var gscale: float = 1.0 + t * 0.8
					var gpts := PackedVector2Array()
					for p in points:
						gpts.append(Vector2(cx, cy) + (p - Vector2(cx, cy)) * gscale)
					draw_colored_polygon(gpts, Color(color, (1.0 - t) * 0.15))

			draw_colored_polygon(points, color)

			# Labels: ship name + count, then formation name in different color
			var fm_id: String = str(enc.get("formation_id", ""))
			var ship_id: String = str(enc.get("ship_id", ""))
			var ship_name: String = s._ship_id_to_name.get(ship_id, ship_id)
			if ship_name == "":
				ship_name = "?"
			var count_val: int = int(enc.get("count", 1))
			var ship_text: String = ship_name
			if count_val > 1:
				ship_text += " x" + str(count_val)
			var font3: Font = ThemeDB.fallback_font
			var label_x: float = cx + sz * 0.7 + 6
			draw_string(font3, Vector2(label_x, cy + 4), ship_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.9))
			if fm_id != "":
				var fm_name: String = s._formation_id_to_name.get(fm_id, fm_id)
				var fm_color := Color(0.6, 1.0, 0.5, 0.8) if is_selected else Color(0.5, 0.9, 0.4, 0.7)
				draw_string(font3, Vector2(label_x, cy + 16), fm_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fm_color)


	func _gui_input(event: InputEvent) -> void:
		if screen:
			screen._handle_map_input(event)
			if event is InputEventMouseButton:
				accept_event()
			elif event is InputEventMouseMotion and (screen._encounter_dragging or screen._map_dragging):
				accept_event()
