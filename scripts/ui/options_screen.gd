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

	# Title
	_title_label = Label.new()
	_title_label.text = "OPTIONS"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

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
	var controls_panel := _build_placeholder_tab("Key bindings coming soon.")
	var video_panel := _build_placeholder_tab("Video settings coming soon.")

	for panel in [sound_panel, gameplay_panel, controls_panel, video_panel]:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		content_area.add_child(panel)
		_tab_panels.append(panel)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size.y = 44
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)

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
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var label := Label.new()
	label.text = display_name
	label.custom_minimum_size.x = 180
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 300
	slider.custom_minimum_size.y = 30
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

	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		var row: HBoxContainer = slider.get_parent() as HBoxContainer
		if row and row.get_child_count() > 0:
			var name_label: Label = row.get_child(0) as Label
			if name_label:
				if body_font:
					name_label.add_theme_font_override("font", body_font)
				name_label.add_theme_font_size_override("font_size", body_size)
				name_label.add_theme_color_override("font_color", text_color)
				ThemeManager.apply_text_glow(name_label, "body")

	# Checkboxes
	for cb in [_persist_checkbox, _mouse_nav_indicator_checkbox]:
		if cb:
			if body_font:
				cb.add_theme_font_override("font", body_font)
			cb.add_theme_font_size_override("font_size", body_size)
			cb.add_theme_color_override("font_color", accent_color)

	# Placeholder labels
	for panel in _tab_panels:
		for child in panel.get_children():
			if child is Label:
				if body_font:
					child.add_theme_font_override("font", body_font)
				child.add_theme_font_size_override("font_size", body_size)

	_style_sliders(accent_color)

	# All buttons
	for child in _get_all_children(self):
		if child is Button and not child in _tab_buttons:
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

	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
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
