extends MarginContainer
## Weapon Builder — full weapon editor with live preview, audio, effect profiles, save/load/delete.

const FIRE_PATTERNS: Array[String] = ["single", "burst", "dual", "wave", "spread", "beam", "scatter"]
const NOTE_DURATIONS: Array[String] = ["1/4", "1/8", "1/16", "1/32"]
const SPECIAL_EFFECTS: Array[String] = ["none", "disable_shields", "disable_weapons", "drain_shields_for_power"]

const EFFECT_LAYERS: Array[String] = ["motion", "muzzle", "shape", "trail", "impact"]

const EFFECT_TYPES: Dictionary = {
	"motion": ["none", "sine_wave", "corkscrew", "wobble"],
	"muzzle": ["none", "radial_burst", "directional_flash", "ring_pulse", "spiral_burst"],
	"shape": ["rect", "streak", "orb", "diamond", "arrow", "pulse_orb"],
	"trail": ["none", "particle", "ribbon", "afterimage", "sparkle", "sine_ribbon"],
	"impact": ["none", "burst", "ring_expand", "shatter_lines", "nova_flash", "ripple"],
}

const EFFECT_PARAM_DEFS: Dictionary = {
	"motion": {
		"none": {},
		"sine_wave": {"amplitude": [5.0, 100.0, 30.0, 1.0], "frequency": [0.5, 10.0, 3.0, 0.1], "phase_offset": [0.0, 6.28, 0.0, 0.01]},
		"corkscrew": {"amplitude": [5.0, 80.0, 20.0, 1.0], "frequency": [0.5, 10.0, 5.0, 0.1], "phase_offset": [0.0, 6.28, 0.0, 0.01]},
		"wobble": {"amplitude": [2.0, 50.0, 10.0, 1.0], "frequency": [1.0, 15.0, 8.0, 0.1], "phase_offset": [0.0, 6.28, 0.0, 0.01]},
	},
	"muzzle": {
		"none": {},
		"radial_burst": {"particle_count": [2, 20, 6, 1], "lifetime": [0.1, 1.0, 0.3, 0.05], "spread_angle": [30.0, 360.0, 360.0, 5.0]},
		"directional_flash": {"particle_count": [2, 12, 4, 1], "lifetime": [0.05, 0.5, 0.2, 0.05], "spread_angle": [10.0, 90.0, 30.0, 5.0]},
		"ring_pulse": {"particle_count": [4, 24, 8, 1], "lifetime": [0.1, 0.8, 0.3, 0.05], "spread_angle": [180.0, 360.0, 360.0, 10.0]},
		"spiral_burst": {"particle_count": [4, 20, 8, 1], "lifetime": [0.1, 1.0, 0.4, 0.05], "spread_angle": [180.0, 360.0, 360.0, 10.0]},
	},
	"shape": {
		"rect": {"width": [2.0, 20.0, 6.0, 1.0], "height": [4.0, 30.0, 12.0, 1.0], "glow_width": [0.0, 10.0, 3.0, 0.5], "glow_intensity": [0.0, 2.0, 0.8, 0.1], "core_brightness": [0.0, 2.0, 1.0, 0.1]},
		"streak": {"width": [1.0, 10.0, 3.0, 0.5], "height": [8.0, 40.0, 20.0, 1.0], "glow_width": [0.0, 12.0, 4.0, 0.5], "glow_intensity": [0.0, 2.0, 0.8, 0.1], "core_brightness": [0.0, 2.0, 1.0, 0.1]},
		"orb": {"radius": [2.0, 15.0, 4.0, 0.5], "glow_width": [0.0, 10.0, 3.0, 0.5], "glow_intensity": [0.0, 2.0, 0.8, 0.1], "core_brightness": [0.0, 2.0, 1.0, 0.1]},
		"diamond": {"width": [4.0, 24.0, 8.0, 1.0], "height": [6.0, 30.0, 14.0, 1.0], "glow_width": [0.0, 10.0, 3.0, 0.5], "glow_intensity": [0.0, 2.0, 0.8, 0.1], "core_brightness": [0.0, 2.0, 1.0, 0.1]},
		"arrow": {"width": [4.0, 20.0, 8.0, 1.0], "height": [6.0, 30.0, 16.0, 1.0], "glow_width": [0.0, 8.0, 2.0, 0.5], "glow_intensity": [0.0, 2.0, 0.8, 0.1], "core_brightness": [0.0, 2.0, 1.0, 0.1]},
		"pulse_orb": {"radius": [2.0, 15.0, 5.0, 0.5], "glow_width": [0.0, 12.0, 4.0, 0.5], "glow_intensity": [0.0, 2.5, 1.0, 0.1], "core_brightness": [0.0, 2.5, 1.2, 0.1]},
	},
	"trail": {
		"none": {},
		"particle": {"amount": [2, 20, 8, 1], "lifetime": [0.05, 0.8, 0.2, 0.05]},
		"ribbon": {"width_start": [1.0, 12.0, 4.0, 0.5], "width_end": [0.0, 6.0, 0.0, 0.5], "lifetime": [0.1, 1.0, 0.3, 0.05]},
		"afterimage": {"amount": [2, 10, 4, 1], "lifetime": [0.05, 0.5, 0.15, 0.05]},
		"sparkle": {"amount": [2, 16, 6, 1], "lifetime": [0.05, 0.6, 0.25, 0.05]},
		"sine_ribbon": {"width_start": [1.0, 10.0, 3.0, 0.5], "width_end": [0.0, 6.0, 0.0, 0.5], "lifetime": [0.1, 1.0, 0.3, 0.05], "amplitude": [1.0, 20.0, 5.0, 0.5], "frequency": [1.0, 10.0, 4.0, 0.5]},
	},
	"impact": {
		"none": {},
		"burst": {"particle_count": [4, 24, 8, 1], "lifetime": [0.1, 1.0, 0.4, 0.05], "radius": [5.0, 60.0, 20.0, 1.0]},
		"ring_expand": {"particle_count": [6, 30, 12, 1], "lifetime": [0.1, 0.8, 0.3, 0.05], "radius": [10.0, 60.0, 30.0, 1.0]},
		"shatter_lines": {"particle_count": [3, 16, 6, 1], "lifetime": [0.1, 0.8, 0.3, 0.05], "radius": [5.0, 50.0, 25.0, 1.0]},
		"nova_flash": {"particle_count": [6, 24, 10, 1], "lifetime": [0.2, 1.0, 0.5, 0.05], "radius": [10.0, 80.0, 40.0, 1.0]},
		"ripple": {"particle_count": [4, 20, 8, 1], "lifetime": [0.1, 1.0, 0.4, 0.05], "radius": [10.0, 70.0, 35.0, 1.0]},
	},
}

