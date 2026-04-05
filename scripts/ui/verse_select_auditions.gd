extends MarginContainer
## Verse Select frame auditions — 4 copies of the mission-prep verse selector,
## each with a different border treatment for comparison.

const VERSES: Array[Dictionary] = [
	{"label": "TUTORIAL", "shader": "", "hdr": 0.0},
	{"label": "NEON RIFT", "shader": "res://assets/shaders/dest_neon_void.gdshader", "hdr": 3.0},
	{"label": "FLUID", "shader": "res://assets/shaders/dest_fluid_rift.gdshader", "hdr": 3.0},
]

const VP_SIZE := Vector2i(800, 450)

const FRAME_CONCEPTS: Array[Dictionary] = [
	{
		"label": "NEON GLOW",
		"desc": "Thick HDR neon border with blooming glow. White-hot core.",
		"shader": "res://assets/shaders/verse_frame_neon_glow.gdshader",
	},
	{
		"label": "PULSE CORNERS",
		"desc": "Slender L-brackets that breathe and pulse. Targeting reticle feel.",
		"shader": "res://assets/shaders/verse_frame_pulse_corners.gdshader",
	},
	{
		"label": "ELEGANT LINES",
		"desc": "Hairline double border with subtle glow. Refined, minimal.",
		"shader": "res://assets/shaders/verse_frame_elegant.gdshader",
	},
	{
		"label": "NEON TRACE",
		"desc": "Bright traces race along the border like circuit paths. HDR bloom.",
		"shader": "res://assets/shaders/verse_frame_neon_trace.gdshader",
	},
]

# Per-concept state: verse_index, shader_mat, grid_overlay, labels
var _states: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var main_col := VBoxContainer.new()
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_theme_constant_override("separation", 30)
	scroll.add_child(main_col)

	for i in FRAME_CONCEPTS.size():
		_build_concept(main_col, FRAME_CONCEPTS[i], i)


func _build_concept(parent: VBoxContainer, def: Dictionary, idx: int) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var hfont: Font = ThemeManager.get_font("font_header")

	# Header
	var title := Label.new()
	title.text = def["label"] as String
	ThemeManager.apply_text_glow(title, "header")
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		title.add_theme_font_override("font", hfont)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	section.add_child(title)

	var desc := Label.new()
	desc.text = def["desc"] as String
	ThemeManager.apply_text_glow(desc, "body")
	desc.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	section.add_child(desc)

	# Preview container — dimensions matching mission prep proportions
	var preview_width: int = 1000
	var preview_height: int = 580
	var frame_margin: int = 28

	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(center_wrap)

	var frame_container := Control.new()
	frame_container.custom_minimum_size = Vector2(preview_width, preview_height)
	center_wrap.add_child(frame_container)

	# SubViewportContainer
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.offset_left = frame_margin
	vpc.offset_top = frame_margin
	vpc.offset_right = -frame_margin
	vpc.offset_bottom = -frame_margin
	frame_container.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = VP_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.005, 0.005, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	# Destination shader rect
	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(shader_rect)

	var verse_mat := ShaderMaterial.new()
	shader_rect.material = verse_mat

	# Grid overlay for Tutorial
	var grid_overlay := ColorRect.new()
	grid_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(grid_overlay)
	ThemeManager.apply_grid_background(grid_overlay)

	# Frame shader overlay — sits just outside viewport so brackets frame it
	var bracket_outset: int = 8
	var frame_shader_path: String = def["shader"] as String
	if frame_shader_path != "":
		var frame_overlay := ColorRect.new()
		frame_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
		frame_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_overlay.offset_left = frame_margin - bracket_outset
		frame_overlay.offset_top = frame_margin - bracket_outset
		frame_overlay.offset_right = -(frame_margin - bracket_outset)
		frame_overlay.offset_bottom = -(frame_margin - bracket_outset)
		frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame_shader: Shader = load(frame_shader_path) as Shader
		if frame_shader:
			var frame_mat := ShaderMaterial.new()
			frame_mat.shader = frame_shader
			frame_overlay.material = frame_mat
		frame_container.add_child(frame_overlay)

	# ── UI overlay inside the frame ──
	var ui_overlay := MarginContainer.new()
	ui_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_overlay.offset_left = frame_margin
	ui_overlay.offset_top = frame_margin
	ui_overlay.offset_right = -frame_margin
	ui_overlay.offset_bottom = -frame_margin
	ui_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_overlay.add_theme_constant_override("margin_left", 16)
	ui_overlay.add_theme_constant_override("margin_top", 12)
	ui_overlay.add_theme_constant_override("margin_right", 16)
	ui_overlay.add_theme_constant_override("margin_bottom", 12)
	frame_container.add_child(ui_overlay)

	var inner_col := VBoxContainer.new()
	inner_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_overlay.add_child(inner_col)

	# "SELECT VERSE" title inside viewport
	var vp_title := Label.new()
	vp_title.text = "SELECT VERSE"
	vp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(vp_title, "header")
	vp_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		vp_title.add_theme_font_override("font", hfont)
	vp_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	inner_col.add_child(vp_title)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(top_spacer)

	# Arrow row
	var arrow_row := HBoxContainer.new()
	arrow_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(arrow_row)

	var left_btn := Button.new()
	left_btn.text = "\u25C1 \u25C1"
	left_btn.custom_minimum_size = Vector2(70, 100)
	_style_holo_arrow(left_btn)
	var ci: int = idx
	left_btn.pressed.connect(func() -> void: _cycle(ci, -1))
	arrow_row.add_child(left_btn)

	var arrow_spacer := Control.new()
	arrow_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_row.add_child(arrow_spacer)

	var right_btn := Button.new()
	right_btn.text = "\u25B7 \u25B7"
	right_btn.custom_minimum_size = Vector2(70, 100)
	_style_holo_arrow(right_btn)
	right_btn.pressed.connect(func() -> void: _cycle(ci, 1))
	arrow_row.add_child(right_btn)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(bottom_spacer)

	# Verse name label
	var verse_label := Label.new()
	verse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verse_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(verse_label, "body")
	verse_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		verse_label.add_theme_font_override("font", hfont)
	verse_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	inner_col.add_child(verse_label)

	# Counter label
	var counter := Label.new()
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(counter, "body")
	counter.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	inner_col.add_child(counter)

	# Store state
	var state := {
		"index": 0,
		"mat": verse_mat,
		"grid": grid_overlay,
		"verse_label": verse_label,
		"counter": counter,
	}
	_states.append(state)

	# Apply initial verse
	_apply_verse(idx)


