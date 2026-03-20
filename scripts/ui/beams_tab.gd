extends MarginContainer
## Beams Tab — beam visual style editor with live preview, shader controls,
## appearance mode, dimensions. Styles saved to res://data/beam_styles/.

const FILL_SHADERS: Array[String] = ["beam", "energy", "plasma", "fire", "electric", "void", "ice", "toxic"]
const APPEARANCE_MODES: Array[String] = ["flow_in", "expand_out"]

const COMMON_PARAM_DISPLAY_NAMES: Dictionary = {
	"brightness": "HDR Brightness",
	"color_mix": "Desaturation",
	"animation_speed": "Time Scale",
	"edge_softness": "Thickness",
}

const COMMON_PARAM_DEFS: Dictionary = {
	"brightness": [0.5, 4.0, 1.0, 0.1],
	"color_mix": [0.0, 1.0, 0.0, 0.01],
	"animation_speed": [0.1, 3.0, 1.0, 0.1],
	"edge_softness": [0.0, 1.0, 0.5, 0.01],
}

const SHADER_PARAM_DEFS: Dictionary = {
	"beam": {"beam_speed": [0.5, 5.0, 3.0, 0.1], "beam_width": [0.1, 0.8, 0.3, 0.01], "flicker_rate": [0.0, 10.0, 4.0, 0.5]},
	"energy": {"scroll_speed": [0.5, 5.0, 2.0, 0.1], "distortion": [0.0, 1.5, 0.15, 0.01], "edge_glow": [0.0, 3.0, 1.5, 0.1]},
	"plasma": {"turbulence_speed": [0.5, 5.0, 2.0, 0.1], "pulse_rate": [0.5, 4.0, 1.5, 0.1]},
	"fire": {"scroll_speed": [0.5, 5.0, 2.0, 0.1], "heat_distortion": [0.0, 0.3, 0.1, 0.01], "flame_detail": [1.0, 6.0, 3.0, 0.5]},
	"electric": {"branch_density": [1.0, 8.0, 4.0, 0.5], "flicker_speed": [2.0, 16.0, 8.0, 1.0], "arc_width": [0.02, 0.2, 0.1, 0.01]},
	"void": {"pulse_speed": [0.5, 4.0, 1.5, 0.1], "edge_width": [0.05, 0.4, 0.15, 0.01], "inner_darkness": [0.5, 1.0, 0.9, 0.05]},
	"ice": {"crystal_density": [2.0, 10.0, 5.0, 0.5], "shimmer_speed": [0.5, 4.0, 2.0, 0.1], "fracture_sharpness": [0.5, 3.0, 1.5, 0.1]},
	"toxic": {"bubble_speed": [0.5, 4.0, 2.0, 0.1], "bubble_density": [1.0, 8.0, 4.0, 0.5], "drip_intensity": [0.0, 1.0, 0.5, 0.05]},
}

# UI references
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _new_button: Button
var _status_label: Label
var _name_input: LineEdit
var _shader_button: OptionButton
var _color_picker: ColorPickerButton
var _secondary_color_picker: ColorPickerButton
var _secondary_color_row: HBoxContainer
var _appearance_button: OptionButton
var _max_length_slider: HSlider
var _max_length_label: Label
var _beam_width_slider: HSlider
var _beam_width_label: Label
var _glow_slider: HSlider
var _glow_label: Label
var _flip_toggle: CheckBox
var _full_screen_toggle: CheckBox

# Effect slot UI — per-slot data (muzzle + impact only)
# _slot_layer_data[slot] = { "type_btn": OptionButton, "param_container": VBoxContainer, "param_sliders": Dictionary, "color_picker": ColorPickerButton }
var _slot_layer_data: Dictionary = {}
const BEAM_EFFECT_SLOTS: Array[String] = ["muzzle", "impact"]

# Dynamic param sections
var _common_params_container: VBoxContainer
var _common_param_sliders: Dictionary = {}
var _shader_params_container: VBoxContainer
var _shader_param_sliders: Dictionary = {}

# Preview
var _preview_viewport: SubViewport
var _preview_spawn_timer: float = 0.0
var _preview_beam_container: Node2D

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	ThemeManager.theme_changed.connect(_apply_theme)
	visibility_changed.connect(_on_visibility_changed)


