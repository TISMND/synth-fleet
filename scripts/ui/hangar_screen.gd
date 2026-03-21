extends MarginContainer
## Hangar Screen — ship thumbnail + stats on left, LOADOUT/ASSIGN FIRE GROUPS/AUDIO MIX tabs center.

var _ship_renderer: ShipRenderer
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
var _bar_gain_waves: Dictionary = {}  # bar_name -> {"active": bool, "position": float}
var _bar_drain_waves: Dictionary = {}  # bar_name -> {"active": bool, "position": float}
const BAR_WAVE_SPEED: float = 2.5
const BAR_WAVE_MIN_CHANGE: float = 0.01
var _play_btn: Button
var _mute_btn: Button
var _is_playing: bool = false
var _is_muted: bool = false

var _weapon_cache: Dictionary = {}
var _power_core_cache: Dictionary = {}
var _device_cache: Dictionary = {}

# Right panel (item picker)
var _right_panel: VBoxContainer
var _right_panel_header: Label
var _right_panel_scroll: ScrollContainer
var _right_panel_list: VBoxContainer
var _expanded_slot: String = ""
var _picker_item_panels: Dictionary = {}  # item_id -> PanelContainer
var _picker_desc_wrappers: Dictionary = {}  # item_id -> Control (clip wrapper for description)
var _picker_desc_labels: Dictionary = {}  # item_id -> Label (description label inside wrapper)
var _ext_slot_btns: Dictionary = {}  # slot_key -> Button (header)
var _int_slot_btns: Dictionary = {}

# Live weapon preview
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _preview_node: Node2D  # positioned at ship center, parent of controllers
var _proj_container: Node2D  # projectiles land here
var _preview_controllers: Array = []  # HardpointController instances

# Power core preview — lightweight pulse trigger tracking
var _core_previews: Array = []  # Array of Dicts: {pc, loop_id, prev_pos, triggers}

# Device preview — field emitter / orbital generator pulse trigger tracking
var _device_previews: Array = []  # Array of Dicts: {device, loop_id, slot_key, prev_pos}

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
	for i in GameState.get_external_slot_count():
		_slot_active["ext_" + str(i)] = false
	for i in GameState.get_internal_slot_count():
		_slot_active["int_" + str(i)] = false


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

	# Right panel — re-highlight the currently selected panel
	if _right_panel and _right_panel.visible and _expanded_slot != "":
		_unhighlight_all_picker_panels()
		var cur_sd: Dictionary = GameState.slot_config.get(_expanded_slot, {})
		var cur_id: String = str(cur_sd.get("weapon_id", str(cur_sd.get("device_id", ""))))
		if cur_id != "" and _picker_item_panels.has(cur_id):
			_highlight_picker_panel(_picker_item_panels[cur_id])

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
	_ship_renderer.ship_id = idx
	_ship_renderer.queue_redraw()
	call_deferred("_position_hangar_thumb")
	_update_stats(info["stats"])
	_rebuild_buttons()
	_sync_preview()


func _position_hangar_thumb() -> void:
	var vp_size: Vector2 = Vector2(_sub_viewport.size)
	var center := Vector2(vp_size.x / 2.0, vp_size.y * 0.55)
	_ship_renderer.position = center
	_ship_renderer.queue_redraw()
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
	_set_bar("THERMAL", 0, thermal_seg)
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
	_slot_toggle_btns.clear()
	_ext_slot_btns.clear()
	_int_slot_btns.clear()

	# External slots (weapons + flexible devices)
	for i in GameState.get_external_slot_count():
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		var item_name: String = "empty"
		if comp_type == "weapon":
			var weapon_id: String = str(slot_data.get("weapon_id", ""))
			if weapon_id != "":
				var w: WeaponData = _weapon_cache.get(weapon_id)
				if w:
					item_name = w.display_name if w.display_name != "" else w.id
				else:
					item_name = weapon_id
		elif comp_type == "device":
			var device_id: String = str(slot_data.get("device_id", ""))
			if device_id != "":
				var d: DeviceData = _device_cache.get(device_id)
				if d:
					item_name = d.display_name if d.display_name != "" else d.id
				else:
					item_name = device_id

		var row: PanelContainer = _create_slot_row(slot_key, item_name)
		_ext_section.add_child(row)

	# Internal slots (power cores + internal/flexible devices)
	for i in GameState.get_internal_slot_count():
		var slot_key: String = "int_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		var item_name: String = "empty"
		if comp_type == "power_core":
			var device_id: String = str(slot_data.get("device_id", ""))
			if device_id != "":
				var pc: PowerCoreData = _power_core_cache.get(device_id)
				if pc:
					item_name = pc.display_name if pc.display_name != "" else pc.id
				else:
					item_name = device_id
		elif comp_type == "device":
			var device_id: String = str(slot_data.get("device_id", ""))
			if device_id != "":
				var d: DeviceData = _device_cache.get(device_id)
				if d:
					item_name = d.display_name if d.display_name != "" else d.id
				else:
					item_name = device_id

		var row: PanelContainer = _create_slot_row(slot_key, item_name)
		_int_section.add_child(row)

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

	return panel


func _get_slot_type_color(slot_key: String) -> Color:
	if slot_key.begins_with("ext_"):
		return ThemeManager.get_color("bar_shield")  # Cyan-ish for external
	elif slot_key.begins_with("int_"):
		return ThemeManager.get_color("bar_electric")  # Yellow for internal
	return ThemeManager.get_color("accent")