# UI references
var _name_input: LineEdit
var _color_picker: ColorPickerButton
var _damage_slider: HSlider
var _damage_label: Label
var _speed_slider: HSlider
var _speed_label: Label
var _power_slider: HSlider
var _power_label: Label
var _pattern_button: OptionButton
var _note_duration_button: OptionButton
var _audio_button: OptionButton
var _mute_button: Button
var _special_button: OptionButton
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _status_label: Label
var _preview_node: WeaponPreview

# Effect section tracking
var _effect_type_buttons: Dictionary = {}
var _effect_param_containers: Dictionary = {}
var _effect_param_sliders: Dictionary = {}

# State
var _current_id: String = ""
var _audio_samples: Array[String] = []
var _audio_muted: bool = false


func _ready() -> void:
	_audio_samples = _scan_audio_samples()
	_build_ui()
	_refresh_load_list()
	call_deferred("_start_preview")


func _exit_tree() -> void:
	if _preview_node:
		_preview_node.stop()


func _start_preview() -> void:
	if _preview_node:
		_preview_node.start()
		_update_preview()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar: Load / Delete
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

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.pressed.connect(_on_new)
	top_bar.add_child(new_btn)

	# Main content: HSplitContainer
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 420
	root.add_child(split)

	# Left: Preview
	var preview_panel := _build_preview_panel()
	split.add_child(preview_panel)

	# Right: Form
	var form_panel := _build_form_panel()
	split.add_child(form_panel)

	# Bottom bar: Save + Status
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE WEAPON"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = "LIVE PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(400, 500)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 500)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport_container.add_child(viewport)

	_preview_node = WeaponPreview.new()
	viewport.add_child(_preview_node)

	# Mute toggle button
	_mute_button = Button.new()
	_mute_button.text = "MUTE"
	_mute_button.pressed.connect(_on_mute_toggle)
	vbox.add_child(_mute_button)

	return panel


