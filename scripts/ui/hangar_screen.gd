extends MarginContainer
## Hangar Screen — ship thumbnail + stats on left, 3 EXT / 3 INT slots on right.

var _ship_thumb: ShipThumbnails
var _ship_name_label: Label
var _center_vbox: VBoxContainer
var _right_panel: VBoxContainer
var _right_panel_header: Label
var _right_panel_scroll: ScrollContainer
var _right_panel_list: VBoxContainer
var _ext_section: VBoxContainer
var _int_section: VBoxContainer
var _title: Label
var _ext_header: Label
var _int_header: Label
var _change_ship_btn: Button
var _back_btn: Button
var _reset_btn: Button
var _vhs_overlay: ColorRect = null
var _bars: Dictionary = {}  # keyed by spec name -> {"bar": ProgressBar, "label": Label}
var _bar_segments: Dictionary = {}  # bar_name -> int segment count
var _play_btn: Button
var _mute_btn: Button
var _is_playing: bool = false
var _is_muted: bool = false

var _weapon_cache: Dictionary = {}
var _power_core_cache: Dictionary = {}
var _expanded_slot: String = ""
var _ext_headers: Dictionary = {}
var _int_headers: Dictionary = {}

# Live weapon preview
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _preview_node: Node2D  # positioned at ship center, parent of controllers
var _proj_container: Node2D  # projectiles land here
var _preview_controllers: Array = []  # HardpointController instances

# Power core preview — lightweight pulse trigger tracking
var _core_previews: Array = []  # Array of Dicts: {pc, loop_id, prev_pos, triggers}



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
		var seg: int = int(_bar_segments.get(bar_name, -1))
		ThemeManager.apply_led_bar(bar, color, ratio, seg)

	# Buttons
	ThemeManager.apply_button_style(_play_btn)
	ThemeManager.apply_button_style(_mute_btn)
	ThemeManager.apply_button_style(_reset_btn)
	ThemeManager.apply_button_style(_change_ship_btn)
	ThemeManager.apply_button_style(_back_btn)

	# Right panel header
	_right_panel_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_right_panel_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		_right_panel_header.add_theme_font_override("font", body_font)

	# Slot buttons — headers only
	for child in _ext_section.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)
	for child in _int_section.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)

	# Right panel weapon list buttons
	for child in _right_panel_list.get_children():
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

	var pcids: Array[String] = PowerCoreDataManager.list_ids()
	for pcid in pcids:
		var pc: PowerCoreData = PowerCoreDataManager.load_by_id(pcid)
		if pc:
			_power_core_cache[pcid] = pc


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
	var eff: Dictionary = ShipData.get_effective_segments(s)
	_bar_segments["SHIELD"] = int(eff.get("shield_segments", 10))
	_bar_segments["HULL"] = int(eff.get("hull_segments", 8))
	_bar_segments["THERMAL"] = int(eff.get("thermal_segments", 6))
	_bar_segments["ELECTRIC"] = int(eff.get("electric_segments", 8))
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
			var seg: int = int(_bar_segments.get(bar_name, -1))
			ThemeManager.apply_led_bar(bar, color, float(value) / maxf(float(max_val), 1.0), seg)
			break


