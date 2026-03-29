extends Control
## Options screen with tabbed layout: Sound, Gameplay, Controls, Video.
## Each category saves to its own file under user://settings/.

const AUDIO_SETTINGS_PATH := "user://settings/audio.json"
const GAMEPLAY_SETTINGS_PATH := "user://settings/gameplay.json"
const VIDEO_SETTINGS_PATH := "user://settings/video.json"

# Bus definitions: display name -> AudioServer bus name
const BUS_DEFS: Array[Array] = [
	["MASTER", "Master"],
	["PLAYER COMPONENTS", "Weapons"],
	["ENEMIES", "Enemies"],
	["ATMOSPHERE", "Atmosphere"],
	["SFX", "SFX"],
	["UI", "UI"],
]

const TAB_NAMES: Array[String] = ["SOUND", "GAMEPLAY", "CONTROLS", "VIDEO"]

var _vhs_overlay: ColorRect
var _bg_rect: TextureRect
var _title_label: Label
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _active_tab: int = 0

# Sound tab
var _sliders: Dictionary = {}  # bus_name -> HSlider
var _value_labels: Dictionary = {}  # bus_name -> Label

# Gameplay tab
var _mouse_nav_indicator_checkbox: CheckBox = null

# Video tab
var _vsync_btn: OptionButton = null
var _bloom_btn: OptionButton = null
var _glow_quality_btn: OptionButton = null
var _boss_quality_btn: OptionButton = null

# Controls tab
var _mouse_sens_slider: HSlider = null
var _mouse_sens_label: Label = null
var _controls_vbox: VBoxContainer = null  # Root of controls tab for rebuilding
var _is_capturing: bool = false
var _capturing_target: String = ""  # e.g. "action_keyboard:toggle_all_weapons", "slot:weapon_0", "firegroup:0"
var _capturing_mouse: bool = false  # true if capturing mouse button instead of key
var _capture_overlay: ColorRect = null


func _ready() -> void:
	_ensure_audio_buses()
	_build_ui()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_load_audio_settings()
	_load_gameplay_settings()
	_load_video_settings()
	_apply_theme()


func _ensure_audio_buses() -> void:
	for def in BUS_DEFS:
		var bus_name: String = def[1]
		if bus_name == "Master":
			continue
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			var new_idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(new_idx, bus_name)
			AudioServer.set_bus_send(new_idx, "Master")


func _build_ui() -> void:
	# Background image
	_bg_rect = TextureRect.new()
	_bg_rect.texture = load("res://assets/backgrounds/options_blur_dark.png")
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	# Content container centered on screen
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 400)
	margin.add_theme_constant_override("margin_right", 400)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Header row: back arrow + title
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	vbox.add_child(header_row)

	var back_btn := Button.new()
	back_btn.text = "\u2190  BACK"
	back_btn.custom_minimum_size = Vector2(120, 36)
	back_btn.pressed.connect(_on_back)
	header_row.add_child(back_btn)

	_title_label = Label.new()
	_title_label.text = "OPTIONS"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_row.add_child(_title_label)

	# Spacer to balance the back button
	var header_spacer := Control.new()
	header_spacer.custom_minimum_size.x = 120
	header_row.add_child(header_spacer)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_bar)

	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 36
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# Tab content area
	var content_area := Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)

	# Build each tab panel
	var sound_panel := _build_sound_tab()
	var gameplay_panel := _build_gameplay_tab()
	var controls_panel := _build_controls_tab()
	var video_panel := _build_video_tab()

	for panel in [sound_panel, gameplay_panel, controls_panel, video_panel]:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		content_area.add_child(panel)
		_tab_panels.append(panel)

	# Show first tab
	_select_tab(0)


# ── Tab switching ─────────────────────────────────────────────

func _on_tab_pressed(index: int) -> void:
	_select_tab(index)


func _select_tab(index: int) -> void:
	_active_tab = index
	for i in _tab_panels.size():
		_tab_panels[i].visible = (i == index)
	_style_tab_buttons()


# ── Sound tab ─────────────────────────────────────────────────

func _build_sound_tab() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# Volume sliders
	for def in BUS_DEFS:
		var display_name: String = def[0]
		var bus_name: String = def[1]
		_add_volume_row(vbox, display_name, bus_name)

	return vbox


