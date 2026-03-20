extends MarginContainer
## Hangar Screen — ship thumbnail + stats on left, FUNCTIONAL/AUDIO/CONTROLS tabs center.

var _ship_thumb: ShipThumbnails
var _ship_name_label: Label
var _center_vbox: VBoxContainer
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
var _device_cache: Dictionary = {}
var _dev_section: VBoxContainer
var _dev_header: Label

# Right panel (item picker)
var _right_panel: VBoxContainer
var _right_panel_header: Label
var _right_panel_scroll: ScrollContainer
var _right_panel_list: VBoxContainer
var _expanded_slot: String = ""
var _ext_slot_btns: Dictionary = {}  # slot_key -> Button (header)
var _int_slot_btns: Dictionary = {}
var _dev_slot_btns: Dictionary = {}

# Live weapon preview
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _preview_node: Node2D  # positioned at ship center, parent of controllers
var _proj_container: Node2D  # projectiles land here
var _preview_controllers: Array = []  # HardpointController instances

# Power core preview — lightweight pulse trigger tracking
var _core_previews: Array = []  # Array of Dicts: {pc, loop_id, prev_pos, triggers}

# Mode toggle: "functional", "audio", or "controls"
var _mode: String = "functional"
var _functional_btn: Button
var _audio_btn: Button
var _controls_btn: Button
var _functional_content: VBoxContainer
var _audio_content: VBoxContainer
var _controls_content: VBoxContainer

# Slot active state for preview toggles
var _slot_active: Dictionary = {}  # slot_key -> bool
var _slot_toggle_btns: Dictionary = {}  # slot_key -> Button (toggle)

# Preset section (in controls tab)
var _preset_section: VBoxContainer
var _preset_list: VBoxContainer

# Key capture overlay
var _capture_overlay: ColorRect = null
var _capture_label: Label = null
var _capturing_for: String = ""  # slot_key or "combo_new" or "combo_N"
var _is_capturing: bool = false

# Audio mode per-slot sliders
var _audio_sliders: Dictionary = {}  # slot_key -> {slider: HSlider, label: Label}

# Controls tab key binding buttons
var _controls_key_btns: Dictionary = {}  # slot_key -> Button


func _ready() -> void:
	_cache_weapons()
	_init_slot_active()
	_build_ui()
	_load_ship()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_apply_theme)
	KeyBindingManager.bindings_changed.connect(_rebuild_buttons)
	call_deferred("_apply_theme")


func _init_slot_active() -> void:
	for i in 3:
		_slot_active["ext_" + str(i)] = true
	for i in 3:
		_slot_active["int_" + str(i)] = true
	for i in 2:
		_slot_active["dev_" + str(i)] = true


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

	# Section headers — larger, color-coded, with glow
	var section_pairs: Array = [
		[_ext_header, "ext_0"],
		[_int_header, "int_0"],
		[_dev_header, "dev_0"],
	]
	for pair in section_pairs:
		var hdr: Label = pair[0]
		var prefix: String = str(pair[1])
		if not hdr:
			continue
		var type_color: Color = _get_slot_type_color(prefix)
		hdr.add_theme_color_override("font_color", type_color)
		hdr.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 4)
		if header_font:
			hdr.add_theme_font_override("font", header_font)
		ThemeManager.apply_text_glow(hdr, "header")
		# Re-apply the panel background bar color
		var panel_parent: PanelContainer = hdr.get_parent() as PanelContainer
		if panel_parent:
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(type_color.r, type_color.g, type_color.b, 0.12)
			sb.border_color = Color(type_color.r, type_color.g, type_color.b, 0.35)
			sb.border_width_bottom = 2
			sb.border_width_top = 0
			sb.border_width_left = 0
			sb.border_width_right = 0
			sb.set_content_margin_all(6)
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			panel_parent.add_theme_stylebox_override("panel", sb)

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
	ThemeManager.apply_button_style(_functional_btn)
	ThemeManager.apply_button_style(_audio_btn)
	ThemeManager.apply_button_style(_controls_btn)

	# Slot buttons in all sections — re-apply base style then color-coding
	var section_prefixes: Array = [
		[_ext_section, "ext_"],
		[_int_section, "int_"],
		[_dev_section, "dev_"],
	]
	for sp in section_prefixes:
		var section: VBoxContainer = sp[0]
		var prefix: String = str(sp[1])
		var slot_idx: int = 0
		for child in section.get_children():
			if child is HBoxContainer:
				var slot_key: String = prefix + str(slot_idx)
				for sub in child.get_children():
					if sub is Button:
						var btn: Button = sub as Button
						ThemeManager.apply_button_style(btn)
						# Re-apply color-coding for the slot header button (the wide one)
						if btn.size_flags_horizontal & Control.SIZE_EXPAND_FILL:
							var slot_color: Color = _get_slot_type_color(slot_key)
							btn.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.7))
							btn.add_theme_color_override("font_hover_color", Color(slot_color.r, slot_color.g, slot_color.b, 1.0))
							btn.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
				slot_idx += 1

	# Right panel header + item buttons
	if _right_panel and _right_panel.visible:
		_right_panel_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
		_right_panel_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
		if body_font:
			_right_panel_header.add_theme_font_override("font", body_font)
		for child in _right_panel_list.get_children():
			if child is Button:
				ThemeManager.apply_button_style(child as Button)

	# Device section header — handled in section_pairs loop above

	# Mode toggle highlight
	_update_mode_buttons()

	# Preset section buttons (in controls tab)
	if _preset_list:
		for child in _preset_list.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is Button:
						ThemeManager.apply_button_style(sub as Button)

	# Audio content children
	if _audio_content:
		for child in _audio_content.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is Button:
						ThemeManager.apply_button_style(sub as Button)
			elif child is Button:
				ThemeManager.apply_button_style(child as Button)

	# Controls content children
	if _controls_content:
		for child in _controls_content.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is Button:
						ThemeManager.apply_button_style(sub as Button)
			elif child is Button:
				ThemeManager.apply_button_style(child as Button)




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

	var dids: Array[String] = DeviceDataManager.list_ids()
	for did in dids:
		var d: DeviceData = DeviceDataManager.load_by_id(did)
		if d:
			_device_cache[did] = d


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
	var hull_seg: int = int(s.get("hull_segments", 8))
	var shield_seg: int = int(s.get("shield_segments", 10))
	var thermal_seg: int = int(s.get("thermal_segments", 6))
	var electric_seg: int = int(s.get("electric_segments", 8))
	_bar_segments["SHIELD"] = shield_seg
	_bar_segments["HULL"] = hull_seg
	_bar_segments["THERMAL"] = thermal_seg
	_bar_segments["ELECTRIC"] = electric_seg
	_set_bar("SHIELD", shield_seg, shield_seg)
	_set_bar("HULL", hull_seg, hull_seg)
	_set_bar("THERMAL", thermal_seg, thermal_seg)
	_set_bar("ELECTRIC", electric_seg, electric_seg)


