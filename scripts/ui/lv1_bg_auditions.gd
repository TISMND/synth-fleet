extends MarginContainer
## Level 1 background auditions — synthwave grid with HDR etchers.

var _shader_mat: ShaderMaterial = null
var _time: float = 0.0
var _sliders: Dictionary = {}

const SHADER_PATH: String = "res://assets/shaders/bg_synthwave_pulse.gdshader"

const SLIDER_DEFS: Array[Dictionary] = [
	{"key": "grid_spacing", "label": "GRID SPACING", "min": 20.0, "max": 200.0, "default": 104.0, "step": 1.0},
	{"key": "line_width", "label": "LINE WIDTH", "min": 0.5, "max": 4.0, "default": 1.9, "step": 0.1},
	{"key": "glow_size", "label": "GLOW SIZE", "min": 0.0, "max": 30.0, "default": 12.0, "step": 0.5},
	{"key": "core_intensity", "label": "CORE INTENSITY", "min": 0.0, "max": 4.0, "default": 1.0, "step": 0.1},
	{"key": "grid_hdr", "label": "GRID HDR", "min": 1.0, "max": 10.0, "default": 1.0, "step": 0.1},
	{"key": "grid_white", "label": "GRID WHITE", "min": 0.0, "max": 1.0, "default": 0.18, "step": 0.02},
	{"key": "_sep_etchers", "label": "", "separator": true, "header": "ETCHERS"},
	{"key": "etch_speed", "label": "ETCH SPEED", "min": 10.0, "max": 400.0, "default": 235.0, "step": 5.0},
	{"key": "min_etch_speed", "label": "MIN ETCH SPEED", "min": 10.0, "max": 400.0, "default": 190.0, "step": 5.0},
	{"key": "speed_variation", "label": "SPEED VARIATION", "min": 0.0, "max": 1.0, "default": 0.96, "step": 0.02},
	{"key": "etcher_size", "label": "ETCHER SIZE", "min": 10.0, "max": 80.0, "default": 10.0, "step": 1.0},
	{"key": "line_length", "label": "LINE LENGTH", "min": 2000.0, "max": 6000.0, "default": 2750.0, "step": 50.0},
	{"key": "dark_gap", "label": "DARK GAP", "min": 100.0, "max": 1500.0, "default": 1280.0, "step": 10.0},
	{"key": "_sep_pulse", "label": "", "separator": true, "header": "PULSE WAVES"},
	{"key": "pulse_intensity", "label": "PULSE INTENSITY", "min": 0.0, "max": 1.0, "default": 0.42, "step": 0.02},
	{"key": "pulse_hdr", "label": "PULSE HDR", "min": 1.0, "max": 20.0, "default": 2.8, "step": 0.1},
	{"key": "pulse_threshold", "label": "PULSE DEAD SPACE", "min": 0.0, "max": 1.0, "default": 0.7, "step": 0.02},
	{"key": "pulse_softness", "label": "PULSE SOFTNESS", "min": 0.01, "max": 1.0, "default": 0.22, "step": 0.01},
	{"key": "pulse_speed", "label": "PULSE SPEED", "min": 0.0, "max": 5.0, "default": 5.0, "step": 0.02},
	{"key": "pulse_scale", "label": "PULSE SCALE", "min": 0.1, "max": 10.0, "default": 0.9, "step": 0.1},
	{"key": "pulse_wobble", "label": "PULSE WOBBLE", "min": 0.0, "max": 3.0, "default": 3.0, "step": 0.02},
]


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	_time += _delta


func _build_ui() -> void:
	var main := HBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	add_child(main)

	# Left: shader preview viewport
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = load(SHADER_PATH) as Shader
	if shader:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = shader
		shader_rect.material = _shader_mat
	vp.add_child(shader_rect)

	# Right: slider panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var slider_col := VBoxContainer.new()
	slider_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_col.add_theme_constant_override("separation", 6)
	scroll.add_child(slider_col)

	var header := Label.new()
	header.text = "SYNTHWAVE GRID"
	ThemeManager.apply_text_glow(header, "header")
	slider_col.add_child(header)

	# Color pickers
	_build_color_row(slider_col, "grid_color", "GRID COLOR", Color(1.0, 0.102, 0.7544))
	_build_color_row(slider_col, "head_color", "HEAD COLOR", Color(1.0, 0.9414, 0.98))
	_build_color_row(slider_col, "band_color_a", "BAND COLOR A", Color(0.9648, 0.5503, 0.9001))
	_build_color_row(slider_col, "band_color_b", "BAND COLOR B", Color(0.15, 0.0, 0.25))

	# Sliders
	for def in SLIDER_DEFS:
		if def.get("separator", false):
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 8)
			slider_col.add_child(sep)
			var sep_header := Label.new()
			sep_header.text = def.get("header", "") as String
			ThemeManager.apply_text_glow(sep_header, "header")
			slider_col.add_child(sep_header)
			continue
		_build_slider_row(slider_col, def)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "RESET ALL"
	reset_btn.pressed.connect(_reset_all)
	ThemeManager.apply_button_style(reset_btn)
	slider_col.add_child(reset_btn)

	# Print button
	var print_btn := Button.new()
	print_btn.text = "PRINT VALUES"
	print_btn.pressed.connect(_print_values)
	ThemeManager.apply_button_style(print_btn)
	slider_col.add_child(print_btn)


func _build_slider_row(parent: VBoxContainer, def: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var lbl := Label.new()
	lbl.text = def["label"] as String
	lbl.custom_minimum_size.x = 160
	ThemeManager.apply_text_glow(lbl, "body")
	hbox.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size.x = 50
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ThemeManager.apply_text_glow(val_lbl, "body")
	hbox.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = float(def["min"])
	slider.max_value = float(def["max"])
	slider.step = float(def["step"])
	slider.value = float(def["default"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 20
	row.add_child(slider)

	var key: String = def["key"] as String
	val_lbl.text = _fmt(slider.value)
	_sliders[key] = {"slider": slider, "label": val_lbl, "default": float(def["default"])}

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = _fmt(v)
		if _shader_mat:
			_shader_mat.set_shader_parameter(key, v)
	)

	# Apply initial value
	if _shader_mat:
		_shader_mat.set_shader_parameter(key, slider.value)


func _build_color_row(parent: VBoxContainer, param: String, label_text: String, default_color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 160
	ThemeManager.apply_text_glow(lbl, "body")
	hbox.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(50, 25)
	picker.color = default_color
	picker.edit_alpha = false
	hbox.add_child(picker)

	_sliders[param] = {"picker": picker, "default": default_color}

	if _shader_mat:
		_shader_mat.set_shader_parameter(param, Color(default_color, 1.0))

	picker.color_changed.connect(func(c: Color) -> void:
		if _shader_mat:
			_shader_mat.set_shader_parameter(param, Color(c, 1.0))
	)


func _reset_all() -> void:
	for key in _sliders:
		var entry: Dictionary = _sliders[key]
		if entry.has("slider"):
			var slider: HSlider = entry["slider"] as HSlider
			slider.value = float(entry["default"])
		elif entry.has("picker"):
			var picker: ColorPickerButton = entry["picker"] as ColorPickerButton
			picker.color = entry["default"] as Color


func _print_values() -> void:
	print("── Synthwave grid values ──")
	for key in _sliders:
		var entry: Dictionary = _sliders[key]
		if entry.has("slider"):
			print("  ", key, " = ", (entry["slider"] as HSlider).value)
		elif entry.has("picker"):
			print("  ", key, " = ", (entry["picker"] as ColorPickerButton).color)
	print("───────────────────────────")


func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(int(v))
	return "%.2f" % v
