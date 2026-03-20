extends MarginContainer
## Orbiters Tab — visual style editor for orbiting object effects.
## Styles are saved to res://data/orbiter_styles/ and will be referenced by devices.

const ORBITER_SHADERS: Array[String] = ["glow", "flame", "electric", "crystal", "plasma", "void"]
const ORBITER_SHAPES: Array[String] = ["circle", "diamond", "triangle", "star", "crescent", "hexagon"]

const ORBITER_SHADER_PARAM_DEFS: Dictionary = {
	"glow": {"core_size": [0.1, 0.8, 0.4, 0.05], "glow_falloff": [0.5, 4.0, 1.5, 0.1], "flicker_amount": [0.0, 0.5, 0.05, 0.01]},
	"flame": {"flame_height": [0.2, 1.0, 0.5, 0.05], "turbulence": [0.5, 4.0, 2.0, 0.1], "core_heat": [0.5, 3.0, 1.5, 0.1]},
	"electric": {"arc_density": [2.0, 8.0, 4.0, 1.0], "arc_intensity": [0.5, 3.0, 1.5, 0.1], "jitter": [0.5, 4.0, 2.0, 0.1]},
	"crystal": {"facet_count": [3.0, 12.0, 6.0, 1.0], "refraction": [0.1, 1.0, 0.4, 0.05], "sparkle_speed": [0.5, 5.0, 2.0, 0.1]},
	"plasma": {"plasma_scale": [1.0, 6.0, 3.0, 0.5], "warp_strength": [0.1, 1.0, 0.4, 0.05], "color_shift": [0.0, 1.0, 0.3, 0.05]},
	"void": {"void_size": [0.05, 0.5, 0.2, 0.01], "rim_width": [0.05, 0.4, 0.15, 0.01], "distortion": [0.1, 2.0, 0.8, 0.1]},
}

# UI references — top bar
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _new_button: Button
var _status_label: Label
var _name_input: LineEdit

# Visual controls
var _shader_button: OptionButton
var _shape_button: OptionButton
var _color_picker: ColorPickerButton
var _glow_slider: HSlider
var _glow_label: Label
var _size_slider: HSlider
var _size_label: Label

# Orbit controls
var _orbit_speed_slider: HSlider
var _orbit_speed_label: Label
var _orbit_dir_button: OptionButton

# Behavior controls
var _spin_speed_slider: HSlider
var _spin_speed_label: Label
var _wobble_amount_slider: HSlider
var _wobble_amount_label: Label
var _wobble_speed_slider: HSlider
var _wobble_speed_label: Label

# Trail controls
var _trail_length_slider: HSlider
var _trail_length_label: Label
var _trail_fade_slider: HSlider
var _trail_fade_label: Label

# Dynamic shader params
var _shader_params_container: VBoxContainer
var _shader_param_sliders: Dictionary = {}

# Count
var _count_slider: HSlider
var _count_label: Label

