extends Control
## Music Screen — edit menu music arrangements.
## Each arrangement is a multi-track layered composition, stored under
## res://data/menu_arrangements/. Tracks support infinite-loop for the
## continuous menu-music case.

const LEFT_PANEL_W: int = 240

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button

var _arrangements: Array[MenuArrangement] = []
var _selected: MenuArrangement = null
var _arrangement_buttons: Array[Button] = []

var _list_vbox: VBoxContainer
var _name_edit: LineEdit
var _bpm_spin: SpinBox
var _rotation_check: CheckBox
var _timeline_editor: MusicTimelineEditor
var _editor_header: Label


func _ready() -> void:
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	_load_arrangements()
	if _arrangements.size() > 0:
		_select_arrangement(_arrangements[0])
	else:
		_refresh_editor_enabled()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "MUSIC"
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Body: split left/right
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = LEFT_PANEL_W
	main_vbox.add_child(split)

	_build_left_panel(split)
	_build_right_panel(split)

	_setup_vhs_overlay()


func _build_left_panel(parent: HSplitContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = LEFT_PANEL_W
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var arr_header := Label.new()
	arr_header.text = "ARRANGEMENTS"
	arr_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(arr_header, "header")
	vbox.add_child(arr_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 180
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_list_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new)
	ThemeManager.apply_button_style(new_btn)
	btn_row.add_child(new_btn)

	var dupe_btn := Button.new()
	dupe_btn.text = "DUPE"
	dupe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dupe_btn.pressed.connect(_on_dupe)
	ThemeManager.apply_button_style(dupe_btn)
	btn_row.add_child(dupe_btn)

	var del_btn := Button.new()
	del_btn.text = "DEL"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete)
	ThemeManager.apply_button_style(del_btn)
	btn_row.add_child(del_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var props_header := Label.new()
	props_header.text = "PROPS"
	props_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(props_header, "header")
	vbox.add_child(props_header)

	_rotation_check = CheckBox.new()
	_rotation_check.text = "IN ROTATION"
	_rotation_check.tooltip_text = "Eligible for random selection as menu music on launch"
	_rotation_check.toggled.connect(_on_rotation_toggled)
	vbox.add_child(_rotation_check)

	var name_lbl := Label.new()
	name_lbl.text = "NAME"
	ThemeManager.apply_text_glow(name_lbl, "body")
	vbox.add_child(name_lbl)

	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(_on_name_changed)
	vbox.add_child(_name_edit)

	var bpm_lbl := Label.new()
	bpm_lbl.text = "BPM"
	ThemeManager.apply_text_glow(bpm_lbl, "body")
	vbox.add_child(bpm_lbl)

	_bpm_spin = SpinBox.new()
	_bpm_spin.min_value = 60
	_bpm_spin.max_value = 200
	_bpm_spin.step = 1
	_bpm_spin.value = 120
	_bpm_spin.value_changed.connect(_on_bpm_changed)
	vbox.add_child(_bpm_spin)


func _build_right_panel(parent: HSplitContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_editor_header = Label.new()
	_editor_header.text = "(no arrangement selected)"
	ThemeManager.apply_text_glow(_editor_header, "header")
	vbox.add_child(_editor_header)

	_timeline_editor = MusicTimelineEditor.new()
	_timeline_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline_editor.tracks_changed.connect(_on_tracks_changed)
	_timeline_editor.duration_changed.connect(_on_duration_changed)
	vbox.add_child(_timeline_editor)


# ── Arrangement management ────────────────────────────────────

func _load_arrangements() -> void:
	_arrangements = MenuArrangementManager.load_all()
	_rebuild_list()


func _rebuild_list() -> void:
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	_arrangement_buttons.clear()
	for a in _arrangements:
		var btn := Button.new()
		var prefix: String = "" if a.in_rotation else "◌ "
		btn.text = prefix + (a.display_name if a.display_name != "" else a.id)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (a == _selected)
		var a_ref: MenuArrangement = a
		btn.pressed.connect(func() -> void: _select_arrangement(a_ref))
		ThemeManager.apply_button_style(btn)
		_list_vbox.add_child(btn)
		_arrangement_buttons.append(btn)


func _select_arrangement(a: MenuArrangement) -> void:
	_timeline_editor._stop_audition()
	_selected = a
	for i in range(_arrangements.size()):
		_arrangement_buttons[i].button_pressed = (_arrangements[i] == a)
	_name_edit.text = a.display_name
	_bpm_spin.set_value_no_signal(a.bpm)
	_rotation_check.set_pressed_no_signal(a.in_rotation)
	_editor_header.text = "ARRANGEMENT — " + a.display_name
	_timeline_editor.set_data(a.tracks, a.bpm, a.duration_bars, true, "Master")
	_refresh_editor_enabled()


func _refresh_editor_enabled() -> void:
	var enabled: bool = _selected != null
	_name_edit.editable = enabled
	_bpm_spin.editable = enabled
	_rotation_check.disabled = not enabled
	if not enabled:
		_name_edit.text = ""
		_editor_header.text = "(no arrangement selected)"


func _save_selected() -> void:
	if not _selected:
		return
	MenuArrangementManager.save(_selected.id, _selected.to_dict())


func _on_new() -> void:
	var new_id: String = MenuArrangementManager.generate_id("arrangement")
	var data: Dictionary = {
		"id": new_id,
		"display_name": "New Arrangement",
		"bpm": 120.0,
		"duration_bars": 16,
		"tracks": [],
	}
	MenuArrangementManager.save(new_id, data)
	_load_arrangements()
	for a in _arrangements:
		if a.id == new_id:
			_select_arrangement(a)
			break


func _on_dupe() -> void:
	if not _selected:
		return
	var new_id: String = MenuArrangementManager.generate_id("arrangement")
	var data: Dictionary = _selected.to_dict()
	data["id"] = new_id
	data["display_name"] = _selected.display_name + " (copy)"
	MenuArrangementManager.save(new_id, data)
	_load_arrangements()
	for a in _arrangements:
		if a.id == new_id:
			_select_arrangement(a)
			break


func _on_delete() -> void:
	if not _selected:
		return
	MenuArrangementManager.delete(_selected.id)
	_selected = null
	_load_arrangements()
	if _arrangements.size() > 0:
		_select_arrangement(_arrangements[0])
	else:
		_timeline_editor.set_data([], 120.0, 16, true, "Master")
		_refresh_editor_enabled()


func _on_name_changed(new_text: String) -> void:
	if not _selected:
		return
	_selected.display_name = new_text
	_editor_header.text = "ARRANGEMENT — " + new_text
	# Update list button label
	for i in range(_arrangements.size()):
		if _arrangements[i] == _selected:
			_rebuild_list_label(i)
			break
	_save_selected()


func _on_bpm_changed(v: float) -> void:
	if not _selected:
		return
	_selected.bpm = v
	# Rebind so timeline header shows new BPM
	_timeline_editor.set_data(_selected.tracks, _selected.bpm, _selected.duration_bars, true, "Master")
	_save_selected()


func _on_rotation_toggled(pressed: bool) -> void:
	if not _selected:
		return
	_selected.in_rotation = pressed
	# Reflect on/off in list button label
	for i in range(_arrangements.size()):
		if _arrangements[i] == _selected:
			_rebuild_list_label(i)
			break
	_save_selected()


func _rebuild_list_label(i: int) -> void:
	var a: MenuArrangement = _arrangements[i]
	var prefix: String = "" if a.in_rotation else "◌ "
	_arrangement_buttons[i].text = prefix + (a.display_name if a.display_name != "" else a.id)


func _on_tracks_changed() -> void:
	_save_selected()


func _on_duration_changed(bars: int) -> void:
	if not _selected:
		return
	_selected.duration_bars = bars
	_save_selected()


# ── Theme / back ─────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_back() -> void:
	_timeline_editor._stop_audition()
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