func _set_bar(bar_name: String, value: int, max_val: int) -> void:
	if not _bars.has(bar_name):
		return
	var entry: Dictionary = _bars[bar_name]
	var bar: ProgressBar = entry["bar"]
	bar.max_value = max_val
	bar.value = value
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
	for child in _dev_section.get_children():
		child.queue_free()
	_slot_toggle_btns.clear()
	_ext_slot_btns.clear()
	_int_slot_btns.clear()
	_dev_slot_btns.clear()

	# External weapon slots (3)
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

		var row: HBoxContainer = _create_slot_row(slot_key, "WEAPON " + str(i + 1), weapon_name, bar_effect_text)
		_ext_section.add_child(row)

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

		var row: HBoxContainer = _create_slot_row(slot_key, "CORE " + str(i + 1), core_name, bar_effect_text)
		_int_section.add_child(row)

	# Device slots (2)
	for i in 2:
		var slot_key: String = "dev_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		var device_name: String = "empty"
		var bar_effect_text: String = ""
		if device_id != "":
			var d: DeviceData = _device_cache.get(device_id)
			if d:
				device_name = d.display_name if d.display_name != "" else d.id
				bar_effect_text = _format_bar_effects(d.bar_effects)
			else:
				device_name = device_id

		var row: HBoxContainer = _create_slot_row(slot_key, "DEVICE " + str(i + 1), device_name, bar_effect_text)
		_dev_section.add_child(row)

	_rebuild_audio_content()
	_rebuild_controls_content()
	call_deferred("_apply_theme")


