extends Control
## Auditions screen — tabbed: Warning Types + Fire Effect audition.
## Warning tab: preset 9 style boxes with per-warning color/HDR.
## Fire tab: live preview of HUD heat effect with timeline + tuning controls.

const SLAB_WIDTH: int = 320
const SLAB_HEIGHT: int = 180
const BOX_W: float = 220.0
const BOX_H: float = 70.0

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button
var _slab_data: Array = []
var _saved_values: Dictionary = {}  # warning_id -> {hdr, color_r, color_g, color_b}

# Tab state
var _active_tab: int = 0  # 0 = warnings, 1 = fire effect
var _tab_warnings_btn: Button
var _tab_fire_btn: Button
var _warnings_content: Control
var _fire_content: Control

const SAVE_PATH := "user://settings/warning_auditions.json"
const FIRE_SAVE_PATH := "user://settings/fire_audition.json"

# Base style (preset 9: violet corner marks chromatic)
const BASE_STYLE: Dictionary = {
	"border_width": 2.0,
	"glow_layers": 4,
	"glow_spread": 3.0,
	"scanline_spacing": 3.0,
	"scanline_alpha": 0.35,
	"scanline_scroll": 45.0,
	"flicker_speed": 7.0,
	"flicker_amount": 0.22,
	"corner_marks": true,
	"double_border": false,
}

# Warning types — paired: orange watch / red warning for each system
const WARNINGS: Array = [
	# Thermal
	{"id": "heat", "label": "HEAT", "color": Color(1.0, 0.4, 0.1), "hdr": 2.8},
	{"id": "fire", "label": "FIRE", "color": Color(1.0, 0.2, 0.0), "hdr": 3.0},
	# Electric
	{"id": "low_power", "label": "LOW POWER", "color": Color(0.7, 0.3, 1.0), "hdr": 2.8},
	{"id": "overdraw", "label": "OVERDRAW", "color": Color(1.0, 0.15, 0.1), "hdr": 3.2},
	# Shields
	{"id": "shields_low", "label": "SHIELDS LOW", "color": Color(1.0, 0.4, 0.1), "hdr": 2.8},
	{"id": "shield_break", "label": "SHIELD BREAK", "color": Color(1.0, 0.15, 0.1), "hdr": 3.0},
	# Hull
	{"id": "hull_damaged", "label": "HULL DAMAGED", "color": Color(1.0, 0.4, 0.1), "hdr": 2.5},
	{"id": "hull_critical", "label": "HULL CRITICAL", "color": Color(1.0, 0.15, 0.1), "hdr": 3.2},
]

# ── Fire effect audition state ───────────────────────────────────────
var _fire_playing: bool = false
var _fire_intensity: float = 0.0
var _fire_time: float = 0.0
var _fire_speed: float = 1.0
var _fire_chrome_mats: Array = []  # ShaderMaterial refs for preview panels
var _fire_intensity_slider: HSlider
var _fire_intensity_label: Label
var _fire_play_btn: Button
var _fire_speed_slider: HSlider
var _fire_smoke_slider: HSlider
var _fire_spark_slider: HSlider
var _fire_ramp_slider: HSlider
var _fire_flicker_slider: HSlider
var _fire_particle_container: Node2D  # Smoke + sparks
var _fire_smoke_particles: Array = []
var _fire_spark_particles: Array = []
var _fire_smoke_accum: float = 0.0
var _fire_spark_accum: float = 0.0
# Color stage pickers
var _fire_color_btns: Array = []  # 4 ColorPickerButtons
# Preview panel rects (for particle spawn positions)
var _fire_preview_left: ColorRect
var _fire_preview_right: ColorRect
var _fire_preview_bottom: ColorRect
var _fire_preview_container: Control  # Parent of preview panels

# Defaults for fire tuning
const FIRE_DEFAULTS: Dictionary = {
	"smoke_rate": 8.0,
	"spark_rate": 12.0,
	"ramp_speed": 0.4,
	"flicker_amount": 0.08,
	"color_1": [0.6, 0.02, 0.0],
	"color_2": [1.0, 0.3, 0.0],
	"color_3": [1.5, 0.8, 0.05],
	"color_4": [2.5, 2.0, 1.5],
}
var _fire_values: Dictionary = {}


func _ready() -> void:
	_load_saved()
	_load_fire_saved()
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	if _active_tab != 1:
		return
	_process_fire_audition(delta)


func _load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_saved_values = json.data


func _save_values() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings/")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_saved_values, "\t"))


func _load_fire_saved() -> void:
	_fire_values = FIRE_DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(FIRE_SAVE_PATH):
		return
	var file := FileAccess.open(FIRE_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		for key in data:
			_fire_values[key] = data[key]


func _save_fire_values() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings/")
	var file := FileAccess.open(FIRE_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_fire_values, "\t"))


