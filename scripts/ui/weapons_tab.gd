extends MarginContainer
## Weapons Tab — weapon editor with subtabs (Timing / Movement / Stats),
## live preview, loop browser, time-based waveform triggers, save/load/delete.
## Effects are configured per-style in the Projectile Animator tab.

const FIRE_PATTERNS: Array[String] = ["single", "burst", "dual", "wave", "spread", "scatter"]
const AIM_MODES: Array[String] = ["fixed", "sweep", "track"]
const MIRROR_MODES: Array[String] = ["none", "mirror", "alternate"]
const SNAP_MODES: Array[Dictionary] = EditorConstants.SNAP_MODES
const BARS_OPTIONS: Array[Dictionary] = EditorConstants.BARS_OPTIONS

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

# Transition controls
var _transition_mode_button: OptionButton
var _transition_ms_slider: HSlider
var _transition_ms_label: Label

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

# Projectile style selector
var _style_selector: OptionButton
var _style_ids: Array[String] = []

# Beam style selector (Movement subtab)
var _beam_style_selector: OptionButton
var _beam_style_ids: Array[String] = []
# Beam controls — sections to grey out
var _projectile_section_controls: Array[Control] = []  # greyed when beam mode
var _beam_section_controls: Array[Control] = []        # greyed when projectile mode

# Beam timing (Timing subtab)
var _beam_timing_section: VBoxContainer
var _beam_duration_slider: HSlider
var _beam_duration_label: Label
var _beam_transition_slider: HSlider
var _beam_transition_label: Label

# Beam stats (Stats subtab)
var _beam_stats_section: VBoxContainer
var _beam_dps_slider: HSlider
var _beam_dps_label: Label
var _beam_passthrough_toggle: CheckBox

# Pierce (Movement subtab)
var _pierce_slider: HSlider
var _pierce_label: Label

# Splash (Stats subtab)
var _splash_toggle: CheckBox
var _splash_radius_slider: HSlider
var _splash_radius_label: Label
var _splash_section: VBoxContainer

# Skips Shields (Stats subtab)
var _skips_shields_toggle: CheckBox

# Stats subtab
var _name_input: LineEdit
var _damage_slider: HSlider
var _damage_label: Label
# Bar effects (Stats subtab)
const BAR_TYPES: Array[String] = ["shield", "hull", "thermal", "electric"]
const BAR_TYPE_LABELS: Array[String] = ["SHD", "HUL", "THR", "ELC"]
const BAR_TYPE_COLOR_KEYS: Array[String] = ["bar_shield", "bar_hull", "bar_thermal", "bar_electric"]
const BAR_MAX_DEFAULTS: Array[float] = [100.0, 80.0, 60.0, 80.0]
var _stats_preview_bars: Array[ProgressBar] = []
var _stats_bar_base_colors: Array[Color] = []
var _stats_bar_values: Array[float] = [50.0, 40.0, 30.0, 40.0]
var _stats_bar_maxes: Array[float] = [100.0, 80.0, 60.0, 80.0]
var _stats_bar_names: Array[String] = []
# Rolling wave state per bar
var _stats_gain_wave: Array[Dictionary] = []
var _stats_drain_wave: Array[Dictionary] = []
const WAVE_SPEED: float = 2.5
const WAVE_MIN_CHANGE: float = 0.01
var _reset_bars_button: Button
var _bar_effect_sliders: Dictionary = {}   # "shield" -> HSlider
var _bar_effect_labels: Dictionary = {}    # "shield" -> Label
var _stats_prev_loop_progress: float = -1.0
# Enemy damage test
var _enemy_selector: OptionButton
var _enemy_ids: Array[String] = []
var _enemy_cache: Dictionary = {}  # id -> ShipData
var _enemy_shield: float = 0.0
var _enemy_shield_max: float = 0.0
var _enemy_hull: float = 0.0
var _enemy_hull_max: float = 0.0
var _enemy_shield_regen: float = 0.0
var _enemy_shield_bar: ProgressBar
var _enemy_hull_bar: ProgressBar
var _enemy_section: VBoxContainer
var _enemy_ttk_label: Label
var _enemy_ttk_timer: float = 0.0
var _enemy_ttk_active: bool = false
var _enemy_ttk_done: bool = false
var _enemy_reset_button: Button
var _enemy_shield_seg: int = 0
var _enemy_hull_seg: int = 0
var _enemy_shield_gain_wave: Dictionary = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
var _enemy_shield_drain_wave: Dictionary = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
var _enemy_hull_drain_wave: Dictionary = {"active": false, "position": -1.0, "speed": WAVE_SPEED}