func _create_section_header_bar(title: String, section_prefix: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Colored background bar
	var type_color: Color = _get_slot_type_color(section_prefix + "_0")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(type_color.r, type_color.g, type_color.b, 0.12)
	sb.border_color = Color(type_color.r, type_color.g, type_color.b, 0.35)
	sb.border_width_bottom = 2
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.set_content_margin_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", sb)

	var header_label := Label.new()
	header_label.text = title
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(header_label)

	# Store reference for theming
	if section_prefix == "ext":
		_ext_header = header_label
	elif section_prefix == "int":
		_int_header = header_label
	elif section_prefix == "dev":
		_dev_header = header_label

	return panel


func _get_slot_type_color(slot_key: String) -> Color:
	if slot_key.begins_with("ext_"):
		return ThemeManager.get_color("bar_shield")  # Cyan-ish for weapons
	elif slot_key.begins_with("int_"):
		return ThemeManager.get_color("bar_electric")  # Yellow for cores
	elif slot_key.begins_with("dev_"):
		return ThemeManager.get_color("bar_thermal")  # Orange for devices
	return ThemeManager.get_color("accent")


func _create_slot_row(slot_key: String, type_label: String, item_name: String, bar_effect_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Toggle button
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(44, 38)
	var is_active: bool = _slot_active.get(slot_key, true)
	toggle.text = "ON" if is_active else "OFF"
	ThemeManager.apply_button_style(toggle)
	if is_active:
		toggle.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		toggle.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	var bound_key: String = slot_key
	toggle.pressed.connect(func() -> void: _on_slot_toggle(bound_key))
	row.add_child(toggle)
	_slot_toggle_btns[slot_key] = toggle

	# Slot button (clickable) — shows equipped item info, opens picker
	var header := Button.new()
	var header_text: String = type_label + "  —  " + item_name
	if bar_effect_text != "":
		header_text += "  " + bar_effect_text
	header.text = header_text
	header.custom_minimum_size.y = 54
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeManager.apply_button_style(header)
	# Apply slot type color tint to the button font
	var slot_color: Color = _get_slot_type_color(slot_key)
	header.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.7))
	header.add_theme_color_override("font_hover_color", Color(slot_color.r, slot_color.g, slot_color.b, 1.0))
	header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
	var bound_slot: String = slot_key
	header.pressed.connect(func() -> void: _toggle_slot_list(bound_slot))
	row.add_child(header)

	# Track header button for highlight
	if slot_key.begins_with("ext_"):
		_ext_slot_btns[slot_key] = header
	elif slot_key.begins_with("int_"):
		_int_slot_btns[slot_key] = header
	elif slot_key.begins_with("dev_"):
		_dev_slot_btns[slot_key] = header

	return row


func _on_slot_toggle(slot_key: String) -> void:
	var new_state: bool = not _slot_active.get(slot_key, false)
	_slot_active[slot_key] = new_state

	# Update toggle button appearance
	if _slot_toggle_btns.has(slot_key):
		var btn: Button = _slot_toggle_btns[slot_key]
		btn.text = "ON" if new_state else "OFF"
		if new_state:
			btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	_sync_preview_active_states()


# ── Slot picker (right panel) ────────────────────────────────────────────────

func _toggle_slot_list(slot_key: String) -> void:
	if _expanded_slot == slot_key:
		_clear_right_panel()
		_expanded_slot = ""
		_unhighlight_all_slot_btns()
		return
	_expanded_slot = slot_key
	_unhighlight_all_slot_btns()
	# Highlight the active slot button
	var btn: Button = _get_slot_btn(slot_key)
	if btn:
		btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	_populate_right_panel(slot_key)


func _unhighlight_all_slot_btns() -> void:
	var body_color: Color = ThemeManager.get_color("body")
	for d in [_ext_slot_btns, _int_slot_btns, _dev_slot_btns]:
		for key in d:
			var b: Button = d[key]
			b.remove_theme_color_override("font_color")


func _get_slot_btn(slot_key: String) -> Button:
	if _ext_slot_btns.has(slot_key):
		return _ext_slot_btns[slot_key]
	if _int_slot_btns.has(slot_key):
		return _int_slot_btns[slot_key]
	if _dev_slot_btns.has(slot_key):
		return _dev_slot_btns[slot_key]
	return null


func _populate_right_panel(slot_key: String) -> void:
	_clear_right_panel()
	_right_panel.visible = true

	var body_font: Font = ThemeManager.get_font("font_body")

	if slot_key.begins_with("ext_"):
		_right_panel_header.text = "━━ SELECT WEAPON ━━━━━━━━━━━"
		# "(none)" option
		var none_btn := Button.new()
		none_btn.text = "(none)"
		none_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		none_btn.custom_minimum_size.y = 36
		ThemeManager.apply_button_style(none_btn)
		var bound_key: String = slot_key
		none_btn.pressed.connect(func() -> void: _select_item(bound_key, ""))
		_right_panel_list.add_child(none_btn)
		# Weapon list
		for wid in _weapon_cache:
			var w: WeaponData = _weapon_cache[wid]
			var item_btn := Button.new()
			var label: String = w.display_name if w.display_name != "" else w.id
			item_btn.text = label
			item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item_btn.custom_minimum_size.y = 36
			ThemeManager.apply_button_style(item_btn)
			var bound_wid: String = wid
			item_btn.pressed.connect(func() -> void: _select_item(bound_key, bound_wid))
			_right_panel_list.add_child(item_btn)

	elif slot_key.begins_with("int_"):
		_right_panel_header.text = "━━ SELECT CORE ━━━━━━━━━━━━━"
		var none_btn := Button.new()
		none_btn.text = "(none)"
		none_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		none_btn.custom_minimum_size.y = 36
		ThemeManager.apply_button_style(none_btn)
		var bound_key: String = slot_key
		none_btn.pressed.connect(func() -> void: _select_item(bound_key, ""))
		_right_panel_list.add_child(none_btn)
		for pcid in _power_core_cache:
			var pc: PowerCoreData = _power_core_cache[pcid]
			var item_btn := Button.new()
			var label: String = pc.display_name if pc.display_name != "" else pc.id
			item_btn.text = label
			item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item_btn.custom_minimum_size.y = 36
			ThemeManager.apply_button_style(item_btn)
			var bound_pcid: String = pcid
			item_btn.pressed.connect(func() -> void: _select_item(bound_key, bound_pcid))
			_right_panel_list.add_child(item_btn)

	elif slot_key.begins_with("dev_"):
		_right_panel_header.text = "━━ SELECT DEVICE ━━━━━━━━━━━"
		var none_btn := Button.new()
		none_btn.text = "(none)"
		none_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		none_btn.custom_minimum_size.y = 36
		ThemeManager.apply_button_style(none_btn)
		var bound_key: String = slot_key
		none_btn.pressed.connect(func() -> void: _select_item(bound_key, ""))
		_right_panel_list.add_child(none_btn)
		for did in _device_cache:
			var d: DeviceData = _device_cache[did]
			var item_btn := Button.new()
			var label: String = d.display_name if d.display_name != "" else d.id
			item_btn.text = label
			item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item_btn.custom_minimum_size.y = 36
			ThemeManager.apply_button_style(item_btn)
			var bound_did: String = did
			item_btn.pressed.connect(func() -> void: _select_item(bound_key, bound_did))
			_right_panel_list.add_child(item_btn)

	# Theme the header
	_right_panel_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_right_panel_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		_right_panel_header.add_theme_font_override("font", body_font)


