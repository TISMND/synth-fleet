extends MarginContainer
## Title auditions — shows aggressive 80s chrome title style presets for "SYNTHERION".
## Uses the title_chrome shader for multi-band metallic gradients, bevels, gleam, and shadow.

const TITLE_TEXT: String = "SYNTHERION"
const SHADER_PATH: String = "res://assets/shaders/title_chrome.gdshader"
const VP_W: int = 900
const VP_H: int = 140
const BG_COLOR: Color = Color(0.015, 0.015, 0.03, 1.0)

var _presets: Array[Dictionary] = []
var _scroll: ScrollContainer
var _grid: VBoxContainer


func _ready() -> void:
	_define_presets()
	_build_ui()
	ThemeManager.theme_changed.connect(func(): queue_redraw())


# Helper to reduce boilerplate — returns a NEON CHROME params dict
func _neon_chrome() -> Dictionary:
	return {
		"chrome_color_top": Color(0.02, 0.04, 0.12),
		"chrome_color_highlight1": Color(0.3, 0.7, 1.0),
		"chrome_color_mid": Color(0.08, 0.1, 0.2),
		"chrome_color_highlight2": Color(0.2, 0.5, 0.9),
		"chrome_color_bottom": Color(0.01, 0.02, 0.08),
		"band1_pos": 0.22, "band2_pos": 0.4, "band3_pos": 0.6, "band4_pos": 0.78,
		"band_sharpness": 18.0,
		"line_density": 60.0, "line_strength": 0.1,
		"bevel_strength": 0.6, "bevel_size": 1.5,
		"bevel_light_color": Color(0.3, 0.6, 1.0),
		"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 3.0,
		"shadow_color": Color(0.0, 0.05, 0.2, 0.8),
		"gleam_enabled": 1.0, "gleam_speed": 0.7, "gleam_width": 0.06, "gleam_intensity": 2.0,
		"hdr_boost": 1.8,
	}


func _cold_steel() -> Dictionary:
	return {
		"chrome_color_top": Color(0.05, 0.08, 0.15),
		"chrome_color_highlight1": Color(0.8, 0.88, 1.0),
		"chrome_color_mid": Color(0.1, 0.14, 0.22),
		"chrome_color_highlight2": Color(0.55, 0.65, 0.9),
		"chrome_color_bottom": Color(0.03, 0.05, 0.1),
		"band1_pos": 0.2, "band2_pos": 0.42, "band3_pos": 0.58, "band4_pos": 0.82,
		"band_sharpness": 15.0,
		"line_density": 90.0, "line_strength": 0.12,
		"bevel_strength": 0.9, "bevel_size": 1.8,
		"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 3.0,
		"shadow_color": Color(0.0, 0.02, 0.08, 0.85),
		"gleam_enabled": 1.0, "gleam_speed": 0.6, "gleam_width": 0.07, "gleam_intensity": 1.8,
		"hdr_boost": 1.3,
	}


