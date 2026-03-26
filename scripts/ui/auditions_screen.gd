extends Control
## Auditions screen — warning box variants for different game events.
## All use preset 9 style (corner marks, chromatic) with per-warning colors.
## HDR slider + color picker per warning, values persist to user://settings/.

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

const SAVE_PATH := "user://settings/warning_auditions.json"

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


func _ready() -> void:
	_load_saved()
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


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


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	var main_scroll := ScrollContainer.new()
	main_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_scroll.offset_left = 20
	main_scroll.offset_top = 20
	main_scroll.offset_right = -20
	main_scroll.offset_bottom = -20
	add_child(main_scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_scroll.add_child(main_vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS — Warning Types"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(flow)

	for i in WARNINGS.size():
		_build_slab(i, flow)

	_setup_vhs_overlay()


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
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)


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
