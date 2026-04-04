extends MarginContainer
## Verse Select UI auditions — 5 frame/arrow styles wrapping destination viewports.
## Each concept has left/right arrows to cycle through destinations.

var _concept_states: Array[Dictionary] = []

const DESTINATIONS: Array[Dictionary] = [
	{"label": "NEON VOID RIFT", "path": "res://assets/shaders/dest_neon_void.gdshader", "hdr": 3.0},
	{"label": "FLUID RIFT", "path": "res://assets/shaders/dest_fluid_rift.gdshader", "hdr": 3.0},
	{"label": "FIRE", "path": "res://assets/shaders/dest_fire.gdshader", "hdr": 3.5},
	{"label": "HAMMERED IRON", "path": "res://assets/shaders/dest_planet_hammered.gdshader", "hdr": 3.0},
	{"label": "FROZEN STEEL", "path": "res://assets/shaders/dest_planet_frozen.gdshader", "hdr": 3.0},
	{"label": "COPPER PATINA", "path": "res://assets/shaders/dest_planet_copper.gdshader", "hdr": 3.0},
	{"label": "OBSIDIAN MIRROR", "path": "res://assets/shaders/dest_planet_obsidian.gdshader", "hdr": 3.0},
	{"label": "VOLCANIC METAL", "path": "res://assets/shaders/dest_planet_volcanic.gdshader", "hdr": 3.5},
]

const VP_SIZE := Vector2i(800, 450)
const VP_HEIGHT := 380

# ── Concept definitions ──
const CONCEPTS: Array[Dictionary] = [
	{
		"label": "HOLOGRAPHIC",
		"desc": "Glitchy holo-projection frame. Scan-line border, corner brackets, data sweep.",
		"frame_shader": "res://assets/shaders/verse_frame_holographic.gdshader",
		"arrow_left": "◁ ◁",
		"arrow_right": "▷ ▷",
		"arrow_font_size": 28,
		"frame_margin": 28,
	},
	{
		"label": "NEON",
		"desc": "Hot neon tube border. Glowing pink/cyan edges, corner accents, traveling light.",
		"frame_shader": "res://assets/shaders/verse_frame_neon.gdshader",
		"arrow_left": "⟨",
		"arrow_right": "⟩",
		"arrow_font_size": 52,
		"frame_margin": 26,
	},
	{
		"label": "METAL",
		"desc": "Brushed gunmetal frame with rivets. Industrial, heavy, tactile.",
		"frame_shader": "res://assets/shaders/verse_frame_metal.gdshader",
		"arrow_left": "◀",
		"arrow_right": "▶",
		"arrow_font_size": 32,
		"frame_margin": 32,
	},
	{
		"label": "SIMPLE",
		"desc": "Clean minimal border. Thin accent line, understated.",
		"frame_shader": "",
		"arrow_left": "‹",
		"arrow_right": "›",
		"arrow_font_size": 48,
		"frame_margin": 6,
	},
	{
		"label": "NOTHING",
		"desc": "No frame. Content bleeds to edges. Ghost arrows.",
		"frame_shader": "",
		"arrow_left": "←",
		"arrow_right": "→",
		"arrow_font_size": 24,
		"frame_margin": 0,
	},
]


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

	for i in CONCEPTS.size():
		_build_concept(main_col, CONCEPTS[i], i)


