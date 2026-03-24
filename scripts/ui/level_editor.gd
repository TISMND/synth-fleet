extends Control
## Level editor screen — compose levels by placing encounters on a scrollable vertical map.
## Left panel: level list + properties. Center: scrollable map. Right panel: encounter properties.

const LEFT_PANEL_W := 240.0
const RIGHT_PANEL_W := 220.0
const SCREEN_W := 1920.0
const MAP_MARGIN := 60.0  # Margin on each side of the map strip within the canvas
const ENCOUNTER_HIT_RADIUS := 40.0
const NEBULA_HIT_RADIUS := 50.0
const GRID_SPACING := 500.0  # Horizontal grid lines every N pixels of level space

var _vhs_overlay: ColorRect
var _bg: ColorRect

# Edit mode: "encounters" or "nebulas"
var _edit_mode: String = "encounters"

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
var _bg_shader_dropdown: OptionButton

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

# Nebula placement state
var _nebula_selected_idx: int = -1
var _nebula_dragging: bool = false
var _nebula_drag_start: Vector2 = Vector2.ZERO
var _nebula_drag_origin_y: float = 0.0
var _nebula_drag_origin_x: float = 0.0

# Doodad placement state
var _doodad_selected_idx: int = -1
var _doodad_dragging: bool = false
var _doodad_drag_start: Vector2 = Vector2.ZERO
var _doodad_drag_origin_y: float = 0.0
var _doodad_drag_origin_x: float = 0.0

# Right panel
var _right_panel: PanelContainer
var _right_panel_vbox: VBoxContainer  # Persistent outer container
var _enc_content: VBoxContainer       # Container for all encounter controls
var _enc_hint: Label                  # "Click map to place" hint
var _enc_path_dropdown: OptionButton
var _enc_fm_dropdown: OptionButton
var _enc_ship_dropdown: OptionButton
var _enc_speed_spin: SpinBox
var _enc_count_spin: SpinBox
var _enc_spacing_spin: SpinBox
var _enc_rotate_check: CheckButton
var _enc_melee_check: CheckButton
var _enc_turn_speed_label: Label
var _enc_turn_speed_spin: SpinBox
var _enc_weapons_active_check: CheckButton
var _enc_center_btn: Button
var _enc_delete_btn: Button

# Right panel — mode toggle + nebula controls
var _mode_toggle_box: HBoxContainer
var _mode_enc_btn: Button
var _mode_neb_btn: Button
var _mode_doodad_btn: Button
var _right_header: Label
var _neb_content: VBoxContainer
var _neb_hint: Label
var _neb_dropdown: OptionButton
var _neb_radius_spin: SpinBox
var _neb_center_btn: Button
var _neb_delete_btn: Button

# Right panel — doodad controls
var _doodad_content: VBoxContainer
var _doodad_hint: Label
var _doodad_type_dropdown: OptionButton
var _doodad_scale_spin: SpinBox
var _doodad_rot_spin: SpinBox
var _doodad_center_btn: Button
var _doodad_delete_btn: Button

# Flight speed + debug grids
var _flight_speed_spin: SpinBox
var _debug_deep_check: CheckButton
var _debug_bg_check: CheckButton
var _debug_fg_check: CheckButton

# Preview mode
var _preview_mode: bool = false
var _preview_toggle_btn: Button
var _preview_container: Control
var _preview_svc: SubViewportContainer
var _preview_viewport: SubViewport
var _preview_bg_rect: ColorRect
var _preview_doodad_layer: Node2D
var _preview_doodad_renderer: DoodadRenderer
var _preview_encounter_markers: Node2D
var _preview_scroll: float = 0.0  # level-space Y position being viewed

# Cached data for dropdowns
var _cached_path_ids: Array[String] = []
var _cached_path_names: Array[String] = []
var _cached_formation_ids: Array[String] = []
var _cached_formation_names: Array[String] = []
var _cached_ship_ids: Array[String] = []
var _cached_ship_names: Array[String] = []
var _ship_id_to_name: Dictionary = {}
var _formation_id_to_name: Dictionary = {}
var _path_id_to_name: Dictionary = {}
var _path_id_to_curve: Dictionary = {}  # path_id -> Curve2D

# Level filter for ship dropdown
var _enc_level_filter: OptionButton
var _cached_ships_by_level: Dictionary = {}  # level_id -> Array of {id, name}

# Clipboard for copy/paste
var _clipboard: Dictionary = {}  # Copied encounter or nebula dict

# Cached nebula data
var _cached_nebula_ids: Array[String] = []
var _cached_nebula_names: Array[String] = []
var _cached_nebula_colors: Dictionary = {}  # id -> Color


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE

	_bg = $Background
	# Background will be set by _select_level → _apply_editor_background()

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

	# Center panel holds both overview map and preview (only one visible at a time)
	var center_container := Control.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_container.clip_contents = true
	inner_split.add_child(center_container)

	_build_map_canvas(center_container)
	_build_preview_viewport(center_container)
	_build_right_panel(inner_split)

	_load_all_levels()
	# Restore previously edited level if returning from play/preview
	var restore_id: String = GameState.editing_level_id
	var restored := false
	if restore_id != "":
		for lv in _all_levels:
			if lv.id == restore_id:
				_select_level(lv)
				restored = true
				break
	if not restored and _all_levels.size() > 0:
		_select_level(_all_levels[0])


func _cache_dropdown_data() -> void:
	_cached_path_ids.clear()
	_cached_path_names.clear()
	_path_id_to_name.clear()
	_path_id_to_curve.clear()
	var paths: Array[FlightPathData] = FlightPathDataManager.load_all()
	for fp in paths:
		_cached_path_ids.append(fp.id)
		var fp_name: String = fp.display_name if fp.display_name != "" else fp.id
		_cached_path_names.append(fp_name)
		_path_id_to_name[fp.id] = fp_name
		var curve: Curve2D = fp.to_curve2d()
		if curve.point_count > 0:
			_path_id_to_curve[fp.id] = curve

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
	_cached_ships_by_level.clear()
	var ships: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	for s in ships:
		_cached_ship_ids.append(s.id)
		var sname: String = s.display_name if s.display_name != "" else s.id
		_cached_ship_names.append(sname)
		_ship_id_to_name[s.id] = sname
		# Group by level for filter dropdown
		var level_id: String = s.level if s.level != "" else "misc"
		if not _cached_ships_by_level.has(level_id):
			_cached_ships_by_level[level_id] = []
		_cached_ships_by_level[level_id].append({"id": s.id, "name": sname})

	_cached_nebula_ids.clear()
	_cached_nebula_names.clear()
	_cached_nebula_colors.clear()
	var nebulas: Array[NebulaData] = NebulaDataManager.load_all()
	for n in nebulas:
		_cached_nebula_ids.append(n.id)
		var nname: String = n.display_name if n.display_name != "" else n.id
		_cached_nebula_names.append(nname)
		var col_arr: Array = n.shader_params.get("nebula_color", [0.5, 0.5, 1.0, 1.0]) as Array
		if col_arr.size() >= 3:
			_cached_nebula_colors[n.id] = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]), 1.0)
		else:
			_cached_nebula_colors[n.id] = Color(0.5, 0.5, 1.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.editing_level_id = ""
		get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")
		return
	if not _is_text_input_focused() and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.ctrl_pressed and _selected_level:
			if key.keycode == KEY_C:
				_copy_selected()
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_V:
				_paste_at_scroll()
				get_viewport().set_input_as_handled()


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
	_apply_editor_background()
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _apply_editor_background() -> void:
	## Set the editor background to the selected level's shader, or default grid.
	var shader_path: String = ""
	if _selected_level:
		shader_path = _selected_level.background_shader
	if shader_path != "":
		var shader: Shader = load(shader_path) as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			_bg.material = mat
			return
	# Fallback to default grid
	_bg.material = null
	ThemeManager.apply_grid_background(_bg)


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

	# Flight Speed
	var flight_label := Label.new()
	flight_label.text = "FLIGHT SPEED"
	ThemeManager.apply_text_glow(flight_label, "body")
	vbox.add_child(flight_label)
	_flight_speed_spin = SpinBox.new()
	_flight_speed_spin.min_value = 20
	_flight_speed_spin.max_value = 600
	_flight_speed_spin.step = 10
	_flight_speed_spin.value = 160
	_flight_speed_spin.value_changed.connect(func(v: float) -> void:
		if _selected_level:
			_selected_level.flight_speed = v
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	vbox.add_child(_flight_speed_spin)

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

	# Background Shader
	var bg_label := Label.new()
	bg_label.text = "BACKGROUND"
	ThemeManager.apply_text_glow(bg_label, "body")
	vbox.add_child(bg_label)

	_bg_shader_dropdown = OptionButton.new()
	_bg_shader_dropdown.add_item("(default grid)", 0)
	_bg_shader_dropdown.set_item_metadata(0, "")
	var bg_shaders: Array = [
		["Synthwave Etch", "res://assets/shaders/bg_synthwave_pulse.gdshader"],
		["Microchip Die", "res://assets/shaders/bg_circuit_board.gdshader"],
		["Bioluminescent Reef", "res://assets/shaders/bg_bioluminescent_reef.gdshader"],
		["Industrial Platform", "res://assets/shaders/bg_industrial_platform.gdshader"],
		["Lava Field", "res://assets/shaders/bg_lava_field.gdshader"],
		["City District", "res://assets/shaders/bg_city_district.gdshader"],
	]
	for i in range(bg_shaders.size()):
		var entry: Array = bg_shaders[i]
		_bg_shader_dropdown.add_item(str(entry[0]), i + 1)
		_bg_shader_dropdown.set_item_metadata(i + 1, str(entry[1]))
	_bg_shader_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_level:
			_selected_level.background_shader = str(_bg_shader_dropdown.get_item_metadata(idx))
			_save_current_level()
			_apply_editor_background()
			if _preview_mode:
				_rebuild_preview()
	)
	vbox.add_child(_bg_shader_dropdown)

	# Play button
	var play_sep := HSeparator.new()
	vbox.add_child(play_sep)

	var play_btn := Button.new()
	play_btn.text = "PLAY LEVEL"
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_play_level)
	ThemeManager.apply_button_style(play_btn)
	vbox.add_child(play_btn)

	_preview_toggle_btn = Button.new()
	_preview_toggle_btn.text = "PREVIEW MODE"
	_preview_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_toggle_btn.pressed.connect(_toggle_preview_mode)
	ThemeManager.apply_button_style(_preview_toggle_btn)
	vbox.add_child(_preview_toggle_btn)

	# Debug grid toggles
	var debug_sep := HSeparator.new()
	vbox.add_child(debug_sep)

	var debug_header := Label.new()
	debug_header.text = "DEBUG GRIDS"
	debug_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(debug_header, "header")
	vbox.add_child(debug_header)

	_debug_deep_check = CheckButton.new()
	_debug_deep_check.text = "Deep (static)"
	_debug_deep_check.button_pressed = false
	_debug_deep_check.toggled.connect(func(_on: bool) -> void: _map_canvas.queue_redraw())
	vbox.add_child(_debug_deep_check)

	_debug_bg_check = CheckButton.new()
	_debug_bg_check.text = "Background"
	_debug_bg_check.button_pressed = false
	_debug_bg_check.toggled.connect(func(_on: bool) -> void: _map_canvas.queue_redraw())
	vbox.add_child(_debug_bg_check)

	_debug_fg_check = CheckButton.new()
	_debug_fg_check.text = "Foreground"
	_debug_fg_check.button_pressed = false
	_debug_fg_check.toggled.connect(func(_on: bool) -> void: _map_canvas.queue_redraw())
	vbox.add_child(_debug_fg_check)


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
		_flight_speed_spin.value = _selected_level.flight_speed
		_length_spin.value = _selected_level.level_length
		# Sync background dropdown
		var bg_path: String = _selected_level.background_shader
		var found_bg := false
		for i in range(_bg_shader_dropdown.item_count):
			if str(_bg_shader_dropdown.get_item_metadata(i)) == bg_path:
				_bg_shader_dropdown.select(i)
				found_bg = true
				break
		if not found_bg:
			_bg_shader_dropdown.select(0)
	else:
		_name_edit.text = ""
		_bpm_spin.value = 110
		_speed_spin.value = 80
		_flight_speed_spin.value = 160
		_length_spin.value = 10000
		_bg_shader_dropdown.select(0)


