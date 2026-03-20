extends Control
## Options screen with volume sliders for each audio bus.
## Accessible from main menu. Saves/loads settings to user://settings/audio.json.

const SETTINGS_PATH := "user://settings/audio.json"

# Bus definitions: display name -> AudioServer bus name
# These buses are created programmatically at startup if they don't exist.
const BUS_DEFS: Array[Array] = [
	["MASTER", "Master"],
	["WEAPONS", "Weapons"],
	["ENEMIES", "Enemies"],
	["ATMOSPHERE", "Atmosphere"],
	["SFX", "SFX"],
	["UI", "UI"],
]

var _vhs_overlay: ColorRect
var _bg_rect: ColorRect
var _title_label: Label
var _sliders: Dictionary = {}  # bus_name -> HSlider
var _value_labels: Dictionary = {}  # bus_name -> Label


func _ready() -> void:
	_ensure_audio_buses()
	_build_ui()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_load_settings()
	_apply_theme()


func _ensure_audio_buses() -> void:
	## Create any missing audio buses so sliders have something to control.
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
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 100)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "OPTIONS"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	# Volume sliders
	for def in BUS_DEFS:
		var display_name: String = def[0]
		var bus_name: String = def[1]
		_add_volume_row(vbox, display_name, bus_name)

	# Spacer before back button
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 30
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer2)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size.y = 44
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)


func _add_volume_row(parent: VBoxContainer, display_name: String, bus_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	# Label for bus name
	var label := Label.new()
	label.text = display_name
	label.custom_minimum_size.x = 180
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# Slider
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

	# Value label (percentage)
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
	_save_settings()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _apply_theme() -> void:
	# Grid background
	ThemeManager.apply_grid_background(_bg_rect)

	# VHS overlay
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	# Title
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		_title_label.add_theme_font_override("font", header_font)
	_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	ThemeManager.apply_text_glow(_title_label, "header")

	# Body font for labels
	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")
	var text_color: Color = ThemeManager.get_color("text")
	var accent_color: Color = ThemeManager.get_color("accent")

	# Style all bus labels and value labels
	for bus_name in _sliders:
		if _value_labels.has(bus_name):
			var val_lbl: Label = _value_labels[bus_name]
			if body_font:
				val_lbl.add_theme_font_override("font", body_font)
			val_lbl.add_theme_font_size_override("font_size", body_size)
			val_lbl.add_theme_color_override("font_color", accent_color)

	# Style row labels (bus name labels are the first child of each HBoxContainer row)
	# Walk through the slider parents to find the row labels
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

	# Style slider grabber/track with theme colors
	_style_sliders(accent_color)

	# Style buttons
	for child in _get_all_children(self):
		if child is Button:
			ThemeManager.apply_button_style(child as Button)


func _style_sliders(accent: Color) -> void:
	var panel_color: Color = ThemeManager.get_color("panel")

	# Create shared styleboxes for all sliders
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(panel_color.r, panel_color.g, panel_color.b, 0.6)
	track_sb.set_corner_radius_all(2)
	track_sb.set_content_margin_all(0)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(accent.r, accent.g, accent.b, 0.4)
	fill_sb.set_corner_radius_all(2)
	fill_sb.set_content_margin_all(0)

	var grabber_sb := StyleBoxFlat.new()
	grabber_sb.bg_color = accent
	grabber_sb.set_corner_radius_all(4)
	grabber_sb.set_content_margin_all(0)

	var grabber_hover_sb := StyleBoxFlat.new()
	grabber_hover_sb.bg_color = accent.lightened(0.2)
	grabber_hover_sb.set_corner_radius_all(4)
	grabber_hover_sb.set_content_margin_all(0)

	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		slider.add_theme_stylebox_override("slider", track_sb.duplicate())
		slider.add_theme_stylebox_override("grabber_area", fill_sb.duplicate())
		slider.add_theme_stylebox_override("grabber_area_highlight", fill_sb.duplicate())
		# Grabber icon size
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


func _on_theme_changed() -> void:
	_apply_theme()


func _save_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var data: Dictionary = {}
	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		data[bus_name] = slider.value
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		# Apply defaults (100%) to all buses
		for bus_name in _sliders:
			_on_slider_changed(100.0, bus_name)
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
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
		# Trigger the change to apply to AudioServer
		_on_slider_changed(val, bus_name)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
