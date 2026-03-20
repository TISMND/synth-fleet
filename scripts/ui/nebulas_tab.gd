extends MarginContainer
## Nebula definition editor — create named nebulas, pick a shader style, tweak parameters.

const STYLES: Dictionary = {
	"classic_fbm": {"name": "Classic FBM", "shader": "res://assets/shaders/nebula_classic_fbm.gdshader", "dual": false},
	"wispy_filaments": {"name": "Wispy Filaments", "shader": "res://assets/shaders/nebula_wispy_filaments.gdshader", "dual": false},
	"dual_color": {"name": "Dual Color", "shader": "res://assets/shaders/nebula_dual_color.gdshader", "dual": true},
	"voronoi": {"name": "Voronoi Cells", "shader": "res://assets/shaders/nebula_voronoi.gdshader", "dual": false},
	"turbulent_swirl": {"name": "Turbulent Swirl", "shader": "res://assets/shaders/nebula_turbulent_swirl.gdshader", "dual": false},
	"electric_filaments": {"name": "Electric Filaments", "shader": "res://assets/shaders/nebula_electric_filaments.gdshader", "dual": false},
	"lightning_strike": {"name": "Lightning Strike", "shader": "res://assets/shaders/nebula_lightning_strike.gdshader", "dual": false},
	"arc_discharge": {"name": "Arc Discharge", "shader": "res://assets/shaders/nebula_arc_discharge.gdshader", "dual": false},
	"energy_flare": {"name": "Energy Flare", "shader": "res://assets/shaders/nebula_energy_flare.gdshader", "dual": false},
	"dual_swirl": {"name": "Dual Swirl", "shader": "res://assets/shaders/nebula_dual_swirl.gdshader", "dual": true},
	"dual_voronoi": {"name": "Dual Voronoi", "shader": "res://assets/shaders/nebula_dual_voronoi.gdshader", "dual": true},
}

var _style_keys: Array[String] = []  # ordered list of style ids for OptionButton indexing
var _nebulas: Array[NebulaData] = []
var _selected_id: String = ""
var _suppressing_signals: bool = false

# UI refs
var _list_container: VBoxContainer
var _create_btn: Button
var _delete_btn: Button
var _preview_rect: ColorRect
var _name_edit: LineEdit
var _style_option: OptionButton
var _params_container: VBoxContainer
var _editor_panel: VBoxContainer
var _empty_label: Label

# Param control refs (rebuilt on style change)
var _color_picker: ColorPickerButton
var _color2_picker: ColorPickerButton
var _color2_row: HBoxContainer
var _brightness_slider: HSlider
var _speed_slider: HSlider
var _density_slider: HSlider
var _seed_slider: HSlider
var _brightness_value: Label
var _speed_value: Label
var _density_value: Label
var _seed_value: Label
var _spread_slider: HSlider
var _spread_value: Label
var _bottom_opacity_slider: HSlider
var _bottom_opacity_value: Label
var _top_opacity_slider: HSlider
var _top_opacity_value: Label

# Bar effects spinboxes
var _bar_effect_spinboxes: Dictionary = {}  # bar_name -> SpinBox
var _effects_container: VBoxContainer

# Special effects checkboxes
var _special_effect_checks: Dictionary = {}  # effect_id -> CheckBox
const KNOWN_SPECIAL_EFFECTS: Array[String] = ["cloak", "slow", "damage_boost"]

# Music effects
var _key_shift_slider: HSlider
var _key_shift_value: Label

# Preview layering refs
var _preview_container: Control  # Holds bottom nebula, ship, top veil
var _preview_bottom: ColorRect
var _preview_ship: ShipRenderer
var _preview_top: ColorRect


func _ready() -> void:
	# Build ordered style key list
	for key in STYLES:
		_style_keys.append(key)

	_nebulas = NebulaDataManager.load_all()
	_build_ui()

	if _nebulas.size() > 0:
		_select_nebula(_nebulas[0].id)
	else:
		_show_empty_state()

	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")
	call_deferred("_center_preview_ship")