# ── Map canvas ─────────────────────────────────────────────────

func _build_map_canvas(parent: Control) -> void:
	var drawer := _MapCanvasDraw.new()
	drawer.screen = self
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(drawer)
	_map_canvas = drawer


func _build_preview_viewport(parent: Control) -> void:
	_preview_container = Control.new()
	_preview_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.visible = false
	parent.add_child(_preview_container)

	_preview_svc = SubViewportContainer.new()
	_preview_svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_svc.stretch = true
	_preview_svc.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.add_child(_preview_svc)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(1920, 1080)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_preview_viewport.transparent_bg = false
	_preview_svc.add_child(_preview_viewport)

	# Background shader rect
	_preview_bg_rect = ColorRect.new()
	_preview_bg_rect.size = Vector2(1920, 1080)
	_preview_viewport.add_child(_preview_bg_rect)

	# Doodad layer (scrolls with preview offset)
	_preview_doodad_layer = Node2D.new()
	_preview_doodad_layer.z_index = 1
	_preview_viewport.add_child(_preview_doodad_layer)

	_preview_doodad_renderer = DoodadRenderer.new()
	_preview_doodad_layer.add_child(_preview_doodad_renderer)

	# Encounter marker layer (scrolls with preview offset)
	_preview_encounter_markers = _PreviewEncounterDraw.new()
	_preview_encounter_markers.screen = self
	_preview_encounter_markers.z_index = 2
	_preview_viewport.add_child(_preview_encounter_markers)

	# Input overlay (catches mouse events for preview)
	var input_overlay := _PreviewInputOverlay.new()
	input_overlay.screen = self
	input_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.add_child(input_overlay)

	# Y position label overlay
	var pos_label := Label.new()
	pos_label.name = "PosLabel"
	pos_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pos_label.offset_left = 10
	pos_label.offset_top = 10
	pos_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.7))
	pos_label.add_theme_font_size_override("font_size", 14)
	_preview_container.add_child(pos_label)


func _toggle_preview_mode() -> void:
	_preview_mode = not _preview_mode
	_map_canvas.visible = not _preview_mode
	_preview_container.visible = _preview_mode
	_preview_toggle_btn.text = "OVERVIEW MODE" if _preview_mode else "PREVIEW MODE"

	if _preview_mode:
		# Sync preview scroll with overview scroll
		_preview_scroll = _scroll_offset
		_rebuild_preview()


func _rebuild_preview() -> void:
	if not _selected_level:
		return

	# Apply background shader
	var bg_applied := false
	if _selected_level.background_shader != "":
		var shader: Shader = load(_selected_level.background_shader) as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			_preview_bg_rect.material = mat
			bg_applied = true
	if not bg_applied:
		_preview_bg_rect.material = null
		ThemeManager.apply_grid_background(_preview_bg_rect)

	# Tell shader to use manual scroll (not TIME-based)
	var prev_mat: ShaderMaterial = _preview_bg_rect.material as ShaderMaterial
	if prev_mat:
		prev_mat.set_shader_parameter("manual_scroll", true)
		prev_mat.set_shader_parameter("scroll_offset", _preview_scroll)

	# Build doodad data in game-space coordinates
	var game_doodads: Array = []
	for dd in _selected_level.doodads:
		game_doodads.append({
			"type": str(dd.get("type", "water_tower")),
			"x": 960.0 + float(dd.get("x", 0.0)),
			"y": -float(dd.get("y", 0.0)) + 540.0,
			"scale": float(dd.get("scale", 1.0)),
			"rotation_deg": float(dd.get("rotation_deg", 0.0)),
		})
	_preview_doodad_renderer.setup(game_doodads)

	# Position layers for current scroll
	_update_preview_scroll()

	# Redraw encounter markers
	_preview_encounter_markers.queue_redraw()


func _update_preview_scroll() -> void:
	# Position doodad and encounter layers based on preview scroll
	_preview_doodad_layer.position.y = _preview_scroll
	_preview_encounter_markers.position.y = _preview_scroll

	# Update shader scroll_offset so background tracks preview position
	var prev_mat: ShaderMaterial = _preview_bg_rect.material as ShaderMaterial
	if prev_mat:
		prev_mat.set_shader_parameter("scroll_offset", _preview_scroll)

	# Update Y position label
	var pos_label: Label = _preview_container.get_node_or_null("PosLabel") as Label
	if pos_label:
		pos_label.text = "Y: " + str(int(_preview_scroll))


func _handle_preview_input(event: InputEvent, overlay_size: Vector2) -> void:
	if not _selected_level:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				var step: float = 200.0 if mb.shift_pressed else 60.0
				_preview_scroll = minf(_preview_scroll + step, maxf(_selected_level.level_length - 500.0, 0.0))
				_update_preview_scroll()
				_preview_encounter_markers.queue_redraw()
				_preview_doodad_renderer.queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var step: float = 200.0 if mb.shift_pressed else 60.0
				_preview_scroll = maxf(_preview_scroll - step, 0.0)
				_update_preview_scroll()
				_preview_encounter_markers.queue_redraw()
				_preview_doodad_renderer.queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_LEFT and _edit_mode == "doodads":
				# Try to select existing doodad first, then place if none hit
				if not _preview_try_select_doodad(mb.position, overlay_size):
					_preview_place_doodad(mb.position, overlay_size)
			elif mb.button_index == MOUSE_BUTTON_RIGHT and _edit_mode == "doodads":
				_preview_delete_doodad(mb.position, overlay_size)
			elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and _edit_mode != "doodads"):
				# Middle-click or left-click in non-doodad mode: start scroll drag
				_map_dragging = true
				_map_drag_start_y = mb.position.y
				_map_drag_scroll_start = _preview_scroll
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
				if _doodad_dragging:
					_doodad_dragging = false
					_save_current_level()
					_rebuild_preview()
					_update_doodad_right_panel()
					_map_canvas.queue_redraw()
				elif _map_dragging:
					_map_dragging = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _doodad_dragging and _doodad_selected_idx >= 0:
			var new_pos: Vector2 = _preview_pos_to_level(mm.position, overlay_size)
			var dd: Dictionary = _selected_level.doodads[_doodad_selected_idx]
			dd["x"] = new_pos.x
			dd["y"] = new_pos.y
			_rebuild_preview()
		elif _map_dragging:
			# Drag to scroll preview
			var delta_px: float = mm.position.y - _map_drag_start_y
			var px_to_level: float = 1080.0 / maxf(overlay_size.y, 1.0)
			_preview_scroll = clampf(_map_drag_scroll_start - delta_px * px_to_level, 0.0, maxf(_selected_level.level_length - 500.0, 0.0))
			_update_preview_scroll()
			_preview_encounter_markers.queue_redraw()
			_preview_doodad_renderer.queue_redraw()


func _preview_pos_to_level(local_pos: Vector2, overlay_size: Vector2) -> Vector2:
	## Convert a click position (in overlay local coords) to level-space coordinates.
	# Scale from overlay pixels to game viewport (1920x1080)
	var vp_x: float = local_pos.x / maxf(overlay_size.x, 1.0) * 1920.0
	var vp_y: float = local_pos.y / maxf(overlay_size.y, 1.0) * 1080.0
	# Convert to level space (same math as game: game_y = -level_y + 540 + scroll)
	var level_y: float = _preview_scroll + 540.0 - vp_y
	var level_x: float = vp_x - 960.0
	return Vector2(level_x, level_y)


