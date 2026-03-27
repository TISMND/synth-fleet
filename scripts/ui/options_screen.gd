extends Control
## Options screen with tabbed layout: Sound, Gameplay, Controls, Video.
## Each category saves to its own file under user://settings/.

const AUDIO_SETTINGS_PATH := "user://settings/audio.json"
const GAMEPLAY_SETTINGS_PATH := "user://settings/gameplay.json"

# Bus definitions: display name -> AudioServer bus name
const BUS_DEFS: Array[Array] = [
	["MASTER", "Master"],
	["WEAPONS", "Weapons"],
	["ENEMIES", "Enemies"],
	["ATMOSPHERE", "Atmosphere"],
	["SFX", "SFX"],
	["UI", "UI"],
]

const TAB_NAMES: Array[String] = ["SOUND", "GAMEPLAY", "CONTROLS", "VIDEO"]

var _vhs_overlay: ColorRect
var _bg_rect: ColorRect
var _title_label: Label
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _active_tab: int = 0

# Sound tab
var _sliders: Dictionary = {}  # bus_name -> HSlider
var _value_labels: Dictionary = {}  # bus_name -> Label
var _persist_checkbox: CheckBox = null

# Gameplay tab
var _mouse_nav_indicator_checkbox: CheckBox = null

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
	# Grid background
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var video_panel := _build_placeholder_tab("Video settings coming soon.")

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

	# Persist enemy audio
	var persist_spacer := Control.new()
	persist_spacer.custom_minimum_size.y = 8
	vbox.add_child(persist_spacer)

	_persist_checkbox = CheckBox.new()
	_persist_checkbox.text = "Keep enemy weapon loops after death"
	_persist_checkbox.button_pressed = AudioBusSetup.persist_enemy_audio
	_persist_checkbox.toggled.connect(_on_persist_toggled)
	vbox.add_child(_persist_checkbox)

	return vbox


func _add_volume_row(parent: VBoxContainer, display_name: String, bus_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label_panel := _make_dark_panel()
	label_panel.custom_minimum_size = Vector2(200, 28)
	row.add_child(label_panel)
	var label := Label.new()
	label.text = display_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 8
	label.offset_right = -4
	label_panel.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.custom_minimum_size = Vector2(200, 26)
	slider.value_changed.connect(_on_slider_changed.bind(bus_name))
	row.add_child(slider)
	_sliders[bus_name] = slider

	var val_label := Label.new()
	val_label.text = "100%"
	val_label.custom_minimum_size.x = 60
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val_label)
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


func _on_persist_toggled(pressed: bool) -> void:
	AudioBusSetup.persist_enemy_audio = pressed
	_save_audio_settings()


# ── Gameplay tab ──────────────────────────────────────────────

func _build_gameplay_tab() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	_mouse_nav_indicator_checkbox = CheckBox.new()
	_mouse_nav_indicator_checkbox.text = "Show mouse navigation indicator"
	_mouse_nav_indicator_checkbox.button_pressed = GameState.show_mouse_nav_indicator
	_mouse_nav_indicator_checkbox.toggled.connect(_on_mouse_nav_indicator_toggled)
	vbox.add_child(_mouse_nav_indicator_checkbox)

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
	sens_row.add_theme_constant_override("separation", 12)
	_controls_vbox.add_child(sens_row)

	var sens_label := Label.new()
	sens_label.text = "SENSITIVITY"
	sens_label.custom_minimum_size.x = 180
	sens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sens_row.add_child(sens_label)

	_mouse_sens_slider = HSlider.new()
	_mouse_sens_slider.min_value = 0.25
	_mouse_sens_slider.max_value = 2.0
	_mouse_sens_slider.step = 0.05
	_mouse_sens_slider.value = GameState.mouse_sensitivity
	_mouse_sens_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_mouse_sens_slider.custom_minimum_size = Vector2(180, 22)
	_mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	sens_row.add_child(_mouse_sens_slider)

	_mouse_sens_label = Label.new()
	_mouse_sens_label.text = _format_sens(GameState.mouse_sensitivity)
	_mouse_sens_label.custom_minimum_size.x = 50
	_mouse_sens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mouse_sens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sens_row.add_child(_mouse_sens_label)

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
			_add_binding_row(_controls_vbox, display + " " + str(i + 1), key_label, "", "slot:" + slot_key, "")

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
		_add_binding_row(_controls_vbox, fg_label, key_lbl, "", "firegroup:" + str(i), "")


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

	# Name label with dark backing
	var name_panel := _make_dark_panel()
	name_panel.custom_minimum_size = Vector2(230, 30)
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
		kb_btn.pressed.connect(_start_capture.bind(kb_target, false))
		_style_binding_button(kb_btn)
		row.add_child(kb_btn)

	# Mouse binding button — always show for actions, allow assignment
	if ms_target != "":
		var ms_btn := Button.new()
		ms_btn.text = ms_label if ms_label != "" else "\u2014"
		ms_btn.custom_minimum_size = Vector2(90, 30)
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

	if not target.begins_with("action_mouse:"):
		return
	var action_name: String = target.replace("action_mouse:", "")
	var label: String = _mouse_button_label(button_index)
	KeyBindingManager.set_action_binding_mouse(action_name, button_index, label)

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
	ThemeManager.apply_grid_background(_bg_rect)
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
	for cb in [_persist_checkbox, _mouse_nav_indicator_checkbox]:
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
			if child is Label and not child in _styled_labels:
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
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
			sb.border_color = accent
			sb.border_width_bottom = 2
		else:
			sb.bg_color = Color(panel_color.r, panel_color.g, panel_color.b, 0.3)
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
	data["persist_enemy_audio"] = AudioBusSetup.persist_enemy_audio
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_audio_settings() -> void:
	if not FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		for bus_name in _sliders:
			_on_slider_changed(100.0, bus_name)
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
	AudioBusSetup.persist_enemy_audio = bool(data.get("persist_enemy_audio", false))
	if _persist_checkbox:
		_persist_checkbox.button_pressed = AudioBusSetup.persist_enemy_audio


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
