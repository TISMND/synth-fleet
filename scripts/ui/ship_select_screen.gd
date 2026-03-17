extends MarginContainer
## Ship Select Screen — pick a ship, see its stats, then return to hangar.

var _ship_list: ItemList
var _canvas: ShipCanvas
var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _generator_label: Label
var _hp_count_label: Label
var _ship_name_label: Label
var _title: Label
var _back_btn: Button
var _select_btn: Button
var _stat_labels: Array[Label] = []
var _vhs_overlay: ColorRect = null

var _ship_ids: Array[String] = []
var _ships: Dictionary = {}  # id -> ShipData


func _ready() -> void:
	_build_ui()
	_load_ships()
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
	ThemeManager.apply_header_chrome(_title)

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

	# Buttons
	ThemeManager.apply_button_style(_back_btn)
	ThemeManager.apply_button_style(_select_btn)


func _apply_grid_bg() -> void:
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_node("Background"):
		var bg: ColorRect = parent_node.get_node("Background") as ColorRect
		if bg:
			ThemeManager.apply_grid_background(bg)


func _load_ships() -> void:
	_ship_ids = ShipDataManager.list_ids()
	_ship_list.clear()
	for sid in _ship_ids:
		var s: ShipData = ShipDataManager.load_by_id(sid)
		if s:
			_ships[sid] = s
			_ship_list.add_item(s.display_name if s.display_name != "" else sid)

	# Highlight current ship
	if GameState.current_ship_id != "":
		for i in _ship_ids.size():
			if _ship_ids[i] == GameState.current_ship_id:
				_ship_list.select(i)
				_show_ship(GameState.current_ship_id)
				break


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# LEFT — ship list
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 280
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_vbox)

	_title = Label.new()
	_title.text = "SELECT SHIP"
	left_vbox.add_child(_title)

	_ship_list = ItemList.new()
	_ship_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ship_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_list.item_selected.connect(_on_ship_selected)
	_ship_list.item_activated.connect(_on_ship_activated)
	left_vbox.add_child(_ship_list)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.pressed.connect(_on_back)
	left_vbox.add_child(_back_btn)

	# RIGHT — preview + stats
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_vbox)

	_ship_name_label = Label.new()
	_ship_name_label.text = ""
	right_vbox.add_child(_ship_name_label)

	# Ship canvas preview
	var canvas_panel := PanelContainer.new()
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(canvas_panel)

	_canvas = ShipCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.display_only = true
	canvas_panel.add_child(_canvas)

	# Stats
	var stats_box := VBoxContainer.new()
	right_vbox.add_child(stats_box)

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

	_select_btn = Button.new()
	_select_btn.text = "SELECT SHIP"
	_select_btn.custom_minimum_size.y = 40
	_select_btn.pressed.connect(_on_select_pressed)
	right_vbox.add_child(_select_btn)


func _on_ship_selected(idx: int) -> void:
	if idx < 0 or idx >= _ship_ids.size():
		return
	_show_ship(_ship_ids[idx])


func _on_ship_activated(idx: int) -> void:
	# Double-click selects and navigates
	if idx < 0 or idx >= _ship_ids.size():
		return
	_select_and_navigate(_ship_ids[idx])


func _show_ship(id: String) -> void:
	var ship: ShipData = _ships.get(id)
	if not ship:
		return
	_ship_name_label.text = ship.display_name if ship.display_name != "" else ship.id
	_canvas.set_grid_size(ship.grid_size)
	_canvas.set_lines(ship.lines.duplicate(true))
	_canvas.set_hardpoints(ship.hardpoints.duplicate(true))

	var stats: Dictionary = ship.stats
	_hull_label.text = "Hull: " + str(int(stats.get("hull_max", 100)))
	_shield_label.text = "Shield: " + str(int(stats.get("shield_max", 50)))
	_speed_label.text = "Speed: " + str(int(stats.get("speed", 400)))
	_generator_label.text = "Generator: " + str(int(stats.get("generator_power", 10)))
	_hp_count_label.text = "Hardpoints: " + str(ship.hardpoints.size())


func _on_select_pressed() -> void:
	var selected: PackedInt32Array = _ship_list.get_selected_items()
	if selected.size() == 0:
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _ship_ids.size():
		return
	_select_and_navigate(_ship_ids[idx])


func _select_and_navigate(id: String) -> void:
	# Only reset config if changing ships
	if GameState.current_ship_id != id:
		GameState.set_ship(id)
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