func _create_slot_row(slot_key: String, item_name: String) -> PanelContainer:
	# Dark backing panel for readability over the BG
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 6
	panel_style.content_margin_right = 6
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", panel_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	# Toggle button
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(150, 38)
	toggle.clip_text = true
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var is_active: bool = _slot_active.get(slot_key, false)
	toggle.text = "PREVIEWING" if is_active else "PAUSED"
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
	header.text = item_name
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

	return panel


func _on_slot_toggle(slot_key: String) -> void:
	var new_state: bool = not _slot_active.get(slot_key, false)
	_slot_active[slot_key] = new_state

	# Update toggle button appearance
	if _slot_toggle_btns.has(slot_key):
		var btn: Button = _slot_toggle_btns[slot_key]
		btn.text = "PREVIEWING" if new_state else "PAUSED"
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
	for d in [_ext_slot_btns, _int_slot_btns]:
		for key in d:
			var b: Button = d[key]
			b.remove_theme_color_override("font_color")


func _get_slot_btn(slot_key: String) -> Button:
	if _ext_slot_btns.has(slot_key):
		return _ext_slot_btns[slot_key]
	if _int_slot_btns.has(slot_key):
		return _int_slot_btns[slot_key]
	return null


func _get_equipped_ids() -> Array[String]:
	## Collect all equipped item IDs across all slots for duplicate prevention.
	var ids: Array[String] = []
	for key in GameState.slot_config:
		var sd: Dictionary = GameState.slot_config[key]
		var wid: String = str(sd.get("weapon_id", ""))
		if wid != "":
			ids.append(wid)
		var did: String = str(sd.get("device_id", ""))
		if did != "":
			ids.append(did)
	return ids


func _add_picker_item(item_id: String, label: String, description: String, slot_key: String, equipped_ids: Array[String], component_type: String) -> void:
	var body_font: Font = ThemeManager.get_font("font_body")
	var accent: Color = ThemeManager.get_color("accent")
	var bg_color: Color = ThemeManager.get_color("background")

	# Filled panel container
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r + 0.08, bg_color.g + 0.08, bg_color.b + 0.08, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.15)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Title label
	var title_lbl := Label.new()
	title_lbl.text = label
	title_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	title_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	if body_font:
		title_lbl.add_theme_font_override("font", body_font)
	vbox.add_child(title_lbl)

	# Description label — starts collapsed, expands on selection
	var desc_wrapper := Control.new()
	desc_wrapper.clip_contents = true
	desc_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_wrapper.custom_minimum_size = Vector2(0, 0)
	vbox.add_child(desc_wrapper)

	var desc_lbl := Label.new()
	desc_lbl.text = description if description != "" else "No description."
	desc_lbl.add_theme_color_override("font_color", Color(ThemeManager.get_color("body"), 0.5))
	desc_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body") - 2)
	if body_font:
		desc_lbl.add_theme_font_override("font", body_font)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Anchor label to fill wrapper width so autowrap works
	desc_lbl.anchor_left = 0.0
	desc_lbl.anchor_right = 1.0
	desc_lbl.anchor_top = 0.0
	desc_lbl.offset_right = 0.0
	desc_wrapper.add_child(desc_lbl)

	_picker_desc_wrappers[item_id] = desc_wrapper
	_picker_desc_labels[item_id] = desc_lbl

	# Grey out if already equipped elsewhere
	var is_duplicate: bool = item_id in equipped_ids
	var current_sd: Dictionary = GameState.slot_config.get(slot_key, {})
	var current_id: String = ""
	if component_type == "weapon":
		current_id = str(current_sd.get("weapon_id", ""))
	else:
		current_id = str(current_sd.get("device_id", ""))
	if is_duplicate and item_id != current_id:
		panel.modulate = Color(1, 1, 1, 0.3)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		# Clickable — use invisible button overlay
		var click_btn := Button.new()
		click_btn.flat = true
		click_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		click_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Transparent style so the panel shows through
		var empty_sb := StyleBoxEmpty.new()
		click_btn.add_theme_stylebox_override("normal", empty_sb)
		click_btn.add_theme_stylebox_override("hover", empty_sb)
		click_btn.add_theme_stylebox_override("pressed", empty_sb)
		click_btn.add_theme_stylebox_override("focus", empty_sb)
		var bound_key: String = slot_key
		var bound_id: String = item_id
		var bound_type: String = component_type
		click_btn.pressed.connect(func() -> void: _select_item_typed(bound_key, bound_id, bound_type))
		panel.add_child(click_btn)

	# Highlight + expand description if currently equipped in this slot
	if item_id == current_id and item_id != "":
		_highlight_picker_panel(panel)
		# Deferred expand — label needs a frame to measure
		var expand_id: String = item_id
		(func() -> void: _expand_picker_description(expand_id)).call_deferred()

	_picker_item_panels[item_id] = panel
	_right_panel_list.add_child(panel)


func _add_picker_category(title: String) -> void:
	var body_font: Font = ThemeManager.get_font("font_body")
	var lbl := Label.new()
	lbl.text = "── " + title + " ──"
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	if body_font:
		lbl.add_theme_font_override("font", body_font)
	# Small top margin for spacing between categories
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_child(lbl)
	_right_panel_list.add_child(margin)


