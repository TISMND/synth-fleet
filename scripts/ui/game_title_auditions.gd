extends MarginContainer
## Game Title auditions — explores Tier-1 fake-3D techniques for text:
##   [A] Normal-from-alpha lighting (title_3d_normal.gdshader)
##   [B] Extrusion stacking (title_chrome_3d.gdshader, extrusion_depth)
##   [C] MSDF font rendering (any shader, crisper alpha gradients)
##
## Every card renders directly in the root viewport at main_menu scale
## (font 180pt, SCREEN_PIXEL_SIZE matching 1920×1080) so shader effects
## render at the same strength they would on the real title.

const TITLE_TEXT: String = "SYNTHERION"
const CHROME_SHADER: String = "res://assets/shaders/title_chrome_3d.gdshader"
const NORMAL_SHADER: String = "res://assets/shaders/title_3d_normal.gdshader"
const ETHNO_FONT: String = "res://assets/fonts/Ethnocentric-Regular.otf"

const STAGE_W: int = 1920
const STAGE_H: int = 360
const TITLE_SIZE: int = 180
const TITLE_OFFSET_TOP: int = 120
const TITLE_OFFSET_BOTTOM: int = 280
const CARD_W: int = 1800
const CARD_H: int = 360
const BG_COLOR: Color = Color(0, 0, 0, 1)
const TITLE_COLOR: Color = Color(0.4, 0.65, 1.0)

# Main-menu Specular Slit config — used as the seed for Chrome-shader presets.
const CHROME_BASELINE: Dictionary = {
	"chrome_color_top": Color(0.01, 0.03, 0.1),
	"chrome_color_highlight1": Color(0.5, 0.75, 1.0),
	"chrome_color_mid": Color(0.03, 0.06, 0.15),
	"chrome_color_highlight2": Color(0.35, 0.55, 0.85),
	"chrome_color_bottom": Color(0.01, 0.02, 0.06),
	"band1_pos": 0.2, "band2_pos": 0.45, "band3_pos": 0.55, "band4_pos": 0.8,
	"band_sharpness": 20.0,
	"line_density": 0.0, "line_strength": 0.0,
	"bevel_strength": 1.0, "bevel_size": 1.8,
	"bevel_light_color": Color(0.5, 0.7, 1.0),
	"bevel_shadow_color": Color(0.0, 0.0, 0.05, 1.0),
	"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 3.0,
	"shadow_color": Color(0.0, 0.0, 0.15, 0.85),
	"gleam_enabled": 0.0, "gleam_speed": 0.4, "gleam_width": 0.1, "gleam_intensity": 2.0, "gleam_angle": 0.3,
	"groove_strength": 0.0, "groove_size": 2.0, "groove_color": Color(0.0, 0.0, 0.08, 1.0),
	"extrusion_depth": 0.0, "extrusion_angle": 0.785, "extrusion_color": Color(0.02, 0.04, 0.12, 1.0),
	"specular_enabled": 1.0, "specular_pos": 0.32, "specular_width": 0.015,
	"specular_intensity": 3.0, "specular_color": Color(0.9, 0.95, 1.0, 1.0),
	"surface_noise": 0.0, "surface_scale": 120.0,
	"outer_glow_strength": 0.0, "outer_glow_radius": 4.0, "outer_glow_color": Color(0.4, 0.7, 1.0, 1.0),
	"outer_bezel_strength": 0.0, "outer_bezel_width": 1.5, "outer_bezel_color": Color(0.8, 0.9, 1.0, 1.0),
	"grain_strength": 0.0, "grain_scale": 500.0, "grain_speed": 0.0,
	"inner_shadow_strength": 0.0, "inner_shadow_size": 3.0, "inner_shadow_angle": 2.35,
	"inner_shadow_color": Color(0.0, 0.0, 0.0, 1.0),
	"hdr_boost": 1.5,
}

# Default Normal-from-alpha config — balanced chrome metal.
const NORMAL_BASELINE: Dictionary = {
	"base_color": Color(0.04, 0.08, 0.18, 1.0),
	"highlight_color": Color(0.55, 0.75, 1.0, 1.0),
	"specular_color": Color(1.0, 1.0, 1.0, 1.0),
	"light_angle": 2.36,  # ~135 degrees, top-left
	"light_elevation": 0.5,
	"ambient": 0.55,
	"diffuse_strength": 1.2,
	"specular_strength": 1.8,
	"specular_power": 48.0,
	"normal_sample_radius": 2.5,
	"depth_scale": 3.0,
	"hdr_boost": 1.3,
}