func _build_form_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Weapon Name
	_add_section_header(form, "WEAPON NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter weapon name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(func(_t: String) -> void: _update_preview())
	form.add_child(_name_input)

	# Color
	_add_section_header(form, "COLOR")
	var color_row := HBoxContainer.new()
	form.add_child(color_row)
	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color.CYAN
	_color_picker.custom_minimum_size = Vector2(80, 30)
	_color_picker.color_changed.connect(func(_c: Color) -> void: _update_preview())
	color_row.add_child(_color_picker)
	var color_info := Label.new()
	color_info.text = "  Weapon color (affects projectile and effects)"
	color_row.add_child(color_info)

	_add_separator(form)

	# Combat Stats
	_add_section_header(form, "COMBAT STATS")
	var damage_row := _add_slider_row(form, "Damage:", 1, 100, 10, 1)
	_damage_slider = damage_row[0]
	_damage_label = damage_row[1]

	var speed_row := _add_slider_row(form, "Projectile Speed:", 100, 1500, 600, 10)
	_speed_slider = speed_row[0]
	_speed_label = speed_row[1]

	var power_row := _add_slider_row(form, "Power Cost:", 1, 30, 5, 1)
	_power_slider = power_row[0]
	_power_label = power_row[1]

	var duration_row := HBoxContainer.new()
	form.add_child(duration_row)
	var duration_label := Label.new()
	duration_label.text = "Note Duration:"
	duration_label.custom_minimum_size.x = 130
	duration_row.add_child(duration_label)
	_note_duration_button = OptionButton.new()
	_note_duration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for nd in NOTE_DURATIONS:
		_note_duration_button.add_item(nd)
	_note_duration_button.selected = 1  # default "1/8"
	_note_duration_button.item_selected.connect(func(_i: int) -> void: _update_preview())
	duration_row.add_child(_note_duration_button)

	_add_separator(form)

	# Fire Pattern
	_add_section_header(form, "FIRE PATTERN")
	_pattern_button = _add_option_button(form, FIRE_PATTERNS)
	_pattern_button.item_selected.connect(func(_i: int) -> void: _update_preview())

	_add_separator(form)

	# Audio
	_add_section_header(form, "AUDIO")
	_audio_button = OptionButton.new()
	_audio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_button.add_item("(none)")
	for sample_path in _audio_samples:
		var fname: String = sample_path.get_file()
		_audio_button.add_item(fname)
	_audio_button.item_selected.connect(func(_i: int) -> void: _update_preview())
	form.add_child(_audio_button)

	_add_separator(form)

	# Special Effect
	_add_section_header(form, "SPECIAL EFFECT")
	_special_button = _add_option_button(form, SPECIAL_EFFECTS)

	_add_separator(form)

	# Effect Profile Sections
	for layer in EFFECT_LAYERS:
		_build_effect_section(form, layer)
		_add_separator(form)

	return scroll


func _build_effect_section(parent: Control, layer: String) -> void:
	_add_section_header(parent, "EFFECT: " + layer.to_upper())

	var type_row := HBoxContainer.new()
	parent.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 60
	type_row.add_child(type_label)

	var types: Array = EFFECT_TYPES[layer]
	var type_btn := OptionButton.new()
	type_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in types:
		type_btn.add_item(str(t))
	type_row.add_child(type_btn)
	_effect_type_buttons[layer] = type_btn

	# Container for dynamic param sliders
	var param_container := VBoxContainer.new()
	param_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(param_container)
	_effect_param_containers[layer] = param_container
	_effect_param_sliders[layer] = {}

	# Build initial params
	var initial_type: String = str(types[0])
	_rebuild_effect_params(layer, initial_type)

	# Connect type change
	type_btn.item_selected.connect(func(idx: int) -> void:
		var new_type: String = type_btn.get_item_text(idx)
		_rebuild_effect_params(layer, new_type)
		_update_preview()
	)


func _rebuild_effect_params(layer: String, type_name: String) -> void:
	var container: VBoxContainer = _effect_param_containers[layer]

	# Clear existing
	for child in container.get_children():
		child.queue_free()
	_effect_param_sliders[layer] = {}

	# Get param definitions for this type
	var layer_defs: Dictionary = EFFECT_PARAM_DEFS.get(layer, {})
	var type_params: Dictionary = layer_defs.get(type_name, {})

	if type_params.is_empty():
		var no_params := Label.new()
		no_params.text = "  (no parameters)"
		no_params.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		container.add_child(no_params)
		return

	for param_name in type_params:
		var bounds: Array = type_params[param_name]
		var min_val: float = float(bounds[0])
		var max_val: float = float(bounds[1])
		var default_val: float = float(bounds[2])
		var step_val: float = float(bounds[3])

		var row := _add_slider_row(container, param_name + ":", min_val, max_val, default_val, step_val)
		var sliders_dict: Dictionary = _effect_param_sliders[layer]
		sliders_dict[param_name] = row[0]
		_effect_param_sliders[layer] = sliders_dict


# ── UI Helpers ──────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
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
		_update_preview()
	)

	return [slider, value_label]


