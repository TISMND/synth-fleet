extends MarginContainer
## Title auditions — Ethnocentric 3D chrome variations + other font keepers.
## Uses title_chrome_3d shader for depth, grooves, specular, extrusion.

const TITLE_TEXT: String = "SYNTHERION"
const SHADER_PATH: String = "res://assets/shaders/title_chrome.gdshader"
const SHADER_3D_PATH: String = "res://assets/shaders/title_chrome_3d.gdshader"
const ETHNO_FONT: String = "res://assets/fonts/Ethnocentric-Regular.otf"
const VP_W: int = 900
const VP_H: int = 140
const BG_COLOR: Color = Color(0.015, 0.015, 0.03, 1.0)

# Base MIDNIGHT ICE palette — shared across Ethnocentric variants
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


## Add a preset using the original shader (for kept fonts).
func _p(label: String, font_path: String, size: int) -> void:
	_presets.append({
		"name": label,
		"font": font_path,
		"size": size,
		"color": MIDNIGHT_ICE_COLOR,
		"params": MIDNIGHT_ICE,
		"shader": SHADER_PATH,
	})


## Add an Ethnocentric 3D preset — merges overrides onto MIDNIGHT ICE base.
func _e(label: String, overrides: Dictionary, size: int = 64) -> void:
	var params: Dictionary = MIDNIGHT_ICE.duplicate()
	# 3D shader defaults for params not in MIDNIGHT_ICE
	params["groove_strength"] = 0.0
	params["groove_size"] = 2.0
	params["groove_color"] = Color(0.0, 0.0, 0.08, 1.0)
	params["extrusion_depth"] = 0.0
	params["extrusion_angle"] = 0.785
	params["extrusion_color"] = Color(0.02, 0.04, 0.12, 1.0)
	params["specular_enabled"] = 0.0
	params["specular_pos"] = 0.35
	params["specular_width"] = 0.03
	params["specular_intensity"] = 2.0
	params["specular_color"] = Color(0.8, 0.9, 1.0, 1.0)
	params["surface_noise"] = 0.0
	params["surface_scale"] = 120.0
	params.merge(overrides, true)
	var color: Color = overrides.get("_color", MIDNIGHT_ICE_COLOR) as Color
	_presets.append({
		"name": label,
		"font": ETHNO_FONT,
		"size": size,
		"color": color,
		"params": params,
		"shader": SHADER_3D_PATH,
	})


