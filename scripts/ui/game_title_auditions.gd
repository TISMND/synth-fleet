extends MarginContainer
## Game Title auditions — takes the main menu SYNTHERION title (Specular Slit)
## as the baseline and explores texture layers: outer glow, outer bezel,
## inner shadow, film grain, brushed metal, grooves, extrusion, shadow.
## Every preset renders with the same shader and font as the live main menu.

const TITLE_TEXT: String = "SYNTHERION"
const SHADER_PATH: String = "res://assets/shaders/title_chrome_3d.gdshader"
const ETHNO_FONT: String = "res://assets/fonts/Ethnocentric-Regular.otf"
# Render each preview DIRECTLY in the root viewport (no SubViewport) so:
#  (a) SCREEN_PIXEL_SIZE matches main_menu exactly (1/1920, 1/1080) — every
#      pixel-space effect (bevel, shadow, outer_glow, bezel, grain, etc.)
#      renders at the same strength it will on the real title.
#  (b) The ThemeManager root WorldEnvironment bloom applies to the title
#      the same way it does on main_menu — no extra tonemapping step.
# We use a clipping card that windows a central slice of the 1920-wide stage.
const STAGE_W: int = 1920
const STAGE_H: int = 360
const TITLE_SIZE: int = 180
const TITLE_OFFSET_TOP: int = 120
const TITLE_OFFSET_BOTTOM: int = 280
const CARD_W: int = 1200
const CARD_H: int = 360
const BG_COLOR: Color = Color(0, 0, 0, 1)
const TITLE_COLOR: Color = Color(0.4, 0.65, 1.0)

# Baseline = exact main_menu.gd Specular Slit config. Every preset merges
# overrides on top of this, so auditions compare apples-to-apples.
const BASELINE: Dictionary = {
	"chrome_color_top": Color(0.01, 0.03, 0.1),
	"chrome_color_highlight1": Color(0.5, 0.75, 1.0),
	"chrome_color_mid": Color(0.03, 0.06, 0.15),
	"chrome_color_highlight2": Color(0.35, 0.55, 0.85),
	"chrome_color_bottom": Color(0.01, 0.02, 0.06),
	"band1_pos": 0.2, "band2_pos": 0.45, "band3_pos": 0.55, "band4_pos": 0.8,
	"band_sharpness": 20.0,
	"line_density": 70.0, "line_strength": 0.12,
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

var _presets: Array[Dictionary] = []
var _scroll: ScrollContainer
var _grid: VBoxContainer


func _ready() -> void:
	_define_presets()
	_build_ui()


## Push a preset that merges `overrides` over the baseline.
func _p(label: String, overrides: Dictionary) -> void:
	var params: Dictionary = BASELINE.duplicate()
	params.merge(overrides, true)
	_presets.append({"name": label, "params": params})


func _define_presets() -> void:
	_p("Baseline — Specular Slit (main menu)", {})

	_p("Outer Glow — Soft Ice", {
		"outer_glow_strength": 1.4, "outer_glow_radius": 6.0,
		"outer_glow_color": Color(0.45, 0.75, 1.0, 1.0),
	})

	_p("Film Grain — Light Static", {
		"grain_strength": 0.18, "grain_scale": 700.0, "grain_speed": 2.5,
	})
	_p("Film Grain — Heavy VHS", {
		"grain_strength": 0.4, "grain_scale": 450.0, "grain_speed": 3.5,
	})

	_p("Brushed — Light Satin", {
		"surface_noise": 0.25, "surface_scale": 180.0,
	})
	_p("Brushed — Heavy Steel", {
		"surface_noise": 0.5, "surface_scale": 140.0,
		"bevel_strength": 1.3,
	})
	_p("Brushed — Hairline", {
		"surface_noise": 0.18, "surface_scale": 320.0,
	})


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var header := Label.new()
	header.text = "GAME TITLE — SYNTHERION TEXTURE AUDITIONS"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	var sub := Label.new()
	sub.text = "Baseline = main menu Specular Slit. Each card stacks one or more texture effects on top."
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

	# Clipping card — windows a central slice of the 1920-wide stage so the
	# title shows at its true main-menu pixel scale without needing a 1920-wide
	# cell. Everything inside renders directly in the root viewport.
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.size_flags_horizontal = 0  # don't let VBox stretch us
	card.clip_contents = true
	cell.add_child(card)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(CARD_W, CARD_H)
	card.add_child(bg)

	# Stage is a 1920-wide virtual frame matching main_menu's root viewport.
	# We shift it left so the centered title lands in the middle of the card.
	var stage := Control.new()
	stage.position = Vector2(-float(STAGE_W - CARD_W) * 0.5, 0.0)
	stage.size = Vector2(STAGE_W, STAGE_H)
	card.add_child(stage)

	# Label geometry mirrors main_menu.tscn TitleLabel exactly:
	# offset_left=0, offset_top=120, offset_right=1920, offset_bottom=280,
	# font_size=180, horizontal_alignment=1 (centered).
	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, float(TITLE_OFFSET_TOP))
	title.size = Vector2(float(STAGE_W), float(TITLE_OFFSET_BOTTOM - TITLE_OFFSET_TOP))

	var font_res: Font = load(ETHNO_FONT)
	if font_res:
		title.add_theme_font_override("font", font_res)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)

	var shader: Shader = load(SHADER_PATH)
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