func _preview_try_select_doodad(click_pos: Vector2, overlay_size: Vector2) -> bool:
	## Try to select an existing doodad at click position. Returns true if one was hit.
	var level_pos: Vector2 = _preview_pos_to_level(click_pos, overlay_size)
	var px_to_level: float = 1920.0 / maxf(overlay_size.x, 1.0)
	var hit_radius: float = 25.0 * px_to_level
	for i in range(_selected_level.doodads.size()):
		var dd: Dictionary = _selected_level.doodads[i]
		var dd_pos := Vector2(float(dd["x"]), float(dd["y"]))
		if dd_pos.distance_to(level_pos) < hit_radius:
			_doodad_selected_idx = i
			_doodad_dragging = true
			_doodad_drag_start = click_pos
			_doodad_drag_origin_x = float(dd["x"])
			_doodad_drag_origin_y = float(dd["y"])
			_update_doodad_right_panel()
			_map_canvas.queue_redraw()
			return true
	return false


func _preview_place_doodad(click_pos: Vector2, overlay_size: Vector2) -> void:
	var level_pos: Vector2 = _preview_pos_to_level(click_pos, overlay_size)
	var type_id: String = "water_tower"
	var sel_idx: int = _doodad_type_dropdown.selected
	if sel_idx >= 0:
		type_id = str(_doodad_type_dropdown.get_item_metadata(sel_idx))
	var new_dd: Dictionary = {
		"type": type_id,
		"x": level_pos.x,
		"y": level_pos.y,
		"scale": _doodad_scale_spin.value,
		"rotation_deg": _doodad_rot_spin.value,
	}
	_selected_level.doodads.append(new_dd)
	_doodad_selected_idx = _selected_level.doodads.size() - 1
	_save_current_level()
	_rebuild_preview()
	_update_doodad_right_panel()
	_map_canvas.queue_redraw()


