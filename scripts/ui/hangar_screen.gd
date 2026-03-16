extends MarginContainer
## Hangar Screen — unified ship preview + grouped weapon/device buttons.
## Replaces the old ship_select → hardpoint_overview flow.

var _canvas: ShipCanvas
var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _generator_label: Label
var _hp_count_label: Label
var _device_slots_label: Label
var _ship_name_label: Label
var _right_vbox: VBoxContainer
var _weapon_section: VBoxContainer
var _device_section: VBoxContainer
var _title: Label
var _weapons_header: Label
var _devices_header: Label
var _change_ship_btn: Button
var _back_btn: Button
var _stat_labels: Array[Label] = []
var _vhs_overlay: ColorRect = null

var _ship: ShipData = null
var _weapon_cache: Dictionary = {}
var _device_cache: Dictionary = {}


func _ready() -> void:
	_cache_data()
	_build_ui()
	_auto_select_ship()
	_load_ship()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")


func _setup_vhs_overlay() -> void:
	var root_node: Node = get_parent() if get_parent() else self
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	root_node.add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _apply_theme() -> void:
	_apply_grid_bg()
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	var body_font: Font = ThemeManager.get_font("font_body")
	var header_font: Font = ThemeManager.get_font("font_header")

	# Title
	_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if header_font:
		_title.add_theme_font_override("font", header_font)
	ThemeManager.apply_text_glow(_title, "header")

	# Ship name
	_ship_name_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	_ship_name_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_title"))
	if body_font:
		_ship_name_label.add_theme_font_override("font", body_font)

	# Stat labels
	for lbl in _stat_labels:
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			lbl.add_theme_font_override("font", body_font)

	# Section headers
	_weapons_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_weapons_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		_weapons_header.add_theme_font_override("font", body_font)

	_devices_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_devices_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		_devices_header.add_theme_font_override("font", body_font)

	# Buttons
	ThemeManager.apply_button_style(_change_ship_btn)
	ThemeManager.apply_button_style(_back_btn)

	# Weapon/device buttons
	for child in _weapon_section.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)
	for child in _device_section.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)


func _apply_grid_bg() -> void:
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_node("Background"):
		var bg: ColorRect = parent_node.get_node("Background") as ColorRect
		if bg:
			ThemeManager.apply_grid_background(bg)


func _cache_data() -> void:
	var wids: Array[String] = WeaponDataManager.list_ids()
	for wid in wids:
		var w: WeaponData = WeaponDataManager.load_by_id(wid)
		if w:
			_weapon_cache[wid] = w
	var dids: Array[String] = DeviceDataManager.list_ids()
	for did in dids:
		var d: DeviceData = DeviceDataManager.load_by_id(did)
		if d:
			_device_cache[did] = d


func _auto_select_ship() -> void:
	if GameState.current_ship_id == "":
		var ids: Array[String] = ShipDataManager.list_ids()
		if ids.size() > 0:
			GameState.set_ship(ids[0])


func _load_ship() -> void:
	if GameState.current_ship_id == "":
		return
	_ship = ShipDataManager.load_by_id(GameState.current_ship_id)
	if not _ship:
		return
	_ship_name_label.text = _ship.display_name if _ship.display_name != "" else _ship.id
	_canvas.set_grid_size(_ship.grid_size)
	_canvas.set_lines(_ship.lines.duplicate(true))
	_canvas.set_hardpoints(_ship.hardpoints.duplicate(true))
	_update_stats()
	_rebuild_buttons()


func _update_stats() -> void:
	if not _ship:
		return
	var s: Dictionary = _ship.stats
	_hull_label.text = "Hull: " + str(int(s.get("hull_max", 100)))
	_shield_label.text = "Shield: " + str(int(s.get("shield_max", 50)))
	_speed_label.text = "Speed: " + str(int(s.get("speed", 400)))
	_generator_label.text = "Generator: " + str(int(s.get("generator_power", 10)))
	_hp_count_label.text = "Hardpoints: " + str(_ship.hardpoints.size())
	_device_slots_label.text = "Device Slots: " + str(int(s.get("device_slots", 2)))


