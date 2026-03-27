extends Node
## ThemeManager — centralized aesthetic theme with persistence.
## All semantic colors, font sizes, glow/grid params in one place.
## Emits theme_changed when any value is modified.

signal theme_changed

const SETTINGS_PATH := "user://settings/aesthetic.json"

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
	"bar_shield": Color(0.3, 1.0, 0.8),
	"bar_hull": Color(1.0, 0.3, 0.3),
	"bar_thermal": Color(1.0, 0.6, 0.1),
	"bar_electric": Color(1.0, 0.9, 0.2),
	"bar_warning": Color(1.0, 0.6, 0.1),
	"bar_disabled": Color(0.4, 0.4, 0.4),
	"bar_supercharged": Color(0.3, 0.8, 1.0),
	"chrome_tint": Color(0.7, 0.75, 0.85, 1.0),
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
	"vhs_roll_period": 4.0,
	"led_segment_count": 20.0,
	"led_segment_gap_px": 3.0,
	"led_inner_intensity": 0.3,
	"led_inner_softness": 1.0,
	"led_smudge_blur": 0.008,
	"led_segment_width_px": 10.0,
	"led_hdr_multiplier": 2.5,
	# Button globals
	"btn_border_width": 1.0,
	"btn_corner_radius": 1.0,
	"btn_border_bottom_only": 0.0,
	"btn_use_chrome": 0.0,
	# Button per-state: normal (6 keys)
	"btn_normal_border_alpha": 0.3,
	"btn_normal_bg_alpha": 0.0,
	"btn_normal_glow_size": 2.0,
	"btn_normal_glow_alpha": 0.12,
	"btn_normal_font_opacity": 0.45,
	"btn_normal_font_whiten": 0.0,
	# Button per-state: hover (6 keys)
	"btn_hover_border_alpha": 0.8,
	"btn_hover_bg_alpha": 0.04,
	"btn_hover_glow_size": 5.0,
	"btn_hover_glow_alpha": 0.85,
	"btn_hover_font_opacity": 1.0,
	"btn_hover_font_whiten": 0.15,
	# Button per-state: pressed (6 keys)
	"btn_pressed_border_alpha": 1.0,
	"btn_pressed_bg_alpha": 0.08,
	"btn_pressed_glow_size": 7.0,
	"btn_pressed_glow_alpha": 1.0,
	"btn_pressed_font_opacity": 1.0,
	"btn_pressed_font_whiten": 0.85,
	# Button per-state: disabled (6 keys)
	"btn_disabled_border_alpha": 0.12,
	"btn_disabled_bg_alpha": 0.0,
	"btn_disabled_glow_size": 0.0,
	"btn_disabled_glow_alpha": 0.0,
	"btn_disabled_font_opacity": 0.2,
	"btn_disabled_font_whiten": 0.0,
	"header_chrome_enabled": 0.0,
	"header_chrome_highlight_pos": 0.25,
	"header_chrome_highlight_width": 0.12,
	"header_chrome_highlight_intensity": 1.5,
	"header_chrome_secondary_pos": 0.75,
	"header_chrome_secondary_intensity": 0.4,
	"header_chrome_base_brightness": 0.3,
	"header_chrome_top_brightness": 0.15,
	"supercharged_speed": 1.5,
	"supercharged_intensity": 1.0,
	"supercharged_distortion": 0.15,
	# WorldEnvironment glow controls
	"glow_intensity": 0.8,
	"glow_bloom": 0.0,
	"glow_hdr_threshold": 0.8,
	"glow_level_0": 1.0,
	"glow_level_1": 1.0,
	"glow_level_2": 1.0,
	"glow_level_3": 0.0,
	"glow_level_4": 0.0,
	"glow_level_5": 0.0,
	"glow_level_6": 0.0,
}

# ── Int keys (font sizes) ──
var _ints: Dictionary = {
	"font_size_header": 20,
	"font_size_title": 16,
	"font_size_section": 14,
	"font_size_body": 13,
	"font_size_button": 14,
}