func _preview_delete_doodad(click_pos: Vector2, overlay_size: Vector2) -> void:
	var level_pos: Vector2 = _preview_pos_to_level(click_pos, overlay_size)
	var closest_idx: int = -1
	# Hit radius in level-space: ~30px at game scale, but scale up for smaller preview
	var px_to_level: float = 1920.0 / maxf(overlay_size.x, 1.0)
	var closest_dist: float = 30.0 * px_to_level
	for i in range(_selected_level.doodads.size()):
		var dd: Dictionary = _selected_level.doodads[i]
		var dd_pos := Vector2(float(dd["x"]), float(dd["y"]))
		var dist: float = dd_pos.distance_to(level_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i
	if closest_idx >= 0:
		_selected_level.doodads.remove_at(closest_idx)
		if _doodad_selected_idx == closest_idx:
			_doodad_selected_idx = -1
		elif _doodad_selected_idx > closest_idx:
			_doodad_selected_idx -= 1
		_save_current_level()
		_rebuild_preview()
		_update_doodad_right_panel()
		_map_canvas.queue_redraw()


func _get_map_rect() -> Rect2:
	# The map strip fills most of the canvas width with margins on each side
	var canvas_size: Vector2 = _map_canvas.size
	var map_w: float = canvas_size.x - MAP_MARGIN * 2.0
	return Rect2(MAP_MARGIN, 0, map_w, canvas_size.y)


func _get_map_scale() -> float:
	# Uniform scale: same ratio for X and Y so circles stay circular.
	# Derived from map width vs game screen width.
	var map_rect: Rect2 = _get_map_rect()
	return map_rect.size.x / SCREEN_W


func _level_y_to_canvas_y(level_y: float) -> float:
	# Convert level-space Y (trigger_y) to canvas Y, accounting for scroll.
	# Flipped: high trigger_y (late encounters) at top, low trigger_y (early) at bottom,
	# matching the player's bottom-to-top travel direction.
	if not _selected_level:
		return 0.0
	var canvas_h: float = _map_canvas.size.y
	var scale: float = _get_map_scale()
	return canvas_h - (level_y - _scroll_offset) * scale


func _canvas_y_to_level_y(canvas_y: float) -> float:
	if not _selected_level:
		return 0.0
	var canvas_h: float = _map_canvas.size.y
	var scale: float = _get_map_scale()
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
				if _edit_mode == "nebulas":
					_map_left_click_nebula(mb.position)
				elif _edit_mode == "doodads":
					_map_left_click_doodad(mb.position)
				else:
					_map_left_click(mb.position)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				if _edit_mode == "nebulas":
					_map_right_click_nebula(mb.position)
				elif _edit_mode == "doodads":
					_map_right_click_doodad(mb.position)
				else:
					_map_right_click(mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				var visible_range: float = _map_canvas.size.y / maxf(_get_map_scale(), 0.001)
				var step: float = visible_range * (0.5 if mb.shift_pressed else 0.15)
				_scroll_offset = minf(_scroll_offset + step, maxf(_selected_level.level_length - 500.0, 0.0))
				_map_canvas.queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var visible_range: float = _map_canvas.size.y / maxf(_get_map_scale(), 0.001)
				var step: float = visible_range * (0.5 if mb.shift_pressed else 0.15)
				_scroll_offset = maxf(_scroll_offset - step, 0.0)
				_map_canvas.queue_redraw()
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if _encounter_dragging:
					_encounter_dragging = false
					_save_current_level()
					_update_right_panel()
				elif _nebula_dragging:
					_nebula_dragging = false
					_save_current_level()
					_update_nebula_right_panel()
				elif _doodad_dragging:
					_doodad_dragging = false
					_save_current_level()
					_update_doodad_right_panel()
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
		elif _nebula_dragging and _nebula_selected_idx >= 0:
			var neb: Dictionary = _selected_level.nebula_placements[_nebula_selected_idx]
			var delta_y: float = _canvas_y_to_level_y(mm.position.y) - _canvas_y_to_level_y(_nebula_drag_start.y)
			neb["trigger_y"] = maxf(_nebula_drag_origin_y + delta_y, 0.0)
			var delta_x: float = _canvas_x_to_level_x(mm.position.x) - _canvas_x_to_level_x(_nebula_drag_start.x)
			neb["x_offset"] = _nebula_drag_origin_x + delta_x
			_map_canvas.queue_redraw()
		elif _doodad_dragging and _doodad_selected_idx >= 0:
			var dd: Dictionary = _selected_level.doodads[_doodad_selected_idx]
			var delta_y: float = _canvas_y_to_level_y(mm.position.y) - _canvas_y_to_level_y(_doodad_drag_start.y)
			dd["y"] = maxf(_doodad_drag_origin_y + delta_y, 0.0)
			var delta_x: float = _canvas_x_to_level_x(mm.position.x) - _canvas_x_to_level_x(_doodad_drag_start.x)
			dd["x"] = _doodad_drag_origin_x + delta_x
			_map_canvas.queue_redraw()
		elif _map_dragging:
			var delta: float = mm.position.y - _map_drag_start_y
			var level_len: float = _selected_level.level_length
			var scale: float = _get_map_scale()
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
			_update_right_panel()
			_map_canvas.queue_redraw()
			return

	# Click empty space on map → place new encounter
	var map_rect: Rect2 = _get_map_rect()
	if map_rect.has_point(pos):
		var trigger_y: float = _canvas_y_to_level_y(pos.y)
		var x_offset: float = _canvas_x_to_level_x(pos.x)
		if trigger_y >= 0.0 and trigger_y <= _selected_level.level_length:
			var enc: Dictionary = {
				"path_id": str(_enc_path_dropdown.get_item_metadata(_enc_path_dropdown.selected)) if _enc_path_dropdown.selected >= 0 else "",
				"formation_id": str(_enc_fm_dropdown.get_item_metadata(_enc_fm_dropdown.selected)) if _enc_fm_dropdown.selected >= 0 else "",
				"ship_id": str(_enc_ship_dropdown.get_item_metadata(_enc_ship_dropdown.selected)) if _enc_ship_dropdown.selected >= 0 else "enemy_1",
				"speed": _enc_speed_spin.value,
				"count": int(_enc_count_spin.value),
				"spacing": _enc_spacing_spin.value,
				"trigger_y": trigger_y,
				"x_offset": x_offset,
				"rotate_with_path": _enc_rotate_check.button_pressed,
				"is_melee": _enc_melee_check.button_pressed,
				"turn_speed": _enc_turn_speed_spin.value,
				"weapons_active": _enc_weapons_active_check.button_pressed,
			}
			_selected_level.encounters.append(enc)
			_selected_encounter_idx = _selected_level.encounters.size() - 1
			_save_current_level()
			_update_right_panel()
			_map_canvas.queue_redraw()
			return

	# Click outside map → start drag-scroll or deselect
	_selected_encounter_idx = -1
	_map_dragging = true
	_map_drag_start_y = pos.y
	_map_drag_scroll_start = _scroll_offset
	_update_right_panel()
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
			_update_right_panel()
			_map_canvas.queue_redraw()
			return


func _get_nebula_spread(nebula_id: String) -> float:
	if nebula_id == "":
		return float(NebulaData.default_params()["radial_spread"])
	var ndata: NebulaData = NebulaDataManager.load_by_id(nebula_id)
	if ndata:
		return float(ndata.shader_params.get("radial_spread", NebulaData.default_params()["radial_spread"]))
	return float(NebulaData.default_params()["radial_spread"])


func _get_nebula_canvas_radius(neb: Dictionary) -> float:
	var radius: float = float(neb.get("radius", 300.0))
	var spread: float = _get_nebula_spread(str(neb.get("nebula_id", "")))
	var effective: float = radius * (1.0 - spread / 2.0)
	return maxf(effective * _get_map_scale(), NEBULA_HIT_RADIUS)


func _map_left_click_nebula(pos: Vector2) -> void:
	# Hit test existing nebula placements — use actual drawn radius
	for i in range(_selected_level.nebula_placements.size()):
		var neb: Dictionary = _selected_level.nebula_placements[i]
		var neb_cy: float = _level_y_to_canvas_y(float(neb["trigger_y"]))
		var neb_cx: float = _level_x_to_canvas_x(float(neb["x_offset"]))
		var hit_radius: float = _get_nebula_canvas_radius(neb)
		if Vector2(neb_cx, neb_cy).distance_to(pos) < hit_radius:
			_nebula_selected_idx = i
			_nebula_dragging = true
			_nebula_drag_start = pos
			_nebula_drag_origin_y = float(neb["trigger_y"])
			_nebula_drag_origin_x = float(neb["x_offset"])
			_update_nebula_right_panel()
			_map_canvas.queue_redraw()
			return

	# Click empty map — place new nebula
	var map_rect: Rect2 = _get_map_rect()
	if map_rect.has_point(pos):
		var trigger_y: float = _canvas_y_to_level_y(pos.y)
		var x_offset: float = _canvas_x_to_level_x(pos.x)
		if trigger_y >= 0.0 and trigger_y <= _selected_level.level_length:
			var neb: Dictionary = {
				"nebula_id": _cached_nebula_ids[0] if _cached_nebula_ids.size() > 0 else "",
				"trigger_y": trigger_y,
				"x_offset": x_offset,
				"radius": 300.0,
			}
			_selected_level.nebula_placements.append(neb)
			_nebula_selected_idx = _selected_level.nebula_placements.size() - 1
			_save_current_level()
			_update_nebula_right_panel()
			_map_canvas.queue_redraw()
			return

	# Click outside map — deselect + scroll drag
	_nebula_selected_idx = -1
	_map_dragging = true
	_map_drag_start_y = pos.y
	_map_drag_scroll_start = _scroll_offset
	_update_nebula_right_panel()
	_map_canvas.queue_redraw()


func _map_right_click_nebula(pos: Vector2) -> void:
	for i in range(_selected_level.nebula_placements.size()):
		var neb: Dictionary = _selected_level.nebula_placements[i]
		var neb_cy: float = _level_y_to_canvas_y(float(neb["trigger_y"]))
		var neb_cx: float = _level_x_to_canvas_x(float(neb["x_offset"]))
		var hit_radius: float = _get_nebula_canvas_radius(neb)
		if Vector2(neb_cx, neb_cy).distance_to(pos) < hit_radius:
			_selected_level.nebula_placements.remove_at(i)
			if _nebula_selected_idx == i:
				_nebula_selected_idx = -1
			elif _nebula_selected_idx > i:
				_nebula_selected_idx -= 1
			_save_current_level()
			_update_nebula_right_panel()
			_map_canvas.queue_redraw()
			return


# ── Copy / Paste ──────────────────────────────────────────────

func _copy_selected() -> void:
	if _edit_mode == "encounters" and _selected_encounter_idx >= 0:
		_clipboard = _selected_level.encounters[_selected_encounter_idx].duplicate(true)
		_clipboard["_clip_type"] = "encounter"
	elif _edit_mode == "nebulas" and _nebula_selected_idx >= 0:
		_clipboard = _selected_level.nebula_placements[_nebula_selected_idx].duplicate(true)
		_clipboard["_clip_type"] = "nebula"


func _paste_at_scroll() -> void:
	if _clipboard.is_empty() or not _selected_level:
		return
	var clip_type: String = str(_clipboard.get("_clip_type", ""))
	var pasted: Dictionary = _clipboard.duplicate(true)
	pasted.erase("_clip_type")
	# Keep same trigger_y, center horizontally
	pasted["x_offset"] = 0.0

	if clip_type == "encounter" and _edit_mode == "encounters":
		_selected_level.encounters.append(pasted)
		_selected_encounter_idx = _selected_level.encounters.size() - 1
		_save_current_level()
		_update_right_panel()
		_map_canvas.queue_redraw()
	elif clip_type == "nebula" and _edit_mode == "nebulas":
		_selected_level.nebula_placements.append(pasted)
		_nebula_selected_idx = _selected_level.nebula_placements.size() - 1
		_save_current_level()
		_update_nebula_right_panel()
		_map_canvas.queue_redraw()


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

	_right_panel_vbox = VBoxContainer.new()
	_right_panel_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel_vbox.custom_minimum_size.x = RIGHT_PANEL_W - 16
	_right_panel_vbox.add_theme_constant_override("separation", 6)
	_right_panel.add_child(_right_panel_vbox)

	# Mode toggle buttons
	_mode_toggle_box = HBoxContainer.new()
	_mode_toggle_box.add_theme_constant_override("separation", 4)
	_right_panel_vbox.add_child(_mode_toggle_box)

	_mode_enc_btn = Button.new()
	_mode_enc_btn.text = "ENCOUNTERS"
	_mode_enc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_enc_btn.pressed.connect(func() -> void: _set_edit_mode("encounters"))
	ThemeManager.apply_button_style(_mode_enc_btn)
	_mode_toggle_box.add_child(_mode_enc_btn)

	_mode_neb_btn = Button.new()
	_mode_neb_btn.text = "NEBULAS"
	_mode_neb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_neb_btn.pressed.connect(func() -> void: _set_edit_mode("nebulas"))
	ThemeManager.apply_button_style(_mode_neb_btn)
	_mode_toggle_box.add_child(_mode_neb_btn)

	_mode_doodad_btn = Button.new()
	_mode_doodad_btn.text = "DOODADS"
	_mode_doodad_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_doodad_btn.pressed.connect(func() -> void: _set_edit_mode("doodads"))
	ThemeManager.apply_button_style(_mode_doodad_btn)
	_mode_toggle_box.add_child(_mode_doodad_btn)

	var mode_sep := HSeparator.new()
	_right_panel_vbox.add_child(mode_sep)

	_right_header = Label.new()
	_right_header.text = "ENCOUNTER"
	_right_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_header.custom_minimum_size.x = RIGHT_PANEL_W - 16
	ThemeManager.apply_text_glow(_right_header, "header")
	_right_panel_vbox.add_child(_right_header)

	# Encounter hint label
	_enc_hint = Label.new()
	_enc_hint.text = "Click map to place"
	_enc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enc_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_right_panel_vbox.add_child(_enc_hint)

	# Encounter content container — built once, never destroyed
	_enc_content = VBoxContainer.new()
	_enc_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enc_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enc_content.add_theme_constant_override("separation", 6)
	_right_panel_vbox.add_child(_enc_content)

	# Path dropdown
	var path_label := Label.new()
	path_label.text = "PATH"
	ThemeManager.apply_text_glow(path_label, "body")
	_enc_content.add_child(path_label)

	_enc_path_dropdown = OptionButton.new()
	for i in range(_cached_path_ids.size()):
		_enc_path_dropdown.add_item(_cached_path_names[i], i)
		_enc_path_dropdown.set_item_metadata(i, _cached_path_ids[i])
	_enc_path_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["path_id"] = str(_enc_path_dropdown.get_item_metadata(idx))
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_enc_content.add_child(_enc_path_dropdown)

	# Formation dropdown
	var sep1 := HSeparator.new()
	_enc_content.add_child(sep1)

	var fm_label := Label.new()
	fm_label.text = "FORMATION"
	ThemeManager.apply_text_glow(fm_label, "body")
	_enc_content.add_child(fm_label)

	_enc_fm_dropdown = OptionButton.new()
	_enc_fm_dropdown.add_item("(none - single ship)", 0)
	_enc_fm_dropdown.set_item_metadata(0, "")
	for i in range(_cached_formation_ids.size()):
		_enc_fm_dropdown.add_item(_cached_formation_names[i], i + 1)
		_enc_fm_dropdown.set_item_metadata(i + 1, _cached_formation_ids[i])
	_enc_fm_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["formation_id"] = str(_enc_fm_dropdown.get_item_metadata(idx))
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_enc_content.add_child(_enc_fm_dropdown)

	# Level filter for ship dropdown
	var level_filter_label := Label.new()
	level_filter_label.text = "LEVEL FILTER"
	ThemeManager.apply_text_glow(level_filter_label, "body")
	_enc_content.add_child(level_filter_label)

	_enc_level_filter = OptionButton.new()
	_enc_level_filter.add_item("ALL", 0)
	_enc_level_filter.set_item_metadata(0, "ALL")
	var sorted_level_keys: Array = _cached_ships_by_level.keys()
	sorted_level_keys.sort()
	for li in range(sorted_level_keys.size()):
		var lkey: String = sorted_level_keys[li]
		_enc_level_filter.add_item(lkey, li + 1)
		_enc_level_filter.set_item_metadata(li + 1, lkey)
	_enc_level_filter.item_selected.connect(func(idx: int) -> void:
		var filter_val: String = str(_enc_level_filter.get_item_metadata(idx))
		_repopulate_ship_dropdown(filter_val)
	)
	_enc_content.add_child(_enc_level_filter)

	# Ship dropdown
	var ship_label := Label.new()
	ship_label.text = "SHIP (single)"
	ThemeManager.apply_text_glow(ship_label, "body")
	_enc_content.add_child(ship_label)

	_enc_ship_dropdown = OptionButton.new()
	for i in range(_cached_ship_ids.size()):
		_enc_ship_dropdown.add_item(_cached_ship_names[i], i)
		_enc_ship_dropdown.set_item_metadata(i, _cached_ship_ids[i])
	_enc_ship_dropdown.item_selected.connect(func(idx: int) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["ship_id"] = str(_enc_ship_dropdown.get_item_metadata(idx))
			_save_current_level()
	)
	_enc_content.add_child(_enc_ship_dropdown)

	# Speed
	var sep2 := HSeparator.new()
	_enc_content.add_child(sep2)

	var speed_label := Label.new()
	speed_label.text = "SPEED"
	ThemeManager.apply_text_glow(speed_label, "body")
	_enc_content.add_child(speed_label)
	_enc_speed_spin = SpinBox.new()
	_enc_speed_spin.min_value = 50
	_enc_speed_spin.max_value = 1000
	_enc_speed_spin.step = 10
	_enc_speed_spin.value = 200
	_enc_speed_spin.value_changed.connect(func(v: float) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["speed"] = v
			_save_current_level()
	)
	_enc_content.add_child(_enc_speed_spin)

	# Count
	var count_label := Label.new()
	count_label.text = "COUNT"
	ThemeManager.apply_text_glow(count_label, "body")
	_enc_content.add_child(count_label)
	_enc_count_spin = SpinBox.new()
	_enc_count_spin.min_value = 1
	_enc_count_spin.max_value = 20
	_enc_count_spin.step = 1
	_enc_count_spin.value = 1
	_enc_count_spin.value_changed.connect(func(v: float) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["count"] = int(v)
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_enc_content.add_child(_enc_count_spin)

	# Spacing
	var spacing_label := Label.new()
	spacing_label.text = "SPACING"
	ThemeManager.apply_text_glow(spacing_label, "body")
	_enc_content.add_child(spacing_label)
	_enc_spacing_spin = SpinBox.new()
	_enc_spacing_spin.min_value = 50
	_enc_spacing_spin.max_value = 2000
	_enc_spacing_spin.step = 50
	_enc_spacing_spin.value = 200
	_enc_spacing_spin.value_changed.connect(func(v: float) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["spacing"] = v
			_save_current_level()
	)
	_enc_content.add_child(_enc_spacing_spin)

	# Rotate with path
	var sep_rotate := HSeparator.new()
	_enc_content.add_child(sep_rotate)

	_enc_rotate_check = CheckButton.new()
	_enc_rotate_check.text = "ROTATE WITH PATH"
	_enc_rotate_check.toggled.connect(func(pressed: bool) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["rotate_with_path"] = pressed
			_save_current_level()
	)
	_enc_content.add_child(_enc_rotate_check)

	# Melee mode
	_enc_melee_check = CheckButton.new()
	_enc_melee_check.text = "MELEE"
	_enc_melee_check.toggled.connect(func(pressed: bool) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["is_melee"] = pressed
			_save_current_level()
			_map_canvas.queue_redraw()
		_update_melee_ui_state()
	)
	_enc_content.add_child(_enc_melee_check)

	_enc_turn_speed_label = Label.new()
	_enc_turn_speed_label.text = "TURN SPEED (deg/s)"
	ThemeManager.apply_text_glow(_enc_turn_speed_label, "body")
	_enc_content.add_child(_enc_turn_speed_label)

	_enc_turn_speed_spin = SpinBox.new()
	_enc_turn_speed_spin.min_value = 10
	_enc_turn_speed_spin.max_value = 720
	_enc_turn_speed_spin.step = 10
	_enc_turn_speed_spin.value = 90
	_enc_turn_speed_spin.value_changed.connect(func(v: float) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["turn_speed"] = v
			_save_current_level()
	)
	_enc_content.add_child(_enc_turn_speed_spin)

	# Weapons active
	var sep_weapons := HSeparator.new()
	_enc_content.add_child(sep_weapons)

	_enc_weapons_active_check = CheckButton.new()
	_enc_weapons_active_check.text = "WEAPONS ACTIVE"
	_enc_weapons_active_check.button_pressed = true
	_enc_weapons_active_check.toggled.connect(func(pressed: bool) -> void:
		if _selected_encounter_idx >= 0 and _selected_level and _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["weapons_active"] = pressed
			_save_current_level()
	)
	_enc_content.add_child(_enc_weapons_active_check)

	# Action buttons
	var sep3 := HSeparator.new()
	_enc_content.add_child(sep3)

	_enc_center_btn = Button.new()
	_enc_center_btn.text = "CENTER"
	_enc_center_btn.pressed.connect(func() -> void:
		if _selected_encounter_idx < 0 or not _selected_level:
			return
		if _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters[_selected_encounter_idx]["x_offset"] = 0.0
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(_enc_center_btn)
	_enc_content.add_child(_enc_center_btn)

	_enc_delete_btn = Button.new()
	_enc_delete_btn.text = "DELETE ENCOUNTER"
	_enc_delete_btn.pressed.connect(func() -> void:
		if _selected_encounter_idx < 0 or not _selected_level:
			return
		if _selected_encounter_idx < _selected_level.encounters.size():
			_selected_level.encounters.remove_at(_selected_encounter_idx)
			_selected_encounter_idx = -1
			_save_current_level()
			_update_right_panel()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(_enc_delete_btn)
	_enc_content.add_child(_enc_delete_btn)

	# ── Nebula content (same level in _right_panel_vbox) ──
	_neb_hint = Label.new()
	_neb_hint.text = "Click map to place"
	_neb_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_neb_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_right_panel_vbox.add_child(_neb_hint)

	_neb_content = VBoxContainer.new()
	_neb_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_neb_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_neb_content.add_theme_constant_override("separation", 6)
	_right_panel_vbox.add_child(_neb_content)

	var neb_label := Label.new()
	neb_label.text = "NEBULA"
	ThemeManager.apply_text_glow(neb_label, "body")
	_neb_content.add_child(neb_label)

	_neb_dropdown = OptionButton.new()
	for i in range(_cached_nebula_ids.size()):
		_neb_dropdown.add_item(_cached_nebula_names[i], i)
		_neb_dropdown.set_item_metadata(i, _cached_nebula_ids[i])
	_neb_dropdown.item_selected.connect(func(idx: int) -> void:
		if _nebula_selected_idx < 0 or not _selected_level:
			return
		if _nebula_selected_idx < _selected_level.nebula_placements.size():
			_selected_level.nebula_placements[_nebula_selected_idx]["nebula_id"] = str(_neb_dropdown.get_item_metadata(idx))
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_neb_content.add_child(_neb_dropdown)

	var neb_sep := HSeparator.new()
	_neb_content.add_child(neb_sep)

	var radius_label := Label.new()
	radius_label.text = "RADIUS"
	ThemeManager.apply_text_glow(radius_label, "body")
	_neb_content.add_child(radius_label)

	_neb_radius_spin = SpinBox.new()
	_neb_radius_spin.min_value = 50
	_neb_radius_spin.max_value = 1000
	_neb_radius_spin.step = 25
	_neb_radius_spin.value = 300
	_neb_radius_spin.value_changed.connect(func(v: float) -> void:
		if _nebula_selected_idx < 0 or not _selected_level:
			return
		if _nebula_selected_idx < _selected_level.nebula_placements.size():
			_selected_level.nebula_placements[_nebula_selected_idx]["radius"] = v
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_neb_content.add_child(_neb_radius_spin)

	var neb_sep2 := HSeparator.new()
	_neb_content.add_child(neb_sep2)

	_neb_center_btn = Button.new()
	_neb_center_btn.text = "CENTER"
	_neb_center_btn.pressed.connect(func() -> void:
		if _nebula_selected_idx < 0 or not _selected_level:
			return
		if _nebula_selected_idx < _selected_level.nebula_placements.size():
			_selected_level.nebula_placements[_nebula_selected_idx]["x_offset"] = 0.0
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(_neb_center_btn)
	_neb_content.add_child(_neb_center_btn)

	_neb_delete_btn = Button.new()
	_neb_delete_btn.text = "DELETE NEBULA"
	_neb_delete_btn.pressed.connect(func() -> void:
		if _nebula_selected_idx < 0 or not _selected_level:
			return
		if _nebula_selected_idx < _selected_level.nebula_placements.size():
			_selected_level.nebula_placements.remove_at(_nebula_selected_idx)
			_nebula_selected_idx = -1
			_save_current_level()
			_update_nebula_right_panel()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(_neb_delete_btn)
	_neb_content.add_child(_neb_delete_btn)

	# ── Doodad controls ──
	_doodad_hint = Label.new()
	_doodad_hint.text = "Click map to place doodad"
	_doodad_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_doodad_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_doodad_hint.visible = false
	_right_panel_vbox.add_child(_doodad_hint)

	_doodad_content = VBoxContainer.new()
	_doodad_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_doodad_content.add_theme_constant_override("separation", 6)
	_doodad_content.visible = false
	_right_panel_vbox.add_child(_doodad_content)

	var dd_type_label := Label.new()
	dd_type_label.text = "TYPE"
	ThemeManager.apply_text_glow(dd_type_label, "body")
	_doodad_content.add_child(dd_type_label)

	_doodad_type_dropdown = OptionButton.new()
	var dd_ids: Array[String] = DoodadRegistry.get_type_ids()
	for i in range(dd_ids.size()):
		_doodad_type_dropdown.add_item(DoodadRegistry.get_display_name(dd_ids[i]), i)
		_doodad_type_dropdown.set_item_metadata(i, dd_ids[i])
	_doodad_type_dropdown.item_selected.connect(func(idx: int) -> void:
		if _doodad_selected_idx >= 0 and _selected_level and _doodad_selected_idx < _selected_level.doodads.size():
			_selected_level.doodads[_doodad_selected_idx]["type"] = str(_doodad_type_dropdown.get_item_metadata(idx))
			_save_current_level()
			_map_canvas.queue_redraw()
	)
	_doodad_content.add_child(_doodad_type_dropdown)

	var dd_scale_label := Label.new()
	dd_scale_label.text = "SCALE"
	ThemeManager.apply_text_glow(dd_scale_label, "body")
	_doodad_content.add_child(dd_scale_label)

	_doodad_scale_spin = SpinBox.new()
	_doodad_scale_spin.min_value = 0.5
	_doodad_scale_spin.max_value = 5.0
	_doodad_scale_spin.step = 0.1
	_doodad_scale_spin.value = 1.0
	_doodad_scale_spin.value_changed.connect(func(val: float) -> void:
		if _doodad_selected_idx >= 0 and _selected_level and _doodad_selected_idx < _selected_level.doodads.size():
			_selected_level.doodads[_doodad_selected_idx]["scale"] = val
			_save_current_level()
	)
	_doodad_content.add_child(_doodad_scale_spin)

	var dd_rot_label := Label.new()
	dd_rot_label.text = "ROTATION"
	ThemeManager.apply_text_glow(dd_rot_label, "body")
	_doodad_content.add_child(dd_rot_label)

	_doodad_rot_spin = SpinBox.new()
	_doodad_rot_spin.min_value = 0.0
	_doodad_rot_spin.max_value = 360.0
	_doodad_rot_spin.step = 15.0
	_doodad_rot_spin.value = 0.0
	_doodad_rot_spin.value_changed.connect(func(val: float) -> void:
		if _doodad_selected_idx >= 0 and _selected_level and _doodad_selected_idx < _selected_level.doodads.size():
			_selected_level.doodads[_doodad_selected_idx]["rotation_deg"] = val
			_save_current_level()
	)
	_doodad_content.add_child(_doodad_rot_spin)

	_doodad_center_btn = Button.new()
	_doodad_center_btn.text = "CENTER VIEW"
	_doodad_center_btn.pressed.connect(func() -> void:
		if _doodad_selected_idx >= 0 and _selected_level and _doodad_selected_idx < _selected_level.doodads.size():
			var dd: Dictionary = _selected_level.doodads[_doodad_selected_idx]
			_scroll_offset = float(dd["y"]) - _map_canvas.size.y * 0.5 / _get_map_scale()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(_doodad_center_btn)
	_doodad_content.add_child(_doodad_center_btn)

	_doodad_delete_btn = Button.new()
	_doodad_delete_btn.text = "DELETE DOODAD"
	_doodad_delete_btn.pressed.connect(func() -> void:
		if _doodad_selected_idx >= 0 and _selected_level and _doodad_selected_idx < _selected_level.doodads.size():
			_selected_level.doodads.remove_at(_doodad_selected_idx)
			_doodad_selected_idx = -1
			_save_current_level()
			_update_doodad_right_panel()
			_map_canvas.queue_redraw()
	)
	ThemeManager.apply_button_style(_doodad_delete_btn)
	_doodad_content.add_child(_doodad_delete_btn)

	_set_edit_mode("encounters")
	_update_right_panel()


func _update_right_panel() -> void:
	var has_enc: bool = _selected_level != null and _selected_encounter_idx >= 0 and _selected_encounter_idx < _selected_level.encounters.size()

	# Hint label always visible — text changes based on selection state
	_enc_hint.visible = true
	if has_enc:
		_enc_hint.text = "Editing encounter #" + str(_selected_encounter_idx + 1)
		_enc_hint.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		_enc_hint.text = "Click map to place with current settings"
		_enc_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	# Panel is always active — controls serve as a "brush" for new placements.
	# Only CENTER and DELETE require a selected encounter.
	_enc_content.modulate = Color.WHITE
	_enc_path_dropdown.disabled = false
	_enc_fm_dropdown.disabled = false
	_enc_ship_dropdown.disabled = false
	_enc_speed_spin.editable = true
	_enc_count_spin.editable = true
	_enc_spacing_spin.editable = true
	_enc_rotate_check.disabled = false
	_enc_melee_check.disabled = false
	_enc_turn_speed_spin.editable = true
	_enc_weapons_active_check.disabled = false
	_enc_level_filter.disabled = false
	_enc_center_btn.disabled = not has_enc
	_enc_delete_btn.disabled = not has_enc

	if has_enc:
		var enc: Dictionary = _selected_level.encounters[_selected_encounter_idx]

		# Update path dropdown selection
		var current_path_id: String = str(enc.get("path_id", ""))
		var path_select: int = 0
		for i in range(_cached_path_ids.size()):
			if _cached_path_ids[i] == current_path_id:
				path_select = i
				break
		if _cached_path_ids.size() > 0:
			_enc_path_dropdown.select(path_select)

		# Update formation dropdown selection
		var current_fm_id: String = str(enc.get("formation_id", ""))
		var fm_select: int = 0
		for i in range(_cached_formation_ids.size()):
			if _cached_formation_ids[i] == current_fm_id:
				fm_select = i + 1
				break
		_enc_fm_dropdown.select(fm_select)

		# Update ship dropdown selection — find in current filtered list
		var current_ship_id: String = str(enc.get("ship_id", ""))
		var ship_select: int = 0
		for i in range(_enc_ship_dropdown.item_count):
			if str(_enc_ship_dropdown.get_item_metadata(i)) == current_ship_id:
				ship_select = i
				break
		if _enc_ship_dropdown.item_count > 0:
			_enc_ship_dropdown.select(ship_select)

		# Update spinbox values
		_enc_speed_spin.value = float(enc.get("speed", 200.0))
		_enc_count_spin.value = int(enc.get("count", 1))
		_enc_spacing_spin.value = float(enc.get("spacing", 200.0))
		_enc_rotate_check.button_pressed = bool(enc.get("rotate_with_path", false))
		_enc_melee_check.button_pressed = bool(enc.get("is_melee", false))
		_enc_turn_speed_spin.value = float(enc.get("turn_speed", 90.0))
		_enc_weapons_active_check.button_pressed = bool(enc.get("weapons_active", true))

	_update_melee_ui_state()


func _update_melee_ui_state() -> void:
	var melee_on: bool = _enc_melee_check.button_pressed
	# When melee is on, path and rotate_with_path are irrelevant
	if melee_on:
		_enc_path_dropdown.disabled = true
		_enc_rotate_check.disabled = true
	# Turn speed editable when melee is on (brush or selected encounter)
	_enc_turn_speed_spin.editable = melee_on
	_enc_turn_speed_label.modulate = Color.WHITE if melee_on else Color(1, 1, 1, 0.3)
	_enc_turn_speed_spin.modulate = Color.WHITE if melee_on else Color(1, 1, 1, 0.3)


func _repopulate_ship_dropdown(level_filter: String) -> void:
	# Remember current selection metadata so we can restore it if still present
	var prev_ship_id: String = ""
	if _enc_ship_dropdown.selected >= 0:
		prev_ship_id = str(_enc_ship_dropdown.get_item_metadata(_enc_ship_dropdown.selected))

	_enc_ship_dropdown.clear()

	var ship_entries: Array = []
	if level_filter == "ALL":
		for i in range(_cached_ship_ids.size()):
			ship_entries.append({"id": _cached_ship_ids[i], "name": _cached_ship_names[i]})
	else:
		if _cached_ships_by_level.has(level_filter):
			ship_entries = _cached_ships_by_level[level_filter]

	for i in range(ship_entries.size()):
		var entry: Dictionary = ship_entries[i]
		_enc_ship_dropdown.add_item(str(entry["name"]), i)
		_enc_ship_dropdown.set_item_metadata(i, str(entry["id"]))

	# Restore previous selection if it's still in the filtered list
	var restored: bool = false
	if prev_ship_id != "":
		for i in range(_enc_ship_dropdown.item_count):
			if str(_enc_ship_dropdown.get_item_metadata(i)) == prev_ship_id:
				_enc_ship_dropdown.select(i)
				restored = true
				break
	if not restored and _enc_ship_dropdown.item_count > 0:
		_enc_ship_dropdown.select(0)


func _set_edit_mode(mode: String) -> void:
	_edit_mode = mode
	var is_enc: bool = mode == "encounters"
	var is_neb: bool = mode == "nebulas"
	var is_dd: bool = mode == "doodads"
	_mode_enc_btn.modulate = Color(1.2, 1.2, 1.5) if is_enc else Color(0.6, 0.6, 0.7)
	_mode_neb_btn.modulate = Color(1.2, 1.2, 1.5) if is_neb else Color(0.6, 0.6, 0.7)
	_mode_doodad_btn.modulate = Color(1.2, 1.2, 1.5) if is_dd else Color(0.6, 0.6, 0.7)
	if is_enc:
		_right_header.text = "ENCOUNTER"
	elif is_neb:
		_right_header.text = "NEBULA"
	else:
		_right_header.text = "DOODAD"

	_enc_hint.visible = is_enc
	_enc_content.visible = is_enc
	_neb_hint.visible = is_neb
	_neb_content.visible = is_neb
	_doodad_hint.visible = is_dd
	_doodad_content.visible = is_dd

	if is_enc:
		_update_right_panel()
	elif is_neb:
		_update_nebula_right_panel()
	else:
		_update_doodad_right_panel()
	_map_canvas.queue_redraw()


func _update_nebula_right_panel() -> void:
	if _edit_mode != "nebulas":
		return
	var has_neb: bool = _selected_level != null and _nebula_selected_idx >= 0 and _nebula_selected_idx < _selected_level.nebula_placements.size()

	_neb_hint.visible = not has_neb
	var disabled: bool = not has_neb
	_neb_content.modulate = Color(1, 1, 1, 0.3) if disabled else Color.WHITE
	_neb_dropdown.disabled = disabled
	_neb_radius_spin.editable = not disabled
	_neb_center_btn.disabled = disabled
	_neb_delete_btn.disabled = disabled

	if not has_neb:
		return

	var neb: Dictionary = _selected_level.nebula_placements[_nebula_selected_idx]

	# Update nebula dropdown selection
	var current_neb_id: String = str(neb.get("nebula_id", ""))
	var neb_select: int = 0
	for i in range(_cached_nebula_ids.size()):
		if _cached_nebula_ids[i] == current_neb_id:
			neb_select = i
			break
	if _cached_nebula_ids.size() > 0:
		_neb_dropdown.select(neb_select)

	_neb_radius_spin.value = float(neb.get("radius", 300.0))


# ── Doodad operations ────────────────────────────────────────────

const DOODAD_HIT_RADIUS := 30.0

func _update_doodad_right_panel() -> void:
	if _edit_mode != "doodads":
		return
	var has_dd: bool = _selected_level != null and _doodad_selected_idx >= 0 and _doodad_selected_idx < _selected_level.doodads.size()

	# Panel always active — controls serve as "brush" for new placements (like encounters)
	_doodad_hint.visible = true
	if has_dd:
		_doodad_hint.text = "Editing doodad #" + str(_doodad_selected_idx + 1)
		_doodad_hint.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		_doodad_hint.text = "Set params, then click map to place"
		_doodad_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	_doodad_content.modulate = Color.WHITE
	_doodad_type_dropdown.disabled = false
	_doodad_scale_spin.editable = true
	_doodad_rot_spin.editable = true
	# Only center/delete require a selection
	_doodad_center_btn.disabled = not has_dd
	_doodad_delete_btn.disabled = not has_dd

	if not has_dd:
		return

	var dd: Dictionary = _selected_level.doodads[_doodad_selected_idx]

	# Update type dropdown to match selected doodad
	var dd_type: String = str(dd.get("type", "water_tower"))
	var dd_ids: Array[String] = DoodadRegistry.get_type_ids()
	for i in range(dd_ids.size()):
		if dd_ids[i] == dd_type:
			_doodad_type_dropdown.select(i)
			break

	_doodad_scale_spin.value = float(dd.get("scale", 1.0))
	_doodad_rot_spin.value = float(dd.get("rotation_deg", 0.0))


func _map_left_click_doodad(click_pos: Vector2) -> void:
	if not _selected_level:
		return
	# Hit test existing doodads
	for i in range(_selected_level.doodads.size()):
		var dd: Dictionary = _selected_level.doodads[i]
		var cy: float = _level_y_to_canvas_y(float(dd["y"]))
		var cx: float = _level_x_to_canvas_x(float(dd["x"]))
		if click_pos.distance_to(Vector2(cx, cy)) < DOODAD_HIT_RADIUS:
			_doodad_selected_idx = i
			_doodad_dragging = true
			_doodad_drag_start = click_pos
			_doodad_drag_origin_y = float(dd["y"])
			_doodad_drag_origin_x = float(dd["x"])
			_update_doodad_right_panel()
			_map_canvas.queue_redraw()
			return

	# Place new doodad
	var level_y: float = _canvas_y_to_level_y(click_pos.y)
	var level_x: float = _canvas_x_to_level_x(click_pos.x)
	# Use currently selected type from dropdown
	var type_id: String = "water_tower"
	var sel_idx: int = _doodad_type_dropdown.selected
	if sel_idx >= 0:
		type_id = str(_doodad_type_dropdown.get_item_metadata(sel_idx))
	var new_dd: Dictionary = {
		"type": type_id,
		"x": level_x,
		"y": level_y,
		"scale": _doodad_scale_spin.value,
		"rotation_deg": _doodad_rot_spin.value,
	}
	_selected_level.doodads.append(new_dd)
	_doodad_selected_idx = _selected_level.doodads.size() - 1
	_save_current_level()
	_update_doodad_right_panel()
	_map_canvas.queue_redraw()


func _map_right_click_doodad(click_pos: Vector2) -> void:
	if not _selected_level:
		return
	for i in range(_selected_level.doodads.size()):
		var dd: Dictionary = _selected_level.doodads[i]
		var cy: float = _level_y_to_canvas_y(float(dd["y"]))
		var cx: float = _level_x_to_canvas_x(float(dd["x"]))
		if click_pos.distance_to(Vector2(cx, cy)) < DOODAD_HIT_RADIUS:
			_selected_level.doodads.remove_at(i)
			if _doodad_selected_idx == i:
				_doodad_selected_idx = -1
			elif _doodad_selected_idx > i:
				_doodad_selected_idx -= 1
			_save_current_level()
			_update_doodad_right_panel()
			_map_canvas.queue_redraw()
			return


# ── Data operations ────────────────────────────────────────────

func _load_all_levels() -> void:
	_all_levels = LevelDataManager.load_all()
	_rebuild_level_list()


func _select_level(lv: LevelData) -> void:
	_selected_level = lv
	GameState.editing_level_id = lv.id
	_selected_encounter_idx = -1
	_nebula_selected_idx = -1
	_doodad_selected_idx = -1
	_scroll_offset = 0.0
	_update_level_props_ui()
	_rebuild_level_list()
	_update_right_panel()
	_update_nebula_right_panel()
	if _edit_mode == "doodads":
		_update_doodad_right_panel()
	_apply_editor_background()
	_map_canvas.queue_redraw()
	if _preview_mode:
		_preview_scroll = 0.0
		_rebuild_preview()


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
		"flight_speed": 160.0,
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
		_update_right_panel()
		_update_nebula_right_panel()
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
		var uniform_scale: float = s._get_map_scale()

		# Debug grid overlays (drawn behind everything else)
		_draw_debug_grids(s, level, map_rect, uniform_scale)

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
		var visible_range: float = canvas_h / maxf(uniform_scale, 0.001)
		var scroll_ratio: float = s._scroll_offset / maxf(level.level_length, 1.0)
		var view_ratio: float = clampf(visible_range / maxf(level.level_length, 1.0), 0.02, 1.0)
		var bar_x: float = map_rect.position.x - 8
		var bar_h: float = canvas_h * view_ratio
		var bar_y: float = (1.0 - scroll_ratio) * (canvas_h - bar_h)
		draw_rect(Rect2(bar_x, bar_y, 4, bar_h), Color(0.4, 0.8, 1.0, 0.5), true)

		# Y position readout
		var font2: Font = ThemeDB.fallback_font
		draw_string(font2, Vector2(bar_x - 40, bar_y + bar_h * 0.5 + 4), str(int(s._scroll_offset)), HORIZONTAL_ALIGNMENT_RIGHT, 44, 10, Color(0.5, 0.7, 1.0, 0.7))

		# Draw nebula placement circles (background layer, always visible)
		for i in range(level.nebula_placements.size()):
			var neb: Dictionary = level.nebula_placements[i]
			var ncy: float = s._level_y_to_canvas_y(float(neb["trigger_y"]))
			var ncx: float = s._level_x_to_canvas_x(float(neb["x_offset"]))
			var neb_radius: float = float(neb.get("radius", 300.0))
			var neb_id_for_spread: String = str(neb.get("nebula_id", ""))
			var spread: float = s._get_nebula_spread(neb_id_for_spread)
			var effective: float = neb_radius * (1.0 - spread / 2.0)
			var canvas_radius: float = maxf(effective * uniform_scale, NEBULA_HIT_RADIUS)

			if ncy < -canvas_radius - 20 or ncy > canvas_h + canvas_radius + 20:
				continue

			var neb_id: String = str(neb.get("nebula_id", ""))
			var neb_color: Color = s._cached_nebula_colors.get(neb_id, Color(0.5, 0.5, 1.0)) as Color
			var is_neb_selected: bool = (s._edit_mode == "nebulas" and i == s._nebula_selected_idx)

			var center := Vector2(ncx, ncy)

			if is_neb_selected:
				# Selected: bright fill + thick outline + outer glow rings
				draw_circle(center, canvas_radius, Color(neb_color, 0.3))
				_draw_circle_outline(center, canvas_radius, Color(neb_color, 0.9), 3.0)
				_draw_circle_outline(center, canvas_radius + 4, Color(neb_color, 0.4), 2.0)
				_draw_circle_outline(center, canvas_radius + 8, Color(neb_color, 0.2), 1.0)
				# Center crosshair
				var ch: float = minf(canvas_radius * 0.3, 12.0)
				draw_line(Vector2(ncx - ch, ncy), Vector2(ncx + ch, ncy), Color(neb_color, 0.6), 1.0)
				draw_line(Vector2(ncx, ncy - ch), Vector2(ncx, ncy + ch), Color(neb_color, 0.6), 1.0)
			else:
				# Unselected: subtle fill + thin outline
				draw_circle(center, canvas_radius, Color(neb_color, 0.15))
				_draw_circle_outline(center, canvas_radius, Color(neb_color, 0.4), 2.0)

			# Name label below circle
			var neb_name: String = ""
			for ni in range(s._cached_nebula_ids.size()):
				if s._cached_nebula_ids[ni] == neb_id:
					neb_name = s._cached_nebula_names[ni]
					break
			if neb_name == "":
				neb_name = neb_id
			var nfont: Font = ThemeDB.fallback_font
			draw_string(nfont, Vector2(ncx - 40, ncy + canvas_radius + 14), neb_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(neb_color, 0.7))

		# Draw doodad markers
		for i in range(level.doodads.size()):
			var dd: Dictionary = level.doodads[i]
			var dcy: float = s._level_y_to_canvas_y(float(dd["y"]))
			var dcx: float = s._level_x_to_canvas_x(float(dd["x"]))
			if dcy < -20 or dcy > canvas_h + 20:
				continue
			var is_dd_selected: bool = (s._edit_mode == "doodads" and i == s._doodad_selected_idx)
			var dd_color := Color(0.6, 0.9, 0.4) if is_dd_selected else Color(0.3, 0.5, 0.25, 0.7)
			var dd_sz: float = 8.0
			# Square marker
			draw_rect(Rect2(dcx - dd_sz, dcy - dd_sz, dd_sz * 2, dd_sz * 2), dd_color, true)
			if is_dd_selected:
				draw_rect(Rect2(dcx - dd_sz - 2, dcy - dd_sz - 2, dd_sz * 2 + 4, dd_sz * 2 + 4), Color(dd_color, 0.5), false, 2.0)
			# Type label
			var dd_type: String = str(dd.get("type", ""))
			var dd_label: String = dd_type.substr(0, 3).to_upper()
			var dfont: Font = ThemeDB.fallback_font
			draw_string(dfont, Vector2(dcx + dd_sz + 3, dcy + 4), dd_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dd_color)

		# Draw encounter markers
		for i in range(level.encounters.size()):
			var enc: Dictionary = level.encounters[i]
			var cy: float = s._level_y_to_canvas_y(float(enc["trigger_y"]))
			var cx: float = s._level_x_to_canvas_x(float(enc["x_offset"]))

			if cy < -30 or cy > canvas_h + 30:
				continue

			var is_selected: bool = (i == s._selected_encounter_idx)
			var enc_is_melee: bool = bool(enc.get("is_melee", false))
			var color := Color(1.0, 0.5, 0.2) if is_selected else (Color(1.0, 0.3, 0.3) if enc_is_melee else Color(0.4, 0.8, 1.0))

			# Path curve preview (draw behind marker when selected, skip for melee)
			if is_selected and not enc_is_melee:
				var path_id: String = str(enc.get("path_id", ""))
				if s._path_id_to_curve.has(path_id):
					_draw_path_preview(s._path_id_to_curve[path_id], cx, cy, color)

			# Diamond marker
			var ship_id: String = str(enc.get("ship_id", ""))
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

			# Labels: ship name + count, formation name, path name
			var fm_id: String = str(enc.get("formation_id", ""))
			var ship_name: String = s._ship_id_to_name.get(ship_id, ship_id) as String
			if ship_name == "":
				ship_name = "?"
			var count_val: int = int(enc.get("count", 1))
			var ship_text: String = ship_name
			if count_val > 1:
				ship_text += " x" + str(count_val)
			var font3: Font = ThemeDB.fallback_font
			var label_x: float = cx + sz * 0.7 + 6
			var label_y_offset: float = 4.0
			draw_string(font3, Vector2(label_x, cy + label_y_offset), ship_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.9))
			label_y_offset += 12.0
			if fm_id != "":
				var fm_name: String = s._formation_id_to_name.get(fm_id, fm_id) as String
				var fm_color := Color(0.6, 1.0, 0.5, 0.8) if is_selected else Color(0.5, 0.9, 0.4, 0.7)
				draw_string(font3, Vector2(label_x, cy + label_y_offset), fm_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fm_color)
				label_y_offset += 12.0
			if enc_is_melee:
				var melee_color := Color(1.0, 0.4, 0.4, 0.9) if is_selected else Color(1.0, 0.3, 0.3, 0.7)
				draw_string(font3, Vector2(label_x, cy + label_y_offset), "MELEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, melee_color)
				label_y_offset += 12.0
			else:
				var enc_path_id: String = str(enc.get("path_id", ""))
				if enc_path_id != "":
					var path_name: String = s._path_id_to_name.get(enc_path_id, enc_path_id) as String
					var path_color := Color(0.5, 0.9, 1.0, 0.7) if is_selected else Color(0.4, 0.7, 0.9, 0.5)
					draw_string(font3, Vector2(label_x, cy + label_y_offset), path_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, path_color)


	func _draw_debug_grids(s: Control, level: LevelData, map_rect: Rect2, scale: float) -> void:
		var left: float = map_rect.position.x
		var right: float = map_rect.position.x + map_rect.size.x
		var font: Font = ThemeDB.fallback_font

		# Deep background grid — fixed canvas intervals (doesn't scroll with level)
		if s._debug_deep_check and s._debug_deep_check.button_pressed:
			var deep_color := Color(0.6, 0.3, 0.9, 0.25)
			var spacing: float = 80.0  # Fixed pixel spacing on canvas
			var y: float = 0.0
			while y < size.y:
				draw_line(Vector2(left, y), Vector2(right, y), deep_color, 1.0)
				y += spacing
			draw_string(font, Vector2(left + 4, 14), "DEEP BG (static)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.3, 0.9, 0.6))

		# Background grid — level-space intervals at GRID_SPACING (scrolls with map)
		if s._debug_bg_check and s._debug_bg_check.button_pressed:
			var bg_color := Color(0.3, 0.9, 0.3, 0.25)
			var grid_y: float = 0.0
			while grid_y <= level.level_length:
				var cy: float = s._level_y_to_canvas_y(grid_y)
				if cy >= -10 and cy <= size.y + 10:
					draw_line(Vector2(left, cy), Vector2(right, cy), bg_color, 1.5)
				grid_y += GRID_SPACING
			draw_string(font, Vector2(left + 4, 28), "BG (" + str(int(level.scroll_speed)) + " px/s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.9, 0.3, 0.6))

		# Foreground grid — denser lines to show faster speed
		if s._debug_fg_check and s._debug_fg_check.button_pressed:
			var fg_color := Color(1.0, 0.5, 0.2, 0.25)
			var ratio: float = level.scroll_speed / maxf(level.flight_speed, 1.0)
			var fg_spacing: float = GRID_SPACING * ratio  # Denser = faster
			var grid_y: float = 0.0
			while grid_y <= level.level_length:
				var cy: float = s._level_y_to_canvas_y(grid_y)
				if cy >= -10 and cy <= size.y + 10:
					draw_line(Vector2(left, cy), Vector2(right, cy), fg_color, 1.5)
				grid_y += fg_spacing
			draw_string(font, Vector2(left + 4, 42), "FG (" + str(int(level.flight_speed)) + " px/s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.5, 0.2, 0.6))


	func _draw_path_preview(curve: Curve2D, cx: float, cy: float, color: Color) -> void:
		var baked: PackedVector2Array = curve.get_baked_points()
		if baked.size() < 2:
			return

		# Use the map's actual coordinate scale so path preview is proportionally correct
		var map_rect: Rect2 = screen._get_map_rect()
		var scale_factor: float = map_rect.size.x / 1920.0

		# Compute bounding box center to anchor preview on the marker
		var bbox_min := baked[0]
		var bbox_max := baked[0]
		for pt in baked:
			bbox_min.x = minf(bbox_min.x, pt.x)
			bbox_min.y = minf(bbox_min.y, pt.y)
			bbox_max.x = maxf(bbox_max.x, pt.x)
			bbox_max.y = maxf(bbox_max.y, pt.y)
		var bbox_center: Vector2 = (bbox_min + bbox_max) * 0.5

		# Build transformed points centered on the marker, at map scale
		var preview_pts := PackedVector2Array()
		for pt in baked:
			preview_pts.append(Vector2(cx + (pt.x - bbox_center.x) * scale_factor, cy + (pt.y - bbox_center.y) * scale_factor))

		# Draw the curve
		draw_polyline(preview_pts, Color(color, 0.3), 2.0, true)

		# Direction arrow at ~25% along the path
		if preview_pts.size() >= 4:
			var arrow_idx: int = int(preview_pts.size() * 0.25)
			var arrow_pos: Vector2 = preview_pts[arrow_idx]
			var arrow_dir: Vector2 = (preview_pts[mini(arrow_idx + 1, preview_pts.size() - 1)] - preview_pts[maxi(arrow_idx - 1, 0)]).normalized()
			var perp: Vector2 = Vector2(-arrow_dir.y, arrow_dir.x)
			var arrow_size: float = 6.0
			var tip: Vector2 = arrow_pos + arrow_dir * arrow_size
			draw_colored_polygon(PackedVector2Array([
				tip,
				arrow_pos - arrow_dir * arrow_size * 0.5 + perp * arrow_size * 0.5,
				arrow_pos - arrow_dir * arrow_size * 0.5 - perp * arrow_size * 0.5,
			]), Color(color, 0.5))

		# Start dot
		if preview_pts.size() > 0:
			draw_circle(preview_pts[0], 3.0, Color(color, 0.6))


	func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
		var segments: int = maxi(int(radius * 0.5), 24)
		var pts := PackedVector2Array()
		for i in range(segments + 1):
			var angle: float = TAU * float(i) / float(segments)
			pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(pts, color, width, true)



	func _gui_input(event: InputEvent) -> void:
		if screen:
			screen._handle_map_input(event)
			if event is InputEventMouseButton:
				accept_event()
			elif event is InputEventMouseMotion and (screen._encounter_dragging or screen._nebula_dragging or screen._doodad_dragging or screen._map_dragging):
				accept_event()


class _PreviewEncounterDraw extends Node2D:
	## Draws static encounter markers in the preview viewport.
	var screen: Control

	func _draw() -> void:
		if not screen or not screen._selected_level:
			return
		var level: LevelData = screen._selected_level
		for enc in level.encounters:
			var trigger_y: float = float(enc["trigger_y"])
			var x_offset: float = float(enc["x_offset"])
			var game_x: float = 960.0 + x_offset
			var game_y: float = -trigger_y + 540.0
			var sz: float = 14.0
			var pts := PackedVector2Array([
				Vector2(game_x, game_y - sz),
				Vector2(game_x + sz * 0.7, game_y),
				Vector2(game_x, game_y + sz),
				Vector2(game_x - sz * 0.7, game_y),
			])
			draw_colored_polygon(pts, Color(0.4, 0.8, 1.0, 0.35))
			draw_polyline(pts, Color(0.4, 0.8, 1.0, 0.6), 1.5)
			var ship_id: String = str(enc.get("ship_id", ""))
			var count: int = int(enc.get("count", 1))
			var label: String = ship_id.replace("enemy_", "") + " x" + str(count)
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(game_x + sz + 3, game_y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.8, 1.0, 0.5))


class _PreviewInputOverlay extends Control:
	## Transparent overlay that routes input to the level editor's preview handler.
	var screen: Control

	func _gui_input(event: InputEvent) -> void:
		if screen:
			screen._handle_preview_input(event, size)
			if event is InputEventMouseButton:
				accept_event()
			elif event is InputEventMouseMotion and (screen._doodad_dragging or screen._map_dragging):
				accept_event()
