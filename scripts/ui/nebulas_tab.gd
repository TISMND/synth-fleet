extends MarginContainer
## Nebulas audition tab — 4x3 grid of shader-driven nebula previews with keep/discard toggles.

const COLUMNS := 4
const CELL_WIDTH := 280
const CELL_HEIGHT := 200
const CELL_SPACING := 12

var _keep_state: Dictionary = {}
var _buttons: Dictionary = {}

var _nebula_defs: Array[Dictionary] = [
	{"id": "classic_fbm", "name": "Classic FBM", "shader": "res://assets/shaders/nebula_classic_fbm.gdshader", "color": Color(0.3, 0.4, 0.9)},
	{"id": "wispy_filaments", "name": "Wispy Filaments", "shader": "res://assets/shaders/nebula_wispy_filaments.gdshader", "color": Color(0.8, 0.3, 0.6)},
	{"id": "dual_color", "name": "Dual Color", "shader": "res://assets/shaders/nebula_dual_color.gdshader", "color": Color(0.2, 0.5, 1.0)},
	{"id": "voronoi", "name": "Voronoi Cells", "shader": "res://assets/shaders/nebula_voronoi.gdshader", "color": Color(0.4, 0.9, 0.5)},
	{"id": "turbulent_swirl", "name": "Turbulent Swirl", "shader": "res://assets/shaders/nebula_turbulent_swirl.gdshader", "color": Color(0.6, 0.2, 0.9)},
	{"id": "electric_filaments", "name": "Electric Filaments", "shader": "res://assets/shaders/nebula_electric_filaments.gdshader", "color": Color(0.3, 0.8, 1.0)},
	{"id": "lightning_strike", "name": "Lightning Strike", "shader": "res://assets/shaders/nebula_lightning_strike.gdshader", "color": Color(0.5, 0.6, 1.0)},
	{"id": "arc_discharge", "name": "Arc Discharge", "shader": "res://assets/shaders/nebula_arc_discharge.gdshader", "color": Color(0.3, 0.7, 1.0)},
	{"id": "energy_flare", "name": "Energy Flare", "shader": "res://assets/shaders/nebula_energy_flare.gdshader", "color": Color(1.0, 0.6, 0.2)},
	{"id": "dual_swirl", "name": "Dual Swirl", "shader": "res://assets/shaders/nebula_dual_swirl.gdshader", "color": Color(0.6, 0.2, 0.9)},
	{"id": "dual_voronoi", "name": "Dual Voronoi", "shader": "res://assets/shaders/nebula_dual_voronoi.gdshader", "color": Color(0.4, 0.9, 0.5)},
]


func _ready() -> void:
	for def in _nebula_defs:
		var id: String = def["id"]
		_keep_state[id] = true

	_build_grid()
	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")


func _build_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", CELL_SPACING)
	grid.add_theme_constant_override("v_separation", CELL_SPACING)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for def in _nebula_defs:
		var cell := _build_cell(def)
		grid.add_child(cell)


func _build_cell(def: Dictionary) -> VBoxContainer:
	var id: String = def["id"]
	var shader_path: String = def["shader"]
	var color: Color = def["color"]

	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)

	# Shader preview
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(CELL_WIDTH, CELL_HEIGHT)
	preview.color = Color(0, 0, 0, 1)
	var shader_res: Shader = load(shader_path) as Shader
	if shader_res:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("nebula_color", Color(color.r, color.g, color.b, 1.0))
		preview.material = mat
	cell.add_child(preview)

	# Name label
	var label := Label.new()
	label.text = def["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)

	# Keep/Discard button
	var btn := Button.new()
	btn.text = "KEEP"
	btn.toggle_mode = true
	btn.button_pressed = true
	btn.pressed.connect(_on_toggle.bind(id, btn))
	cell.add_child(btn)
	_buttons[id] = btn

	return cell


func _on_toggle(id: String, btn: Button) -> void:
	var kept: bool = btn.button_pressed
	_keep_state[id] = kept
	_style_toggle_button(btn, kept)


func _style_toggle_button(btn: Button, kept: bool) -> void:
	if kept:
		btn.text = "KEEP"
		btn.modulate = Color(0.3, 1.0, 0.4)
	else:
		btn.text = "DISCARD"
		btn.modulate = Color(1.0, 0.3, 0.3, 0.6)


func _apply_theme() -> void:
	for child in get_children():
		if child is ScrollContainer:
			var grid: GridContainer = child.get_child(0) as GridContainer
			if not grid:
				continue
			for cell_node in grid.get_children():
				if cell_node is VBoxContainer:
					for sub in cell_node.get_children():
						if sub is Label:
							ThemeManager.apply_text_glow(sub, "body")
						elif sub is Button:
							ThemeManager.apply_button_style(sub)

	# Re-apply keep/discard styling on top of theme
	for id in _buttons:
		var btn: Button = _buttons[id]
		var kept: bool = _keep_state[id]
		_style_toggle_button(btn, kept)