func _rebuild_buttons() -> void:
	# Clear sections
	for child in _ext_section.get_children():
		child.queue_free()
	for child in _int_section.get_children():
		child.queue_free()
	_ext_headers.clear()
	_int_headers.clear()
	_clear_right_panel()

	# External weapon slots (3) — header buttons only
	for i in 3:
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		var weapon_name: String = "empty"
		var bar_effect_text: String = ""
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				weapon_name = w.display_name if w.display_name != "" else w.id
				bar_effect_text = _format_bar_effects(w.bar_effects)
			else:
				weapon_name = weapon_id

		var header := Button.new()
		var header_text: String = "WEAPON " + str(i + 1) + "  —  " + weapon_name
		if bar_effect_text != "":
			header_text += "  " + bar_effect_text
		header.text = header_text
		header.custom_minimum_size.y = 55
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(header)
		var bound_key: String = slot_key
		header.pressed.connect(func() -> void: _toggle_slot_list(bound_key))
		_ext_section.add_child(header)
		_ext_headers[slot_key] = header

	# Internal power core slots (3)
	for i in 3:
		var slot_key: String = "int_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		var core_name: String = "empty"
		var bar_effect_text: String = ""
		if device_id != "":
			var pc: PowerCoreData = _power_core_cache.get(device_id)
			if pc:
				core_name = pc.display_name if pc.display_name != "" else pc.id
				bar_effect_text = _format_bar_effects(pc.bar_effects)
			else:
				core_name = device_id

		var header := Button.new()
		var header_text: String = "CORE " + str(i + 1) + "  —  " + core_name
		if bar_effect_text != "":
			header_text += "  " + bar_effect_text
		header.text = header_text
		header.custom_minimum_size.y = 50
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(header)
		var bound_key: String = slot_key
		header.pressed.connect(func() -> void: _toggle_slot_list(bound_key))
		_int_section.add_child(header)
		_int_headers[slot_key] = header


func _toggle_slot_list(slot_key: String) -> void:
	if _expanded_slot == slot_key:
		_expanded_slot = ""
		_clear_right_panel()
	else:
		_expanded_slot = slot_key
		_populate_right_panel(slot_key)
	# Highlight the active slot header across both sections
	for key in _ext_headers:
		var btn: Button = _ext_headers[key]
		if key == _expanded_slot:
			btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		else:
			btn.remove_theme_color_override("font_color")
		ThemeManager.apply_button_style(btn)
	for key in _int_headers:
		var btn: Button = _int_headers[key]
		if key == _expanded_slot:
			btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		else:
			btn.remove_theme_color_override("font_color")
		ThemeManager.apply_button_style(btn)


func _populate_right_panel(slot_key: String) -> void:
	_clear_right_panel()
	var is_int: bool = slot_key.begins_with("int_")
	_right_panel_header.text = "SELECT POWER CORE" if is_int else "SELECT WEAPON"
	_right_panel_header.visible = true

	# "(none)" option
	var none_btn := Button.new()
	none_btn.text = "(none)"
	none_btn.custom_minimum_size.y = 38
	none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeManager.apply_button_style(none_btn)
	var bound_key: String = slot_key
	none_btn.pressed.connect(func() -> void: _select_item(bound_key, ""))
	_right_panel_list.add_child(none_btn)

	if is_int:
		# Power core choices
		for pcid in _power_core_cache:
			var pc: PowerCoreData = _power_core_cache[pcid]
			var label: String = pc.display_name if pc.display_name != "" else pc.id
			var effect_text: String = _format_bar_effects(pc.bar_effects)
			if effect_text != "":
				label += "  " + effect_text
			var btn := Button.new()
			btn.text = label
			btn.custom_minimum_size.y = 38
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ThemeManager.apply_button_style(btn)
			var bound_key2: String = slot_key
			var bound_id: String = pcid
			btn.pressed.connect(func() -> void: _select_item(bound_key2, bound_id))
			_right_panel_list.add_child(btn)
	else:
		# Weapon choices
		for wid in _weapon_cache:
			var w: WeaponData = _weapon_cache[wid]
			var label: String = w.display_name if w.display_name != "" else w.id
			var wbtn := Button.new()
			wbtn.text = label
			wbtn.custom_minimum_size.y = 38
			wbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ThemeManager.apply_button_style(wbtn)
			var bound_key2: String = slot_key
			var bound_wid: String = wid
			wbtn.pressed.connect(func() -> void: _select_item(bound_key2, bound_wid))
			_right_panel_list.add_child(wbtn)


func _clear_right_panel() -> void:
	for child in _right_panel_list.get_children():
		child.queue_free()
	_right_panel_header.visible = false