func _populate_right_panel(slot_key: String) -> void:
	_clear_right_panel()
	_right_panel.visible = true
	_picker_item_panels.clear()

	var body_font: Font = ThemeManager.get_font("font_body")
	var equipped_ids: Array[String] = _get_equipped_ids()

	if slot_key.begins_with("ext_"):

		# Beam Weapons
		var has_beams: bool = false
		for wid in _weapon_cache:
			var w: WeaponData = _weapon_cache[wid]
			if w.beam_style_id != "":
				if not has_beams:
					_add_picker_category("BEAM WEAPONS")
					has_beams = true
				var label: String = w.display_name if w.display_name != "" else w.id
				_add_picker_item(wid, label, w.description, slot_key, equipped_ids, "weapon")

		# Projectile Weapons
		var has_projectiles: bool = false
		for wid in _weapon_cache:
			var w: WeaponData = _weapon_cache[wid]
			if w.beam_style_id == "":
				if not has_projectiles:
					_add_picker_category("PROJECTILE WEAPONS")
					has_projectiles = true
				var label: String = w.display_name if w.display_name != "" else w.id
				_add_picker_item(wid, label, w.description, slot_key, equipped_ids, "weapon")

		# Field Emitters (external/flexible only)
		var has_fields: bool = false
		for did in _device_cache:
			var d: DeviceData = _device_cache[did]
			if d.visual_mode != "field":
				continue
			if d.equip_slot == "flexible" or d.equip_slot == "external":
				if not has_fields:
					_add_picker_category("FIELD EMITTERS")
					has_fields = true
				var label: String = d.display_name if d.display_name != "" else d.id
				_add_picker_item(did, label, d.description, slot_key, equipped_ids, "device")

	elif slot_key.begins_with("int_"):

		# Power Cores
		var has_cores: bool = false
		for pcid in _power_core_cache:
			if not has_cores:
				_add_picker_category("POWER CORES")
				has_cores = true
			var pc: PowerCoreData = _power_core_cache[pcid]
			var label: String = pc.display_name if pc.display_name != "" else pc.id
			_add_picker_item(pcid, label, pc.description, slot_key, equipped_ids, "power_core")

		# Field Emitters (internal/flexible only)
		var has_fields: bool = false
		for did in _device_cache:
			var d: DeviceData = _device_cache[did]
			if d.visual_mode != "field":
				continue
			if d.equip_slot == "flexible" or d.equip_slot == "internal":
				if not has_fields:
					_add_picker_category("FIELD EMITTERS")
					has_fields = true
				var label: String = d.display_name if d.display_name != "" else d.id
				_add_picker_item(did, label, d.description, slot_key, equipped_ids, "device")



func _select_item_typed(slot_key: String, item_id: String, component_type: String) -> void:
	if component_type == "weapon":
		GameState.set_slot_weapon(slot_key, item_id)
	elif component_type == "power_core":
		GameState.set_slot_device(slot_key, item_id, "power_core")
	elif component_type == "device":
		GameState.set_slot_device(slot_key, item_id, "device")
	else:
		# Clear slot
		if slot_key.begins_with("ext_"):
			GameState.set_slot_weapon(slot_key, "")
		else:
			GameState.set_slot_device(slot_key, "", "")
	# Update highlight + description — don't close the panel
	_unhighlight_all_picker_panels()
	_collapse_all_picker_descriptions()
	if item_id != "" and _picker_item_panels.has(item_id):
		_highlight_picker_panel(_picker_item_panels[item_id])
	_expand_picker_description(item_id)
	_rebuild_buttons()
	_sync_preview()


func _highlight_picker_panel(panel: PanelContainer) -> void:
	var accent: Color = ThemeManager.get_color("accent")
	var bg_color: Color = ThemeManager.get_color("background")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.2 + bg_color.r * 0.8, accent.g * 0.2 + bg_color.g * 0.8, accent.b * 0.2 + bg_color.b * 0.8, 0.95)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.8)
	panel.add_theme_stylebox_override("panel", style)


func _unhighlight_all_picker_panels() -> void:
	var accent: Color = ThemeManager.get_color("accent")
	var bg_color: Color = ThemeManager.get_color("background")
	for key in _picker_item_panels:
		var panel: PanelContainer = _picker_item_panels[key]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(bg_color.r + 0.08, bg_color.g + 0.08, bg_color.b + 0.08, 0.9)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(accent.r, accent.g, accent.b, 0.15)
		panel.add_theme_stylebox_override("panel", style)


func _expand_picker_description(item_id: String) -> void:
	if not _picker_desc_wrappers.has(item_id):
		return
	var wrapper: Control = _picker_desc_wrappers[item_id]
	var desc_lbl: Label = _picker_desc_labels[item_id]
	# Wait a frame so the label has computed its size within the panel width
	await wrapper.get_tree().process_frame
	var target_h: float = desc_lbl.get_combined_minimum_size().y
	var tween: Tween = wrapper.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(wrapper, "custom_minimum_size:y", target_h, 0.2)


func _collapse_all_picker_descriptions() -> void:
	for key in _picker_desc_wrappers:
		var wrapper: Control = _picker_desc_wrappers[key]
		# Kill any running tweens on this wrapper
		var tween: Tween = wrapper.create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(wrapper, "custom_minimum_size:y", 0.0, 0.15)