# Dirty tracking
var _dirty: bool = false
var _populating: bool = false
var _name_header_label: Label

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	# Apply default snap mode (1/16)
	_waveform_editor.set_snap_mode(16)
	call_deferred("_start_preview")
	ThemeManager.theme_changed.connect(_apply_theme)
	visibility_changed.connect(_on_visibility_changed)


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

	# Component Name
	_name_header_label = _add_section_header(vbox, "COMPONENT NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter weapon name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_name_input.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_name_input.text_changed.connect(func(_t: String) -> void:
		_mark_dirty()
		_update_preview()
	)
	vbox.add_child(_name_input)

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

	# Control row: Mute + Snap + Grid toggle + Bars
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

	var bars_label := Label.new()
	bars_label.text = "  Bars:"
	control_row.add_child(bars_label)

	_bars_button = OptionButton.new()
	for bo in BARS_OPTIONS:
		_bars_button.add_item(str(bo["label"]))
	_bars_button.selected = 0  # Auto
	_bars_button.item_selected.connect(_on_bars_changed)
	control_row.add_child(_bars_button)

	_add_separator(vbox)

	# Audio Transition
	_add_section_header(vbox, "AUDIO TRANSITION")
	var transition_row := HBoxContainer.new()
	vbox.add_child(transition_row)

	var trans_mode_label := Label.new()
	trans_mode_label.text = "Mode:"
	trans_mode_label.custom_minimum_size.x = 60
	transition_row.add_child(trans_mode_label)

	_transition_mode_button = OptionButton.new()
	_transition_mode_button.add_item("Instant")
	_transition_mode_button.add_item("Fade")
	_transition_mode_button.selected = 0
	_transition_mode_button.item_selected.connect(_on_transition_mode_changed)
	transition_row.add_child(_transition_mode_button)

	var trans_dur_label := Label.new()
	trans_dur_label.text = "  Duration:"
	transition_row.add_child(trans_dur_label)

	_transition_ms_slider = HSlider.new()
	_transition_ms_slider.min_value = 50
	_transition_ms_slider.max_value = 2000
	_transition_ms_slider.value = 200
	_transition_ms_slider.step = 10
	_transition_ms_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transition_ms_slider.custom_minimum_size.x = 120
	_transition_ms_slider.editable = false
	_transition_ms_slider.value_changed.connect(_on_transition_ms_changed)
	transition_row.add_child(_transition_ms_slider)

	_transition_ms_label = Label.new()
	_transition_ms_label.text = "200ms"
	_transition_ms_label.custom_minimum_size.x = 60
	_transition_ms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	transition_row.add_child(_transition_ms_label)

	_add_separator(vbox)

	# Beam Timing (visible when beam_style_id set)
	_beam_timing_section = VBoxContainer.new()
	_beam_timing_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beam_timing_section.modulate = Color(1, 1, 1, 0.3)
	vbox.add_child(_beam_timing_section)
	_add_section_header(_beam_timing_section, "BEAM TIMING")
	var bdur_row: Array = _add_slider_row(_beam_timing_section, "Beam Duration:", 0.05, 3.0, 0.3, 0.05)
	_beam_duration_slider = bdur_row[0]
	_beam_duration_label = bdur_row[1]
	_beam_duration_slider.editable = false
	var btrans_row: Array = _add_slider_row(_beam_timing_section, "Transition Time:", 0.01, 1.0, 0.1, 0.01)
	_beam_transition_slider = btrans_row[0]
	_beam_transition_label = btrans_row[1]
	_beam_transition_slider.editable = false

	_add_separator(vbox)

	# Loop Browser
	_add_section_header(vbox, "LOOP BROWSER")
	_loop_browser = LoopBrowser.new()
	_loop_browser.loop_selected.connect(_on_loop_selected)
	vbox.add_child(_loop_browser)
	# Defer usage scan so it doesn't block UI construction
	_loop_browser.call_deferred("refresh_usage")

	return scroll


func _build_movement_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Projectile Style selector (at top of Movement)
	_add_section_header(form, "PROJECTILE STYLE")
	var style_row := HBoxContainer.new()
	form.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Style:"
	style_label.custom_minimum_size.x = 60
	style_row.add_child(style_label)
	_style_selector = OptionButton.new()
	_style_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_selector.item_selected.connect(_on_style_selected)
	style_row.add_child(_style_selector)
	_refresh_style_list()

	_add_separator(form)

	# Beam Style selector
	_add_section_header(form, "BEAM STYLE")
	var beam_style_row := HBoxContainer.new()
	form.add_child(beam_style_row)
	var beam_style_label := Label.new()
	beam_style_label.text = "Beam:"
	beam_style_label.custom_minimum_size.x = 60
	beam_style_row.add_child(beam_style_label)
	_beam_style_selector = OptionButton.new()
	_beam_style_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beam_style_selector.item_selected.connect(_on_beam_style_selected)
	beam_style_row.add_child(_beam_style_selector)
	_refresh_beam_style_list()

	_add_separator(form)

	# Fire Pattern
	_add_section_header(form, "FIRE PATTERN")
	_pattern_button = _add_option_button(form, FIRE_PATTERNS)
	_pattern_button.item_selected.connect(func(_i: int) -> void:
		_mark_dirty()
		_update_preview()
	)

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
	_mirror_mode_button.item_selected.connect(func(_i: int) -> void:
		_mark_dirty()
		_update_preview()
	)

	_add_separator(form)

	# Pierce (passthrough)
	_add_section_header(form, "PIERCE")
	var pierce_row := _add_slider_row(form, "Pierce Count:", -1, 20, 0, 1)
	_pierce_slider = pierce_row[0]
	_pierce_label = pierce_row[1]
	_pierce_label.text = "0"

	var pierce_hint := Label.new()
	pierce_hint.text = "0 = normal  |  N = pass through N enemies  |  -1 = infinite"
	pierce_hint.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	pierce_hint.add_theme_font_size_override("font_size", 11)
	form.add_child(pierce_hint)

	return scroll