func _add_volume_row(parent: VBoxContainer, display_name: String, bus_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label_panel := _make_dark_panel()
	label_panel.custom_minimum_size = Vector2(200, 28)
	label_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label_panel)
	var label := Label.new()
	label.text = display_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 8
	label.offset_right = -4
	label_panel.add_child(label)

	var slider_panel := _make_dark_panel()
	slider_panel.custom_minimum_size = Vector2(200, 28)
	slider_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(slider_panel)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(180, 22)
	slider.value_changed.connect(_on_slider_changed.bind(bus_name))
	slider_panel.add_child(slider)
	_sliders[bus_name] = slider

	var val_panel := _make_dark_panel()
	val_panel.custom_minimum_size = Vector2(60, 28)
	val_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(val_panel)
	var val_label := Label.new()
	val_label.text = "100%"
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	val_panel.add_child(val_label)
	_value_labels[bus_name] = val_label


func _on_slider_changed(value: float, bus_name: String) -> void:
	var linear: float = value / 100.0
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if linear <= 0.0:
			AudioServer.set_bus_volume_db(bus_idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
	if _value_labels.has(bus_name):
		var lbl: Label = _value_labels[bus_name]
		lbl.text = str(int(value)) + "%"
	_save_audio_settings()


func _on_persist_toggled(_pressed: bool) -> void:
	pass


# ── Gameplay tab ──────────────────────────────────────────────

func _build_gameplay_tab() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl := Label.new()
	lbl.text = "There is nothing to change.\nIt's perfect."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(lbl)

	return vbox


func _on_mouse_nav_indicator_toggled(pressed: bool) -> void:
	GameState.show_mouse_nav_indicator = pressed
	_save_gameplay_settings()


# ── Controls tab ──────────────────────────────────────────────

func _build_controls_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_controls_vbox = VBoxContainer.new()
	_controls_vbox.add_theme_constant_override("separation", 12)
	_controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_controls_vbox)
	_populate_controls_tab()
	return scroll


