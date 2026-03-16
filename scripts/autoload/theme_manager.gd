extends Node
## ThemeManager — centralized aesthetic theme with persistence + presets.
## All semantic colors, font sizes, glow/grid params in one place.
## Emits theme_changed when any value is modified.

signal theme_changed

const SETTINGS_PATH := "user://settings/aesthetic.json"
const PRESETS_PATH := "user://settings/aesthetic_presets.json"

# ── Color keys ──
var _colors: Dictionary = {
	"header": Color(0.4, 0.8, 1.0),
	"accent": Color(0.3, 1.0, 0.8),
	"positive": Color(0.3, 1.0, 0.5),
	"warning": Color(1.0, 0.3, 0.3),
	"dimmed": Color(0.5, 0.5, 0.6),
	"disabled": Color(0.5, 0.5, 0.5),
	"text": Color(0.85, 0.85, 0.9),
	"background": Color(0.02, 0.02, 0.06),
	"panel": Color(0.08, 0.08, 0.12),
	"bar_positive": Color(0.15, 0.7, 0.3),
	"bar_negative": Color(0.8, 0.15, 0.15),
}

# ── Float keys ──
var _floats: Dictionary = {
	"grid_spacing": 64.0,
	"grid_scroll_speed": 20.0,
	"grid_line_width": 1.0,
	"grid_inner_intensity": 0.0,
	"grid_aura_size": 4.0,
	"grid_aura_intensity": 0.6,
	"grid_bloom_size": 12.0,
	"grid_bloom_intensity": 0.2,
	"grid_smudge_blur": 0.0,
	"header_inner_intensity": 0.0,
	"header_aura_size": 0.0,
	"header_aura_intensity": 0.0,
	"header_bloom_size": 0.0,
	"header_bloom_intensity": 0.0,
	"header_smudge_blur": 0.0,
	"body_inner_intensity": 0.0,
	"body_aura_size": 0.0,
	"body_aura_intensity": 0.0,
	"body_bloom_size": 0.0,
	"body_bloom_intensity": 0.0,
	"body_smudge_blur": 0.0,
	"vhs_scanline_strength": 0.0,
	"vhs_scanline_spacing": 2.0,
	"vhs_chromatic_aberration": 0.0,
	"vhs_barrel_distortion": 0.0,
	"vhs_vignette_strength": 0.0,
	"vhs_noise_intensity": 0.0,
	"vhs_color_bleed": 0.0,
	"vhs_roll_speed": 0.0,
	"vhs_roll_strength": 0.0,
	"led_bar_enabled": 0.0,
	"led_segment_count": 20.0,
	"led_segment_gap": 0.015,
	"led_inner_intensity": 0.3,
	"led_aura_size": 0.02,
	"led_aura_intensity": 0.8,
	"led_bloom_size": 0.05,
	"led_bloom_intensity": 0.4,
	"led_smudge_blur": 0.008,
}

# ── Int keys (font sizes) ──
var _ints: Dictionary = {
	"font_size_header": 20,
	"font_size_title": 16,
	"font_size_section": 14,
	"font_size_body": 13,
}

# ── Font paths ──
var _font_paths: Dictionary = {
	"font_header": "res://assets/fonts/Orbitron.ttf",
	"font_body": "res://assets/fonts/ShareTechMono-Regular.ttf",
}

var _font_cache: Dictionary = {}

# ── Grid line color (separate since it's used in shader) ──
var _grid_line_color: Color = Color(0.15, 0.35, 0.6, 0.4)