func _select_item(slot_key: String, item_id: String) -> void:
	if slot_key.begins_with("ext_"):
		GameState.set_slot_weapon(slot_key, item_id)
	else:
		GameState.set_slot_device(slot_key, item_id)
	_clear_right_panel()
	_expanded_slot = ""
	_unhighlight_all_slot_btns()
	_rebuild_buttons()
	_sync_preview()


func _clear_right_panel() -> void:
	for child in _right_panel_list.get_children():
		child.queue_free()
	_right_panel.visible = false
	_right_panel_header.text = ""


func _sync_preview_active_states() -> void:
	if not _is_playing:
		return

	# Sync weapon controllers (ext slots)
	var ext_controller_idx: int = 0
	for i in 3:
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id == "":
			continue
		if ext_controller_idx < _preview_controllers.size():
			var controller: Node2D = _preview_controllers[ext_controller_idx]
			if _slot_active.get(slot_key, false):
				controller.activate()
			else:
				controller.deactivate()
		ext_controller_idx += 1

	# Sync core previews (int slots) — mute/unmute loops
	for entry in _core_previews:
		var loop_id: String = entry["loop_id"]
		# Extract slot index from loop_id "core_N"
		var slot_idx: String = loop_id.replace("core_", "")
		var slot_key: String = "int_" + slot_idx
		if _slot_active.get(slot_key, false):
			LoopMixer.unmute(loop_id)
		else:
			LoopMixer.mute(loop_id)


# ── Mode toggle ──────────────────────────────────────────────────────────────

func _on_mode_toggle(new_mode: String) -> void:
	_mode = new_mode
	_functional_content.visible = (_mode == "functional")
	_audio_content.visible = (_mode == "audio")
	_controls_content.visible = (_mode == "controls")
	# Hide right panel when not on functional tab
	if _mode != "functional":
		_clear_right_panel()
		_expanded_slot = ""
		_unhighlight_all_slot_btns()
	_update_mode_buttons()


func _update_mode_buttons() -> void:
	var accent: Color = ThemeManager.get_color("accent")
	for btn in [_functional_btn, _audio_btn, _controls_btn]:
		btn.remove_theme_color_override("font_color")
	if _mode == "functional":
		_functional_btn.add_theme_color_override("font_color", accent)
	elif _mode == "audio":
		_audio_btn.add_theme_color_override("font_color", accent)
	else:
		_controls_btn.add_theme_color_override("font_color", accent)
	ThemeManager.apply_button_style(_functional_btn)
	ThemeManager.apply_button_style(_audio_btn)
	ThemeManager.apply_button_style(_controls_btn)


# ── Key capture ──────────────────────────────────────────────────────────────

func _start_key_capture(target: String) -> void:
	_capturing_for = target
	_is_capturing = true
	if not _capture_overlay:
		_capture_overlay = ColorRect.new()
		_capture_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
		_capture_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_capture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_capture_label = Label.new()
		_capture_label.text = "PRESS A KEY...\n(ESC to cancel)"
		_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_capture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_capture_label.set_anchors_preset(Control.PRESET_CENTER)
		_capture_label.add_theme_font_size_override("font_size", 32)
		_capture_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		var body_font: Font = ThemeManager.get_font("font_body")
		if body_font:
			_capture_label.add_theme_font_override("font", body_font)
		_capture_overlay.add_child(_capture_label)
	_capture_overlay.visible = true
	# Add to parent so it covers everything
	var root_node: Node = get_parent() if get_parent() else self
	if _capture_overlay.get_parent() != root_node:
		if _capture_overlay.get_parent():
			_capture_overlay.get_parent().remove_child(_capture_overlay)
		root_node.add_child(_capture_overlay)


