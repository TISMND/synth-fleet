class_name DeviceTabBase
extends MarginContainer
## Base class for device editor tabs (Field Emitters, Orbital Generators).
## Subclasses override virtual methods to customize visual mode, preview, and data.

const BAR_TYPES: Array[String] = ["shield", "hull", "thermal", "electric"]
const BAR_TYPE_LABELS: Array[String] = ["SHD", "HUL", "THR", "ELC"]
const BAR_TYPE_COLOR_KEYS: Array[String] = ["bar_shield", "bar_hull", "bar_thermal", "bar_electric"]

const SNAP_MODES: Array[Dictionary] = EditorConstants.SNAP_MODES
const BARS_OPTIONS: Array[Dictionary] = EditorConstants.BARS_OPTIONS

const DEVICE_TYPES: Array[String] = ["shield_aura", "damage_aura", "reflect", "regen", "invincibility", "emp", "slow_field"]

const DEVICE_MECHANIC_PARAMS: Dictionary = {
	"shield_aura": {"absorption_rate": [0.1, 10.0, 1.0, 0.1]},
	"damage_aura": {"damage_per_sec": [0.1, 20.0, 5.0, 0.1]},
	"reflect": {"reflect_chance": [0.01, 1.0, 0.3, 0.01]},
	"regen": {"regen_rate": [0.1, 10.0, 1.0, 0.1], "regen_bar": [0.0, 3.0, 0.0, 1.0]},
	"invincibility": {"duration": [0.1, 5.0, 1.0, 0.1]},
	"emp": {"stun_duration": [0.1, 5.0, 1.0, 0.1]},
	"slow_field": {"slow_factor": [0.1, 0.9, 0.5, 0.05]},
}

# UI references — shared
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _new_button: Button
var _status_label: Label
var _tab_container: TabContainer

# Timing subtab
var _waveform_editor: WaveformEditor
var _loop_browser: LoopBrowser
var _mute_button: Button
var _snap_button: OptionButton
var _grid_toggle: Button
var _bars_button: OptionButton

# Preview panel
var _preview_ship_renderer: ShipRenderer = null
var _preview_bars: Array[ProgressBar] = []
var _preview_bar_base_colors: Array[Color] = []
var _preview_bar_brightness: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _preview_viewport: SubViewport = null

# Mechanics subtab
var _device_type_button: OptionButton
var _mechanic_params_container: VBoxContainer
var _mechanic_param_sliders: Dictionary = {}
var _bar_effect_sliders: Dictionary = {}
var _passive_effect_sliders: Dictionary = {}
var _effect_rate_label: Label = null
var _speed_modifier_slider: HSlider
var _accel_modifier_slider: HSlider

# Transition controls
var _transition_mode_button: OptionButton
var _transition_ms_slider: HSlider
var _transition_ms_label: Label

# Stats bar effect preview
var _stats_preview_bars: Array[ProgressBar] = []
var _stats_bar_base_colors: Array[Color] = []
var _stats_bar_values: Array[float] = [50.0, 40.0, 30.0, 40.0]
var _stats_bar_maxes: Array[float] = [100.0, 80.0, 60.0, 80.0]
var _stats_bar_names: Array[String] = []
var _stats_gain_wave: Array[Dictionary] = []
var _stats_drain_wave: Array[Dictionary] = []
const WAVE_SPEED: float = 2.5
const WAVE_MIN_CHANGE: float = 0.01
const BAR_MAX_DEFAULTS: Array[float] = [100.0, 80.0, 60.0, 80.0]


# Component name
var _name_input: LineEdit
var _desc_input: TextEdit

# Dirty tracking
var _dirty: bool = false
var _populating: bool = false

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false
var _prev_loop_progress: float = -1.0
var _auto_pulse_timer: float = 0.0


# ── Virtual methods (override in subclasses) ───────────────

func _get_visual_mode() -> String:
	return "field"

func _get_type_label() -> String:
	return "DEVICE"

func _get_id_prefix() -> String:
	return "dev_"

func _get_save_label() -> String:
	return "SAVE " + _get_type_label()

func _build_visual_tab() -> Control:
	return Control.new()