func _get_warning_color(warning_id: String, default_color: Color) -> Color:
	if _saved_values.has(warning_id):
		var d: Dictionary = _saved_values[warning_id]
		return Color(float(d.get("r", default_color.r)), float(d.get("g", default_color.g)), float(d.get("b", default_color.b)))
	return default_color


func _get_warning_hdr(warning_id: String, default_hdr: float) -> float:
	if _saved_values.has(warning_id):
		return float(_saved_values[warning_id].get("hdr", default_hdr))
	return default_hdr


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# Header: BACK + title + tab buttons
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS"
	header_hbox.add_child(_title_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	# Tab buttons
	_tab_warnings_btn = Button.new()
	_tab_warnings_btn.text = "WARNINGS"
	_tab_warnings_btn.toggle_mode = true
	_tab_warnings_btn.button_pressed = true
	_tab_warnings_btn.pressed.connect(_show_warnings_tab)
	header_hbox.add_child(_tab_warnings_btn)

	_tab_fire_btn = Button.new()
	_tab_fire_btn.text = "FIRE EFFECT"
	_tab_fire_btn.toggle_mode = true
	_tab_fire_btn.pressed.connect(_show_fire_tab)
	header_hbox.add_child(_tab_fire_btn)

	# ── Warnings content ──
	_warnings_content = ScrollContainer.new()
	_warnings_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_warnings_content.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_warnings_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_warnings_content)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warnings_content.add_child(flow)

	for i in WARNINGS.size():
		_build_slab(i, flow)

	# ── Fire effect content ──
	_fire_content = Control.new()
	_fire_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fire_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fire_content.visible = false
	main_vbox.add_child(_fire_content)
	_build_fire_tab()

	_setup_vhs_overlay()


func _show_warnings_tab() -> void:
	if _active_tab == 0:
		_tab_warnings_btn.button_pressed = true
		return
	_active_tab = 0
	_tab_warnings_btn.button_pressed = true
	_tab_fire_btn.button_pressed = false
	_warnings_content.visible = true
	_fire_content.visible = false
	_fire_playing = false
	_update_fire_play_btn()


func _show_fire_tab() -> void:
	if _active_tab == 1:
		_tab_fire_btn.button_pressed = true
		return
	_active_tab = 1
	_tab_warnings_btn.button_pressed = false
	_tab_fire_btn.button_pressed = true
	_warnings_content.visible = false
	_fire_content.visible = true


# ── Fire effect audition tab ─────────────────────────────────────────

