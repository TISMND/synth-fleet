extends MarginContainer
## Weapons Tab — weapon editor with subtabs (Timing / Movement / Effects / Stats),
## live preview, loop browser, time-based waveform triggers, save/load/delete.
## Effects tab has 3 slots (muzzle/trail/impact) with single layer each + per-layer color.

const FIRE_PATTERNS: Array[String] = ["single", "burst", "dual", "wave", "spread", "beam", "scatter"]
const AIM_MODES: Array[String] = ["fixed", "sweep", "track"]
const MIRROR_MODES: Array[String] = ["none", "mirror", "alternate"]
const SPECIAL_EFFECTS: Array[String] = ["none", "disable_shields", "disable_weapons", "drain_shields_for_power"]

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

const EFFECT_SLOTS: Array[String] = ["muzzle", "trail", "impact"]
const EFFECT_SLOT_LABELS: Dictionary = {
	"muzzle": "MUZZLE FLASH",
	"trail": "TRAIL",
	"impact": "IMPACT",
}

const EFFECT_TYPES: Dictionary = {
	"muzzle": ["none", "radial_burst", "directional_flash", "ring_pulse", "spiral_burst"],
	"trail": ["none", "particle", "ribbon", "afterimage", "sparkle", "sine_ribbon"],
	"impact": ["none", "burst", "ring_expand", "shatter_lines", "nova_flash", "ripple"],
}

