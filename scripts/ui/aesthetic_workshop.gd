extends MarginContainer
## Aesthetic Workshop — real-time theme editor for Dev Studio.
## Tweaks colors, glow, font sizes, grid background params. Persists to user://.

# Color keys to expose in the palette section
const COLOR_KEYS: Array[String] = [
	"header", "accent", "positive", "warning",
	"background", "panel", "text", "dimmed",
]

# Float slider definitions: [key, label, min, max, step]
const GLOW_SLIDERS: Array[Array] = [
	["glow_intensity", "Glow Intensity:", 0.0, 2.0, 0.05],
	["neon_brightness", "Neon Brightness:", 0.0, 2.0, 0.05],
]

const GRID_SLIDERS: Array[Array] = [
	["grid_spacing", "Spacing:", 16.0, 256.0, 4.0],
	["grid_scroll_speed", "Scroll Speed:", 0.0, 100.0, 1.0],
	["grid_glow_intensity", "Glow:", 0.0, 2.0, 0.05],
	["grid_line_width", "Line Width:", 0.5, 4.0, 0.1],
]

const FONT_SIZE_SLIDERS: Array[Array] = [
	["font_size_header", "Header Size:", 12, 40, 1],
	["font_size_title", "Title Size:", 10, 32, 1],
	["font_size_section", "Section Size:", 10, 24, 1],
	["font_size_body", "Body Size:", 8, 20, 1],
]

# UI refs
var _preset_selector: OptionButton
var _preset_name_input: LineEdit
var _status_label: Label
var _color_pickers: Dictionary = {}  # key -> ColorPickerButton
var _grid_line_color_picker: ColorPickerButton
var _section_headers: Array[Label] = []


func _ready() -> void:
	_build_ui()
	_refresh_preset_list()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	# ── Presets ──
	_add_section_header(root, "PRESETS")
	var preset_row := HBoxContainer.new()
	root.add_child(preset_row)

	_preset_selector = OptionButton.new()
	_preset_selector.custom_minimum_size.x = 220
	preset_row.add_child(_preset_selector)

	var load_btn := Button.new()
	load_btn.text = "LOAD"
	load_btn.pressed.connect(_on_load_preset)
	preset_row.add_child(load_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 20
	preset_row.add_child(spacer)

	_preset_name_input = LineEdit.new()
	_preset_name_input.placeholder_text = "Custom preset name..."
	_preset_name_input.custom_minimum_size.x = 180
	preset_row.add_child(_preset_name_input)

	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.pressed.connect(_on_save_preset)
	preset_row.add_child(save_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.pressed.connect(_on_delete_preset)
	preset_row.add_child(del_btn)

	_add_separator(root)

	# ── Color Palette ──
	_add_section_header(root, "COLOR PALETTE")
	for key in COLOR_KEYS:
		var row := HBoxContainer.new()
		root.add_child(row)

		var label := Label.new()
		label.text = key.capitalize() + ":"
		label.custom_minimum_size.x = 130
		row.add_child(label)

		var picker := ColorPickerButton.new()
		picker.color = ThemeManager.get_color(key)
		picker.custom_minimum_size = Vector2(80, 28)
		var bound_key: String = key
		picker.color_changed.connect(func(c: Color) -> void:
			ThemeManager.set_color(bound_key, c)
			ThemeManager.save_settings()
		)
		row.add_child(picker)
		_color_pickers[key] = picker

	_add_separator(root)

	# ── Glow & Effects ──
	_add_section_header(root, "GLOW & EFFECTS")
	for def in GLOW_SLIDERS:
		var key: String = str(def[0])
		var label_text: String = str(def[1])
		var min_val: float = float(def[2])
		var max_val: float = float(def[3])
		var step_val: float = float(def[4])
		_add_float_slider(root, key, label_text, min_val, max_val, step_val)

	_add_separator(root)

	# ── Font Sizes ──
	_add_section_header(root, "FONT SIZES")
	for def in FONT_SIZE_SLIDERS:
		var key: String = str(def[0])
		var label_text: String = str(def[1])
		var min_val: float = float(def[2])
		var max_val: float = float(def[3])
		var step_val: float = float(def[4])
		_add_int_slider(root, key, label_text, min_val, max_val, step_val)

	_add_separator(root)

	# ── Grid Background ──
	_add_section_header(root, "GRID BACKGROUND")

	var glc_row := HBoxContainer.new()
	root.add_child(glc_row)
	var glc_label := Label.new()
	glc_label.text = "Line Color:"
	glc_label.custom_minimum_size.x = 130
	glc_row.add_child(glc_label)

	_grid_line_color_picker = ColorPickerButton.new()
	_grid_line_color_picker.color = ThemeManager.get_color("grid_line_color")
	_grid_line_color_picker.custom_minimum_size = Vector2(80, 28)
	_grid_line_color_picker.color_changed.connect(func(c: Color) -> void:
		ThemeManager.set_color("grid_line_color", c)
		ThemeManager.save_settings()
	)
	glc_row.add_child(_grid_line_color_picker)

	for def in GRID_SLIDERS:
		var key: String = str(def[0])
		var label_text: String = str(def[1])
		var min_val: float = float(def[2])
		var max_val: float = float(def[3])
		var step_val: float = float(def[4])
		_add_float_slider(root, key, label_text, min_val, max_val, step_val)

	_add_separator(root)

	# ── Status ──
	_status_label = Label.new()
	_status_label.text = ""
	root.add_child(_status_label)

	# Connect theme_changed to refresh pickers
	ThemeManager.theme_changed.connect(_refresh_pickers)


func _refresh_pickers() -> void:
	for key in _color_pickers:
		var picker: ColorPickerButton = _color_pickers[key]
		var current: Color = ThemeManager.get_color(key)
		if not picker.color.is_equal_approx(current):
			picker.color = current
	if _grid_line_color_picker:
		var glc: Color = ThemeManager.get_color("grid_line_color")
		if not _grid_line_color_picker.color.is_equal_approx(glc):
			_grid_line_color_picker.color = glc
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))