func _build_stats_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Bar Effect Preview (LED bars — segment-based like the game)
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
		var bar_max: float = BAR_MAX_DEFAULTS[i]
		var bar_start: float = bar_max * 0.5
		bar.max_value = bar_max
		bar.value = bar_start
		bar.show_percentage = false
		bar_hbox.add_child(bar)
		var bar_name: String = str(spec["name"])
		ThemeManager.apply_led_bar(bar, color, bar_start / bar_max, 20)
		_stats_preview_bars.append(bar)
		_stats_bar_base_colors.append(color)
		_stats_bar_names.append(bar_name)
		_stats_bar_values[i] = bar_start
		_stats_bar_maxes[i] = bar_max
		_stats_gain_wave.append({"active": false, "position": -1.0, "speed": WAVE_SPEED})
		_stats_drain_wave.append({"active": false, "position": -1.0, "speed": WAVE_SPEED})

	_reset_bars_button = Button.new()
	_reset_bars_button.text = "RESET BARS"
	_reset_bars_button.custom_minimum_size = Vector2(120, 30)
	_reset_bars_button.pressed.connect(_on_reset_bars)
	ThemeManager.apply_button_style(_reset_bars_button)
	form.add_child(_reset_bars_button)

	_add_separator(form)

	# Combat Stats
	_add_section_header(form, "COMBAT STATS")
	var damage_row := _add_slider_row(form, "Damage:", 1, 100, 10, 1)
	_damage_slider = damage_row[0]
	_damage_label = damage_row[1]

	_add_separator(form)

	# Beam Damage (visible when beam_style_id set)
	_beam_stats_section = VBoxContainer.new()
	_beam_stats_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beam_stats_section.modulate = Color(1, 1, 1, 0.3)
	form.add_child(_beam_stats_section)
	_add_section_header(_beam_stats_section, "BEAM DAMAGE")
	var bdps_row: Array = _add_slider_row(_beam_stats_section, "Beam DPS:", 1, 500, 50, 1)
	_beam_dps_slider = bdps_row[0]
	_beam_dps_label = bdps_row[1]
	_beam_dps_slider.editable = false
	_beam_passthrough_toggle = CheckBox.new()
	_beam_passthrough_toggle.text = "BEAM PASSTHROUGH"
	_beam_passthrough_toggle.button_pressed = true
	_beam_passthrough_toggle.disabled = true
	_beam_passthrough_toggle.toggled.connect(func(_on: bool) -> void:
		_mark_dirty()
		_update_preview()
	)
	_beam_stats_section.add_child(_beam_passthrough_toggle)

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
		slider.min_value = -100.0
		slider.max_value = 100.0
		slider.value = 0.0
		slider.step = 0.5
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 150
		row.add_child(slider)

		var val_label := Label.new()
		val_label.text = "0.00"
		val_label.custom_minimum_size.x = 50
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_label)

		slider.value_changed.connect(func(val: float) -> void:
			val_label.text = "%.2f" % val
			_mark_dirty()
			_update_preview()
		)

		_bar_effect_sliders[bar_type] = slider
		_bar_effect_labels[bar_type] = val_label

	_add_separator(form)

	# Enemy Damage Test
	_add_section_header(form, "ENEMY DAMAGE TEST")
	var enemy_row := HBoxContainer.new()
	form.add_child(enemy_row)
	var enemy_label := Label.new()
	enemy_label.text = "Enemy:"
	enemy_label.custom_minimum_size.x = 60
	enemy_row.add_child(enemy_label)
	_enemy_selector = OptionButton.new()
	_enemy_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_selector.item_selected.connect(_on_enemy_selected)
	enemy_row.add_child(_enemy_selector)
	_refresh_enemy_list()

	_enemy_section = VBoxContainer.new()
	_enemy_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_enemy_section)

	# Enemy shield bar
	var shield_hbox := HBoxContainer.new()
	shield_hbox.add_theme_constant_override("separation", 6)
	_enemy_section.add_child(shield_hbox)
	var shield_lbl := Label.new()
	shield_lbl.text = "SHIELD"
	shield_lbl.custom_minimum_size.x = 70
	shield_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shield_lbl.add_theme_color_override("font_color", ThemeManager.get_color("bar_shield"))
	shield_hbox.add_child(shield_lbl)
	_enemy_shield_bar = ProgressBar.new()
	_enemy_shield_bar.custom_minimum_size = Vector2(200, 20)
	_enemy_shield_bar.show_percentage = false
	shield_hbox.add_child(_enemy_shield_bar)

	# Enemy hull bar
	var hull_hbox := HBoxContainer.new()
	hull_hbox.add_theme_constant_override("separation", 6)
	_enemy_section.add_child(hull_hbox)
	var hull_lbl := Label.new()
	hull_lbl.text = "HULL"
	hull_lbl.custom_minimum_size.x = 70
	hull_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hull_lbl.add_theme_color_override("font_color", ThemeManager.get_color("bar_hull"))
	hull_hbox.add_child(hull_lbl)
	_enemy_hull_bar = ProgressBar.new()
	_enemy_hull_bar.custom_minimum_size = Vector2(200, 20)
	_enemy_hull_bar.show_percentage = false
	hull_hbox.add_child(_enemy_hull_bar)

	# TTK label + reset
	var ttk_row := HBoxContainer.new()
	ttk_row.add_theme_constant_override("separation", 8)
	_enemy_section.add_child(ttk_row)
	_enemy_ttk_label = Label.new()
	_enemy_ttk_label.text = "TTK: —"
	_enemy_ttk_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_ttk_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	ttk_row.add_child(_enemy_ttk_label)
	_enemy_reset_button = Button.new()
	_enemy_reset_button.text = "RESET"
	_enemy_reset_button.custom_minimum_size.x = 80
	_enemy_reset_button.pressed.connect(_on_enemy_reset)
	ThemeManager.apply_button_style(_enemy_reset_button)
	ttk_row.add_child(_enemy_reset_button)

	_enemy_section.visible = false

	_add_separator(form)

	# Splash Damage
	_add_section_header(form, "SPLASH DAMAGE")
	_splash_toggle = CheckBox.new()
	_splash_toggle.text = "ENABLE SPLASH"
	_splash_toggle.button_pressed = false
	_splash_toggle.toggled.connect(_on_splash_toggled)
	form.add_child(_splash_toggle)

	_splash_section = VBoxContainer.new()
	_splash_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_splash_section.modulate = Color(1, 1, 1, 0.3)
	form.add_child(_splash_section)

	var splash_row := _add_slider_row(_splash_section, "Radius:", 10, 200, 40, 5)
	_splash_radius_slider = splash_row[0]
	_splash_radius_label = splash_row[1]
	_splash_radius_slider.editable = false

	_add_separator(form)

	# Skips Shields
	_add_section_header(form, "SKIPS SHIELDS")
	_skips_shields_toggle = CheckBox.new()
	_skips_shields_toggle.text = "BYPASS ENEMY SHIELDS"
	_skips_shields_toggle.button_pressed = false
	_skips_shields_toggle.toggled.connect(func(_on: bool) -> void:
		_mark_dirty()
		_update_preview()
	)
	form.add_child(_skips_shields_toggle)

	return scroll