const EFFECT_PARAM_DEFS: Dictionary = {
	"muzzle": {
		"none": {},
		"radial_burst": {"particle_count": [2, 20, 6, 1], "lifetime": [0.1, 1.0, 0.3, 0.05], "spread_angle": [30.0, 360.0, 360.0, 5.0]},
		"directional_flash": {"particle_count": [2, 12, 4, 1], "lifetime": [0.05, 0.5, 0.2, 0.05], "spread_angle": [10.0, 90.0, 30.0, 5.0]},
		"ring_pulse": {"particle_count": [4, 24, 8, 1], "lifetime": [0.1, 0.8, 0.3, 0.05], "spread_angle": [180.0, 360.0, 360.0, 10.0]},
		"spiral_burst": {"particle_count": [4, 20, 8, 1], "lifetime": [0.1, 1.0, 0.4, 0.05], "spread_angle": [180.0, 360.0, 360.0, 10.0]},
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
var _preview_controller: HardpointController
var _preview_proj_container: Node2D
var _preview_fire_point: Node2D
var _tab_container: TabContainer

# Timing subtab
var _waveform_editor: WaveformEditor
var _loop_browser: LoopBrowser
var _mute_button: Button
var _snap_button: OptionButton
var _grid_toggle: Button
var _bars_button: OptionButton

# Movement subtab
var _pattern_button: OptionButton
var _speed_slider: HSlider
var _speed_label: Label
var _aim_mode_button: OptionButton
var _direction_slider: HSlider
var _direction_label: Label
var _sweep_arc_slider: HSlider
var _sweep_arc_label: Label
var _sweep_duration_slider: HSlider
var _sweep_duration_label: Label
var _mirror_mode_button: OptionButton
var _direction_section: VBoxContainer
var _sweep_section: VBoxContainer
var _mirror_section: VBoxContainer

# Effects subtab — per-slot single layer data
# _slot_layer_data[slot] = { "type_btn": OptionButton, "param_container": VBoxContainer, "param_sliders": Dictionary, "color_picker": ColorPickerButton }
var _slot_layer_data: Dictionary = {}

# Per-trigger override state
var _trigger_override_selector: OptionButton
var _editing_trigger_index: int = -1  # -1 = editing defaults

# Projectile style selector
var _style_selector: OptionButton
var _style_ids: Array[String] = []

# Stats subtab
var _name_input: LineEdit
var _damage_slider: HSlider
var _damage_label: Label
var _power_slider: HSlider
var _power_label: Label
var _special_effect_button: OptionButton

# Bar effects (Stats subtab)
const BAR_TYPES: Array[String] = ["shield", "hull", "thermal", "electric"]
const BAR_TYPE_LABELS: Array[String] = ["SHD", "HUL", "THR", "ELC"]
const BAR_TYPE_COLOR_KEYS: Array[String] = ["bar_shield", "bar_hull", "bar_thermal", "bar_electric"]
var _stats_preview_bars: Array[ProgressBar] = []
var _stats_bar_base_colors: Array[Color] = []
var _stats_bar_brightness: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _stats_bar_values: Array[float] = [50.0, 50.0, 50.0, 50.0]
var _reset_bars_button: Button
var _stats_bar_names: Array[String] = []
var _bar_effect_sliders: Dictionary = {}   # "shield" -> HSlider
var _bar_effect_labels: Dictionary = {}    # "shield" -> Label
var _stats_prev_loop_progress: float = -1.0

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false
var _effects_form: VBoxContainer


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	# Apply default snap mode (1/16)
	_waveform_editor.set_snap_mode(16)
	call_deferred("_start_preview")
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	_update_stats_preview(delta)


func _exit_tree() -> void:
	_stop_preview()


func _start_preview() -> void:
	if _preview_controller:
		_preview_controller.setup_from_dict(_collect_weapon_data(), _preview_proj_container, "loop_browser_audition")
		_preview_controller.activate()


func _stop_preview() -> void:
	if _preview_controller:
		_preview_controller.deactivate()
		_preview_controller.cleanup()
	if _preview_proj_container:
		for child in _preview_proj_container.get_children():
			child.queue_free()


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

	var movement_tab := _build_movement_tab()
	movement_tab.name = "Movement"
	_tab_container.add_child(movement_tab)

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

	# Add bloom to preview viewport
	VFXFactory.add_bloom_to_viewport(viewport)

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(bg)

	# Fire point positioned at bottom-center
	_preview_fire_point = Node2D.new()
	_preview_fire_point.position = Vector2(200, 310)
	viewport.add_child(_preview_fire_point)

	# Projectile container
	_preview_proj_container = Node2D.new()
	viewport.add_child(_preview_proj_container)

	# HardpointController (setup deferred until weapon data available)
	_preview_controller = HardpointController.new()
	_preview_fire_point.add_child(_preview_controller)

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
	_waveform_editor.play_pause_requested.connect(_on_play_pause)
	_waveform_editor.seek_requested.connect(_on_seek)
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
	_snap_button.selected = 3  # 1/16
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


func _build_movement_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Fire Pattern
	_add_section_header(form, "FIRE PATTERN")
	_pattern_button = _add_option_button(form, FIRE_PATTERNS)
	_pattern_button.item_selected.connect(func(_i: int) -> void: _update_preview())

	_add_separator(form)

	# Projectile Speed
	_add_section_header(form, "PROJECTILE SPEED")
	var speed_row := _add_slider_row(form, "Speed:", 100, 1500, 600, 10)
	_speed_slider = speed_row[0]
	_speed_label = speed_row[1]

	_add_separator(form)

	# Aim Mode
	_add_section_header(form, "AIM MODE")
	_aim_mode_button = _add_option_button(form, AIM_MODES)
	_aim_mode_button.item_selected.connect(_on_aim_mode_changed)

	_add_separator(form)

	# Direction section (visible for fixed + sweep)
	_direction_section = VBoxContainer.new()
	_direction_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_direction_section)
	_add_section_header(_direction_section, "DIRECTION")
	var dir_row := _add_slider_row(_direction_section, "Angle (deg):", 0, 360, 0, 1)
	_direction_slider = dir_row[0]
	_direction_label = dir_row[1]
	_direction_slider.value_changed.connect(func(_v: float) -> void: _update_mirror_visibility())

	_add_separator(form)

	# Sweep section (visible only for sweep mode)
	_sweep_section = VBoxContainer.new()
	_sweep_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sweep_section.visible = false
	form.add_child(_sweep_section)
	_add_section_header(_sweep_section, "SWEEP")
	var arc_row := _add_slider_row(_sweep_section, "Arc (deg):", 10, 360, 60, 1)
	_sweep_arc_slider = arc_row[0]
	_sweep_arc_label = arc_row[1]
	var dur_row := _add_slider_row(_sweep_section, "Duration (s):", 0.2, 5.0, 1.0, 0.1)
	_sweep_duration_slider = dur_row[0]
	_sweep_duration_label = dur_row[1]

	_add_separator(form)

	# Mirror Mode section (visible when direction != 0 or sweep mode)
	_mirror_section = VBoxContainer.new()
	_mirror_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mirror_section.visible = false
	form.add_child(_mirror_section)
	_add_section_header(_mirror_section, "MIRROR MODE")
	_mirror_mode_button = _add_option_button(_mirror_section, MIRROR_MODES)
	_mirror_mode_button.item_selected.connect(func(_i: int) -> void: _update_preview())

	return scroll


func _build_effects_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_effects_form = VBoxContainer.new()
	_effects_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_effects_form)

	# Projectile Style selector
	var style_row := HBoxContainer.new()
	_effects_form.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Projectile Style:"
	style_row.add_child(style_label)
	_style_selector = OptionButton.new()
	_style_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_selector.item_selected.connect(_on_style_selected)
	style_row.add_child(_style_selector)
	_refresh_style_list()

	_add_separator(_effects_form)

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

	# Build slot sections (single layer each)
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

	# Bar Effect Preview (LED bars at top)
	_add_section_header(form, "BAR EFFECT PREVIEW")
	var specs: Array = ThemeManager.get_status_bar_specs()
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var bar_hbox := HBoxContainer.new()
		bar_hbox.add_theme_constant_override("separation", 6)
		form.add_child(bar_hbox)

		var bar_label := Label.new()
		bar_label.text = str(spec["name"])
		bar_label.custom_minimum_size.x = 70
		bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var color: Color = ThemeManager.resolve_bar_color(spec)
		bar_label.add_theme_color_override("font_color", color)
		bar_hbox.add_child(bar_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(200, 20)
		bar.max_value = 100.0
		bar.value = 50.0
		bar.show_percentage = false
		bar_hbox.add_child(bar)
		var bar_name: String = str(spec["name"])
		var seg: int = int(ShipData.DEFAULT_SEGMENTS.get(bar_name, -1))
		ThemeManager.apply_led_bar(bar, color, 0.5, seg)
		_stats_preview_bars.append(bar)
		_stats_bar_base_colors.append(color)
		_stats_bar_names.append(bar_name)

	_reset_bars_button = Button.new()
	_reset_bars_button.text = "RESET BARS"
	_reset_bars_button.custom_minimum_size = Vector2(120, 30)
	_reset_bars_button.pressed.connect(_on_reset_bars)
	ThemeManager.apply_button_style(_reset_bars_button)
	form.add_child(_reset_bars_button)

	_add_separator(form)

	# Weapon Name
	_add_section_header(form, "WEAPON NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter weapon name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(func(_t: String) -> void: _update_preview())
	form.add_child(_name_input)

	_add_separator(form)

	# Combat Stats
	_add_section_header(form, "COMBAT STATS")
	var damage_row := _add_slider_row(form, "Damage:", 1, 100, 10, 1)
	_damage_slider = damage_row[0]
	_damage_label = damage_row[1]

	var power_row := _add_slider_row(form, "Power Cost:", 1, 30, 5, 1)
	_power_slider = power_row[0]
	_power_label = power_row[1]

	_add_separator(form)

	# Special Effect
	_add_section_header(form, "SPECIAL EFFECT")
	_special_effect_button = _add_option_button(form, SPECIAL_EFFECTS)
	_special_effect_button.item_selected.connect(func(_i: int) -> void: _update_preview())

	_add_separator(form)

	# Bar Effects (per trigger hit)
	_add_section_header(form, "BAR EFFECTS (per trigger hit)")
	for i in BAR_TYPES.size():
		var bar_type: String = BAR_TYPES[i]
		var color_key: String = BAR_TYPE_COLOR_KEYS[i]
		var bar_color: Color = ThemeManager.get_color(color_key)

		var row := HBoxContainer.new()
		form.add_child(row)

		var lbl := Label.new()
		lbl.text = BAR_TYPE_LABELS[i] + ":"
		lbl.custom_minimum_size.x = 50
		lbl.add_theme_color_override("font_color", bar_color)
		row.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = -5.0
		slider.max_value = 5.0
		slider.value = 0.0
		slider.step = 0.1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 150
		row.add_child(slider)

		var val_label := Label.new()
		val_label.text = "0.0"
		val_label.custom_minimum_size.x = 50
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_label)

		slider.value_changed.connect(func(val: float) -> void:
			val_label.text = "%.1f" % val
			_update_preview()
		)

		_bar_effect_sliders[bar_type] = slider
		_bar_effect_labels[bar_type] = val_label

	return scroll


# ── Effect Slot Section (single layer per slot) ─────────────────

func _build_effect_slot_section(parent: Control, slot: String) -> void:
	var slot_label: String = EFFECT_SLOT_LABELS.get(slot, slot.to_upper())
	_add_section_header(parent, slot_label)

	# Type selector row
	var type_row := HBoxContainer.new()
	parent.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 60
	type_row.add_child(type_label)

	var types: Array = EFFECT_TYPES[slot]
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
	color_label.custom_minimum_size.x = 100
	color_row.add_child(color_label)

	var color_picker := ColorPickerButton.new()
	color_picker.color = Color.WHITE
	color_picker.custom_minimum_size = Vector2(80, 30)
	color_picker.color_changed.connect(func(_c: Color) -> void: _update_preview())
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
	_rebuild_slot_params(slot, type_btn.get_item_text(type_btn.selected))

	# Connect type change
	type_btn.item_selected.connect(func(idx: int) -> void:
		var new_type: String = type_btn.get_item_text(idx)
		_rebuild_slot_params(slot, new_type)
		_update_preview()
	)


func _rebuild_slot_params(slot: String, type_name: String) -> void:
	var data: Dictionary = _slot_layer_data[slot]
	var param_container: VBoxContainer = data["param_container"]

	for child in param_container.get_children():
		child.queue_free()
	data["param_sliders"] = {}

	var slot_defs: Dictionary = EFFECT_PARAM_DEFS.get(slot, {})
	var type_params: Dictionary = slot_defs.get(type_name, {})

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

	data["param_sliders"] = sliders_dict


# ── Aim Mode Visibility ────────────────────────────────────

func _on_aim_mode_changed(idx: int) -> void:
	var mode: String = AIM_MODES[idx]
	match mode:
		"fixed":
			_direction_section.visible = true
			_sweep_section.visible = false
			_update_mirror_visibility()
		"sweep":
			_direction_section.visible = true
			_sweep_section.visible = true
			_mirror_section.visible = true
		"track":
			_direction_section.visible = false
			_sweep_section.visible = false
			_mirror_section.visible = false
	_update_preview()


func _update_mirror_visibility() -> void:
	if not _aim_mode_button:
		return
	var mode: String = AIM_MODES[_aim_mode_button.selected]
	if mode == "sweep":
		_mirror_section.visible = true
	elif mode == "fixed":
		_mirror_section.visible = absf(_direction_slider.value) > 0.01 and _direction_slider.value < 359.99
	else:
		_mirror_section.visible = false


# ── Per-Trigger Override ────────────────────────────────────

func _on_trigger_override_changed(idx: int) -> void:
	if idx == 0:
		_editing_trigger_index = -1
	else:
		_editing_trigger_index = idx - 1
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


# ── Projectile Style ────────────────────────────────────────

func _refresh_style_list() -> void:
	if not _style_selector:
		return
	var prev_text: String = ""
	if _style_selector.selected >= 0:
		prev_text = _style_selector.get_item_text(_style_selector.selected)
	_style_selector.clear()
	_style_selector.add_item("None (use shape layers)")
	_style_ids = ProjectileStyleManager.list_ids()
	for id in _style_ids:
		_style_selector.add_item(id)
	# Restore selection
	if prev_text != "" and prev_text != "None (use shape layers)":
		for i in _style_selector.item_count:
			if _style_selector.get_item_text(i) == prev_text:
				_style_selector.selected = i
				return
	_style_selector.selected = 0


func _on_style_selected(_idx: int) -> void:
	_update_preview()


func _get_selected_style_id() -> String:
	if not _style_selector or _style_selector.selected <= 0:
		return ""
	return _style_selector.get_item_text(_style_selector.selected)


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
		"damage": int(_damage_slider.value),
		"projectile_speed": _speed_slider.value,
		"power_cost": int(_power_slider.value),
		"loop_file_path": loop_path,
		"loop_length_bars": loop_bars,
		"fire_triggers": triggers,
		"fire_pattern": _pattern_button.get_item_text(_pattern_button.selected),
		"effect_profile": _collect_effect_profile(),
		"special_effect": SPECIAL_EFFECTS[_special_effect_button.selected],
		"direction_deg": _direction_slider.value,
		"projectile_style_id": _get_selected_style_id(),
		"aim_mode": AIM_MODES[_aim_mode_button.selected],
		"sweep_arc_deg": _sweep_arc_slider.value,
		"sweep_duration": _sweep_duration_slider.value,
		"mirror_mode": MIRROR_MODES[_mirror_mode_button.selected],
		"bar_effects": _collect_bar_effects(),
	}


