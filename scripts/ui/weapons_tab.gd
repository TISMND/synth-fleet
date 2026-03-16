extends MarginContainer
## Weapons Tab — weapon editor with subtabs (Timing / Effects / Stats),
## live preview, loop browser, time-based waveform triggers, save/load/delete.

const FIRE_PATTERNS: Array[String] = ["single", "burst", "dual", "wave", "spread", "beam", "scatter"]
const SNAP_MODES: Array[Dictionary] = [
	{"label": "Free", "value": 0},
	{"label": "1/4", "value": 4},
	{"label": "1/8", "value": 8},
	{"label": "1/16", "value": 16},
]
const BARS_OPTIONS: Array[Dictionary] = [
	{"label": "Auto", "value": 0},
	{"label": "1", "value": 1},
	{"label": "2", "value": 2},
	{"label": "4", "value": 4},
	{"label": "8", "value": 8},
]

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

# UI references — shared
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _new_button: Button
var _status_label: Label
var _preview_node: WeaponPreview
var _tab_container: TabContainer

# Timing subtab
var _waveform_editor: WaveformEditor
var _loop_browser: LoopBrowser
var _mute_button: Button
var _snap_button: OptionButton
var _grid_toggle: Button
var _bars_button: OptionButton

# Stats subtab
var _name_input: LineEdit
var _color_picker: ColorPickerButton
var _damage_slider: HSlider
var _damage_label: Label
var _speed_slider: HSlider
var _speed_label: Label
var _power_slider: HSlider
var _power_label: Label
var _direction_slider: HSlider
var _direction_label: Label
var _pattern_button: OptionButton

# Effect section tracking
var _effect_type_buttons: Dictionary = {}
var _effect_param_containers: Dictionary = {}
var _effect_param_sliders: Dictionary = {}

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	call_deferred("_start_preview")
	ThemeManager.theme_changed.connect(_apply_theme)


func _exit_tree() -> void:
	if _preview_node:
		_preview_node.stop()


func _start_preview() -> void:
	if _preview_node:
		_preview_node.set_loop_id("loop_browser_audition")
		_preview_node.start()
		_update_preview()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar: Load / Delete / New
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

	# Left: Preview (always visible)
	var left_panel := _build_left_panel()
	split.add_child(left_panel)

	# Right: TabContainer with subtabs
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_tab_container)

	var timing_tab := _build_timing_tab()
	timing_tab.name = "Timing"
	_tab_container.add_child(timing_tab)

	var effects_tab := _build_effects_tab()
	effects_tab.name = "Effects"
	_tab_container.add_child(effects_tab)

	var stats_tab := _build_stats_tab()
	stats_tab.name = "Stats"
	_tab_container.add_child(stats_tab)

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
	viewport_container.custom_minimum_size = Vector2(400, 350)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 350)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport_container.add_child(viewport)

	_preview_node = WeaponPreview.new()
	viewport.add_child(_preview_node)

	return panel


