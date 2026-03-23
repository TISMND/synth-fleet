extends MarginContainer
## Hangar Screen — ship thumbnail + stats on left, LOADOUT/FIRE GROUPS/AUDIO MIX tabs center.

var _ship_renderer: ShipRenderer
var _ship_name_label: Label
var _center_vbox: VBoxContainer
var _weapon_section: VBoxContainer
var _core_section: VBoxContainer
var _field_section: VBoxContainer
var _particle_section: VBoxContainer
var _title: Label
var _weapon_header: Label
var _core_header: Label
var _field_header: Label
var _particle_header: Label
var _change_ship_btn: Button
var _launch_btn: Button
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
var _slot_btns: Dictionary = {}  # slot_key -> Button (header)

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

# Mode toggle: "functional", "workshop", "controls", or "audio"
var _mode: String = "functional"
var _functional_btn: Button
var _workshop_btn: Button
var _audio_btn: Button
var _controls_btn: Button
var _functional_content: VBoxContainer
var _workshop_content: VBoxContainer
var _audio_content: VBoxContainer
var _controls_content: VBoxContainer
var _ws_slot_rows: Dictionary = {}  # slot_key -> {toggle_btn, name_btn, rate_labels}

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
var _audio_play_btn: Button
var _audio_reset_btn: Button
var _master_vol_bar: ProgressBar
var _master_vol_label: Label

# Fire groups tab state
var _controls_key_btns: Dictionary = {}  # slot_key -> Button (kept for keyboard input handler)
var _fg_active_index: int = -1
var _fg_slot_rows: Dictionary = {}  # slot_key -> {toggle_btn, name_lbl, rate_labels}
var _fg_tab_label_refs: Array = []  # Label refs for tab name updates
var _fg_total_labels: Dictionary = {}  # bar_type -> Label
var _fg_total_current: Dictionary = {}  # bar_type -> float (displayed value, animating)
var _fg_total_target: Dictionary = {}   # bar_type -> float (target value)


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
	for i in GameState.get_weapon_slot_count():
		_slot_active["weapon_" + str(i)] = true
	for i in GameState.get_core_slot_count():
		_slot_active["core_" + str(i)] = true
	for i in GameState.get_field_slot_count():
		_slot_active["field_" + str(i)] = true
	for i in GameState.get_particle_slot_count():
		_slot_active["particle_" + str(i)] = true


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
		[_weapon_header, "weapon_0"],
		[_core_header, "core_0"],
		[_field_header, "field_0"],
		[_particle_header, "particle_0"],
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
		var is_vert: bool = entry.get("vertical", false)
		ThemeManager.apply_led_bar(bar, color, ratio, seg, is_vert)
		HudBuilder.update_bar_bezel(entry, seg)

	# Buttons
	_darken_button(_play_btn)
	_darken_button(_mute_btn)
	_darken_button(_reset_btn)
	_darken_button(_change_ship_btn)
	_darken_button(_launch_btn)
	_darken_button(_back_btn)
	_darken_button(_functional_btn)
	_darken_button(_workshop_btn)
	_darken_button(_audio_btn)
	_darken_button(_controls_btn)

	# Slot buttons in all sections — re-apply base style then color-coding
	var section_prefixes: Array = [
		[_weapon_section, "weapon_"],
		[_core_section, "core_"],
		[_field_section, "field_"],
		[_particle_section, "particle_"],
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
						_darken_button(btn)
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
						_darken_button(sub as Button)

	# Audio content children
	if _audio_content:
		for child in _audio_content.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is Button:
						_darken_button(sub as Button)
			elif child is Button:
				_darken_button(child as Button)

	# Controls content children
	if _controls_content:
		for child in _controls_content.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is Button:
						_darken_button(sub as Button)
			elif child is Button:
				_darken_button(child as Button)




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
	var is_vert: bool = entry.get("vertical", false)
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		if str(spec["name"]) == bar_name:
			var color: Color = ThemeManager.resolve_bar_color(spec)
			var seg: int = int(_bar_segments.get(bar_name, -1))
			ThemeManager.apply_led_bar(bar, color, float(value) / maxf(float(max_val), 1.0), seg, is_vert)
			HudBuilder.update_bar_bezel(entry, seg)
			break


func _rebuild_buttons() -> void:
	# Clear all sections
	for section in [_weapon_section, _core_section, _field_section, _particle_section]:
		for child in section.get_children():
			child.queue_free()
	_slot_toggle_btns.clear()
	_slot_btns.clear()

	# Weapon slots
	for i in GameState.get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var item_name: String = "empty"
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				item_name = w.display_name if w.display_name != "" else w.id
			else:
				item_name = weapon_id
		var row: PanelContainer = _create_slot_row(slot_key, item_name)
		_weapon_section.add_child(row)

	# Core slots
	for i in GameState.get_core_slot_count():
		var slot_key: String = "core_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var item_name: String = "empty"
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var pc: PowerCoreData = _power_core_cache.get(device_id)
			if pc:
				item_name = pc.display_name if pc.display_name != "" else pc.id
			else:
				item_name = device_id
		var row: PanelContainer = _create_slot_row(slot_key, item_name)
		_core_section.add_child(row)

	# Field slots
	for i in GameState.get_field_slot_count():
		var slot_key: String = "field_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var item_name: String = "empty"
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var d: DeviceData = _device_cache.get(device_id)
			if d:
				item_name = d.display_name if d.display_name != "" else d.id
			else:
				item_name = device_id
		var row: PanelContainer = _create_slot_row(slot_key, item_name)
		_field_section.add_child(row)

	# Particle slots (coming soon)
	for i in GameState.get_particle_slot_count():
		var slot_key: String = "particle_" + str(i)
		var row: PanelContainer = _create_slot_row(slot_key, "COMING SOON", true)
		_particle_section.add_child(row)

	_rebuild_audio_content()
	if _workshop_content and _workshop_content.visible:
		_rebuild_workshop_content()
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
	if section_prefix == "weapon":
		_weapon_header = header_label
	elif section_prefix == "core":
		_core_header = header_label
	elif section_prefix == "field":
		_field_header = header_label
	elif section_prefix == "particle":
		_particle_header = header_label

	return panel


func _get_slot_type_color(slot_key: String) -> Color:
	if slot_key.begins_with("weapon_"):
		return ThemeManager.get_color("bar_shield")  # Cyan for weapons
	elif slot_key.begins_with("core_"):
		return ThemeManager.get_color("bar_electric")  # Yellow for cores
	elif slot_key.begins_with("field_"):
		return Color(0.2, 0.8, 1.0)  # Teal for fields
	elif slot_key.begins_with("particle_"):
		return Color(0.5, 0.5, 0.5)  # Grey for particles
	return ThemeManager.get_color("accent")


func _create_slot_row(slot_key: String, item_name: String, disabled: bool = false) -> PanelContainer:
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

	# Slot button (clickable) — shows equipped item info, opens picker
	var header := Button.new()
	header.text = item_name
	header.custom_minimum_size.y = 54
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_darken_button(header)
	# Apply slot type color tint to the button font
	var slot_color: Color = _get_slot_type_color(slot_key)
	header.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.7))
	header.add_theme_color_override("font_hover_color", Color(slot_color.r, slot_color.g, slot_color.b, 1.0))
	header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
	if disabled:
		header.disabled = true
	else:
		var bound_slot: String = slot_key
		header.pressed.connect(func() -> void: _toggle_slot_list(bound_slot))
	row.add_child(header)

	# Track header button for highlight
	_slot_btns[slot_key] = header

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
	for key in _slot_btns:
		var b: Button = _slot_btns[key]
		b.remove_theme_color_override("font_color")


func _get_slot_btn(slot_key: String) -> Button:
	if _slot_btns.has(slot_key):
		return _slot_btns[slot_key]
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