func _collect_effect_profile() -> Dictionary:
	# Collect current UI state — single layer per slot
	var current_layers: Dictionary = {}
	for slot in EFFECT_SLOTS:
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
		# Add color if not white
		var color_picker: ColorPickerButton = data["color_picker"]
		var c: Color = color_picker.color
		if not c.is_equal_approx(Color.WHITE):
			layer_dict["color"] = [c.r, c.g, c.b, c.a]
		current_layers[slot] = [layer_dict]

	# Build v2 profile
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
	if not _ui_ready or not _preview_controller:
		return
	_preview_controller.update_from_dict(_collect_weapon_data())


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


func _on_play_pause() -> void:
	_on_mute_toggle()


func _on_seek(time_normalized: float) -> void:
	var loop_id: String = "loop_browser_audition"
	var duration: float = LoopMixer.get_stream_duration(loop_id)
	if duration > 0.0:
		LoopMixer.seek(loop_id, time_normalized * duration)


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
	_damage_slider.value = 10
	_speed_slider.value = 600
	_power_slider.value = 5
	_direction_slider.value = 0
	_pattern_button.selected = 0
	_aim_mode_button.selected = 0  # fixed
	_sweep_arc_slider.value = 60
	_sweep_duration_slider.value = 1.0
	_mirror_mode_button.selected = 0  # none
	_special_effect_button.selected = 0  # none
	_direction_section.visible = true
	_sweep_section.visible = false
	_mirror_section.visible = false
	_waveform_editor.set_stream_from_path("")
	_waveform_editor.set_triggers([])
	_bars_button.selected = 0
	_editing_trigger_index = -1
	if _trigger_override_selector:
		_trigger_override_selector.selected = 0
	_current_profile_cache = {"version": 2, "defaults": {}, "trigger_overrides": {}}
	_refresh_style_list()

	# Reset bar effect sliders
	for bar_type in BAR_TYPES:
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		var val_label: Label = _bar_effect_labels.get(bar_type) as Label
		if slider:
			slider.value = 0.0
		if val_label:
			val_label.text = "0.0"
	_on_reset_bars()
	_stats_prev_loop_progress = -1.0

	# Reset all effect slots to "none" with white color
	for slot in EFFECT_SLOTS:
		var data: Dictionary = _slot_layer_data.get(slot, {})
		if not data.is_empty():
			var type_btn: OptionButton = data["type_btn"]
			type_btn.selected = 0
			_rebuild_slot_params(slot, "none")
			var color_picker: ColorPickerButton = data["color_picker"]
			color_picker.color = Color.WHITE

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

	# Aim mode
	var aim_idx: int = AIM_MODES.find(weapon.aim_mode)
	_aim_mode_button.selected = aim_idx if aim_idx >= 0 else 0
	_on_aim_mode_changed(_aim_mode_button.selected)

	# Sweep params
	_sweep_arc_slider.value = weapon.sweep_arc_deg
	_sweep_duration_slider.value = weapon.sweep_duration

	# Mirror mode
	var mirror_idx: int = MIRROR_MODES.find(weapon.mirror_mode)
	_mirror_mode_button.selected = mirror_idx if mirror_idx >= 0 else 0

	# Special effect
	var special_idx: int = SPECIAL_EFFECTS.find(weapon.special_effect)
	_special_effect_button.selected = special_idx if special_idx >= 0 else 0

	# Projectile style selector
	_refresh_style_list()
	if weapon.projectile_style_id != "":
		for i in _style_selector.item_count:
			if _style_selector.get_item_text(i) == weapon.projectile_style_id:
				_style_selector.selected = i
				break
	else:
		_style_selector.selected = 0

	# Effect profile (v2 format — WeaponData.from_dict auto-migrates)
	_current_profile_cache = weapon.effect_profile.duplicate(true)
	_editing_trigger_index = -1
	if _trigger_override_selector:
		_trigger_override_selector.selected = 0
	_refresh_trigger_override_selector()
	_rebuild_effects_from_profile(weapon.effect_profile)

	# Bar effects
	for bar_type in BAR_TYPES:
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		var val_label: Label = _bar_effect_labels.get(bar_type) as Label
		if slider:
			var val: float = float(weapon.bar_effects.get(bar_type, 0.0))
			slider.value = val
			if val_label:
				val_label.text = "%.1f" % val
	_stats_prev_loop_progress = -1.0

	_update_preview()