func _clear_right_panel() -> void:
	for child in _right_panel_list.get_children():
		child.queue_free()
	_picker_item_panels.clear()
	_picker_desc_wrappers.clear()
	_picker_desc_labels.clear()
	_right_panel.visible = false
	_right_panel_header.text = ""


func _sync_preview_active_states() -> void:
	if not _is_playing:
		return

	# Sync weapon controllers (ext slots with weapon component_type)
	var ext_controller_idx: int = 0
	for i in GameState.get_external_slot_count():
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		if comp_type != "weapon":
			continue
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
		var slot_idx: String = loop_id.replace("core_", "")
		var slot_key: String = "int_" + slot_idx
		if _slot_active.get(slot_key, false):
			LoopMixer.unmute(loop_id)
		else:
			LoopMixer.mute(loop_id)

	# Sync device previews — mute/unmute loops
	for entry in _device_previews:
		var loop_id: String = entry["loop_id"]
		var slot_key: String = entry["slot_key"]
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

	# Binding rows — built dynamically from slot counts
	var all_slots: Array = []
	for i in GameState.get_external_slot_count():
		all_slots.append("ext_" + str(i))
	for i in GameState.get_internal_slot_count():
		all_slots.append("int_" + str(i))

	for slot_key in all_slots:
		var item_name: String = _get_slot_item_name(slot_key)
		# Dark backing panel — matches loadout row style
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.0, 0.0, 0.0, 0.55)
		ps.corner_radius_top_left = 4
		ps.corner_radius_top_right = 4
		ps.corner_radius_bottom_left = 4
		ps.corner_radius_bottom_right = 4
		ps.content_margin_left = 8
		ps.content_margin_right = 8
		ps.content_margin_top = 6
		ps.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", ps)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		# Key binding button on the left (like PREVIEWING/PAUSED toggle position)
		var key_btn := Button.new()
		key_btn.text = "[" + KeyBindingManager.get_key_label_for_slot(slot_key) + "]"
		key_btn.custom_minimum_size = Vector2(70, 38)
		key_btn.clip_text = true
		key_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ThemeManager.apply_button_style(key_btn)
		key_btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		var bound_key: String = slot_key
		key_btn.pressed.connect(func() -> void: _start_key_capture(bound_key))
		row.add_child(key_btn)
		_controls_key_btns[slot_key] = key_btn

		# Item name label — fills remaining space
		var name_lbl := Label.new()
		name_lbl.text = item_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_color: Color = _get_slot_type_color(slot_key)
		name_lbl.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.7))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		row.add_child(name_lbl)

		_controls_content.add_child(panel)

	# Spacer before presets
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	_controls_content.add_child(spacer)

	# Combo presets section
	_preset_list = VBoxContainer.new()
	_preset_list.add_theme_constant_override("separation", 4)
	_controls_content.add_child(_preset_list)

	_rebuild_presets()

	var save_spacer := Control.new()
	save_spacer.custom_minimum_size.y = 6
	_controls_content.add_child(save_spacer)

	var save_combo_btn := Button.new()
	save_combo_btn.text = "SAVE CURRENT COMBO"
	save_combo_btn.custom_minimum_size.y = 38
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

		# Dark backing panel
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.0, 0.0, 0.0, 0.45)
		ps.corner_radius_top_left = 4
		ps.corner_radius_top_right = 4
		ps.corner_radius_bottom_left = 4
		ps.corner_radius_bottom_right = 4
		ps.content_margin_left = 8
		ps.content_margin_right = 8
		ps.content_margin_top = 4
		ps.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", ps)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		panel.add_child(row)

		# Key label button (rebindable)
		var key_btn := Button.new()
		key_btn.text = "[" + str(preset.get("key_label", "?")) + "]"
		key_btn.custom_minimum_size = Vector2(50, 34)
		ThemeManager.apply_button_style(key_btn)
		key_btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		var bound_idx: int = i
		key_btn.pressed.connect(func() -> void: _start_key_capture("combo_" + str(bound_idx)))
		row.add_child(key_btn)

		# Label
		var name_lbl := Label.new()
		name_lbl.text = str(preset.get("label", "COMBO"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		row.add_child(name_lbl)

		# Dot pattern
		var pattern: Dictionary = preset.get("pattern", {})
		var dots_lbl := Label.new()
		var dots_text: String = ""
		var dot_slots: Array = []
		for ei in GameState.get_external_slot_count():
			dot_slots.append("ext_" + str(ei))
		for ii in GameState.get_internal_slot_count():
			dot_slots.append("int_" + str(ii))
		for sk in dot_slots:
			var on: bool = pattern.get(sk, false)
			dots_text += "●" if on else "○"
		dots_lbl.text = dots_text
		dots_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		dots_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		row.add_child(dots_lbl)

		# Load button
		var load_btn := Button.new()
		load_btn.text = "LOAD"
		load_btn.custom_minimum_size = Vector2(60, 34)
		ThemeManager.apply_button_style(load_btn)
		load_btn.pressed.connect(func() -> void: _load_combo_pattern(bound_idx))
		row.add_child(load_btn)

		# Delete button
		var del_btn := Button.new()
		del_btn.text = "X"
		del_btn.custom_minimum_size = Vector2(34, 34)
		ThemeManager.apply_button_style(del_btn)
		del_btn.pressed.connect(func() -> void: _delete_combo(bound_idx))
		row.add_child(del_btn)

		_preset_list.add_child(panel)


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
		btn.text = "PREVIEWING" if is_on else "PAUSED"
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
	for slot_key in pattern:
		var on: bool = pattern[slot_key]
		if not on:
			continue
		if str(slot_key).begins_with("ext_"):
			ext_count += 1
		elif str(slot_key).begins_with("int_"):
			int_count += 1
	var parts: Array[String] = []
	if ext_count > 0:
		parts.append(str(ext_count) + "E")
	if int_count > 0:
		parts.append(str(int_count) + "I")
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

	# Per-slot volume slider rows — built dynamically from slot counts
	var audio_slots: Array = []
	for i in GameState.get_external_slot_count():
		audio_slots.append("ext_" + str(i))
	for i in GameState.get_internal_slot_count():
		audio_slots.append("int_" + str(i))

	for slot_key in audio_slots:
		var item_name: String = _get_slot_item_name(slot_key)

		# Dark backing panel — matches loadout row style
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.0, 0.0, 0.0, 0.55)
		ps.corner_radius_top_left = 4
		ps.corner_radius_top_right = 4
		ps.corner_radius_bottom_left = 4
		ps.corner_radius_bottom_right = 4
		ps.content_margin_left = 8
		ps.content_margin_right = 8
		ps.content_margin_top = 6
		ps.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", ps)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		# Item name at top of each card
		var name_lbl := Label.new()
		name_lbl.text = item_name
		var slot_color: Color = _get_slot_type_color(slot_key)
		name_lbl.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.7))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		vbox.add_child(name_lbl)

		if item_name != "empty":
			var stored_vol: float = KeyBindingManager.get_slot_volume(slot_key)

			# LED volume meter row
			var meter_row := HBoxContainer.new()
			meter_row.add_theme_constant_override("separation", 8)
			vbox.add_child(meter_row)

			# Fine segmented LED bar as volume control
			var vol_bar := ProgressBar.new()
			vol_bar.min_value = -40.0
			vol_bar.max_value = 6.0
			vol_bar.value = stored_vol
			vol_bar.show_percentage = false
			vol_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vol_bar.custom_minimum_size = Vector2(0, 20)
			vol_bar.mouse_filter = Control.MOUSE_FILTER_PASS
			meter_row.add_child(vol_bar)

			# Apply LED shader with fine segments
			var vol_ratio: float = (stored_vol - (-40.0)) / 46.0
			var slot_col: Color = _get_slot_type_color(slot_key)
			_apply_fine_led(vol_bar, slot_col, vol_ratio)

			# Click/drag handler overlay
			var click_area := Control.new()
			click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			vol_bar.add_child(click_area)

			var bound_key: String = slot_key
			var is_dragging: Array = [false]  # mutable ref for closures
			click_area.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mb: InputEventMouseButton = event as InputEventMouseButton
					if mb.button_index == MOUSE_BUTTON_LEFT:
						if mb.pressed:
							is_dragging[0] = true
							_on_vol_bar_click(bound_key, vol_bar, mb.position.x)
						else:
							is_dragging[0] = false
				elif event is InputEventMouseMotion and is_dragging[0]:
					var mm: InputEventMouseMotion = event as InputEventMouseMotion
					_on_vol_bar_click(bound_key, vol_bar, mm.position.x)
			)

			var val_lbl := Label.new()
			val_lbl.text = _format_db(stored_vol)
			val_lbl.custom_minimum_size.x = 65
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
			val_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
			if body_font:
				val_lbl.add_theme_font_override("font", body_font)
			meter_row.add_child(val_lbl)

			_audio_sliders[slot_key] = {"bar": vol_bar, "label": val_lbl}

		_audio_content.add_child(panel)