func _build_timing_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Loop Browser
	_add_section_header(vbox, "LOOP BROWSER")
	_loop_browser = LoopBrowser.new()
	_loop_browser.loop_selected.connect(_on_loop_selected)
	vbox.add_child(_loop_browser)

	_add_separator(vbox)

	# Waveform Editor
	_add_section_header(vbox, "WAVEFORM / TRIGGERS")
	_waveform_editor = WaveformEditor.new()
	_waveform_editor.custom_minimum_size = Vector2(400, 140)
	_waveform_editor.triggers_changed.connect(_on_triggers_changed)
	_waveform_editor.set_audition_loop_id("loop_browser_audition")
	vbox.add_child(_waveform_editor)

	# Control row: Mute + Snap + Grid toggle
	var control_row := HBoxContainer.new()
	vbox.add_child(control_row)

	_mute_button = Button.new()
	_mute_button.text = "MUTE"
	_mute_button.custom_minimum_size.x = 80
	_mute_button.pressed.connect(_on_mute_toggle)
	ThemeManager.apply_button_style(_mute_button)
	control_row.add_child(_mute_button)

	var snap_label := Label.new()
	snap_label.text = "  Snap:"
	control_row.add_child(snap_label)

	_snap_button = OptionButton.new()
	for sm in SNAP_MODES:
		_snap_button.add_item(str(sm["label"]))
	_snap_button.selected = 0
	_snap_button.item_selected.connect(_on_snap_changed)
	control_row.add_child(_snap_button)

	var grid_label := Label.new()
	grid_label.text = "  Grid:"
	control_row.add_child(grid_label)

	_grid_toggle = Button.new()
	_grid_toggle.text = "ON"
	_grid_toggle.toggle_mode = true
	_grid_toggle.button_pressed = true
	_grid_toggle.custom_minimum_size.x = 50
	_grid_toggle.toggled.connect(_on_grid_toggled)
	ThemeManager.apply_button_style(_grid_toggle)
	control_row.add_child(_grid_toggle)

	# Bars override row
	var bars_row := HBoxContainer.new()
	vbox.add_child(bars_row)

	var bars_label := Label.new()
	bars_label.text = "Bars:"
	bars_row.add_child(bars_label)

	_bars_button = OptionButton.new()
	for bo in BARS_OPTIONS:
		_bars_button.add_item(str(bo["label"]))
	_bars_button.selected = 0  # Auto
	_bars_button.item_selected.connect(_on_bars_changed)
	bars_row.add_child(_bars_button)

	return scroll


func _build_effects_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	for layer in EFFECT_LAYERS:
		_build_effect_section(form, layer)
		_add_separator(form)

	return scroll


func _build_stats_tab() -> Control:
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

	_add_separator(form)

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

	_add_separator(form)

	# Fire Pattern + Direction
	_add_section_header(form, "FIRE PATTERN")
	_pattern_button = _add_option_button(form, FIRE_PATTERNS)
	_pattern_button.item_selected.connect(func(_i: int) -> void: _update_preview())

	var dir_row := _add_slider_row(form, "Direction (deg):", 0, 360, 0, 1)
	_direction_slider = dir_row[0]
	_direction_label = dir_row[1]

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

	var param_container := VBoxContainer.new()
	param_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(param_container)
	_effect_param_containers[layer] = param_container
	_effect_param_sliders[layer] = {}

	var initial_type: String = str(types[0])
	_rebuild_effect_params(layer, initial_type)

	type_btn.item_selected.connect(func(idx: int) -> void:
		var new_type: String = type_btn.get_item_text(idx)
		_rebuild_effect_params(layer, new_type)
		_update_preview()
	)


func _rebuild_effect_params(layer: String, type_name: String) -> void:
	var container: VBoxContainer = _effect_param_containers[layer]

	for child in container.get_children():
		child.queue_free()
	_effect_param_sliders[layer] = {}

	var layer_defs: Dictionary = EFFECT_PARAM_DEFS.get(layer, {})
	var type_params: Dictionary = layer_defs.get(type_name, {})

	if type_params.is_empty():
		var no_params := Label.new()
		no_params.text = "  (no parameters)"
		no_params.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
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


# ── Data Collection (triggers stored as normalized time 0.0–1.0) ─────

