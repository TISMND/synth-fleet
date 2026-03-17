extends MarginContainer
## Hangar Screen — ship thumbnail + stats on left, 3 EXT / 3 INT slots on right.

var _ship_thumb: ShipThumbnails
var _ship_name_label: Label
var _right_vbox: VBoxContainer
var _ext_section: VBoxContainer
var _int_section: VBoxContainer
var _title: Label
var _ext_header: Label
var _int_header: Label
var _change_ship_btn: Button
var _back_btn: Button
var _vhs_overlay: ColorRect = null
var _bars: Dictionary = {}  # keyed by spec name -> {"bar": ProgressBar, "label": Label}
var _play_btn: Button
var _mute_btn: Button
var _is_playing: bool = false
var _is_muted: bool = false

var _weapon_cache: Dictionary = {}
var _expanded_slot: String = ""
var _ext_headers: Dictionary = {}
var _ext_lists: Dictionary = {}

# Live weapon preview
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _preview_node: Node2D  # positioned at ship center, parent of controllers
var _proj_container: Node2D  # projectiles land here
var _preview_controllers: Array = []  # HardpointController instances


func _ready() -> void:
	_cache_weapons()
	_build_ui()
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
	ThemeManager.apply_header_chrome(_title)

	# Ship name
	_ship_name_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	_ship_name_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_title"))
	if body_font:
		_ship_name_label.add_theme_font_override("font", body_font)

	# Section headers
	_ext_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_ext_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		_ext_header.add_theme_font_override("font", body_font)

	_int_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_int_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		_int_header.add_theme_font_override("font", body_font)

	# Status bars
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not _bars.has(bar_name):
			continue
		var entry: Dictionary = _bars[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var lbl: Label = entry["label"]
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		lbl.add_theme_color_override("font_color", color)
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(lbl, "body")
		var bar: ProgressBar = entry["bar"]
		var ratio: float = bar.value / maxf(bar.max_value, 1.0)
		ThemeManager.apply_led_bar(bar, color, ratio)

	# Buttons
	ThemeManager.apply_button_style(_play_btn)
	ThemeManager.apply_button_style(_mute_btn)
	ThemeManager.apply_button_style(_change_ship_btn)
	ThemeManager.apply_button_style(_back_btn)

	# Slot buttons — headers and weapon list items
	for child in _ext_section.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)
		elif child is VBoxContainer:
			for sub in child.get_children():
				if sub is Button:
					ThemeManager.apply_button_style(sub as Button)
	for child in _int_section.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)


func _apply_grid_bg() -> void:
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_node("Background"):
		var bg: ColorRect = parent_node.get_node("Background") as ColorRect
		if bg:
			ThemeManager.apply_grid_background(bg)


func _cache_weapons() -> void:
	var wids: Array[String] = WeaponDataManager.list_ids()
	for wid in wids:
		var w: WeaponData = WeaponDataManager.load_by_id(wid)
		if w:
			_weapon_cache[wid] = w


func _load_ship() -> void:
	var idx: int = GameState.current_ship_index
	var info: Dictionary = ShipRegistry.get_ship(idx)
	_ship_name_label.text = str(info["name"])
	_ship_thumb.ship_index = idx
	call_deferred("_position_hangar_thumb")
	_update_stats(info["stats"])
	_rebuild_buttons()
	_sync_preview()


func _position_hangar_thumb() -> void:
	var panel_size: Vector2 = _ship_thumb.size
	var center := Vector2(panel_size.x / 2.0, panel_size.y * 0.75)
	_ship_thumb.origin = center
	_ship_thumb.queue_redraw()
	_preview_node.position = center


func _update_stats(s: Dictionary) -> void:
	var hull_max: int = int(s.get("hull_max", 100))
	var shield_max: int = int(s.get("shield_max", 50))
	_set_bar("SHIELD", shield_max, shield_max)
	_set_bar("HULL", hull_max, hull_max)
	_set_bar("THERMAL", 30, 100)
	_set_bar("ELECTRIC", 70, 100)