func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 300
	add_child(split)

	# --- Left panel: nebula list ---
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size.x = 280
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 8)
	split.add_child(left_panel)

	var header := Label.new()
	header.text = "NEBULAS"
	header.name = "ListHeader"
	left_panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_container)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	left_panel.add_child(btn_row)

	_create_btn = Button.new()
	_create_btn.text = "+ CREATE NEW"
	_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_btn.pressed.connect(_on_create_new)
	btn_row.add_child(_create_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "DELETE"
	_delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete)
	btn_row.add_child(_delete_btn)

	# --- Right panel: editor ---
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	_editor_panel = VBoxContainer.new()
	_editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_panel.add_theme_constant_override("separation", 12)
	right_scroll.add_child(_editor_panel)

	# Preview — layered: black bg, bottom nebula, ship, top nebula veil
	_preview_container = Control.new()
	_preview_container.custom_minimum_size = Vector2(400, 300)
	_preview_container.clip_contents = true
	_editor_panel.add_child(_preview_container)

	# Black background
	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0, 0, 0, 1)
	preview_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_container.add_child(preview_bg)

	# Bottom nebula layer
	_preview_bottom = ColorRect.new()
	_preview_bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_bottom.color = Color.WHITE
	_preview_container.add_child(_preview_bottom)

	# Ship silhouette in the middle
	_preview_ship = ShipRenderer.new()
	_preview_ship.ship_id = 0
	_preview_ship.render_mode = ShipRenderer.RenderMode.CHROME
	_preview_ship.animate = false
	_preview_ship.scale = Vector2(1.5, 1.5)
	_preview_container.add_child(_preview_ship)

	# Top nebula veil (over the ship)
	_preview_top = ColorRect.new()
	_preview_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_top.color = Color.WHITE
	_preview_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_container.add_child(_preview_top)

	# Keep ref for compatibility with existing code
	_preview_rect = _preview_bottom

	# Name
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size.x = 100
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)

	# Style dropdown
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Style"
	style_label.custom_minimum_size.x = 100
	style_row.add_child(style_label)
	_style_option = OptionButton.new()
	_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in _style_keys:
		var info: Dictionary = STYLES[key]
		_style_option.add_item(info["name"])
	_style_option.item_selected.connect(_on_style_changed)
	style_row.add_child(_style_option)

	# Parameters section
	var params_label := Label.new()
	params_label.text = "PARAMETERS"
	params_label.name = "ParamsHeader"
	_editor_panel.add_child(params_label)

	_params_container = VBoxContainer.new()
	_params_container.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(_params_container)
	_build_param_controls()

	# --- Status Effects section ---
	var effects_header := Label.new()
	effects_header.text = "STATUS EFFECTS"
	effects_header.name = "EffectsHeader"
	_editor_panel.add_child(effects_header)

	_effects_container = VBoxContainer.new()
	_effects_container.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(_effects_container)
	_build_effects_controls()

	# Empty state label (shown when no nebulas exist)
	_empty_label = Label.new()
	_empty_label.text = "No nebulas yet. Click + CREATE NEW to get started."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_panel.add_child(_empty_label)
	_empty_label.visible = false

	_rebuild_list()