func _select_item(slot_key: String, item_id: String) -> void:
	if slot_key.begins_with("int_"):
		GameState.set_slot_device(slot_key, item_id)
	else:
		GameState.set_slot_weapon(slot_key, item_id)
	_expanded_slot = ""
	_clear_right_panel()
	_rebuild_buttons()
	_sync_preview()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# LEFT — ship preview + stats
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 300
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
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

	# Bloom for projectile glow
	VFXFactory.add_bloom_to_viewport(_sub_viewport)

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
		var seg: int = int(ShipData.DEFAULT_SEGMENTS.get(bar_name, -1))
		var cell: Dictionary = _create_bar_cell(bar_name, color, seg)
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

	_reset_btn = Button.new()
	_reset_btn.text = "RESET"
	_reset_btn.custom_minimum_size = Vector2(80, 34)
	_reset_btn.pressed.connect(_on_reset_bars)
	controls_hbox.add_child(_reset_btn)

	# CENTER — slot buttons in padded container
	var center_margin := MarginContainer.new()
	center_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_margin.size_flags_stretch_ratio = 1.0
	center_margin.add_theme_constant_override("margin_left", 20)
	center_margin.add_theme_constant_override("margin_right", 20)
	root.add_child(center_margin)

	_center_vbox = VBoxContainer.new()
	_center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_margin.add_child(_center_vbox)

	_ext_header = Label.new()
	_ext_header.text = "━━ EXTERNAL ━━━━━━━━"
	_center_vbox.add_child(_ext_header)

	_ext_section = VBoxContainer.new()
	_center_vbox.add_child(_ext_section)

	_int_header = Label.new()
	_int_header.text = "━━ INTERNAL ━━━━━━━━"
	_center_vbox.add_child(_int_header)

	_int_section = VBoxContainer.new()
	_center_vbox.add_child(_int_section)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_vbox.add_child(spacer)

	_change_ship_btn = Button.new()
	_change_ship_btn.text = "CHANGE SHIP"
	_change_ship_btn.custom_minimum_size.y = 40
	_change_ship_btn.pressed.connect(_on_change_ship)
	_center_vbox.add_child(_change_ship_btn)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.custom_minimum_size.y = 40
	_back_btn.pressed.connect(_on_back)
	_center_vbox.add_child(_back_btn)

	# RIGHT — selection panel
	_right_panel = VBoxContainer.new()
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_stretch_ratio = 1.0
	root.add_child(_right_panel)

	_right_panel_header = Label.new()
	_right_panel_header.text = "SELECT WEAPON"
	_right_panel_header.visible = false
	_right_panel.add_child(_right_panel_header)

	_right_panel_scroll = ScrollContainer.new()
	_right_panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.add_child(_right_panel_scroll)

	_right_panel_list = VBoxContainer.new()
	_right_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel_scroll.add_child(_right_panel_list)


func _create_bar_cell(text: String, color: Color, seg_count: int = -1) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = 90
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 20
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	hbox.add_child(bar)

	ThemeManager.apply_led_bar(bar, color, 0.0, seg_count)

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


func _on_reset_bars() -> void:
	var idx: int = GameState.current_ship_index
	var info: Dictionary = ShipRegistry.get_ship(idx)
	_update_stats(info["stats"])


func _on_change_ship() -> void:
	_cleanup_preview()
	get_tree().change_scene_to_file("res://scenes/ui/ship_select_screen.tscn")


func _on_back() -> void:
	_cleanup_preview()
	get_tree().change_scene_to_file("res://scenes/ui/play_menu.tscn")


