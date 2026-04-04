extends MarginContainer
## Destinations auditions — 4 destination types × 3 approaches, each with HDR glow slider.

var _shader_mats: Array[ShaderMaterial] = []

const CATEGORIES: Array[Dictionary] = [
	{
		"label": "NEON VOID RIFT",
		"shaders": [
			{"name": "A: GRID RIFT", "path": "res://assets/shaders/dest_neon_rift_grid.gdshader", "hdr": 3.0},
			{"name": "B: PORTAL VORTEX", "path": "res://assets/shaders/dest_neon_rift_portal.gdshader", "hdr": 3.5},
			{"name": "C: FRACTURE CRACKS", "path": "res://assets/shaders/dest_neon_rift_fracture.gdshader", "hdr": 3.0},
		],
	},
	{
		"label": "FLUID RIFT",
		"shaders": [
			{"name": "A: SPIRAL VORTEX", "path": "res://assets/shaders/dest_fluid_vortex.gdshader", "hdr": 3.0},
			{"name": "B: JELLYFISH TENDRILS", "path": "res://assets/shaders/dest_fluid_tendrils.gdshader", "hdr": 3.0},
			{"name": "C: AURORA CURTAINS", "path": "res://assets/shaders/dest_fluid_aurora.gdshader", "hdr": 3.0},
		],
	},
	{
		"label": "FIRE",
		"shaders": [
			{"name": "A: INFERNO MAW", "path": "res://assets/shaders/dest_fire_inferno.gdshader", "hdr": 3.5},
			{"name": "B: LAVA SPHERE", "path": "res://assets/shaders/dest_fire_lava.gdshader", "hdr": 3.5},
			{"name": "C: SOLAR PLASMA", "path": "res://assets/shaders/dest_fire_plasma.gdshader", "hdr": 4.0},
		],
	},
	{
		"label": "METALLIC PLANET",
		"shaders": [
			{"name": "A: CHROME SPHERE", "path": "res://assets/shaders/dest_planet_chrome.gdshader", "hdr": 3.0},
			{"name": "B: CIRCUIT WORLD", "path": "res://assets/shaders/dest_planet_circuit.gdshader", "hdr": 3.0},
			{"name": "C: FORTRESS WORLD", "path": "res://assets/shaders/dest_planet_fortress.gdshader", "hdr": 3.0},
		],
	},
]

const VP_SIZE := Vector2i(480, 300)


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
	main_col.add_theme_constant_override("separation", 16)
	scroll.add_child(main_col)

	for cat in CATEGORIES:
		_build_category(main_col, cat)


func _build_category(parent: VBoxContainer, cat: Dictionary) -> void:
	# Category header
	var header := Label.new()
	header.text = cat["label"] as String
	ThemeManager.apply_text_glow(header, "header")
	header.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	var hfont: Font = ThemeManager.get_font("font_header")
	if hfont:
		header.add_theme_font_override("font", hfont)
	header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	parent.add_child(header)

	# Row of 3 shader cells
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var shaders: Array = cat["shaders"] as Array
	for shader_def in shaders:
		_build_cell(row, shader_def as Dictionary)


func _build_cell(parent: HBoxContainer, def: Dictionary) -> void:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	parent.add_child(cell)

	# Shader viewport
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.custom_minimum_size.y = 300
	cell.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = VP_SIZE
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

	# Label + slider row
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 8)
	cell.add_child(ctrl_row)

	var name_lbl := Label.new()
	name_lbl.text = def["name"] as String
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeManager.apply_text_glow(name_lbl, "body")
	ctrl_row.add_child(name_lbl)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "HDR"
	ThemeManager.apply_text_glow(hdr_lbl, "body")
	ctrl_row.add_child(hdr_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 8.0
	slider.step = 0.1
	slider.value = float(def["hdr"])
	slider.custom_minimum_size = Vector2(120, 20)
	ctrl_row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.1f" % slider.value
	val_lbl.custom_minimum_size.x = 35
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ThemeManager.apply_text_glow(val_lbl, "body")
	ctrl_row.add_child(val_lbl)

	if mat:
		slider.value_changed.connect(func(v: float) -> void:
			mat.set_shader_parameter("hdr_intensity", v)
			val_lbl.text = "%.1f" % v
		)