func _build_fire_tab() -> void:
	var hsplit := HBoxContainer.new()
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.add_theme_constant_override("separation", 20)
	_fire_content.add_child(hsplit)

	# Left: preview area — miniature HUD layout with chrome panels
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(900, 0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.01, 0.01, 0.02, 1.0)
	preview_style.set_content_margin_all(0)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	hsplit.add_child(preview_panel)

	_fire_preview_container = Control.new()
	_fire_preview_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fire_preview_container.clip_contents = true
	preview_panel.add_child(_fire_preview_container)

	# Build chrome panels matching HUD layout (scaled down)
	# Preview area ~900x700: left strip (40px), right strip (40px), bottom bar (60px)
	var chrome_shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader

	# Left panel
	_fire_preview_left = ColorRect.new()
	_fire_preview_left.color = Color.WHITE
	_fire_preview_left.position = Vector2(0, 0)
	_fire_preview_left.size = Vector2(40, 640)
	if chrome_shader:
		var mat := ShaderMaterial.new()
		mat.shader = chrome_shader
		_apply_chrome_defaults(mat)
		mat.set_shader_parameter("divider_y", 0.5)
		_fire_preview_left.material = mat
		_fire_chrome_mats.append(mat)
	_fire_preview_container.add_child(_fire_preview_left)

	# Right panel
	_fire_preview_right = ColorRect.new()
	_fire_preview_right.color = Color.WHITE
	_fire_preview_right.position = Vector2(860, 0)
	_fire_preview_right.size = Vector2(40, 640)
	if chrome_shader:
		var mat := ShaderMaterial.new()
		mat.shader = chrome_shader
		_apply_chrome_defaults(mat)
		mat.set_shader_parameter("divider_y", 0.5)
		_fire_preview_right.material = mat
		_fire_chrome_mats.append(mat)
	_fire_preview_container.add_child(_fire_preview_right)

	# Bottom panel
	_fire_preview_bottom = ColorRect.new()
	_fire_preview_bottom.color = Color.WHITE
	_fire_preview_bottom.position = Vector2(0, 640)
	_fire_preview_bottom.size = Vector2(900, 60)
	if chrome_shader:
		var mat := ShaderMaterial.new()
		mat.shader = chrome_shader
		_apply_chrome_defaults(mat)
		mat.set_shader_parameter("divider_y", -1.0)
		_fire_preview_bottom.material = mat
		_fire_chrome_mats.append(mat)
	_fire_preview_container.add_child(_fire_preview_bottom)

	# Particle container — above chrome panels
	_fire_particle_container = Node2D.new()
	_fire_particle_container.z_index = 5
	_fire_preview_container.add_child(_fire_particle_container)

	# Apply saved colors to shader uniforms
	_apply_fire_colors_to_shaders()

	# Right: controls panel
	var controls_scroll := ScrollContainer.new()
	controls_scroll.custom_minimum_size = Vector2(380, 0)
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hsplit.add_child(controls_scroll)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls)

	# ── Intensity scrubber ──
	_add_section_label(controls, "INTENSITY")
	var intensity_row := HBoxContainer.new()
	intensity_row.add_theme_constant_override("separation", 8)
	controls.add_child(intensity_row)
	_fire_intensity_slider = HSlider.new()
	_fire_intensity_slider.min_value = 0.0
	_fire_intensity_slider.max_value = 1.0
	_fire_intensity_slider.step = 0.005
	_fire_intensity_slider.value = 0.0
	_fire_intensity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fire_intensity_slider.value_changed.connect(_on_fire_intensity_changed)
	intensity_row.add_child(_fire_intensity_slider)
	_fire_intensity_label = Label.new()
	_fire_intensity_label.text = "0%"
	_fire_intensity_label.custom_minimum_size.x = 40
	ThemeManager.apply_text_glow(_fire_intensity_label, "body")
	intensity_row.add_child(_fire_intensity_label)

	# ── Transport controls ──
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	controls.add_child(transport)

	_fire_play_btn = Button.new()
	_fire_play_btn.text = "\u25b6 PLAY"
	_fire_play_btn.pressed.connect(_on_fire_play_pause)
	transport.add_child(_fire_play_btn)

	var reset_btn := Button.new()
	reset_btn.text = "\u25a0 RESET"
	reset_btn.pressed.connect(_on_fire_reset)
	transport.add_child(reset_btn)

	# Speed
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	controls.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "SPEED"
	speed_label.custom_minimum_size.x = 60
	ThemeManager.apply_text_glow(speed_label, "body")
	speed_row.add_child(speed_label)
	_fire_speed_slider = HSlider.new()
	_fire_speed_slider.min_value = 0.05
	_fire_speed_slider.max_value = 3.0
	_fire_speed_slider.step = 0.05
	_fire_speed_slider.value = 1.0
	_fire_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(_fire_speed_slider)

	# ── Separator ──
	controls.add_child(HSeparator.new())
	_add_section_label(controls, "PARTICLE RATES")

	# Smoke rate
	_fire_smoke_slider = _add_tuning_slider(controls, "SMOKE", 0.0, 30.0, 0.5,
		float(_fire_values.get("smoke_rate", FIRE_DEFAULTS["smoke_rate"])))
	_fire_smoke_slider.value_changed.connect(func(val: float) -> void:
		_fire_values["smoke_rate"] = val
		_save_fire_values()
	)

	# Spark rate
	_fire_spark_slider = _add_tuning_slider(controls, "SPARKS", 0.0, 40.0, 0.5,
		float(_fire_values.get("spark_rate", FIRE_DEFAULTS["spark_rate"])))
	_fire_spark_slider.value_changed.connect(func(val: float) -> void:
		_fire_values["spark_rate"] = val
		_save_fire_values()
	)

	# ── Separator ──
	controls.add_child(HSeparator.new())
	_add_section_label(controls, "TIMING")

	# Ramp speed
	_fire_ramp_slider = _add_tuning_slider(controls, "RAMP", 0.05, 2.0, 0.05,
		float(_fire_values.get("ramp_speed", FIRE_DEFAULTS["ramp_speed"])))
	_fire_ramp_slider.value_changed.connect(func(val: float) -> void:
		_fire_values["ramp_speed"] = val
		_save_fire_values()
	)

	# Flicker
	_fire_flicker_slider = _add_tuning_slider(controls, "FLICKER", 0.0, 0.3, 0.005,
		float(_fire_values.get("flicker_amount", FIRE_DEFAULTS["flicker_amount"])))
	_fire_flicker_slider.value_changed.connect(func(val: float) -> void:
		_fire_values["flicker_amount"] = val
		_save_fire_values()
	)

	# ── Separator ──
	controls.add_child(HSeparator.new())
	_add_section_label(controls, "HEAT COLOR RAMP")

	var stage_names: Array = ["CHERRY RED (0-30%)", "ORANGE (30-60%)", "YELLOW HDR (60-80%)", "WHITE HOT (80-100%)"]
	var color_keys: Array = ["color_1", "color_2", "color_3", "color_4"]
	for i in 4:
		var color_arr: Array = _fire_values.get(color_keys[i], FIRE_DEFAULTS[color_keys[i]])
		var col := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]))
		# Clamp for display (HDR values > 1.0 clip in picker)
		var display_col := Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0))
		var color_row := HBoxContainer.new()
		color_row.add_theme_constant_override("separation", 8)
		controls.add_child(color_row)
		var stage_lbl := Label.new()
		stage_lbl.text = stage_names[i]
		stage_lbl.custom_minimum_size.x = 180
		ThemeManager.apply_text_glow(stage_lbl, "body")
		color_row.add_child(stage_lbl)
		var color_btn := ColorPickerButton.new()
		color_btn.color = display_col
		color_btn.custom_minimum_size = Vector2(40, 28)
		color_row.add_child(color_btn)
		_fire_color_btns.append(color_btn)
		# HDR multiplier slider for this stage
		var hdr_slider := HSlider.new()
		hdr_slider.min_value = 0.1
		hdr_slider.max_value = 5.0
		hdr_slider.step = 0.05
		hdr_slider.value = maxf(col.r, maxf(col.g, col.b))
		hdr_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_row.add_child(hdr_slider)
		var idx: int = i
		var key: String = color_keys[i]
		color_btn.color_changed.connect(func(new_col: Color) -> void:
			_on_fire_color_changed(idx, key, new_col, -1.0)
		)
		hdr_slider.value_changed.connect(func(val: float) -> void:
			var btn_col: Color = _fire_color_btns[idx].color
			_on_fire_color_changed(idx, key, btn_col, val)
		)

	# ── Reset defaults ──
	controls.add_child(HSeparator.new())
	var defaults_btn := Button.new()
	defaults_btn.text = "RESET TO DEFAULTS"
	defaults_btn.pressed.connect(_on_fire_reset_defaults)
	controls.add_child(defaults_btn)