func _add_picker_item(item_id: String, label: String, description: String, slot_key: String, equipped_ids: Array[String], component_type: String, rates: Dictionary = {}) -> void:
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

	# Effect rates — boxed color badges (same style as fire groups)
	if not rates.is_empty():
		var rates_hbox := HBoxContainer.new()
		rates_hbox.add_theme_constant_override("separation", 4)
		vbox.add_child(rates_hbox)
		var rate_font_size: int = ThemeManager.get_font_size("font_size_body") - 5
		for bar_type in EffectRateCalculator.BAR_TYPES:
			if not rates.has(bar_type):
				continue
			var val: float = float(rates[bar_type])
			var bar_color: Color = EffectRateCalculator.get_bar_color(bar_type)
			var rate_box := PanelContainer.new()
			var rbs := StyleBoxFlat.new()
			rbs.bg_color = Color(bar_color.r * 0.15, bar_color.g * 0.15, bar_color.b * 0.15, 0.6)
			rbs.corner_radius_top_left = 3
			rbs.corner_radius_top_right = 3
			rbs.corner_radius_bottom_left = 3
			rbs.corner_radius_bottom_right = 3
			rbs.content_margin_left = 4
			rbs.content_margin_right = 4
			rbs.content_margin_top = 1
			rbs.content_margin_bottom = 1
			rbs.border_width_left = 1
			rbs.border_width_right = 1
			rbs.border_width_top = 1
			rbs.border_width_bottom = 1
			rbs.border_color = Color(bar_color.r, bar_color.g, bar_color.b, 0.3)
			rate_box.add_theme_stylebox_override("panel", rbs)
			var rl := Label.new()
			var rate_sign: String = "+" if val > 0 else ""
			rl.text = rate_sign + str(int(val))
			var text_alpha: float = 0.8 if val >= 0 else 0.6
			rl.add_theme_color_override("font_color", Color(bar_color.r, bar_color.g, bar_color.b, text_alpha))
			rl.add_theme_font_size_override("font_size", rate_font_size)
			if body_font:
				rl.add_theme_font_override("font", body_font)
			rate_box.add_child(rl)
			rates_hbox.add_child(rate_box)

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
	if slot_key.begins_with("weapon_"):
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

	if slot_key.begins_with("weapon_"):
		# Show player weapons only (skip enemy-flagged weapons)
		for wid in _weapon_cache:
			var w: WeaponData = _weapon_cache[wid]
			if w.is_enemy_weapon:
				continue
			var label: String = w.display_name if w.display_name != "" else w.id
			var rates: Dictionary = EffectRateCalculator.calc_weapon(w)
			_add_picker_item(wid, label, w.description, slot_key, equipped_ids, "weapon", rates)

	elif slot_key.begins_with("core_"):
		# Show all power cores
		for pcid in _power_core_cache:
			var pc: PowerCoreData = _power_core_cache[pcid]
			var label: String = pc.display_name if pc.display_name != "" else pc.id
			var rates: Dictionary = EffectRateCalculator.calc_power_core(pc)
			_add_picker_item(pcid, label, pc.description, slot_key, equipped_ids, "device", rates)

	elif slot_key.begins_with("field_"):
		# Show all field-mode devices
		for did in _device_cache:
			var d: DeviceData = _device_cache[did]
			if d.visual_mode != "field":
				continue
			var label: String = d.display_name if d.display_name != "" else d.id
			var rates: Dictionary = EffectRateCalculator.calc_device(d)
			_add_picker_item(did, label, d.description, slot_key, equipped_ids, "device", rates)

	elif slot_key.begins_with("particle_"):
		# Coming soon — show message, no items
		var lbl := Label.new()
		lbl.text = "COMING SOON"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		_right_panel_list.add_child(lbl)



func _select_item_typed(slot_key: String, item_id: String, _component_type: String) -> void:
	if slot_key.begins_with("weapon_"):
		GameState.set_slot_weapon(slot_key, item_id)
	else:
		GameState.set_slot_device(slot_key, item_id)
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

	# Sync weapon controllers
	var weapon_ctrl_idx: int = 0
	for i in GameState.get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id == "":
			continue
		if weapon_ctrl_idx < _preview_controllers.size():
			var controller: Node2D = _preview_controllers[weapon_ctrl_idx]
			if _slot_active.get(slot_key, false):
				controller.activate()
			else:
				controller.deactivate()
		weapon_ctrl_idx += 1

	# Sync core previews — mute/unmute loops
	for entry in _core_previews:
		var loop_id: String = entry["loop_id"]
		var slot_idx: String = loop_id.replace("core_", "")
		var slot_key: String = "core_" + slot_idx
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
	_workshop_content.visible = (_mode == "workshop")
	_audio_content.visible = (_mode == "audio")
	_controls_content.visible = (_mode == "controls")
	if _mode == "controls":
		_clear_right_panel()
		_expanded_slot = ""
		_unhighlight_all_slot_btns()
		_auto_select_first_fg()
		_rebuild_controls_content()
		_show_fire_groups_panel()
	elif _mode == "workshop":
		# Keep right panel available for picker (same as loadout)
		_expanded_slot = ""
		_unhighlight_all_slot_btns()
		_auto_select_first_fg()
		_rebuild_workshop_content()
	elif _mode != "functional":
		_clear_right_panel()
		_expanded_slot = ""
		_unhighlight_all_slot_btns()
	_update_mode_buttons()


func _auto_select_first_fg() -> void:
	if _fg_active_index < 0:
		var presets: Array = KeyBindingManager.get_combo_presets()
		if not presets.is_empty():
			_fg_active_index = 0
			var pattern: Dictionary = presets[0].get("pattern", {})
			for slot_key in _slot_active:
				_slot_active[slot_key] = pattern.get(slot_key, false)
			_sync_preview_active_states()