func _on_visibility_changed() -> void:
	if visible and _ui_ready:
		_refresh_style_list()
		_refresh_beam_style_list()
		_refresh_load_list()


func _on_splash_toggled(enabled: bool) -> void:
	_splash_section.modulate = Color(1, 1, 1, 1.0) if enabled else Color(1, 1, 1, 0.3)
	_splash_radius_slider.editable = enabled
	_mark_dirty()
	_update_preview()


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
	_mark_dirty()
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
	_mark_dirty()
	_update_preview()


func _get_selected_style_id() -> String:
	if not _style_selector or _style_selector.selected <= 0:
		return ""
	return _style_selector.get_item_text(_style_selector.selected)


# ── Beam Style ─────────────────────────────────────────────

func _refresh_beam_style_list() -> void:
	if not _beam_style_selector:
		return
	var prev_text: String = ""
	if _beam_style_selector.selected >= 0:
		prev_text = _beam_style_selector.get_item_text(_beam_style_selector.selected)
	_beam_style_selector.clear()
	_beam_style_selector.add_item("None (projectile weapon)")
	_beam_style_ids = BeamStyleManager.list_ids()
	for id in _beam_style_ids:
		_beam_style_selector.add_item(id)
	if prev_text != "" and prev_text != "None (projectile weapon)":
		for i in _beam_style_selector.item_count:
			if _beam_style_selector.get_item_text(i) == prev_text:
				_beam_style_selector.selected = i
				return
	_beam_style_selector.selected = 0


func _on_beam_style_selected(_idx: int) -> void:
	_update_beam_visibility()
	_mark_dirty()
	_update_preview()


func _get_selected_beam_style_id() -> String:
	if not _beam_style_selector or _beam_style_selector.selected <= 0:
		return ""
	return _beam_style_selector.get_item_text(_beam_style_selector.selected)


func _is_beam_mode() -> bool:
	return _get_selected_beam_style_id() != ""