func _apply_fine_led(bar: ProgressBar, color: Color, ratio: float) -> void:
	## Apply LED shader with fine/thin segments for volume meters.
	var led_shader: Shader = load("res://assets/shaders/led_bar_hdr.gdshader") as Shader
	if not led_shader:
		return
	var seg_count: int = 46  # 1 segment per dB (-40 to +6)
	var seg_px: float = 4.0
	var gap_px: float = 1.5

	bar.custom_minimum_size.x = float(seg_count) * seg_px + float(seg_count - 1) * gap_px

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 1)
	bar.add_theme_stylebox_override("background", bg_style)

	var long_axis: float = maxf(bar.custom_minimum_size.x, 20.0)
	var gap_uv: float = gap_px / maxf(long_axis, 1.0)

	var mat := ShaderMaterial.new()
	mat.shader = led_shader
	bar.material = mat
	mat.set_shader_parameter("segment_count", seg_count)
	mat.set_shader_parameter("segment_gap", gap_uv)
	mat.set_shader_parameter("vertical", 0)
	mat.set_shader_parameter("inner_intensity", ThemeManager.get_float("led_inner_intensity"))
	mat.set_shader_parameter("inner_softness", ThemeManager.get_float("led_inner_softness"))
	mat.set_shader_parameter("smudge_blur", ThemeManager.get_float("led_smudge_blur"))
	mat.set_shader_parameter("fill_color", color)
	mat.set_shader_parameter("bg_color", ThemeManager.get_color("panel"))
	mat.set_shader_parameter("fill_ratio", ratio)
	mat.set_shader_parameter("hdr_multiplier", ThemeManager.get_float("led_hdr_multiplier"))


