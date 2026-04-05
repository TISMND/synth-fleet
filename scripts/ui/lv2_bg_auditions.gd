extends MarginContainer
## Level 2 background auditions — live shader preview with control sliders.

var _shader_mat: ShaderMaterial = null
var _time: float = 0.0

# Slider references for reading values
var _sliders: Dictionary = {}

const SHADER_PATH: String = "res://assets/shaders/bg_bioluminescent_reef.gdshader"

const SLIDER_DEFS: Array[Dictionary] = [
	{"key": "cell_scale", "label": "CELL SCALE", "min": 0.3, "max": 4.0, "default": 0.3, "step": 0.05},
	{"key": "density", "label": "DENSITY", "min": 0.5, "max": 6.0, "default": 0.5, "step": 0.1},
	{"key": "strand_thickness", "label": "STRAND THICKNESS", "min": 0.01, "max": 0.5, "default": 0.02, "step": 0.005},
	{"key": "strand_sharpness", "label": "STRAND SHARPNESS", "min": 0.0, "max": 1.0, "default": 0.0, "step": 0.02},
	{"key": "fine_strand_thickness", "label": "FINE THICKNESS", "min": 0.01, "max": 0.5, "default": 0.01, "step": 0.005},
	{"key": "fine_strand_sharpness", "label": "FINE SHARPNESS", "min": 0.0, "max": 1.0, "default": 1.0, "step": 0.02},
	{"key": "fine_strand_blur", "label": "FINE STRAND BLUR", "min": 0.0, "max": 1.0, "default": 0.04, "step": 0.02},
	{"key": "fine_strand_mix", "label": "FINE STRAND MIX", "min": 0.0, "max": 1.0, "default": 0.8, "step": 0.02},
	{"key": "strand_brightness", "label": "STRAND BRIGHTNESS", "min": 0.0, "max": 5.0, "default": 0.8, "step": 0.05},
	{"key": "strand_hdr", "label": "STRAND HDR", "min": 1.0, "max": 6.0, "default": 4.3, "step": 0.1},
	{"key": "strand_white", "label": "STRAND WHITE", "min": 0.0, "max": 1.0, "default": 0.08, "step": 0.02},
	{"key": "drift_speed", "label": "DRIFT SPEED", "min": 0.0, "max": 1.0, "default": 0.06, "step": 0.02},
	{"key": "_sep_pulse", "label": "", "separator": true, "header": "PULSE WAVES"},
	{"key": "pulse_intensity", "label": "PULSE INTENSITY", "min": 0.0, "max": 1.0, "default": 0.3, "step": 0.02},
	{"key": "pulse_hdr", "label": "PULSE HDR", "min": 1.0, "max": 20.0, "default": 8.9, "step": 0.1},
	{"key": "pulse_threshold", "label": "PULSE DEAD SPACE", "min": 0.0, "max": 1.0, "default": 0.92, "step": 0.02},
	{"key": "pulse_softness", "label": "PULSE SOFTNESS", "min": 0.01, "max": 1.0, "default": 0.49, "step": 0.01},
	{"key": "pulse_speed", "label": "PULSE SPEED", "min": 0.0, "max": 5.0, "default": 0.5, "step": 0.02},
	{"key": "pulse_scale", "label": "PULSE SCALE", "min": 0.1, "max": 10.0, "default": 7.1, "step": 0.1},
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
	header.text = "BIOLUMINESCENT REEF"
	ThemeManager.apply_text_glow(header, "header")
	slider_col.add_child(header)

	# Color pickers
	_build_color_row(slider_col, "deep_color", "DEEP COLOR", Color(0.0, 0.02, 0.06))
	_build_color_row(slider_col, "coral_color", "CORAL COLOR", Color(0.0, 0.6, 0.9))

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
	print("── Reef shader values ──")
	for key in _sliders:
		var entry: Dictionary = _sliders[key]
		if entry.has("slider"):
			print("  ", key, " = ", (entry["slider"] as HSlider).value)
		elif entry.has("picker"):
			print("  ", key, " = ", (entry["picker"] as ColorPickerButton).color)
	print("────────────────────────")


func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(int(v))
	return "%.2f" % v