func _populate_controls_tab() -> void:
	# Clear existing children
	for child in _controls_vbox.get_children():
		child.queue_free()

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	_controls_vbox.add_child(spacer)

	# ── Mouse sensitivity ──
	_add_section_label(_controls_vbox, "MOUSE")

	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 8)
	_controls_vbox.add_child(sens_row)

	var sens_name_panel := _make_dark_panel()
	sens_name_panel.custom_minimum_size = Vector2(230, 30)
	sens_name_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sens_row.add_child(sens_name_panel)
	var sens_label := Label.new()
	sens_label.text = "SENSITIVITY"
	sens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sens_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	sens_label.offset_left = 8
	sens_label.offset_right = -4
	sens_name_panel.add_child(sens_label)

	var sens_slider_panel := _make_dark_panel()
	sens_slider_panel.custom_minimum_size = Vector2(180, 30)
	sens_slider_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sens_row.add_child(sens_slider_panel)
	_mouse_sens_slider = HSlider.new()
	_mouse_sens_slider.min_value = 0.25
	_mouse_sens_slider.max_value = 2.0
	_mouse_sens_slider.step = 0.05
	_mouse_sens_slider.value = GameState.mouse_sensitivity
	_mouse_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mouse_sens_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mouse_sens_slider.custom_minimum_size = Vector2(160, 22)
	_mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	sens_slider_panel.add_child(_mouse_sens_slider)

	var sens_val_panel := _make_dark_panel()
	sens_val_panel.custom_minimum_size = Vector2(60, 30)
	sens_val_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sens_row.add_child(sens_val_panel)
	_mouse_sens_label = Label.new()
	_mouse_sens_label.text = _format_sens(GameState.mouse_sensitivity)
	_mouse_sens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mouse_sens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mouse_sens_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	sens_val_panel.add_child(_mouse_sens_label)

	# ── Component slots ──
	_add_section_label(_controls_vbox, "COMPONENT SLOTS")

	var slot_types: Array = [
		["weapon_", GameState.get_weapon_slot_count(), "WEAPON"],
		["core_", GameState.get_core_slot_count(), "CORE"],
		["field_", GameState.get_field_slot_count(), "FIELD"],
	]
	for st in slot_types:
		var prefix: String = st[0]
		var count: int = st[1]
		var display: String = st[2]
		for i in count:
			var slot_key: String = prefix + str(i)
			var key_label: String = KeyBindingManager.get_key_label_for_slot(slot_key)
			var slot_mb: Dictionary = KeyBindingManager.get_mouse_binding(slot_key)
			var slot_ms_label: String = str(slot_mb.get("mouse_label", ""))
			_add_binding_row(_controls_vbox, display + " " + str(i + 1), key_label, slot_ms_label, "slot:" + slot_key, "slot_mouse:" + slot_key)

	# ── Actions ──
	_add_section_label(_controls_vbox, "ACTIONS")

	var action_defs: Array = [
		["Toggle All Weapons", "toggle_all_weapons"],
		["Toggle All Cores", "toggle_all_cores"],
		["Emergency Cool", "thermal_purge"],
		["Deactivate All", "hardpoints_off"],
	]
	for ad in action_defs:
		var display_name: String = ad[0]
		var action_name: String = ad[1]
		var ab: Dictionary = KeyBindingManager.get_action_binding(action_name)
		var kb_label: String = str(ab.get("keyboard_label", ""))
		var ms_label: String = str(ab.get("mouse_label", ""))
		_add_binding_row(_controls_vbox, display_name, kb_label, ms_label,
			"action_keyboard:" + action_name, "action_mouse:" + action_name)

	# ── Fire groups ──
	_add_section_label(_controls_vbox, "FIRE GROUPS")

	var presets: Array = KeyBindingManager.get_combo_presets()
	for i in presets.size():
		var preset: Dictionary = presets[i]
		var fg_label: String = "Group " + str(i + 1)
		var key_lbl: String = str(preset.get("key_label", "?"))
		var fg_key: String = "firegroup_" + str(i)
		var fg_mb: Dictionary = KeyBindingManager.get_mouse_binding(fg_key)
		var fg_ms_label: String = str(fg_mb.get("mouse_label", ""))
		_add_binding_row(_controls_vbox, fg_label, key_lbl, fg_ms_label, "firegroup:" + str(i), "firegroup_mouse:" + str(i))


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	parent.add_child(spacer)
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)


func _add_binding_row(parent: VBoxContainer, display_name: String, kb_label: String, ms_label: String, kb_target: String, ms_target: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Name label with dark backing — SHRINK so buttons aren't pushed off-screen
	var name_panel := _make_dark_panel()
	name_panel.custom_minimum_size = Vector2(230, 30)
	name_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(name_panel)
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_lbl.offset_left = 8
	name_lbl.offset_right = -4
	name_panel.add_child(name_lbl)

	# Keyboard binding button — styled like a dark panel
	if kb_target != "":
		var kb_btn := Button.new()
		kb_btn.text = kb_label if kb_label != "" else "\u2014"
		kb_btn.custom_minimum_size = Vector2(90, 30)
		kb_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		kb_btn.pressed.connect(_start_capture.bind(kb_target, false))
		_style_binding_button(kb_btn)
		row.add_child(kb_btn)

	# Mouse binding button — always show for actions, allow assignment
	if ms_target != "":
		var ms_btn := Button.new()
		ms_btn.text = ms_label if ms_label != "" else "\u2014"
		ms_btn.custom_minimum_size = Vector2(90, 30)
		ms_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ms_btn.pressed.connect(_start_capture.bind(ms_target, true))
		_style_binding_button(ms_btn)
		row.add_child(ms_btn)


func _style_binding_button(btn: Button) -> void:
	## Style a binding button to look like a dark panel label, not a bright outlined button.
	btn.set_meta("binding_btn", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	hover_sb.set_corner_radius_all(2)
	hover_sb.content_margin_left = 8
	hover_sb.content_margin_right = 8
	hover_sb.content_margin_top = 4
	hover_sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	btn.add_theme_stylebox_override("focus", sb)
	var text_color: Color = ThemeManager.get_color("accent")
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", text_color.lightened(0.3))
	var body_font: Font = ThemeManager.get_font("font_body")
	if body_font:
		btn.add_theme_font_override("font", body_font)
	btn.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))