# ── Built-in presets ──
const BUILTIN_PRESETS: Dictionary = {
	"Classic Synthwave": {
		"colors": {
			"header": "#66CCFF",
			"accent": "#4DFFCC",
			"positive": "#4DFF80",
			"warning": "#FF4D4D",
			"dimmed": "#808099",
			"disabled": "#808080",
			"text": "#D9D9E6",
			"background": "#050510",
			"panel": "#14141F",
			"bar_positive": "#26B34D",
			"bar_negative": "#CC2626",
		},
		"floats": {
			"grid_spacing": 64.0,
			"grid_scroll_speed": 20.0,
			"grid_line_width": 1.0,
			"grid_inner_intensity": 0.0,
			"grid_aura_size": 4.0,
			"grid_aura_intensity": 0.6,
			"grid_bloom_size": 12.0,
			"grid_bloom_intensity": 0.2,
			"grid_smudge_blur": 0.0,
			"header_inner_intensity": 0.0,
			"header_aura_size": 0.0,
			"header_aura_intensity": 0.0,
			"header_bloom_size": 0.0,
			"header_bloom_intensity": 0.0,
			"header_smudge_blur": 0.0,
			"body_inner_intensity": 0.0,
			"body_aura_size": 0.0,
			"body_aura_intensity": 0.0,
			"body_bloom_size": 0.0,
			"body_bloom_intensity": 0.0,
			"body_smudge_blur": 0.0,
			"vhs_scanline_strength": 0.0,
			"vhs_scanline_spacing": 2.0,
			"vhs_chromatic_aberration": 0.0,
			"vhs_barrel_distortion": 0.0,
			"vhs_vignette_strength": 0.0,
			"vhs_noise_intensity": 0.0,
			"vhs_color_bleed": 0.0,
			"vhs_roll_speed": 0.0,
			"vhs_roll_strength": 0.0,
			"led_bar_enabled": 0.0,
			"led_segment_count": 20.0,
			"led_segment_gap": 0.04,
			"led_glow_size": 3.0,
			"led_glow_strength": 1.5,
			"led_smudge_blur": 1.0,
		},
		"ints": {
			"font_size_header": 20,
			"font_size_title": 16,
			"font_size_section": 14,
			"font_size_body": 13,
		},
		"grid_line_color": "#265999",
		"font_paths": {
			"font_header": "res://assets/fonts/Orbitron.ttf",
			"font_body": "res://assets/fonts/ShareTechMono-Regular.ttf",
		},
	},
	"Neon Frost": {
		"colors": {
			"header": "#80FFFF",
			"accent": "#B3FFE6",
			"positive": "#80FFB3",
			"warning": "#FF6680",
			"dimmed": "#6699AA",
			"disabled": "#668899",
			"text": "#E6F2FF",
			"background": "#000A14",
			"panel": "#0A1A2A",
			"bar_positive": "#339966",
			"bar_negative": "#CC3355",
		},
		"floats": {
			"grid_spacing": 48.0,
			"grid_scroll_speed": 15.0,
			"grid_line_width": 1.5,
			"grid_inner_intensity": 0.0,
			"grid_aura_size": 5.0,
			"grid_aura_intensity": 0.9,
			"grid_bloom_size": 14.0,
			"grid_bloom_intensity": 0.3,
			"grid_smudge_blur": 0.0,
			"header_inner_intensity": 0.0,
			"header_aura_size": 0.0,
			"header_aura_intensity": 0.0,
			"header_bloom_size": 0.0,
			"header_bloom_intensity": 0.0,
			"header_smudge_blur": 0.0,
			"body_inner_intensity": 0.0,
			"body_aura_size": 0.0,
			"body_aura_intensity": 0.0,
			"body_bloom_size": 0.0,
			"body_bloom_intensity": 0.0,
			"body_smudge_blur": 0.0,
			"vhs_scanline_strength": 0.1,
			"vhs_scanline_spacing": 2.0,
			"vhs_chromatic_aberration": 0.5,
			"vhs_barrel_distortion": 0.0,
			"vhs_vignette_strength": 0.2,
			"vhs_noise_intensity": 0.0,
			"vhs_color_bleed": 0.0,
			"vhs_roll_speed": 0.0,
			"vhs_roll_strength": 0.0,
			"led_bar_enabled": 0.0,
			"led_segment_count": 20.0,
			"led_segment_gap": 0.04,
			"led_glow_size": 3.0,
			"led_glow_strength": 1.5,
			"led_smudge_blur": 1.0,
		},
		"ints": {
			"font_size_header": 20,
			"font_size_title": 16,
			"font_size_section": 14,
			"font_size_body": 13,
		},
		"grid_line_color": "#338899",
		"font_paths": {
			"font_header": "res://assets/fonts/Orbitron.ttf",
			"font_body": "res://assets/fonts/ShareTechMono-Regular.ttf",
		},
	},
	"Void Purple": {
		"colors": {
			"header": "#CC80FF",
			"accent": "#FF80CC",
			"positive": "#80FF80",
			"warning": "#FF6633",
			"dimmed": "#666680",
			"disabled": "#555566",
			"text": "#D9CCE6",
			"background": "#0A0510",
			"panel": "#1A0F26",
			"bar_positive": "#339933",
			"bar_negative": "#993333",
		},
		"floats": {
			"grid_spacing": 72.0,
			"grid_scroll_speed": 12.0,
			"grid_line_width": 1.2,
			"grid_inner_intensity": 0.0,
			"grid_aura_size": 4.5,
			"grid_aura_intensity": 0.7,
			"grid_bloom_size": 14.0,
			"grid_bloom_intensity": 0.25,
			"grid_smudge_blur": 0.0,
			"header_inner_intensity": 0.0,
			"header_aura_size": 0.0,
			"header_aura_intensity": 0.0,
			"header_bloom_size": 0.0,
			"header_bloom_intensity": 0.0,
			"header_smudge_blur": 0.0,
			"body_inner_intensity": 0.0,
			"body_aura_size": 0.0,
			"body_aura_intensity": 0.0,
			"body_bloom_size": 0.0,
			"body_bloom_intensity": 0.0,
			"body_smudge_blur": 0.0,
			"vhs_scanline_strength": 0.15,
			"vhs_scanline_spacing": 3.0,
			"vhs_chromatic_aberration": 1.0,
			"vhs_barrel_distortion": 0.05,
			"vhs_vignette_strength": 0.4,
			"vhs_noise_intensity": 0.03,
			"vhs_color_bleed": 0.5,
			"vhs_roll_speed": 0.0,
			"vhs_roll_strength": 0.0,
			"led_bar_enabled": 0.0,
			"led_segment_count": 20.0,
			"led_segment_gap": 0.04,
			"led_glow_size": 3.0,
			"led_glow_strength": 1.5,
			"led_smudge_blur": 1.0,
		},
		"ints": {
			"font_size_header": 20,
			"font_size_title": 16,
			"font_size_section": 14,
			"font_size_body": 13,
		},
		"grid_line_color": "#442266",
		"font_paths": {
			"font_header": "res://assets/fonts/Orbitron.ttf",
			"font_body": "res://assets/fonts/ShareTechMono-Regular.ttf",
		},
	},
}