# Preview
var _orbiter_renderer: OrbiterRenderer = null

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	call_deferred("_rebuild_preview")
	ThemeManager.theme_changed.connect(_apply_theme)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var load_label := Label.new()
	load_label.text = "Load:"
	top_bar.add_child(load_label)

	_load_button = OptionButton.new()
	_load_button.custom_minimum_size.x = 250
	_load_button.item_selected.connect(_on_load_selected)
	top_bar.add_child(_load_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "DELETE"
	_delete_button.pressed.connect(_on_delete)
	top_bar.add_child(_delete_button)

	_new_button = Button.new()
	_new_button.text = "NEW"
	_new_button.pressed.connect(_on_new)
	top_bar.add_child(_new_button)

	# Main content: HSplitContainer
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 420
	root.add_child(split)

	# Left: Preview
	var left_panel := _build_left_panel()
	split.add_child(left_panel)

	# Right: Controls
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)

	_build_controls(right_vbox)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE STYLE"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = "LIVE PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)
	_section_headers.append(preview_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(400, 400)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport_container.add_child(viewport)

	VFXFactory.add_bloom_to_viewport(viewport)

	# Dark bg
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(bg)

	# Ship silhouette
	var ship_dot := ColorRect.new()
	ship_dot.color = Color(0.3, 0.3, 0.4)
	ship_dot.size = Vector2(20, 30)
	ship_dot.position = Vector2(190, 185)
	viewport.add_child(ship_dot)

	# Orbiter renderer centered on ship
	_orbiter_renderer = OrbiterRenderer.new()
	_orbiter_renderer.position = Vector2(200, 200)
	viewport.add_child(_orbiter_renderer)

	return panel


func _build_controls(parent: VBoxContainer) -> void:
	# Name
	_add_section_header(parent, "NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter orbiter style name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_name_input)

	_add_separator(parent)

	# Shader
	_add_section_header(parent, "SHADER")
	_shader_button = OptionButton.new()
	_shader_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ORBITER_SHADERS:
		_shader_button.add_item(s)
	_shader_button.item_selected.connect(_on_shader_changed)
	parent.add_child(_shader_button)

	# Shape
	_add_section_header(parent, "SHAPE")
	_shape_button = OptionButton.new()
	_shape_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ORBITER_SHAPES:
		_shape_button.add_item(s)
	_shape_button.item_selected.connect(func(_idx: int) -> void: _rebuild_preview())
	parent.add_child(_shape_button)

	# Visual
	_add_section_header(parent, "VISUAL")
	var color_row := HBoxContainer.new()
	parent.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size.x = 130
	color_row.add_child(color_label)
	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color(0.0, 1.0, 1.0, 1.0)
	_color_picker.custom_minimum_size = Vector2(80, 30)
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.color_changed.connect(func(_c: Color) -> void: _rebuild_preview())
	color_row.add_child(_color_picker)

	var glow_row: Array = _add_slider_row(parent, "HDR Brightness:", 0.5, 6.0, 2.0, 0.1)
	_glow_slider = glow_row[0]
	_glow_label = glow_row[1]

	var size_row: Array = _add_slider_row(parent, "Size:", 6.0, 48.0, 16.0, 1.0)
	_size_slider = size_row[0]
	_size_label = size_row[1]

	# Dynamic per-shader params
	_shader_params_container = VBoxContainer.new()
	_shader_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_shader_params_container)
	_rebuild_shader_params("glow")

	_add_separator(parent)

	# Orbit
	_add_section_header(parent, "ORBIT")
	var cnt_row: Array = _add_slider_row(parent, "Count:", 1.0, 8.0, 3.0, 1.0)
	_count_slider = cnt_row[0]
	_count_label = cnt_row[1]

	var spd_row: Array = _add_slider_row(parent, "Speed:", 0.1, 5.0, 1.0, 0.1)
	_orbit_speed_slider = spd_row[0]
	_orbit_speed_label = spd_row[1]

	var dir_row := HBoxContainer.new()
	parent.add_child(dir_row)
	var dir_label := Label.new()
	dir_label.text = "Direction:"
	dir_label.custom_minimum_size.x = 130
	dir_row.add_child(dir_label)
	_orbit_dir_button = OptionButton.new()
	_orbit_dir_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orbit_dir_button.add_item("Counter-clockwise")
	_orbit_dir_button.add_item("Clockwise")
	_orbit_dir_button.item_selected.connect(func(_idx: int) -> void: _rebuild_preview())
	dir_row.add_child(_orbit_dir_button)

	_add_separator(parent)

	# Behavior
	_add_section_header(parent, "BEHAVIOR")
	var spin_row: Array = _add_slider_row(parent, "Spin:", -10.0, 10.0, 0.0, 0.5)
	_spin_speed_slider = spin_row[0]
	_spin_speed_label = spin_row[1]

	var wa_row: Array = _add_slider_row(parent, "Wobble Amt:", 0.0, 30.0, 0.0, 1.0)
	_wobble_amount_slider = wa_row[0]
	_wobble_amount_label = wa_row[1]

	var ws_row: Array = _add_slider_row(parent, "Wobble Speed:", 0.5, 8.0, 2.0, 0.5)
	_wobble_speed_slider = ws_row[0]
	_wobble_speed_label = ws_row[1]

	_add_separator(parent)

	# Trail
	_add_section_header(parent, "TRAIL")
	var tl_row: Array = _add_slider_row(parent, "Length:", 0.0, 8.0, 0.0, 1.0)
	_trail_length_slider = tl_row[0]
	_trail_length_label = tl_row[1]

	var tf_row: Array = _add_slider_row(parent, "Fade:", 0.2, 0.95, 0.6, 0.05)
	_trail_fade_slider = tf_row[0]
	_trail_fade_label = tf_row[1]


func _rebuild_shader_params(shader_name: String) -> void:
	for child in _shader_params_container.get_children():
		child.queue_free()
	_shader_param_sliders.clear()

	var defs: Dictionary = ORBITER_SHADER_PARAM_DEFS.get(shader_name, {}) as Dictionary
	if defs.is_empty():
		return

	for param_name in defs:
		var bounds: Array = defs[param_name]
		var row: Array = _add_slider_row(_shader_params_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_shader_param_sliders[param_name] = row[0]


func _on_shader_changed(_idx: int) -> void:
	var shader_name: String = _shader_button.get_item_text(_shader_button.selected)
	_rebuild_shader_params(shader_name)
	_rebuild_preview()


func _collect_style() -> OrbiterStyle:
	var shader_params: Dictionary = {}
	for param_name in _shader_param_sliders:
		var slider: HSlider = _shader_param_sliders[param_name]
		shader_params[param_name] = slider.value

	var s := OrbiterStyle.new()
	s.id = _current_id if _current_id != "" else _generate_id(_name_input.text)
	s.display_name = _name_input.text
	s.shader = _shader_button.get_item_text(_shader_button.selected)
	s.shader_params = shader_params
	s.shape = _shape_button.get_item_text(_shape_button.selected)
	s.color = _color_picker.color
	s.glow_intensity = _glow_slider.value
	s.size = _size_slider.value
	s.orbiter_count = int(_count_slider.value)
	s.orbit_speed = _orbit_speed_slider.value
	s.orbit_direction = 1 if _orbit_dir_button.selected == 0 else -1
	s.spin_speed = _spin_speed_slider.value
	s.wobble_amount = _wobble_amount_slider.value
	s.wobble_speed = _wobble_speed_slider.value
	s.trail_length = int(_trail_length_slider.value)
	s.trail_fade = _trail_fade_slider.value
	return s


func _rebuild_preview() -> void:
	if not _ui_ready or not _orbiter_renderer:
		return
	var style: OrbiterStyle = _collect_style()
	_orbiter_renderer.remove_all()
	_orbiter_renderer.setup(style)
	_orbiter_renderer.set_orbit_radius(80.0)  # fixed preview radius
	var count: int = style.orbiter_count
	for i in range(count):
		_orbiter_renderer.add_orbiter(float(i) / float(count))


# ── Save / Load / Delete ──────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a style name first!"
		return
	var style: OrbiterStyle = _collect_style()
	var id: String = style.id
	_current_id = id
	OrbiterStyleManager.save(id, style.to_dict())
	_status_label.text = "Saved: " + id
	_refresh_load_list()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var style: OrbiterStyle = OrbiterStyleManager.load_by_id(id)
	if not style:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_style(style)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No style loaded to delete."
		return
	OrbiterStyleManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_name_input.text = ""
	_shader_button.selected = 0
	_shape_button.selected = 0
	_color_picker.color = Color(0.0, 1.0, 1.0, 1.0)
	_glow_slider.value = 2.0
	_size_slider.value = 16.0
	_count_slider.value = 3.0
	_orbit_speed_slider.value = 1.0
	_orbit_dir_button.selected = 0
	_spin_speed_slider.value = 0.0
	_wobble_amount_slider.value = 0.0
	_wobble_speed_slider.value = 2.0
	_trail_length_slider.value = 0.0
	_trail_fade_slider.value = 0.6
	_rebuild_shader_params("glow")
	_rebuild_preview()
	_status_label.text = "New orbiter style — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select style)")
	var ids: Array[String] = OrbiterStyleManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_style(style: OrbiterStyle) -> void:
	_current_id = style.id
	_name_input.text = style.display_name

	var shader_idx: int = ORBITER_SHADERS.find(style.shader)
	_shader_button.selected = shader_idx if shader_idx >= 0 else 0
	_rebuild_shader_params(style.shader)

	for param_name in style.shader_params:
		if param_name in _shader_param_sliders:
			var slider: HSlider = _shader_param_sliders[param_name]
			slider.value = float(style.shader_params[param_name])

	var shape_idx: int = ORBITER_SHAPES.find(style.shape)
	_shape_button.selected = shape_idx if shape_idx >= 0 else 0

	_color_picker.color = style.color
	_glow_slider.value = style.glow_intensity
	_size_slider.value = style.size
	_count_slider.value = float(style.orbiter_count)
	_orbit_speed_slider.value = style.orbit_speed
	_orbit_dir_button.selected = 0 if style.orbit_direction == 1 else 1
	_spin_speed_slider.value = style.spin_speed
	_wobble_amount_slider.value = style.wobble_amount
	_wobble_speed_slider.value = style.wobble_speed
	_trail_length_slider.value = float(style.trail_length)
	_trail_fade_slider.value = style.trail_fade

	_rebuild_preview()


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "orbiter_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower().replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "orbiter_" + str(randi() % 10000)
	return clean


# ── UI Helpers ─────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	parent.add_child(label)
	_section_headers.append(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


func _add_slider_row(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, step_val: float) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(default_val)
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		if step_val >= 1.0:
			value_label.text = str(int(val))
		else:
			value_label.text = "%.2f" % val
		_rebuild_preview()
	)

	return [slider, value_label]


func _apply_theme() -> void:
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if _save_button:
		ThemeManager.apply_button_style(_save_button)
	if _delete_button:
		ThemeManager.apply_button_style(_delete_button)
	if _new_button:
		ThemeManager.apply_button_style(_new_button)