func _make_dark_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _format_sens(value: float) -> String:
	return str(snapped(value, 0.05)) + "x"


func _on_mouse_sens_changed(value: float) -> void:
	GameState.mouse_sensitivity = value
	if _mouse_sens_label:
		_mouse_sens_label.text = _format_sens(value)
	_save_gameplay_settings()


# ── Key / Mouse Capture ──────────────────────────────────────

func _start_capture(target: String, is_mouse: bool) -> void:
	_capturing_target = target
	_capturing_mouse = is_mouse
	_is_capturing = true
	if not _capture_overlay:
		_capture_overlay = ColorRect.new()
		_capture_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
		_capture_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_capture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var cap_label := Label.new()
		cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap_label.set_anchors_preset(Control.PRESET_CENTER)
		cap_label.add_theme_font_size_override("font_size", 28)
		cap_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		var body_font: Font = ThemeManager.get_font("font_body")
		if body_font:
			cap_label.add_theme_font_override("font", body_font)
		cap_label.name = "CaptureLabel"
		_capture_overlay.add_child(cap_label)
	var lbl: Label = _capture_overlay.get_node("CaptureLabel") as Label
	if is_mouse:
		lbl.text = "CLICK A MOUSE BUTTON...\n(ESC to cancel)"
	else:
		lbl.text = "PRESS A KEY...\n(ESC to cancel)"
	_capture_overlay.visible = true
	if _capture_overlay.get_parent() != self:
		if _capture_overlay.get_parent():
			_capture_overlay.get_parent().remove_child(_capture_overlay)
		add_child(_capture_overlay)


func _end_capture() -> void:
	_is_capturing = false
	_capturing_target = ""
	_capturing_mouse = false
	if _capture_overlay:
		_capture_overlay.visible = false


func _apply_capture_key(physical_keycode: int, label: String) -> void:
	var target: String = _capturing_target
	_end_capture()

	if target.begins_with("slot:"):
		var slot_key: String = target.replace("slot:", "")
		KeyBindingManager.set_slot_key(slot_key, physical_keycode, label)
	elif target.begins_with("action_keyboard:"):
		var action_name: String = target.replace("action_keyboard:", "")
		KeyBindingManager.set_action_binding_keyboard(action_name, physical_keycode, label)
	elif target.begins_with("firegroup:"):
		var idx: int = int(target.replace("firegroup:", ""))
		KeyBindingManager.set_combo_preset_key(idx, physical_keycode, label)

	_populate_controls_tab()
	_apply_theme()


func _apply_capture_mouse(button_index: int) -> void:
	var target: String = _capturing_target
	_end_capture()

	var label: String = _mouse_button_label(button_index)

	if target.begins_with("action_mouse:"):
		var action_name: String = target.replace("action_mouse:", "")
		KeyBindingManager.set_action_binding_mouse(action_name, button_index, label)
	elif target.begins_with("slot_mouse:"):
		var slot_key: String = target.replace("slot_mouse:", "")
		KeyBindingManager.set_mouse_binding(slot_key, button_index, label)
	elif target.begins_with("firegroup_mouse:"):
		var fg_key: String = "firegroup_" + target.replace("firegroup_mouse:", "")
		KeyBindingManager.set_mouse_binding(fg_key, button_index, label)

	_populate_controls_tab()
	_apply_theme()