# ── Font paths ──
var _font_paths: Dictionary = {
	"font_header": "res://assets/fonts/Bungee-Regular.ttf",
	"font_body": "res://assets/fonts/ShareTechMono-Regular.ttf",
	"font_button": "res://assets/fonts/Audiowide-Regular.ttf",
}

var _font_cache: Dictionary = {}

# ── Grid line color (separate since it's used in shader) ──
var _grid_line_color: Color = Color(0.15, 0.35, 0.6, 0.4)

var _grid_shader: Shader = null
var _world_env: WorldEnvironment = null
var _env: Environment = null


func _ready() -> void:
	_grid_shader = load("res://assets/shaders/grid_background.gdshader") as Shader
	_setup_world_environment()
	load_settings()
	_apply_glow_settings()  # Re-apply with loaded saved values (defaults are stale)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_F4:
		print("\n── UI Tree Dump (F4) ──")
		var dt: GDScript = load("res://scripts/util/debug_tools.gd") as GDScript
		if dt:
			dt.dump_ui_tree(get_tree().root)
		print("── End Dump ──\n")


func _setup_world_environment() -> void:
	_world_env = WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_CANVAS
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Godot's 2D glow post-processing runs on the ROOT viewport only.
	# SubViewport WorldEnvironments don't drive bloom — the root does.
	# All bloom comes from here; SubViewport ACES handles tonemapping only.
	_apply_glow_settings()
	_world_env.environment = _env
	add_child(_world_env)


func _apply_glow_settings() -> void:
	if not _env:
		return
	_env.glow_enabled = true
	_env.glow_intensity = get_float("glow_intensity")
	_env.glow_bloom = get_float("glow_bloom")
	_env.glow_hdr_threshold = get_float("glow_hdr_threshold")
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		var val: float = get_float("glow_level_%d" % i)
		_env.set_glow_level(i, val > 0.5)


func get_environment() -> Environment:
	return _env


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
	theme_changed.emit()


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
	if key.begins_with("glow_"):
		_apply_glow_settings()
	theme_changed.emit()


# ── Status Bar Specs (shared between HUD and Hangar) ─────────

func get_status_bar_specs() -> Array:
	return [
		{"name": "SHIELD", "color_key": "bar_shield", "color_fallback": Color(0, 0, 0, 0), "segments_stat": "shield_segments"},
		{"name": "HULL", "color_key": "bar_hull", "color_fallback": Color(0, 0, 0, 0), "segments_stat": "hull_segments"},
		{"name": "THERMAL", "color_key": "bar_thermal", "color_fallback": Color(0, 0, 0, 0), "segments_stat": "thermal_segments"},
		{"name": "ELECTRIC", "color_key": "bar_electric", "color_fallback": Color(0, 0, 0, 0), "segments_stat": "electric_segments"},
	]


func resolve_bar_color(spec: Dictionary) -> Color:
	var key: String = str(spec.get("color_key", ""))
	if key != "":
		return get_color(key)
	return spec.get("color_fallback", Color.WHITE) as Color


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
	mat.set_shader_parameter("roll_period", get_float("vhs_roll_period"))


# ── LED Bar Helper ───────────────────────────────────────────

var _led_shader: Shader = null