func _on_vol_bar_click(slot_key: String, bar: ProgressBar, click_x: float) -> void:
	## Convert click position to dB value and update volume.
	var ratio: float = clampf(click_x / maxf(bar.size.x, 1.0), 0.0, 1.0)
	var db: float = lerpf(-40.0, 6.0, ratio)
	# Snap to 0.5 dB steps
	db = roundf(db * 2.0) / 2.0
	bar.value = db

	# Update LED shader fill
	var new_ratio: float = (db - (-40.0)) / 46.0
	var mat: ShaderMaterial = bar.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fill_ratio", new_ratio)

	_on_volume_slider_changed(slot_key, db)


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
	var comp_type: String = str(slot_data.get("component_type", ""))
	if comp_type == "weapon":
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				return w.display_name if w.display_name != "" else w.id
			return weapon_id
	elif comp_type == "power_core":
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var pc: PowerCoreData = _power_core_cache.get(device_id)
			if pc:
				return pc.display_name if pc.display_name != "" else pc.id
			return device_id
	elif comp_type == "device":
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var d: DeviceData = _device_cache.get(device_id)
			if d:
				return d.display_name if d.display_name != "" else d.id
			return device_id
	return "empty"


func _get_loop_id_for_slot(slot_key: String) -> String:
	var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
	var comp_type: String = str(slot_data.get("component_type", ""))
	if comp_type == "weapon":
		# Match HardpointController's loop_id format: weapon.id + "_hp_" + hp_index
		# Find the matching controller by slot index
		var ext_idx: int = int(slot_key.replace("ext_", ""))
		var ctrl_idx: int = 0
		for i in GameState.get_external_slot_count():
			var sk: String = "ext_" + str(i)
			var sd: Dictionary = GameState.slot_config.get(sk, {})
			if str(sd.get("component_type", "")) != "weapon":
				continue
			if sk == slot_key:
				if ctrl_idx < _preview_controllers.size():
					return _preview_controllers[ctrl_idx]._loop_id
				return ""
			ctrl_idx += 1
		return ""
	elif comp_type == "power_core":
		return "core_" + slot_key.replace("int_", "")
	elif comp_type == "device":
		return "dev_" + slot_key
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
	# Fixed render size (400×500) so bloom matches dev studio previews exactly.
	# SubViewportContainer with stretch=true scales the output up for display.
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(400, 500)
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_sub_viewport)

	# Bloom for projectile glow — runs at fixed 400px, identical to dev studio
	VFXFactory.add_bloom_to_viewport(_sub_viewport)

	# Dark background for the viewport
	var vp_bg := ColorRect.new()
	vp_bg.color = Color(0.05, 0.06, 0.1)
	vp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_viewport.add_child(vp_bg)

	_ship_renderer = ShipRenderer.new()
	_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	_sub_viewport.add_child(_ship_renderer)

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
		_bar_gain_waves[bar_name] = {"active": false, "position": -1.0}
		_bar_drain_waves[bar_name] = {"active": false, "position": -1.0}

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
	_functional_btn.text = "LOADOUT"
	_functional_btn.custom_minimum_size = Vector2(100, 36)
	_functional_btn.pressed.connect(func() -> void: _on_mode_toggle("functional"))
	mode_hbox.add_child(_functional_btn)

	_controls_btn = Button.new()
	_controls_btn.text = "ASSIGN FIRE GROUPS"
	_controls_btn.custom_minimum_size = Vector2(160, 36)
	_controls_btn.pressed.connect(func() -> void: _on_mode_toggle("controls"))
	mode_hbox.add_child(_controls_btn)

	_audio_btn = Button.new()
	_audio_btn.text = "AUDIO MIX"
	_audio_btn.custom_minimum_size = Vector2(100, 36)
	_audio_btn.pressed.connect(func() -> void: _on_mode_toggle("audio"))
	mode_hbox.add_child(_audio_btn)

	# FUNCTIONAL content
	_functional_content = VBoxContainer.new()
	_functional_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_functional_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_functional_content.add_theme_constant_override("separation", 4)
	_center_vbox.add_child(_functional_content)

	# External section
	var ext_header_bar: PanelContainer = _create_section_header_bar("EXTERNAL", "ext")
	_functional_content.add_child(ext_header_bar)

	_ext_section = VBoxContainer.new()
	_ext_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_ext_section)

	# Add spacer between sections
	var spacer_1 := Control.new()
	spacer_1.custom_minimum_size.y = 8
	_functional_content.add_child(spacer_1)

	# Internal section
	var int_header_bar: PanelContainer = _create_section_header_bar("INTERNAL", "int")
	_functional_content.add_child(int_header_bar)

	_int_section = VBoxContainer.new()
	_int_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_int_section)

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

	# Outer VBox to push content down from top
	var right_outer := VBoxContainer.new()
	right_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right_outer)

	# Top spacer — keeps list from hugging the top edge
	var right_spacer := Control.new()
	right_spacer.custom_minimum_size.y = 40
	right_outer.add_child(right_spacer)

	# Semi-transparent backing panel for readability
	var right_backing := PanelContainer.new()
	right_backing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_backing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	backing_style.corner_radius_top_left = 6
	backing_style.corner_radius_top_right = 6
	backing_style.corner_radius_bottom_left = 6
	backing_style.corner_radius_bottom_right = 6
	backing_style.content_margin_left = 8
	backing_style.content_margin_right = 8
	backing_style.content_margin_top = 8
	backing_style.content_margin_bottom = 8
	right_backing.add_theme_stylebox_override("panel", backing_style)
	right_outer.add_child(right_backing)

	_right_panel = VBoxContainer.new()
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.visible = false
	right_backing.add_child(_right_panel)

	_right_panel_header = Label.new()
	_right_panel_header.text = ""
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

	# Cleanup old device loops
	for entry in _device_previews:
		var loop_id: String = entry["loop_id"]
		LoopMixer.remove_loop(loop_id)
	_device_previews.clear()

	# Create new controllers for each equipped ext slot with weapons
	for i in GameState.get_external_slot_count():
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		if comp_type != "weapon":
			continue
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

	# Register power core loops for each equipped int slot with power_core type
	for i in GameState.get_internal_slot_count():
		var slot_key: String = "int_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		if comp_type != "power_core":
			continue
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

	# Register device loops (field emitters / orbital generators) from all slots
	var _dev_slot_sources: Array = []
	for i3 in GameState.get_internal_slot_count():
		_dev_slot_sources.append("int_" + str(i3))
	for i3 in GameState.get_external_slot_count():
		_dev_slot_sources.append("ext_" + str(i3))
	for slot_key in _dev_slot_sources:
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		if comp_type != "device":
			continue
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		var device: DeviceData = _device_cache.get(device_id)
		if not device or device.loop_file_path == "":
			continue
		var loop_id: String = "dev_" + slot_key
		LoopMixer.add_loop(loop_id, device.loop_file_path)
		var dev_vol: float = KeyBindingManager.get_slot_volume(slot_key)
		if dev_vol != 0.0:
			LoopMixer.set_volume(loop_id, dev_vol)

		# Create FieldRenderer for field-mode devices
		var field_renderer: FieldRenderer = null
		if device.visual_mode == "field" and device.field_style_id != "":
			var style: FieldStyle = FieldStyleManager.load_by_id(device.field_style_id)
			if not style:
				style = FieldStyle.new()
				style.color = Color(0.0, 1.0, 1.0, 1.0)
			field_renderer = FieldRenderer.new()
			_preview_node.add_child(field_renderer)
			field_renderer.setup(style, device.radius, device.animation_speed)
			# Override z_index — default -1 renders behind SubViewport background
			field_renderer.z_index = 1
			field_renderer.set_pulse_timing(device.pulse_total_duration, device.pulse_fade_up, device.pulse_fade_out)
			# Always start hidden — slot must be toggled on + PLAY to see fields
			field_renderer.set_opacity(0.0)

		_device_previews.append({"device": device, "loop_id": loop_id, "slot_key": slot_key, "prev_pos": -1.0, "field_renderer": field_renderer})

	# Apply stored volumes for weapon preview loops
	var ext_ctrl_idx: int = 0
	for i2 in GameState.get_external_slot_count():
		var sk: String = "ext_" + str(i2)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		if str(sd.get("component_type", "")) != "weapon":
			continue
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
		if not _core_previews.is_empty() or not _device_previews.is_empty():
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
	for entry in _device_previews:
		var loop_id: String = entry["loop_id"]
		LoopMixer.remove_loop(loop_id)
		var fr: FieldRenderer = entry.get("field_renderer") as FieldRenderer
		if fr and is_instance_valid(fr):
			fr.queue_free()
	_device_previews.clear()
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
		# Scale effect so it feels proportional regardless of bar segment count.
		var raw_delta: float = float(effects[key])
		var delta: float = raw_delta * (bar.max_value / 80.0)
		var old_val: float = bar.value
		bar.value = clampf(bar.value + delta, 0.0, bar.max_value)
		var actual_change: float = bar.value - old_val
		# Trigger rolling wave
		var change_ratio: float = actual_change / maxf(bar.max_value, 1.0)
		if change_ratio > BAR_WAVE_MIN_CHANGE:
			_bar_gain_waves[bar_name]["active"] = true
			_bar_gain_waves[bar_name]["position"] = 0.0
		elif change_ratio < -BAR_WAVE_MIN_CHANGE:
			_bar_drain_waves[bar_name]["active"] = true
			_bar_drain_waves[bar_name]["position"] = 1.0
		# Update fill ratio on shader (don't rebuild the whole bar)
		if bar.material is ShaderMaterial:
			var mat: ShaderMaterial = bar.material as ShaderMaterial
			mat.set_shader_parameter("fill_ratio", bar.value / maxf(bar.max_value, 1.0))