func _rebuild_workshop_content() -> void:
	for child in _workshop_content.get_children():
		child.queue_free()
	_ws_slot_rows.clear()

	var presets: Array = KeyBindingManager.get_combo_presets()
	var body_font: Font = ThemeManager.get_font("font_body")
	var accent: Color = ThemeManager.get_color("accent")

	# Fire group tab bar (no key labels)
	_build_fg_tab_bar(_workshop_content, presets, true)

	var has_group: bool = _fg_active_index >= 0 and _fg_active_index < presets.size()

	# Scroll container for slot rows
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_workshop_content.add_child(scroll)

	var slots_vbox := VBoxContainer.new()
	slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(slots_vbox)

	var all_slots: Array = _get_all_slot_keys()
	var active_totals: Dictionary = {}

	# Group slots by type for section headers
	var sections: Array = [
		{"label": "WEAPONS", "prefix": "weapon_", "type": "weapon"},
		{"label": "POWER CORES", "prefix": "core_", "type": "core"},
		{"label": "FIELD EMITTERS", "prefix": "field_", "type": "field"},
		{"label": "PARTICLE GENERATORS", "prefix": "particle_", "type": "particle"},
	]

	for section in sections:
		var section_prefix: String = section["prefix"]
		var section_slots: Array = []
		for sk in all_slots:
			if str(sk).begins_with(section_prefix):
				section_slots.append(sk)
		if section_slots.is_empty():
			continue

		var header: PanelContainer = _create_section_header_bar(section["label"], section["type"])
		slots_vbox.add_child(header)

		for slot_key in section_slots:
			var item_name: String = _get_slot_item_name(slot_key)
			var is_active: bool = _slot_active.get(slot_key, true)
			var slot_rates: Dictionary = _get_slot_rates(slot_key)

			if is_active:
				for bar_type in slot_rates:
					active_totals[str(bar_type)] = float(active_totals.get(str(bar_type), 0.0)) + float(slot_rates[bar_type])

			# Hybrid row: power toggle + clickable slot name + rate badges
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
			ps.content_margin_top = 4
			ps.content_margin_bottom = 4
			panel.add_theme_stylebox_override("panel", ps)

			var slot_vbox := VBoxContainer.new()
			slot_vbox.add_theme_constant_override("separation", 0)
			panel.add_child(slot_vbox)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			slot_vbox.add_child(row)

			# Power toggle
			var toggle_btn := Button.new()
			toggle_btn.text = "\u23fb"
			toggle_btn.custom_minimum_size = Vector2(36, 36)
			toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_apply_power_toggle_style(toggle_btn, is_active)
			if has_group:
				var bound_slot: String = slot_key
				toggle_btn.pressed.connect(func() -> void: _on_fg_slot_toggle(bound_slot))
			else:
				toggle_btn.disabled = true
			row.add_child(toggle_btn)

			# Slot name — styled button to open picker (matches loadout aesthetic)
			var name_btn := Button.new()
			name_btn.text = item_name
			name_btn.custom_minimum_size.y = 54
			name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_darken_button(name_btn)
			var slot_color: Color = _get_slot_type_color(slot_key)
			var name_alpha: float = 0.7 if is_active else 0.3
			name_btn.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, name_alpha))
			name_btn.add_theme_color_override("font_hover_color", Color(slot_color.r, slot_color.g, slot_color.b, 1.0))
			name_btn.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
			var bound_key: String = slot_key
			name_btn.pressed.connect(func() -> void: _toggle_slot_list(bound_key))
			row.add_child(name_btn)
			_slot_btns[slot_key] = name_btn

			# Key binding button — shows current bound key, click to rebind
			var current_binding: Dictionary = KeyBindingManager.get_binding(slot_key)
			var key_label_text: String = str(current_binding.get("label", "?"))
			var key_btn := Button.new()
			key_btn.text = key_label_text
			key_btn.custom_minimum_size = Vector2(40, 36)
			key_btn.tooltip_text = "Click to rebind key"
			_darken_button(key_btn)
			key_btn.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
			var capture_key: String = slot_key
			key_btn.pressed.connect(func() -> void: _start_key_capture(capture_key))
			row.add_child(key_btn)

			# Rate badges
			var rate_label_refs: Array = _build_rate_badges(slot_vbox, slot_rates, is_active)
			_ws_slot_rows[slot_key] = {"toggle_btn": toggle_btn, "name_btn": name_btn, "rate_labels": rate_label_refs}
			slots_vbox.add_child(panel)

		var section_spacer := Control.new()
		section_spacer.custom_minimum_size.y = 4
		slots_vbox.add_child(section_spacer)

	# Totals
	_build_fg_totals(active_totals, body_font, _workshop_content)


func _update_mode_buttons() -> void:
	var accent: Color = ThemeManager.get_color("accent")
	for btn in [_functional_btn, _workshop_btn, _audio_btn, _controls_btn]:
		btn.remove_theme_color_override("font_color")
	if _mode == "functional":
		_functional_btn.add_theme_color_override("font_color", accent)
	elif _mode == "workshop":
		_workshop_btn.add_theme_color_override("font_color", accent)
	elif _mode == "audio":
		_audio_btn.add_theme_color_override("font_color", accent)
	else:
		_controls_btn.add_theme_color_override("font_color", accent)
	_darken_button(_functional_btn)
	_darken_button(_workshop_btn)
	_darken_button(_audio_btn)
	_darken_button(_controls_btn)


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


# ── Fire Groups tab content ──────────────────────────────────────────────────

func _rebuild_controls_content() -> void:
	if not _controls_content:
		return
	for child in _controls_content.get_children():
		child.queue_free()
	_controls_key_btns.clear()
	_fg_slot_rows.clear()
	_fg_tab_label_refs.clear()

	var body_font: Font = ThemeManager.get_font("font_body")
	var button_font: Font = ThemeManager.get_font("font_button")
	var presets: Array = KeyBindingManager.get_combo_presets()
	var accent: Color = ThemeManager.get_color("accent")

	# ── TAB BAR ──
	_build_fg_tab_bar(_controls_content, presets, true)

	# ── EMPTY STATE ──
	var has_group: bool = _fg_active_index >= 0 and _fg_active_index < presets.size()
	if presets.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Create your first fire group with the + button above."
		empty_lbl.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
		empty_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if body_font:
			empty_lbl.add_theme_font_override("font", body_font)
		_controls_content.add_child(empty_lbl)
		return

	# ── SLOT ROWS ──
	var all_slots: Array = _get_all_slot_keys()
	var active_totals: Dictionary = {}
	var small_size: int = ThemeManager.get_font_size("font_size_body") - 4

	for slot_key in all_slots:
		var item_name: String = _get_slot_item_name(slot_key)
		var is_active: bool = _slot_active.get(slot_key, true)
		var slot_rates: Dictionary = _get_slot_rates(slot_key)

		if is_active:
			for bar_type in slot_rates:
				active_totals[str(bar_type)] = float(active_totals.get(str(bar_type), 0.0)) + float(slot_rates[bar_type])

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
		ps.content_margin_top = 4
		ps.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", ps)

		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 0)
		panel.add_child(slot_vbox)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slot_vbox.add_child(row)

		# Power toggle button (circular)
		var toggle_btn := Button.new()
		toggle_btn.text = "\u23fb"
		toggle_btn.custom_minimum_size = Vector2(40, 40)
		toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_apply_power_toggle_style(toggle_btn, is_active)
		if has_group:
			var bound_slot: String = slot_key
			toggle_btn.pressed.connect(func() -> void: _on_fg_slot_toggle(bound_slot))
		else:
			toggle_btn.disabled = true
		row.add_child(toggle_btn)

		# Slot name label
		var name_lbl := Label.new()
		name_lbl.text = item_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size.y = 40
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var slot_color: Color = _get_slot_type_color(slot_key)
		if is_active:
			name_lbl.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.9))
		else:
			name_lbl.add_theme_color_override("font_color", Color(slot_color.r, slot_color.g, slot_color.b, 0.35))
		name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		row.add_child(name_lbl)

		# Per-slot rates — tiny boxed labels
		var rate_label_refs: Array = _build_rate_badges(slot_vbox, slot_rates, is_active)

		_fg_slot_rows[slot_key] = {"toggle_btn": toggle_btn, "name_lbl": name_lbl, "rate_labels": rate_label_refs}
		_controls_content.add_child(panel)

	# ── TOTALS ──
	_build_fg_totals(active_totals, body_font, _controls_content)


func _build_fg_tab_bar(parent: VBoxContainer, presets: Array, show_key_labels: bool = true) -> void:
	var accent: Color = ThemeManager.get_color("accent")
	var body_font: Font = ThemeManager.get_font("font_body")
	var button_font: Font = ThemeManager.get_font("font_header")

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tab_bar)

	for i in presets.size():
		var preset: Dictionary = presets[i]
		var is_active_tab: bool = (i == _fg_active_index)

		var tab_panel := PanelContainer.new()
		var tps := StyleBoxFlat.new()
		if is_active_tab:
			tps.bg_color = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 0.8)
			tps.border_width_bottom = 2
			tps.border_color = accent
		else:
			tps.bg_color = Color(0.08, 0.08, 0.08, 0.7)
		tps.corner_radius_top_left = 4
		tps.corner_radius_top_right = 4
		tps.content_margin_left = 10
		tps.content_margin_right = 10
		tps.content_margin_top = 4
		tps.content_margin_bottom = 4
		tab_panel.add_theme_stylebox_override("panel", tps)

		var tab_vbox := VBoxContainer.new()
		tab_vbox.add_theme_constant_override("separation", 0)
		tab_panel.add_child(tab_vbox)

		var tab_name := Label.new()
		tab_name.text = "GROUP " + str(i + 1)
		tab_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_name.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body") - 2)
		tab_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9) if is_active_tab else ThemeManager.get_color("dimmed"))
		if body_font:
			tab_name.add_theme_font_override("font", body_font)
		tab_vbox.add_child(tab_name)
		_fg_tab_label_refs.append(tab_name)

		if show_key_labels:
			var tab_key := Label.new()
			tab_key.text = str(preset.get("key_label", "?"))
			tab_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tab_key.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
			tab_key.add_theme_color_override("font_color", accent if is_active_tab else ThemeManager.get_color("text"))
			if button_font:
				tab_key.add_theme_font_override("font", button_font)
			tab_vbox.add_child(tab_key)

		tab_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var bound_idx: int = i
		tab_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_select_fire_group(bound_idx)
		)
		tab_bar.add_child(tab_panel)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(44, 0)
	add_btn.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_darken_button(add_btn)
	add_btn.pressed.connect(_on_add_fire_group)
	tab_bar.add_child(add_btn)

	var tab_spacer := Control.new()
	tab_spacer.custom_minimum_size.y = 6
	parent.add_child(tab_spacer)