func apply_led_bar(bar: ProgressBar, fill_color: Color, value_ratio: float, segment_count: int = -1, vertical: bool = false) -> void:
	if not _led_shader:
		_led_shader = load("res://assets/shaders/led_bar_hdr.gdshader") as Shader
	if not _led_shader:
		return

	# Remove legacy overlay if present (migration from old shader system)
	var old_overlay: ColorRect = bar.get_node_or_null("led_overlay") as ColorRect
	if old_overlay:
		old_overlay.queue_free()

	var seg_count: int = segment_count if segment_count > 0 else int(get_float("led_segment_count"))
	var seg_px: float = get_float("led_segment_width_px")
	var gap_px: float = get_float("led_segment_gap_px")

	# Bar size = segments at full size + gaps between them
	if segment_count > 0:
		if vertical:
			bar.custom_minimum_size.y = float(seg_count) * seg_px + float(seg_count - 1) * gap_px
			bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		else:
			bar.custom_minimum_size.x = float(seg_count) * seg_px + float(seg_count - 1) * gap_px
			bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	# Transparent fill so ProgressBar's value-based scaling doesn't affect visuals.
	# Opaque background covers the full bar area — shader renders on it.
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 1)
	bar.add_theme_stylebox_override("background", bg_style)

	# Convert pixel gap to bar-UV fraction for the shader
	var long_axis: float
	if vertical:
		long_axis = maxf(bar.custom_minimum_size.y, 14.0)
	else:
		long_axis = maxf(bar.custom_minimum_size.x, 20.0)
	var gap_uv: float = gap_px / maxf(long_axis, 1.0)

	# Apply shader directly to bar — no overlay needed
	var mat: ShaderMaterial
	if bar.material is ShaderMaterial:
		mat = bar.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = _led_shader
		bar.material = mat
	mat.set_shader_parameter("segment_count", seg_count)
	mat.set_shader_parameter("segment_gap", gap_uv)
	mat.set_shader_parameter("vertical", 1 if vertical else 0)
	mat.set_shader_parameter("inner_intensity", get_float("led_inner_intensity"))
	mat.set_shader_parameter("inner_softness", get_float("led_inner_softness"))
	mat.set_shader_parameter("smudge_blur", get_float("led_smudge_blur"))
	mat.set_shader_parameter("fill_color", fill_color)
	mat.set_shader_parameter("bg_color", get_color("panel"))
	mat.set_shader_parameter("fill_ratio", value_ratio)
	mat.set_shader_parameter("hdr_multiplier", get_float("led_hdr_multiplier"))

	# HDR glow source — a ColorRect child with color > 1.0 that WorldEnvironment
	# bloom picks up. Shader output alone doesn't survive as HDR in Godot's 2D pipeline,
	# but ColorRect.color does. This rect provides the bloom; the shader provides the detail.
	var hdr_mult: float = get_float("led_hdr_multiplier")
	var glow_rect: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
	if not glow_rect:
		glow_rect = ColorRect.new()
		glow_rect.name = "led_glow"
		glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(glow_rect)
	# Clip glow rect to only the filled portion so OFF segments stay dark and colorless
	if vertical:
		glow_rect.anchor_left = 0.0
		glow_rect.anchor_right = 1.0
		glow_rect.anchor_top = 1.0 - value_ratio
		glow_rect.anchor_bottom = 1.0
	else:
		glow_rect.anchor_left = 0.0
		glow_rect.anchor_right = value_ratio
		glow_rect.anchor_top = 0.0
		glow_rect.anchor_bottom = 1.0
	glow_rect.offset_left = 0.0
	glow_rect.offset_top = 0.0
	glow_rect.offset_right = 0.0
	glow_rect.offset_bottom = 0.0
	# HDR color for bloom, low alpha so it doesn't overpower the shader visual
	glow_rect.color = Color(
		fill_color.r * hdr_mult,
		fill_color.g * hdr_mult,
		fill_color.b * hdr_mult,
		0.15 * value_ratio
	)


# ── Supercharged LED Bar Helper ──────────────────────────────

var _supercharged_shader: Shader = null