func _rebuild_buttons() -> void:
	# Clear weapon section
	for child in _weapon_section.get_children():
		child.queue_free()
	# Clear device section
	for child in _device_section.get_children():
		child.queue_free()

	if not _ship:
		return

	# Weapon buttons (one per hardpoint)
	for hp in _ship.hardpoints:
		var hp_id: String = str(hp.get("id", ""))
		var hp_label: String = str(hp.get("label", hp_id))
		var config: Dictionary = GameState.hardpoint_config.get(hp_id, {})
		var weapon_id: String = str(config.get("weapon_id", ""))
		var weapon_name: String = "empty"
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				weapon_name = w.display_name if w.display_name != "" else w.id
			else:
				weapon_name = weapon_id

		var btn := Button.new()
		btn.text = hp_label + "  —  " + weapon_name
		btn.custom_minimum_size.y = 55
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(btn)
		var bound_hp_id: String = hp_id
		btn.pressed.connect(func() -> void:
			GameState._editing_hp_id = bound_hp_id
			get_tree().change_scene_to_file("res://scenes/ui/hardpoint_edit_screen.tscn")
		)
		_weapon_section.add_child(btn)

	# Device buttons
	var device_slots: int = int(_ship.stats.get("device_slots", 2))
	for i in device_slots:
		var slot_key: String = "slot_" + str(i)
		var device_id: String = str(GameState.device_config.get(slot_key, ""))
		var device_name: String = "empty"
		if device_id != "":
			var d: DeviceData = _device_cache.get(device_id)
			if d:
				device_name = d.display_name if d.display_name != "" else d.id
			else:
				device_name = device_id

		var btn := Button.new()
		btn.text = "SLOT " + str(i + 1) + "  —  " + device_name
		btn.custom_minimum_size.y = 50
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(btn)
		var bound_slot: int = i
		btn.pressed.connect(func() -> void:
			GameState._editing_device_slot = bound_slot
			get_tree().change_scene_to_file("res://scenes/ui/device_edit_screen.tscn")
		)
		_device_section.add_child(btn)


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# LEFT — ship preview + stats
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 400
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_vbox)

	_title = Label.new()
	_title.text = "HANGAR"
	left_vbox.add_child(_title)

	_ship_name_label = Label.new()
	_ship_name_label.text = ""
	left_vbox.add_child(_ship_name_label)

	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(canvas_panel)

	_canvas = ShipCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.display_only = true
	canvas_panel.add_child(_canvas)

	# Stats
	var stats_box := VBoxContainer.new()
	left_vbox.add_child(stats_box)

	_hull_label = Label.new()
	_hull_label.text = "Hull: —"
	stats_box.add_child(_hull_label)
	_stat_labels.append(_hull_label)

	_shield_label = Label.new()
	_shield_label.text = "Shield: —"
	stats_box.add_child(_shield_label)
	_stat_labels.append(_shield_label)

	_speed_label = Label.new()
	_speed_label.text = "Speed: —"
	stats_box.add_child(_speed_label)
	_stat_labels.append(_speed_label)

	_generator_label = Label.new()
	_generator_label.text = "Generator: —"
	stats_box.add_child(_generator_label)
	_stat_labels.append(_generator_label)

	_hp_count_label = Label.new()
	_hp_count_label.text = "Hardpoints: —"
	stats_box.add_child(_hp_count_label)
	_stat_labels.append(_hp_count_label)

	_device_slots_label = Label.new()
	_device_slots_label.text = "Device Slots: —"
	stats_box.add_child(_device_slots_label)
	_stat_labels.append(_device_slots_label)

	# RIGHT — grouped buttons
	_right_vbox = VBoxContainer.new()
	_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_right_vbox)

	_weapons_header = Label.new()
	_weapons_header.text = "━━ WEAPONS ━━━━━━━━"
	_right_vbox.add_child(_weapons_header)

	_weapon_section = VBoxContainer.new()
	_right_vbox.add_child(_weapon_section)

	_devices_header = Label.new()
	_devices_header.text = "━━ DEVICES ━━━━━━━━"
	_right_vbox.add_child(_devices_header)

	_device_section = VBoxContainer.new()
	_right_vbox.add_child(_device_section)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_vbox.add_child(spacer)

	_change_ship_btn = Button.new()
	_change_ship_btn.text = "CHANGE SHIP"
	_change_ship_btn.custom_minimum_size.y = 40
	_change_ship_btn.pressed.connect(_on_change_ship)
	_right_vbox.add_child(_change_ship_btn)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.custom_minimum_size.y = 40
	_back_btn.pressed.connect(_on_back)
	_right_vbox.add_child(_back_btn)


func _on_change_ship() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ship_select_screen.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		_on_back()