var _custom_presets: Dictionary = {}
var _grid_shader: Shader = null
var _active_preset: String = ""
var _preset_dirty: bool = false


func _ready() -> void:
	_grid_shader = load("res://assets/shaders/grid_background.gdshader") as Shader
	load_settings()
	_load_custom_presets()


# ── Typed getters (no Variant leaks) ──────────────────────────

func get_color(key: String) -> Color:
	if key == "grid_line_color":
		return _grid_line_color
	var c: Color = _colors.get(key, Color.WHITE)
	return c


func get_font_size(key: String) -> int:
	var s: int = int(_ints.get(key, 13))
	return s


func get_float(key: String) -> float:
	var f: float = float(_floats.get(key, 0.0))
	return f


func get_font(key: String) -> Font:
	var path: String = str(_font_paths.get(key, ""))
	if path == "":
		return null
	if path in _font_cache:
		return _font_cache[path] as Font
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var font: Font = load(path) as Font
	if font:
		_font_cache[path] = font
	return font


func get_font_path(key: String) -> String:
	return str(_font_paths.get(key, ""))


func set_font_path(key: String, path: String) -> void:
	_font_paths[key] = path
	_font_cache.erase(path)
	_preset_dirty = true
	theme_changed.emit()


# ── Setters ───────────────────────────────────────────────────