func _cycle(concept_idx: int, direction: int) -> void:
	var state: Dictionary = _states[concept_idx]
	var cur: int = int(state["index"])
	var new_idx: int = (cur + direction) % VERSES.size()
	if new_idx < 0:
		new_idx += VERSES.size()
	state["index"] = new_idx
	_apply_verse(concept_idx)


func _apply_verse(concept_idx: int) -> void:
	var state: Dictionary = _states[concept_idx]
	var vi: int = int(state["index"])
	var verse: Dictionary = VERSES[vi]
	var shader_path: String = verse["shader"] as String
	var mat: ShaderMaterial = state["mat"] as ShaderMaterial
	var grid: ColorRect = state["grid"] as ColorRect

	if shader_path != "":
		var shader: Shader = load(shader_path) as Shader
		if shader:
			mat.shader = shader
			mat.set_shader_parameter("hdr_intensity", float(verse["hdr"]))
		grid.visible = false
	else:
		mat.shader = null
		grid.visible = true

	var verse_label: Label = state["verse_label"] as Label
	verse_label.text = verse["label"] as String

	var counter: Label = state["counter"] as Label
	counter.text = "%d / %d" % [vi + 1, VERSES.size()]


func _style_holo_arrow(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 28)

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.18, 0.04, 0.1, 0.85)
	sbox.border_color = Color(0.9, 0.15, 0.5, 0.7)
	sbox.border_width_left = 2
	sbox.border_width_right = 2
	sbox.border_width_top = 2
	sbox.border_width_bottom = 2
	sbox.corner_radius_top_left = 4
	sbox.corner_radius_top_right = 4
	sbox.corner_radius_bottom_left = 4
	sbox.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sbox)

	var hover := sbox.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.06, 0.15, 0.92)
	hover.border_color = Color(1.0, 0.25, 0.6, 0.9)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := sbox.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.35, 0.08, 0.2, 0.95)
	pressed.border_color = Color(1.0, 0.3, 0.65, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.65, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.75, 1.0))
