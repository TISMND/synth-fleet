extends Control
## Auditions screen — tabbed: Warning Types + Fire Effect audition.
## Warning tab: preset 9 style boxes with per-warning color/HDR.
## Fire tab: 3-stage heat effect preview with per-stage tuning subtabs.

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
	{"id": "heat", "label": "HEAT", "color": Color(1.0, 0.4, 0.1), "hdr": 2.8},
	{"id": "fire", "label": "FIRE", "color": Color(1.0, 0.2, 0.0), "hdr": 3.0},
	{"id": "low_power", "label": "LOW POWER", "color": Color(0.7, 0.3, 1.0), "hdr": 2.8},
	{"id": "overdraw", "label": "OVERDRAW", "color": Color(1.0, 0.15, 0.1), "hdr": 3.2},
	{"id": "shields_low", "label": "SHIELDS LOW", "color": Color(1.0, 0.4, 0.1), "hdr": 2.8},
	{"id": "shield_break", "label": "SHIELD BREAK", "color": Color(1.0, 0.15, 0.1), "hdr": 3.0},
	{"id": "hull_damaged", "label": "HULL DAMAGED", "color": Color(1.0, 0.4, 0.1), "hdr": 2.5},
	{"id": "hull_critical", "label": "HULL CRITICAL", "color": Color(1.0, 0.15, 0.1), "hdr": 3.2},
]

# ── Fire effect audition state ───────────────────────────────────────
var _fire_playing: bool = false
var _fire_intensity: float = 0.0
var _fire_time: float = 0.0
var _fire_chrome_mats: Array = []
var _fire_intensity_slider: HSlider
var _fire_intensity_label: Label
var _fire_play_btn: Button
var _fire_speed_slider: HSlider
var _fire_transition_slider: HSlider
var _fire_particle_container: Node2D
var _fire_smoke_particles: Array = []
var _fire_spark_particles: Array = []
var _fire_smoke_accum: float = 0.0
var _fire_spark_accum: float = 0.0
# Stage subtabs
var _fire_stage_btns: Array = []  # 3 Button nodes
var _fire_stage_panels: Array = []  # 3 Control nodes
var _fire_active_stage: int = 0
# Preview panels
var _fire_preview_left: ColorRect
var _fire_preview_right: ColorRect
var _fire_preview_bottom: ColorRect
var _fire_preview_container: Control

const STAGE_NAMES: Array = ["WARM", "HOT"]
const NUM_STAGES: int = 2

