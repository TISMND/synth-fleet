extends MarginContainer
## Ship Select Screen — grid of 9 ship thumbnails with stats panel.

var _title: Label
var _ship_name_label: Label
var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _generator_label: Label
var _slots_label: Label
var _stat_labels: Array[Label] = []
var _select_btn: Button
var _back_btn: Button
var _ship_panels: Array = []  # Array[PanelContainer]
var _ship_thumbnails: Array = []  # Array[ShipThumbnails]
var _vhs_overlay: ColorRect = null

var _selected_index: int = -1


func _ready() -> void:
	_selected_index = GameState.current_ship_index
	_build_ui()
	_show_ship(_selected_index)
	_update_selection_highlight()
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

	_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if header_font:
		_title.add_theme_font_override("font", header_font)
	ThemeManager.apply_header_chrome(_title)

	_ship_name_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	_ship_name_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_title"))
	if body_font:
		_ship_name_label.add_theme_font_override("font", body_font)

	for lbl in _stat_labels:
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			lbl.add_theme_font_override("font", body_font)

	ThemeManager.apply_button_style(_back_btn)
	ThemeManager.apply_button_style(_select_btn)
	_update_selection_highlight()


func _apply_grid_bg() -> void:
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_node("Background"):
		var bg: ColorRect = parent_node.get_node("Background") as ColorRect
		if bg:
			ThemeManager.apply_grid_background(bg)


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# LEFT — ship grid
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.6
	root.add_child(left_vbox)

	_title = Label.new()
	_title.text = "SELECT SHIP"
	left_vbox.add_child(_title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	left_vbox.add_child(grid)

	for i in ShipRegistry.get_count():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(160, 120)
		grid.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(vbox)

		# Thumbnail
		var thumb := ShipThumbnails.new()
		thumb.ship_index = i
		thumb.render_mode = ShipThumbnails.RenderMode.CHROME
		thumb.custom_minimum_size = Vector2(140, 80)
		thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(thumb)
		_ship_thumbnails.append(thumb)

		# Name label
		var name_lbl := Label.new()
		name_lbl.text = ShipRegistry.get_ship_name(i)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_lbl)

		# Click handler via invisible button overlay
		var click_btn := Button.new()
		click_btn.flat = true
		click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bound_idx: int = i
		click_btn.pressed.connect(func() -> void:
			_on_ship_clicked(bound_idx)
		)
		panel.add_child(click_btn)

		_ship_panels.append(panel)

	# Position thumbnails after layout
	call_deferred("_position_thumbnails")

	# RIGHT — stats + buttons
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.4
	right_vbox.custom_minimum_size.x = 280
	root.add_child(right_vbox)

	_ship_name_label = Label.new()
	_ship_name_label.text = ""
	right_vbox.add_child(_ship_name_label)

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

	_slots_label = Label.new()
	_slots_label.text = "3 External / 3 Internal"
	stats_box.add_child(_slots_label)
	_stat_labels.append(_slots_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)

	_select_btn = Button.new()
	_select_btn.text = "SELECT SHIP"
	_select_btn.custom_minimum_size.y = 50
	_select_btn.pressed.connect(_on_select_pressed)
	right_vbox.add_child(_select_btn)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.custom_minimum_size.y = 40
	_back_btn.pressed.connect(_on_back)
	right_vbox.add_child(_back_btn)


func _position_thumbnails() -> void:
	for thumb in _ship_thumbnails:
		var node: ShipThumbnails = thumb as ShipThumbnails
		node.origin = node.size * 0.5
		node.queue_redraw()


func _on_ship_clicked(index: int) -> void:
	_selected_index = index
	_show_ship(index)
	_update_selection_highlight()


func _show_ship(index: int) -> void:
	var info: Dictionary = ShipRegistry.get_ship(index)
	_ship_name_label.text = str(info["name"])
	var s: Dictionary = info["stats"]
	_hull_label.text = "Hull: " + str(int(s.get("hull_max", 100)))
	_shield_label.text = "Shield: " + str(int(s.get("shield_max", 50)))
	_speed_label.text = "Speed: " + str(int(s.get("speed", 400)))
	_generator_label.text = "Generator: " + str(int(s.get("generator_power", 10)))
	_slots_label.text = "3 External / 3 Internal"


func _update_selection_highlight() -> void:
	var accent: Color = ThemeManager.get_color("accent")
	var dimmed: Color = ThemeManager.get_color("dimmed")
	for i in _ship_panels.size():
		var panel: PanelContainer = _ship_panels[i]
		var sb := StyleBoxFlat.new()
		if i == _selected_index:
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
			sb.border_color = accent
			sb.set_border_width_all(2)
		else:
			sb.bg_color = Color(0.05, 0.05, 0.1, 0.6)
			sb.border_color = Color(dimmed.r, dimmed.g, dimmed.b, 0.3)
			sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", sb)


func _on_select_pressed() -> void:
	if _selected_index < 0 or _selected_index >= ShipRegistry.get_count():
		return
	if GameState.current_ship_index != _selected_index:
		GameState.set_ship_index(_selected_index)
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
