extends MarginContainer
## Ship Builder — grid-based ship editor with line drawing, hardpoint placement, and stats.

const SHIP_TYPES: Array[String] = ["player", "enemy"]

# UI references
var _name_input: LineEdit
var _type_button: OptionButton
var _grid_w_spin: SpinBox
var _grid_h_spin: SpinBox
var _hull_slider: HSlider
var _hull_label: Label
var _shield_slider: HSlider
var _shield_label: Label
var _speed_slider: HSlider
var _speed_label: Label
var _generator_slider: HSlider
var _generator_label: Label
var _mode_button: OptionButton
var _mirror_button: Button
var _line_color_picker: ColorPickerButton
var _canvas: ShipCanvas
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _status_label: Label
var _hp_count_label: Label

# Hardpoint edit popup
var _hp_popup: PopupPanel
var _hp_edit_index: int = -1
var _hp_label_input: LineEdit
var _hp_dir_slider: HSlider
var _hp_dir_label: Label

# State
var _current_id: String = ""


func _ready() -> void:
	_build_ui()
	_refresh_load_list()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var load_label := Label.new()
	load_label.text = "Load:"
	top_bar.add_child(load_label)

	_load_button = OptionButton.new()
	_load_button.custom_minimum_size.x = 250
	_load_button.item_selected.connect(_on_load_selected)
	top_bar.add_child(_load_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "DELETE"
	_delete_button.pressed.connect(_on_delete)
	top_bar.add_child(_delete_button)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.pressed.connect(_on_new)
	top_bar.add_child(new_btn)

	# Main split
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 500
	root.add_child(split)

	# Left: canvas area
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_vbox)

	# Toolbar
	var toolbar := HBoxContainer.new()
	left_vbox.add_child(toolbar)

	_mode_button = OptionButton.new()
	_mode_button.add_item("Draw Lines")
	_mode_button.add_item("Place Hardpoints")
	_mode_button.item_selected.connect(_on_mode_changed)
	toolbar.add_child(_mode_button)

	_mirror_button = Button.new()
	_mirror_button.text = "MIRROR: OFF"
	_mirror_button.pressed.connect(_on_mirror_toggle)
	toolbar.add_child(_mirror_button)

	_line_color_picker = ColorPickerButton.new()
	_line_color_picker.color = Color.CYAN
	_line_color_picker.custom_minimum_size = Vector2(60, 30)
	_line_color_picker.color_changed.connect(_on_line_color_changed)
	toolbar.add_child(_line_color_picker)

	_canvas = ShipCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.lines_changed.connect(_on_canvas_lines_changed)
	_canvas.hardpoints_changed.connect(_on_canvas_hardpoints_changed)
	_canvas.hardpoint_edit_requested.connect(_on_hardpoint_edit_requested)
	left_vbox.add_child(_canvas)

	# Right: form
	var form_panel := _build_form_panel()
	split.add_child(form_panel)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE SHIP"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)

	# Hardpoint edit popup
	_build_hp_popup(root)