func _build_param_controls() -> void:
	# Clear existing
	for child in _params_container.get_children():
		child.queue_free()

	# Color
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	_params_container.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Color"
	color_label.custom_minimum_size.x = 100
	color_row.add_child(color_label)
	_color_picker = ColorPickerButton.new()
	_color_picker.custom_minimum_size = Vector2(60, 30)
	_color_picker.color = Color(0.3, 0.4, 0.9, 1.0)
	_color_picker.color_changed.connect(_on_color_changed)
	color_row.add_child(_color_picker)

	# Secondary color (dual styles only)
	_color2_row = HBoxContainer.new()
	_color2_row.add_theme_constant_override("separation", 8)
	_params_container.add_child(_color2_row)
	var color2_label := Label.new()
	color2_label.text = "Color 2"
	color2_label.custom_minimum_size.x = 100
	_color2_row.add_child(color2_label)
	_color2_picker = ColorPickerButton.new()
	_color2_picker.custom_minimum_size = Vector2(60, 30)
	_color2_picker.color = Color(1.0, 0.5, 0.2, 1.0)
	_color2_picker.color_changed.connect(_on_color2_changed)
	_color2_row.add_child(_color2_picker)
	_color2_row.visible = false

	# Brightness
	_brightness_slider = _add_slider_row("Brightness", 0.5, 4.0, 0.05, 1.5)
	_brightness_slider.value_changed.connect(_on_brightness_changed)

	# Animation Speed
	_speed_slider = _add_slider_row("Anim Speed", 0.0, 3.0, 0.05, 0.5)
	_speed_slider.value_changed.connect(_on_speed_changed)

	# Density
	_density_slider = _add_slider_row("Density", 0.5, 4.0, 0.05, 1.5)
	_density_slider.value_changed.connect(_on_density_changed)

	# Seed Offset
	_seed_slider = _add_slider_row("Seed", 0.0, 1000.0, 1.0, 0.0)
	_seed_slider.value_changed.connect(_on_seed_changed)

	# Spread — controls how evenly intensity fills the radius
	_spread_slider = _add_slider_row("Spread", 0.05, 1.0, 0.05, 0.2)
	_spread_slider.value_changed.connect(_on_spread_changed)

	# --- Layer opacity section ---
	var layer_label := Label.new()
	layer_label.text = "LAYER OPACITY"
	layer_label.name = "LayerHeader"
	_params_container.add_child(layer_label)

	# Bottom layer opacity
	_bottom_opacity_slider = _add_slider_row("Bottom", 0.0, 1.0, 0.05, 1.0)
	_bottom_opacity_slider.value_changed.connect(_on_bottom_opacity_changed)

	# Top veil opacity
	_top_opacity_slider = _add_slider_row("Top Veil", 0.0, 0.5, 0.01, 0.1)
	_top_opacity_slider.value_changed.connect(_on_top_opacity_changed)


func _add_slider_row(label_text: String, min_val: float, max_val: float, step: float, default_val: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_params_container.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(snapped(default_val, step))
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	# Store value label ref by slider name for updates
	if label_text == "Brightness":
		_brightness_value = value_label
	elif label_text == "Anim Speed":
		_speed_value = value_label
	elif label_text == "Density":
		_density_value = value_label
	elif label_text == "Seed":
		_seed_value = value_label
	elif label_text == "Spread":
		_spread_value = value_label
	elif label_text == "Bottom":
		_bottom_opacity_value = value_label
	elif label_text == "Top Veil":
		_top_opacity_value = value_label

	return slider


func _build_effects_controls() -> void:
	# Clear existing
	for child in _effects_container.get_children():
		child.queue_free()
	_bar_effect_spinboxes.clear()
	_special_effect_checks.clear()

	# Bar effects: spinboxes for shield, hull, thermal, electric
	var bar_label := Label.new()
	bar_label.text = "Bar Rates (per second)"
	bar_label.name = "BarRatesLabel"
	_effects_container.add_child(bar_label)

	var bar_names: Array[String] = ["shield", "hull", "thermal", "electric"]
	for bar_name in bar_names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_effects_container.add_child(row)

		var lbl := Label.new()
		lbl.text = bar_name.capitalize()
		lbl.custom_minimum_size.x = 100
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = -10.0
		spin.max_value = 10.0
		spin.step = 0.5
		spin.value = 0.0
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_on_bar_effect_changed.bind(bar_name))
		row.add_child(spin)

		_bar_effect_spinboxes[bar_name] = spin

	# Special effects: checkboxes
	var special_label := Label.new()
	special_label.text = "Special Effects"
	special_label.name = "SpecialEffectsLabel"
	_effects_container.add_child(special_label)

	for effect_id in KNOWN_SPECIAL_EFFECTS:
		var check := CheckBox.new()
		check.text = effect_id.capitalize().replace("_", " ")
		check.toggled.connect(_on_special_effect_toggled.bind(effect_id))
		_effects_container.add_child(check)
		_special_effect_checks[effect_id] = check

	# Music effects
	var music_label := Label.new()
	music_label.text = "Music Effects"
	music_label.name = "MusicEffectsLabel"
	_effects_container.add_child(music_label)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 8)
	_effects_container.add_child(key_row)

	var key_lbl := Label.new()
	key_lbl.text = "Key Shift"
	key_lbl.custom_minimum_size.x = 100
	key_row.add_child(key_lbl)

	_key_shift_slider = HSlider.new()
	_key_shift_slider.min_value = -6
	_key_shift_slider.max_value = 6
	_key_shift_slider.step = 1
	_key_shift_slider.value = 0
	_key_shift_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_shift_slider.custom_minimum_size.x = 200
	_key_shift_slider.value_changed.connect(_on_key_shift_changed)
	key_row.add_child(_key_shift_slider)

	_key_shift_value = Label.new()
	_key_shift_value.text = "0 st"
	_key_shift_value.custom_minimum_size.x = 60
	_key_shift_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_row.add_child(_key_shift_value)