# Defaults for 2-stage fire tuning
const FIRE_DEFAULTS: Dictionary = {
	"speed": 1.0,
	"transition_speed": 0.4,
	"stage_1": {
		"color": [0.8, 0.1, 0.0],
		"hdr": 1.5,
		"flicker": 0.02,
		"smoke_rate": 4.0,
		"spark_rate": 0.0,
	},
	"stage_2": {
		"color": [1.0, 0.85, 0.6],
		"hdr": 3.0,
		"flicker": 0.08,
		"smoke_rate": 12.0,
		"spark_rate": 16.0,
	},
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


# ── Warning persistence ──────────────────────────────────────────────

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


func _get_warning_color(warning_id: String, default_color: Color) -> Color:
	if _saved_values.has(warning_id):
		var d: Dictionary = _saved_values[warning_id]
		return Color(float(d.get("r", default_color.r)), float(d.get("g", default_color.g)), float(d.get("b", default_color.b)))
	return default_color


func _get_warning_hdr(warning_id: String, default_hdr: float) -> float:
	if _saved_values.has(warning_id):
		return float(_saved_values[warning_id].get("hdr", default_hdr))
	return default_hdr


# ── Fire persistence ─────────────────────────────────────────────────

func _load_fire_saved() -> void:
	_fire_values = _deep_copy_defaults()
	if not FileAccess.file_exists(FIRE_SAVE_PATH):
		return
	var file := FileAccess.open(FIRE_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		# Merge top-level keys
		if data.has("speed"):
			_fire_values["speed"] = float(data["speed"])
		if data.has("transition_speed"):
			_fire_values["transition_speed"] = float(data["transition_speed"])
		# Merge per-stage dicts
		for stage_key in ["stage_1", "stage_2"]:
			if data.has(stage_key) and data[stage_key] is Dictionary:
				var saved_stage: Dictionary = data[stage_key]
				var target: Dictionary = _fire_values[stage_key]
				for k in saved_stage:
					target[k] = saved_stage[k]


func _deep_copy_defaults() -> Dictionary:
	var result: Dictionary = {}
	result["speed"] = FIRE_DEFAULTS["speed"]
	result["transition_speed"] = FIRE_DEFAULTS["transition_speed"]
	for stage_key in ["stage_1", "stage_2"]:
		var src: Dictionary = FIRE_DEFAULTS[stage_key]
		var copy: Dictionary = {}
		for k in src:
			var val = src[k]
			if val is Array:
				copy[k] = [val[0], val[1], val[2]]
			else:
				copy[k] = val
		result[stage_key] = copy
	return result


func _save_fire_values() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings/")
	var file := FileAccess.open(FIRE_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_fire_values, "\t"))


# ── Helpers for reading stage values ─────────────────────────────────

func _stage_key(stage: int) -> String:
	return "stage_" + str(stage + 1)


func _get_stage(stage: int) -> Dictionary:
	return _fire_values.get(_stage_key(stage), FIRE_DEFAULTS[_stage_key(stage)])


func _get_stage_float(stage: int, key: String) -> float:
	var s: Dictionary = _get_stage(stage)
	var def_stage: Dictionary = FIRE_DEFAULTS[_stage_key(stage)]
	return float(s.get(key, def_stage.get(key, 0.0)))


func _get_stage_color(stage: int) -> Color:
	var s: Dictionary = _get_stage(stage)
	var arr: Array = s.get("color", FIRE_DEFAULTS[_stage_key(stage)]["color"])
	return Color(float(arr[0]), float(arr[1]), float(arr[2]))


func _set_stage_value(stage: int, key: String, value) -> void:
	var sk: String = _stage_key(stage)
	if not _fire_values.has(sk):
		_fire_values[sk] = _deep_copy_defaults()[sk]
	_fire_values[sk][key] = value
	_save_fire_values()


# ── Interpolation helpers for current intensity ──────────────────────

func _get_interpolated_float(key: String) -> float:
	## Get a per-stage float value interpolated by current _fire_intensity.
	var h: float = _fire_intensity
	if h <= 0.0:
		return 0.0
	if h < 0.5:
		return _get_stage_float(0, key) * (h / 0.5)
	var t: float = (h - 0.5) / 0.5
	return lerpf(_get_stage_float(0, key), _get_stage_float(1, key), t)


# ── Build UI ─────────────────────────────────────────────────────────

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

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

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

	# ── Left: preview area ──
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(860, 0)
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

	var chrome_shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader

	_fire_preview_left = _make_chrome_panel(chrome_shader, Vector2(0, 0), Vector2(40, 640), 0.5)
	_fire_preview_right = _make_chrome_panel(chrome_shader, Vector2(820, 0), Vector2(40, 640), 0.5)
	_fire_preview_bottom = _make_chrome_panel(chrome_shader, Vector2(0, 640), Vector2(860, 60), -1.0)

	_fire_particle_container = Node2D.new()
	_fire_particle_container.z_index = 5
	_fire_preview_container.add_child(_fire_particle_container)

	_apply_fire_colors_to_shaders()

	# ── Right: controls ──
	var controls_scroll := ScrollContainer.new()
	controls_scroll.custom_minimum_size = Vector2(420, 0)
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hsplit.add_child(controls_scroll)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls)

	# ── Master: intensity scrubber ──
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

	# ── Transport ──
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

	# ── Master speed + transition ──
	controls.add_child(HSeparator.new())
	_add_section_label(controls, "MASTER")
	_fire_speed_slider = _add_slider_row(controls, "SPEED", 0.05, 3.0, 0.05,
		float(_fire_values.get("speed", FIRE_DEFAULTS["speed"])))
	_fire_speed_slider.value_changed.connect(func(val: float) -> void:
		_fire_values["speed"] = val
		_save_fire_values()
	)
	_fire_transition_slider = _add_slider_row(controls, "TRANSITION", 0.05, 2.0, 0.05,
		float(_fire_values.get("transition_speed", FIRE_DEFAULTS["transition_speed"])))
	_fire_transition_slider.value_changed.connect(func(val: float) -> void:
		_fire_values["transition_speed"] = val
		_save_fire_values()
	)

	# ── Stage subtabs ──
	controls.add_child(HSeparator.new())
	var stage_tab_row := HBoxContainer.new()
	stage_tab_row.add_theme_constant_override("separation", 6)
	controls.add_child(stage_tab_row)
	for i in NUM_STAGES:
		var btn := Button.new()
		btn.text = STAGE_NAMES[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		var idx: int = i
		btn.pressed.connect(func() -> void: _show_fire_stage(idx))
		stage_tab_row.add_child(btn)
		_fire_stage_btns.append(btn)

	# Build 3 stage panels (only one visible at a time)
	for i in NUM_STAGES:
		var panel := VBoxContainer.new()
		panel.add_theme_constant_override("separation", 8)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.visible = (i == 0)
		controls.add_child(panel)
		_fire_stage_panels.append(panel)
		_build_stage_panel(i, panel)

	# ── Reset defaults ──
	controls.add_child(HSeparator.new())
	var defaults_btn := Button.new()
	defaults_btn.text = "RESET ALL TO DEFAULTS"
	defaults_btn.pressed.connect(_on_fire_reset_defaults)
	controls.add_child(defaults_btn)


func _make_chrome_panel(shader: Shader, pos: Vector2, panel_size: Vector2, divider: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.position = pos
	rect.size = panel_size
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("base_color", Vector4(0.02, 0.02, 0.03, 1.0))
		mat.set_shader_parameter("chrome_top_brightness", 0.3)
		mat.set_shader_parameter("chrome_base_brightness", 0.15)
		mat.set_shader_parameter("highlight_intensity", 0.06)
		mat.set_shader_parameter("edge_brightness", 0.02)
		mat.set_shader_parameter("divider_y", divider)
		rect.material = mat
		_fire_chrome_mats.append(mat)
	_fire_preview_container.add_child(rect)
	return rect


func _build_stage_panel(stage: int, parent: VBoxContainer) -> void:
	var sk: String = _stage_key(stage)

	# Color row
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	parent.add_child(color_row)
	var color_lbl := Label.new()
	color_lbl.text = "COLOR"
	color_lbl.custom_minimum_size.x = 70
	ThemeManager.apply_text_glow(color_lbl, "body")
	color_row.add_child(color_lbl)
	var color_btn := ColorPickerButton.new()
	var init_col: Color = _get_stage_color(stage)
	color_btn.color = Color(minf(init_col.r, 1.0), minf(init_col.g, 1.0), minf(init_col.b, 1.0))
	color_btn.custom_minimum_size = Vector2(50, 28)
	color_row.add_child(color_btn)
	var idx: int = stage
	color_btn.color_changed.connect(func(col: Color) -> void:
		_on_stage_color_changed(idx, col)
	)

	# HDR
	var hdr_slider: HSlider = _add_slider_row(parent, "HDR", 0.1, 5.0, 0.05,
		_get_stage_float(stage, "hdr"))
	hdr_slider.value_changed.connect(func(val: float) -> void:
		_set_stage_value(idx, "hdr", val)
		_apply_fire_colors_to_shaders()
	)

	# Flicker
	var flicker_slider: HSlider = _add_slider_row(parent, "FLICKER", 0.0, 0.3, 0.005,
		_get_stage_float(stage, "flicker"))
	flicker_slider.value_changed.connect(func(val: float) -> void:
		_set_stage_value(idx, "flicker", val)
	)

	# Smoke rate
	var smoke_slider: HSlider = _add_slider_row(parent, "SMOKE", 0.0, 30.0, 0.5,
		_get_stage_float(stage, "smoke_rate"))
	smoke_slider.value_changed.connect(func(val: float) -> void:
		_set_stage_value(idx, "smoke_rate", val)
	)

	# Spark rate
	var spark_slider: HSlider = _add_slider_row(parent, "SPARKS", 0.0, 40.0, 0.5,
		_get_stage_float(stage, "spark_rate"))
	spark_slider.value_changed.connect(func(val: float) -> void:
		_set_stage_value(idx, "spark_rate", val)
	)


func _show_fire_stage(stage: int) -> void:
	_fire_active_stage = stage
	for i in NUM_STAGES:
		_fire_stage_btns[i].button_pressed = (i == stage)
		_fire_stage_panels[i].visible = (i == stage)


func _on_stage_color_changed(stage: int, picker_color: Color) -> void:
	var current_hdr: float = _get_stage_float(stage, "hdr")
	# Store the picker color directly — HDR multiplier is separate
	_set_stage_value(stage, "color", [picker_color.r, picker_color.g, picker_color.b])
	_apply_fire_colors_to_shaders()


func _apply_fire_colors_to_shaders() -> void:
	for i in NUM_STAGES:
		var col: Color = _get_stage_color(i)
		var hdr: float = _get_stage_float(i, "hdr")
		var uniform_name: String = "heat_color_" + str(i + 1)
		var hdr_name: String = "heat_hdr_" + str(i + 1)
		for mat in _fire_chrome_mats:
			if is_instance_valid(mat):
				var m: ShaderMaterial = mat as ShaderMaterial
				m.set_shader_parameter(uniform_name, Vector3(col.r, col.g, col.b))
				m.set_shader_parameter(hdr_name, hdr)


func _apply_fire_heat() -> void:
	var flicker: float = _get_interpolated_float("flicker")
	var f: float = 0.0
	if _fire_intensity > 0.1 and flicker > 0.0:
		f = sin(_fire_time * 13.7) * cos(_fire_time * 7.3) * flicker
	var h: float = clampf(_fire_intensity + f, 0.0, 1.0)
	for mat in _fire_chrome_mats:
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter("heat_intensity", h)


# ── Fire audition process ────────────────────────────────────────────

func _process_fire_audition(delta: float) -> void:
	_fire_time += delta

	if _fire_playing:
		var speed: float = float(_fire_values.get("speed", 1.0))
		var transition: float = float(_fire_values.get("transition_speed", 0.4))
		_fire_intensity += transition * speed * delta
		if _fire_intensity >= 1.0:
			_fire_intensity = 1.0
			_fire_playing = false
			_update_fire_play_btn()
		_fire_intensity_slider.set_value_no_signal(_fire_intensity)
		_fire_intensity_label.text = "%d%%" % int(_fire_intensity * 100.0)

	_apply_fire_heat()

	# Spawn smoke — interpolated rate from current stage
	if _fire_intensity > 0.05:
		var smoke_rate: float = _get_interpolated_float("smoke_rate")
		_fire_smoke_accum += smoke_rate * delta
		while _fire_smoke_accum >= 1.0:
			_fire_smoke_accum -= 1.0
			_spawn_preview_smoke()

	# Spawn sparks — interpolated rate
	if _fire_intensity > 0.1:
		var spark_rate: float = _get_interpolated_float("spark_rate")
		_fire_spark_accum += spark_rate * delta
		while _fire_spark_accum >= 1.0:
			_fire_spark_accum -= 1.0
			_spawn_preview_spark()

	_update_preview_smoke(delta)
	_update_preview_sparks(delta)


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
	_fire_values = _deep_copy_defaults()
	_save_fire_values()
	_apply_fire_colors_to_shaders()
	# Rebuild stage panels to reflect defaults
	for i in NUM_STAGES:
		var panel: VBoxContainer = _fire_stage_panels[i]
		for child in panel.get_children():
			child.queue_free()
		# Defer rebuild so freed children are gone
		var idx: int = i
		panel.call_deferred("_build_stage_deferred", idx)
	# Use call_deferred to rebuild after children are freed
	call_deferred("_rebuild_all_stage_panels")
	# Reset master sliders
	_fire_speed_slider.value = float(FIRE_DEFAULTS["speed"])
	_fire_transition_slider.value = float(FIRE_DEFAULTS["transition_speed"])


func _rebuild_all_stage_panels() -> void:
	for i in NUM_STAGES:
		var panel: VBoxContainer = _fire_stage_panels[i]
		_build_stage_panel(i, panel)
	_apply_theme_recursive(_fire_content)


# ── Particle spawning ────────────────────────────────────────────────

func _spawn_preview_smoke() -> void:
	var puff := _PreviewSmokePuff.new()
	var roll: float = randf()
	if roll < 0.3:
		puff.position = Vector2(randf_range(0.0, 40.0), randf_range(50.0, 600.0))
	elif roll < 0.6:
		puff.position = Vector2(randf_range(820.0, 860.0), randf_range(50.0, 600.0))
	else:
		puff.position = Vector2(randf_range(100.0, 760.0), 640.0 + randf_range(0.0, 15.0))
	puff.velocity = Vector2(randf_range(-15.0, 15.0), randf_range(-60.0, -30.0))
	puff.lifetime = randf_range(1.2, 2.5)
	puff.max_lifetime = puff.lifetime
	puff.base_size = randf_range(6.0, 16.0) * (0.3 + _fire_intensity * 0.7)
	puff.base_alpha = randf_range(0.15, 0.35) * minf(_fire_intensity * 2.0, 1.0)
	_fire_particle_container.add_child(puff)
	_fire_smoke_particles.append(puff)


func _spawn_preview_spark() -> void:
	var spark := _PreviewSpark.new()
	var roll: float = randf()
	if roll < 0.35:
		spark.position = Vector2(40.0 + randf_range(-3.0, 3.0), randf_range(80.0, 580.0))
	elif roll < 0.7:
		spark.position = Vector2(820.0 + randf_range(-3.0, 3.0), randf_range(80.0, 580.0))
	else:
		spark.position = Vector2(randf_range(80.0, 780.0), 640.0 + randf_range(-3.0, 3.0))
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


# ── UI helpers ───────────────────────────────────────────────────────

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_text_glow(lbl, "header")
	parent.add_child(lbl)


func _add_slider_row(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, step_val: float, current: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70
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

	var live_preset: Dictionary = BASE_STYLE.duplicate(true)
	live_preset["color"] = current_color
	live_preset["hdr"] = current_hdr

	var box := _WarningBoxDraw.new()
	box.preset = live_preset
	box.box_size = Vector2(BOX_W, BOX_H)
	box.position = Vector2((SLAB_WIDTH - BOX_W) * 0.5, (SLAB_HEIGHT - BOX_H) * 0.5)
	box.size = Vector2(BOX_W, BOX_H)
	vp.add_child(box)

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

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.custom_minimum_size.x = SLAB_WIDTH
	slab_vbox.add_child(controls)

	var color_btn := ColorPickerButton.new()
	color_btn.color = current_color
	color_btn.custom_minimum_size = Vector2(40, 24)
	controls.add_child(color_btn)

	var hdr_label := Label.new()
	hdr_label.text = "HDR"
	hdr_label.custom_minimum_size.x = 28
	ThemeManager.apply_text_glow(hdr_label, "body")
	controls.add_child(hdr_label)

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


# ── Theme ────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _tab_warnings_btn:
		ThemeManager.apply_button_style(_tab_warnings_btn)
	if _tab_fire_btn:
		ThemeManager.apply_button_style(_tab_fire_btn)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	if _fire_content:
		_apply_theme_recursive(_fire_content)


func _apply_theme_recursive(node: Node) -> void:
	if node is Button:
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


# ── Procedural warning box — _draw() based, same pipeline as ships ──

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

		var border_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, 0.9 * flicker)
		draw_rect(rect, border_col, false, border_w)

		if has_double:
			var inset: float = border_w * 2.5 + 2.0
			var inner_rect := Rect2(
				Vector2(inset, inset),
				Vector2(w - inset * 2.0, h - inset * 2.0)
			)
			var inner_col := Color(col.r * hdr * 0.7, col.g * hdr * 0.7, col.b * hdr * 0.7, 0.6 * flicker)
			draw_rect(inner_rect, inner_col, false, maxf(border_w * 0.5, 1.0))

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

		var scan_col := Color(col.r * hdr * 0.5, col.g * hdr * 0.5, col.b * hdr * 0.5, scan_alpha * flicker)
		var scroll_offset: float = fmod(_time * scan_scroll, scan_spacing)
		var y: float = scroll_offset
		while y < h:
			draw_line(Vector2(border_w, y), Vector2(w - border_w, y), scan_col, 1.0)
			y += scan_spacing


# ── Fire preview particles — same visual approach as hud.gd ──────────

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
		draw_circle(Vector2.ZERO, current_size, Color(gray, gray * 0.95, gray * 0.9, alpha * 0.3))
		draw_circle(Vector2.ZERO, current_size * 0.7, Color(gray, gray * 0.95, gray * 0.9, alpha * 0.5))
		draw_circle(Vector2.ZERO, current_size * 0.4, Color(gray, gray * 0.95, gray * 0.9, alpha * 0.7))


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