func _build_form_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Ship Name
	_add_section_header(form, "SHIP NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter ship name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_name_input)

	_add_separator(form)

	# Ship Type
	_add_section_header(form, "SHIP TYPE")
	_type_button = OptionButton.new()
	_type_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in SHIP_TYPES:
		_type_button.add_item(t)
	form.add_child(_type_button)

	_add_separator(form)

	# Grid Size
	_add_section_header(form, "GRID SIZE")
	var grid_row := HBoxContainer.new()
	form.add_child(grid_row)

	var w_label := Label.new()
	w_label.text = "Width:"
	w_label.custom_minimum_size.x = 50
	grid_row.add_child(w_label)

	_grid_w_spin = SpinBox.new()
	_grid_w_spin.min_value = 8
	_grid_w_spin.max_value = 64
	_grid_w_spin.value = 32
	_grid_w_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_w_spin.value_changed.connect(_on_grid_size_changed)
	grid_row.add_child(_grid_w_spin)

	var h_label := Label.new()
	h_label.text = "Height:"
	h_label.custom_minimum_size.x = 50
	grid_row.add_child(h_label)

	_grid_h_spin = SpinBox.new()
	_grid_h_spin.min_value = 8
	_grid_h_spin.max_value = 64
	_grid_h_spin.value = 32
	_grid_h_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_h_spin.value_changed.connect(_on_grid_size_changed)
	grid_row.add_child(_grid_h_spin)

	_add_separator(form)

	# Ship Stats
	_add_section_header(form, "SHIP STATS")
	var hull_row := _add_slider_row(form, "Hull:", 10, 500, 100, 5)
	_hull_slider = hull_row[0]
	_hull_label = hull_row[1]

	var shield_row := _add_slider_row(form, "Shield:", 0, 300, 50, 5)
	_shield_slider = shield_row[0]
	_shield_label = shield_row[1]

	var speed_row := _add_slider_row(form, "Speed:", 50, 800, 400, 10)
	_speed_slider = speed_row[0]
	_speed_label = speed_row[1]

	var gen_row := _add_slider_row(form, "Generator:", 1, 50, 10, 1)
	_generator_slider = gen_row[0]
	_generator_label = gen_row[1]

	_add_separator(form)

	# Hardpoints info
	_add_section_header(form, "HARDPOINTS")
	_hp_count_label = Label.new()
	_hp_count_label.text = "0 hardpoints placed"
	form.add_child(_hp_count_label)

	return scroll


func _build_hp_popup(parent: Control) -> void:
	_hp_popup = PopupPanel.new()
	_hp_popup.size = Vector2i(280, 180)
	parent.add_child(_hp_popup)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_popup.add_child(vbox)

	var title := Label.new()
	title.text = "Edit Hardpoint"
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(title)

	var label_row := HBoxContainer.new()
	vbox.add_child(label_row)
	var lbl := Label.new()
	lbl.text = "Label:"
	lbl.custom_minimum_size.x = 60
	label_row.add_child(lbl)
	_hp_label_input = LineEdit.new()
	_hp_label_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(_hp_label_input)

	var dir_row := HBoxContainer.new()
	vbox.add_child(dir_row)
	var dir_lbl := Label.new()
	dir_lbl.text = "Direction:"
	dir_lbl.custom_minimum_size.x = 60
	dir_row.add_child(dir_lbl)
	_hp_dir_slider = HSlider.new()
	_hp_dir_slider.min_value = 0
	_hp_dir_slider.max_value = 360
	_hp_dir_slider.step = 5
	_hp_dir_slider.value = 0
	_hp_dir_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_dir_slider.custom_minimum_size.x = 120
	dir_row.add_child(_hp_dir_slider)
	_hp_dir_label = Label.new()
	_hp_dir_label.text = "0°"
	_hp_dir_label.custom_minimum_size.x = 40
	dir_row.add_child(_hp_dir_label)
	_hp_dir_slider.value_changed.connect(func(val: float) -> void:
		_hp_dir_label.text = str(int(val)) + "°"
	)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.pressed.connect(_on_hp_popup_ok)
	btn_row.add_child(ok_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(_on_hp_popup_delete)
	btn_row.add_child(del_btn)


# ── UI Helpers ──────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


func _add_slider_row(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, step_val: float) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(int(default_val))
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		if step_val >= 1.0:
			value_label.text = str(int(val))
		else:
			value_label.text = "%.2f" % val
	)

	return [slider, value_label]


# ── Data Collection ─────────────────────────────────────────

func _collect_ship_data() -> Dictionary:
	return {
		"id": _current_id if _current_id != "" else _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"type": _type_button.get_item_text(_type_button.selected),
		"grid_size": [int(_grid_w_spin.value), int(_grid_h_spin.value)],
		"lines": _canvas.lines.duplicate(true),
		"hardpoints": _canvas.hardpoints.duplicate(true),
		"stats": {
			"hull_max": int(_hull_slider.value),
			"shield_max": int(_shield_slider.value),
			"speed": int(_speed_slider.value),
			"generator_power": int(_generator_slider.value),
		},
	}


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "ship_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower()
	id = id.replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "ship_" + str(randi() % 10000)
	return "ship_" + clean


# ── Events ──────────────────────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a ship name first!"
		return
	var data: Dictionary = _collect_ship_data()
	var id: String = str(data["id"])
	_current_id = id
	ShipDataManager.save(id, data)
	_status_label.text = "Saved: " + id
	_refresh_load_list()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var ship: ShipData = ShipDataManager.load_by_id(id)
	if not ship:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_ship(ship)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No ship loaded to delete."
		return
	ShipDataManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_name_input.text = ""
	_type_button.selected = 0
	_grid_w_spin.value = 32
	_grid_h_spin.value = 32
	_hull_slider.value = 100
	_shield_slider.value = 50
	_speed_slider.value = 400
	_generator_slider.value = 10
	_canvas.set_lines([])
	_canvas.set_hardpoints([])
	_canvas.set_grid_size(Vector2i(32, 32))
	_canvas.set_mirror(false)
	_mirror_button.text = "MIRROR: OFF"
	_mode_button.selected = 0
	_canvas.mode = ShipCanvas.Mode.DRAW_LINE
	_line_color_picker.color = Color.CYAN
	_canvas.set_line_color("#00FFFF")
	_hp_count_label.text = "0 hardpoints placed"
	_status_label.text = "New ship — ready to edit."


func _on_mode_changed(idx: int) -> void:
	if idx == 0:
		_canvas.mode = ShipCanvas.Mode.DRAW_LINE
	else:
		_canvas.mode = ShipCanvas.Mode.PLACE_HARDPOINT


func _on_mirror_toggle() -> void:
	_canvas.mirror_enabled = not _canvas.mirror_enabled
	_mirror_button.text = "MIRROR: ON" if _canvas.mirror_enabled else "MIRROR: OFF"
	_canvas.queue_redraw()


func _on_line_color_changed(color: Color) -> void:
	_canvas.set_line_color("#" + color.to_html(false))


func _on_grid_size_changed(_val: float) -> void:
	var new_size: Vector2i = Vector2i(int(_grid_w_spin.value), int(_grid_h_spin.value))
	_canvas.set_grid_size(new_size)


func _on_canvas_lines_changed() -> void:
	pass  # Could add status update here


func _on_canvas_hardpoints_changed() -> void:
	_hp_count_label.text = str(_canvas.hardpoints.size()) + " hardpoints placed"


func _on_hardpoint_edit_requested(index: int, screen_pos: Vector2) -> void:
	if index < 0 or index >= _canvas.hardpoints.size():
		return
	_hp_edit_index = index
	var hp: Dictionary = _canvas.hardpoints[index]
	_hp_label_input.text = str(hp.get("label", ""))
	_hp_dir_slider.value = float(hp.get("direction_deg", 0.0))
	_hp_dir_label.text = str(int(_hp_dir_slider.value)) + "°"
	_hp_popup.popup(Rect2i(Vector2i(int(screen_pos.x), int(screen_pos.y)), Vector2i(280, 180)))


func _on_hp_popup_ok() -> void:
	if _hp_edit_index >= 0 and _hp_edit_index < _canvas.hardpoints.size():
		var hp: Dictionary = _canvas.hardpoints[_hp_edit_index]
		hp["label"] = _hp_label_input.text
		hp["direction_deg"] = _hp_dir_slider.value
		_canvas.hardpoints[_hp_edit_index] = hp
		_canvas.queue_redraw()
	_hp_popup.hide()


func _on_hp_popup_delete() -> void:
	if _hp_edit_index >= 0 and _hp_edit_index < _canvas.hardpoints.size():
		_canvas.hardpoints.remove_at(_hp_edit_index)
		_canvas.queue_redraw()
		_hp_count_label.text = str(_canvas.hardpoints.size()) + " hardpoints placed"
	_hp_popup.hide()


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select ship)")
	var ids: Array[String] = ShipDataManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_ship(ship: ShipData) -> void:
	_current_id = ship.id
	_name_input.text = ship.display_name

	var type_idx: int = SHIP_TYPES.find(ship.type)
	_type_button.selected = type_idx if type_idx >= 0 else 0

	_grid_w_spin.value = ship.grid_size.x
	_grid_h_spin.value = ship.grid_size.y

	var stats: Dictionary = ship.stats
	_hull_slider.value = float(stats.get("hull_max", 100))
	_shield_slider.value = float(stats.get("shield_max", 50))
	_speed_slider.value = float(stats.get("speed", 400))
	_generator_slider.value = float(stats.get("generator_power", 10))

	_canvas.set_grid_size(ship.grid_size)
	_canvas.set_lines(ship.lines.duplicate(true))
	_canvas.set_hardpoints(ship.hardpoints.duplicate(true))

	_hp_count_label.text = str(_canvas.hardpoints.size()) + " hardpoints placed"
