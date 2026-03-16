extends MarginContainer
## Weapons Tab — weapon editor with subtabs (Timing / Effects / Stats),
## live preview, loop browser, time-based waveform triggers, save/load/delete.
## Effects tab supports stackable layers per slot, per-trigger overrides, and beat_fx.

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

const EFFECT_SLOTS: Array[String] = ["shape", "motion", "muzzle", "trail", "impact", "beat_fx"]

const EFFECT_TYPES: Dictionary = {
	"motion": ["none", "sine_wave", "corkscrew", "wobble"],
	"muzzle": ["none", "radial_burst", "directional_flash", "ring_pulse", "spiral_burst"],
	"shape": ["rect", "streak", "orb", "diamond", "arrow", "pulse_orb"],
	"trail": ["none", "particle", "ribbon", "afterimage", "sparkle", "sine_ribbon"],
	"impact": ["none", "burst", "ring_expand", "shatter_lines", "nova_flash", "ripple"],
	"beat_fx": ["none", "color_pulse", "scale_pulse", "sparkle_burst", "glow_flash", "ring_ping"],
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
	"beat_fx": {
		"none": {},
		"color_pulse": {"subdivision": [2, 32, 16, 1], "intensity": [0.1, 1.0, 0.6, 0.05], "r": [0.0, 1.0, 1.0, 0.05], "g": [0.0, 1.0, 1.0, 0.05], "b": [0.0, 1.0, 1.0, 0.05]},
		"scale_pulse": {"subdivision": [2, 32, 16, 1], "intensity": [0.1, 1.0, 0.6, 0.05], "max_scale": [1.1, 2.0, 1.5, 0.05]},
		"sparkle_burst": {"subdivision": [2, 32, 16, 1], "intensity": [0.1, 1.0, 0.6, 0.05]},
		"glow_flash": {"subdivision": [2, 32, 16, 1], "intensity": [0.1, 1.0, 0.6, 0.05]},
		"ring_ping": {"subdivision": [2, 32, 8, 1], "intensity": [0.1, 1.0, 0.6, 0.05]},
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

# Effect section tracking — per-slot: Array of layer UIs
# _slot_layers_data[slot] = Array of { "type_btn": OptionButton, "param_container": VBoxContainer, "param_sliders": Dictionary, "row_container": VBoxContainer }
var _slot_layers_data: Dictionary = {}
var _slot_containers: Dictionary = {}  # slot -> VBoxContainer that holds all layer rows
var _slot_add_buttons: Dictionary = {}  # slot -> Button

# Per-trigger override state
var _trigger_override_selector: OptionButton
var _editing_trigger_index: int = -1  # -1 = editing defaults

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false
var _effects_form: VBoxContainer


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

	_effects_form = VBoxContainer.new()
	_effects_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_effects_form)

	# Per-trigger override selector
	var override_row := HBoxContainer.new()
	_effects_form.add_child(override_row)

	var override_label := Label.new()
	override_label.text = "Editing:"
	override_row.add_child(override_label)

	_trigger_override_selector = OptionButton.new()
	_trigger_override_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trigger_override_selector.add_item("All Triggers (Defaults)")
	_trigger_override_selector.item_selected.connect(_on_trigger_override_changed)
	override_row.add_child(_trigger_override_selector)

	_add_separator(_effects_form)

	# Build slot sections
	for slot in EFFECT_SLOTS:
		_build_effect_slot_section(_effects_form, slot)
		_add_separator(_effects_form)

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


# ── Effect Slot Section (stackable layers) ─────────────────

func _build_effect_slot_section(parent: Control, slot: String) -> void:
	_add_section_header(parent, "EFFECT: " + slot.to_upper())

	# Container for all layer rows in this slot
	var layers_container := VBoxContainer.new()
	layers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(layers_container)
	_slot_containers[slot] = layers_container
	_slot_layers_data[slot] = []

	# Add first default layer
	_add_effect_layer(slot)

	# Add Layer button
	var add_btn := Button.new()
	add_btn.text = "+ Add " + slot.capitalize() + " Layer"
	add_btn.pressed.connect(_on_add_layer.bind(slot))
	ThemeManager.apply_button_style(add_btn)
	parent.add_child(add_btn)
	_slot_add_buttons[slot] = add_btn


func _add_effect_layer(slot: String, type_name: String = "", params: Dictionary = {}) -> void:
	var layers_data: Array = _slot_layers_data[slot]
	if layers_data.size() >= EffectLayerRenderer.MAX_LAYERS_PER_SLOT:
		return

	var container: VBoxContainer = _slot_containers[slot]
	var layer_idx: int = layers_data.size()

	# Layer row container
	var row_container := VBoxContainer.new()
	row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(row_container)

	# Header row: [Layer N] type_selector [^] [v] [X]
	var header_row := HBoxContainer.new()
	row_container.add_child(header_row)

	var layer_label := Label.new()
	layer_label.text = "[Layer " + str(layer_idx + 1) + "]"
	layer_label.custom_minimum_size.x = 70
	header_row.add_child(layer_label)

	var types: Array = EFFECT_TYPES[slot]
	var type_btn := OptionButton.new()
	type_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in types:
		type_btn.add_item(str(t))
	header_row.add_child(type_btn)

	# Set initial type
	if type_name != "":
		var type_idx: int = -1
		for i in types.size():
			if str(types[i]) == type_name:
				type_idx = i
				break
		if type_idx >= 0:
			type_btn.selected = type_idx
	else:
		type_btn.selected = 0

	# Param container
	var param_container := VBoxContainer.new()
	param_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_container.add_child(param_container)

	var layer_data: Dictionary = {
		"type_btn": type_btn,
		"param_container": param_container,
		"param_sliders": {},
		"row_container": row_container,
		"label": layer_label,
	}
	layers_data.append(layer_data)

	# Reorder/remove buttons — bind layer_data ref, resolve index dynamically
	var up_btn := Button.new()
	up_btn.text = "^"
	up_btn.custom_minimum_size.x = 30
	up_btn.pressed.connect(func() -> void:
		var idx: int = _find_layer_index(slot, layer_data)
		if idx >= 0:
			_on_reorder_layer(slot, idx, -1)
	)
	ThemeManager.apply_button_style(up_btn)
	header_row.add_child(up_btn)

	var down_btn := Button.new()
	down_btn.text = "v"
	down_btn.custom_minimum_size.x = 30
	down_btn.pressed.connect(func() -> void:
		var idx: int = _find_layer_index(slot, layer_data)
		if idx >= 0:
			_on_reorder_layer(slot, idx, 1)
	)
	ThemeManager.apply_button_style(down_btn)
	header_row.add_child(down_btn)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(func() -> void:
		var idx: int = _find_layer_index(slot, layer_data)
		if idx >= 0:
			_on_remove_layer(slot, idx)
	)
	ThemeManager.apply_button_style(remove_btn)
	header_row.add_child(remove_btn)

	# Build params for initial type
	var initial_type: String = type_btn.get_item_text(type_btn.selected)
	_rebuild_layer_params(slot, layer_idx, initial_type)

	# Set param values if provided
	if not params.is_empty():
		var sliders: Dictionary = layer_data["param_sliders"]
		for param_name in params:
			if param_name in sliders:
				var slider: HSlider = sliders[param_name]
				slider.value = float(params[param_name])

	# Connect type change
	type_btn.item_selected.connect(func(idx: int) -> void:
		var new_type: String = type_btn.get_item_text(idx)
		# Find current index of this layer in the array
		var current_idx: int = _find_layer_index(slot, layer_data)
		if current_idx >= 0:
			_rebuild_layer_params(slot, current_idx, new_type)
		_update_preview()
	)

	# Separator between layers
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	row_container.add_child(sep)


func _find_layer_index(slot: String, layer_data: Dictionary) -> int:
	var layers: Array = _slot_layers_data[slot]
	for i in layers.size():
		if layers[i] == layer_data:
			return i
	return -1


func _rebuild_layer_params(slot: String, layer_idx: int, type_name: String) -> void:
	var layers_data: Array = _slot_layers_data[slot]
	if layer_idx < 0 or layer_idx >= layers_data.size():
		return
	var layer_data: Dictionary = layers_data[layer_idx]
	var param_container: VBoxContainer = layer_data["param_container"]

	for child in param_container.get_children():
		child.queue_free()
	layer_data["param_sliders"] = {}

	var layer_defs: Dictionary = EFFECT_PARAM_DEFS.get(slot, {})
	var type_params: Dictionary = layer_defs.get(type_name, {})

	if type_params.is_empty():
		var no_params := Label.new()
		no_params.text = "  (no parameters)"
		no_params.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		param_container.add_child(no_params)
		return

	var sliders_dict: Dictionary = {}
	for param_name in type_params:
		var bounds: Array = type_params[param_name]
		var min_val: float = float(bounds[0])
		var max_val: float = float(bounds[1])
		var default_val: float = float(bounds[2])
		var step_val: float = float(bounds[3])

		var row := _add_slider_row(param_container, param_name + ":", min_val, max_val, default_val, step_val)
		sliders_dict[param_name] = row[0]

	layer_data["param_sliders"] = sliders_dict


func _on_add_layer(slot: String) -> void:
	_add_effect_layer(slot)
	_update_preview()


func _on_remove_layer(slot: String, layer_idx: int) -> void:
	var layers_data: Array = _slot_layers_data[slot]
	if layers_data.size() <= 1:
		# Don't remove the last layer, just reset it to "none"/first type
		var layer_data: Dictionary = layers_data[0]
		var type_btn: OptionButton = layer_data["type_btn"]
		type_btn.selected = 0
		var types: Array = EFFECT_TYPES[slot]
		_rebuild_layer_params(slot, 0, str(types[0]))
		_update_preview()
		return
	if layer_idx < 0 or layer_idx >= layers_data.size():
		return
	# Remove the UI and data
	var layer_data: Dictionary = layers_data[layer_idx]
	var row_container: VBoxContainer = layer_data["row_container"]
	row_container.queue_free()
	layers_data.remove_at(layer_idx)
	# Update labels
	_update_layer_labels(slot)
	_update_preview()


func _on_reorder_layer(slot: String, layer_idx: int, direction: int) -> void:
	var layers_data: Array = _slot_layers_data[slot]
	var new_idx: int = layer_idx + direction
	if new_idx < 0 or new_idx >= layers_data.size():
		return
	# Swap data
	var temp: Dictionary = layers_data[layer_idx]
	layers_data[layer_idx] = layers_data[new_idx]
	layers_data[new_idx] = temp
	# Swap visual order
	var container: VBoxContainer = _slot_containers[slot]
	var row_a: VBoxContainer = (layers_data[layer_idx] as Dictionary)["row_container"]
	var row_b: VBoxContainer = (layers_data[new_idx] as Dictionary)["row_container"]
	container.move_child(row_a, layer_idx)
	container.move_child(row_b, new_idx)
	_update_layer_labels(slot)
	_update_preview()


func _update_layer_labels(slot: String) -> void:
	var layers_data: Array = _slot_layers_data[slot]
	for i in layers_data.size():
		var layer_data: Dictionary = layers_data[i]
		var label: Label = layer_data["label"]
		label.text = "[Layer " + str(i + 1) + "]"


# ── Per-Trigger Override ────────────────────────────────────

func _on_trigger_override_changed(idx: int) -> void:
	# Save current editing state before switching
	if idx == 0:
		_editing_trigger_index = -1
	else:
		_editing_trigger_index = idx - 1

	# Rebuild effects UI with the selected trigger's data
	_rebuild_effects_from_profile(_get_current_profile())


func _refresh_trigger_override_selector() -> void:
	if not _trigger_override_selector:
		return
	var prev_selected: int = _trigger_override_selector.selected
	_trigger_override_selector.clear()
	_trigger_override_selector.add_item("All Triggers (Defaults)")
	var triggers: Array = _waveform_editor.get_triggers()
	for i in triggers.size():
		_trigger_override_selector.add_item("Trigger " + str(i + 1) + " (%.3f)" % float(triggers[i]))
	if prev_selected < _trigger_override_selector.item_count:
		_trigger_override_selector.selected = prev_selected
	else:
		_trigger_override_selector.selected = 0
		_editing_trigger_index = -1


func _get_current_profile() -> Dictionary:
	return _collect_effect_profile()


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


# ── Data Collection (v2 format) ─────────────────────────────

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
	# Collect current UI state as layer arrays for the currently-editing target
	var current_layers: Dictionary = {}
	for slot in EFFECT_SLOTS:
		var layers_data: Array = _slot_layers_data.get(slot, [])
		var slot_layers: Array = []
		for layer_data in layers_data:
			var ld: Dictionary = layer_data as Dictionary
			var type_btn: OptionButton = ld["type_btn"]
			var type_name: String = type_btn.get_item_text(type_btn.selected)
			if type_name == "none":
				continue
			var params: Dictionary = {}
			var sliders: Dictionary = ld.get("param_sliders", {}) as Dictionary
			for param_name in sliders:
				var slider: HSlider = sliders[param_name]
				params[param_name] = slider.value
			slot_layers.append({"type": type_name, "params": params})
		if not slot_layers.is_empty():
			current_layers[slot] = slot_layers

	# Build v2 profile
	# Start from the existing profile if we're editing an override
	var profile: Dictionary = {"version": 2, "defaults": {}, "trigger_overrides": {}}

	# Preserve existing data we're not currently editing
	if _current_profile_cache.has("defaults"):
		profile["defaults"] = (_current_profile_cache["defaults"] as Dictionary).duplicate(true)
	if _current_profile_cache.has("trigger_overrides"):
		profile["trigger_overrides"] = (_current_profile_cache["trigger_overrides"] as Dictionary).duplicate(true)

	if _editing_trigger_index < 0:
		# Editing defaults
		profile["defaults"] = current_layers
	else:
		# Editing a specific trigger override
		var key: String = str(_editing_trigger_index)
		var overrides: Dictionary = profile.get("trigger_overrides", {}) as Dictionary
		if current_layers.is_empty():
			overrides.erase(key)
		else:
			overrides[key] = current_layers
		profile["trigger_overrides"] = overrides

	_current_profile_cache = profile.duplicate(true)
	return profile

# Cache to preserve non-editing-target data
var _current_profile_cache: Dictionary = {"version": 2, "defaults": {}, "trigger_overrides": {}}


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
	_refresh_trigger_override_selector()
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
	_editing_trigger_index = -1
	if _trigger_override_selector:
		_trigger_override_selector.selected = 0
	_current_profile_cache = {"version": 2, "defaults": {}, "trigger_overrides": {}}

	# Reset all slots to single layer with first type
	for slot in EFFECT_SLOTS:
		_clear_slot_layers(slot)
		_add_effect_layer(slot)

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

	# Effect profile (v2 format — WeaponData.from_dict auto-migrates)
	_current_profile_cache = weapon.effect_profile.duplicate(true)
	_editing_trigger_index = -1
	if _trigger_override_selector:
		_trigger_override_selector.selected = 0
	_refresh_trigger_override_selector()
	_rebuild_effects_from_profile(weapon.effect_profile)

	_update_preview()


func _rebuild_effects_from_profile(profile: Dictionary) -> void:
	# Determine which layers to show based on editing target
	var layers_source: Dictionary = {}
	if _editing_trigger_index < 0:
		# Editing defaults
		layers_source = profile.get("defaults", {}) as Dictionary
	else:
		# Editing a specific trigger override
		var overrides: Dictionary = profile.get("trigger_overrides", {}) as Dictionary
		var key: String = str(_editing_trigger_index)
		if overrides.has(key):
			layers_source = overrides[key] as Dictionary
		else:
			# No override for this trigger — show defaults (user can modify to create override)
			layers_source = profile.get("defaults", {}) as Dictionary

	# Rebuild all slots
	for slot in EFFECT_SLOTS:
		_clear_slot_layers(slot)
		var slot_layers: Array = layers_source.get(slot, []) as Array
		if slot_layers.is_empty():
			# Add a single empty/default layer
			_add_effect_layer(slot)
		else:
			for layer_dict in slot_layers:
				var ld: Dictionary = layer_dict as Dictionary
				var type_name: String = str(ld.get("type", "none"))
				var params: Dictionary = ld.get("params", {}) as Dictionary
				_add_effect_layer(slot, type_name, params)


func _clear_slot_layers(slot: String) -> void:
	var layers_data: Array = _slot_layers_data.get(slot, [])
	for layer_data in layers_data:
		var ld: Dictionary = layer_data as Dictionary
		var row_container: VBoxContainer = ld["row_container"]
		row_container.queue_free()
	_slot_layers_data[slot] = []


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
	for slot in _slot_add_buttons:
		var btn: Button = _slot_add_buttons[slot]
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)