func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	for nebula in _nebulas:
		var btn := Button.new()
		btn.text = nebula.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (nebula.id == _selected_id)
		btn.pressed.connect(_on_list_item_pressed.bind(nebula.id))
		btn.name = "ListItem_" + nebula.id
		_list_container.add_child(btn)
		ThemeManager.apply_button_style(btn)

	_delete_btn.disabled = (_selected_id == "")


func _show_empty_state() -> void:
	_selected_id = ""
	_editor_panel.visible = true
	_preview_container.visible = false
	_empty_label.visible = true
	_name_edit.get_parent().visible = false
	_style_option.get_parent().visible = false
	_params_container.visible = false
	_effects_container.visible = false
	# Hide params header and effects header
	for child in _editor_panel.get_children():
		if child is Label and (child.name == "ParamsHeader" or child.name == "EffectsHeader"):
			child.visible = false
	_delete_btn.disabled = true


func _show_editor_state() -> void:
	_preview_container.visible = true
	_empty_label.visible = false
	_name_edit.get_parent().visible = true
	_style_option.get_parent().visible = true
	_params_container.visible = true
	_effects_container.visible = true
	for child in _editor_panel.get_children():
		if child is Label and (child.name == "ParamsHeader" or child.name == "EffectsHeader"):
			child.visible = true


func _select_nebula(id: String) -> void:
	_selected_id = id
	_show_editor_state()

	var data: NebulaData = _get_nebula_by_id(id)
	if not data:
		_show_empty_state()
		return

	_suppressing_signals = true

	_name_edit.text = data.display_name

	# Set style dropdown
	var style_idx: int = _style_keys.find(data.style_id)
	if style_idx >= 0:
		_style_option.selected = style_idx

	# Update param controls
	var params: Dictionary = data.shader_params
	var defaults: Dictionary = NebulaData.default_params()

	var color_arr: Array = params.get("nebula_color", defaults["nebula_color"])
	_color_picker.color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])

	var color2_arr: Array = params.get("secondary_color", defaults["secondary_color"])
	_color2_picker.color = Color(color2_arr[0], color2_arr[1], color2_arr[2], color2_arr[3])

	var brightness_val: float = float(params.get("brightness", defaults["brightness"]))
	_brightness_slider.value = brightness_val
	_brightness_value.text = str(snapped(brightness_val, 0.05))

	var speed_val: float = float(params.get("animation_speed", defaults["animation_speed"]))
	_speed_slider.value = speed_val
	_speed_value.text = str(snapped(speed_val, 0.05))

	var density_val: float = float(params.get("density", defaults["density"]))
	_density_slider.value = density_val
	_density_value.text = str(snapped(density_val, 0.05))

	var seed_val: float = float(params.get("seed_offset", defaults["seed_offset"]))
	_seed_slider.value = seed_val
	_seed_value.text = str(snapped(seed_val, 1.0))

	var spread_val: float = float(params.get("radial_spread", defaults["radial_spread"]))
	_spread_slider.value = spread_val
	_spread_value.text = str(snapped(spread_val, 0.1))

	var bottom_val: float = float(params.get("bottom_opacity", defaults["bottom_opacity"]))
	_bottom_opacity_slider.value = bottom_val
	_bottom_opacity_value.text = str(snapped(bottom_val, 0.05))

	var top_val: float = float(params.get("top_opacity", defaults["top_opacity"]))
	_top_opacity_slider.value = top_val
	_top_opacity_value.text = str(snapped(top_val, 0.01))

	# Load bar effects into spinboxes
	for bar_name in _bar_effect_spinboxes:
		var spin: SpinBox = _bar_effect_spinboxes[bar_name]
		var rate: float = float(data.bar_effects.get(bar_name, 0.0))
		spin.value = rate

	# Load special effects into checkboxes
	for effect_id in _special_effect_checks:
		var check: CheckBox = _special_effect_checks[effect_id]
		check.button_pressed = data.special_effects.has(effect_id)

	# Load key shift
	_key_shift_slider.value = data.key_shift_semitones
	_key_shift_value.text = _format_semitones(data.key_shift_semitones)

	_suppressing_signals = false

	# Show/hide secondary color based on style
	var style_info: Dictionary = STYLES.get(data.style_id, {})
	var is_dual: bool = style_info.get("dual", false)
	_color2_row.visible = is_dual

	_update_preview()
	_update_list_selection()