func _define_presets() -> void:
	# ── ETHNOCENTRIC — 3D CHROME VARIATIONS ──────────────────────────

	# 1. Baseline Midnight Ice (flat, for comparison)
	_e("Ethnocentric — Midnight Ice (baseline)", {})

	# 2. Heavy Bevel — chunky 3D edges, strong light/shadow contrast
	_e("Ethnocentric — Heavy Bevel", {
		"bevel_strength": 1.6,
		"bevel_size": 3.0,
		"bevel_light_color": Color(0.7, 0.85, 1.0),
		"shadow_offset_x": 3.5, "shadow_offset_y": 4.5, "shadow_softness": 4.0,
		"hdr_boost": 1.8,
	})

	# 3. Razor Gleam — very narrow gleam line, like a blade reflection
	_e("Ethnocentric — Razor Gleam", {
		"gleam_width": 0.025,
		"gleam_intensity": 2.8,
		"gleam_speed": 0.3,
		"gleam_angle": 0.15,
		"line_density": 0.0, "line_strength": 0.0,
		"bevel_strength": 1.2, "bevel_size": 2.0,
	})

	# 4. Engraved Grooves — dark inner edge creates chiseled look
	_e("Ethnocentric — Engraved Grooves", {
		"groove_strength": 1.2,
		"groove_size": 3.0,
		"groove_color": Color(0.0, 0.01, 0.06, 1.0),
		"bevel_strength": 1.0, "bevel_size": 2.2,
		"line_density": 0.0, "line_strength": 0.0,
	})

	# 5. Deep Extrusion — thick 3D side wall
	_e("Ethnocentric — Deep Extrusion", {
		"extrusion_depth": 6.0,
		"extrusion_angle": 0.6,
		"extrusion_color": Color(0.01, 0.02, 0.08, 1.0),
		"bevel_strength": 1.4, "bevel_size": 2.5,
		"shadow_offset_x": 4.0, "shadow_offset_y": 5.0, "shadow_softness": 5.0,
	})

	# 6. Specular Slit — narrow hot specular band across face
	_e("Ethnocentric — Specular Slit", {
		"specular_enabled": 1.0,
		"specular_pos": 0.32,
		"specular_width": 0.015,
		"specular_intensity": 3.0,
		"specular_color": Color(0.9, 0.95, 1.0, 1.0),
		"line_density": 0.0, "line_strength": 0.0,
		"bevel_strength": 1.0,
	})

	# 7. Brushed Steel — surface noise for machined metal texture
	_e("Ethnocentric — Brushed Steel", {
		"surface_noise": 0.4,
		"surface_scale": 150.0,
		"bevel_strength": 1.3, "bevel_size": 2.0,
		"chrome_color_highlight1": Color(0.6, 0.7, 0.8),
		"chrome_color_highlight2": Color(0.4, 0.5, 0.65),
		"line_density": 0.0, "line_strength": 0.0,
		"hdr_boost": 1.4,
	})

	# 8. Grooves + Extrusion — engraved AND extruded, full 3D
	_e("Ethnocentric — Grooved Block", {
		"groove_strength": 0.9,
		"groove_size": 2.5,
		"groove_color": Color(0.0, 0.005, 0.04, 1.0),
		"extrusion_depth": 5.0,
		"extrusion_angle": 0.7,
		"extrusion_color": Color(0.015, 0.03, 0.1, 1.0),
		"bevel_strength": 1.5, "bevel_size": 2.8,
		"shadow_offset_x": 3.0, "shadow_offset_y": 4.0, "shadow_softness": 4.0,
	})

	# 9. Wide Specular + Heavy Lines — broad warm highlight, dense lines
	_e("Ethnocentric — Lined Specular", {
		"specular_enabled": 1.0,
		"specular_pos": 0.38,
		"specular_width": 0.06,
		"specular_intensity": 2.0,
		"specular_color": Color(0.7, 0.85, 1.0, 1.0),
		"line_density": 120.0, "line_strength": 0.22,
		"bevel_strength": 1.0, "bevel_size": 1.8,
	})

	# 10. Titanium — cooler palette, brushed noise, subtle groove
	_e("Ethnocentric — Titanium", {
		"chrome_color_top": Color(0.02, 0.03, 0.06),
		"chrome_color_highlight1": Color(0.45, 0.55, 0.7),
		"chrome_color_mid": Color(0.05, 0.07, 0.12),
		"chrome_color_highlight2": Color(0.3, 0.4, 0.55),
		"chrome_color_bottom": Color(0.02, 0.03, 0.05),
		"surface_noise": 0.25,
		"surface_scale": 200.0,
		"groove_strength": 0.5,
		"groove_size": 2.0,
		"bevel_strength": 1.2, "bevel_size": 2.0,
		"line_density": 0.0, "line_strength": 0.0,
		"_color": Color(0.35, 0.5, 0.7),
	})

	# 11. Hot Chrome — warmer gold-silver bands, punchy gleam
	_e("Ethnocentric — Hot Chrome", {
		"chrome_color_top": Color(0.08, 0.04, 0.02),
		"chrome_color_highlight1": Color(1.0, 0.85, 0.6),
		"chrome_color_mid": Color(0.12, 0.08, 0.04),
		"chrome_color_highlight2": Color(0.8, 0.65, 0.4),
		"chrome_color_bottom": Color(0.06, 0.03, 0.01),
		"bevel_light_color": Color(1.0, 0.9, 0.7),
		"gleam_width": 0.04,
		"gleam_intensity": 2.5,
		"bevel_strength": 1.4, "bevel_size": 2.2,
		"hdr_boost": 1.8,
		"_color": Color(0.9, 0.7, 0.4),
	})

	# 12. Razor + Grooves — knife-edge gleam with engraved surface
	_e("Ethnocentric — Razor Engraved", {
		"gleam_width": 0.02,
		"gleam_intensity": 3.0,
		"gleam_speed": 0.25,
		"groove_strength": 1.0,
		"groove_size": 2.8,
		"groove_color": Color(0.0, 0.01, 0.05, 1.0),
		"bevel_strength": 1.3, "bevel_size": 2.5,
		"line_density": 0.0, "line_strength": 0.0,
	})

	# 13. Monolith — very dark, extreme bevel, heavy extrusion
	_e("Ethnocentric — Monolith", {
		"chrome_color_top": Color(0.005, 0.01, 0.04),
		"chrome_color_highlight1": Color(0.3, 0.45, 0.7),
		"chrome_color_mid": Color(0.01, 0.02, 0.06),
		"chrome_color_highlight2": Color(0.2, 0.3, 0.5),
		"chrome_color_bottom": Color(0.005, 0.01, 0.03),
		"bevel_strength": 1.8, "bevel_size": 3.5,
		"bevel_light_color": Color(0.4, 0.6, 1.0),
		"extrusion_depth": 7.0,
		"extrusion_angle": 0.5,
		"extrusion_color": Color(0.005, 0.01, 0.04, 1.0),
		"shadow_offset_x": 5.0, "shadow_offset_y": 6.0, "shadow_softness": 6.0,
		"line_density": 0.0, "line_strength": 0.0,
		"hdr_boost": 1.6,
		"_color": Color(0.3, 0.5, 0.8),
	})

	# 14. Specular Slit + Extrusion — glossy raised block
	_e("Ethnocentric — Glossy Block", {
		"specular_enabled": 1.0,
		"specular_pos": 0.3,
		"specular_width": 0.02,
		"specular_intensity": 2.5,
		"extrusion_depth": 4.0,
		"extrusion_angle": 0.6,
		"extrusion_color": Color(0.01, 0.025, 0.08, 1.0),
		"bevel_strength": 1.2, "bevel_size": 2.2,
		"line_density": 50.0, "line_strength": 0.1,
	})

	# 15. Brushed + Grooves + Specular — full kitchen sink
	_e("Ethnocentric — Full Metal", {
		"surface_noise": 0.3,
		"surface_scale": 160.0,
		"groove_strength": 0.7,
		"groove_size": 2.2,
		"specular_enabled": 1.0,
		"specular_pos": 0.33,
		"specular_width": 0.025,
		"specular_intensity": 2.0,
		"bevel_strength": 1.5, "bevel_size": 2.5,
		"extrusion_depth": 3.0,
		"extrusion_angle": 0.7,
		"line_density": 0.0, "line_strength": 0.0,
		"hdr_boost": 1.6,
	})

	# ── KEPT FONTS (original shader) ────────────────────────────────
	_p("Bungee Inline", "res://assets/fonts/BungeeInline-Regular.ttf", 76)
	_p("Alumni Sans Pinstripe", "res://assets/fonts/AlumniSansPinstripe-Regular.ttf", 84)
	_p("Saira Stencil One", "res://assets/fonts/SairaStencilOne-Regular.ttf", 72)
	_p("Street Cred", "res://assets/fonts/StreetCred-Regular.otf", 72)
	_p("Empire State", "res://assets/fonts/EmpireState-Regular.ttf", 72)


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var header := Label.new()
	header.text = "TITLE STYLES — ETHNOCENTRIC 3D"
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

	var shader_path: String = preset.get("shader", SHADER_PATH) as String
	var shader: Shader = load(shader_path)
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var params: Dictionary = preset.get("params", {}) as Dictionary
		for key in params:
			if str(key).begins_with("_"):
				continue
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
