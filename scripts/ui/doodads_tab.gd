extends MarginContainer
## Doodads editor — create/edit decorative objects with level assignment.
## No hitpoints, no weapons — just placement properties.
## NOTE: Doodad map placement is being actively troubleshot — this tab is
## definition-only for now, not wired to level placement.

var _doodads: Array[DoodadData] = []
var _selected_id: String = ""
var _suppressing_signals: bool = false

var _list_container: VBoxContainer
var _create_btn: Button
var _delete_btn: Button
var _editor_panel: VBoxContainer
var _empty_label: Label

var _name_edit: LineEdit
var _level_option: OptionButton
var _level_ids: Array[String] = []
var _type_option: OptionButton
var _type_ids: Array[String] = []
var _scale_spin: SpinBox


func _ready() -> void:
	_doodads = DoodadDataManager.load_all()
	_build_ui()

	if _doodads.size() > 0:
		_select_doodad(_doodads[0].id)
	else:
		_show_empty_state()

	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")


func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = -200
	add_child(split)

	# --- Left: list ---
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size.x = 200
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.35
	left_panel.add_theme_constant_override("separation", 8)
	split.add_child(left_panel)

	var header := Label.new()
	header.text = "DOODADS"
	header.name = "ListHeader"
	left_panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_container)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	left_panel.add_child(btn_row)

	_create_btn = Button.new()
	_create_btn.text = "+ NEW"
	_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_btn.pressed.connect(_on_create)
	btn_row.add_child(_create_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "DELETE"
	_delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete)
	btn_row.add_child(_delete_btn)

	# --- Right: editor ---
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 0.65
	split.add_child(right_scroll)

	_editor_panel = VBoxContainer.new()
	_editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_panel.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_editor_panel)

	# Name
	var name_row := _make_row("Name")
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)

	# Level
	var level_row := _make_row("Level")
	_level_option = OptionButton.new()
	_level_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_option.add_item("(none)")
	_level_ids.clear()
	var all_levels: Array[String] = LevelDataManager.list_ids()
	for lid in all_levels:
		_level_ids.append(lid)
		var ldata: LevelData = LevelDataManager.load_by_id(lid)
		var lname: String = ldata.display_name if ldata else lid
		_level_option.add_item(lname)
	_level_option.item_selected.connect(_on_level_changed)
	level_row.add_child(_level_option)

	# Doodad type (from DoodadRegistry)
	var type_row := _make_row("Type")
	_type_option = OptionButton.new()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_ids = DoodadRegistry.get_type_ids()
	for tid in _type_ids:
		_type_option.add_item(DoodadRegistry.get_display_name(tid))
	_type_option.item_selected.connect(_on_type_changed)
	type_row.add_child(_type_option)

	# Scale
	var scale_row := _make_row("Scale")
	_scale_spin = SpinBox.new()
	_scale_spin.min_value = 0.1
	_scale_spin.max_value = 10.0
	_scale_spin.step = 0.1
	_scale_spin.value = 1.0
	_scale_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_spin.value_changed.connect(_on_scale_changed)
	scale_row.add_child(_scale_spin)

	# Empty state
	_empty_label = Label.new()
	_empty_label.text = "No doodads yet. Click + NEW to get started."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_panel.add_child(_empty_label)
	_empty_label.visible = false

	_rebuild_list()


func _make_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100
	row.add_child(label)
	return row


# ── List ──────────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	for d in _doodads:
		var btn := Button.new()
		btn.text = d.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (d.id == _selected_id)
		btn.pressed.connect(_on_list_pressed.bind(d.id))
		btn.name = "ListItem_" + d.id
		_list_container.add_child(btn)
		ThemeManager.apply_button_style(btn)
	_delete_btn.disabled = (_selected_id == "")


func _show_empty_state() -> void:
	_selected_id = ""
	_empty_label.visible = true
	for child in _editor_panel.get_children():
		if child != _empty_label:
			child.visible = false
	_delete_btn.disabled = true


func _show_editor_state() -> void:
	_empty_label.visible = false
	for child in _editor_panel.get_children():
		if child != _empty_label:
			child.visible = true


func _select_doodad(id: String) -> void:
	_selected_id = id
	_show_editor_state()
	var data: DoodadData = _get_by_id(id)
	if not data:
		_show_empty_state()
		return

	_suppressing_signals = true
	_name_edit.text = data.display_name

	if data.level_id == "" or data.level_id not in _level_ids:
		_level_option.selected = 0
	else:
		_level_option.selected = _level_ids.find(data.level_id) + 1

	var type_idx: int = _type_ids.find(data.doodad_type)
	_type_option.selected = maxi(type_idx, 0)

	_scale_spin.value = data.scale
	_suppressing_signals = false
	_rebuild_list()


func _get_by_id(id: String) -> DoodadData:
	for d in _doodads:
		if d.id == id:
			return d
	return null


func _generate_id() -> String:
	var existing: Array[String] = []
	for d in _doodads:
		existing.append(d.id)
	var counter: int = 1
	while true:
		var candidate: String = "doodad_" + str(counter)
		if candidate not in existing:
			return candidate
		counter += 1
	return "doodad_1"


func _auto_save() -> void:
	var data: DoodadData = _get_by_id(_selected_id)
	if data:
		DoodadDataManager.save(data)


# ── Signals ───────────────────────────────────────────────────────────────

func _on_create() -> void:
	var id: String = _generate_id()
	var data := DoodadData.new()
	data.id = id
	data.display_name = "Doodad " + str(_doodads.size() + 1)
	data.doodad_type = _type_ids[0] if _type_ids.size() > 0 else ""
	DoodadDataManager.save(data)
	_doodads.append(data)
	_rebuild_list()
	_select_doodad(id)


func _on_delete() -> void:
	if _selected_id == "":
		return
	DoodadDataManager.delete(_selected_id)
	var idx: int = -1
	for i in range(_doodads.size()):
		if _doodads[i].id == _selected_id:
			idx = i
			break
	if idx >= 0:
		_doodads.remove_at(idx)
	if _doodads.size() > 0:
		_rebuild_list()
		_select_doodad(_doodads[mini(idx, _doodads.size() - 1)].id)
	else:
		_selected_id = ""
		_rebuild_list()
		_show_empty_state()


func _on_list_pressed(id: String) -> void:
	_select_doodad(id)


func _on_name_changed(new_name: String) -> void:
	if _suppressing_signals:
		return
	var data: DoodadData = _get_by_id(_selected_id)
	if data:
		data.display_name = new_name
		_auto_save()
		for child in _list_container.get_children():
			if child is Button and child.name == "ListItem_" + _selected_id:
				child.text = new_name


func _on_level_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: DoodadData = _get_by_id(_selected_id)
	if data:
		data.level_id = "" if idx <= 0 else _level_ids[idx - 1]
		_auto_save()


func _on_type_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: DoodadData = _get_by_id(_selected_id)
	if data and idx < _type_ids.size():
		data.doodad_type = _type_ids[idx]
		_auto_save()


func _on_scale_changed(val: float) -> void:
	if _suppressing_signals:
		return
	var data: DoodadData = _get_by_id(_selected_id)
	if data:
		data.scale = val
		_auto_save()


func _apply_theme() -> void:
	ThemeManager.apply_button_style(_create_btn)
	ThemeManager.apply_button_style(_delete_btn)
	for child in _list_container.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child)
	for child in _editor_panel.get_children():
		if child is Label:
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")