func _apply_chrome_defaults(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("base_color", Vector4(0.02, 0.02, 0.03, 1.0))
	mat.set_shader_parameter("chrome_top_brightness", 0.3)
	mat.set_shader_parameter("chrome_base_brightness", 0.15)
	mat.set_shader_parameter("highlight_intensity", 0.06)
	mat.set_shader_parameter("edge_brightness", 0.02)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_text_glow(lbl, "header")
	parent.add_child(lbl)


func _add_tuning_slider(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, step_val: float, current: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 60
	ThemeManager.apply_text_glow(lbl, "body")
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % current
	val_lbl.custom_minimum_size.x = 40
	ThemeManager.apply_text_glow(val_lbl, "body")
	row.add_child(val_lbl)
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%.2f" % val
	)
	return slider


func _on_fire_intensity_changed(val: float) -> void:
	_fire_intensity = val
	_fire_intensity_label.text = "%d%%" % int(val * 100.0)
	_apply_fire_heat()


func _on_fire_play_pause() -> void:
	_fire_playing = not _fire_playing
	_update_fire_play_btn()


func _update_fire_play_btn() -> void:
	if _fire_play_btn:
		_fire_play_btn.text = "\u23f8 PAUSE" if _fire_playing else "\u25b6 PLAY"


func _on_fire_reset() -> void:
	_fire_playing = false
	_fire_intensity = 0.0
	_fire_time = 0.0
	_fire_intensity_slider.value = 0.0
	_fire_intensity_label.text = "0%"
	_update_fire_play_btn()
	_apply_fire_heat()
	_clear_fire_particles()


func _on_fire_reset_defaults() -> void:
	_fire_values = FIRE_DEFAULTS.duplicate(true)
	_save_fire_values()
	# Update sliders
	_fire_smoke_slider.value = float(FIRE_DEFAULTS["smoke_rate"])
	_fire_spark_slider.value = float(FIRE_DEFAULTS["spark_rate"])
	_fire_ramp_slider.value = float(FIRE_DEFAULTS["ramp_speed"])
	_fire_flicker_slider.value = float(FIRE_DEFAULTS["flicker_amount"])
	# Update color pickers
	var color_keys: Array = ["color_1", "color_2", "color_3", "color_4"]
	for i in 4:
		var arr: Array = FIRE_DEFAULTS[color_keys[i]]
		_fire_color_btns[i].color = Color(minf(float(arr[0]), 1.0), minf(float(arr[1]), 1.0), minf(float(arr[2]), 1.0))
	_apply_fire_colors_to_shaders()


func _on_fire_color_changed(stage_idx: int, key: String, picker_color: Color, hdr_override: float) -> void:
	# Reconstruct HDR color: use picker hue/sat but allow brightness > 1.0
	var current_arr: Array = _fire_values.get(key, FIRE_DEFAULTS[key])
	var old_max: float = maxf(float(current_arr[0]), maxf(float(current_arr[1]), float(current_arr[2])))
	var scale: float = hdr_override if hdr_override > 0.0 else maxf(old_max, 0.1)
	# Normalize picker color and scale
	var max_comp: float = maxf(picker_color.r, maxf(picker_color.g, picker_color.b))
	if max_comp > 0.001:
		var r: float = (picker_color.r / max_comp) * scale
		var g: float = (picker_color.g / max_comp) * scale
		var b: float = (picker_color.b / max_comp) * scale
		_fire_values[key] = [r, g, b]
	else:
		_fire_values[key] = [0.0, 0.0, 0.0]
	_save_fire_values()
	_apply_fire_colors_to_shaders()


func _apply_fire_colors_to_shaders() -> void:
	var c1: Array = _fire_values.get("color_1", FIRE_DEFAULTS["color_1"])
	var c2: Array = _fire_values.get("color_2", FIRE_DEFAULTS["color_2"])
	var c3: Array = _fire_values.get("color_3", FIRE_DEFAULTS["color_3"])
	var c4: Array = _fire_values.get("color_4", FIRE_DEFAULTS["color_4"])
	for mat in _fire_chrome_mats:
		if is_instance_valid(mat):
			var m: ShaderMaterial = mat as ShaderMaterial
			m.set_shader_parameter("heat_color_1", Vector3(float(c1[0]), float(c1[1]), float(c1[2])))
			m.set_shader_parameter("heat_color_2", Vector3(float(c2[0]), float(c2[1]), float(c2[2])))
			m.set_shader_parameter("heat_color_3", Vector3(float(c3[0]), float(c3[1]), float(c3[2])))
			m.set_shader_parameter("heat_color_4", Vector3(float(c4[0]), float(c4[1]), float(c4[2])))


func _apply_fire_heat() -> void:
	var flicker_amt: float = float(_fire_values.get("flicker_amount", FIRE_DEFAULTS["flicker_amount"]))
	var flicker: float = 0.0
	if _fire_intensity > 0.5:
		var f: float = (_fire_intensity - 0.5) * flicker_amt
		flicker = sin(_fire_time * 13.7) * cos(_fire_time * 7.3) * f
	var h: float = clampf(_fire_intensity + flicker, 0.0, 1.0)
	for mat in _fire_chrome_mats:
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter("heat_intensity", h)


func _process_fire_audition(delta: float) -> void:
	_fire_time += delta

	# Auto-play: ramp intensity 0 → 1 then hold
	if _fire_playing:
		var speed: float = _fire_speed_slider.value if _fire_speed_slider else 1.0
		var ramp: float = float(_fire_values.get("ramp_speed", FIRE_DEFAULTS["ramp_speed"]))
		_fire_intensity += ramp * speed * delta
		if _fire_intensity >= 1.0:
			_fire_intensity = 1.0
			_fire_playing = false
			_update_fire_play_btn()
		_fire_intensity_slider.set_value_no_signal(_fire_intensity)
		_fire_intensity_label.text = "%d%%" % int(_fire_intensity * 100.0)

	_apply_fire_heat()

	# Spawn smoke
	if _fire_intensity > 0.1 and _fire_preview_container:
		var smoke_rate: float = float(_fire_values.get("smoke_rate", FIRE_DEFAULTS["smoke_rate"]))
		var rate: float = smoke_rate * _fire_intensity * _fire_intensity
		_fire_smoke_accum += rate * delta
		while _fire_smoke_accum >= 1.0:
			_fire_smoke_accum -= 1.0
			_spawn_preview_smoke()

	# Spawn sparks
	if _fire_intensity > 0.4 and _fire_preview_container:
		var spark_rate: float = float(_fire_values.get("spark_rate", FIRE_DEFAULTS["spark_rate"]))
		var factor: float = (_fire_intensity - 0.4) / 0.6
		var rate: float = spark_rate * factor * factor
		_fire_spark_accum += rate * delta
		while _fire_spark_accum >= 1.0:
			_fire_spark_accum -= 1.0
			_spawn_preview_spark()

	# Update particles
	_update_preview_smoke(delta)
	_update_preview_sparks(delta)


func _spawn_preview_smoke() -> void:
	var puff := _PreviewSmokePuff.new()
	# Pick spawn location on a panel edge
	var roll: float = randf()
	if roll < 0.3:
		puff.position = Vector2(randf_range(0.0, 40.0), randf_range(50.0, 600.0))
	elif roll < 0.6:
		puff.position = Vector2(randf_range(860.0, 900.0), randf_range(50.0, 600.0))
	else:
		puff.position = Vector2(randf_range(100.0, 800.0), 640.0 + randf_range(0.0, 15.0))
	puff.velocity = Vector2(randf_range(-15.0, 15.0), randf_range(-60.0, -30.0))
	puff.lifetime = randf_range(1.2, 2.5)
	puff.max_lifetime = puff.lifetime
	puff.base_size = randf_range(6.0, 16.0) * (0.5 + _fire_intensity * 0.5)
	puff.base_alpha = randf_range(0.15, 0.35) * minf(_fire_intensity * 2.0, 1.0)
	_fire_particle_container.add_child(puff)
	_fire_smoke_particles.append(puff)


func _spawn_preview_spark() -> void:
	var spark := _PreviewSpark.new()
	var roll: float = randf()
	if roll < 0.35:
		spark.position = Vector2(40.0 + randf_range(-3.0, 3.0), randf_range(80.0, 580.0))
	elif roll < 0.7:
		spark.position = Vector2(860.0 + randf_range(-3.0, 3.0), randf_range(80.0, 580.0))
	else:
		spark.position = Vector2(randf_range(80.0, 820.0), 640.0 + randf_range(-3.0, 3.0))
	var angle: float = randf_range(-PI * 0.8, -PI * 0.2)
	var speed: float = randf_range(80.0, 250.0)
	spark.velocity = Vector2(cos(angle), sin(angle)) * speed
	spark.lifetime = randf_range(0.3, 0.8)
	spark.max_lifetime = spark.lifetime
	spark.gravity = 200.0
	spark.base_color = Color(1.0, randf_range(0.4, 0.9), randf_range(0.0, 0.2))
	spark.hdr_mult = randf_range(2.0, 4.0)
	_fire_particle_container.add_child(spark)
	_fire_spark_particles.append(spark)


func _update_preview_smoke(delta: float) -> void:
	var i: int = _fire_smoke_particles.size() - 1
	while i >= 0:
		var puff: _PreviewSmokePuff = _fire_smoke_particles[i]
		puff.lifetime -= delta
		if puff.lifetime <= 0.0:
			puff.queue_free()
			_fire_smoke_particles.remove_at(i)
		else:
			puff.position += puff.velocity * delta
			puff.velocity.x += randf_range(-20.0, 20.0) * delta
			puff.velocity.y -= 5.0 * delta
			puff.queue_redraw()
		i -= 1


func _update_preview_sparks(delta: float) -> void:
	var i: int = _fire_spark_particles.size() - 1
	while i >= 0:
		var spark: _PreviewSpark = _fire_spark_particles[i]
		spark.lifetime -= delta
		if spark.lifetime <= 0.0:
			spark.queue_free()
			_fire_spark_particles.remove_at(i)
		else:
			spark.velocity.y += spark.gravity * delta
			spark.position += spark.velocity * delta
			spark.queue_redraw()
		i -= 1


func _clear_fire_particles() -> void:
	for p in _fire_smoke_particles:
		if is_instance_valid(p):
			p.queue_free()
	_fire_smoke_particles.clear()
	for p in _fire_spark_particles:
		if is_instance_valid(p):
			p.queue_free()
	_fire_spark_particles.clear()


# ── Warning slab builder (unchanged) ─────────────────────────────────

func _build_slab(index: int, parent: HFlowContainer) -> void:
	var warning: Dictionary = WARNINGS[index]
	var warning_id: String = str(warning["id"])
	var warning_label: String = str(warning["label"])
	var default_color: Color = warning["color"]
	var default_hdr: float = float(warning["hdr"])

	var current_color: Color = _get_warning_color(warning_id, default_color)
	var current_hdr: float = _get_warning_hdr(warning_id, default_hdr)

	var slab_vbox := VBoxContainer.new()
	slab_vbox.add_theme_constant_override("separation", 4)
	parent.add_child(slab_vbox)

	# Viewport with etch grid
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(SLAB_WIDTH, SLAB_HEIGHT)
	vpc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slab_vbox.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(SLAB_WIDTH, SLAB_HEIGHT)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var etch_shader: Shader = load("res://assets/shaders/bg_synthwave_pulse.gdshader") as Shader
	if etch_shader:
		var etch_rect := ColorRect.new()
		etch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		etch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var etch_mat := ShaderMaterial.new()
		etch_mat.shader = etch_shader
		etch_rect.material = etch_mat
		vp.add_child(etch_rect)

	# Warning box
	var live_preset: Dictionary = BASE_STYLE.duplicate(true)
	live_preset["color"] = current_color
	live_preset["hdr"] = current_hdr

	var box := _WarningBoxDraw.new()
	box.preset = live_preset
	box.box_size = Vector2(BOX_W, BOX_H)
	box.position = Vector2((SLAB_WIDTH - BOX_W) * 0.5, (SLAB_HEIGHT - BOX_H) * 0.5)
	box.size = Vector2(BOX_W, BOX_H)
	vp.add_child(box)

	# Warning text label
	var warn_label := Label.new()
	warn_label.text = warning_label
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warn_label.size = Vector2(BOX_W, BOX_H)
	warn_label.position = box.position
	warn_label.modulate = Color(current_hdr, current_hdr, current_hdr, 1.0)
	warn_label.add_theme_color_override("font_color", current_color)
	warn_label.add_theme_font_size_override("font_size", 24)
	var hdr_font: Font = ThemeManager.get_font("font_header")
	if hdr_font:
		warn_label.add_theme_font_override("font", hdr_font)
	var text_shader: Shader = load("res://assets/shaders/crt_scanline_text.gdshader") as Shader
	if text_shader:
		var text_mat := ShaderMaterial.new()
		text_mat.shader = text_shader
		warn_label.material = text_mat
	warn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(warn_label)

	# Controls row — color picker + HDR slider
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.custom_minimum_size.x = SLAB_WIDTH
	slab_vbox.add_child(controls)

	# Color picker
	var color_btn := ColorPickerButton.new()
	color_btn.color = current_color
	color_btn.custom_minimum_size = Vector2(40, 24)
	controls.add_child(color_btn)

	# HDR label
	var hdr_label := Label.new()
	hdr_label.text = "HDR"
	hdr_label.custom_minimum_size.x = 28
	ThemeManager.apply_text_glow(hdr_label, "body")
	controls.add_child(hdr_label)

	# HDR slider
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 5.0
	slider.step = 0.1
	slider.value = current_hdr
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%.1f" % current_hdr
	val_label.custom_minimum_size.x = 28
	ThemeManager.apply_text_glow(val_label, "body")
	controls.add_child(val_label)

	var slab_idx: int = _slab_data.size()
	_slab_data.append({
		"box": box,
		"warn_label": warn_label,
		"preset": live_preset,
		"val_label": val_label,
		"warning_id": warning_id,
	})

	slider.value_changed.connect(func(val: float) -> void:
		var entry: Dictionary = _slab_data[slab_idx]
		entry["preset"]["hdr"] = val
		var lbl: Label = entry["warn_label"]
		lbl.modulate = Color(val, val, val, 1.0)
		var vlbl: Label = entry["val_label"]
		vlbl.text = "%.1f" % val
		_update_saved(str(entry["warning_id"]), val, -1.0, -1.0, -1.0)
	)

	color_btn.color_changed.connect(func(col: Color) -> void:
		var entry: Dictionary = _slab_data[slab_idx]
		entry["preset"]["color"] = col
		var lbl: Label = entry["warn_label"]
		lbl.add_theme_color_override("font_color", col)
		_update_saved(str(entry["warning_id"]), -1.0, col.r, col.g, col.b)
	)


func _update_saved(warning_id: String, hdr: float, r: float, g: float, b: float) -> void:
	if not _saved_values.has(warning_id):
		# Find default from WARNINGS
		var default_color := Color.WHITE
		var default_hdr: float = 2.8
		for w in WARNINGS:
			if str(w["id"]) == warning_id:
				default_color = w["color"]
				default_hdr = float(w["hdr"])
				break
		_saved_values[warning_id] = {
			"hdr": default_hdr,
			"r": default_color.r,
			"g": default_color.g,
			"b": default_color.b,
		}
	var d: Dictionary = _saved_values[warning_id]
	if hdr >= 0.0:
		d["hdr"] = hdr
	if r >= 0.0:
		d["r"] = r
	if g >= 0.0:
		d["g"] = g
	if b >= 0.0:
		d["b"] = b
	_save_values()


func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _tab_warnings_btn:
		ThemeManager.apply_button_style(_tab_warnings_btn)
	if _tab_fire_btn:
		ThemeManager.apply_button_style(_tab_fire_btn)
	if _fire_play_btn:
		ThemeManager.apply_button_style(_fire_play_btn)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	# Style all buttons in fire controls
	for child in _fire_content.get_children():
		_apply_theme_recursive(child)


func _apply_theme_recursive(node: Node) -> void:
	if node is Button and node != _tab_warnings_btn and node != _tab_fire_btn and node != _back_button:
		ThemeManager.apply_button_style(node as Button)
	for child in node.get_children():
		_apply_theme_recursive(child)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_back() -> void:
	_fire_playing = false
	_clear_fire_particles()
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


# ── Procedural warning box — _draw() based, same pipeline as ships ──────

class _WarningBoxDraw extends Control:
	var preset: Dictionary = {}
	var box_size: Vector2 = Vector2(220, 70)
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if preset.is_empty():
			return
		var col: Color = preset.get("color", Color.RED)
		var border_w: float = float(preset["border_width"])
		var glow_layers: int = int(preset["glow_layers"])
		var glow_spread: float = float(preset["glow_spread"])
		var hdr: float = float(preset.get("hdr", 2.5))
		var scan_spacing: float = float(preset["scanline_spacing"])
		var scan_alpha: float = float(preset["scanline_alpha"])
		var scan_scroll: float = float(preset["scanline_scroll"])
		var flicker_spd: float = float(preset["flicker_speed"])
		var flicker_amt: float = float(preset["flicker_amount"])
		var has_corners: bool = bool(preset["corner_marks"])
		var has_double: bool = bool(preset["double_border"])

		var flicker: float = 1.0 - flicker_amt * (0.5 + 0.5 * sin(_time * flicker_spd + sin(_time * 2.3) * 3.0))

		var w: float = box_size.x
		var h: float = box_size.y
		var rect := Rect2(Vector2.ZERO, box_size)

		# Glow layers
		for gi in range(glow_layers, 0, -1):
			var t: float = float(gi) / float(glow_layers)
			var expand: float = t * glow_spread * float(glow_layers)
			var glow_alpha: float = (1.0 - t) * 0.15 * flicker
			var glow_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, glow_alpha)
			var glow_rect := Rect2(
				Vector2(-expand, -expand),
				Vector2(w + expand * 2.0, h + expand * 2.0)
			)
			draw_rect(glow_rect, glow_col, false, border_w + expand * 0.5)

		# Main border
		var border_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, 0.9 * flicker)
		draw_rect(rect, border_col, false, border_w)

		# Double border
		if has_double:
			var inset: float = border_w * 2.5 + 2.0
			var inner_rect := Rect2(
				Vector2(inset, inset),
				Vector2(w - inset * 2.0, h - inset * 2.0)
			)
			var inner_col := Color(col.r * hdr * 0.7, col.g * hdr * 0.7, col.b * hdr * 0.7, 0.6 * flicker)
			draw_rect(inner_rect, inner_col, false, maxf(border_w * 0.5, 1.0))

		# Corner marks
		if has_corners:
			var cm_len: float = 12.0
			var cm_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, 0.7 * flicker)
			var cm_w: float = maxf(border_w * 0.8, 1.0)
			var cm_off: float = -4.0
			draw_line(Vector2(cm_off, cm_off), Vector2(cm_off + cm_len, cm_off), cm_col, cm_w)
			draw_line(Vector2(cm_off, cm_off), Vector2(cm_off, cm_off + cm_len), cm_col, cm_w)
			draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off - cm_len, cm_off), cm_col, cm_w)
			draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off, cm_off + cm_len), cm_col, cm_w)
			draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off + cm_len, h - cm_off), cm_col, cm_w)
			draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off, h - cm_off - cm_len), cm_col, cm_w)
			draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off - cm_len, h - cm_off), cm_col, cm_w)
			draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off, h - cm_off - cm_len), cm_col, cm_w)

		# Scanlines
		var scan_col := Color(col.r * hdr * 0.5, col.g * hdr * 0.5, col.b * hdr * 0.5, scan_alpha * flicker)
		var scroll_offset: float = fmod(_time * scan_scroll, scan_spacing)
		var y: float = scroll_offset
		while y < h:
			draw_line(Vector2(border_w, y), Vector2(w - border_w, y), scan_col, 1.0)
			y += scan_spacing