func _process(_delta: float) -> void:
	if not _ui_ready or not visible or not _preview_beam_container:
		return
	_preview_spawn_timer += _delta
	if _preview_spawn_timer >= 2.0:
		_preview_spawn_timer = 0.0
		_spawn_preview_beam()


func _on_visibility_changed() -> void:
	if visible and _ui_ready:
		_refresh_load_list()
		_preview_spawn_timer = 1.5  # spawn soon after becoming visible


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var load_label := Label.new()
	load_label.text = "Load:"
	top_bar.add_child(load_label)

	_load_button = OptionButton.new()
	_load_button.custom_minimum_size.x = 250
	_load_button.item_selected.connect(_on_load_selected)
	top_bar.add_child(_load_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "DELETE"
	_delete_button.pressed.connect(_on_delete)
	top_bar.add_child(_delete_button)

	_new_button = Button.new()
	_new_button.text = "NEW"
	_new_button.pressed.connect(_on_new)
	top_bar.add_child(_new_button)

	# Main content: HSplitContainer
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 420
	root.add_child(split)

	# Left: Preview
	var left_panel := _build_left_panel()
	split.add_child(left_panel)

	# Right: Controls
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)

	_build_controls(right_vbox)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE STYLE"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = "LIVE PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)
	_section_headers.append(preview_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(400, 500)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(400, 500)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.transparent_bg = false
	viewport_container.add_child(_preview_viewport)

	VFXFactory.add_bloom_to_viewport(_preview_viewport)

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_viewport.add_child(bg)

	# Beam container
	_preview_beam_container = Node2D.new()
	_preview_viewport.add_child(_preview_beam_container)

	return panel


func _build_controls(parent: VBoxContainer) -> void:
	# Name
	_add_section_header(parent, "NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter beam style name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(func(_t: String) -> void: pass)
	parent.add_child(_name_input)

	_add_separator(parent)

	# Fill Shader
	_add_section_header(parent, "FILL SHADER")
	_shader_button = OptionButton.new()
	_shader_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in FILL_SHADERS:
		_shader_button.add_item(s)
	_shader_button.item_selected.connect(_on_shader_changed)
	parent.add_child(_shader_button)

	# Common Params
	_add_section_header(parent, "COMMON PARAMS")
	_common_params_container = VBoxContainer.new()
	_common_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_common_params_container)
	_rebuild_common_params()

	# Shader Params (dynamic)
	_add_section_header(parent, "SHADER PARAMS")
	_shader_params_container = VBoxContainer.new()
	_shader_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_shader_params_container)
	_rebuild_shader_params("beam")

	_add_separator(parent)

	# Color
	_add_section_header(parent, "COLOR")
	var color_row := HBoxContainer.new()
	parent.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Primary:"
	color_label.custom_minimum_size.x = 130
	color_row.add_child(color_label)
	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color.CYAN
	_color_picker.custom_minimum_size = Vector2(80, 30)
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.color_changed.connect(func(_c: Color) -> void: _spawn_preview_beam())
	color_row.add_child(_color_picker)

	_secondary_color_row = HBoxContainer.new()
	parent.add_child(_secondary_color_row)
	var sec_label := Label.new()
	sec_label.text = "Secondary:"
	sec_label.custom_minimum_size.x = 130
	_secondary_color_row.add_child(sec_label)
	_secondary_color_picker = ColorPickerButton.new()
	_secondary_color_picker.color = Color(1.0, 0.3, 0.5, 1.0)
	_secondary_color_picker.custom_minimum_size = Vector2(80, 30)
	_secondary_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secondary_color_picker.color_changed.connect(func(_c: Color) -> void: _spawn_preview_beam())
	_secondary_color_row.add_child(_secondary_color_picker)

	_add_separator(parent)

	# Appearance Mode
	_add_section_header(parent, "APPEARANCE MODE")
	_appearance_button = OptionButton.new()
	_appearance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_appearance_button.add_item("Flow In")
	_appearance_button.add_item("Expand Out")
	_appearance_button.selected = 0
	_appearance_button.item_selected.connect(func(_i: int) -> void: _spawn_preview_beam())
	parent.add_child(_appearance_button)

	_flip_toggle = CheckBox.new()
	_flip_toggle.text = "FLIP SHADER DIRECTION"
	_flip_toggle.button_pressed = false
	_flip_toggle.toggled.connect(func(_on: bool) -> void: _spawn_preview_beam())
	parent.add_child(_flip_toggle)

	_add_separator(parent)

	# Dimensions
	_add_section_header(parent, "DIMENSIONS")
	var length_row: Array = _add_slider_row(parent, "Max Length:", 100, 800, 400, 10)
	_max_length_slider = length_row[0]
	_max_length_label = length_row[1]

	var width_row: Array = _add_slider_row(parent, "Beam Width:", 4, 64, 16, 2)
	_beam_width_slider = width_row[0]
	_beam_width_label = width_row[1]

	_full_screen_toggle = CheckBox.new()
	_full_screen_toggle.text = "FULL SCREEN LENGTH"
	_full_screen_toggle.button_pressed = false
	_full_screen_toggle.toggled.connect(func(on: bool) -> void:
		_max_length_slider.editable = not on
		_max_length_slider.modulate = Color(1, 1, 1, 0.3) if on else Color(1, 1, 1, 1.0)
		_spawn_preview_beam()
	)
	parent.add_child(_full_screen_toggle)

	_add_separator(parent)

	# Glow
	_add_section_header(parent, "GLOW")
	var glow_row: Array = _add_slider_row(parent, "Glow Intensity:", 0.5, 4.0, 1.5, 0.1)
	_glow_slider = glow_row[0]
	_glow_label = glow_row[1]

	_add_separator(parent)

	# Effect sections (muzzle + impact — no trail for beams)
	for slot in BEAM_EFFECT_SLOTS:
		_build_effect_slot_section(parent, slot)
		_add_separator(parent)