var _presets: Array[Dictionary] = []
var _scroll: ScrollContainer
var _grid: VBoxContainer
var _msdf_font: Font = null


func _ready() -> void:
	_load_msdf_font()
	_define_presets()
	_build_ui()


func _load_msdf_font() -> void:
	var base: Resource = load(ETHNO_FONT)
	if base is FontFile:
		var f: FontFile = (base as FontFile).duplicate() as FontFile
		f.multichannel_signed_distance_field = true
		_msdf_font = f


## Register a preset. `technique` prefixes the label. `shader_path` picks the
## shader. `params` are merged on top of the appropriate baseline for that
## shader. `msdf` swaps to the MSDF-enabled font.
func _p(technique: String, label: String, shader_path: String, overrides: Dictionary, msdf: bool = false) -> void:
	var baseline: Dictionary = NORMAL_BASELINE if shader_path == NORMAL_SHADER else CHROME_BASELINE
	var params: Dictionary = baseline.duplicate()
	params.merge(overrides, true)
	_presets.append({
		"name": "[%s] %s" % [technique, label],
		"shader": shader_path,
		"params": params,
		"msdf": msdf,
	})


func _define_presets() -> void:
	# ═══════════════════════════════════════════════════════════════════
	# TECHNIQUE A — Normal-from-alpha lighting
	# 8-tap Sobel gradient on font alpha → pseudo-normal → directional
	# diffuse + Blinn-Phong specular. This is the real fake-3D workhorse.
	# ═══════════════════════════════════════════════════════════════════

	_p("A", "Normal — Front-Lit Chrome (light overhead)", NORMAL_SHADER, {
		"light_elevation": 0.92,
		"depth_scale": 3.0,
		"specular_power": 64.0,
	})

	_p("A", "Normal — Top-Left Studio Metal (classic)", NORMAL_SHADER, {
		"light_angle": 2.36, "light_elevation": 0.45,
		"depth_scale": 4.0,
		"specular_power": 48.0,
	})

	_p("A", "Normal — Grazing Rim Light (low angle)", NORMAL_SHADER, {
		"light_angle": 3.14, "light_elevation": 0.15,
		"depth_scale": 5.0,
		"specular_power": 24.0,
		"specular_strength": 2.6,
	})

	_p("A", "Normal — Deep Bulge (puffy letters)", NORMAL_SHADER, {
		"light_angle": 2.36, "light_elevation": 0.55,
		"depth_scale": 9.0,
		"normal_sample_radius": 3.5,
		"specular_power": 32.0,
	})

	_p("A", "Normal — Sharp Phong Pin-Point (tight speculars)", NORMAL_SHADER, {
		"light_angle": 2.1, "light_elevation": 0.4,
		"depth_scale": 4.5,
		"specular_power": 160.0,
		"specular_strength": 3.2,
	})

	_p("A", "Normal — Warm Gold Metal", NORMAL_SHADER, {
		"base_color": Color(0.18, 0.10, 0.02, 1.0),
		"highlight_color": Color(1.0, 0.82, 0.35, 1.0),
		"specular_color": Color(1.0, 0.95, 0.7, 1.0),
		"light_angle": 2.36, "light_elevation": 0.5,
		"depth_scale": 4.0,
		"specular_power": 72.0,
		"hdr_boost": 1.5,
	})

	_p("A", "Normal — Cyan Neon Plastic", NORMAL_SHADER, {
		"base_color": Color(0.0, 0.12, 0.18, 1.0),
		"highlight_color": Color(0.3, 1.0, 1.0, 1.0),
		"specular_color": Color(0.85, 1.0, 1.0, 1.0),
		"light_angle": 2.0, "light_elevation": 0.55,
		"depth_scale": 5.0,
		"specular_power": 96.0,
		"specular_strength": 2.4,
		"hdr_boost": 1.7,
	})

	# ═══════════════════════════════════════════════════════════════════
	# TECHNIQUE B — Extrusion stacking
	# Draws the glyph silhouette multiple times at a consistent offset
	# angle, darkening each copy. Creates real apparent letter thickness
	# by accumulating overlapping shadows behind the face.
	# ═══════════════════════════════════════════════════════════════════

	_p("B", "Extrusion — Thin Depth (6px, 45°)", CHROME_SHADER, {
		"extrusion_depth": 6.0, "extrusion_angle": 0.785,
		"extrusion_color": Color(0.02, 0.05, 0.15, 1.0),
	})

	_p("B", "Extrusion — Chunky 3D (16px, 45°)", CHROME_SHADER, {
		"extrusion_depth": 16.0, "extrusion_angle": 0.785,
		"extrusion_color": Color(0.02, 0.04, 0.10, 1.0),
	})

	_p("B", "Extrusion — Heavy Block (28px, 30°)", CHROME_SHADER, {
		"extrusion_depth": 28.0, "extrusion_angle": 0.524,
		"extrusion_color": Color(0.01, 0.02, 0.06, 1.0),
	})

	_p("B", "Extrusion — Long Isometric Shadow (40px, 30°)", CHROME_SHADER, {
		"extrusion_depth": 40.0, "extrusion_angle": 0.524,
		"extrusion_color": Color(0.03, 0.06, 0.14, 1.0),
		"shadow_softness": 0.5,
	})

	# ═══════════════════════════════════════════════════════════════════
	# TECHNIQUE C — MSDF font rendering
	# Loads the font with multichannel_signed_distance_field enabled.
	# The alpha ramp at glyph edges becomes mathematically smooth instead
	# of atlas-interpolated, which (a) stays crisp at any zoom and (b)
	# gives cleaner gradients that the normal-from-alpha shader loves.
	# ═══════════════════════════════════════════════════════════════════

	_p("C", "MSDF — Baseline Chrome (compare edges vs baseline)", CHROME_SHADER, {}, true)

	_p("C", "MSDF + Normal Light — Top-Left Studio Metal", NORMAL_SHADER, {
		"light_angle": 2.36, "light_elevation": 0.45,
		"depth_scale": 4.0,
		"specular_power": 48.0,
	}, true)

	_p("C", "MSDF + Normal Light — Deep Bulge (cleaner gradients)", NORMAL_SHADER, {
		"light_angle": 2.36, "light_elevation": 0.55,
		"depth_scale": 9.0,
		"normal_sample_radius": 3.5,
		"specular_power": 32.0,
	}, true)

	# Plain baseline last — the original main-menu look for comparison.
	_p("ref", "Baseline Chrome (current main menu)", CHROME_SHADER, {})


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var header := Label.new()
	header.text = "GAME TITLE — SYNTHERION 3D TECHNIQUE AUDITIONS"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	var sub := Label.new()
	sub.text = "[A] Normal-from-alpha lighting  ·  [B] Extrusion stacking  ·  [C] MSDF font"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	main.add_child(sub)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_scroll)

	_grid = VBoxContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("separation", 20)
	_scroll.add_child(_grid)

	for preset in _presets:
		_build_preset_cell(preset)