func _collect_visual_data(data: Dictionary) -> void:
	pass

func _populate_visual_fields(_device: DeviceData) -> void:
	pass

func _reset_visual_defaults() -> void:
	pass

func _setup_visual_preview(_viewport: SubViewport) -> void:
	pass

func _update_visual_preview() -> void:
	pass

func _on_trigger_crossed() -> void:
	pass

func _on_auto_pulse() -> void:
	pass

func _update_visual_preview_frame(_delta: float) -> void:
	pass

func _get_bar_effect_range() -> Vector2:
	return Vector2(-10.0, 10.0)

func _get_passive_effect_range() -> Vector2:
	return Vector2(-10.0, 10.0)

func _build_post_waveform_content(_parent: VBoxContainer) -> void:
	pass

func _on_snap_mode_updated(_mode: int) -> void:
	pass

func _on_bars_updated(_bars: int) -> void:
	pass

func _get_visual_pulse_triggers() -> Array:
	return []

func _on_visual_pulse_crossed() -> void:
	pass

func _save_data(id: String, data: Dictionary) -> void:
	pass

func _rename_data(old_id: String, new_id: String, data: Dictionary) -> void:
	pass

func _delete_data(id: String) -> void:
	pass

func _list_ids() -> Array[String]:
	return []

func _load_data(id: String) -> DeviceData:
	return null


# ── Lifecycle ──────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	_waveform_editor.set_snap_mode(16)
	_on_snap_mode_updated(16)
	# Sync lanes with waveform's detected bars (default 2 if auto/unknown)
	var init_bars: int = _waveform_editor._loop_length_bars if _waveform_editor._loop_length_bars > 0 else 2
	_on_bars_updated(init_bars)
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	_update_preview(delta)


# ── UI Construction ─────────────────────────────────────────

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

	# Main content
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 350
	root.add_child(split)

	# Left: Preview panel
	var left_panel := _build_preview_panel()
	split.add_child(left_panel)

	# Right: TabContainer with subtabs
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_tab_container)

	var timing_tab := _build_timing_tab()
	timing_tab.name = "Timing"
	_tab_container.add_child(timing_tab)

	var visual_tab := _build_visual_tab()
	visual_tab.name = "Visual"
	_tab_container.add_child(visual_tab)

	var stats_tab := _build_mechanics_tab()
	stats_tab.name = "Stats"
	_tab_container.add_child(stats_tab)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = _get_save_label()
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 350
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = _get_type_label() + " PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)
	_section_headers.append(preview_label)

	# SubViewport for preview
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(300, 300)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(300, 300)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.transparent_bg = false
	viewport_container.add_child(_preview_viewport)

	VFXFactory.add_bloom_to_viewport(_preview_viewport)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_viewport.add_child(bg)

	# Ship preview
	_preview_ship_renderer = ShipRenderer.new()
	_preview_ship_renderer.ship_id = 0
	_preview_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	_preview_ship_renderer.animate = true
	_preview_ship_renderer.position = Vector2(150, 150)
	_preview_ship_renderer.scale = Vector2(0.7, 0.7)
	_preview_viewport.add_child(_preview_ship_renderer)

	# Let subclass add its preview nodes
	_setup_visual_preview(_preview_viewport)

	_add_separator(vbox)

	# Status bars
	var specs: Array = ThemeManager.get_status_bar_specs()
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var bar_label := Label.new()
		bar_label.text = str(spec["name"])
		vbox.add_child(bar_label)

		var seg_count: int = int(ShipData.DEFAULT_SEGMENTS.get(str(spec["name"]), 8))
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 18
		bar.max_value = float(seg_count)
		bar.value = float(seg_count) * 0.5
		bar.show_percentage = false
		vbox.add_child(bar)

		var color: Color = ThemeManager.resolve_bar_color(spec)
		ThemeManager.apply_led_bar(bar, color, 0.5, seg_count)
		_preview_bars.append(bar)
		_preview_bar_base_colors.append(color)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(bottom_spacer)

	return panel