func _end_key_capture() -> void:
	_is_capturing = false
	_capturing_for = ""
	if _capture_overlay:
		_capture_overlay.visible = false


# ── Controls tab content ─────────────────────────────────────────────────────

func _rebuild_controls_content() -> void:
	if not _controls_content:
		return
	for child in _controls_content.get_children():
		child.queue_free()
	_controls_key_btns.clear()

	var body_font: Font = ThemeManager.get_font("font_body")

	# Slot bindings header
	var bindings_header := Label.new()
	bindings_header.text = "━━ SLOT BINDINGS ━━━━━━━━━━━━━━━━━"
	bindings_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	bindings_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		bindings_header.add_theme_font_override("font", body_font)
	_controls_content.add_child(bindings_header)

	# Binding rows
	var slot_labels: Dictionary = {
		"ext_0": "WEAPON 1", "ext_1": "WEAPON 2", "ext_2": "WEAPON 3",
		"int_0": "CORE 1", "int_1": "CORE 2", "int_2": "CORE 3",
		"dev_0": "DEVICE 1", "dev_1": "DEVICE 2",
	}
	var all_slots: Array = ["ext_0", "ext_1", "ext_2", "int_0", "int_1", "int_2", "dev_0", "dev_1"]
	for slot_key in all_slots:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = str(slot_labels.get(slot_key, slot_key))
		name_lbl.custom_minimum_size.x = 120
		name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		row.add_child(name_lbl)

		var key_btn := Button.new()
		key_btn.text = "[" + KeyBindingManager.get_key_label_for_slot(slot_key) + "]"
		key_btn.custom_minimum_size = Vector2(60, 30)
		ThemeManager.apply_button_style(key_btn)
		var bound_key: String = slot_key
		key_btn.pressed.connect(func() -> void: _start_key_capture(bound_key))
		row.add_child(key_btn)
		_controls_key_btns[slot_key] = key_btn

		_controls_content.add_child(row)

	# Combo presets header
	var presets_header := Label.new()
	presets_header.text = "━━ COMBO PRESETS ━━━━━━━━━━━━━━━━━"
	presets_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	presets_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		presets_header.add_theme_font_override("font", body_font)
	_controls_content.add_child(presets_header)

	_preset_list = VBoxContainer.new()
	_controls_content.add_child(_preset_list)

	_rebuild_presets()

	var save_combo_btn := Button.new()
	save_combo_btn.text = "SAVE CURRENT COMBO"
	save_combo_btn.custom_minimum_size.y = 34
	save_combo_btn.pressed.connect(_on_save_combo)
	ThemeManager.apply_button_style(save_combo_btn)
	_controls_content.add_child(save_combo_btn)