func _update_list_selection() -> void:
	for child in _list_container.get_children():
		if child is Button:
			var btn_id: String = child.name.replace("ListItem_", "")
			child.button_pressed = (btn_id == _selected_id)


func _update_preview() -> void:
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		_preview_bottom.material = null
		_preview_top.material = null
		return

	var style_info: Dictionary = STYLES.get(data.style_id, {})
	var shader_path: String = style_info.get("shader", "")
	if shader_path == "":
		_preview_bottom.material = null
		_preview_top.material = null
		return

	var shader_res: Shader = load(shader_path) as Shader
	if not shader_res:
		_preview_bottom.material = null
		_preview_top.material = null
		return

	var params: Dictionary = data.shader_params
	var defaults: Dictionary = NebulaData.default_params()

	# Build shader material
	var mat := ShaderMaterial.new()
	mat.shader = shader_res

	var color_arr: Array = params.get("nebula_color", defaults["nebula_color"])
	mat.set_shader_parameter("nebula_color", Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3]))

	if style_info.get("dual", false):
		var color2_arr: Array = params.get("secondary_color", defaults["secondary_color"])
		mat.set_shader_parameter("secondary_color", Color(color2_arr[0], color2_arr[1], color2_arr[2], color2_arr[3]))

	mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
	mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
	mat.set_shader_parameter("density", float(params.get("density", defaults["density"])))
	mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])))
	mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))

	# Bottom layer — full nebula behind ship
	_preview_bottom.material = mat
	_preview_bottom.modulate.a = float(params.get("bottom_opacity", defaults["bottom_opacity"]))

	# Top veil — same shader over ship
	var top_mat := mat.duplicate() as ShaderMaterial
	_preview_top.material = top_mat
	_preview_top.modulate.a = float(params.get("top_opacity", defaults["top_opacity"]))


func _get_nebula_by_id(id: String) -> NebulaData:
	for n in _nebulas:
		if n.id == id:
			return n
	return null


func _generate_unique_id() -> String:
	var existing: Array[String] = []
	for n in _nebulas:
		existing.append(n.id)
	var counter: int = 1
	while true:
		var candidate: String = "nebula_" + str(counter)
		if candidate not in existing:
			return candidate
		counter += 1
	return "nebula_1"


func _auto_save() -> void:
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		NebulaDataManager.save(data)


# --- Signals ---

func _on_create_new() -> void:
	var id: String = _generate_unique_id()
	var counter: int = _nebulas.size() + 1
	var data := NebulaData.new()
	data.id = id
	data.display_name = "Nebula " + str(counter)
	data.style_id = "classic_fbm"
	data.shader_params = NebulaData.default_params()
	NebulaDataManager.save(data)
	_nebulas.append(data)
	_rebuild_list()
	_select_nebula(id)