func apply_supercharged_bar(bar: ProgressBar, fill_color: Color, value_ratio: float, segment_count: int = -1) -> void:
	if not _supercharged_shader:
		_supercharged_shader = load("res://assets/shaders/led_bar_supercharged_hdr.gdshader") as Shader
	if not _supercharged_shader:
		return

	# Remove legacy overlay if present
	var old_overlay: ColorRect = bar.get_node_or_null("led_overlay") as ColorRect
	if old_overlay:
		old_overlay.queue_free()

	var seg_count: int = segment_count if segment_count > 0 else int(get_float("led_segment_count"))
	var seg_px: float = get_float("led_segment_width_px")
	var gap_px: float = get_float("led_segment_gap_px")

	# Bar width = segments at full width + gaps between them
	if segment_count > 0:
		bar.custom_minimum_size.x = float(seg_count) * seg_px + float(seg_count - 1) * gap_px
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	# Transparent fill so ProgressBar's value-based scaling doesn't affect visuals.
	# Opaque background covers the full bar area — shader renders on it.
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 1)
	bar.add_theme_stylebox_override("background", bg_style)

	# Convert pixel gap to bar-UV fraction for the shader
	var bar_w: float = maxf(bar.custom_minimum_size.x, 20.0)
	var gap_uv: float = gap_px / maxf(bar_w, 1.0)

	# Apply shader directly to bar
	var mat: ShaderMaterial
	if bar.material is ShaderMaterial:
		mat = bar.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = _supercharged_shader
		bar.material = mat
	mat.set_shader_parameter("segment_count", seg_count)
	mat.set_shader_parameter("segment_gap", gap_uv)
	mat.set_shader_parameter("inner_intensity", get_float("led_inner_intensity"))
	mat.set_shader_parameter("inner_softness", get_float("led_inner_softness"))
	mat.set_shader_parameter("smudge_blur", get_float("led_smudge_blur"))
	mat.set_shader_parameter("fill_color", fill_color)
	mat.set_shader_parameter("bg_color", get_color("panel"))
	mat.set_shader_parameter("fill_ratio", value_ratio)
	mat.set_shader_parameter("hdr_multiplier", get_float("led_hdr_multiplier"))
	mat.set_shader_parameter("animation_speed", get_float("supercharged_speed"))
	mat.set_shader_parameter("pulse_intensity", get_float("supercharged_intensity"))
	mat.set_shader_parameter("energy_distortion", get_float("supercharged_distortion"))

	# HDR glow source (same as apply_led_bar)
	var hdr_mult: float = get_float("led_hdr_multiplier")
	var glow_rect: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
	if not glow_rect:
		glow_rect = ColorRect.new()
		glow_rect.name = "led_glow"
		glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(glow_rect)
	# Clip glow rect to only the filled portion (supercharged bars are always horizontal)
	glow_rect.anchor_left = 0.0
	glow_rect.anchor_right = value_ratio
	glow_rect.anchor_top = 0.0
	glow_rect.anchor_bottom = 1.0
	glow_rect.offset_left = 0.0
	glow_rect.offset_top = 0.0
	glow_rect.offset_right = 0.0
	glow_rect.offset_bottom = 0.0
	glow_rect.color = Color(
		fill_color.r * hdr_mult,
		fill_color.g * hdr_mult,
		fill_color.b * hdr_mult,
		0.15 * value_ratio
	)


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


# ── Header Chrome Helper ─────────────────────────────────────

var _text_chrome_shader: Shader = null

func apply_header_chrome(label: Label) -> void:
	if get_float("header_chrome_enabled") <= 0.0:
		apply_text_glow(label, "header")
		return

	if not _text_chrome_shader:
		_text_chrome_shader = load("res://assets/shaders/text_chrome.gdshader") as Shader
	if not _text_chrome_shader:
		apply_text_glow(label, "header")
		return

	var mat: ShaderMaterial
	if label.material is ShaderMaterial:
		mat = label.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
	mat.shader = _text_chrome_shader
	label.material = mat

	# Glow uniforms (header prefix)
	mat.set_shader_parameter("inner_intensity", get_float("header_inner_intensity"))
	mat.set_shader_parameter("aura_size", get_float("header_aura_size"))
	mat.set_shader_parameter("aura_intensity", get_float("header_aura_intensity"))
	mat.set_shader_parameter("bloom_size", get_float("header_bloom_size"))
	mat.set_shader_parameter("bloom_intensity", get_float("header_bloom_intensity"))
	mat.set_shader_parameter("smudge_blur", get_float("header_smudge_blur"))

	# Chrome uniforms
	mat.set_shader_parameter("chrome_enabled", 1.0)
	mat.set_shader_parameter("chrome_highlight_pos", get_float("header_chrome_highlight_pos"))
	mat.set_shader_parameter("chrome_highlight_width", get_float("header_chrome_highlight_width"))
	mat.set_shader_parameter("chrome_highlight_intensity", get_float("header_chrome_highlight_intensity"))
	mat.set_shader_parameter("chrome_secondary_pos", get_float("header_chrome_secondary_pos"))
	mat.set_shader_parameter("chrome_secondary_intensity", get_float("header_chrome_secondary_intensity"))
	mat.set_shader_parameter("chrome_base_brightness", get_float("header_chrome_base_brightness"))
	mat.set_shader_parameter("chrome_top_brightness", get_float("header_chrome_top_brightness"))
	mat.set_shader_parameter("chrome_tint", get_color("chrome_tint"))


