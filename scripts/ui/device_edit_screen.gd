extends MarginContainer
## Device Edit Screen — pick a device for a slot. Shows ship stats with device modifiers.

var _canvas: ShipCanvas
var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _generator_label: Label
var _slot_title: Label
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_desc: Label
var _detail_stats: Label
var _device_container: VBoxContainer
var _device_buttons: Array = []

var _slot: int = -1
var _ship: ShipData = null
var _devices: Array[DeviceData] = []
var _selected_device_id: String = ""


func _ready() -> void:
	_slot = GameState._editing_device_slot
	if _slot < 0:
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return
	_build_ui()
	_load_data()


func _load_data() -> void:
	_ship = ShipDataManager.load_by_id(GameState.current_ship_id)
	if not _ship:
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return

	_canvas.set_grid_size(_ship.grid_size)
	_canvas.set_lines(_ship.lines.duplicate(true))
	_canvas.set_hardpoints(_ship.hardpoints.duplicate(true))

	_slot_title.text = "SLOT " + str(_slot + 1)

	_devices = DeviceDataManager.load_all()
	_selected_device_id = str(GameState.device_config.get("slot_" + str(_slot), ""))

	_rebuild_device_list()
	_update_stats()
	_update_detail()


func _rebuild_device_list() -> void:
	for child in _device_container.get_children():
		child.queue_free()
	_device_buttons.clear()

	# "(none)" button
	var none_btn := Button.new()
	none_btn.text = "(none)"
	none_btn.custom_minimum_size.y = 40
	none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	none_btn.pressed.connect(func() -> void:
		_on_device_selected("")
	)
	_device_container.add_child(none_btn)
	_device_buttons.append({"button": none_btn, "id": ""})

	for dev in _devices:
		var type_badge: String = "GEN" if dev.type == "generator" else "SHLD"
		var stats_text: String = ""
		for key in dev.stats_modifiers:
			var val: int = int(dev.stats_modifiers[key])
			stats_text += " +" + str(val) + " " + str(key).replace("_", " ")

		var btn := Button.new()
		btn.text = "[" + type_badge + "] " + dev.display_name + stats_text
		btn.custom_minimum_size.y = 45
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bound_id: String = dev.id
		btn.pressed.connect(func() -> void:
			_on_device_selected(bound_id)
		)
		_device_container.add_child(btn)
		_device_buttons.append({"button": btn, "id": dev.id})

	_update_button_highlights()


func _on_device_selected(device_id: String) -> void:
	_selected_device_id = device_id
	GameState.set_device(_slot, device_id)
	_update_button_highlights()
	_update_stats()
	_update_detail()


func _update_button_highlights() -> void:
	for entry in _device_buttons:
		var btn: Button = entry["button"]
		var did: String = str(entry["id"])
		if did == _selected_device_id:
			btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		else:
			btn.remove_theme_color_override("font_color")


func _update_stats() -> void:
	if not _ship:
		return
	var s: Dictionary = _ship.stats
	var hull_mod: int = 0
	var shield_mod: int = 0
	var speed_mod: int = 0
	var gen_mod: int = 0

	# Sum all device modifiers
	for slot_key in GameState.device_config:
		var did: String = str(GameState.device_config[slot_key])
		if did == "":
			continue
		var dev: DeviceData = DeviceDataManager.load_by_id(did)
		if dev:
			hull_mod += int(dev.stats_modifiers.get("hull_max", 0))
			shield_mod += int(dev.stats_modifiers.get("shield_max", 0))
			speed_mod += int(dev.stats_modifiers.get("speed", 0))
			gen_mod += int(dev.stats_modifiers.get("generator_power", 0))

	var base_hull: int = int(s.get("hull_max", 100))
	var base_shield: int = int(s.get("shield_max", 50))
	var base_speed: int = int(s.get("speed", 400))
	var base_gen: int = int(s.get("generator_power", 10))

	_hull_label.text = "Hull: " + str(base_hull) + (_fmt_mod(hull_mod))
	_shield_label.text = "Shield: " + str(base_shield) + (_fmt_mod(shield_mod))
	_speed_label.text = "Speed: " + str(base_speed) + (_fmt_mod(speed_mod))
	_generator_label.text = "Generator: " + str(base_gen) + (_fmt_mod(gen_mod))


func _fmt_mod(val: int) -> String:
	if val > 0:
		return " (+" + str(val) + ")"
	elif val < 0:
		return " (" + str(val) + ")"
	return ""


func _update_detail() -> void:
	if _selected_device_id == "":
		_detail_name.text = "(no device)"
		_detail_desc.text = ""
		_detail_stats.text = ""
		return
	var dev: DeviceData = DeviceDataManager.load_by_id(_selected_device_id)
	if not dev:
		_detail_name.text = _selected_device_id
		_detail_desc.text = ""
		_detail_stats.text = ""
		return
	_detail_name.text = dev.display_name
	_detail_desc.text = dev.description
	var stats_lines: String = ""
	for key in dev.stats_modifiers:
		var val: int = int(dev.stats_modifiers[key])
		stats_lines += str(key).replace("_", " ") + ": +" + str(val) + "\n"
	_detail_stats.text = stats_lines


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# LEFT — ship preview + stats
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 350
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_vbox)

	var title := Label.new()
	title.text = "DEVICES"
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	left_vbox.add_child(title)

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

	var stats_box := VBoxContainer.new()
	left_vbox.add_child(stats_box)

	_hull_label = Label.new()
	_hull_label.text = "Hull: —"
	stats_box.add_child(_hull_label)

	_shield_label = Label.new()
	_shield_label.text = "Shield: —"
	stats_box.add_child(_shield_label)

	_speed_label = Label.new()
	_speed_label.text = "Speed: —"
	stats_box.add_child(_speed_label)

	_generator_label = Label.new()
	_generator_label.text = "Generator: —"
	stats_box.add_child(_generator_label)

	# RIGHT — device list + detail
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_vbox)

	_slot_title = Label.new()
	_slot_title.text = "SLOT"
	_slot_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_slot_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_title"))
	right_vbox.add_child(_slot_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	_device_container = VBoxContainer.new()
	_device_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_device_container)

	# Detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size.y = 120
	right_vbox.add_child(_detail_panel)

	var detail_vbox := VBoxContainer.new()
	_detail_panel.add_child(detail_vbox)

	_detail_name = Label.new()
	_detail_name.text = ""
	_detail_name.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	_detail_name.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_title"))
	detail_vbox.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_desc)

	_detail_stats = Label.new()
	_detail_stats.text = ""
	_detail_stats.add_theme_color_override("font_color", ThemeManager.get_color("positive"))
	detail_vbox.add_child(_detail_stats)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size.y = 40
	back_btn.pressed.connect(_on_back)
	right_vbox.add_child(back_btn)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		_on_back()