func _rebuild_presets() -> void:
	if not _preset_list:
		return
	for child in _preset_list.get_children():
		child.queue_free()

	var body_font: Font = ThemeManager.get_font("font_body")
	var presets: Array = KeyBindingManager.get_combo_presets()
	for i in presets.size():
		var preset: Dictionary = presets[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Key label button (rebindable)
		var key_btn := Button.new()
		key_btn.text = "[" + str(preset.get("key_label", "?")) + "]"
		key_btn.custom_minimum_size = Vector2(50, 30)
		ThemeManager.apply_button_style(key_btn)
		var bound_idx: int = i
		key_btn.pressed.connect(func() -> void: _start_key_capture("combo_" + str(bound_idx)))
		row.add_child(key_btn)

		# Label
		var name_lbl := Label.new()
		name_lbl.text = str(preset.get("label", "COMBO"))
		name_lbl.custom_minimum_size.x = 100
		name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		row.add_child(name_lbl)

		# Dot pattern
		var pattern: Dictionary = preset.get("pattern", {})
		var dots_lbl := Label.new()
		var dots_text: String = ""
		var all_slots: Array = ["ext_0", "ext_1", "ext_2", "int_0", "int_1", "int_2", "dev_0", "dev_1"]
		for sk in all_slots:
			var on: bool = pattern.get(sk, false)
			dots_text += "●" if on else "○"
		dots_lbl.text = dots_text
		dots_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		dots_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		dots_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(dots_lbl)

		# Load button
		var load_btn := Button.new()
		load_btn.text = "LOAD"
		load_btn.custom_minimum_size = Vector2(50, 28)
		ThemeManager.apply_button_style(load_btn)
		load_btn.pressed.connect(func() -> void: _load_combo_pattern(bound_idx))
		row.add_child(load_btn)

		# Delete button
		var del_btn := Button.new()
		del_btn.text = "X"
		del_btn.custom_minimum_size = Vector2(30, 28)
		ThemeManager.apply_button_style(del_btn)
		del_btn.pressed.connect(func() -> void: _delete_combo(bound_idx))
		row.add_child(del_btn)

		_preset_list.add_child(row)


func _load_combo_pattern(index: int) -> void:
	var presets: Array = KeyBindingManager.get_combo_presets()
	if index < 0 or index >= presets.size():
		return
	var preset: Dictionary = presets[index]
	var pattern: Dictionary = preset.get("pattern", {})
	for slot_key in _slot_active:
		_slot_active[slot_key] = pattern.get(slot_key, false)
	# Update toggle button visuals
	for slot_key in _slot_toggle_btns:
		var btn: Button = _slot_toggle_btns[slot_key]
		var is_on: bool = _slot_active.get(slot_key, false)
		btn.text = "ON" if is_on else "OFF"
		if is_on:
			btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		else:
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	_sync_preview_active_states()


func _on_save_combo() -> void:
	# Start key capture for the new combo
	_start_key_capture("combo_new")


func _finish_save_combo(physical_keycode: int, key_label: String) -> void:
	# Build pattern from current slot_active
	var pattern: Dictionary = {}
	for slot_key in _slot_active:
		pattern[slot_key] = _slot_active[slot_key]

	# Generate label from active slots
	var label: String = _generate_combo_label(pattern)
	KeyBindingManager.add_combo_preset(label, pattern, physical_keycode, key_label)
	_rebuild_presets()


func _generate_combo_label(pattern: Dictionary) -> String:
	var ext_count: int = 0
	var int_count: int = 0
	var dev_count: int = 0
	for slot_key in pattern:
		var on: bool = pattern[slot_key]
		if not on:
			continue
		if str(slot_key).begins_with("ext_"):
			ext_count += 1
		elif str(slot_key).begins_with("int_"):
			int_count += 1
		elif str(slot_key).begins_with("dev_"):
			dev_count += 1
	var parts: Array[String] = []
	if ext_count > 0:
		parts.append(str(ext_count) + "W")
	if int_count > 0:
		parts.append(str(int_count) + "C")
	if dev_count > 0:
		parts.append(str(dev_count) + "D")
	if parts.is_empty():
		return "EMPTY"
	return "+".join(parts)


func _delete_combo(index: int) -> void:
	KeyBindingManager.remove_combo_preset(index)
	_rebuild_presets()


# ── Audio mode content ───────────────────────────────────────────────────────

func _rebuild_audio_content() -> void:
	if not _audio_content:
		return
	for child in _audio_content.get_children():
		child.queue_free()
	_audio_sliders.clear()

	var body_font: Font = ThemeManager.get_font("font_body")

	# Header
	var sep_lbl := Label.new()
	sep_lbl.text = "━━ LOOP VOLUMES ━━━━━━━━━━━━━━━━━━"
	sep_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	sep_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		sep_lbl.add_theme_font_override("font", body_font)
	_audio_content.add_child(sep_lbl)

	# Per-slot volume slider rows
	var all_slots: Array = ["ext_0", "ext_1", "ext_2", "int_0", "int_1", "int_2", "dev_0", "dev_1"]
	var slot_labels: Dictionary = {
		"ext_0": "WEAPON 1", "ext_1": "WEAPON 2", "ext_2": "WEAPON 3",
		"int_0": "CORE 1", "int_1": "CORE 2", "int_2": "CORE 3",
		"dev_0": "DEVICE 1", "dev_1": "DEVICE 2",
	}
	for slot_key in all_slots:
		var item_name: String = _get_slot_item_name(slot_key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		var type_text: String = str(slot_labels.get(slot_key, slot_key))
		name_lbl.text = type_text + " — " + item_name
		name_lbl.custom_minimum_size.x = 180
		name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		row.add_child(name_lbl)

		if item_name != "empty":
			var stored_vol: float = KeyBindingManager.get_slot_volume(slot_key)

			var slider := HSlider.new()
			slider.min_value = -40.0
			slider.max_value = 6.0
			slider.step = 0.5
			slider.value = stored_vol
			slider.custom_minimum_size = Vector2(160, 20)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var bound_key: String = slot_key
			row.add_child(slider)

			var val_lbl := Label.new()
			val_lbl.text = _format_db(stored_vol)
			val_lbl.custom_minimum_size.x = 55
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
			val_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
			if body_font:
				val_lbl.add_theme_font_override("font", body_font)
			row.add_child(val_lbl)

			slider.value_changed.connect(func(new_val: float) -> void: _on_volume_slider_changed(bound_key, new_val))
			_audio_sliders[slot_key] = {"slider": slider, "label": val_lbl}

		_audio_content.add_child(row)

	# Global controls at bottom
	var global_hbox := HBoxContainer.new()
	global_hbox.add_theme_constant_override("separation", 10)

	var play_btn := Button.new()
	play_btn.text = "PLAY" if not _is_playing else "PAUSE"
	play_btn.custom_minimum_size = Vector2(80, 34)
	play_btn.pressed.connect(_on_play_toggle)
	ThemeManager.apply_button_style(play_btn)
	global_hbox.add_child(play_btn)

	var mute_all_btn := Button.new()
	mute_all_btn.text = "MUTE ALL" if not _is_muted else "UNMUTE ALL"
	mute_all_btn.custom_minimum_size = Vector2(100, 34)
	mute_all_btn.pressed.connect(_on_mute_toggle)
	ThemeManager.apply_button_style(mute_all_btn)
	global_hbox.add_child(mute_all_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET BARS"
	reset_btn.custom_minimum_size = Vector2(100, 34)
	reset_btn.pressed.connect(_on_reset_bars)
	ThemeManager.apply_button_style(reset_btn)
	global_hbox.add_child(reset_btn)

	_audio_content.add_child(global_hbox)


func _format_db(db: float) -> String:
	if db <= -40.0:
		return "-INF"
	var prefix: String = "+" if db > 0.0 else ""
	return prefix + "%.1f dB" % db


func _on_volume_slider_changed(slot_key: String, volume_db: float) -> void:
	# Update label
	if _audio_sliders.has(slot_key):
		var entry: Dictionary = _audio_sliders[slot_key]
		var lbl: Label = entry["label"]
		lbl.text = _format_db(volume_db)

	# Apply to LoopMixer live
	var loop_id: String = _get_loop_id_for_slot(slot_key)
	if loop_id != "" and LoopMixer.has_loop(loop_id):
		LoopMixer.set_volume(loop_id, volume_db)

	# Persist
	KeyBindingManager.set_slot_volume(slot_key, volume_db)


func _get_slot_item_name(slot_key: String) -> String:
	var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
	if slot_key.begins_with("ext_"):
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				return w.display_name if w.display_name != "" else w.id
			return weapon_id
	else:
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			if slot_key.begins_with("int_"):
				var pc: PowerCoreData = _power_core_cache.get(device_id)
				if pc:
					return pc.display_name if pc.display_name != "" else pc.id
			else:
				var d: DeviceData = _device_cache.get(device_id)
				if d:
					return d.display_name if d.display_name != "" else d.id
			return device_id
	return "empty"


func _get_loop_id_for_slot(slot_key: String) -> String:
	if slot_key.begins_with("ext_"):
		return "weapon_" + slot_key.replace("ext_", "")
	elif slot_key.begins_with("int_"):
		return "core_" + slot_key.replace("int_", "")
	elif slot_key.begins_with("dev_"):
		return "device_" + slot_key.replace("dev_", "")
	return ""




# ── Build UI ─────────────────────────────────────────────────────────────────

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
	_ship_thumb.render_mode = ShipRenderer.RenderMode.CHROME
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

	# Playback controls on left panel
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

	# CENTER — mode toggle + content
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

	# Mode toggle buttons
	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 6)
	_center_vbox.add_child(mode_hbox)

	# Spacer below mode tabs
	var mode_spacer := Control.new()
	mode_spacer.custom_minimum_size.y = 6
	_center_vbox.add_child(mode_spacer)

	_functional_btn = Button.new()
	_functional_btn.text = "FUNCTIONAL"
	_functional_btn.custom_minimum_size = Vector2(110, 36)
	_functional_btn.pressed.connect(func() -> void: _on_mode_toggle("functional"))
	mode_hbox.add_child(_functional_btn)

	_audio_btn = Button.new()
	_audio_btn.text = "AUDIO"
	_audio_btn.custom_minimum_size = Vector2(80, 36)
	_audio_btn.pressed.connect(func() -> void: _on_mode_toggle("audio"))
	mode_hbox.add_child(_audio_btn)

	_controls_btn = Button.new()
	_controls_btn.text = "CONTROLS"
	_controls_btn.custom_minimum_size = Vector2(100, 36)
	_controls_btn.pressed.connect(func() -> void: _on_mode_toggle("controls"))
	mode_hbox.add_child(_controls_btn)

	# FUNCTIONAL content
	_functional_content = VBoxContainer.new()
	_functional_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_functional_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_functional_content.add_theme_constant_override("separation", 4)
	_center_vbox.add_child(_functional_content)

	# Weapons section
	var ext_header_bar: PanelContainer = _create_section_header_bar("WEAPONS", "ext")
	_functional_content.add_child(ext_header_bar)

	_ext_section = VBoxContainer.new()
	_ext_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_ext_section)

	# Add spacer between sections
	var spacer_1 := Control.new()
	spacer_1.custom_minimum_size.y = 8
	_functional_content.add_child(spacer_1)

	# Cores section
	var int_header_bar: PanelContainer = _create_section_header_bar("CORES", "int")
	_functional_content.add_child(int_header_bar)

	_int_section = VBoxContainer.new()
	_int_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_int_section)

	# Add spacer between sections
	var spacer_2 := Control.new()
	spacer_2.custom_minimum_size.y = 8
	_functional_content.add_child(spacer_2)

	# Devices section
	var dev_header_bar: PanelContainer = _create_section_header_bar("DEVICES", "dev")
	_functional_content.add_child(dev_header_bar)

	_dev_section = VBoxContainer.new()
	_dev_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_dev_section)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_functional_content.add_child(spacer)

	# AUDIO content (hidden by default)
	_audio_content = VBoxContainer.new()
	_audio_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_audio_content.visible = false
	_center_vbox.add_child(_audio_content)

	# CONTROLS content (hidden by default)
	_controls_content = VBoxContainer.new()
	_controls_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_controls_content.visible = false
	_center_vbox.add_child(_controls_content)

	# Bottom buttons (always visible, below all content areas)
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

	# RIGHT — item picker panel
	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_stretch_ratio = 0.8
	right_margin.add_theme_constant_override("margin_left", 10)
	root.add_child(right_margin)

	_right_panel = VBoxContainer.new()
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.visible = false
	right_margin.add_child(_right_panel)

	_right_panel_header = Label.new()
	_right_panel_header.text = ""
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