func _build_rate_badges(parent_vbox: VBoxContainer, slot_rates: Dictionary, is_active: bool) -> Array:
	var rate_label_refs: Array = []
	if slot_rates.is_empty():
		return rate_label_refs
	var body_font: Font = ThemeManager.get_font("font_body")
	var rates_hbox := HBoxContainer.new()
	rates_hbox.add_theme_constant_override("separation", 4)
	parent_vbox.add_child(rates_hbox)
	var indent := Control.new()
	indent.custom_minimum_size.x = 48
	rates_hbox.add_child(indent)
	var rate_font_size: int = ThemeManager.get_font_size("font_size_body") - 5
	for bar_type in EffectRateCalculator.BAR_TYPES:
		if not slot_rates.has(bar_type):
			continue
		var val: float = float(slot_rates[bar_type])
		var bar_color: Color = EffectRateCalculator.get_bar_color(bar_type)
		var alpha: float = 0.8 if is_active else 0.25
		var rate_box := PanelContainer.new()
		var rbs := StyleBoxFlat.new()
		rbs.bg_color = Color(bar_color.r * 0.15, bar_color.g * 0.15, bar_color.b * 0.15, alpha * 0.6)
		rbs.corner_radius_top_left = 3
		rbs.corner_radius_top_right = 3
		rbs.corner_radius_bottom_left = 3
		rbs.corner_radius_bottom_right = 3
		rbs.content_margin_left = 4
		rbs.content_margin_right = 4
		rbs.content_margin_top = 1
		rbs.content_margin_bottom = 1
		rbs.border_width_left = 1
		rbs.border_width_right = 1
		rbs.border_width_top = 1
		rbs.border_width_bottom = 1
		rbs.border_color = Color(bar_color.r, bar_color.g, bar_color.b, alpha * 0.3)
		rate_box.add_theme_stylebox_override("panel", rbs)
		var rl := Label.new()
		var rate_sign: String = "+" if val > 0 else ""
		rl.text = rate_sign + str(int(val))
		rl.add_theme_color_override("font_color", Color(bar_color.r, bar_color.g, bar_color.b, alpha))
		rl.add_theme_font_size_override("font_size", rate_font_size)
		if body_font:
			rl.add_theme_font_override("font", body_font)
		rate_box.add_child(rl)
		rates_hbox.add_child(rate_box)
		rate_label_refs.append(rl)
	return rate_label_refs


func _build_fg_totals(active_totals: Dictionary, body_font: Font, parent: VBoxContainer = null) -> void:
	if not parent:
		parent = _controls_content
	var totals_spacer := Control.new()
	totals_spacer.custom_minimum_size.y = 10
	parent.add_child(totals_spacer)

	var totals_panel := PanelContainer.new()
	totals_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tps := StyleBoxFlat.new()
	tps.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	tps.corner_radius_top_left = 4
	tps.corner_radius_top_right = 4
	tps.corner_radius_bottom_left = 4
	tps.corner_radius_bottom_right = 4
	tps.content_margin_left = 12
	tps.content_margin_right = 12
	tps.content_margin_top = 8
	tps.content_margin_bottom = 8
	totals_panel.add_theme_stylebox_override("panel", tps)

	var totals_vbox := VBoxContainer.new()
	totals_vbox.add_theme_constant_override("separation", 4)
	totals_panel.add_child(totals_vbox)

	var totals_header := Label.new()
	totals_header.text = "EFFECT TOTALS (active components)"
	totals_header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	totals_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	if body_font:
		totals_header.add_theme_font_override("font", body_font)
	totals_vbox.add_child(totals_header)

	var abbrev: Dictionary = {"shield": "SHIELD", "hull": "HULL", "thermal": "THERMAL", "electric": "ELECTRIC"}
	var section_size: int = ThemeManager.get_font_size("font_size_section")
	_fg_total_labels.clear()
	for bar_type in EffectRateCalculator.BAR_TYPES:
		var target_val: float = float(active_totals.get(bar_type, 0.0))
		_fg_total_target[bar_type] = target_val
		# Initialize current to target on first build, keep existing for animation
		if not _fg_total_current.has(bar_type):
			_fg_total_current[bar_type] = target_val
		var display_val: float = float(_fg_total_current[bar_type])
		var total_row := HBoxContainer.new()
		total_row.add_theme_constant_override("separation", 8)
		totals_vbox.add_child(total_row)
		var bar_color: Color = EffectRateCalculator.get_bar_color(bar_type)
		var type_lbl := Label.new()
		type_lbl.text = str(abbrev.get(bar_type, bar_type.to_upper()))
		type_lbl.custom_minimum_size.x = 80
		type_lbl.add_theme_color_override("font_color", Color(bar_color.r, bar_color.g, bar_color.b, 0.6))
		type_lbl.add_theme_font_size_override("font_size", section_size)
		if body_font:
			type_lbl.add_theme_font_override("font", body_font)
		total_row.add_child(type_lbl)
		var val_lbl := Label.new()
		val_lbl.add_theme_color_override("font_color", bar_color)
		val_lbl.add_theme_font_size_override("font_size", section_size + 2)
		if body_font:
			val_lbl.add_theme_font_override("font", body_font)
		_fg_total_format_label(val_lbl, display_val)
		total_row.add_child(val_lbl)
		_fg_total_labels[bar_type] = val_lbl

	parent.add_child(totals_panel)


func _fg_total_format_label(lbl: Label, val: float) -> void:
	if is_zero_approx(val):
		lbl.text = "\u2014"
	else:
		var sign: String = "+" if val > 0 else ""
		lbl.text = sign + str(int(val)) + " seg/min"


func _animate_fg_totals(delta: float) -> void:
	if _fg_total_labels.is_empty():
		return
	var speed: float = 120.0  # segments per second counting speed
	for bar_type in _fg_total_target:
		var target: float = float(_fg_total_target[bar_type])
		var current: float = float(_fg_total_current.get(bar_type, target))
		if is_equal_approx(current, target):
			continue
		# Move current toward target
		var diff: float = target - current
		var step: float = speed * delta
		if absf(diff) <= step:
			current = target
		elif diff > 0:
			current += step
		else:
			current -= step
		_fg_total_current[bar_type] = current
		# Update label
		if _fg_total_labels.has(bar_type):
			var lbl: Label = _fg_total_labels[bar_type]
			if is_instance_valid(lbl):
				_fg_total_format_label(lbl, current)