# ── Fire preview particles — same visual approach as hud.gd ──────────
# Uses same _draw() technique. Shader (chrome_panel.gdshader) is shared.

class _PreviewSmokePuff extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var lifetime: float = 2.0
	var max_lifetime: float = 2.0
	var base_size: float = 12.0
	var base_alpha: float = 0.25

	func _draw() -> void:
		var t: float = 1.0 - (lifetime / maxf(max_lifetime, 0.001))
		var current_size: float = base_size * (1.0 + t * 2.5)
		var alpha: float = base_alpha * (1.0 - t * t)
		var gray: float = 0.4 + t * 0.3
		var col := Color(gray, gray * 0.95, gray * 0.9, alpha)
		draw_circle(Vector2.ZERO, current_size, Color(col.r, col.g, col.b, alpha * 0.3))
		draw_circle(Vector2.ZERO, current_size * 0.7, Color(col.r, col.g, col.b, alpha * 0.5))
		draw_circle(Vector2.ZERO, current_size * 0.4, Color(col.r, col.g, col.b, alpha * 0.7))


class _PreviewSpark extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var lifetime: float = 0.5
	var max_lifetime: float = 0.5
	var gravity: float = 200.0
	var base_color: Color = Color(1.0, 0.6, 0.1)
	var hdr_mult: float = 3.0

	func _draw() -> void:
		var t: float = 1.0 - (lifetime / maxf(max_lifetime, 0.001))
		var alpha: float = 1.0 - t * t
		var col := Color(
			base_color.r * hdr_mult,
			base_color.g * hdr_mult,
			base_color.b * hdr_mult,
			alpha
		)
		draw_circle(Vector2.ZERO, 2.0, col)
		draw_circle(Vector2.ZERO, 5.0, Color(col.r, col.g, col.b, alpha * 0.3))
		var trail_len: float = minf(velocity.length() * 0.03, 12.0)
		var trail_dir: Vector2 = -velocity.normalized() * trail_len
		draw_line(Vector2.ZERO, trail_dir, Color(col.r * 0.7, col.g * 0.7, col.b * 0.5, alpha * 0.5), 1.5)