func _build_concept(parent: VBoxContainer, def: Dictionary, concept_idx: int) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	# Header + description
	var title := Label.new()
	title.text = def["label"] as String
	ThemeManager.apply_text_glow(title, "header")
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	var hfont: Font = ThemeManager.get_font("font_header")
	if hfont:
		title.add_theme_font_override("font", hfont)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	section.add_child(title)

	var desc := Label.new()
	desc.text = def["desc"] as String
	ThemeManager.apply_text_glow(desc, "body")
	desc.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	section.add_child(desc)

	# Main row: [left arrow] [viewport+frame] [right arrow]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(row)

	# Left arrow
	var left_btn := Button.new()
	left_btn.text = def["arrow_left"] as String
	left_btn.custom_minimum_size = Vector2(70, VP_HEIGHT)
	_style_arrow(left_btn, def, concept_idx)
	row.add_child(left_btn)

	# Viewport area with frame
	var frame_margin: int = int(def["frame_margin"])
	var frame_container := Control.new()
	frame_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_container.custom_minimum_size = Vector2(0, VP_HEIGHT + frame_margin * 2)
	row.add_child(frame_container)

	# SubViewportContainer fills the frame area (with margin for frame border)
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

	var bg := ColorRect.new()
	bg.color = Color(0.005, 0.005, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(shader_rect)

	# Load initial destination
	var dest: Dictionary = DESTINATIONS[0]
	var shader: Shader = load(dest["path"] as String) as Shader
	var mat := ShaderMaterial.new()
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("hdr_intensity", float(dest["hdr"]))
	shader_rect.material = mat

	# Frame overlay (shader or simple border)
	var frame_shader_path: String = def["frame_shader"] as String
	if frame_shader_path != "":
		var frame_overlay := ColorRect.new()
		frame_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		frame_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame_shader: Shader = load(frame_shader_path) as Shader
		if frame_shader:
			var frame_mat := ShaderMaterial.new()
			frame_mat.shader = frame_shader
			frame_overlay.material = frame_mat
		frame_container.add_child(frame_overlay)
	elif def["label"] == "SIMPLE":
		# Simple: thin accent border via Panel + StyleBoxFlat
		var border_panel := Panel.new()
		border_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sbox := StyleBoxFlat.new()
		sbox.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		sbox.border_color = ThemeManager.get_color("accent")
		sbox.border_width_left = 1
		sbox.border_width_right = 1
		sbox.border_width_top = 1
		sbox.border_width_bottom = 1
		border_panel.add_theme_stylebox_override("panel", sbox)
		frame_container.add_child(border_panel)

	# Right arrow
	var right_btn := Button.new()
	right_btn.text = def["arrow_right"] as String
	right_btn.custom_minimum_size = Vector2(70, VP_HEIGHT)
	_style_arrow(right_btn, def, concept_idx)
	row.add_child(right_btn)

	# Destination name label
	var dest_label := Label.new()
	dest_label.text = dest["label"] as String
	dest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(dest_label, "body")
	dest_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		dest_label.add_theme_font_override("font", hfont)
	dest_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	section.add_child(dest_label)

	# Counter label (e.g. "1 / 8")
	var counter := Label.new()
	counter.text = "1 / %d" % DESTINATIONS.size()
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(counter, "body")
	counter.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	section.add_child(counter)

	# Store state
	var state := {
		"index": 0,
		"mat": mat,
		"dest_label": dest_label,
		"counter": counter,
	}
	_concept_states.append(state)

	# Connect arrows
	var ci: int = concept_idx
	left_btn.pressed.connect(func() -> void: _cycle(ci, -1))
	right_btn.pressed.connect(func() -> void: _cycle(ci, 1))


func _cycle(concept_idx: int, direction: int) -> void:
	var state: Dictionary = _concept_states[concept_idx]
	var cur: int = int(state["index"])
	var new_idx: int = (cur + direction) % DESTINATIONS.size()
	if new_idx < 0:
		new_idx += DESTINATIONS.size()
	state["index"] = new_idx

	var dest: Dictionary = DESTINATIONS[new_idx]
	var mat: ShaderMaterial = state["mat"] as ShaderMaterial
	var shader: Shader = load(dest["path"] as String) as Shader
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("hdr_intensity", float(dest["hdr"]))

	var dest_label: Label = state["dest_label"] as Label
	dest_label.text = dest["label"] as String

	var counter: Label = state["counter"] as Label
	counter.text = "%d / %d" % [new_idx + 1, DESTINATIONS.size()]


func _style_arrow(btn: Button, def: Dictionary, concept_idx: int) -> void:
	var font_size: int = int(def["arrow_font_size"])
	btn.add_theme_font_size_override("font_size", font_size)

	var label_text: String = def["label"] as String

	match label_text:
		"HOLOGRAPHIC":
			# Cyan translucent buttons, no background
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.0, 0.15, 0.2, 0.3)
			sbox.border_color = Color(0.2, 0.7, 1.0, 0.6)
			sbox.border_width_left = 1
			sbox.border_width_right = 1
			sbox.border_width_top = 1
			sbox.border_width_bottom = 1
			sbox.corner_radius_top_left = 2
			sbox.corner_radius_top_right = 2
			sbox.corner_radius_bottom_left = 2
			sbox.corner_radius_bottom_right = 2
			btn.add_theme_stylebox_override("normal", sbox)
			var hover := sbox.duplicate() as StyleBoxFlat
			hover.bg_color = Color(0.0, 0.2, 0.3, 0.5)
			hover.border_color = Color(0.3, 0.8, 1.0, 0.9)
			btn.add_theme_stylebox_override("hover", hover)
			var pressed := sbox.duplicate() as StyleBoxFlat
			pressed.bg_color = Color(0.0, 0.3, 0.4, 0.6)
			btn.add_theme_stylebox_override("pressed", pressed)
			btn.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 0.8))
			btn.add_theme_color_override("font_hover_color", Color(0.5, 0.9, 1.0, 1.0))

		"NEON":
			# Big glowing neon buttons — hot pink
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.2, 0.0, 0.1, 0.4)
			sbox.border_color = Color(1.0, 0.1, 0.5, 0.8)
			sbox.border_width_left = 2
			sbox.border_width_right = 2
			sbox.border_width_top = 2
			sbox.border_width_bottom = 2
			sbox.corner_radius_top_left = 6
			sbox.corner_radius_top_right = 6
			sbox.corner_radius_bottom_left = 6
			sbox.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", sbox)
			var hover := sbox.duplicate() as StyleBoxFlat
			hover.bg_color = Color(0.3, 0.0, 0.15, 0.6)
			hover.border_color = Color(1.0, 0.2, 0.6, 1.0)
			btn.add_theme_stylebox_override("hover", hover)
			var pressed := sbox.duplicate() as StyleBoxFlat
			pressed.bg_color = Color(0.4, 0.0, 0.2, 0.7)
			btn.add_theme_stylebox_override("pressed", pressed)
			btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.6, 0.9))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.7, 1.0))

		"METAL":
			# Chunky embossed metal buttons
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.2, 0.22, 0.25, 0.9)
			sbox.border_color = Color(0.4, 0.42, 0.48, 0.8)
			sbox.border_width_left = 2
			sbox.border_width_right = 2
			sbox.border_width_top = 2
			sbox.border_width_bottom = 3
			sbox.corner_radius_top_left = 3
			sbox.corner_radius_top_right = 3
			sbox.corner_radius_bottom_left = 3
			sbox.corner_radius_bottom_right = 3
			btn.add_theme_stylebox_override("normal", sbox)
			var hover := sbox.duplicate() as StyleBoxFlat
			hover.bg_color = Color(0.28, 0.3, 0.34, 0.95)
			hover.border_color = Color(0.5, 0.55, 0.6, 0.9)
			btn.add_theme_stylebox_override("hover", hover)
			var pressed := sbox.duplicate() as StyleBoxFlat
			pressed.bg_color = Color(0.15, 0.16, 0.18, 0.95)
			pressed.border_width_top = 3
			pressed.border_width_bottom = 2
			btn.add_theme_stylebox_override("pressed", pressed)
			btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78, 0.9))
			btn.add_theme_color_override("font_hover_color", Color(0.85, 0.87, 0.92, 1.0))

		"SIMPLE":
			# Minimal thin border
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			sbox.border_color = ThemeManager.get_color("accent").darkened(0.5)
			sbox.border_width_left = 0
			sbox.border_width_right = 0
			sbox.border_width_top = 0
			sbox.border_width_bottom = 0
			btn.add_theme_stylebox_override("normal", sbox)
			var hover := sbox.duplicate() as StyleBoxFlat
			hover.border_color = ThemeManager.get_color("accent")
			hover.border_width_left = 1
			hover.border_width_right = 1
			hover.border_width_top = 1
			hover.border_width_bottom = 1
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", hover)
			btn.add_theme_color_override("font_color", ThemeManager.get_color("text").darkened(0.2))
			btn.add_theme_color_override("font_hover_color", ThemeManager.get_color("accent"))

		"NOTHING":
			# Nearly invisible ghost arrows
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			sbox.border_color = Color(0.0, 0.0, 0.0, 0.0)
			btn.add_theme_stylebox_override("normal", sbox)
			btn.add_theme_stylebox_override("hover", sbox)
			btn.add_theme_stylebox_override("pressed", sbox)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.15))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.4))
			btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.6))