func _apply_power_toggle_style(btn: Button, is_on: bool) -> void:
	# Desaturated pink/purple for ON, dark grey for OFF
	var on_color := Color(0.65, 0.4, 0.7)       # muted lavender
	var on_border := Color(0.75, 0.5, 0.85)      # slightly brighter border
	var on_bg := Color(0.25, 0.12, 0.3, 0.9)     # dark purple fill
	var on_bg_hover := Color(0.32, 0.18, 0.38, 0.9)
	var r: int = 20  # half of 40px → circular
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = r
		sb.corner_radius_top_right = r
		sb.corner_radius_bottom_left = r
		sb.corner_radius_bottom_right = r
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		if is_on:
			sb.bg_color = on_bg_hover if state == "hover" else on_bg
			sb.border_color = on_border
			sb.shadow_color = Color(0.4, 0.15, 0.5, 0.4)
			sb.shadow_size = 5
		else:
			sb.bg_color = Color(0.06, 0.06, 0.06, 0.9) if state != "hover" else Color(0.12, 0.12, 0.12, 0.9)
			sb.border_color = Color(0.25, 0.25, 0.25)
			sb.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
			sb.shadow_size = 2
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", on_color if is_on else Color(0.3, 0.3, 0.3))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.55, 0.9) if is_on else Color(0.4, 0.4, 0.4))
	btn.add_theme_font_size_override("font_size", 18)


func _select_fire_group(index: int) -> void:
	var presets: Array = KeyBindingManager.get_combo_presets()
	if index < 0 or index >= presets.size():
		return
	_fg_active_index = index
	var pattern: Dictionary = presets[index].get("pattern", {})
	for slot_key in _slot_active:
		_slot_active[slot_key] = pattern.get(slot_key, false)
	if _mode == "workshop":
		_rebuild_workshop_content()
	else:
		_rebuild_controls_content()
		_show_fire_groups_panel()
	_sync_preview_active_states()


func _on_fg_slot_toggle(slot_key: String) -> void:
	_slot_active[slot_key] = not _slot_active.get(slot_key, false)
	# Auto-save to current fire group
	if _fg_active_index >= 0:
		var pattern: Dictionary = {}
		for sk in _slot_active:
			pattern[sk] = _slot_active[sk]
		KeyBindingManager.update_combo_preset_pattern(_fg_active_index, pattern)
	# Rebuild UI (totals need recalculating)
	if _mode == "workshop":
		_rebuild_workshop_content()
	else:
		_rebuild_controls_content()
		_show_fire_groups_panel()
	_sync_preview_active_states()


func _update_fg_slot_visual(slot_key: String) -> void:
	if not _fg_slot_rows.has(slot_key):
		return
	var row_data: Dictionary = _fg_slot_rows[slot_key]
	var is_on: bool = _slot_active.get(slot_key, false)
	_apply_power_toggle_style(row_data["toggle_btn"], is_on)
	var slot_color: Color = _get_slot_type_color(slot_key)
	row_data["name_lbl"].add_theme_color_override("font_color",
		Color(slot_color.r, slot_color.g, slot_color.b, 0.9 if is_on else 0.35))
	for rl in row_data["rate_labels"]:
		var c: Color = rl.get_theme_color("font_color")
		rl.add_theme_color_override("font_color", Color(c.r, c.g, c.b, 0.7 if is_on else 0.25))


func _on_add_fire_group() -> void:
	_start_key_capture("combo_new")


func _finish_save_combo(physical_keycode: int, key_label: String) -> void:
	# New fire groups start with all slots ON
	var pattern: Dictionary = {}
	for slot_key in _slot_active:
		pattern[slot_key] = true
	var label: String = KeyBindingManager.generate_combo_label(pattern)
	KeyBindingManager.add_combo_preset(label, pattern, physical_keycode, key_label)
	# Select the newly created group
	_fg_active_index = KeyBindingManager.get_combo_presets().size() - 1
	for slot_key in _slot_active:
		_slot_active[slot_key] = true
	if _mode == "controls":
		_rebuild_controls_content()
		_show_fire_groups_panel()
	_sync_preview_active_states()


func _delete_fire_group(index: int) -> void:
	KeyBindingManager.remove_combo_preset(index)
	var presets: Array = KeyBindingManager.get_combo_presets()
	if presets.is_empty():
		_fg_active_index = -1
		for slot_key in _slot_active:
			_slot_active[slot_key] = true
	else:
		_fg_active_index = mini(index, presets.size() - 1)
		var pattern: Dictionary = presets[_fg_active_index].get("pattern", {})
		for slot_key in _slot_active:
			_slot_active[slot_key] = pattern.get(slot_key, false)
	_rebuild_controls_content()
	_show_fire_groups_panel()
	_sync_preview_active_states()