func _set_bar(bar_name: String, value: int, max_val: int) -> void:
	if not _bars.has(bar_name):
		return
	var entry: Dictionary = _bars[bar_name]
	var bar: ProgressBar = entry["bar"]
	bar.max_value = max_val
	bar.value = value
	# Re-apply LED with correct ratio
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		if str(spec["name"]) == bar_name:
			var color: Color = ThemeManager.resolve_bar_color(spec)
			ThemeManager.apply_led_bar(bar, color, float(value) / maxf(float(max_val), 1.0))
			break


func _rebuild_buttons() -> void:
	# Clear sections
	for child in _ext_section.get_children():
		child.queue_free()
	for child in _int_section.get_children():
		child.queue_free()
	_ext_headers.clear()
	_ext_lists.clear()

	# External weapon slots (3) — inline expandable pickers
	for i in 3:
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		var weapon_name: String = "empty"
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				weapon_name = w.display_name if w.display_name != "" else w.id
			else:
				weapon_name = weapon_id

		# Header button
		var header := Button.new()
		header.text = "WEAPON " + str(i + 1) + "  —  " + weapon_name
		header.custom_minimum_size.y = 55
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(header)
		var bound_key: String = slot_key
		header.pressed.connect(func() -> void: _toggle_weapon_list(bound_key))
		_ext_section.add_child(header)
		_ext_headers[slot_key] = header

		# Weapon list (hidden by default)
		var wlist := VBoxContainer.new()
		wlist.visible = (_expanded_slot == slot_key)
		wlist.add_theme_constant_override("separation", 2)
		_ext_section.add_child(wlist)
		_ext_lists[slot_key] = wlist

		# "(none)" option
		var none_btn := Button.new()
		none_btn.text = "    (none)"
		none_btn.custom_minimum_size.y = 38
		none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(none_btn)
		var bound_key2: String = slot_key
		none_btn.pressed.connect(func() -> void: _select_weapon(bound_key2, ""))
		wlist.add_child(none_btn)

		# One button per cached weapon
		for wid in _weapon_cache:
			var w: WeaponData = _weapon_cache[wid]
			var label: String = w.display_name if w.display_name != "" else w.id
			var wbtn := Button.new()
			wbtn.text = "    " + label
			wbtn.custom_minimum_size.y = 38
			wbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ThemeManager.apply_button_style(wbtn)
			var bound_key3: String = slot_key
			var bound_wid: String = wid
			wbtn.pressed.connect(func() -> void: _select_weapon(bound_key3, bound_wid))
			wlist.add_child(wbtn)

	# Internal slot buttons (3)
	for i in 3:
		var slot_key: String = "int_" + str(i)
		var device_name: String = "(coming soon)"

		var btn := Button.new()
		btn.text = "INT " + str(i + 1) + "  —  " + device_name
		btn.custom_minimum_size.y = 50
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = true
		ThemeManager.apply_button_style(btn)
		_int_section.add_child(btn)


func _toggle_weapon_list(slot_key: String) -> void:
	if _expanded_slot == slot_key:
		_expanded_slot = ""
	else:
		_expanded_slot = slot_key
	# Show/hide all weapon lists
	for key in _ext_lists:
		var wlist: VBoxContainer = _ext_lists[key]
		wlist.visible = (_expanded_slot == key)