func _update_beam_visibility() -> void:
	var beam_mode: bool = _is_beam_mode()
	# Grey out projectile controls when beam mode
	var proj_alpha: float = 0.3 if beam_mode else 1.0
	var beam_alpha: float = 1.0 if beam_mode else 0.3
	if _style_selector:
		_style_selector.disabled = beam_mode
		_style_selector.modulate = Color(1, 1, 1, proj_alpha)
	if _pattern_button:
		_pattern_button.disabled = beam_mode
		_pattern_button.modulate = Color(1, 1, 1, proj_alpha)
	if _speed_slider:
		_speed_slider.editable = not beam_mode
		_speed_slider.modulate = Color(1, 1, 1, proj_alpha)
	if _pierce_slider:
		_pierce_slider.editable = not beam_mode
		_pierce_slider.modulate = Color(1, 1, 1, proj_alpha)
	# Grey out beam controls when projectile mode
	if _beam_timing_section:
		_beam_timing_section.modulate = Color(1, 1, 1, beam_alpha)
		_beam_duration_slider.editable = beam_mode
		_beam_transition_slider.editable = beam_mode
	if _beam_stats_section:
		_beam_stats_section.modulate = Color(1, 1, 1, beam_alpha)
		_beam_dps_slider.editable = beam_mode
		_beam_passthrough_toggle.disabled = not beam_mode
	# Grey out regular damage when beam mode
	if _damage_slider:
		_damage_slider.editable = not beam_mode
		_damage_slider.modulate = Color(1, 1, 1, proj_alpha)


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
		_mark_dirty()
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
		"id": _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"description": "",
		"damage": int(_damage_slider.value),
		"projectile_speed": _speed_slider.value,
		"loop_file_path": loop_path,
		"loop_length_bars": loop_bars,
		"fire_triggers": triggers,
		"fire_pattern": _pattern_button.get_item_text(_pattern_button.selected),
		"effect_profile": {"version": 2, "defaults": {}, "trigger_overrides": {}},
		"direction_deg": _direction_slider.value,
		"projectile_style_id": _get_selected_style_id(),
		"aim_mode": AIM_MODES[_aim_mode_button.selected],
		"sweep_arc_deg": _sweep_arc_slider.value,
		"sweep_duration": _sweep_duration_slider.value,
		"mirror_mode": MIRROR_MODES[_mirror_mode_button.selected],
		"bar_effects": _collect_bar_effects(),
		"transition_mode": "fade" if _transition_mode_button.selected == 1 else "instant",
		"transition_ms": int(_transition_ms_slider.value),
		"pierce_count": int(_pierce_slider.value),
		"splash_enabled": _splash_toggle.button_pressed,
		"splash_radius": _splash_radius_slider.value if _splash_toggle.button_pressed else 0.0,
		"skips_shields": _skips_shields_toggle.button_pressed,
		"beam_style_id": _get_selected_beam_style_id(),
		"beam_duration": _beam_duration_slider.value,
		"beam_transition_time": _beam_transition_slider.value,
		"beam_dps": _beam_dps_slider.value,
		"beam_passthrough": _beam_passthrough_toggle.button_pressed,
	}



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
	_mark_dirty()
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


func _on_transition_mode_changed(idx: int) -> void:
	var is_fade: bool = idx == 1
	_transition_ms_slider.editable = is_fade
	_transition_ms_slider.modulate = Color(1, 1, 1, 1.0) if is_fade else Color(1, 1, 1, 0.3)
	_transition_ms_label.modulate = Color(1, 1, 1, 1.0) if is_fade else Color(1, 1, 1, 0.3)
	_mark_dirty()


func _on_transition_ms_changed(val: float) -> void:
	_transition_ms_label.text = str(int(val)) + "ms"
	_mark_dirty()