# ── Dynamic Param Sections ─────────────────────────────────

func _rebuild_common_params() -> void:
	for child in _common_params_container.get_children():
		child.queue_free()
	_common_param_sliders.clear()

	for param_name in COMMON_PARAM_DEFS:
		var bounds: Array = COMMON_PARAM_DEFS[param_name]
		var display: String = COMMON_PARAM_DISPLAY_NAMES.get(param_name, param_name) as String
		var row: Array = _add_slider_row(_common_params_container, display + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_common_param_sliders[param_name] = row[0]


func _rebuild_shader_params(shader_name: String) -> void:
	for child in _shader_params_container.get_children():
		child.queue_free()
	_shader_param_sliders.clear()

	var defs: Dictionary = SHADER_PARAM_DEFS.get(shader_name, {}) as Dictionary
	if defs.is_empty():
		var lbl := Label.new()
		lbl.text = "  (no parameters)"
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		_shader_params_container.add_child(lbl)
		return

	for param_name in defs:
		var bounds: Array = defs[param_name]
		var row: Array = _add_slider_row(_shader_params_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_shader_param_sliders[param_name] = row[0]


# ── Effect Slot Sections ───────────────────────────────────

func _build_effect_slot_section(parent: Control, slot: String) -> void:
	var slot_label: String = EditorConstants.EFFECT_SLOT_LABELS.get(slot, slot.to_upper()) as String
	_add_section_header(parent, slot_label)

	# Type selector row
	var type_row := HBoxContainer.new()
	parent.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 130
	type_row.add_child(type_label)

	var types: Array = EditorConstants.EFFECT_TYPES[slot]
	var type_btn := OptionButton.new()
	type_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in types:
		type_btn.add_item(str(t))
	type_btn.selected = 0
	type_row.add_child(type_btn)

	# Color picker row
	var color_row := HBoxContainer.new()
	parent.add_child(color_row)

	var color_label := Label.new()
	color_label.text = "Effect Color:"
	color_label.custom_minimum_size.x = 130
	color_row.add_child(color_label)

	var color_picker := ColorPickerButton.new()
	color_picker.color = _color_picker.color if _color_picker else Color.CYAN
	color_picker.custom_minimum_size = Vector2(80, 30)
	color_picker.color_changed.connect(func(_c: Color) -> void: _spawn_preview_beam())
	color_row.add_child(color_picker)

	# Param container
	var param_container := VBoxContainer.new()
	param_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(param_container)

	_slot_layer_data[slot] = {
		"type_btn": type_btn,
		"param_container": param_container,
		"param_sliders": {},
		"color_picker": color_picker,
	}

	# Build params for initial type
	_rebuild_effect_slot_params(slot, type_btn.get_item_text(type_btn.selected))

	# Connect type change
	type_btn.item_selected.connect(func(idx: int) -> void:
		var new_type: String = type_btn.get_item_text(idx)
		_rebuild_effect_slot_params(slot, new_type)
		_spawn_preview_beam()
	)


func _rebuild_effect_slot_params(slot: String, type_name: String) -> void:
	var data: Dictionary = _slot_layer_data[slot]
	var param_container: VBoxContainer = data["param_container"]

	for child in param_container.get_children():
		child.queue_free()
	data["param_sliders"] = {}

	var slot_defs: Dictionary = EditorConstants.EFFECT_PARAM_DEFS.get(slot, {}) as Dictionary
	var type_params: Dictionary = slot_defs.get(type_name, {}) as Dictionary

	if type_params.is_empty():
		var no_params := Label.new()
		no_params.text = "  (no parameters)"
		no_params.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		param_container.add_child(no_params)
		return

	var sliders_dict: Dictionary = {}
	for param_name in type_params:
		var bounds: Array = type_params[param_name]
		var row: Array = _add_slider_row(param_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		sliders_dict[param_name] = row[0]
	data["param_sliders"] = sliders_dict


func _collect_effect_profile() -> Dictionary:
	var defaults: Dictionary = {}
	for slot in BEAM_EFFECT_SLOTS:
		var data: Dictionary = _slot_layer_data.get(slot, {})
		if data.is_empty():
			continue
		var type_btn: OptionButton = data["type_btn"]
		var type_name: String = type_btn.get_item_text(type_btn.selected)
		if type_name == "none":
			continue
		var params: Dictionary = {}
		var sliders: Dictionary = data.get("param_sliders", {}) as Dictionary
		for param_name in sliders:
			var slider: HSlider = sliders[param_name]
			params[param_name] = slider.value
		var layer_dict: Dictionary = {"type": type_name, "params": params}
		var color_picker: ColorPickerButton = data["color_picker"]
		var c: Color = color_picker.color
		if not c.is_equal_approx(_color_picker.color):
			layer_dict["color"] = [c.r, c.g, c.b, c.a]
		defaults[slot] = [layer_dict]
	if defaults.is_empty():
		return {}
	return {"version": 2, "defaults": defaults, "trigger_overrides": {}}


func _populate_effects_from_profile(profile: Dictionary) -> void:
	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	for slot in BEAM_EFFECT_SLOTS:
		var data: Dictionary = _slot_layer_data.get(slot, {})
		if data.is_empty():
			continue
		var type_btn: OptionButton = data["type_btn"]
		var color_picker: ColorPickerButton = data["color_picker"]
		var slot_layers: Array = defaults.get(slot, []) as Array
		if slot_layers.is_empty():
			type_btn.selected = 0
			_rebuild_effect_slot_params(slot, "none")
			color_picker.color = _color_picker.color if _color_picker else Color.CYAN
		else:
			var layer_dict: Dictionary = slot_layers[0] as Dictionary
			var type_name: String = str(layer_dict.get("type", "none"))
			var types: Array = EditorConstants.EFFECT_TYPES[slot]
			var type_idx: int = -1
			for i in types.size():
				if str(types[i]) == type_name:
					type_idx = i
					break
			type_btn.selected = type_idx if type_idx >= 0 else 0
			_rebuild_effect_slot_params(slot, type_name)
			var params: Dictionary = layer_dict.get("params", {}) as Dictionary
			var sliders: Dictionary = data.get("param_sliders", {}) as Dictionary
			for param_name in params:
				if param_name in sliders:
					var slider: HSlider = sliders[param_name]
					slider.value = float(params[param_name])
			if layer_dict.has("color"):
				var ca: Array = layer_dict["color"] as Array
				if ca.size() >= 3:
					var a: float = float(ca[3]) if ca.size() >= 4 else 1.0
					color_picker.color = Color(float(ca[0]), float(ca[1]), float(ca[2]), a)
				else:
					color_picker.color = _color_picker.color if _color_picker else Color.CYAN
			else:
				color_picker.color = _color_picker.color if _color_picker else Color.CYAN


func _reset_effect_slots() -> void:
	for slot in BEAM_EFFECT_SLOTS:
		var data: Dictionary = _slot_layer_data.get(slot, {})
		if not data.is_empty():
			var type_btn: OptionButton = data["type_btn"]
			type_btn.selected = 0
			_rebuild_effect_slot_params(slot, "none")
			var color_picker: ColorPickerButton = data["color_picker"]
			color_picker.color = _color_picker.color if _color_picker else Color.CYAN


func _on_shader_changed(_idx: int) -> void:
	var shader_name: String = _shader_button.get_item_text(_shader_button.selected)
	_rebuild_shader_params(shader_name)
	_spawn_preview_beam()


# ── Preview ────────────────────────────────────────────────

func _spawn_preview_beam() -> void:
	if not _ui_ready or not _preview_beam_container:
		return
	# Clear old beams and effects
	for child in _preview_beam_container.get_children():
		child.queue_free()
	# Build a BeamStyle from current settings
	var bstyle: BeamStyle = _collect_beam_style()
	var beam := BeamProjectile.new()
	var fire_pos: Vector2 = Vector2(200, 460)
	beam.position = fire_pos
	beam.weapon_color = bstyle.color
	beam.damage_per_tick = 0.0  # preview only
	beam.beam_duration = 1.5
	beam.beam_transition_time = 0.3
	beam.appearance_mode = bstyle.appearance_mode
	beam.max_length = minf(bstyle.max_length, 420.0)  # cap for preview viewport
	beam.beam_width = bstyle.beam_width
	beam.beam_style = bstyle
	beam.passthrough = true
	beam.preview_mode = true
	_preview_beam_container.add_child(beam)

	# Spawn muzzle effect at fire point
	_spawn_preview_effects(bstyle, fire_pos)


func _spawn_preview_effects(bstyle: BeamStyle, fire_pos: Vector2) -> void:
	var profile: Dictionary = bstyle.effect_profile
	if profile.is_empty() or (profile.get("defaults", {}) as Dictionary).is_empty():
		return
	var resolved: Dictionary = EffectLayerRenderer.resolve_layers(profile, -1)
	var color: Color = bstyle.color

	# Muzzle at fire point
	var muzzle_layers: Array = resolved.get("muzzle", []) as Array
	for layer in muzzle_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var mtype: String = str(layer_dict.get("type", "none"))
		if mtype == "none":
			continue
		var layer_color: Color = EffectLayerRenderer.get_layer_color(layer_dict, color)
		var emitter: GPUParticles2D = VFXFactory.create_muzzle_emitter(layer_dict, layer_color)
		emitter.position = fire_pos
		_preview_beam_container.add_child(emitter)

	# Impact at beam tip (top of beam)
	var impact_layers: Array = resolved.get("impact", []) as Array
	var tip_pos: Vector2 = Vector2(fire_pos.x, fire_pos.y - minf(bstyle.max_length, 420.0))
	for layer in impact_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var itype: String = str(layer_dict.get("type", "none"))
		if itype == "none":
			continue
		var layer_color: Color = EffectLayerRenderer.get_layer_color(layer_dict, color)
		var emitter: GPUParticles2D = VFXFactory.create_impact_emitter(layer_dict, layer_color)
		emitter.position = tip_pos
		_preview_beam_container.add_child(emitter)


func _collect_beam_style() -> BeamStyle:
	var s := BeamStyle.new()
	s.id = _generate_id(_name_input.text)
	s.display_name = _name_input.text
	s.fill_shader = _shader_button.get_item_text(_shader_button.selected)
	s.color = _color_picker.color
	s.secondary_color = _secondary_color_picker.color
	s.glow_intensity = _glow_slider.value
	s.max_length = _max_length_slider.value
	s.beam_width = _beam_width_slider.value
	s.appearance_mode = APPEARANCE_MODES[_appearance_button.selected]
	s.flip_shader = _flip_toggle.button_pressed
	s.full_screen_length = _full_screen_toggle.button_pressed
	s.effect_profile = _collect_effect_profile()
	# Collect shader params
	var params: Dictionary = {}
	for param_name in _common_param_sliders:
		var slider: HSlider = _common_param_sliders[param_name]
		params[param_name] = slider.value
	for param_name in _shader_param_sliders:
		var slider: HSlider = _shader_param_sliders[param_name]
		params[param_name] = slider.value
	s.shader_params = params
	return s


func _collect_style_data() -> Dictionary:
	var s: BeamStyle = _collect_beam_style()
	return s.to_dict()


# ── Save / Load / Delete ──────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a style name first!"
		return
	var data: Dictionary = _collect_style_data()
	var new_id: String = str(data["id"])
	var old_id: String = _current_id
	if old_id != "" and old_id != new_id:
		BeamStyleManager.rename(old_id, new_id, data)
		_status_label.text = "Renamed: " + old_id + " → " + new_id
	else:
		BeamStyleManager.save(new_id, data)
		_status_label.text = "Saved: " + new_id
	_current_id = new_id
	_refresh_load_list()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var bstyle: BeamStyle = BeamStyleManager.load_by_id(id)
	if not bstyle:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_style(bstyle)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No style loaded to delete."
		return
	BeamStyleManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_name_input.text = ""
	_shader_button.selected = 0
	_color_picker.color = Color.CYAN
	_secondary_color_picker.color = Color(1.0, 0.3, 0.5, 1.0)
	_appearance_button.selected = 0
	_flip_toggle.button_pressed = false
	_full_screen_toggle.button_pressed = false
	_max_length_slider.editable = true
	_max_length_slider.modulate = Color(1, 1, 1, 1.0)
	_max_length_slider.value = 400.0
	_beam_width_slider.value = 16.0
	_glow_slider.value = 1.5
	_rebuild_common_params()
	_rebuild_shader_params("beam")
	_reset_effect_slots()
	_spawn_preview_beam()
	_status_label.text = "New beam style — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select beam style)")
	var ids: Array[String] = BeamStyleManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_style(bstyle: BeamStyle) -> void:
	_current_id = bstyle.id
	_name_input.text = bstyle.display_name

	# Fill shader
	var shader_idx: int = FILL_SHADERS.find(bstyle.fill_shader)
	_shader_button.selected = shader_idx if shader_idx >= 0 else 0
	_rebuild_shader_params(bstyle.fill_shader)

	# Set common param values
	for param_name in bstyle.shader_params:
		if param_name in _common_param_sliders:
			var slider: HSlider = _common_param_sliders[param_name]
			slider.value = float(bstyle.shader_params[param_name])

	# Set shader param values
	for param_name in bstyle.shader_params:
		if param_name in _shader_param_sliders:
			var slider: HSlider = _shader_param_sliders[param_name]
			slider.value = float(bstyle.shader_params[param_name])

	# Color
	_color_picker.color = bstyle.color
	_secondary_color_picker.color = bstyle.secondary_color

	# Appearance mode
	var mode_idx: int = APPEARANCE_MODES.find(bstyle.appearance_mode)
	_appearance_button.selected = mode_idx if mode_idx >= 0 else 0

	# Flip + Full screen
	_flip_toggle.button_pressed = bstyle.flip_shader
	_full_screen_toggle.button_pressed = bstyle.full_screen_length
	_max_length_slider.editable = not bstyle.full_screen_length
	_max_length_slider.modulate = Color(1, 1, 1, 0.3) if bstyle.full_screen_length else Color(1, 1, 1, 1.0)

	# Dimensions
	_max_length_slider.value = bstyle.max_length
	_beam_width_slider.value = bstyle.beam_width
	_glow_slider.value = bstyle.glow_intensity

	# Effect profile
	if not bstyle.effect_profile.is_empty():
		_populate_effects_from_profile(bstyle.effect_profile)
	else:
		_reset_effect_slots()

	_spawn_preview_beam()


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "beam_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower().replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "beam_" + str(randi() % 10000)
	return clean


# ── UI Helpers ─────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	parent.add_child(label)
	_section_headers.append(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


func _add_slider_row(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, step_val: float) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(default_val)
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		if step_val >= 1.0:
			value_label.text = str(int(val))
		else:
			value_label.text = "%.2f" % val
		_spawn_preview_beam()
	)

	return [slider, value_label]


func _apply_theme() -> void:
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if _save_button:
		ThemeManager.apply_button_style(_save_button)
	if _delete_button:
		ThemeManager.apply_button_style(_delete_button)
	if _new_button:
		ThemeManager.apply_button_style(_new_button)