func _collect_weapon_data() -> Dictionary:
	var loop_path: String = _loop_browser.get_selected_path()
	var loop_bars: int = _waveform_editor.get_detected_bars()

	# Triggers are already normalized time (0.0–1.0) — no conversion needed
	var triggers: Array = _waveform_editor.get_triggers()

	return {
		"id": _current_id if _current_id != "" else _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"description": "",
		"color": "#" + _color_picker.color.to_html(false),
		"damage": int(_damage_slider.value),
		"projectile_speed": _speed_slider.value,
		"power_cost": int(_power_slider.value),
		"loop_file_path": loop_path,
		"loop_length_bars": loop_bars,
		"fire_triggers": triggers,
		"fire_pattern": _pattern_button.get_item_text(_pattern_button.selected),
		"effect_profile": _collect_effect_profile(),
		"special_effect": "none",
		"direction_deg": _direction_slider.value,
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
	if not _ui_ready or not _preview_node:
		return
	var data: Dictionary = _collect_weapon_data()
	_preview_node.update_weapon(data)


# ── Loop Browser Events ────────────────────────────────────

func _on_loop_selected(path: String, _category: String) -> void:
	_waveform_editor.set_stream_from_path(path)
	# Reset bars override to Auto when a new loop is selected
	_bars_button.selected = 0
	_update_preview()


func _on_snap_changed(idx: int) -> void:
	var mode: int = int(SNAP_MODES[idx]["value"])
	_waveform_editor.set_snap_mode(mode)


func _on_grid_toggled(pressed: bool) -> void:
	_grid_toggle.text = "ON" if pressed else "OFF"
	_waveform_editor.set_show_beat_grid(pressed)


func _on_bars_changed(idx: int) -> void:
	var bars_val: int = int(BARS_OPTIONS[idx]["value"])
	if bars_val == 0:
		# Auto: re-detect from WAV duration
		_waveform_editor._auto_detect_bars()
	else:
		_waveform_editor.set_loop_length_bars(bars_val)
	_update_preview()


func _on_triggers_changed(_triggers: Array) -> void:
	_update_preview()


func _on_mute_toggle() -> void:
	var audition_id: String = "loop_browser_audition"
	if not LoopMixer.has_loop(audition_id):
		return
	if LoopMixer.is_muted(audition_id):
		LoopMixer.unmute(audition_id)
		_mute_button.text = "MUTE"
	else:
		LoopMixer.mute(audition_id)
		_mute_button.text = "UNMUTE"


# ── Save / Load / Delete ───────────────────────────────────

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
	_direction_slider.value = 0
	_pattern_button.selected = 0
	_waveform_editor.set_stream_from_path("")
	_waveform_editor.set_triggers([])
	_bars_button.selected = 0

	for layer in EFFECT_LAYERS:
		var type_btn: OptionButton = _effect_type_buttons[layer]
		type_btn.selected = 0
		var types: Array = EFFECT_TYPES[layer]
		_rebuild_effect_params(layer, str(types[0]))

	_update_preview()
	_status_label.text = "New weapon — ready to edit."


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
	_direction_slider.value = weapon.direction_deg

	# Select loop in browser
	if weapon.loop_file_path != "":
		_loop_browser.select_path(weapon.loop_file_path)
		_waveform_editor.set_stream_from_path(weapon.loop_file_path)
	else:
		_waveform_editor.set_stream_from_path("")

	# Triggers are already normalized time (0.0–1.0) from WeaponData
	_waveform_editor.set_triggers(weapon.fire_triggers)

	# Reset bars override to Auto
	_bars_button.selected = 0

	# Fire pattern
	var pat_idx: int = FIRE_PATTERNS.find(weapon.fire_pattern)
	_pattern_button.selected = pat_idx if pat_idx >= 0 else 0

	# Effect profile
	var ep: Dictionary = weapon.effect_profile
	for layer in EFFECT_LAYERS:
		var layer_data: Dictionary = ep.get(layer, {"type": "none", "params": {}})
		var type_name: String = str(layer_data.get("type", "none"))
		var params: Dictionary = layer_data.get("params", {})

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

		_rebuild_effect_params(layer, type_name)
		var sliders: Dictionary = _effect_param_sliders.get(layer, {})
		for param_name in params:
			if param_name in sliders:
				var slider: HSlider = sliders[param_name]
				slider.value = float(params[param_name])

	_update_preview()


func _apply_theme() -> void:
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if _mute_button:
		ThemeManager.apply_button_style(_mute_button)
	if _grid_toggle:
		ThemeManager.apply_button_style(_grid_toggle)
	if _save_button:
		ThemeManager.apply_button_style(_save_button)
	if _delete_button:
		ThemeManager.apply_button_style(_delete_button)
	if _new_button:
		ThemeManager.apply_button_style(_new_button)