func _rebuild_effects_from_profile(profile: Dictionary) -> void:
	# Determine which layers to show based on editing target
	var layers_source: Dictionary = {}
	if _editing_trigger_index < 0:
		layers_source = profile.get("defaults", {}) as Dictionary
	else:
		var overrides: Dictionary = profile.get("trigger_overrides", {}) as Dictionary
		var key: String = str(_editing_trigger_index)
		if overrides.has(key):
			layers_source = overrides[key] as Dictionary
		else:
			layers_source = profile.get("defaults", {}) as Dictionary

	# Populate each slot from profile (single layer per slot)
	for slot in EFFECT_SLOTS:
		var data: Dictionary = _slot_layer_data.get(slot, {})
		if data.is_empty():
			continue
		var type_btn: OptionButton = data["type_btn"]
		var color_picker: ColorPickerButton = data["color_picker"]
		var slot_layers: Array = layers_source.get(slot, []) as Array
		if slot_layers.is_empty():
			type_btn.selected = 0
			_rebuild_slot_params(slot, "none")
			color_picker.color = Color.WHITE
		else:
			var layer_dict: Dictionary = slot_layers[0] as Dictionary
			var type_name: String = str(layer_dict.get("type", "none"))
			# Find type index
			var types: Array = EFFECT_TYPES[slot]
			var type_idx: int = -1
			for i in types.size():
				if str(types[i]) == type_name:
					type_idx = i
					break
			type_btn.selected = type_idx if type_idx >= 0 else 0
			_rebuild_slot_params(slot, type_name)
			# Set param values
			var params: Dictionary = layer_dict.get("params", {}) as Dictionary
			var sliders: Dictionary = data.get("param_sliders", {}) as Dictionary
			for param_name in params:
				if param_name in sliders:
					var slider: HSlider = sliders[param_name]
					slider.value = float(params[param_name])
			# Set color
			if layer_dict.has("color"):
				var c: Array = layer_dict["color"] as Array
				if c.size() >= 3:
					var a: float = float(c[3]) if c.size() >= 4 else 1.0
					color_picker.color = Color(float(c[0]), float(c[1]), float(c[2]), a)
				else:
					color_picker.color = Color.WHITE
			else:
				color_picker.color = Color.WHITE