func _advance_bar_waves(delta: float) -> void:
	for bar_name in _bars:
		var gain_wave: Dictionary = _bar_gain_waves.get(bar_name, {})
		var drain_wave: Dictionary = _bar_drain_waves.get(bar_name, {})
		# Advance gain wave (rolls from 0 → 1.3)
		if gain_wave.get("active", false):
			var pos: float = float(gain_wave["position"])
			pos += BAR_WAVE_SPEED * delta
			if pos > 1.3:
				gain_wave["active"] = false
				gain_wave["position"] = -1.0
			else:
				gain_wave["position"] = pos
		# Advance drain wave (rolls from 1 → -0.3)
		if drain_wave.get("active", false):
			var pos: float = float(drain_wave["position"])
			pos -= BAR_WAVE_SPEED * delta
			if pos < -0.3:
				drain_wave["active"] = false
				drain_wave["position"] = -1.0
			else:
				drain_wave["position"] = pos
		# Push wave positions to shader
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			var mat: ShaderMaterial = bar.material as ShaderMaterial
			var gp: float = float(gain_wave["position"]) if gain_wave.get("active", false) else -1.0
			var dp: float = float(drain_wave["position"]) if drain_wave.get("active", false) else -1.0
			mat.set_shader_parameter("gain_wave_pos", gp)
			mat.set_shader_parameter("drain_wave_pos", dp)