func set_color(key: String, value: Color) -> void:
	if key == "grid_line_color":
		_grid_line_color = value
	else:
		_colors[key] = value
	_preset_dirty = true
	theme_changed.emit()


func set_font_size(key: String, value: int) -> void:
	_ints[key] = value
	_preset_dirty = true
	theme_changed.emit()


func set_float(key: String, value: float) -> void:
	_floats[key] = value
	_preset_dirty = true
	theme_changed.emit()


# ── Grid Background Helper ────────────────────────────────────

func apply_grid_background(color_rect: ColorRect) -> void:
	if not _grid_shader:
		return
	var mat: ShaderMaterial
	if color_rect.material is ShaderMaterial:
		mat = color_rect.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = _grid_shader
		color_rect.material = mat
	_update_grid_material(mat)


func _update_grid_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("line_color", _grid_line_color)
	mat.set_shader_parameter("bg_color", get_color("background"))
	mat.set_shader_parameter("spacing", get_float("grid_spacing"))
	mat.set_shader_parameter("scroll_speed", get_float("grid_scroll_speed"))
	mat.set_shader_parameter("line_width", get_float("grid_line_width"))
	mat.set_shader_parameter("inner_intensity", get_float("grid_inner_intensity"))
	mat.set_shader_parameter("aura_size", get_float("grid_aura_size"))
	mat.set_shader_parameter("aura_intensity", get_float("grid_aura_intensity"))
	mat.set_shader_parameter("bloom_size", get_float("grid_bloom_size"))
	mat.set_shader_parameter("bloom_intensity", get_float("grid_bloom_intensity"))
	mat.set_shader_parameter("smudge_blur", get_float("grid_smudge_blur"))


# ── VHS Overlay Helper ────────────────────────────────────────

var _vhs_shader: Shader = null

func apply_vhs_overlay(color_rect: ColorRect) -> void:
	if not _vhs_shader:
		_vhs_shader = load("res://assets/shaders/vhs_crt.gdshader") as Shader
	if not _vhs_shader:
		return
	var mat: ShaderMaterial
	if color_rect.material is ShaderMaterial:
		mat = color_rect.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = _vhs_shader
		color_rect.material = mat
	_update_vhs_material(mat)


func _update_vhs_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("scanline_strength", get_float("vhs_scanline_strength"))
	mat.set_shader_parameter("scanline_spacing", get_float("vhs_scanline_spacing"))
	mat.set_shader_parameter("chromatic_aberration", get_float("vhs_chromatic_aberration"))
	mat.set_shader_parameter("barrel_distortion", get_float("vhs_barrel_distortion"))
	mat.set_shader_parameter("vignette_strength", get_float("vhs_vignette_strength"))
	mat.set_shader_parameter("noise_intensity", get_float("vhs_noise_intensity"))
	mat.set_shader_parameter("color_bleed", get_float("vhs_color_bleed"))
	mat.set_shader_parameter("roll_speed", get_float("vhs_roll_speed"))
	mat.set_shader_parameter("roll_strength", get_float("vhs_roll_strength"))


# ── LED Bar Helper ───────────────────────────────────────────

var _led_shader: Shader = null