func _show_fire_groups_panel() -> void:
	## Right panel: fire group details (key binding + delete) for the active group.
	if not _right_panel:
		return
	_right_panel.visible = true
	_right_panel_header.text = "FIRE GROUP"
	_right_panel_header.visible = true
	_right_panel_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
	ThemeManager.apply_text_glow(_right_panel_header, "header")

	for child in _right_panel_list.get_children():
		child.queue_free()

	var body_font: Font = ThemeManager.get_font("font_body")
	var presets: Array = KeyBindingManager.get_combo_presets()

	if _fg_active_index < 0 or _fg_active_index >= presets.size():
		var hint := Label.new()
		hint.text = "Select or create a fire group."
		hint.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
		hint.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if body_font:
			hint.add_theme_font_override("font", body_font)
		_right_panel_list.add_child(hint)
		return

	var preset: Dictionary = presets[_fg_active_index]
	var bound_idx: int = _fg_active_index

	# Group name
	var name_lbl := Label.new()
	name_lbl.text = str(preset.get("label", "GROUP"))
	name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	name_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 2)
	if body_font:
		name_lbl.add_theme_font_override("font", body_font)
	_right_panel_list.add_child(name_lbl)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 12
	_right_panel_list.add_child(spacer1)

	# Key binding section
	var key_header := Label.new()
	key_header.text = "KEY BINDING"
	key_header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.5))
	key_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	if body_font:
		key_header.add_theme_font_override("font", body_font)
	_right_panel_list.add_child(key_header)

	var key_btn := Button.new()
	key_btn.text = "[" + str(preset.get("key_label", "?")) + "]"
	key_btn.custom_minimum_size = Vector2(70, 42)
	_darken_button(key_btn)
	key_btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	key_btn.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 4)
	key_btn.pressed.connect(func() -> void: _start_key_capture("combo_" + str(bound_idx)))
	_right_panel_list.add_child(key_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 20
	_right_panel_list.add_child(spacer2)

	# Delete button
	var del_btn := Button.new()
	del_btn.text = "DELETE FIRE GROUP"
	del_btn.custom_minimum_size.y = 38
	_darken_button(del_btn)
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	del_btn.pressed.connect(func() -> void: _delete_fire_group(bound_idx))
	_right_panel_list.add_child(del_btn)


# ── Audio mode content ───────────────────────────────────────────────────────

func _rebuild_audio_content() -> void:
	if not _audio_content:
		return
	for child in _audio_content.get_children():
		child.queue_free()
	_audio_sliders.clear()

	var body_font: Font = ThemeManager.get_font("font_body")

	# Master volume bar — larger, white, controls overall level
	var master_panel := PanelContainer.new()
	master_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mps := StyleBoxFlat.new()
	mps.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	mps.corner_radius_top_left = 4
	mps.corner_radius_top_right = 4
	mps.corner_radius_bottom_left = 4
	mps.corner_radius_bottom_right = 4
	mps.content_margin_left = 10
	mps.content_margin_right = 10
	mps.content_margin_top = 8
	mps.content_margin_bottom = 8
	master_panel.add_theme_stylebox_override("panel", mps)

	var master_vbox := VBoxContainer.new()
	master_vbox.add_theme_constant_override("separation", 6)
	master_panel.add_child(master_vbox)

	var master_lbl := Label.new()
	master_lbl.text = "MIX LEVEL"
	master_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	master_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section") + 4)
	if body_font:
		master_lbl.add_theme_font_override("font", body_font)
	master_vbox.add_child(master_lbl)

	var master_row := HBoxContainer.new()
	master_row.add_theme_constant_override("separation", 8)
	master_vbox.add_child(master_row)

	var master_stored: float = KeyBindingManager.get_slot_volume("mix_level")
	_master_vol_bar = ProgressBar.new()
	_master_vol_bar.min_value = -80.0
	_master_vol_bar.max_value = 6.0
	_master_vol_bar.value = master_stored
	_master_vol_bar.show_percentage = false
	_master_vol_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_vol_bar.custom_minimum_size = Vector2(0, 26)
	_master_vol_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	master_row.add_child(_master_vol_bar)

	_apply_fine_led(_master_vol_bar, Color(1.0, 1.0, 1.0), (master_stored - (-40.0)) / 46.0)

	# Click/drag handler for master bar
	var master_click := Control.new()
	master_click.set_anchors_preset(Control.PRESET_FULL_RECT)
	master_click.mouse_filter = Control.MOUSE_FILTER_STOP
	_master_vol_bar.add_child(master_click)
	var master_dragging: Array = [false]
	master_click.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					master_dragging[0] = true
					_on_master_vol_click(mb.position.x)
				else:
					master_dragging[0] = false
		elif event is InputEventMouseMotion and master_dragging[0]:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			_on_master_vol_click(mm.position.x)
	)

	_master_vol_label = Label.new()
	_master_vol_label.text = _format_db(master_stored)
	_master_vol_label.custom_minimum_size.x = 65
	_master_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_master_vol_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_master_vol_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body") + 2)
	if body_font:
		_master_vol_label.add_theme_font_override("font", body_font)
	master_row.add_child(_master_vol_label)

	_audio_content.add_child(master_panel)

	# Apply mix level offset to all loop volumes
	_apply_mix_level(master_stored)

	# Spacer between master and slots
	var master_spacer := Control.new()
	master_spacer.custom_minimum_size = Vector2(0, 4)
	_audio_content.add_child(master_spacer)

	# Per-slot volume slider rows — built dynamically from slot counts (skip particle)
	var audio_slots: Array = []
	for i in GameState.get_weapon_slot_count():
		audio_slots.append("weapon_" + str(i))
	for i in GameState.get_core_slot_count():
		audio_slots.append("core_" + str(i))
	for i in GameState.get_field_slot_count():
		audio_slots.append("field_" + str(i))

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
			vol_bar.min_value = -80.0
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

	# Bottom controls row: play/stop symbol + reset — centered below the mixer bars
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_audio_content.add_child(bottom_row)

	_audio_play_btn = Button.new()
	_audio_play_btn.text = "\u25b6" if not _is_playing else "\u25a0"
	_audio_play_btn.custom_minimum_size = Vector2(48, 38)
	_audio_play_btn.pressed.connect(_on_audio_play_toggle)
	bottom_row.add_child(_audio_play_btn)
	_darken_button(_audio_play_btn)

	_audio_reset_btn = Button.new()
	_audio_reset_btn.text = "RESET TO DEFAULT"
	_audio_reset_btn.custom_minimum_size = Vector2(0, 38)
	_audio_reset_btn.pressed.connect(_on_audio_reset_volumes)
	bottom_row.add_child(_audio_reset_btn)
	_darken_button(_audio_reset_btn)



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


func _apply_mix_level(mix_db: float) -> void:
	## Apply mix level offset to all slot loop volumes in LoopMixer.
	for slot_key in _audio_sliders:
		var slot_vol: float = KeyBindingManager.get_slot_volume(slot_key)
		var loop_id: String = _get_loop_id_for_slot(slot_key)
		if loop_id != "" and LoopMixer.has_loop(loop_id):
			LoopMixer.set_volume(loop_id, slot_vol + mix_db)


func _on_master_vol_click(click_x: float) -> void:
	if not _master_vol_bar:
		return
	var ratio: float = clampf(click_x / maxf(_master_vol_bar.size.x, 1.0), 0.0, 1.0)
	var db: float = lerpf(-40.0, 6.0, ratio)
	db = roundf(db * 2.0) / 2.0
	_master_vol_bar.value = db

	# Update LED shader fill
	var new_ratio: float = (db - (-40.0)) / 46.0
	var mat: ShaderMaterial = _master_vol_bar.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fill_ratio", new_ratio)

	# Update label
	if _master_vol_label:
		_master_vol_label.text = _format_db(db)

	# Apply offset to all loop volumes
	_apply_mix_level(db)

	# Persist
	KeyBindingManager.set_slot_volume("mix_level", db)


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

	# Apply to LoopMixer live (with mix level offset)
	var mix_offset: float = KeyBindingManager.get_slot_volume("mix_level")
	var loop_id: String = _get_loop_id_for_slot(slot_key)
	if loop_id != "" and LoopMixer.has_loop(loop_id):
		LoopMixer.set_volume(loop_id, volume_db + mix_offset)

	# Persist
	KeyBindingManager.set_slot_volume(slot_key, volume_db)


func _get_all_slot_keys() -> Array:
	## Returns all active slot keys in order (weapons, cores, fields). Skips particles.
	var slots: Array = []
	for i in GameState.get_weapon_slot_count():
		slots.append("weapon_" + str(i))
	for i in GameState.get_core_slot_count():
		slots.append("core_" + str(i))
	for i in GameState.get_field_slot_count():
		slots.append("field_" + str(i))
	return slots


func _get_slot_rates(slot_key: String) -> Dictionary:
	var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
	if slot_key.begins_with("weapon_"):
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				return EffectRateCalculator.calc_weapon(w)
	elif slot_key.begins_with("core_"):
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var pc: PowerCoreData = _power_core_cache.get(device_id)
			if pc:
				return EffectRateCalculator.calc_power_core(pc)
	elif slot_key.begins_with("field_"):
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var d: DeviceData = _device_cache.get(device_id)
			if d:
				return EffectRateCalculator.calc_device(d)
	return {}


func _get_slot_item_name(slot_key: String) -> String:
	var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
	if slot_key.begins_with("weapon_"):
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				return w.display_name if w.display_name != "" else w.id
			return weapon_id
	elif slot_key.begins_with("core_"):
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var pc: PowerCoreData = _power_core_cache.get(device_id)
			if pc:
				return pc.display_name if pc.display_name != "" else pc.id
			return device_id
	elif slot_key.begins_with("field_"):
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id != "":
			var d: DeviceData = _device_cache.get(device_id)
			if d:
				return d.display_name if d.display_name != "" else d.id
			return device_id
	elif slot_key.begins_with("particle_"):
		return "COMING SOON"
	return "empty"