func _add_option_button(parent: Control, options: Array[String]) -> OptionButton:
	var btn := OptionButton.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in options:
		btn.add_item(opt)
	parent.add_child(btn)
	return btn


# ── Data Collection ─────────────────────────────────────────

func _collect_weapon_data() -> Dictionary:
	var audio_path: String = ""
	if _audio_button.selected > 0:
		audio_path = _audio_samples[_audio_button.selected - 1]

	return {
		"id": _current_id if _current_id != "" else _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"description": "",
		"color": "#" + _color_picker.color.to_html(false),
		"damage": int(_damage_slider.value),
		"projectile_speed": _speed_slider.value,
		"power_cost": int(_power_slider.value),
		"audio_sample_path": audio_path,
		"audio_pitch": 1.0,
		"audio_muted": _audio_muted,
		"note_duration": _note_duration_button.get_item_text(_note_duration_button.selected),
		"fire_pattern": _pattern_button.get_item_text(_pattern_button.selected),
		"effect_profile": _collect_effect_profile(),
		"special_effect": _special_button.get_item_text(_special_button.selected),
	}


func _collect_effect_profile() -> Dictionary:
	var profile: Dictionary = {}
	for layer in EFFECT_LAYERS:
		var type_btn: OptionButton = _effect_type_buttons[layer]
		var type_name: String = type_btn.get_item_text(type_btn.selected)
		var params: Dictionary = {}
		var sliders: Dictionary = _effect_param_sliders.get(layer, {})
		for param_name in sliders:
			var slider: HSlider = sliders[param_name]
			params[param_name] = slider.value
		profile[layer] = {"type": type_name, "params": params}
	return profile


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "weapon_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower()
	id = id.replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "weapon_" + str(randi() % 10000)
	return clean


# ── Preview ─────────────────────────────────────────────────

func _update_preview() -> void:
	if not _preview_node:
		return
	var data: Dictionary = _collect_weapon_data()
	_preview_node.update_weapon(data)


