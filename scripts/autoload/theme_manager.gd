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
	"glow_intensity": 0.8,
	"neon_brightness": 1.0,
	"grid_spacing": 64.0,
	"grid_scroll_speed": 20.0,
	"grid_glow_intensity": 0.6,
	"grid_line_width": 1.0,
}

# ── Int keys (font sizes) ──
var _ints: Dictionary = {
	"font_size_header": 20,
	"font_size_title": 16,
	"font_size_section": 14,
	"font_size_body": 13,
}

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
			"glow_intensity": 0.8,
			"neon_brightness": 1.0,
			"grid_spacing": 64.0,
			"grid_scroll_speed": 20.0,
			"grid_glow_intensity": 0.6,
			"grid_line_width": 1.0,
		},
		"ints": {
			"font_size_header": 20,
			"font_size_title": 16,
			"font_size_section": 14,
			"font_size_body": 13,
		},
		"grid_line_color": "#265999",
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
			"glow_intensity": 1.2,
			"neon_brightness": 1.3,
			"grid_spacing": 48.0,
			"grid_scroll_speed": 15.0,
			"grid_glow_intensity": 0.9,
			"grid_line_width": 1.5,
		},
		"ints": {
			"font_size_header": 20,
			"font_size_title": 16,
			"font_size_section": 14,
			"font_size_body": 13,
		},
		"grid_line_color": "#338899",
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
			"glow_intensity": 1.0,
			"neon_brightness": 1.1,
			"grid_spacing": 72.0,
			"grid_scroll_speed": 12.0,
			"grid_glow_intensity": 0.7,
			"grid_line_width": 1.2,
		},
		"ints": {
			"font_size_header": 20,
			"font_size_title": 16,
			"font_size_section": 14,
			"font_size_body": 13,
		},
		"grid_line_color": "#442266",
	},
}

var _custom_presets: Dictionary = {}
var _grid_shader: Shader = null


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


# ── Setters ───────────────────────────────────────────────────

func set_color(key: String, value: Color) -> void:
	if key == "grid_line_color":
		_grid_line_color = value
	else:
		_colors[key] = value
	theme_changed.emit()


func set_font_size(key: String, value: int) -> void:
	_ints[key] = value
	theme_changed.emit()


func set_float(key: String, value: float) -> void:
	_floats[key] = value
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
	mat.set_shader_parameter("glow_intensity", get_float("grid_glow_intensity"))
	mat.set_shader_parameter("line_width", get_float("grid_line_width"))


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


func apply_preset(preset_name: String) -> void:
	var data: Dictionary = {}
	if preset_name in BUILTIN_PRESETS:
		data = BUILTIN_PRESETS[preset_name]
	elif preset_name in _custom_presets:
		data = _custom_presets[preset_name]
	else:
		return
	_deserialize(data)
	theme_changed.emit()
	save_settings()


func save_custom_preset(preset_name: String) -> void:
	_custom_presets[preset_name] = _serialize()
	_save_custom_presets()


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