# ── Stats Bar Preview ────────────────────────────────────────

func _on_reset_bars() -> void:
	for i in _stats_bar_values.size():
		_stats_bar_values[i] = 50.0
		_stats_bar_brightness[i] = 0.0
	_refresh_stats_bars()


func _update_stats_preview(delta: float) -> void:
	if not _ui_ready or _stats_preview_bars.is_empty():
		return
	# Only animate when Stats subtab is active
	if _tab_container.current_tab != 3:
		return

	var audition_id: String = "loop_browser_audition"
	if not LoopMixer.has_loop(audition_id):
		return

	var pos_sec: float = LoopMixer.get_playback_position(audition_id)
	var duration: float = LoopMixer.get_stream_duration(audition_id)
	if pos_sec < 0.0 or duration <= 0.0:
		return

	var progress: float = clampf(pos_sec / duration, 0.0, 1.0)
	var prev: float = _stats_prev_loop_progress

	# Detect trigger crossings
	if prev >= 0.0:
		var triggers: Array = _waveform_editor.get_triggers()
		for i in triggers.size():
			var t: float = float(triggers[i])
			var crossed: bool = false
			if progress < prev:
				crossed = t > prev or t <= progress
			else:
				crossed = t > prev and t <= progress
			if crossed:
				# Apply bar effect deltas
				for bi in BAR_TYPES.size():
					var bar_type: String = BAR_TYPES[bi]
					var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
					if slider and slider.value != 0.0:
						_stats_bar_values[bi] = clampf(_stats_bar_values[bi] + slider.value, 0.0, 100.0)
						_stats_bar_brightness[bi] = 1.0

	_stats_prev_loop_progress = progress

	# Decay brightness and update display
	for i in _stats_preview_bars.size():
		if i >= BAR_TYPES.size():
			break
		_stats_bar_brightness[i] = maxf(0.0, _stats_bar_brightness[i] - delta / 0.3)
		_apply_stats_bar_glow(i)