func apply_led_bar(bar: ProgressBar, fill_color: Color, value_ratio: float) -> void:
	var overlay_name := "led_overlay"
	var existing: ColorRect = bar.get_node_or_null(overlay_name) as ColorRect

	if get_float("led_bar_enabled") > 0.5:
		if not _led_shader:
			_led_shader = load("res://assets/shaders/led_bar.gdshader") as Shader
		if not _led_shader:
			return

		# Hide bar's own rendering — transparent styleboxes
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color(0, 0, 0, 0)
		bar.add_theme_stylebox_override("fill", transparent)
		bar.add_theme_stylebox_override("background", transparent)
		bar.material = null
		bar.clip_contents = false

		# Also disable clipping on bar's parent so overlay can extend
		var bar_parent: Control = bar.get_parent() as Control
		if bar_parent:
			bar_parent.clip_contents = false

		# Compute padding from glow settings — enough room for bloom falloff
		var max_glow: float = maxf(get_float("led_bloom_size"), get_float("led_aura_size"))
		var bar_w: float = maxf(bar.custom_minimum_size.x, 100.0)
		var bar_h: float = maxf(bar.custom_minimum_size.y, 14.0)
		var pad_px: float = clampf(max_glow * bar_w * 2.5 + 4.0, 4.0, 50.0)

		# Create or reuse overlay ColorRect
		var overlay: ColorRect
		if existing:
			overlay = existing
		else:
			overlay = ColorRect.new()
			overlay.name = overlay_name
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.color = Color(1, 1, 1, 1)  # Shader overrides this
			bar.add_child(overlay)

		# Position overlay to extend beyond bar bounds
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.offset_left = -pad_px
		overlay.offset_top = -pad_px
		overlay.offset_right = pad_px
		overlay.offset_bottom = pad_px

		# Calculate padding as fraction of overlay size
		var total_w: float = bar_w + pad_px * 2.0
		var total_h: float = bar_h + pad_px * 2.0
		var pad_x: float = pad_px / total_w
		var pad_y: float = pad_px / total_h

		# Apply shader to overlay
		var mat: ShaderMaterial
		if overlay.material is ShaderMaterial:
			mat = overlay.material as ShaderMaterial
		else:
			mat = ShaderMaterial.new()
			mat.shader = _led_shader
			overlay.material = mat
		mat.set_shader_parameter("pad_x", pad_x)
		mat.set_shader_parameter("pad_y", pad_y)
		mat.set_shader_parameter("segment_count", int(get_float("led_segment_count")))
		mat.set_shader_parameter("segment_gap", get_float("led_segment_gap"))
		mat.set_shader_parameter("inner_intensity", get_float("led_inner_intensity"))
		mat.set_shader_parameter("aura_size", get_float("led_aura_size"))
		mat.set_shader_parameter("aura_intensity", get_float("led_aura_intensity"))
		mat.set_shader_parameter("bloom_size", get_float("led_bloom_size"))
		mat.set_shader_parameter("bloom_intensity", get_float("led_bloom_intensity"))
		mat.set_shader_parameter("smudge_blur", get_float("led_smudge_blur"))
		mat.set_shader_parameter("fill_color", fill_color)
		mat.set_shader_parameter("bg_color", get_color("panel"))
		mat.set_shader_parameter("fill_ratio", value_ratio)
	else:
		# Remove overlay, restore normal bar
		if existing:
			existing.queue_free()
		bar.clip_contents = false
		bar.material = null
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill_style)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = get_color("panel")
		bg_style.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bg_style)


# ── Text Glow Helper ─────────────────────────────────────────

var _text_glow_shader: Shader = null