func _build_preset_cell(preset: Dictionary) -> void:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	_grid.add_child(cell)

	var name_label := Label.new()
	name_label.text = str(preset["name"])
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	cell.add_child(name_label)

	# Clipping card windowing a 1920-wide stage so SCREEN_PIXEL_SIZE matches
	# main_menu's root viewport exactly.
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.size_flags_horizontal = 0
	card.clip_contents = true
	cell.add_child(card)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(CARD_W, CARD_H)
	card.add_child(bg)

	var stage := Control.new()
	stage.position = Vector2(-float(STAGE_W - CARD_W) * 0.5, 0.0)
	stage.size = Vector2(STAGE_W, STAGE_H)
	card.add_child(stage)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, float(TITLE_OFFSET_TOP))
	title.size = Vector2(float(STAGE_W), float(TITLE_OFFSET_BOTTOM - TITLE_OFFSET_TOP))

	var use_msdf: bool = preset.get("msdf", false) as bool
	var font_res: Font = _msdf_font if (use_msdf and _msdf_font != null) else load(ETHNO_FONT) as Font
	if font_res:
		title.add_theme_font_override("font", font_res)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)

	var shader_path: String = preset["shader"] as String
	var shader: Shader = load(shader_path)
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var params: Dictionary = preset["params"] as Dictionary
		for key in params:
			mat.set_shader_parameter(key, params[key])
		title.material = mat

	stage.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.12, 0.15, 0.22, 0.4)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	cell.add_child(sep)