func _build_timing_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Name
	_add_section_header(vbox, _get_type_label() + " NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_name_input.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_name_input.text_changed.connect(func(_t: String) -> void: _mark_dirty())
	vbox.add_child(_name_input)

	_desc_input = TextEdit.new()
	_desc_input.placeholder_text = "Description (shows in hangar picker)..."
	_desc_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_input.custom_minimum_size.y = 50
	_desc_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_desc_input.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body") - 2)
	_desc_input.add_theme_color_override("font_color", ThemeManager.get_color("body"))
	_desc_input.text_changed.connect(func() -> void: _mark_dirty())
	vbox.add_child(_desc_input)

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

	# Control row
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
	_bars_button.selected = 0
	_bars_button.item_selected.connect(_on_bars_changed)
	control_row.add_child(_bars_button)

	# Subclass hook for post-waveform content (e.g. cosmetic pulse lane)
	_build_post_waveform_content(vbox)

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

	# Loop Browser
	_add_section_header(vbox, "LOOP BROWSER")
	_loop_browser = LoopBrowser.new()
	_loop_browser.loop_selected.connect(_on_loop_selected)
	vbox.add_child(_loop_browser)
	_loop_browser.call_deferred("refresh_usage")

	return scroll


func _build_mechanics_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Bar Effect Preview
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

		ThemeManager.apply_led_bar(bar, color, bar_start / bar_max, 20)
		_stats_preview_bars.append(bar)
		_stats_bar_base_colors.append(color)
		_stats_bar_names.append(str(spec["name"]))
		_stats_bar_values[i] = bar_start
		_stats_bar_maxes[i] = bar_max
		_stats_gain_wave.append({"active": false, "position": -1.0, "speed": WAVE_SPEED})
		_stats_drain_wave.append({"active": false, "position": -1.0, "speed": WAVE_SPEED})

	var reset_btn := Button.new()
	reset_btn.text = "RESET BARS"
	reset_btn.custom_minimum_size.x = 120
	reset_btn.pressed.connect(_on_reset_stats_bars)
	ThemeManager.apply_button_style(reset_btn)
	form.add_child(reset_btn)

	_add_separator(form)

	# Bar Effects (per trigger hit)
	var bar_range: Vector2 = _get_bar_effect_range()
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
		slider.min_value = bar_range.x
		slider.max_value = bar_range.y
		slider.value = 0.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 150
		row.add_child(slider)

		var val_edit: SliderValueEdit = SliderValueEdit.create(slider)
		row.add_child(val_edit)

		slider.value_changed.connect(func(_val: float) -> void:
			_mark_dirty()
		)

		_bar_effect_sliders[bar_type] = slider

	_add_separator(form)

	# Passive Effects
	var passive_range: Vector2 = _get_passive_effect_range()
	_add_section_header(form, "PASSIVE EFFECTS (per second, while active)")
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
		slider.min_value = passive_range.x
		slider.max_value = passive_range.y
		slider.value = 0.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 150
		row.add_child(slider)

		var val_edit: SliderValueEdit = SliderValueEdit.create(slider)
		row.add_child(val_edit)

		slider.value_changed.connect(func(_val: float) -> void:
			_mark_dirty()
		)

		_passive_effect_sliders[bar_type] = slider

	# Effect rate readout
	_effect_rate_label = Label.new()
	_effect_rate_label.text = "No bar effects"
	_effect_rate_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	_effect_rate_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body") - 1)
	_effect_rate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_effect_rate_label)

	_add_separator(form)

	# Ship Modifiers
	_add_section_header(form, "SHIP MODIFIERS (while active)")
	var speed_row: Array = _add_slider_row(form, "Speed %:", -75.0, 200.0, 0.0, 5.0)
	_speed_modifier_slider = speed_row[0]
	var accel_row: Array = _add_slider_row(form, "Accel %:", -75.0, 200.0, 0.0, 5.0)
	_accel_modifier_slider = accel_row[0]

	return scroll