func _sync_preview() -> void:
	# Cleanup old weapon controllers
	for c in _preview_controllers:
		c.deactivate()
		c.cleanup()
		c.queue_free()
	_preview_controllers.clear()
	_clear_projectiles()

	# Cleanup old power core loops
	for entry in _core_previews:
		var loop_id: String = entry["loop_id"]
		LoopMixer.remove_loop(loop_id)
	_core_previews.clear()

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
		controller.bar_effect_fired.connect(_on_bar_effect_fired)
		_preview_controllers.append(controller)

	# Register power core loops for each equipped int slot
	for i in 3:
		var slot_key: String = "int_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		var pc: PowerCoreData = _power_core_cache.get(device_id)
		if not pc or pc.loop_file_path == "":
			continue
		# Merge all pulse_triggers into a single sorted array
		var merged: Array[float] = []
		for bar_type in pc.pulse_triggers:
			var arr: Array = pc.pulse_triggers[bar_type]
			for t in arr:
				var tf: float = float(t)
				if not merged.has(tf):
					merged.append(tf)
		merged.sort()
		if merged.is_empty() and pc.bar_effects.is_empty():
			continue
		var loop_id: String = "core_" + str(i)
		LoopMixer.add_loop(loop_id, pc.loop_file_path)
		_core_previews.append({"pc": pc, "loop_id": loop_id, "prev_pos": -1.0, "triggers": merged})

	# If already playing, activate new controllers immediately
	if _is_playing:
		for c in _preview_controllers:
			c.activate()
		if not _core_previews.is_empty():
			LoopMixer.start_all()


func _cleanup_preview() -> void:
	for c in _preview_controllers:
		c.deactivate()
		c.cleanup()
	_preview_controllers.clear()
	_clear_projectiles()
	for entry in _core_previews:
		var loop_id: String = entry["loop_id"]
		LoopMixer.remove_loop(loop_id)
	_core_previews.clear()
	if _is_playing:
		LoopMixer.stop_all()
		_is_playing = false
		_play_btn.text = "PLAY"


func _clear_projectiles() -> void:
	for child in _proj_container.get_children():
		child.queue_free()


func _format_bar_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""
	var abbreviations: Dictionary = {"shield": "SHD", "hull": "HUL", "thermal": "THR", "electric": "ELC"}
	var parts: Array[String] = []
	for key in effects:
		var val: float = float(effects[key])
		if val == 0.0:
			continue
		var prefix: String = "+" if val > 0.0 else ""
		parts.append(str(abbreviations.get(key, str(key))) + ":" + prefix + "%.1f" % val)
	return " ".join(parts)


func _on_bar_effect_fired(effects: Dictionary) -> void:
	var abbreviations: Dictionary = {"shield": "SHIELD", "hull": "HULL", "thermal": "THERMAL", "electric": "ELECTRIC"}
	for key in effects:
		var bar_name: String = str(abbreviations.get(str(key), str(key).to_upper()))
		if not _bars.has(bar_name):
			continue
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		var delta: float = float(effects[key])
		bar.value = clampf(bar.value + delta, 0.0, bar.max_value)
		# Re-apply LED with updated ratio
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			if str(spec["name"]) == bar_name:
				var color: Color = ThemeManager.resolve_bar_color(spec)
				var seg: int = int(_bar_segments.get(bar_name, -1))
				ThemeManager.apply_led_bar(bar, color, bar.value / maxf(bar.max_value, 1.0), seg)
				break


func _process(_delta: float) -> void:
	if not _is_playing or _core_previews.is_empty():
		return
	for entry in _core_previews:
		var pc: PowerCoreData = entry["pc"]
		var loop_id: String = entry["loop_id"]
		var pos_sec: float = LoopMixer.get_playback_position(loop_id)
		var duration: float = LoopMixer.get_stream_duration(loop_id)
		if pos_sec < 0.0 or duration <= 0.0:
			continue
		var curr: float = pos_sec / duration
		var prev: float = float(entry["prev_pos"])
		entry["prev_pos"] = curr
		if prev < 0.0:
			continue
		# Check each merged trigger
		var triggers: Array = entry["triggers"]
		for t in triggers:
			var tval: float = float(t)
			var crossed: bool = false
			if curr >= prev:
				crossed = tval > prev and tval <= curr
			else:
				crossed = tval > prev or tval <= curr
			if crossed:
				_on_bar_effect_fired(pc.bar_effects)


func _exit_tree() -> void:
	_cleanup_preview()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