# ── Events ──────────────────────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a weapon name first!"
		return

	var data: Dictionary = _collect_weapon_data()
	var id: String = str(data["id"])
	_current_id = id
	WeaponDataManager.save(id, data)
	_status_label.text = "Saved: " + id
	_refresh_load_list()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var weapon: WeaponData = WeaponDataManager.load_by_id(id)
	if not weapon:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_weapon(weapon)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No weapon loaded to delete."
		return
	WeaponDataManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_name_input.text = ""
	_color_picker.color = Color.CYAN
	_damage_slider.value = 10
	_speed_slider.value = 600
	_power_slider.value = 5
	_note_duration_button.selected = 1  # "1/8"
	_pattern_button.selected = 0
	_audio_button.selected = 0
	_special_button.selected = 0

	# Reset all effect sections
	for layer in EFFECT_LAYERS:
		var type_btn: OptionButton = _effect_type_buttons[layer]
		type_btn.selected = 0
		var types: Array = EFFECT_TYPES[layer]
		_rebuild_effect_params(layer, str(types[0]))

	_update_preview()
	_status_label.text = "New weapon — ready to edit."


func _on_mute_toggle() -> void:
	_audio_muted = not _audio_muted
	_mute_button.text = "UNMUTE" if _audio_muted else "MUTE"
	_update_preview()


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select weapon)")
	var ids: Array[String] = WeaponDataManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_weapon(weapon: WeaponData) -> void:
	_current_id = weapon.id
	_name_input.text = weapon.display_name
	_color_picker.color = Color(weapon.color)
	_damage_slider.value = weapon.damage
	_speed_slider.value = weapon.projectile_speed
	_power_slider.value = weapon.power_cost

	# Note duration
	var nd_idx: int = NOTE_DURATIONS.find(weapon.note_duration)
	_note_duration_button.selected = nd_idx if nd_idx >= 0 else 1

	# Fire pattern
	var pat_idx: int = FIRE_PATTERNS.find(weapon.fire_pattern)
	_pattern_button.selected = pat_idx if pat_idx >= 0 else 0

	# Audio
	_audio_button.selected = 0
	if weapon.audio_sample_path != "":
		for i in _audio_samples.size():
			if _audio_samples[i] == weapon.audio_sample_path:
				_audio_button.selected = i + 1
				break

	# Special effect
	var spec_idx: int = SPECIAL_EFFECTS.find(weapon.special_effect)
	_special_button.selected = spec_idx if spec_idx >= 0 else 0

	# Effect profile
	var ep: Dictionary = weapon.effect_profile
	for layer in EFFECT_LAYERS:
		var layer_data: Dictionary = ep.get(layer, {"type": "none", "params": {}})
		var type_name: String = str(layer_data.get("type", "none"))
		var params: Dictionary = layer_data.get("params", {})

		# Set type dropdown
		var type_btn: OptionButton = _effect_type_buttons[layer]
		var types: Array = EFFECT_TYPES[layer]
		var type_idx: int = -1
		for i in types.size():
			if str(types[i]) == type_name:
				type_idx = i
				break
		if type_idx >= 0:
			type_btn.selected = type_idx
		else:
			type_btn.selected = 0
			type_name = str(types[0])

		# Rebuild params and set values
		_rebuild_effect_params(layer, type_name)
		var sliders: Dictionary = _effect_param_sliders.get(layer, {})
		for param_name in params:
			if param_name in sliders:
				var slider: HSlider = sliders[param_name]
				slider.value = float(params[param_name])

	_update_preview()


func _scan_audio_samples() -> Array[String]:
	var samples: Array[String] = []
	var dir := DirAccess.open("res://assets/audio/samples/")
	if not dir:
		return samples
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext: String = fname.get_extension().to_lower()
			if ext == "wav" or ext == "ogg" or ext == "mp3":
				samples.append("res://assets/audio/samples/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	samples.sort()
	return samples