func _rebuild_mechanic_params(device_type: String) -> void:
	if not _mechanic_params_container:
		return
	for child in _mechanic_params_container.get_children():
		child.queue_free()
	_mechanic_param_sliders.clear()

	var defs: Dictionary = DEVICE_MECHANIC_PARAMS.get(device_type, {}) as Dictionary
	if defs.is_empty():
		var lbl := Label.new()
		lbl.text = "  (no type-specific parameters)"
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		_mechanic_params_container.add_child(lbl)
		return

	for param_name in defs:
		var bounds: Array = defs[param_name]
		var row: Array = _add_slider_row(_mechanic_params_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_mechanic_param_sliders[param_name] = row[0]


func _on_device_type_changed(_idx: int) -> void:
	if not _device_type_button:
		return
	var device_type: String = _device_type_button.get_item_text(_device_type_button.selected)
	_rebuild_mechanic_params(device_type)
	_mark_dirty()


# ── Preview Update (called every frame) ───────────────────

func _update_preview(delta: float) -> void:
	if not _ui_ready:
		return

	# Auto-pulse preview (cosmetic only — bars + subclass visual, NOT trigger spawns)
	_auto_pulse_timer += delta
	if _auto_pulse_timer >= 1.5:
		_auto_pulse_timer = 0.0
		_on_auto_pulse()
		for i in _preview_bar_brightness.size():
			_preview_bar_brightness[i] = 1.0

	# Subclass frame update
	_update_visual_preview_frame(delta)

	# Trigger crossing detection from loop
	var audition_id: String = "loop_browser_audition"
	if LoopMixer.has_loop(audition_id):
		var pos_sec: float = LoopMixer.get_playback_position(audition_id)
		var duration: float = LoopMixer.get_stream_duration(audition_id)
		if pos_sec >= 0.0 and duration > 0.0:
			var progress: float = clampf(pos_sec / duration, 0.0, 1.0)
			var prev: float = _prev_loop_progress
			if prev >= 0.0:
				var triggers: Array = _waveform_editor.get_triggers() if _waveform_editor else []
				for t in triggers:
					var tval: float = float(t)
					var crossed: bool = false
					if progress < prev:
						crossed = tval > prev or tval <= progress
					else:
						crossed = tval > prev and tval <= progress
					if crossed:
						_on_trigger_crossed()
						_apply_stats_bar_effects_once()
						for i in _preview_bar_brightness.size():
							_preview_bar_brightness[i] = 1.0
				# Cosmetic trigger crossing (visual pulse lane)
				var vis_triggers: Array = _get_visual_pulse_triggers()
				for vt in vis_triggers:
					var vtval: float = float(vt)
					var vis_crossed: bool = false
					if progress < prev:
						vis_crossed = vtval > prev or vtval <= progress
					else:
						vis_crossed = vtval > prev and vtval <= progress
					if vis_crossed:
						_on_visual_pulse_crossed()
			_prev_loop_progress = progress

	# Decay bar brightness
	for i in _preview_bars.size():
		if i >= _preview_bar_brightness.size():
			break
		_preview_bar_brightness[i] = maxf(0.0, _preview_bar_brightness[i] - delta / 0.3)
		_apply_bar_glow(i, _preview_bar_brightness[i])

	# Passive effects
	for i in BAR_TYPES.size():
		var bar_type: String = BAR_TYPES[i]
		var slider: HSlider = _passive_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0 and i < _preview_bars.size():
			var bar: ProgressBar = _preview_bars[i]
			bar.value = clampf(bar.value + slider.value * delta, 0.0, bar.max_value)

	# Stats preview bar waves + passive
	if not _stats_preview_bars.is_empty():
		for i in BAR_TYPES.size():
			var bar_type: String = BAR_TYPES[i]
			var slider: HSlider = _passive_effect_sliders.get(bar_type) as HSlider
			if slider and slider.value != 0.0 and i < _stats_preview_bars.size():
				var old_val: float = _stats_bar_values[i]
				_stats_bar_values[i] = clampf(old_val + slider.value * delta, 0.0, _stats_bar_maxes[i])
		for i in _stats_preview_bars.size():
			if i >= BAR_TYPES.size():
				break
			_advance_stats_wave(_stats_gain_wave[i], delta, 1.0)
			_advance_stats_wave(_stats_drain_wave[i], delta, -1.0)
			_update_stats_bar_display(i)


func _apply_bar_glow(bar_idx: int, glow: float) -> void:
	if bar_idx >= _preview_bars.size() or bar_idx >= _preview_bar_base_colors.size():
		return
	var bar: ProgressBar = _preview_bars[bar_idx]
	if not bar.material is ShaderMaterial:
		return
	var mat: ShaderMaterial = bar.material as ShaderMaterial
	var base_color: Color = _preview_bar_base_colors[bar_idx]
	var bright: Color = base_color.lightened(0.6)
	var modulated: Color = base_color.lerp(bright, clampf(glow, 0.0, 1.0))
	mat.set_shader_parameter("fill_color", modulated)


func _apply_stats_bar_effects_once() -> void:
	for bi in BAR_TYPES.size():
		var bar_type: String = BAR_TYPES[bi]
		var slider: HSlider = _bar_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0 and bi < _stats_preview_bars.size():
			_stats_bar_values[bi] = clampf(_stats_bar_values[bi] + slider.value, 0.0, _stats_bar_maxes[bi])
			# Trigger wave based on intended delta, not clamped result
			if slider.value > 0.0:
				if not bool(_stats_gain_wave[bi].get("active", false)):
					_stats_gain_wave[bi]["position"] = 0.0
				_stats_gain_wave[bi]["active"] = true
			elif slider.value < 0.0:
				if not bool(_stats_drain_wave[bi].get("active", false)):
					_stats_drain_wave[bi]["position"] = 1.0
				_stats_drain_wave[bi]["active"] = true


func _advance_stats_wave(wave: Dictionary, delta: float, direction: float) -> void:
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


func _update_stats_bar_display(bar_idx: int) -> void:
	if bar_idx < 0 or bar_idx >= _stats_preview_bars.size():
		return
	var bar: ProgressBar = _stats_preview_bars[bar_idx]
	var bar_max: float = _stats_bar_maxes[bar_idx]
	var ratio: float = _stats_bar_values[bar_idx] / maxf(bar_max, 1.0)
	bar.max_value = bar_max
	bar.value = _stats_bar_values[bar_idx]
	if bar.material is ShaderMaterial:
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		mat.set_shader_parameter("fill_ratio", ratio)
		var gain_pos: float = float(_stats_gain_wave[bar_idx]["position"]) if bool(_stats_gain_wave[bar_idx]["active"]) else -1.0
		var drain_pos: float = float(_stats_drain_wave[bar_idx]["position"]) if bool(_stats_drain_wave[bar_idx]["active"]) else -1.0
		mat.set_shader_parameter("gain_wave_pos", gain_pos)
		mat.set_shader_parameter("drain_wave_pos", drain_pos)


func _on_reset_stats_bars() -> void:
	for i in _stats_bar_values.size():
		_stats_bar_values[i] = _stats_bar_maxes[i] * 0.5
		_stats_gain_wave[i] = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
		_stats_drain_wave[i] = {"active": false, "position": -1.0, "speed": WAVE_SPEED}
	_refresh_stats_bars()


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


# ── Data Collection ────────────────────────────────────────

func _collect_device_data() -> Dictionary:
	var triggers: Array = _waveform_editor.get_triggers() if _waveform_editor else []

	var bar_effects: Dictionary = {}
	for bar_type in _bar_effect_sliders:
		var slider: HSlider = _bar_effect_sliders[bar_type]
		if slider.value != 0.0:
			bar_effects[bar_type] = slider.value

	var passive_effects: Dictionary = {}
	for bar_type in _passive_effect_sliders:
		var slider: HSlider = _passive_effect_sliders[bar_type]
		if slider.value != 0.0:
			passive_effects[bar_type] = slider.value

	var mechanic_params: Dictionary = {}
	for param_name in _mechanic_param_sliders:
		var slider: HSlider = _mechanic_param_sliders[param_name]
		mechanic_params[param_name] = slider.value

	var data: Dictionary = {
		"id": _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"description": _desc_input.text,
		"loop_file_path": _loop_browser.get_selected_path() if _loop_browser else "",
		"loop_length_bars": _waveform_editor.get_detected_bars() if _waveform_editor else 2,
		"pulse_triggers": triggers,
		"visual_mode": _get_visual_mode(),
		"radius": 100.0,
		"fade_in_duration": 0.3,
		"fade_out_duration": 0.3,
		"animation_speed": 1.0,
		"device_type": _device_type_button.get_item_text(_device_type_button.selected) if _device_type_button else "shield_aura",
		"mechanic_params": mechanic_params,
		"bar_effects": bar_effects,
		"passive_effects": passive_effects,
		"transition_mode": "fade" if _transition_mode_button.selected == 1 else "instant",
		"transition_ms": int(_transition_ms_slider.value),
		"speed_modifier": _speed_modifier_slider.value if _speed_modifier_slider else 0.0,
		"accel_modifier": _accel_modifier_slider.value if _accel_modifier_slider else 0.0,
	}

	# Let subclass add its visual-mode-specific fields
	_collect_visual_data(data)

	return data


# ── Save / Load / Delete ──────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a name first!"
		return
	var data: Dictionary = _collect_device_data()
	var new_id: String = str(data["id"])
	var old_id: String = _current_id
	if old_id != "" and old_id != new_id:
		_rename_data(old_id, new_id, data)
		_status_label.text = "Renamed: " + old_id + " → " + new_id
	else:
		_save_data(new_id, data)
		_status_label.text = "Saved: " + new_id
	_current_id = new_id
	_refresh_load_list()
	_dirty = false


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var device: DeviceData = _load_data(id)
	if not device:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_device(device)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "Nothing loaded to delete."
		return
	_delete_data(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_populating = true
	_name_input.text = ""
	_desc_input.text = ""
	if _device_type_button:
		_device_type_button.selected = 0
		_rebuild_mechanic_params("shield_aura")
	for bar_type in _bar_effect_sliders:
		var slider: HSlider = _bar_effect_sliders[bar_type]
		slider.value = 0.0
	for bar_type in _passive_effect_sliders:
		var slider: HSlider = _passive_effect_sliders[bar_type]
		slider.value = 0.0
	if _waveform_editor:
		_waveform_editor.set_triggers([])
	_transition_mode_button.selected = 0
	_on_transition_mode_changed(0)
	_transition_ms_slider.value = 200
	_transition_ms_label.text = "200ms"
	if _speed_modifier_slider:
		_speed_modifier_slider.value = 0.0
	if _accel_modifier_slider:
		_accel_modifier_slider.value = 0.0
	_reset_visual_defaults()
	if not _stats_preview_bars.is_empty():
		_on_reset_stats_bars()
	_populating = false
	_dirty = false
	_update_visual_preview()
	_update_effect_rate_label()
	_status_label.text = "New " + _get_type_label().to_lower() + " — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select " + _get_type_label().to_lower() + ")")
	var ids: Array[String] = _list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_device(device: DeviceData) -> void:
	_populating = true
	_current_id = device.id
	_name_input.text = device.display_name
	_desc_input.text = device.description

	# Load loop into browser + waveform
	if device.loop_file_path != "":
		_loop_browser.select_path(device.loop_file_path)
		_waveform_editor.set_stream_from_path(device.loop_file_path)
		_waveform_editor.set_loop_length_bars(device.loop_length_bars)

	# Set triggers
	var triggers: Array[float] = []
	for t in device.pulse_triggers:
		triggers.append(float(t))
	_waveform_editor.set_triggers(triggers)

	# Mechanics
	if _device_type_button:
		var type_idx: int = DEVICE_TYPES.find(device.device_type)
		_device_type_button.selected = type_idx if type_idx >= 0 else 0
		_rebuild_mechanic_params(device.device_type)
		for param_name in device.mechanic_params:
			if param_name in _mechanic_param_sliders:
				var slider: HSlider = _mechanic_param_sliders[param_name]
				slider.value = float(device.mechanic_params[param_name])

	for bar_type in BAR_TYPES:
		if bar_type in _bar_effect_sliders:
			var slider: HSlider = _bar_effect_sliders[bar_type]
			slider.value = float(device.bar_effects.get(bar_type, 0.0))
		if bar_type in _passive_effect_sliders:
			var slider: HSlider = _passive_effect_sliders[bar_type]
			slider.value = float(device.passive_effects.get(bar_type, 0.0))

	# Ship modifiers
	if _speed_modifier_slider:
		_speed_modifier_slider.value = device.speed_modifier
	if _accel_modifier_slider:
		_accel_modifier_slider.value = device.accel_modifier

	# Transition settings
	if device.transition_mode == "fade":
		_transition_mode_button.selected = 1
	else:
		_transition_mode_button.selected = 0
	_on_transition_mode_changed(_transition_mode_button.selected)
	_transition_ms_slider.value = float(device.transition_ms)
	_transition_ms_label.text = str(device.transition_ms) + "ms"

	# Let subclass populate its visual fields
	_populate_visual_fields(device)

	_populating = false
	_dirty = false
	_update_visual_preview()
	_update_effect_rate_label()


func _generate_id(display_name: String) -> String:
	var prefix: String = _get_id_prefix()
	if display_name.strip_edges() == "":
		return prefix + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower().replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = prefix + str(randi() % 10000)
	else:
		clean = prefix + clean
	return clean


# ── Waveform / Loop Callbacks ─────────────────────────────

func _on_triggers_changed(_triggers: Array) -> void:
	_mark_dirty()


func _on_loop_selected(path: String, _category: String) -> void:
	_waveform_editor.set_stream_from_path(path)
	_mark_dirty()


func _on_play_pause() -> void:
	var audition_id: String = "loop_browser_audition"
	if LoopMixer.has_loop(audition_id):
		if LoopMixer.is_muted(audition_id):
			LoopMixer.unmute(audition_id)
		else:
			LoopMixer.mute(audition_id)


func _on_seek(_position: float) -> void:
	pass  # Seek not directly supported on LoopMixer audition


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


func _on_snap_changed(idx: int) -> void:
	if idx < SNAP_MODES.size():
		var snap_val: int = int(SNAP_MODES[idx]["value"])
		_waveform_editor.set_snap_mode(snap_val)
		_on_snap_mode_updated(snap_val)


func _on_grid_toggled(pressed: bool) -> void:
	_grid_toggle.text = "ON" if pressed else "OFF"
	_waveform_editor.set_show_beat_grid(pressed)


func _on_bars_changed(idx: int) -> void:
	if idx < BARS_OPTIONS.size():
		var bars_val: int = int(BARS_OPTIONS[idx]["value"])
		_waveform_editor.set_loop_length_bars(bars_val)
		# Lanes need a real bar count for snap math — use waveform's detected value if auto
		var lane_bars: int = _waveform_editor._loop_length_bars if _waveform_editor._loop_length_bars > 0 else 2
		_on_bars_updated(lane_bars)


func _on_transition_mode_changed(idx: int) -> void:
	var is_fade: bool = idx == 1
	_transition_ms_slider.editable = is_fade
	_transition_ms_slider.modulate = Color(1, 1, 1, 1.0) if is_fade else Color(1, 1, 1, 0.3)
	_transition_ms_label.modulate = Color(1, 1, 1, 1.0) if is_fade else Color(1, 1, 1, 0.3)
	_mark_dirty()


func _on_transition_ms_changed(val: float) -> void:
	_transition_ms_label.text = str(int(val)) + "ms"
	_mark_dirty()


func _mark_dirty() -> void:
	if _populating:
		return
	_dirty = true
	_update_effect_rate_label()


func _update_effect_rate_label() -> void:
	if not _effect_rate_label:
		return
	var data: Dictionary = _collect_device_data()
	var device: DeviceData = DeviceData.from_dict(data)
	var rates: Dictionary = EffectRateCalculator.calc_device(device)
	var text: String = EffectRateCalculator.format_rates(rates)
	_effect_rate_label.text = text if text != "" else "No bar effects"


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
		_mark_dirty()
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
	if _mute_button:
		ThemeManager.apply_button_style(_mute_button)
	if _grid_toggle:
		ThemeManager.apply_button_style(_grid_toggle)