func apply_text_glow(label: Label, prefix: String) -> void:
	var ii: float = get_float(prefix + "_inner_intensity")
	var as_val: float = get_float(prefix + "_aura_size")
	var ai: float = get_float(prefix + "_aura_intensity")
	var bs: float = get_float(prefix + "_bloom_size")
	var bi: float = get_float(prefix + "_bloom_intensity")
	var sb: float = get_float(prefix + "_smudge_blur")

	var all_zero: bool = ii <= 0.0 and as_val <= 0.0 and ai <= 0.0 and bs <= 0.0 and bi <= 0.0 and sb <= 0.0
	if all_zero:
		label.material = null
		return

	if not _text_glow_shader:
		_text_glow_shader = load("res://assets/shaders/text_glow.gdshader") as Shader
	if not _text_glow_shader:
		return

	var mat: ShaderMaterial
	if label.material is ShaderMaterial:
		mat = label.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = _text_glow_shader
		label.material = mat
	mat.set_shader_parameter("inner_intensity", ii)
	mat.set_shader_parameter("aura_size", as_val)
	mat.set_shader_parameter("aura_intensity", ai)
	mat.set_shader_parameter("bloom_size", bs)
	mat.set_shader_parameter("bloom_intensity", bi)
	mat.set_shader_parameter("smudge_blur", sb)


# ── Persistence ───────────────────────────────────────────────

func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var data: Dictionary = _serialize()
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
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
	_deserialize(data)


func _serialize() -> Dictionary:
	var color_data: Dictionary = {}
	for key in _colors:
		var c: Color = _colors[key]
		color_data[key] = "#" + c.to_html(false)
	return {
		"colors": color_data,
		"floats": _floats.duplicate(),
		"ints": _ints.duplicate(),
		"grid_line_color": "#" + _grid_line_color.to_html(false),
		"font_paths": _font_paths.duplicate(),
		"active_preset": _active_preset,
	}


func _deserialize(data: Dictionary) -> void:
	var color_data: Dictionary = data.get("colors", {})
	for key in color_data:
		if key in _colors:
			_colors[key] = Color(str(color_data[key]))
	var float_data: Dictionary = data.get("floats", {})
	for key in float_data:
		if key in _floats:
			_floats[key] = float(float_data[key])
	var int_data: Dictionary = data.get("ints", {})
	for key in int_data:
		if key in _ints:
			_ints[key] = int(int_data[key])
	var glc: String = str(data.get("grid_line_color", ""))
	if glc != "":
		_grid_line_color = Color(glc)
	var font_data: Dictionary = data.get("font_paths", {})
	for key in font_data:
		_font_paths[key] = str(font_data[key])
	_font_cache.clear()
	var ap: String = str(data.get("active_preset", ""))
	if ap != "":
		_active_preset = ap


# ── Presets ───────────────────────────────────────────────────

func list_preset_names() -> Array[String]:
	var names: Array[String] = []
	for key in BUILTIN_PRESETS:
		names.append(str(key))
	for key in _custom_presets:
		if not names.has(str(key)):
			names.append(str(key))
	names.sort()
	return names


func get_active_preset() -> String:
	return _active_preset


func is_preset_dirty() -> bool:
	return _preset_dirty


func apply_preset(preset_name: String) -> void:
	var data: Dictionary = {}
	if preset_name in BUILTIN_PRESETS:
		data = BUILTIN_PRESETS[preset_name]
	elif preset_name in _custom_presets:
		data = _custom_presets[preset_name]
	else:
		return
	_deserialize(data)
	_active_preset = preset_name
	_preset_dirty = false
	theme_changed.emit()
	save_settings()


func save_custom_preset(preset_name: String) -> void:
	_custom_presets[preset_name] = _serialize()
	_active_preset = preset_name
	_preset_dirty = false
	_save_custom_presets()
	save_settings()


func delete_custom_preset(preset_name: String) -> void:
	if preset_name in _custom_presets:
		_custom_presets.erase(preset_name)
		_save_custom_presets()


func is_builtin_preset(preset_name: String) -> bool:
	return preset_name in BUILTIN_PRESETS


func _save_custom_presets() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var json_str: String = JSON.stringify(_custom_presets, "\t")
	var file: FileAccess = FileAccess.open(PRESETS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_custom_presets() -> void:
	if not FileAccess.file_exists(PRESETS_PATH):
		return
	var file: FileAccess = FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return
	_custom_presets = json.data
