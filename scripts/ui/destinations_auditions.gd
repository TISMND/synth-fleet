extends MarginContainer
## Destinations auditions — single destinations + man-made experiments.

var _shader_mats: Array[ShaderMaterial] = []

const SINGLES: Array[Dictionary] = [
	{"label": "NEON VOID RIFT", "path": "res://assets/shaders/dest_neon_void.gdshader", "hdr": 3.0},
	{"label": "FLUID RIFT", "path": "res://assets/shaders/dest_fluid_rift.gdshader", "hdr": 3.0},
	{"label": "FIRE", "path": "res://assets/shaders/dest_fire.gdshader", "hdr": 3.5},
]

const MANMADE: Array[Dictionary] = [
	{"label": "MONOLITH", "path": "res://assets/shaders/dest_monolith.gdshader", "hdr": 3.0},
	{"label": "CHROME RING", "path": "res://assets/shaders/dest_chrome_ring.gdshader", "hdr": 3.0},
	{"label": "RIFT GATE", "path": "res://assets/shaders/dest_rift_gate.gdshader", "hdr": 3.0},
	{"label": "DEBRIS SWIRL", "path": "res://assets/shaders/dest_debris_swirl.gdshader", "hdr": 3.0},
	{"label": "HIVE", "path": "res://assets/shaders/dest_hive.gdshader", "hdr": 3.0},
]

const VP_SIZE_LARGE := Vector2i(960, 480)
const VP_SIZE_MANMADE := Vector2i(640, 420)


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
	main_col.add_theme_constant_override("separation", 14)
	scroll.add_child(main_col)

	# ── Singles: 2 + 1 ──
	var singles_row1 := HBoxContainer.new()
	singles_row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	singles_row1.add_theme_constant_override("separation", 14)
	main_col.add_child(singles_row1)
	_build_cell(singles_row1, SINGLES[0], VP_SIZE_LARGE, 400)
	_build_cell(singles_row1, SINGLES[1], VP_SIZE_LARGE, 400)

	var singles_row2 := HBoxContainer.new()
	singles_row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	singles_row2.add_theme_constant_override("separation", 14)
	main_col.add_child(singles_row2)
	_build_cell(singles_row2, SINGLES[2], VP_SIZE_LARGE, 400)

	# ── Man-made experiments header ──
	var mm_header := Label.new()
	mm_header.text = "── MAN-MADE EXPERIMENTS ──"
	ThemeManager.apply_text_glow(mm_header, "header")
	mm_header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	var hfont: Font = ThemeManager.get_font("font_header")
	if hfont:
		mm_header.add_theme_font_override("font", hfont)
	mm_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	main_col.add_child(mm_header)

	# ── Man-made: 3 per row ──
	for row_idx in range(0, MANMADE.size(), 3):
		var mm_row := HBoxContainer.new()
		mm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mm_row.add_theme_constant_override("separation", 12)
		main_col.add_child(mm_row)
		for col_idx in range(3):
			var idx: int = row_idx + col_idx
			if idx < MANMADE.size():
				_build_cell(mm_row, MANMADE[idx], VP_SIZE_MANMADE, 320)


func _build_cell(parent: HBoxContainer, def: Dictionary, vp_size: Vector2i, min_h: int) -> void:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	parent.add_child(cell)

	# Header
	var header := Label.new()
	header.text = def["label"] as String
	ThemeManager.apply_text_glow(header, "body")
	cell.add_child(header)

	# Shader viewport
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.custom_minimum_size.y = min_h
	cell.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	# Shader rect
	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader_path: String = def["path"] as String
	var shader: Shader = load(shader_path) as Shader
	var mat: ShaderMaterial = null
	if shader:
		mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("hdr_intensity", float(def["hdr"]))
		shader_rect.material = mat
		_shader_mats.append(mat)
	vp.add_child(shader_rect)

	# HDR slider row
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 6)
	cell.add_child(ctrl_row)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "HDR"
	ThemeManager.apply_text_glow(hdr_lbl, "body")
	ctrl_row.add_child(hdr_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 8.0
	slider.step = 0.1
	slider.value = float(def["hdr"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(80, 20)
	ctrl_row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.1f" % slider.value
	val_lbl.custom_minimum_size.x = 30
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ThemeManager.apply_text_glow(val_lbl, "body")
	ctrl_row.add_child(val_lbl)

	if mat:
		slider.value_changed.connect(func(v: float) -> void:
			mat.set_shader_parameter("hdr_intensity", v)
			val_lbl.text = "%.1f" % v
		)