func _on_delete() -> void:
	if _selected_id == "":
		return
	NebulaDataManager.delete(_selected_id)
	var idx: int = -1
	for i in range(_nebulas.size()):
		if _nebulas[i].id == _selected_id:
			idx = i
			break
	if idx >= 0:
		_nebulas.remove_at(idx)

	if _nebulas.size() > 0:
		var new_idx: int = mini(idx, _nebulas.size() - 1)
		_rebuild_list()
		_select_nebula(_nebulas[new_idx].id)
	else:
		_selected_id = ""
		_rebuild_list()
		_show_empty_state()


func _on_list_item_pressed(id: String) -> void:
	_select_nebula(id)


func _on_name_changed(new_name: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.display_name = new_name
		_auto_save()
		# Update list button text
		for child in _list_container.get_children():
			if child is Button and child.name == "ListItem_" + _selected_id:
				child.text = new_name


func _on_style_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	data.style_id = _style_keys[idx]
	var style_info: Dictionary = STYLES[data.style_id]
	_color2_row.visible = style_info.get("dual", false)
	_update_preview()
	_auto_save()


func _on_color_changed(color: Color) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["nebula_color"] = [color.r, color.g, color.b, color.a]
		_update_preview()
		_auto_save()


func _on_color2_changed(color: Color) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["secondary_color"] = [color.r, color.g, color.b, color.a]
		_update_preview()
		_auto_save()


func _on_brightness_changed(val: float) -> void:
	_brightness_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["brightness"] = val
		_update_preview()
		_auto_save()


func _on_speed_changed(val: float) -> void:
	_speed_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["animation_speed"] = val
		_update_preview()
		_auto_save()


func _on_density_changed(val: float) -> void:
	_density_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["density"] = val
		_update_preview()
		_auto_save()


func _on_seed_changed(val: float) -> void:
	_seed_value.text = str(snapped(val, 1.0))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["seed_offset"] = val
		_update_preview()
		_auto_save()


func _on_spread_changed(val: float) -> void:
	_spread_value.text = str(snapped(val, 0.1))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["radial_spread"] = val
		_update_preview()
		_auto_save()


func _on_bottom_opacity_changed(val: float) -> void:
	_bottom_opacity_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["bottom_opacity"] = val
		_update_preview()
		_auto_save()


func _on_top_opacity_changed(val: float) -> void:
	_top_opacity_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["top_opacity"] = val
		_update_preview()
		_auto_save()


func _on_bar_effect_changed(val: float, bar_name: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if val == 0.0:
		data.bar_effects.erase(bar_name)
	else:
		data.bar_effects[bar_name] = val
	_auto_save()


func _on_special_effect_toggled(toggled_on: bool, effect_id: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if toggled_on and not data.special_effects.has(effect_id):
		data.special_effects.append(effect_id)
	elif not toggled_on and data.special_effects.has(effect_id):
		data.special_effects.erase(effect_id)
	_auto_save()


func _on_key_shift_changed(val: float) -> void:
	_key_shift_value.text = _format_semitones(int(val))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	data.key_shift_semitones = int(val)
	_auto_save()


static func _format_semitones(st: int) -> String:
	if st == 0:
		return "0 st"
	elif st > 0:
		return "+" + str(st) + " st"
	else:
		return str(st) + " st"


func _center_preview_ship() -> void:
	if _preview_ship and _preview_container:
		var sz: Vector2 = _preview_container.size
		_preview_ship.position = Vector2(sz.x * 0.5, sz.y * 0.5)


func _apply_theme() -> void:
	ThemeManager.apply_button_style(_create_btn)
	ThemeManager.apply_button_style(_delete_btn)

	for child in _list_container.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child)

	# Header labels
	for child in get_children():
		if child is HSplitContainer:
			var left: VBoxContainer = child.get_child(0) as VBoxContainer
			if left:
				for sub in left.get_children():
					if sub is Label:
						ThemeManager.apply_text_glow(sub, "header")

	# Editor labels
	for child in _editor_panel.get_children():
		if child is Label:
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")

	for child in _params_container.get_children():
		if child is Label:
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")

	for child in _effects_container.get_children():
		if child is Label:
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")
		elif child is CheckBox:
			ThemeManager.apply_button_style(child)

	ThemeManager.apply_text_glow(_empty_label, "body")