func _select_weapon(slot_key: String, weapon_id: String) -> void:
	GameState.set_slot_weapon(slot_key, weapon_id)
	_expanded_slot = ""
	_rebuild_buttons()
	_sync_preview()


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

	# Ship thumbnail display — SubViewport for live weapon preview
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_sub_viewport)

	# Dark background for the viewport
	var vp_bg := ColorRect.new()
	vp_bg.color = Color(0.05, 0.06, 0.1)
	vp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_viewport.add_child(vp_bg)

	_ship_thumb = ShipThumbnails.new()
	_ship_thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ship_thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ship_thumb.render_mode = ShipThumbnails.RenderMode.CHROME
	_ship_thumb.draw_scale = 3.0
	_sub_viewport.add_child(_ship_thumb)

	_preview_node = Node2D.new()
	_sub_viewport.add_child(_preview_node)

	_proj_container = Node2D.new()
	_sub_viewport.add_child(_proj_container)

	# Status bars — vertical stack
	var bars_vbox := VBoxContainer.new()
	bars_vbox.add_theme_constant_override("separation", 6)
	left_vbox.add_child(bars_vbox)

	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var cell: Dictionary = _create_bar_cell(bar_name, color)
		bars_vbox.add_child(cell["hbox"])
		_bars[bar_name] = {"bar": cell["bar"], "label": cell["label"]}

	# Playback controls
	var controls_hbox := HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 10)
	left_vbox.add_child(controls_hbox)

	_play_btn = Button.new()
	_play_btn.text = "PLAY"
	_play_btn.custom_minimum_size = Vector2(80, 34)
	_play_btn.pressed.connect(_on_play_toggle)
	controls_hbox.add_child(_play_btn)

	_mute_btn = Button.new()
	_mute_btn.text = "MUTE"
	_mute_btn.custom_minimum_size = Vector2(80, 34)
	_mute_btn.pressed.connect(_on_mute_toggle)
	controls_hbox.add_child(_mute_btn)

	# RIGHT — grouped slot buttons
	_right_vbox = VBoxContainer.new()
	_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_right_vbox)

	_ext_header = Label.new()
	_ext_header.text = "━━ EXTERNAL ━━━━━━━━"
	_right_vbox.add_child(_ext_header)

	_ext_section = VBoxContainer.new()
	_right_vbox.add_child(_ext_section)

	_int_header = Label.new()
	_int_header.text = "━━ INTERNAL ━━━━━━━━"
	_right_vbox.add_child(_int_header)

	_int_section = VBoxContainer.new()
	_right_vbox.add_child(_int_section)

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


func _create_bar_cell(text: String, color: Color) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = 70
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(100, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	hbox.add_child(bar)

	ThemeManager.apply_led_bar(bar, color, 0.0)

	return {"hbox": hbox, "label": lbl, "bar": bar}


func _on_play_toggle() -> void:
	if _is_playing:
		for c in _preview_controllers:
			c.deactivate()
		LoopMixer.stop_all()
		_clear_projectiles()
		_is_playing = false
		_play_btn.text = "PLAY"
	else:
		LoopMixer.start_all()
		for c in _preview_controllers:
			c.activate()
		_is_playing = true
		_play_btn.text = "PAUSE"


func _on_mute_toggle() -> void:
	if _is_muted:
		LoopMixer.unmute_all()
		_is_muted = false
		_mute_btn.text = "MUTE"
	else:
		LoopMixer.mute_all()
		_is_muted = true
		_mute_btn.text = "UNMUTE"


func _on_change_ship() -> void:
	_cleanup_preview()
	get_tree().change_scene_to_file("res://scenes/ui/ship_select_screen.tscn")


func _on_back() -> void:
	_cleanup_preview()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _sync_preview() -> void:
	# Cleanup old controllers
	for c in _preview_controllers:
		c.deactivate()
		c.cleanup()
		c.queue_free()
	_preview_controllers.clear()
	_clear_projectiles()

	# Create new controllers for each equipped ext slot
	for i in 3:
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id == "":
			continue
		var weapon: WeaponData = _weapon_cache.get(weapon_id)
		if not weapon:
			continue
		var controller: Node2D = HardpointController.new()
		_preview_node.add_child(controller)
		controller.setup(weapon, weapon.direction_deg, _proj_container, i)
		_preview_controllers.append(controller)

	# If already playing, activate new controllers immediately
	if _is_playing:
		for c in _preview_controllers:
			c.activate()


func _cleanup_preview() -> void:
	for c in _preview_controllers:
		c.deactivate()
		c.cleanup()
	_preview_controllers.clear()
	_clear_projectiles()
	if _is_playing:
		LoopMixer.stop_all()
		_is_playing = false
		_play_btn.text = "PLAY"


func _clear_projectiles() -> void:
	for child in _proj_container.get_children():
		child.queue_free()


func _exit_tree() -> void:
	_cleanup_preview()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