func _midnight_ice() -> Dictionary:
	return {
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


func _define_presets() -> void:
	# ── 4 WINNERS ────────────────────────────────────────────────────

	_presets.append({"name": "NEON CHROME — Faster One", "font": "res://assets/fonts/FasterOne-Regular.ttf", "size": 68, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "COLD STEEL — Quantico", "font": "res://assets/fonts/Quantico-Bold.ttf", "size": 72, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "MIDNIGHT ICE — Black Ops One", "font": "res://assets/fonts/BlackOpsOne-Regular.ttf", "size": 72, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})
	_presets.append({"name": "NEON CHROME — Stalinist One", "font": "res://assets/fonts/StalinistOne-Regular.ttf", "size": 58, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})

	# ── NEW FONTS × WINNING STYLES ───────────────────────────────────

	# Tourney — armored plating, ultra-geometric sharp corners
	_presets.append({"name": "NEON CHROME — Tourney", "font": "res://assets/fonts/Tourney.ttf", "size": 72, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "COLD STEEL — Tourney", "font": "res://assets/fonts/Tourney.ttf", "size": 72, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "MIDNIGHT ICE — Tourney", "font": "res://assets/fonts/Tourney.ttf", "size": 72, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})

	# Oxanium — HUD/spaceship font, hexagonal clipped corners
	_presets.append({"name": "NEON CHROME — Oxanium", "font": "res://assets/fonts/Oxanium.ttf", "size": 72, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "MIDNIGHT ICE — Oxanium", "font": "res://assets/fonts/Oxanium.ttf", "size": 72, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})

	# Michroma — precise squared-off mechanical, 60s futurism
	_presets.append({"name": "COLD STEEL — Michroma", "font": "res://assets/fonts/Michroma-Regular.ttf", "size": 56, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "NEON CHROME — Michroma", "font": "res://assets/fonts/Michroma-Regular.ttf", "size": 56, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})

	# Electrolize — Russian metro sheet metal, modular industrial
	_presets.append({"name": "MIDNIGHT ICE — Electrolize", "font": "res://assets/fonts/Electrolize-Regular.ttf", "size": 72, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})
	_presets.append({"name": "COLD STEEL — Electrolize", "font": "res://assets/fonts/Electrolize-Regular.ttf", "size": 72, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})

	# Wallpoet — raw brutalist stencil, propaganda poster
	_presets.append({"name": "NEON CHROME — Wallpoet", "font": "res://assets/fonts/Wallpoet-Regular.ttf", "size": 68, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "MIDNIGHT ICE — Wallpoet", "font": "res://assets/fonts/Wallpoet-Regular.ttf", "size": 68, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})

	# Squada One — ultra-condensed heavy, stamped military markings
	_presets.append({"name": "COLD STEEL — Squada One", "font": "res://assets/fonts/SquadaOne-Regular.ttf", "size": 84, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "NEON CHROME — Squada One", "font": "res://assets/fonts/SquadaOne-Regular.ttf", "size": 84, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})

	# Chakra Petch Bold — cyberpunk mech-suit, angular tapered corners
	_presets.append({"name": "NEON CHROME — Chakra Petch", "font": "res://assets/fonts/ChakraPetch-Bold.ttf", "size": 72, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "COLD STEEL — Chakra Petch", "font": "res://assets/fonts/ChakraPetch-Bold.ttf", "size": 72, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})

	# Kenia — alien stencil, uncategorizable geometry
	_presets.append({"name": "MIDNIGHT ICE — Kenia", "font": "res://assets/fonts/Kenia-Regular.ttf", "size": 72, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})
	_presets.append({"name": "NEON CHROME — Kenia", "font": "res://assets/fonts/Kenia-Regular.ttf", "size": 72, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})

	# ── CROSS-POLLINATED: winner fonts in other winner styles ────────

	_presets.append({"name": "MIDNIGHT ICE — Faster One", "font": "res://assets/fonts/FasterOne-Regular.ttf", "size": 68, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})
	_presets.append({"name": "COLD STEEL — Faster One", "font": "res://assets/fonts/FasterOne-Regular.ttf", "size": 68, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "COLD STEEL — Stalinist One", "font": "res://assets/fonts/StalinistOne-Regular.ttf", "size": 58, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "MIDNIGHT ICE — Stalinist One", "font": "res://assets/fonts/StalinistOne-Regular.ttf", "size": 58, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})
	_presets.append({"name": "NEON CHROME — Black Ops One", "font": "res://assets/fonts/BlackOpsOne-Regular.ttf", "size": 72, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "COLD STEEL — Black Ops One", "font": "res://assets/fonts/BlackOpsOne-Regular.ttf", "size": 72, "color": Color(0.7, 0.8, 1.0), "params": _cold_steel()})
	_presets.append({"name": "NEON CHROME — Quantico", "font": "res://assets/fonts/Quantico-Bold.ttf", "size": 72, "color": Color(0.3, 0.6, 1.0), "params": _neon_chrome()})
	_presets.append({"name": "MIDNIGHT ICE — Quantico", "font": "res://assets/fonts/Quantico-Bold.ttf", "size": 72, "color": Color(0.4, 0.65, 1.0), "params": _midnight_ice()})


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var header := Label.new()
	header.text = "TITLE STYLES"
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

	# Preset name label
	var name_label := Label.new()
	name_label.text = str(preset["name"])
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	cell.add_child(name_label)

	# SubViewport for rendering the title with shader
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

	# Dark background inside viewport
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)

	# Title label
	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)

	var font_path: String = str(preset["font"])
	var font_res: Font = load(font_path)
	if font_res:
		title.add_theme_font_override("font", font_res)
	var font_size: int = int(preset["size"])
	title.add_theme_font_size_override("font_size", font_size)

	var color: Color = preset["color"] as Color
	title.add_theme_color_override("font_color", color)

	# Apply title chrome shader
	var shader: Shader = load(SHADER_PATH)
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var params: Dictionary = preset.get("params", {}) as Dictionary
		for key in params:
			mat.set_shader_parameter(key, params[key])
		title.material = mat

	svp.add_child(title)

	# Add bloom to the viewport
	VFXFactory.add_bloom_to_viewport(svp)

	# Thin separator line
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 1)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.12, 0.15, 0.22, 0.4)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	cell.add_child(sep)