func _get_loop_id_for_slot(slot_key: String) -> String:
	if slot_key.begins_with("weapon_"):
		# Match HardpointController's loop_id format
		var ctrl_idx: int = 0
		for i in GameState.get_weapon_slot_count():
			var sk: String = "weapon_" + str(i)
			var sd: Dictionary = GameState.slot_config.get(sk, {})
			var wid: String = str(sd.get("weapon_id", ""))
			if wid == "":
				continue
			if sk == slot_key:
				if ctrl_idx < _preview_controllers.size():
					return _preview_controllers[ctrl_idx]._loop_id
				return ""
			ctrl_idx += 1
		return ""
	elif slot_key.begins_with("core_"):
		var idx: String = slot_key.replace("core_", "")
		return "core_" + idx
	elif slot_key.begins_with("field_"):
		var idx: String = slot_key.replace("field_", "")
		return "dev_field_" + idx
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

	# Ship preview with vertical status bars flanking — mirrors game HUD layout.
	# Left side panel: Shield/Hull. Right side panel: Thermal/Electric.
	var preview_hbox := HBoxContainer.new()
	preview_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_hbox.add_theme_constant_override("separation", 0)
	left_vbox.add_child(preview_hbox)

	# Left side panel — Shield + Hull (vertical bars, same as game HUD)
	# Width = BAR_WIDTH(52) + bezel padding(6*2) + margin = 68
	var left_panel_data: Dictionary = HudBuilder.build_side_panel("hangar", ["SHIELD", "HULL"], {})
	var left_panel_root: Control = left_panel_data["root"]
	left_panel_root.custom_minimum_size.x = HudBuilder.BAR_WIDTH + 16
	preview_hbox.add_child(left_panel_root)

	# Ship viewport — center
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_hbox.add_child(_viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(400, 500)
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_sub_viewport)

	VFXFactory.add_bloom_to_viewport(_sub_viewport)

	var vp_bg := ColorRect.new()
	vp_bg.color = Color(0.0, 0.0, 0.0)
	vp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_viewport.add_child(vp_bg)

	# Scrolling star layers for parallax depth
	var vp_size: Vector2 = Vector2(_sub_viewport.size)
	var star_layer_far := _ScrollingStarField.new()
	star_layer_far.star_count = 60
	star_layer_far.star_color = Color(0.3, 0.3, 0.5, 0.4)
	star_layer_far.scroll_speed = 8.0
	star_layer_far.star_seed = 1
	star_layer_far.star_size_min = 0.5
	star_layer_far.star_size_max = 1.2
	star_layer_far.field_size = vp_size
	star_layer_far.set_anchors_preset(Control.PRESET_FULL_RECT)
	star_layer_far.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_viewport.add_child(star_layer_far)

	var star_layer_near := _ScrollingStarField.new()
	star_layer_near.star_count = 30
	star_layer_near.star_color = Color(0.6, 0.6, 0.9, 0.7)
	star_layer_near.scroll_speed = 20.0
	star_layer_near.star_seed = 2
	star_layer_near.star_size_min = 1.0
	star_layer_near.star_size_max = 2.5
	star_layer_near.field_size = vp_size
	star_layer_near.set_anchors_preset(Control.PRESET_FULL_RECT)
	star_layer_near.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_viewport.add_child(star_layer_near)

	_ship_renderer = ShipRenderer.new()
	_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	_ship_renderer.z_index = 1
	_sub_viewport.add_child(_ship_renderer)

	_preview_node = Node2D.new()
	_sub_viewport.add_child(_preview_node)

	_proj_container = Node2D.new()
	_sub_viewport.add_child(_proj_container)

	# Right side panel — Thermal + Electric (vertical bars, same as game HUD)
	var right_panel_data: Dictionary = HudBuilder.build_side_panel("hangar", ["THERMAL", "ELECTRIC"], {})
	var right_panel_root: Control = right_panel_data["root"]
	right_panel_root.custom_minimum_size.x = HudBuilder.BAR_WIDTH + 16
	preview_hbox.add_child(right_panel_root)

	# Merge bars from both panels into _bars dict for animation
	var left_bars: Dictionary = left_panel_data["bars"]
	var right_bars: Dictionary = right_panel_data["bars"]
	for bar_name in left_bars:
		var entry: Dictionary = left_bars[bar_name]
		_bars[bar_name] = {"bar": entry["bar"], "label": entry["label"], "vertical": true}
		_bar_gain_waves[bar_name] = {"active": false, "position": -1.0}
		_bar_drain_waves[bar_name] = {"active": false, "position": -1.0}
	for bar_name in right_bars:
		var entry: Dictionary = right_bars[bar_name]
		_bars[bar_name] = {"bar": entry["bar"], "label": entry["label"], "vertical": true}
		_bar_gain_waves[bar_name] = {"active": false, "position": -1.0}
		_bar_drain_waves[bar_name] = {"active": false, "position": -1.0}

	# Simulator controls — overlaid inside the viewport container, top-center
	var sim_vbox := VBoxContainer.new()
	sim_vbox.add_theme_constant_override("separation", 2)
	sim_vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sim_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sim_vbox.offset_top = 4
	sim_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.add_child(sim_vbox)

	var sim_header := Label.new()
	sim_header.text = "SIMULATOR"
	sim_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sim_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body") - 2)
	sim_header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.5))
	sim_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim_vbox.add_child(sim_header)

	var controls_hbox := HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 10)
	controls_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim_vbox.add_child(controls_hbox)

	_play_btn = Button.new()
	_play_btn.text = "RUN"
	_play_btn.custom_minimum_size = Vector2(70, 30)
	_play_btn.pressed.connect(_on_play_toggle)
	controls_hbox.add_child(_play_btn)

	_mute_btn = Button.new()
	_mute_btn.text = "MUTE"
	_mute_btn.custom_minimum_size = Vector2(70, 30)
	_mute_btn.pressed.connect(_on_mute_toggle)
	controls_hbox.add_child(_mute_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "RESET"
	_reset_btn.custom_minimum_size = Vector2(70, 30)
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

	_workshop_btn = Button.new()
	_workshop_btn.text = "WORKSHOP"
	_workshop_btn.custom_minimum_size = Vector2(110, 36)
	_workshop_btn.pressed.connect(func() -> void: _on_mode_toggle("workshop"))
	mode_hbox.add_child(_workshop_btn)

	# Fire Groups tab hidden — functionality merged into Workshop
	_controls_btn = Button.new()
	_controls_btn.text = "FIRE GROUPS"
	_controls_btn.visible = false

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

	# Weapons section
	var weapon_header_bar: PanelContainer = _create_section_header_bar("WEAPONS", "weapon")
	_functional_content.add_child(weapon_header_bar)

	_weapon_section = VBoxContainer.new()
	_weapon_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_weapon_section)

	# Spacer between sections
	var spacer_1 := Control.new()
	spacer_1.custom_minimum_size.y = 8
	_functional_content.add_child(spacer_1)

	# Power Cores section
	var core_header_bar: PanelContainer = _create_section_header_bar("POWER CORES", "core")
	_functional_content.add_child(core_header_bar)

	_core_section = VBoxContainer.new()
	_core_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_core_section)

	var spacer_2 := Control.new()
	spacer_2.custom_minimum_size.y = 8
	_functional_content.add_child(spacer_2)

	# Field Emitters section
	var field_header_bar: PanelContainer = _create_section_header_bar("FIELD EMITTERS", "field")
	_functional_content.add_child(field_header_bar)

	_field_section = VBoxContainer.new()
	_field_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_field_section)

	var spacer_3 := Control.new()
	spacer_3.custom_minimum_size.y = 8
	_functional_content.add_child(spacer_3)

	# Particle Generators section
	var particle_header_bar: PanelContainer = _create_section_header_bar("PARTICLE GENERATORS", "particle")
	_functional_content.add_child(particle_header_bar)

	_particle_section = VBoxContainer.new()
	_particle_section.add_theme_constant_override("separation", 6)
	_functional_content.add_child(_particle_section)

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

	# WORKSHOP content (hidden by default)
	_workshop_content = VBoxContainer.new()
	_workshop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workshop_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workshop_content.add_theme_constant_override("separation", 4)
	_workshop_content.visible = false
	_center_vbox.add_child(_workshop_content)

	# Bottom buttons (always visible, below all content areas)
	var bottom_btns := HBoxContainer.new()
	bottom_btns.add_theme_constant_override("separation", 10)
	_center_vbox.add_child(bottom_btns)

	_change_ship_btn = Button.new()
	_change_ship_btn.text = "CHANGE SHIP"
	_change_ship_btn.custom_minimum_size.y = 40
	_change_ship_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_change_ship_btn.pressed.connect(_on_change_ship)
	bottom_btns.add_child(_change_ship_btn)

	_launch_btn = Button.new()
	_launch_btn.text = "LAUNCH"
	_launch_btn.custom_minimum_size.y = 40
	_launch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launch_btn.pressed.connect(_on_launch)
	bottom_btns.add_child(_launch_btn)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.custom_minimum_size.y = 40
	_back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_btn.pressed.connect(_on_back)
	bottom_btns.add_child(_back_btn)

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
		_play_btn.text = "RUN"
	else:
		LoopMixer.start_all()
		# Only activate controllers for slots that are toggled ON
		_is_playing = true
		_sync_preview_active_states()
		_play_btn.text = "STOP"
	_sync_audio_play_btn()