func _apply_stats_bar_glow(bar_idx: int) -> void:
	if bar_idx < 0 or bar_idx >= _stats_preview_bars.size():
		return
	var bar: ProgressBar = _stats_preview_bars[bar_idx]
	var ratio: float = _stats_bar_values[bar_idx] / 100.0
	bar.value = _stats_bar_values[bar_idx]
	var base_color: Color = _stats_bar_base_colors[bar_idx]

	# Update LED bar fill
	var seg: int = -1
	if bar_idx < _stats_bar_names.size():
		seg = int(ShipData.DEFAULT_SEGMENTS.get(_stats_bar_names[bar_idx], -1))
	ThemeManager.apply_led_bar(bar, base_color, ratio, seg)

	# Apply glow pulse on the overlay
	var glow: float = _stats_bar_brightness[bar_idx] * 0.5
	var overlay: ColorRect = bar.get_node_or_null("led_overlay") as ColorRect
	if overlay and overlay.material is ShaderMaterial:
		var mat: ShaderMaterial = overlay.material as ShaderMaterial
		var bright: Color = base_color.lightened(0.6)
		var modulated: Color = base_color.lerp(bright, clampf(glow, 0.0, 1.0))
		mat.set_shader_parameter("fill_color", modulated)
		var base_inner: float = ThemeManager.get_float("led_inner_intensity")
		var base_bloom: float = ThemeManager.get_float("led_bloom_intensity")
		var base_aura: float = ThemeManager.get_float("led_aura_intensity")
		mat.set_shader_parameter("inner_intensity", base_inner + glow * 1.5)
		mat.set_shader_parameter("bloom_intensity", base_bloom + glow * 0.8)
		mat.set_shader_parameter("aura_intensity", base_aura + glow * 0.6)


func _refresh_stats_bars() -> void:
	for i in _stats_preview_bars.size():
		if i >= BAR_TYPES.size():
			break
		var bar: ProgressBar = _stats_preview_bars[i]
		bar.value = _stats_bar_values[i]
		var color: Color = _stats_bar_base_colors[i]
		var seg: int = -1
		if i < _stats_bar_names.size():
			seg = int(ShipData.DEFAULT_SEGMENTS.get(_stats_bar_names[i], -1))
		ThemeManager.apply_led_bar(bar, color, _stats_bar_values[i] / 100.0, seg)


func _collect_bar_effects() -> Dictionary:
	var result: Dictionary = {}
	for bar_type in BAR_TYPES:
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0:
			result[bar_type] = slider.value
	return result


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
	if _reset_bars_button:
		ThemeManager.apply_button_style(_reset_bars_button)
	# Update stats preview bar base colors
	var specs: Array = ThemeManager.get_status_bar_specs()
	for i in _stats_preview_bars.size():
		if i < specs.size():
			_stats_bar_base_colors[i] = ThemeManager.resolve_bar_color(specs[i])
	_refresh_stats_bars()