# ── Button Style Helper ──────────────────────────────────────

func _btn_font_color(base: Color, opacity: float, whiten: float) -> Color:
	var c: Color = base.lerp(Color.WHITE, whiten)
	c.a = opacity
	return c


func _btn_make_stylebox(col: Color, border_a: float, bg_a: float,
		border_w: int, corner_r: int, bottom_only: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, bg_a)
	sb.border_color = Color(col.r, col.g, col.b, border_a)
	sb.set_border_width_all(border_w)
	if bottom_only:
		sb.set_border_width_all(0)
		sb.border_width_bottom = border_w
	sb.set_corner_radius_all(corner_r)
	sb.set_content_margin_all(8)
	return sb


func apply_button_style(btn: Button) -> void:
	# Global params
	var border_w: int = int(get_float("btn_border_width"))
	var corner_r: int = int(get_float("btn_corner_radius"))
	var bottom_only: bool = get_float("btn_border_bottom_only") > 0.5
	var use_chrome: bool = get_float("btn_use_chrome") > 0.5

	var accent: Color = get_color("accent")
	var text_col: Color = get_color("text")
	var base_col: Color = get_color("chrome_tint") if use_chrome else accent
	var dim_col: Color = get_color("disabled")

	# Per-state params (6 each)
	var n_border_a: float = get_float("btn_normal_border_alpha")
	var n_bg_a: float = get_float("btn_normal_bg_alpha")
	var n_glow_sz: int = int(get_float("btn_normal_glow_size"))
	var n_glow_a: float = get_float("btn_normal_glow_alpha")
	var n_font_op: float = get_float("btn_normal_font_opacity")
	var n_font_wh: float = get_float("btn_normal_font_whiten")

	var h_border_a: float = get_float("btn_hover_border_alpha")
	var h_bg_a: float = get_float("btn_hover_bg_alpha")
	var h_glow_sz: int = int(get_float("btn_hover_glow_size"))
	var h_glow_a: float = get_float("btn_hover_glow_alpha")
	var h_font_op: float = get_float("btn_hover_font_opacity")
	var h_font_wh: float = get_float("btn_hover_font_whiten")

	var p_border_a: float = get_float("btn_pressed_border_alpha")
	var p_bg_a: float = get_float("btn_pressed_bg_alpha")
	var p_glow_sz: int = int(get_float("btn_pressed_glow_size"))
	var p_glow_a: float = get_float("btn_pressed_glow_alpha")
	var p_font_op: float = get_float("btn_pressed_font_opacity")
	var p_font_wh: float = get_float("btn_pressed_font_whiten")

	var d_border_a: float = get_float("btn_disabled_border_alpha")
	var d_bg_a: float = get_float("btn_disabled_bg_alpha")
	var d_glow_sz: int = int(get_float("btn_disabled_glow_size"))
	var d_glow_a: float = get_float("btn_disabled_glow_alpha")
	var d_font_op: float = get_float("btn_disabled_font_opacity")
	var d_font_wh: float = get_float("btn_disabled_font_whiten")

	# StyleBoxes
	var normal_sb: StyleBoxFlat = _btn_make_stylebox(base_col, n_border_a, n_bg_a,
		border_w, corner_r, bottom_only)
	var hover_sb: StyleBoxFlat = _btn_make_stylebox(base_col, h_border_a, h_bg_a,
		border_w, corner_r, bottom_only)
	var pressed_sb: StyleBoxFlat = _btn_make_stylebox(base_col, p_border_a, p_bg_a,
		border_w, corner_r, bottom_only)
	var disabled_sb: StyleBoxFlat = _btn_make_stylebox(dim_col, d_border_a, d_bg_a,
		border_w, corner_r, bottom_only)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	btn.add_theme_stylebox_override("focus", hover_sb.duplicate())

	# Font colors via opacity + whiten
	var n_font: Color = _btn_font_color(text_col, n_font_op, n_font_wh)
	var h_font: Color = _btn_font_color(text_col, h_font_op, h_font_wh)
	var p_font: Color = _btn_font_color(text_col, p_font_op, p_font_wh)
	var d_font: Color = _btn_font_color(dim_col, d_font_op, d_font_wh)
	btn.add_theme_color_override("font_color", n_font)
	btn.add_theme_color_override("font_hover_color", h_font)
	btn.add_theme_color_override("font_pressed_color", p_font)
	btn.add_theme_color_override("font_disabled_color", d_font)

	# Font
	var btn_font: Font = get_font("font_button")
	if not btn_font:
		btn_font = get_font("font_body")
	if btn_font:
		btn.add_theme_font_override("font", btn_font)
	btn.add_theme_font_size_override("font_size", get_font_size("font_size_button"))

	# Outline glow — per-state size + alpha via signal lambdas
	_disconnect_btn_glow(btn)

	var n_outline: Color = Color(base_col.r, base_col.g, base_col.b, n_glow_a)
	var h_outline: Color = Color(base_col.r, base_col.g, base_col.b, h_glow_a)
	var p_outline: Color = Color(1.0, 1.0, 1.0, p_glow_a)
	var d_outline: Color = Color(dim_col.r, dim_col.g, dim_col.b, d_glow_a)

	# Store for lock_button_state
	btn.set_meta("_outline_normal", n_outline)
	btn.set_meta("_outline_hover", h_outline)
	btn.set_meta("_outline_press", p_outline)
	btn.set_meta("_outline_disabled", d_outline)
	btn.set_meta("_glow_sz_normal", n_glow_sz)
	btn.set_meta("_glow_sz_hover", h_glow_sz)
	btn.set_meta("_glow_sz_press", p_glow_sz)
	btn.set_meta("_glow_sz_disabled", d_glow_sz)

	# Set initial normal state
	btn.add_theme_constant_override("outline_size", n_glow_sz)
	btn.add_theme_color_override("font_outline_color", n_outline)

	var enter_fn: Callable = func() -> void:
		btn.add_theme_constant_override("outline_size", h_glow_sz)
		btn.add_theme_color_override("font_outline_color", h_outline)
	var exit_fn: Callable = func() -> void:
		btn.add_theme_constant_override("outline_size", n_glow_sz)
		btn.add_theme_color_override("font_outline_color", n_outline)
	var down_fn: Callable = func() -> void:
		btn.add_theme_constant_override("outline_size", p_glow_sz)
		btn.add_theme_color_override("font_outline_color", p_outline)
	var up_fn: Callable = func() -> void:
		btn.add_theme_constant_override("outline_size", h_glow_sz)
		btn.add_theme_color_override("font_outline_color", h_outline)

	btn.mouse_entered.connect(enter_fn)
	btn.mouse_exited.connect(exit_fn)
	btn.button_down.connect(down_fn)
	btn.button_up.connect(up_fn)
	btn.set_meta("_glow_enter", enter_fn)
	btn.set_meta("_glow_exit", exit_fn)
	btn.set_meta("_glow_down", down_fn)
	btn.set_meta("_glow_up", up_fn)


func _disconnect_btn_glow(btn: Button) -> void:
	if not btn.has_meta("_glow_enter"):
		return
	var old_enter: Callable = btn.get_meta("_glow_enter")
	var old_exit: Callable = btn.get_meta("_glow_exit")
	var old_down: Callable = btn.get_meta("_glow_down")
	var old_up: Callable = btn.get_meta("_glow_up")
	if btn.mouse_entered.is_connected(old_enter):
		btn.mouse_entered.disconnect(old_enter)
	if btn.mouse_exited.is_connected(old_exit):
		btn.mouse_exited.disconnect(old_exit)
	if btn.button_down.is_connected(old_down):
		btn.button_down.disconnect(old_down)
	if btn.button_up.is_connected(old_up):
		btn.button_up.disconnect(old_up)
	btn.remove_meta("_glow_enter")
	btn.remove_meta("_glow_exit")
	btn.remove_meta("_glow_down")
	btn.remove_meta("_glow_up")


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