func _on_triggers_changed(_triggers: Array) -> void:
	_mark_dirty()
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
	var new_id: String = str(data["id"])
	var old_id: String = _current_id
	if old_id != "" and old_id != new_id:
		# Name changed — rename (updates GameState references)
		WeaponDataManager.rename(old_id, new_id, data)
		_status_label.text = "Renamed: " + old_id + " → " + new_id
	else:
		WeaponDataManager.save(new_id, data)
		_status_label.text = "Saved: " + new_id
	_current_id = new_id
	_refresh_load_list()
	_mark_clean()


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
	_populating = true
	_current_id = ""
	_name_input.text = ""
	_damage_slider.value = 10
	_speed_slider.value = 600
	_direction_slider.value = 0
	_pattern_button.selected = 0
	_aim_mode_button.selected = 0  # fixed
	_sweep_arc_slider.value = 60
	_sweep_duration_slider.value = 1.0
	_mirror_mode_button.selected = 0  # none
	_direction_section.visible = true
	_sweep_section.visible = false
	_mirror_section.visible = false
	_waveform_editor.set_stream_from_path("")
	_waveform_editor.set_triggers([])
	_bars_button.selected = 0
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

	# Reset transition controls
	_transition_mode_button.selected = 0
	_on_transition_mode_changed(0)
	_transition_ms_slider.value = 200
	_transition_ms_label.text = "200ms"

	# Reset pierce / splash / skips shields
	_pierce_slider.value = 0
	_splash_toggle.button_pressed = false
	_on_splash_toggled(false)
	_splash_radius_slider.value = 40
	_skips_shields_toggle.button_pressed = false

	# Reset beam fields
	_refresh_beam_style_list()
	_beam_style_selector.selected = 0
	_beam_duration_slider.value = 0.3
	_beam_transition_slider.value = 0.1
	_beam_dps_slider.value = 50
	_beam_passthrough_toggle.button_pressed = true
	_update_beam_visibility()

	_update_preview()
	_populating = false
	_mark_clean()
	_status_label.text = "New weapon — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select weapon)")
	var ids: Array[String] = WeaponDataManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_weapon(weapon: WeaponData) -> void:
	_populating = true
	_current_id = weapon.id
	_name_input.text = weapon.display_name
	_damage_slider.value = weapon.damage
	_speed_slider.value = weapon.projectile_speed
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

	# Projectile style selector
	_refresh_style_list()
	if weapon.projectile_style_id != "":
		for i in _style_selector.item_count:
			if _style_selector.get_item_text(i) == weapon.projectile_style_id:
				_style_selector.selected = i
				break
	else:
		_style_selector.selected = 0

	# Bar effects
	for bar_type in BAR_TYPES:
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		var val_label: Label = _bar_effect_labels.get(bar_type) as Label
		if slider:
			var val: float = float(weapon.bar_effects.get(bar_type, 0.0))
			slider.value = val
			if val_label:
				val_label.text = "%.2f" % val
	_stats_prev_loop_progress = -1.0

	# Transition settings
	if weapon.transition_mode == "fade":
		_transition_mode_button.selected = 1
	else:
		_transition_mode_button.selected = 0
	_on_transition_mode_changed(_transition_mode_button.selected)
	_transition_ms_slider.value = float(weapon.transition_ms)
	_transition_ms_label.text = str(weapon.transition_ms) + "ms"

	# Pierce / Splash / Skips Shields
	_pierce_slider.value = weapon.pierce_count
	_splash_toggle.button_pressed = weapon.splash_enabled
	_on_splash_toggled(weapon.splash_enabled)
	_splash_radius_slider.value = weapon.splash_radius if weapon.splash_radius > 0.0 else 40.0
	_skips_shields_toggle.button_pressed = weapon.skips_shields

	# Beam fields
	_refresh_beam_style_list()
	if weapon.beam_style_id != "":
		for i in _beam_style_selector.item_count:
			if _beam_style_selector.get_item_text(i) == weapon.beam_style_id:
				_beam_style_selector.selected = i
				break
	else:
		_beam_style_selector.selected = 0
	_beam_duration_slider.value = weapon.beam_duration
	_beam_transition_slider.value = weapon.beam_transition_time
	_beam_dps_slider.value = weapon.beam_dps
	_beam_passthrough_toggle.button_pressed = weapon.beam_passthrough
	_update_beam_visibility()

	_update_preview()
	_populating = false
	_mark_clean()



# ── Stats Bar Preview ────────────────────────────────────────

func _on_reset_bars() -> void:
	for i in _stats_bar_values.size():
		_stats_bar_values[i] = _stats_bar_maxes[i] * 0.5
		_stats_gain_wave[i] = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
		_stats_drain_wave[i] = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
	_refresh_stats_bars()


func _update_stats_preview(delta: float) -> void:
	if not _ui_ready or _stats_preview_bars.is_empty():
		return
	# Only animate when Stats subtab is active
	if _tab_container.current_tab != 2:
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
				_on_trigger_fired()

	_stats_prev_loop_progress = progress

	# Advance rolling waves + update bars
	for i in _stats_preview_bars.size():
		if i >= BAR_TYPES.size():
			break
		_advance_wave(_stats_gain_wave[i], delta, 1.0)
		_advance_wave(_stats_drain_wave[i], delta, -1.0)
		_update_bar_display(i)

	# Advance enemy waves + regen
	if _enemy_section.visible and not _enemy_ttk_done:
		_advance_wave(_enemy_shield_gain_wave, delta, 1.0)
		_advance_wave(_enemy_shield_drain_wave, delta, -1.0)
		_advance_wave(_enemy_hull_drain_wave, delta, -1.0)
		# TTK timer
		if _enemy_ttk_active and not _enemy_ttk_done:
			_enemy_ttk_timer += delta
			_enemy_ttk_label.text = "TTK: %.1fs" % _enemy_ttk_timer
		_update_enemy_bar_display()