func _on_audio_play_toggle() -> void:
	## Play/stop from the audio mix tab — same as main play toggle.
	_on_play_toggle()


func _on_audio_reset_volumes() -> void:
	## Reset all slot volumes and master to 0.0 dB (default).
	# Reset master
	if _master_vol_bar:
		_master_vol_bar.value = 0.0
		var mat: ShaderMaterial = _master_vol_bar.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("fill_ratio", (0.0 - (-40.0)) / 46.0)
	if _master_vol_label:
		_master_vol_label.text = _format_db(0.0)
	_apply_mix_level(0.0)
	KeyBindingManager.set_slot_volume("mix_level", 0.0)

	# Reset per-slot
	for slot_key in _audio_sliders:
		KeyBindingManager.set_slot_volume(slot_key, 0.0)
		# Update the LoopMixer live volume
		var loop_id: String = _get_loop_id_for_slot(slot_key)
		if loop_id != "" and LoopMixer.has_loop(loop_id):
			LoopMixer.set_volume(loop_id, 0.0)
		# Update the UI bar and label
		var entry: Dictionary = _audio_sliders[slot_key]
		var bar: ProgressBar = entry["bar"]
		bar.value = 0.0
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("fill_ratio", (0.0 - (-40.0)) / 46.0)
		var lbl: Label = entry["label"]
		lbl.text = _format_db(0.0)


func _sync_audio_play_btn() -> void:
	if _audio_play_btn and is_instance_valid(_audio_play_btn):
		_audio_play_btn.text = "\u25a0" if _is_playing else "\u25b6"


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


func _darken_button(btn: Button) -> void:
	## Apply theme style then darken the background for better visibility on this screen.
	ThemeManager.apply_button_style(btn)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBox = btn.get_theme_stylebox(state)
		if sb and sb is StyleBoxFlat:
			var dark: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			if state == "hover":
				dark.bg_color = Color(0.18, 0.18, 0.18, 0.9)
			elif state == "pressed":
				dark.bg_color = Color(0.12, 0.12, 0.12, 0.9)
			else:
				dark.bg_color = Color(0.08, 0.08, 0.08, 0.9)
			btn.add_theme_stylebox_override(state, dark)


func _on_launch() -> void:
	_cleanup_preview()
	GameState.current_level_id = "level_1"
	GameState.return_scene = "res://scenes/ui/hangar_screen.tscn"
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back() -> void:
	_cleanup_preview()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


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

	# Create new controllers for each equipped weapon slot
	for i in GameState.get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
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

	# Register power core loops for each equipped core slot
	for i in GameState.get_core_slot_count():
		var slot_key: String = "core_" + str(i)
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

	# Register device loops for field emitter slots
	for i in GameState.get_field_slot_count():
		var slot_key: String = "field_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		var device: DeviceData = _device_cache.get(device_id)
		if not device or device.loop_file_path == "":
			continue
		var loop_id: String = "dev_field_" + str(i)
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
			# z_index 1 (FieldRenderer default) — renders above ship, above background
			field_renderer.set_pulse_timing(device.pulse_total_duration, device.pulse_fade_up, device.pulse_fade_out)
			# Always start hidden — slot must be toggled on + PLAY to see fields
			field_renderer.set_opacity(0.0)

		_device_previews.append({"device": device, "loop_id": loop_id, "slot_key": slot_key, "prev_pos": -1.0, "field_renderer": field_renderer})

	# Apply stored volumes for weapon preview loops
	var weapon_ctrl_idx: int = 0
	for i2 in GameState.get_weapon_slot_count():
		var sk: String = "weapon_" + str(i2)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		var wid: String = str(sd.get("weapon_id", ""))
		if wid == "":
			continue
		if weapon_ctrl_idx < _preview_controllers.size():
			var ctrl_loop_id: String = _preview_controllers[weapon_ctrl_idx]._loop_id
			var weapon_vol: float = KeyBindingManager.get_slot_volume(sk)
			if ctrl_loop_id != "" and weapon_vol != 0.0:
				LoopMixer.set_volume(ctrl_loop_id, weapon_vol)
		weapon_ctrl_idx += 1

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
		bar.value = clampf(bar.value + delta, 0.0, bar.max_value)
		# Trigger rolling wave based on intended delta (not clamped result)
		# Only reset position if wave isn't already rolling (passive effects fire every frame)
		if delta > 0.0:
			if not bool(_bar_gain_waves[bar_name].get("active", false)):
				_bar_gain_waves[bar_name]["position"] = 0.0
			_bar_gain_waves[bar_name]["active"] = true
		elif delta < 0.0:
			if not bool(_bar_drain_waves[bar_name].get("active", false)):
				_bar_drain_waves[bar_name]["position"] = 1.0
			_bar_drain_waves[bar_name]["active"] = true
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
	_animate_fg_totals(_delta)
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
		var slot_key: String = "core_" + slot_idx
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
			if _mode == "controls":
				_rebuild_controls_content()
				_show_fire_groups_panel()
		else:
			# Rebinding a slot key
			KeyBindingManager.set_slot_key(_capturing_for, pkc, label)
			_end_key_capture()
			# Rebuild workshop to show updated key label
			if _mode == "workshop":
				_rebuild_workshop_content()
			elif _mode == "controls":
				_rebuild_controls_content()
				_show_fire_groups_panel()
		return

	# Slot key toggling on controls tab — routes through fire group auto-save
	if _mode == "controls" and _fg_active_index >= 0 and event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event: InputEventKey = event as InputEventKey
		var pkc: int = key_event.physical_keycode as int
		var toggled_slot: String = KeyBindingManager.get_slot_for_keycode_filtered(pkc, _slot_active)
		if toggled_slot != "":
			_on_fg_slot_toggle(toggled_slot)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") and not _is_capturing:
		_on_back()


class _ScrollingStarField extends Control:
	var star_count: int = 50
	var star_color: Color = Color(0.5, 0.5, 0.8, 0.6)
	var star_seed: int = 1
	var scroll_speed: float = 20.0
	var star_size_min: float = 0.8
	var star_size_max: float = 2.0
	var field_size: Vector2 = Vector2(400, 500)
	var _positions: PackedVector2Array = PackedVector2Array()
	var _sizes: PackedFloat32Array = PackedFloat32Array()
	var _offset: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = star_seed
		for i in star_count:
			_positions.append(Vector2(rng.randf() * field_size.x, rng.randf() * field_size.y))
			_sizes.append(rng.randf_range(star_size_min, star_size_max))

	func _process(delta: float) -> void:
		var h: float = size.y if size.y > 0.0 else field_size.y
		_offset += scroll_speed * delta
		if _offset >= h:
			_offset -= h
		queue_redraw()

	func _draw() -> void:
		var h: float = size.y if size.y > 0.0 else field_size.y
		var w: float = size.x if size.x > 0.0 else field_size.x
		for i in _positions.size():
			var x: float = _positions[i].x / field_size.x * w
			var y: float = fmod(_positions[i].y / field_size.y * h + _offset, h)
			draw_circle(Vector2(x, y), _sizes[i], star_color)
