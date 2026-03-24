extends MarginContainer
## Buildings editor — create/edit destructible buildings with weapons and level assignment.

var _buildings: Array[BuildingData] = []
var _selected_id: String = ""
var _suppressing_signals: bool = false

# UI refs
var _list_container: VBoxContainer
var _create_btn: Button
var _delete_btn: Button
var _editor_panel: VBoxContainer
var _empty_label: Label

# Editor controls
var _name_edit: LineEdit
var _level_option: OptionButton
var _level_ids: Array[String] = []
var _hp_spin: SpinBox
var _destructible_check: CheckBox
var _weapons_container: VBoxContainer
var _add_weapon_btn: Button
var _weapon_ids_available: Array[String] = []


func _ready() -> void:
	_buildings = BuildingDataManager.load_all()
	_build_ui()

	if _buildings.size() > 0:
		_select_building(_buildings[0].id)
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
	header.text = "BUILDINGS"
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
	_name_edit = _add_field_row("Name", "LineEdit") as LineEdit
	_name_edit.text_changed.connect(_on_name_changed)

	# Level
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(level_row)
	var level_label := Label.new()
	level_label.text = "Level"
	level_label.custom_minimum_size.x = 100
	level_row.add_child(level_label)
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

	# Hitpoints
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(hp_row)
	var hp_label := Label.new()
	hp_label.text = "Hitpoints"
	hp_label.custom_minimum_size.x = 100
	hp_row.add_child(hp_label)
	_hp_spin = SpinBox.new()
	_hp_spin.min_value = 1.0
	_hp_spin.max_value = 10000.0
	_hp_spin.step = 10.0
	_hp_spin.value = 100.0
	_hp_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_spin.value_changed.connect(_on_hp_changed)
	hp_row.add_child(_hp_spin)

	# Destructible
	_destructible_check = CheckBox.new()
	_destructible_check.text = "Destructible"
	_destructible_check.button_pressed = true
	_destructible_check.toggled.connect(_on_destructible_toggled)
	_editor_panel.add_child(_destructible_check)

	# Weapons section
	var weapons_header := Label.new()
	weapons_header.text = "WEAPONS"
	weapons_header.name = "WeaponsHeader"
	_editor_panel.add_child(weapons_header)

	_weapons_container = VBoxContainer.new()
	_weapons_container.add_theme_constant_override("separation", 4)
	_editor_panel.add_child(_weapons_container)

	_add_weapon_btn = Button.new()
	_add_weapon_btn.text = "+ Add Weapon"
	_add_weapon_btn.pressed.connect(_on_add_weapon)
	_editor_panel.add_child(_add_weapon_btn)

	# Cache available weapon IDs
	_weapon_ids_available = WeaponDataManager.list_ids()

	# Empty state
	_empty_label = Label.new()
	_empty_label.text = "No buildings yet. Click + NEW to get started."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_panel.add_child(_empty_label)
	_empty_label.visible = false

	_rebuild_list()