func _on_trigger_fired() -> void:
	# Apply bar effect deltas with wave animation
	for bi in BAR_TYPES.size():
		var bar_type: String = BAR_TYPES[bi]
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0:
			var old_val: float = _stats_bar_values[bi]
			_stats_bar_values[bi] = clampf(old_val + slider.value, 0.0, _stats_bar_maxes[bi])
			var delta_ratio: float = (_stats_bar_values[bi] - old_val) / maxf(_stats_bar_maxes[bi], 1.0)
			if delta_ratio > WAVE_MIN_CHANGE:
				_stats_gain_wave[bi]["active"] = true
				_stats_gain_wave[bi]["position"] = 0.0
			elif delta_ratio < -WAVE_MIN_CHANGE:
				_stats_drain_wave[bi]["active"] = true
				_stats_drain_wave[bi]["position"] = 1.0

	# Apply damage to enemy
	if _enemy_section.visible and _enemy_hull > 0.0 and not _enemy_ttk_done:
		if not _enemy_ttk_active:
			_enemy_ttk_active = true
			_enemy_ttk_timer = 0.0
		var dmg: float = float(_damage_slider.value)
		_apply_enemy_damage(dmg)


func _apply_enemy_damage(amount: float) -> void:
	var remaining: float = amount
	if _enemy_shield > 0.0 and not _skips_shields_toggle.button_pressed:
		var absorbed: float = minf(remaining, _enemy_shield)
		var old_shield: float = _enemy_shield
		_enemy_shield -= absorbed
		remaining -= absorbed
		if (old_shield - _enemy_shield) / maxf(_enemy_shield_max, 1.0) > WAVE_MIN_CHANGE:
			_enemy_shield_drain_wave["active"] = true
			_enemy_shield_drain_wave["position"] = 1.0
	if remaining > 0.0:
		var old_hull: float = _enemy_hull
		_enemy_hull = maxf(_enemy_hull - remaining, 0.0)
		if (old_hull - _enemy_hull) / maxf(_enemy_hull_max, 1.0) > WAVE_MIN_CHANGE:
			_enemy_hull_drain_wave["active"] = true
			_enemy_hull_drain_wave["position"] = 1.0
	if _enemy_hull <= 0.0:
		_enemy_ttk_done = true
		_enemy_ttk_label.text = "DESTROYED in %.1fs" % _enemy_ttk_timer


func _advance_wave(wave: Dictionary, delta: float, direction: float) -> void:
	if not bool(wave["active"]):
		return
	var pos: float = float(wave["position"])
	pos += direction * float(wave["speed"]) * delta
	if direction > 0.0 and pos > 1.3:
		wave["active"] = false
		wave["position"] = -1.0
	elif direction < 0.0 and pos < -0.3:
		wave["active"] = false
		wave["position"] = -1.0
	else:
		wave["position"] = pos


func _update_bar_display(bar_idx: int) -> void:
	if bar_idx < 0 or bar_idx >= _stats_preview_bars.size():
		return
	var bar: ProgressBar = _stats_preview_bars[bar_idx]
	var bar_max: float = _stats_bar_maxes[bar_idx]
	var ratio: float = _stats_bar_values[bar_idx] / maxf(bar_max, 1.0)
	bar.max_value = bar_max
	bar.value = _stats_bar_values[bar_idx]
	# Update fill_ratio on shader without rebuilding bar
	if bar.material is ShaderMaterial:
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		mat.set_shader_parameter("fill_ratio", ratio)
		var gain_pos: float = float(_stats_gain_wave[bar_idx]["position"]) if bool(_stats_gain_wave[bar_idx]["active"]) else -1.0
		var drain_pos: float = float(_stats_drain_wave[bar_idx]["position"]) if bool(_stats_drain_wave[bar_idx]["active"]) else -1.0
		mat.set_shader_parameter("gain_wave_pos", gain_pos)
		mat.set_shader_parameter("drain_wave_pos", drain_pos)


func _update_enemy_bar_display() -> void:
	if not _enemy_shield_bar or not _enemy_hull_bar:
		return
	# Shield
	var s_ratio: float = _enemy_shield / maxf(_enemy_shield_max, 1.0) if _enemy_shield_max > 0.0 else 0.0
	_enemy_shield_bar.max_value = _enemy_shield_max
	_enemy_shield_bar.value = _enemy_shield
	if _enemy_shield_bar.material is ShaderMaterial:
		var mat: ShaderMaterial = _enemy_shield_bar.material as ShaderMaterial
		mat.set_shader_parameter("fill_ratio", s_ratio)
		var gain_pos: float = float(_enemy_shield_gain_wave["position"]) if bool(_enemy_shield_gain_wave["active"]) else -1.0
		var drain_pos: float = float(_enemy_shield_drain_wave["position"]) if bool(_enemy_shield_drain_wave["active"]) else -1.0
		mat.set_shader_parameter("gain_wave_pos", gain_pos)
		mat.set_shader_parameter("drain_wave_pos", drain_pos)
	# Hull
	var h_ratio: float = _enemy_hull / maxf(_enemy_hull_max, 1.0) if _enemy_hull_max > 0.0 else 0.0
	_enemy_hull_bar.max_value = _enemy_hull_max
	_enemy_hull_bar.value = _enemy_hull
	if _enemy_hull_bar.material is ShaderMaterial:
		var mat: ShaderMaterial = _enemy_hull_bar.material as ShaderMaterial
		mat.set_shader_parameter("fill_ratio", h_ratio)
		var drain_pos: float = float(_enemy_hull_drain_wave["position"]) if bool(_enemy_hull_drain_wave["active"]) else -1.0
		mat.set_shader_parameter("gain_wave_pos", -1.0)
		mat.set_shader_parameter("drain_wave_pos", drain_pos)


