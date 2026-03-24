extends MarginContainer
## Items editor — create/edit powerups and money pickups.

const CATEGORIES: Array[String] = ["powerup", "money"]
const EFFECT_TYPES: Array[String] = [
	"shield_restore", "hull_repair", "speed_boost", "damage_boost",
	"thermal_dump", "electric_charge", "invincibility", "magnet",
]

var _items: Array[ItemData] = []
var _selected_id: String = ""
var _suppressing_signals: bool = false

var _list_container: VBoxContainer
var _create_btn: Button
var _delete_btn: Button
var _editor_panel: VBoxContainer
var _empty_label: Label

var _name_edit: LineEdit
var _category_option: OptionButton
var _value_spin: SpinBox
var _value_label: Label  # "Value" for money, "Strength" for powerup
var _duration_spin: SpinBox
var _duration_row: HBoxContainer
var _effect_option: OptionButton
var _effect_row: HBoxContainer


func _ready() -> void:
	_items = ItemDataManager.load_all()
	_build_ui()

	if _items.size() > 0:
		_select_item(_items[0].id)
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
	header.text = "ITEMS"
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

	# Category
	var cat_row := _make_row("Category")
	_category_option = OptionButton.new()
	_category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cat in CATEGORIES:
		_category_option.add_item(cat.capitalize())
	_category_option.item_selected.connect(_on_category_changed)
	cat_row.add_child(_category_option)

	# Effect type (powerups only)
	_effect_row = _make_row("Effect")
	_effect_option = OptionButton.new()
	_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for eff in EFFECT_TYPES:
		_effect_option.add_item(eff.replace("_", " ").capitalize())
	_effect_option.item_selected.connect(_on_effect_changed)
	_effect_row.add_child(_effect_option)

	# Value
	var value_row := _make_row("Value")
	_value_label = value_row.get_child(0) as Label
	_value_spin = SpinBox.new()
	_value_spin.min_value = 0.0
	_value_spin.max_value = 10000.0
	_value_spin.step = 10.0
	_value_spin.value = 100.0
	_value_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value_spin.value_changed.connect(_on_value_changed)
	value_row.add_child(_value_spin)

	# Duration (powerups only)
	_duration_row = _make_row("Duration (s)")
	_duration_spin = SpinBox.new()
	_duration_spin.min_value = 0.0
	_duration_spin.max_value = 60.0
	_duration_spin.step = 0.5
	_duration_spin.value = 5.0
	_duration_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_duration_spin.value_changed.connect(_on_duration_changed)
	_duration_row.add_child(_duration_spin)

	# Empty state
	_empty_label = Label.new()
	_empty_label.text = "No items yet. Click + NEW to get started."
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


func _update_category_visibility(cat: String) -> void:
	var is_powerup: bool = (cat == "powerup")
	_effect_row.visible = is_powerup
	_duration_row.visible = is_powerup
	_value_label.text = "Strength" if is_powerup else "Value"


# ── List ──────────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	for item in _items:
		var btn := Button.new()
		var prefix: String = "[P] " if item.category == "powerup" else "[$] "
		btn.text = prefix + item.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (item.id == _selected_id)
		btn.pressed.connect(_on_list_pressed.bind(item.id))
		btn.name = "ListItem_" + item.id
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


func _select_item(id: String) -> void:
	_selected_id = id
	_show_editor_state()
	var data: ItemData = _get_by_id(id)
	if not data:
		_show_empty_state()
		return

	_suppressing_signals = true
	_name_edit.text = data.display_name

	var cat_idx: int = CATEGORIES.find(data.category)
	_category_option.selected = maxi(cat_idx, 0)
	_update_category_visibility(data.category)

	var eff_idx: int = EFFECT_TYPES.find(data.effect_type)
	_effect_option.selected = maxi(eff_idx, 0)

	_value_spin.value = data.value
	_duration_spin.value = data.duration
	_suppressing_signals = false
	_rebuild_list()


func _get_by_id(id: String) -> ItemData:
	for item in _items:
		if item.id == id:
			return item
	return null


func _generate_id() -> String:
	var existing: Array[String] = []
	for item in _items:
		existing.append(item.id)
	var counter: int = 1
	while true:
		var candidate: String = "item_" + str(counter)
		if candidate not in existing:
			return candidate
		counter += 1
	return "item_1"


func _auto_save() -> void:
	var data: ItemData = _get_by_id(_selected_id)
	if data:
		ItemDataManager.save(data)


# ── Signals ───────────────────────────────────────────────────────────────

func _on_create() -> void:
	var id: String = _generate_id()
	var data := ItemData.new()
	data.id = id
	data.display_name = "Item " + str(_items.size() + 1)
	data.category = "powerup"
	data.value = 100.0
	ItemDataManager.save(data)
	_items.append(data)
	_rebuild_list()
	_select_item(id)


func _on_delete() -> void:
	if _selected_id == "":
		return
	ItemDataManager.delete(_selected_id)
	var idx: int = -1
	for i in range(_items.size()):
		if _items[i].id == _selected_id:
			idx = i
			break
	if idx >= 0:
		_items.remove_at(idx)
	if _items.size() > 0:
		_rebuild_list()
		_select_item(_items[mini(idx, _items.size() - 1)].id)
	else:
		_selected_id = ""
		_rebuild_list()
		_show_empty_state()


func _on_list_pressed(id: String) -> void:
	_select_item(id)


func _on_name_changed(new_name: String) -> void:
	if _suppressing_signals:
		return
	var data: ItemData = _get_by_id(_selected_id)
	if data:
		data.display_name = new_name
		_auto_save()
		_rebuild_list()


func _on_category_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: ItemData = _get_by_id(_selected_id)
	if data:
		data.category = CATEGORIES[idx]
		_update_category_visibility(data.category)
		_auto_save()
		_rebuild_list()


func _on_effect_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: ItemData = _get_by_id(_selected_id)
	if data:
		data.effect_type = EFFECT_TYPES[idx]
		_auto_save()


func _on_value_changed(val: float) -> void:
	if _suppressing_signals:
		return
	var data: ItemData = _get_by_id(_selected_id)
	if data:
		data.value = val
		_auto_save()


func _on_duration_changed(val: float) -> void:
	if _suppressing_signals:
		return
	var data: ItemData = _get_by_id(_selected_id)
	if data:
		data.duration = val
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