# ── Presets ───────────────────────────────────────────────────

func _refresh_preset_list() -> void:
	_preset_selector.clear()
	var names: Array[String] = ThemeManager.list_preset_names()
	for n in names:
		_preset_selector.add_item(n)


func _on_load_preset() -> void:
	if _preset_selector.selected < 0:
		return
	var name: String = _preset_selector.get_item_text(_preset_selector.selected)
	ThemeManager.apply_preset(name)
	_refresh_pickers()
	_status_label.text = "Loaded preset: " + name


func _on_save_preset() -> void:
	var pname: String = _preset_name_input.text.strip_edges()
	if pname == "":
		_status_label.text = "Enter a preset name first."
		return
	if ThemeManager.is_builtin_preset(pname):
		_status_label.text = "Cannot overwrite a built-in preset."
		return
	ThemeManager.save_custom_preset(pname)
	_refresh_preset_list()
	_status_label.text = "Saved preset: " + pname


func _on_delete_preset() -> void:
	var pname: String = _preset_name_input.text.strip_edges()
	if pname == "":
		_status_label.text = "Enter preset name to delete."
		return
	if ThemeManager.is_builtin_preset(pname):
		_status_label.text = "Cannot delete a built-in preset."
		return
	ThemeManager.delete_custom_preset(pname)
	_refresh_preset_list()
	_status_label.text = "Deleted preset: " + pname


# ── UI Helpers ────────────────────────────────────────────────

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


func _add_float_slider(parent: Control, key: String, label_text: String, min_val: float, max_val: float, step_val: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = ThemeManager.get_float(key)
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%.2f" % slider.value
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		value_label.text = "%.2f" % val
		ThemeManager.set_float(bound_key, val)
		ThemeManager.save_settings()
	)


func _add_int_slider(parent: Control, key: String, label_text: String, min_val: float, max_val: float, step_val: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = ThemeManager.get_font_size(key)
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(int(slider.value))
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var bound_key: String = key
	slider.value_changed.connect(func(val: float) -> void:
		value_label.text = str(int(val))
		ThemeManager.set_font_size(bound_key, int(val))
		ThemeManager.save_settings()
	)