func _refresh_stats_bars() -> void:
	for i in _stats_preview_bars.size():
		if i >= BAR_TYPES.size():
			break
		var bar: ProgressBar = _stats_preview_bars[i]
		var bar_max: float = _stats_bar_maxes[i]
		bar.max_value = bar_max
		bar.value = _stats_bar_values[i]
		var color: Color = _stats_bar_base_colors[i]
		ThemeManager.apply_led_bar(bar, color, _stats_bar_values[i] / maxf(bar_max, 1.0), 20)


# ── Enemy Damage Test ────────────────────────────────────────

func _refresh_enemy_list() -> void:
	if not _enemy_selector:
		return
	_enemy_selector.clear()
	_enemy_selector.add_item("(none)")
	_enemy_ids.clear()
	_enemy_cache.clear()
	var enemies: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	for e in enemies:
		_enemy_ids.append(e.id)
		_enemy_cache[e.id] = e
		var hp_text: String = "%s  [S:%d H:%d]" % [e.display_name, int(e.stats.get("shield_hp", 0)), int(e.stats.get("hull_hp", 0))]
		_enemy_selector.add_item(hp_text)


func _on_enemy_selected(idx: int) -> void:
	if idx <= 0:
		_enemy_section.visible = false
		return
	var eid: String = _enemy_ids[idx - 1]
	var ship: ShipData = _enemy_cache.get(eid) as ShipData
	if not ship:
		return
	_load_enemy(ship)


func _load_enemy(ship: ShipData) -> void:
	_enemy_shield_max = float(ship.stats.get("shield_hp", 0.0))
	_enemy_shield = _enemy_shield_max
	_enemy_hull_max = float(ship.stats.get("hull_hp", 30.0))
	_enemy_hull = _enemy_hull_max
	_enemy_shield_regen = float(ship.stats.get("shield_regen", 0.0))
	_enemy_shield_seg = int(ship.stats.get("shield_segments", 0))
	_enemy_hull_seg = int(ship.stats.get("hull_segments", 4))

	# Setup bars
	var shield_color: Color = ThemeManager.get_color("bar_shield")
	var hull_color: Color = ThemeManager.get_color("bar_hull")
	_enemy_shield_bar.max_value = maxf(_enemy_shield_max, 1.0)
	_enemy_shield_bar.value = _enemy_shield
	ThemeManager.apply_led_bar(_enemy_shield_bar, shield_color, _enemy_shield / maxf(_enemy_shield_max, 1.0), _enemy_shield_seg)
	_enemy_hull_bar.max_value = maxf(_enemy_hull_max, 1.0)
	_enemy_hull_bar.value = _enemy_hull
	ThemeManager.apply_led_bar(_enemy_hull_bar, hull_color, 1.0, _enemy_hull_seg)

	# Reset TTK
	_enemy_ttk_timer = 0.0
	_enemy_ttk_active = false
	_enemy_ttk_done = false
	_enemy_ttk_label.text = "TTK: —"
	_enemy_shield_gain_wave = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
	_enemy_shield_drain_wave = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
	_enemy_hull_drain_wave = {"active": false, "position": -1.0, "speed": WAVE_SPEED}

	_enemy_section.visible = true


func _on_enemy_reset() -> void:
	var idx: int = _enemy_selector.selected
	if idx <= 0:
		return
	var eid: String = _enemy_ids[idx - 1]
	var ship: ShipData = _enemy_cache.get(eid) as ShipData
	if ship:
		_load_enemy(ship)


func _collect_bar_effects() -> Dictionary:
	var result: Dictionary = {}
	for bar_type in BAR_TYPES:
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0:
			result[bar_type] = slider.value
	return result


func _mark_dirty() -> void:
	if not _ui_ready or _populating:
		return
	if not _dirty:
		_dirty = true
		_update_dirty_display()


func _mark_clean() -> void:
	_dirty = false
	_update_dirty_display()


func _update_dirty_display() -> void:
	if _name_header_label:
		_name_header_label.text = "COMPONENT NAME *" if _dirty else "COMPONENT NAME"
	if _dirty and _status_label:
		_status_label.text = "* Unsaved changes"


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
	if _enemy_reset_button:
		ThemeManager.apply_button_style(_enemy_reset_button)
	if _name_input:
		_name_input.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		_name_input.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	# Update stats preview bar base colors
	var specs: Array = ThemeManager.get_status_bar_specs()
	for i in _stats_preview_bars.size():
		if i < specs.size():
			_stats_bar_base_colors[i] = ThemeManager.resolve_bar_color(specs[i])
	_refresh_stats_bars()