# ── Playback controls ────────────────────────────────────────────────────────

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
		# Only activate controllers for slots that are toggled ON
		_is_playing = true
		_sync_preview_active_states()
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


# ── Preview management ───────────────────────────────────────────────────────

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
		var core_vol: float = KeyBindingManager.get_slot_volume(slot_key)
		if core_vol != 0.0:
			LoopMixer.set_volume(loop_id, core_vol)
		_core_previews.append({"pc": pc, "loop_id": loop_id, "prev_pos": -1.0, "triggers": merged})

	# Apply stored volumes for weapon preview loops
	var ext_ctrl_idx: int = 0
	for i2 in 3:
		var sk: String = "ext_" + str(i2)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		var wid: String = str(sd.get("weapon_id", ""))
		if wid == "":
			continue
		if ext_ctrl_idx < _preview_controllers.size():
			var ctrl_loop_id: String = _preview_controllers[ext_ctrl_idx]._loop_id
			var ext_vol: float = KeyBindingManager.get_slot_volume(sk)
			if ctrl_loop_id != "" and ext_vol != 0.0:
				LoopMixer.set_volume(ctrl_loop_id, ext_vol)
		ext_ctrl_idx += 1

	# If already playing, sync active states
	if _is_playing:
		_sync_preview_active_states()
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
		var bar_specs: Array = ThemeManager.get_status_bar_specs()
		for spec in bar_specs:
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
		# Only fire effects if slot is active
		var slot_idx: String = loop_id.replace("core_", "")
		var slot_key: String = "int_" + slot_idx
		if not _slot_active.get(slot_key, false):
			continue
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
	# Key capture mode intercepts all keys
	if _is_capturing and event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event: InputEventKey = event as InputEventKey
		get_viewport().set_input_as_handled()

		# ESC cancels
		if key_event.physical_keycode == KEY_ESCAPE:
			_end_key_capture()
			return

		var pkc: int = key_event.physical_keycode as int

		# Check reserved keys
		if KeyBindingManager.is_key_reserved(pkc):
			# Flash warning but don't bind
			if _capture_label:
				_capture_label.text = "RESERVED KEY!\nPRESS A KEY... (ESC to cancel)"
			return

		var label: String = OS.get_keycode_string(key_event.physical_keycode)
		if label == "":
			label = "KEY_" + str(pkc)

		if _capturing_for == "combo_new":
			_end_key_capture()
			_finish_save_combo(pkc, label)
		elif _capturing_for.begins_with("combo_"):
			# Rebinding existing combo preset key
			var idx_str: String = _capturing_for.replace("combo_", "")
			var idx: int = int(idx_str)
			var presets: Array = KeyBindingManager.get_combo_presets()
			if idx >= 0 and idx < presets.size():
				presets[idx]["physical_keycode"] = pkc
				presets[idx]["key_label"] = label
				KeyBindingManager.apply_to_input_map()
				KeyBindingManager.save_bindings()
			_end_key_capture()
			_rebuild_presets()
		else:
			# Rebinding a slot key
			KeyBindingManager.set_slot_key(_capturing_for, pkc, label)
			_end_key_capture()
			# Update the key label button in controls tab
			if _controls_key_btns.has(_capturing_for):
				var btn: Button = _controls_key_btns[_capturing_for]
				btn.text = "[" + label + "]"
		return

	if event.is_action_pressed("ui_cancel") and not _is_capturing:
		_on_back()
