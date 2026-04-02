extends MarginContainer
## Title auditions — shows "SYNTHERION" in MIDNIGHT ICE chrome across many typefaces.
## Uses the title_chrome shader for multi-band metallic gradients, bevels, gleam, and shadow.

const TITLE_TEXT: String = "SYNTHERION"
const SHADER_PATH: String = "res://assets/shaders/title_chrome.gdshader"
const VP_W: int = 900
const VP_H: int = 140
const BG_COLOR: Color = Color(0.015, 0.015, 0.03, 1.0)

# MIDNIGHT ICE: deep dark blue chrome, icy highlights, slow dramatic gleam
const MIDNIGHT_ICE: Dictionary = {
	"chrome_color_top": Color(0.01, 0.03, 0.1),
	"chrome_color_highlight1": Color(0.5, 0.75, 1.0),
	"chrome_color_mid": Color(0.03, 0.06, 0.15),
	"chrome_color_highlight2": Color(0.35, 0.55, 0.85),
	"chrome_color_bottom": Color(0.01, 0.02, 0.06),
	"band1_pos": 0.2, "band2_pos": 0.45, "band3_pos": 0.55, "band4_pos": 0.8,
	"band_sharpness": 20.0,
	"line_density": 70.0, "line_strength": 0.16,
	"bevel_strength": 0.8, "bevel_size": 1.8,
	"bevel_light_color": Color(0.5, 0.7, 1.0),
	"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 3.0,
	"shadow_color": Color(0.0, 0.0, 0.15, 0.85),
	"gleam_enabled": 1.0, "gleam_speed": 0.4, "gleam_width": 0.1, "gleam_intensity": 2.0,
	"hdr_boost": 1.5,
}
const MIDNIGHT_ICE_COLOR: Color = Color(0.4, 0.65, 1.0)

var _presets: Array[Dictionary] = []
var _scroll: ScrollContainer
var _grid: VBoxContainer


func _ready() -> void:
	_define_presets()
	_build_ui()
	ThemeManager.theme_changed.connect(func(): queue_redraw())


func _p(label: String, font_path: String, size: int) -> void:
	_presets.append({
		"name": label,
		"font": font_path,
		"size": size,
		"color": MIDNIGHT_ICE_COLOR,
		"params": MIDNIGHT_ICE,
	})


func _define_presets() -> void:
	# ── PREVIOUS WINNERS ─────────────────────────────────────────────
	_p("Black Ops One", "res://assets/fonts/BlackOpsOne-Regular.ttf", 72)
	_p("Quantico Bold", "res://assets/fonts/Quantico-Bold.ttf", 72)
	_p("Stalinist One", "res://assets/fonts/StalinistOne-Regular.ttf", 58)

	# ── ROUND 2 FONTS ────────────────────────────────────────────────
	_p("Tourney", "res://assets/fonts/Tourney.ttf", 72)
	_p("Oxanium", "res://assets/fonts/Oxanium.ttf", 72)
	_p("Michroma", "res://assets/fonts/Michroma-Regular.ttf", 56)
	_p("Electrolize", "res://assets/fonts/Electrolize-Regular.ttf", 72)
	_p("Wallpoet", "res://assets/fonts/Wallpoet-Regular.ttf", 68)
	_p("Squada One", "res://assets/fonts/SquadaOne-Regular.ttf", 84)
	_p("Chakra Petch Bold", "res://assets/fonts/ChakraPetch-Bold.ttf", 72)
	_p("Kenia", "res://assets/fonts/Kenia-Regular.ttf", 72)

	# ── NEW ROUND 3 FONTS — 80s / retro / action ────────────────────
	_p("Anton", "res://assets/fonts/Anton-Regular.ttf", 80)
	_p("Kanit Black", "res://assets/fonts/Kanit-Black.ttf", 72)
	_p("Racing Sans One", "res://assets/fonts/RacingSansOne-Regular.ttf", 72)
	_p("Fugaz One", "res://assets/fonts/FugazOne-Regular.ttf", 72)
	_p("Secular One", "res://assets/fonts/SecularOne-Regular.ttf", 72)
	_p("Archivo Black", "res://assets/fonts/ArchivoBlack-Regular.ttf", 72)
	_p("Black Han Sans", "res://assets/fonts/BlackHanSans-Regular.ttf", 80)
	_p("Saira Extra Condensed Black", "res://assets/fonts/SairaExtraCondensed-Black.ttf", 88)
	_p("Bruno Ace", "res://assets/fonts/BrunoAce-Regular.ttf", 60)
	_p("Passion One Black", "res://assets/fonts/PassionOne-Black.ttf", 76)
	_p("Rajdhani Bold", "res://assets/fonts/Rajdhani-Bold.ttf", 80)
	_p("Khand Bold", "res://assets/fonts/Khand-Bold.ttf", 80)

	# ── ORIGINAL FONTS (for comparison) ──────────────────────────────
	_p("Bungee", "res://assets/fonts/Bungee-Regular.ttf", 76)
	_p("Orbitron", "res://assets/fonts/Orbitron.ttf", 72)
	_p("RussoOne", "res://assets/fonts/RussoOne-Regular.ttf", 76)


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var header := Label.new()
	header.text = "TITLE STYLES — MIDNIGHT ICE"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_scroll)

	_grid = VBoxContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("separation", 24)
	_scroll.add_child(_grid)

	for i in _presets.size():
		_build_preset_cell(_presets[i])


func _build_preset_cell(preset: Dictionary) -> void:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	_grid.add_child(cell)

	var name_label := Label.new()
	name_label.text = str(preset["name"])
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	cell.add_child(name_label)

	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(VP_W, VP_H)
	svc.size = Vector2(VP_W, VP_H)
	svc.stretch = true
	cell.add_child(svc)

	var svp := SubViewport.new()
	svp.size = Vector2i(VP_W, VP_H)
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(svp)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)

	var font_path: String = str(preset["font"])
	var font_res: Font = load(font_path)
	if font_res:
		title.add_theme_font_override("font", font_res)
	title.add_theme_font_size_override("font_size", int(preset["size"]))
	title.add_theme_color_override("font_color", preset["color"] as Color)

	var shader: Shader = load(SHADER_PATH)
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var params: Dictionary = preset.get("params", {}) as Dictionary
		for key in params:
			mat.set_shader_parameter(key, params[key])
		title.material = mat

	svp.add_child(title)
	VFXFactory.add_bloom_to_viewport(svp)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 1)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.12, 0.15, 0.22, 0.4)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	cell.add_child(sep)