func _mouse_button_label(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "WheelUp"
		MOUSE_BUTTON_WHEEL_DOWN: return "WheelDn"
		4: return "Mouse4"
		5: return "Mouse5"
		_: return "Mouse" + str(button_index)


# ── Video tab ─────────────────────────────────────────────────

func _build_video_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# V-Sync
	_add_video_setting(vbox, "V-SYNC",
		"Syncs frame rate to your monitor. Prevents screen tearing but may add input lag.",
		func() -> OptionButton:
			_vsync_btn = OptionButton.new()
			_vsync_btn.add_item("On", 0)
			_vsync_btn.add_item("Off", 1)
			_vsync_btn.custom_minimum_size.x = 200
			_vsync_btn.item_selected.connect(_on_vsync_changed)
			return _vsync_btn)

	# Bloom
	_add_video_setting(vbox, "BLOOM",
		"Adds a glow effect around bright objects. Disable for better performance.",
		func() -> OptionButton:
			_bloom_btn = OptionButton.new()
			_bloom_btn.add_item("On", 0)
			_bloom_btn.add_item("Off", 1)
			_bloom_btn.custom_minimum_size.x = 200
			_bloom_btn.item_selected.connect(_on_bloom_changed)
			return _bloom_btn)

	# Glow Quality
	_add_video_setting(vbox, "GLOW QUALITY",
		"Controls how many blur passes are used for the glow effect. Lower = faster.",
		func() -> OptionButton:
			_glow_quality_btn = OptionButton.new()
			_glow_quality_btn.add_item("High", 0)
			_glow_quality_btn.add_item("Medium", 1)
			_glow_quality_btn.add_item("Low", 2)
			_glow_quality_btn.custom_minimum_size.x = 200
			_glow_quality_btn.item_selected.connect(_on_glow_quality_changed)
			return _glow_quality_btn)

	# Boss Animation Quality
	_add_video_setting(vbox, "BOSS ANIMATION",
		"How often boss visuals update. Low reduces detail but improves frame rate.",
		func() -> OptionButton:
			_boss_quality_btn = OptionButton.new()
			_boss_quality_btn.add_item("High", 0)
			_boss_quality_btn.add_item("Low", 1)
			_boss_quality_btn.custom_minimum_size.x = 200
			_boss_quality_btn.item_selected.connect(_on_boss_quality_changed)
			return _boss_quality_btn)

	return scroll


func _add_video_setting(parent: VBoxContainer, title: String, description: String, make_control: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	# Left side: title + description stacked tight
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var label := Label.new()
	label.text = title
	left.add_child(label)

	var desc := Label.new()
	desc.text = description
	desc.set_meta("video_desc", true)
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	var disabled_font: Font = ThemeManager.get_font("font_body")
	if disabled_font:
		desc.add_theme_font_override("font", disabled_font)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(desc)

	# Right side: dropdown
	var control: OptionButton = make_control.call() as OptionButton
	row.add_child(control)


func _on_vsync_changed(index: int) -> void:
	if index == 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_save_video_settings()


func _on_bloom_changed(index: int) -> void:
	var env: Environment = ThemeManager.get_environment()
	if env:
		env.glow_enabled = (index == 0)
	_save_video_settings()


func _on_glow_quality_changed(index: int) -> void:
	var env: Environment = ThemeManager.get_environment()
	if not env:
		return
	# High: levels 0,1,2  Medium: levels 0,1  Low: level 0 only
	var max_level: int = 2 - index  # 2, 1, or 0
	for i in 7:
		env.set_glow_level(i, i <= max_level)
	_save_video_settings()


func _on_boss_quality_changed(index: int) -> void:
	# High = render every 3 frames, Low = render every 6 frames
	var interval: int = 3 if index == 0 else 6
	var shared_renderer: Node = get_tree().root.get_node_or_null("EnemySharedRenderer")
	if shared_renderer and shared_renderer.has_method("set_boss_render_interval"):
		shared_renderer.set_boss_render_interval(interval)
	# Store for game scenes to read on load
	GameState.set_meta("boss_render_interval", interval)
	_save_video_settings()


func _save_video_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var data: Dictionary = {
		"vsync": _vsync_btn.selected,
		"bloom": _bloom_btn.selected,
		"glow_quality": _glow_quality_btn.selected,
		"boss_quality": _boss_quality_btn.selected,
	}
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(VIDEO_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_video_settings() -> void:
	# Defaults
	var vs: int = 0
	var bloom_idx: int = 0
	var glow_q: int = 0
	var boss_q: int = 0

	if FileAccess.file_exists(VIDEO_SETTINGS_PATH):
		var file: FileAccess = FileAccess.open(VIDEO_SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_str: String = file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(json_str) == OK:
				var data: Dictionary = json.data
				vs = int(data.get("vsync", 0))
				# Back-compat: old saves stored bloom as bool
				var bloom_val: Variant = data.get("bloom", 0)
				if bloom_val is bool:
					bloom_idx = 0 if bool(bloom_val) else 1
				else:
					bloom_idx = int(bloom_val)
				glow_q = int(data.get("glow_quality", 0))
				boss_q = int(data.get("boss_quality", 0))

	# Apply without triggering save
	_vsync_btn.selected = vs
	_bloom_btn.selected = bloom_idx
	_glow_quality_btn.selected = glow_q
	_boss_quality_btn.selected = boss_q

	# Apply settings
	_on_vsync_changed(vs)
	_on_bloom_changed(bloom_idx)
	_on_glow_quality_changed(glow_q)
	_on_boss_quality_changed(boss_q)


# ── Placeholder tabs ──────────────────────────────────────────

func _build_placeholder_tab(message: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	vbox.add_child(spacer)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(label)

	return vbox


# ── Navigation ────────────────────────────────────────────────

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if _is_capturing:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var key_event: InputEventKey = event as InputEventKey
			get_viewport().set_input_as_handled()
			if key_event.physical_keycode == KEY_ESCAPE:
				_end_capture()
				return
			var pkc: int = key_event.physical_keycode as int
			if _capturing_mouse:
				# Player pressed a keyboard key while we expected mouse — ignore
				return
			var label: String = OS.get_keycode_string(key_event.physical_keycode)
			if label == "":
				label = "KEY_" + str(pkc)
			_apply_capture_key(pkc, label)
			return
		elif event is InputEventMouseButton and event.is_pressed() and _capturing_mouse:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			get_viewport().set_input_as_handled()
			_apply_capture_mouse(mb.button_index)
			return
		# Consume all other input during capture
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_on_back()


# ── VHS overlay ───────────────────────────────────────────────

func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


# ── Theme ─────────────────────────────────────────────────────

func _on_theme_changed() -> void:
	_apply_theme()


func _apply_theme() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	# Title
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		_title_label.add_theme_font_override("font", header_font)
	_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	ThemeManager.apply_text_glow(_title_label, "header")

	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")
	var text_color: Color = ThemeManager.get_color("text")
	var accent_color: Color = ThemeManager.get_color("accent")

	# Tab buttons
	_style_tab_buttons()

	# Bus labels and value labels
	for bus_name in _sliders:
		if _value_labels.has(bus_name):
			var val_lbl: Label = _value_labels[bus_name]
			if body_font:
				val_lbl.add_theme_font_override("font", body_font)
			val_lbl.add_theme_font_size_override("font_size", body_size)
			val_lbl.add_theme_color_override("font_color", accent_color)

	# Checkboxes
	for cb in [_mouse_nav_indicator_checkbox]:
		if cb:
			if body_font:
				cb.add_theme_font_override("font", body_font)
			cb.add_theme_font_size_override("font_size", body_size)
			cb.add_theme_color_override("font_color", accent_color)

	# Style all labels in tab panels not already styled above
	var _styled_labels: Array[Label] = []
	for bus_name in _value_labels:
		_styled_labels.append(_value_labels[bus_name])
	for panel in _tab_panels:
		for child in _get_all_children(panel):
			if child is Label and not child in _styled_labels and not child.has_meta("video_desc"):
				if body_font:
					child.add_theme_font_override("font", body_font)
				child.add_theme_font_size_override("font_size", body_size)
				child.add_theme_color_override("font_color", text_color)
				ThemeManager.apply_text_glow(child, "body")

	_style_sliders(accent_color)

	# All buttons (skip binding buttons which have custom dark styling)
	for child in _get_all_children(self):
		if child is Button and not child in _tab_buttons and not child.has_meta("binding_btn"):
			ThemeManager.apply_button_style(child as Button)
			_darken_button(child as Button)


func _style_tab_buttons() -> void:
	var accent: Color = ThemeManager.get_color("accent")
	var panel_color: Color = ThemeManager.get_color("panel")
	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")

	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var is_active: bool = (i == _active_tab)

		var sb := StyleBoxFlat.new()
		if is_active:
			sb.bg_color = Color(0.06, 0.06, 0.06, 1.0)
			sb.border_color = accent
			sb.border_width_bottom = 2
		else:
			sb.bg_color = Color(0.04, 0.04, 0.04, 1.0)
			sb.border_color = Color(accent.r, accent.g, accent.b, 0.3)
			sb.border_width_bottom = 1
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(6)

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

		var font_color: Color = accent if is_active else Color(accent.r, accent.g, accent.b, 0.6)
		btn.add_theme_color_override("font_color", font_color)
		btn.add_theme_color_override("font_hover_color", font_color)
		btn.add_theme_color_override("font_pressed_color", accent)
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", body_size)


func _darken_button(btn: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBox = btn.get_theme_stylebox(state)
		if sb and sb is StyleBoxFlat:
			var dark: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			if state == "hover":
				dark.bg_color = Color(0.12, 0.12, 0.12, 1.0)
			elif state == "pressed":
				dark.bg_color = Color(0.08, 0.08, 0.08, 1.0)
			else:
				dark.bg_color = Color(0.04, 0.04, 0.04, 1.0)
			btn.add_theme_stylebox_override(state, dark)


func _style_sliders(accent: Color) -> void:
	var panel_color: Color = ThemeManager.get_color("panel")

	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(panel_color.r, panel_color.g, panel_color.b, 0.6)
	track_sb.set_corner_radius_all(2)
	track_sb.set_content_margin_all(0)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(accent.r, accent.g, accent.b, 0.4)
	fill_sb.set_corner_radius_all(2)
	fill_sb.set_content_margin_all(0)

	var all_sliders: Array[HSlider] = []
	for bus_name in _sliders:
		all_sliders.append(_sliders[bus_name])
	if _mouse_sens_slider:
		all_sliders.append(_mouse_sens_slider)

	for slider in all_sliders:
		slider.add_theme_stylebox_override("slider", track_sb.duplicate())
		slider.add_theme_stylebox_override("grabber_area", fill_sb.duplicate())
		slider.add_theme_stylebox_override("grabber_area_highlight", fill_sb.duplicate())
		slider.add_theme_icon_override("grabber", _make_grabber_texture(accent, 14))
		slider.add_theme_icon_override("grabber_highlight", _make_grabber_texture(accent.lightened(0.2), 16))
		slider.add_theme_icon_override("grabber_disabled", _make_grabber_texture(ThemeManager.get_color("disabled"), 14))


func _make_grabber_texture(color: Color, pixel_size: int) -> Texture2D:
	var img := Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	var center: float = float(pixel_size) / 2.0
	var radius: float = center - 1.0
	for y in pixel_size:
		for x in pixel_size:
			var dx: float = float(x) - center + 0.5
			var dy: float = float(y) - center + 0.5
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist <= radius:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result


# ── Settings persistence ──────────────────────────────────────

func _save_audio_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var data: Dictionary = {}
	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		data[bus_name] = slider.value
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_audio_settings() -> void:
	if not FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		for bus_name in _sliders:
			var default_val: float = 80.0 if bus_name == "Master" else 100.0
			var slider: HSlider = _sliders[bus_name]
			slider.value = default_val
			_on_slider_changed(default_val, bus_name)
		return
	var file: FileAccess = FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return
	var data: Dictionary = json.data
	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		var val: float = float(data.get(bus_name, 100.0))
		slider.value = val
		_on_slider_changed(val, bus_name)


func _save_gameplay_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var data: Dictionary = {
		"show_mouse_nav_indicator": GameState.show_mouse_nav_indicator,
		"mouse_sensitivity": GameState.mouse_sensitivity,
	}
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(GAMEPLAY_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_gameplay_settings() -> void:
	if not FileAccess.file_exists(GAMEPLAY_SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(GAMEPLAY_SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return
	var data: Dictionary = json.data
	GameState.show_mouse_nav_indicator = bool(data.get("show_mouse_nav_indicator", true))
	if _mouse_nav_indicator_checkbox:
		_mouse_nav_indicator_checkbox.button_pressed = GameState.show_mouse_nav_indicator
	GameState.mouse_sensitivity = clampf(float(data.get("mouse_sensitivity", 1.0)), 0.25, 2.0)
	if _mouse_sens_slider:
		_mouse_sens_slider.value = GameState.mouse_sensitivity
	if _mouse_sens_label:
		_mouse_sens_label.text = _format_sens(GameState.mouse_sensitivity)