func _process(_delta: float) -> void:
	_advance_bar_waves(_delta)
	if not _is_playing:
		return
	_process_core_previews()
	_process_device_previews()
	_update_ship_field_tint()


func _process_core_previews() -> void:
	if _core_previews.is_empty():
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
		# Passive effects — apply per-second rate * delta while active
		if not pc.passive_effects.is_empty():
			var passive_delta: Dictionary = {}
			for bar_type in pc.passive_effects:
				var rate: float = float(pc.passive_effects[bar_type])
				if rate != 0.0:
					passive_delta[str(bar_type)] = rate * get_process_delta_time()
			if not passive_delta.is_empty():
				_on_bar_effect_fired(passive_delta)
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


func _process_device_previews() -> void:
	if _device_previews.is_empty():
		return
	for entry in _device_previews:
		var device: DeviceData = entry["device"]
		var loop_id: String = entry["loop_id"]
		var slot_key: String = entry["slot_key"]
		var fr: FieldRenderer = entry.get("field_renderer") as FieldRenderer
		var is_active: bool = _slot_active.get(slot_key, false)

		# Manage field visibility based on active state
		if fr:
			if is_active:
				if device.active_always_on:
					fr.set_opacity(1.0)
				fr.visible = true
			else:
				fr.set_opacity(0.0)
				# Kill any running pulse so it doesn't keep driving brightness
				fr._pulse_active = false
				if fr._material:
					fr._material.set_shader_parameter("pulse_intensity", 0.0)
				fr.visible = false

		# Passive effects — apply per-second rate * delta while active
		if is_active and not device.passive_effects.is_empty():
			var passive_delta: Dictionary = {}
			for bar_type in device.passive_effects:
				var rate: float = float(device.passive_effects[bar_type])
				if rate != 0.0:
					passive_delta[str(bar_type)] = rate * get_process_delta_time()
			if not passive_delta.is_empty():
				_on_bar_effect_fired(passive_delta)

		var pos_sec: float = LoopMixer.get_playback_position(loop_id)
		var duration: float = LoopMixer.get_stream_duration(loop_id)
		if pos_sec < 0.0 or duration <= 0.0:
			continue
		var curr: float = pos_sec / duration
		var prev: float = float(entry["prev_pos"])
		entry["prev_pos"] = curr
		if prev < 0.0:
			continue
		if not is_active:
			continue

		# Check pulse triggers
		for t in device.pulse_triggers:
			var tval: float = float(t)
			var crossed: bool = false
			if curr >= prev:
				crossed = tval > prev and tval <= curr
			else:
				crossed = tval > prev or tval <= curr
			if crossed:
				if fr:
					fr.set_opacity(1.0)
					fr.pulse()
				if not device.bar_effects.is_empty():
					_on_bar_effect_fired(device.bar_effects)

		# Check visual-only pulse triggers
		if fr:
			for t in device.visual_pulse_triggers:
				var tval: float = float(t)
				var crossed: bool = false
				if curr >= prev:
					crossed = tval > prev and tval <= curr
				else:
					crossed = tval > prev or tval <= curr
				if crossed:
					fr.pulse()


func _update_ship_field_tint() -> void:
	## Combine tints from all active field devices and apply to ship renderer modulate.
	## Mirrors DeviceController.get_ship_tint() logic.
	var combined := Color(1.0, 1.0, 1.0, 1.0)
	for entry in _device_previews:
		var device: DeviceData = entry["device"]
		var slot_key: String = entry["slot_key"]
		var fr: FieldRenderer = entry.get("field_renderer") as FieldRenderer
		if not fr or not _slot_active.get(slot_key, false):
			continue
		if device.visual_mode != "field" or device.field_style_id == "":
			continue
		var style: FieldStyle = FieldStyleManager.load_by_id(device.field_style_id)
		if not style:
			continue
		# Read pulse intensity from the field renderer's shader
		var pulse_val: float = 0.0
		if fr._material:
			pulse_val = float(fr._material.get_shader_parameter("pulse_intensity"))
		var active_hdr: float = style.ship_active_hdr
		var pulse_hdr: float = style.ship_pulse_hdr
		var bright: float = 1.0 + active_hdr + pulse_val * pulse_hdr
		var field_col: Color = style.color
		var tint_strength: float = style.ship_tint_strength
		var tint_scaled: float = tint_strength * (style.glow_intensity / 1.5)
		var r: float = lerpf(bright, field_col.r * bright * 1.5, tint_scaled)
		var g: float = lerpf(bright, field_col.g * bright * 1.5, tint_scaled)
		var b: float = lerpf(bright, field_col.b * bright * 1.5, tint_scaled)
		# Multiply into combined tint
		combined.r *= r
		combined.g *= g
		combined.b *= b
	_ship_renderer.modulate = combined


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