func _add_field_row(label_text: String, _type: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


# ── List management ───────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	for b in _buildings:
		var btn := Button.new()
		btn.text = b.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (b.id == _selected_id)
		btn.pressed.connect(_on_list_pressed.bind(b.id))
		btn.name = "ListItem_" + b.id
		_list_container.add_child(btn)
		ThemeManager.apply_button_style(btn)
	_delete_btn.disabled = (_selected_id == "")


func _show_empty_state() -> void:
	_selected_id = ""
	_empty_label.visible = true
	_name_edit.get_parent().visible = false
	_level_option.get_parent().visible = false
	_hp_spin.get_parent().visible = false
	_destructible_check.visible = false
	_weapons_container.visible = false
	_add_weapon_btn.visible = false
	for child in _editor_panel.get_children():
		if child is Label and child.name == "WeaponsHeader":
			child.visible = false
	_delete_btn.disabled = true


func _show_editor_state() -> void:
	_empty_label.visible = false
	_name_edit.get_parent().visible = true
	_level_option.get_parent().visible = true
	_hp_spin.get_parent().visible = true
	_destructible_check.visible = true
	_weapons_container.visible = true
	_add_weapon_btn.visible = true
	for child in _editor_panel.get_children():
		if child is Label and child.name == "WeaponsHeader":
			child.visible = true


func _select_building(id: String) -> void:
	_selected_id = id
	_show_editor_state()
	var data: BuildingData = _get_by_id(id)
	if not data:
		_show_empty_state()
		return

	_suppressing_signals = true
	_name_edit.text = data.display_name

	if data.level_id == "" or data.level_id not in _level_ids:
		_level_option.selected = 0
	else:
		_level_option.selected = _level_ids.find(data.level_id) + 1

	_hp_spin.value = data.hitpoints
	_destructible_check.button_pressed = data.destructible
	_rebuild_weapons_list(data)
	_suppressing_signals = false
	_rebuild_list()


func _rebuild_weapons_list(data: BuildingData) -> void:
	for child in _weapons_container.get_children():
		child.queue_free()
	for i in range(data.weapon_ids.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for wid in _weapon_ids_available:
			option.add_item(wid)
		var idx: int = _weapon_ids_available.find(data.weapon_ids[i])
		if idx >= 0:
			option.selected = idx
		option.item_selected.connect(_on_weapon_slot_changed.bind(i))
		row.add_child(option)
		var remove_btn := Button.new()
		remove_btn.text = "X"
		remove_btn.pressed.connect(_on_remove_weapon.bind(i))
		row.add_child(remove_btn)
		_weapons_container.add_child(row)


# ── Helpers ───────────────────────────────────────────────────────────────

func _get_by_id(id: String) -> BuildingData:
	for b in _buildings:
		if b.id == id:
			return b
	return null


func _generate_id() -> String:
	var existing: Array[String] = []
	for b in _buildings:
		existing.append(b.id)
	var counter: int = 1
	while true:
		var candidate: String = "building_" + str(counter)
		if candidate not in existing:
			return candidate
		counter += 1
	return "building_1"


func _auto_save() -> void:
	var data: BuildingData = _get_by_id(_selected_id)
	if data:
		BuildingDataManager.save(data)


# ── Signals ───────────────────────────────────────────────────────────────

func _on_create() -> void:
	var id: String = _generate_id()
	var data := BuildingData.new()
	data.id = id
	data.display_name = "Building " + str(_buildings.size() + 1)
	BuildingDataManager.save(data)
	_buildings.append(data)
	_rebuild_list()
	_select_building(id)


func _on_delete() -> void:
	if _selected_id == "":
		return
	BuildingDataManager.delete(_selected_id)
	var idx: int = -1
	for i in range(_buildings.size()):
		if _buildings[i].id == _selected_id:
			idx = i
			break
	if idx >= 0:
		_buildings.remove_at(idx)
	if _buildings.size() > 0:
		_rebuild_list()
		_select_building(_buildings[mini(idx, _buildings.size() - 1)].id)
	else:
		_selected_id = ""
		_rebuild_list()
		_show_empty_state()


func _on_list_pressed(id: String) -> void:
	_select_building(id)


func _on_name_changed(new_name: String) -> void:
	if _suppressing_signals:
		return
	var data: BuildingData = _get_by_id(_selected_id)
	if data:
		data.display_name = new_name
		_auto_save()
		for child in _list_container.get_children():
			if child is Button and child.name == "ListItem_" + _selected_id:
				child.text = new_name


func _on_level_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: BuildingData = _get_by_id(_selected_id)
	if data:
		data.level_id = "" if idx <= 0 else _level_ids[idx - 1]
		_auto_save()


func _on_hp_changed(val: float) -> void:
	if _suppressing_signals:
		return
	var data: BuildingData = _get_by_id(_selected_id)
	if data:
		data.hitpoints = val
		_auto_save()


func _on_destructible_toggled(toggled_on: bool) -> void:
	if _suppressing_signals:
		return
	var data: BuildingData = _get_by_id(_selected_id)
	if data:
		data.destructible = toggled_on
		_auto_save()


func _on_add_weapon() -> void:
	var data: BuildingData = _get_by_id(_selected_id)
	if not data:
		return
	var first_id: String = _weapon_ids_available[0] if _weapon_ids_available.size() > 0 else ""
	data.weapon_ids.append(first_id)
	_auto_save()
	_rebuild_weapons_list(data)


func _on_weapon_slot_changed(option_idx: int, slot_idx: int) -> void:
	if _suppressing_signals:
		return
	var data: BuildingData = _get_by_id(_selected_id)
	if data and slot_idx < data.weapon_ids.size():
		data.weapon_ids[slot_idx] = _weapon_ids_available[option_idx]
		_auto_save()


func _on_remove_weapon(slot_idx: int) -> void:
	var data: BuildingData = _get_by_id(_selected_id)
	if data and slot_idx < data.weapon_ids.size():
		data.weapon_ids.remove_at(slot_idx)
		_auto_save()
		_rebuild_weapons_list(data)


func _apply_theme() -> void:
	ThemeManager.apply_button_style(_create_btn)
	ThemeManager.apply_button_style(_delete_btn)
	ThemeManager.apply_button_style(_add_weapon_btn)
	ThemeManager.apply_button_style(_destructible_check)
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
