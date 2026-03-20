extends MarginContainer
## Power Cores Tab — editor for power cores that pulse status bars at beat-synced triggers.
## Subtabs: Timing (loop + waveform + bar-type triggers), Pulse (global + per-bar settings),
## Mechanics (placeholder), Effects (placeholder).

const BAR_TYPES: Array[String] = ["shield", "hull", "thermal", "electric"]
const BAR_TYPE_LABELS: Array[String] = ["SHD", "HUL", "THR", "ELC"]
const BAR_TYPE_COLOR_KEYS: Array[String] = ["bar_shield", "bar_hull", "bar_thermal", "bar_electric"]

const SNAP_MODES: Array[Dictionary] = EditorConstants.SNAP_MODES
const BARS_OPTIONS: Array[Dictionary] = EditorConstants.BARS_OPTIONS

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
var _bar_type_buttons: Array[Button] = []
var _active_bar_type: int = 0  # Index into BAR_TYPES

# Preview panel (left side)
var _preview_bars: Array[ProgressBar] = []
var _preview_bar_base_colors: Array[Color] = []  # Base colors per bar (from theme)
var _preview_bar_brightness: Array[float] = [0.0, 0.0, 0.0, 0.0]  # 0.0=idle, 1.0=full pulse
var _component_display: Control = null  # Ship component shapes display

# Mechanics subtab
var _mechanics_bar_effect_sliders: Dictionary = {}  # bar_type -> HSlider
var _passive_effect_sliders: Dictionary = {}  # bar_type -> HSlider

# Pulse subtab
var _global_brightness_slider: HSlider
var _global_brighten_slider: HSlider
var _global_dim_slider: HSlider
var _per_bar_overrides: Dictionary = {}  # bar_type -> {checkbox, brightness, brighten, dim, container}

# Merged triggers for waveform editor + parallel type tracking
var _merged_triggers: Array = []       # Array[float] — sorted normalized times
var _trigger_types: Array = []         # Array[String] — bar type per trigger index

# Component name
var _name_input: LineEdit
var _name_header_label: Label

# Dirty tracking
var _dirty: bool = false
var _populating: bool = false

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false
var _prev_loop_progress: float = -1.0


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	_waveform_editor.set_snap_mode(16)
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	_update_preview_bars(delta)


# ── UI Construction ─────────────────────────────────────────

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
	split.split_offset = 300
	root.add_child(split)

	# Left: Preview panel with 4 LED bars
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

	var pulse_tab := _build_pulse_tab()
	pulse_tab.name = "Pulse"
	_tab_container.add_child(pulse_tab)

	var mechanics_tab := _build_mechanics_tab()
	mechanics_tab.name = "Mechanics"
	_tab_container.add_child(mechanics_tab)

	var effects_tab := _build_placeholder_tab("Effects — Coming soon")
	effects_tab.name = "Effects"
	_tab_container.add_child(effects_tab)

	# Bottom bar: Save + Status
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE POWER CORE"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = "PULSE PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)
	_section_headers.append(preview_label)

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
		bar.custom_minimum_size.y = 20
		bar.max_value = float(seg_count)
		bar.value = float(seg_count) * 0.5
		bar.show_percentage = false
		vbox.add_child(bar)

		var color: Color = ThemeManager.resolve_bar_color(spec)
		ThemeManager.apply_led_bar(bar, color, 0.5, seg_count)
		_preview_bars.append(bar)
		_preview_bar_base_colors.append(color)

		if i < specs.size() - 1:
			var gap := Control.new()
			gap.custom_minimum_size.y = 8
			vbox.add_child(gap)

	_add_separator(vbox)

	# Ship component shapes display
	var shapes_label := Label.new()
	shapes_label.text = "COMPONENTS"
	shapes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(shapes_label)
	_section_headers.append(shapes_label)

	_component_display = ComponentShapeDisplay.new()
	_component_display.custom_minimum_size = Vector2(250, 140)
	_component_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_component_display)

	# Spacer to push content toward top
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

	# Component Name
	_name_header_label = _add_section_header(vbox, "COMPONENT NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter power core name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_name_input.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_name_input.text_changed.connect(func(_t: String) -> void: _mark_dirty())
	vbox.add_child(_name_input)

	_add_separator(vbox)

	# Bar type selector
	_add_section_header(vbox, "BAR TYPE")
	var type_row := HBoxContainer.new()
	vbox.add_child(type_row)

	for i in BAR_TYPES.size():
		var btn := Button.new()
		btn.text = BAR_TYPE_LABELS[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.custom_minimum_size = Vector2(70, 32)
		var color_key: String = BAR_TYPE_COLOR_KEYS[i]
		var bar_color: Color = ThemeManager.get_color(color_key)
		btn.add_theme_color_override("font_color", bar_color)
		btn.add_theme_color_override("font_pressed_color", bar_color)
		btn.add_theme_color_override("font_hover_color", bar_color)
		btn.add_theme_color_override("font_hover_pressed_color", bar_color)
		var idx: int = i
		btn.pressed.connect(_on_bar_type_pressed.bind(idx))
		ThemeManager.apply_button_style(btn)
		type_row.add_child(btn)
		_bar_type_buttons.append(btn)

	# Waveform Editor
	_add_section_header(vbox, "WAVEFORM / TRIGGERS")
	_waveform_editor = WaveformEditor.new()
	_waveform_editor.custom_minimum_size = Vector2(400, 140)
	_waveform_editor.triggers_changed.connect(_on_triggers_changed)
	_waveform_editor.play_pause_requested.connect(_on_play_pause)
	_waveform_editor.seek_requested.connect(_on_seek)
	_waveform_editor.set_audition_loop_id("loop_browser_audition")
	_waveform_editor.set_marker_color_callback(_get_trigger_color)
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

	# Loop Browser
	_add_section_header(vbox, "LOOP BROWSER")
	_loop_browser = LoopBrowser.new()
	_loop_browser.loop_selected.connect(_on_loop_selected)
	vbox.add_child(_loop_browser)
	_loop_browser.call_deferred("refresh_usage")

	return scroll


func _build_pulse_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Global pulse settings
	_add_section_header(form, "GLOBAL PULSE SETTINGS")
	var brightness_row := _add_slider_row(form, "Brightness:", 0.0, 1.0, 0.5, 0.01)
	_global_brightness_slider = brightness_row[0]
	var brighten_row := _add_slider_row(form, "Brighten (s):", 0.01, 0.5, 0.05, 0.01)
	_global_brighten_slider = brighten_row[0]
	var dim_row := _add_slider_row(form, "Dim (s):", 0.05, 2.0, 0.3, 0.01)
	_global_dim_slider = dim_row[0]

	_add_separator(form)

	# Per-bar override sections
	for i in BAR_TYPES.size():
		var bar_type: String = BAR_TYPES[i]
		var color_key: String = BAR_TYPE_COLOR_KEYS[i]
		var bar_color: Color = ThemeManager.get_color(color_key)

		var header := _add_section_header(form, BAR_TYPE_LABELS[i] + " OVERRIDES")
		header.add_theme_color_override("font_color", bar_color)

		var checkbox := CheckBox.new()
		checkbox.text = "Override global settings"
		checkbox.button_pressed = false
		form.add_child(checkbox)

		var override_container := VBoxContainer.new()
		override_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		override_container.visible = false
		form.add_child(override_container)

		var disable_checkbox := CheckBox.new()
		disable_checkbox.text = "Disable pulsing"
		disable_checkbox.button_pressed = false
		disable_checkbox.toggled.connect(func(_p: bool) -> void: _mark_dirty())
		override_container.add_child(disable_checkbox)

		var b_row := _add_slider_row(override_container, "Brightness:", 0.0, 1.0, 0.5, 0.01)
		var bn_row := _add_slider_row(override_container, "Brighten (s):", 0.01, 0.5, 0.05, 0.01)
		var d_row := _add_slider_row(override_container, "Dim (s):", 0.05, 2.0, 0.3, 0.01)

		checkbox.toggled.connect(func(pressed: bool) -> void:
			override_container.visible = pressed
			_mark_dirty()
		)

		_per_bar_overrides[bar_type] = {
			"checkbox": checkbox,
			"disable_checkbox": disable_checkbox,
			"brightness": b_row[0],
			"brighten": bn_row[0],
			"dim": d_row[0],
			"container": override_container,
		}

		if i < BAR_TYPES.size() - 1:
			_add_separator(form)

	return scroll


func _build_mechanics_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

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
		slider.min_value = -10.0
		slider.max_value = 10.0
		slider.value = 0.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 150
		row.add_child(slider)

		var val_label := Label.new()
		val_label.text = "0.00"
		val_label.custom_minimum_size.x = 60
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_label)

		slider.value_changed.connect(func(val: float) -> void:
			val_label.text = "%.2f" % val
			_mark_dirty()
		)

		_mechanics_bar_effect_sliders[bar_type] = slider

	_add_separator(form)

	# Passive Effects (per second)
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
		slider.min_value = -10.0
		slider.max_value = 10.0
		slider.value = 0.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 150
		row.add_child(slider)

		var val_label := Label.new()
		val_label.text = "0.00"
		val_label.custom_minimum_size.x = 60
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_label)

		slider.value_changed.connect(func(val: float) -> void:
			val_label.text = "%.2f" % val
			_mark_dirty()
		)

		_passive_effect_sliders[bar_type] = slider

	return scroll


func _build_placeholder_tab(text: String) -> Control:
	var container := MarginContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	return container


# ── Bar Type Selector ──────────────────────────────────────

func _on_bar_type_pressed(idx: int) -> void:
	_active_bar_type = idx
	for i in _bar_type_buttons.size():
		_bar_type_buttons[i].button_pressed = (i == idx)


func _get_trigger_color(idx: int) -> Color:
	if idx < 0 or idx >= _trigger_types.size():
		return ThemeManager.get_color("bar_shield")
	var bar_type: String = _trigger_types[idx]
	var type_idx: int = BAR_TYPES.find(bar_type)
	if type_idx < 0:
		return ThemeManager.get_color("bar_shield")
	return ThemeManager.get_color(BAR_TYPE_COLOR_KEYS[type_idx])


# ── Preview Pulsing (glow brightness, not bar fill) ────────

func _update_preview_bars(delta: float) -> void:
	if not _ui_ready:
		return

	var audition_id: String = "loop_browser_audition"
	if not LoopMixer.has_loop(audition_id):
		return

	var pos_sec: float = LoopMixer.get_playback_position(audition_id)
	var duration: float = LoopMixer.get_stream_duration(audition_id)
	if pos_sec < 0.0 or duration <= 0.0:
		return

	var progress: float = clampf(pos_sec / duration, 0.0, 1.0)
	var prev: float = _prev_loop_progress

	# Detect trigger crossings
	if prev >= 0.0:
		for i in _merged_triggers.size():
			var t: float = float(_merged_triggers[i])
			var crossed: bool = false
			if progress < prev:
				# Wrap-around
				crossed = t > prev or t <= progress
			else:
				crossed = t > prev and t <= progress
			if crossed and i < _trigger_types.size():
				var bar_type: String = _trigger_types[i]
				var bar_idx: int = BAR_TYPES.find(bar_type)
				if bar_idx >= 0 and not _is_pulsing_disabled(bar_type):
					_preview_bar_brightness[bar_idx] = 1.0

	_prev_loop_progress = progress

	# Animate brightness decay and apply glow modulation
	for i in _preview_bars.size():
		if i >= BAR_TYPES.size():
			break
		var bar_type: String = BAR_TYPES[i]
		var settings: Dictionary = _get_pulse_settings_for(bar_type)
		var dim_duration: float = float(settings.get("dim_duration", 0.3))
		var pulse_strength: float = float(settings.get("brightness", 0.5))
		if dim_duration > 0.0:
			_preview_bar_brightness[i] = maxf(0.0, _preview_bar_brightness[i] - delta / dim_duration)

		# Modulate bar fill_color brightness via shader parameter
		_apply_bar_glow(i, _preview_bar_brightness[i] * pulse_strength)

	# Passive effects: apply per-second deltas continuously
	for i in BAR_TYPES.size():
		var bar_type: String = BAR_TYPES[i]
		var slider: HSlider = _passive_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0 and i < _preview_bars.size():
			var bar: ProgressBar = _preview_bars[i]
			bar.value = clampf(bar.value + slider.value * delta, 0.0, bar.max_value)

	# Update component shapes display
	if _component_display and _component_display is ComponentShapeDisplay:
		var shape_display: ComponentShapeDisplay = _component_display as ComponentShapeDisplay
		var glow_values: Array[float] = []
		for i in BAR_TYPES.size():
			var settings: Dictionary = _get_pulse_settings_for(BAR_TYPES[i])
			var pulse_strength: float = float(settings.get("brightness", 0.5))
			glow_values.append(_preview_bar_brightness[i] * pulse_strength)
		shape_display.update_glow(glow_values)


func _apply_bar_glow(bar_idx: int, glow: float) -> void:
	## Modulate the LED bar's fill_color brightness without changing fill ratio.
	## glow 0.0 = base color, glow 1.0 = white-hot.
	if bar_idx < 0 or bar_idx >= _preview_bars.size() or bar_idx >= _preview_bar_base_colors.size():
		return
	var bar: ProgressBar = _preview_bars[bar_idx]
	var base_color: Color = _preview_bar_base_colors[bar_idx]

	# Brighten: lerp toward a bright white version of the color
	var bright: Color = base_color.lightened(0.6)
	var modulated: Color = base_color.lerp(bright, clampf(glow, 0.0, 1.0))

	# Update shader fill_color directly on the bar material
	if bar.material is ShaderMaterial:
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		mat.set_shader_parameter("fill_color", modulated)
		# Boost inner_intensity and HDR multiplier for visible glow pulse
		var base_inner: float = ThemeManager.get_float("led_inner_intensity")
		var base_hdr: float = ThemeManager.get_float("led_hdr_multiplier")
		mat.set_shader_parameter("inner_intensity", base_inner + glow * 1.5)
		mat.set_shader_parameter("hdr_multiplier", base_hdr + glow * 0.8)


func _get_pulse_brightness(bar_type: String) -> float:
	var settings: Dictionary = _get_pulse_settings_for(bar_type)
	return float(settings.get("brightness", 0.5))


func _get_pulse_settings_for(bar_type: String) -> Dictionary:
	if not _ui_ready:
		return {"brightness": 0.5, "brighten_duration": 0.05, "dim_duration": 0.3}
	var override_data: Dictionary = _per_bar_overrides.get(bar_type, {}) as Dictionary
	if not override_data.is_empty():
		var checkbox: CheckBox = override_data.get("checkbox") as CheckBox
		if checkbox and checkbox.button_pressed:
			return {
				"brightness": (override_data["brightness"] as HSlider).value,
				"brighten_duration": (override_data["brighten"] as HSlider).value,
				"dim_duration": (override_data["dim"] as HSlider).value,
			}
	return {
		"brightness": _global_brightness_slider.value,
		"brighten_duration": _global_brighten_slider.value,
		"dim_duration": _global_dim_slider.value,
	}


func _is_pulsing_disabled(bar_type: String) -> bool:
	if not _ui_ready:
		return false
	var override_data: Dictionary = _per_bar_overrides.get(bar_type, {}) as Dictionary
	if override_data.is_empty():
		return false
	var checkbox: CheckBox = override_data.get("checkbox") as CheckBox
	if not checkbox or not checkbox.button_pressed:
		return false
	var disable_cb: CheckBox = override_data.get("disable_checkbox") as CheckBox
	return disable_cb != null and disable_cb.button_pressed


# ── Trigger Management ─────────────────────────────────────

func _on_triggers_changed(new_triggers: Array) -> void:
	_mark_dirty()
	# Diff old vs new by time proximity to preserve type assignments
	var old_triggers: Array = _merged_triggers.duplicate()
	var old_types: Array = _trigger_types.duplicate()
	var new_types: Array = []
	var used_old: Array[bool] = []
	used_old.resize(old_triggers.size())
	used_old.fill(false)

	for ni in new_triggers.size():
		var t: float = float(new_triggers[ni])
		var best_old: int = -1
		var best_dist: float = 0.005  # Proximity threshold
		for oi in old_triggers.size():
			if used_old[oi]:
				continue
			var dist: float = absf(float(old_triggers[oi]) - t)
			if dist < best_dist:
				best_dist = dist
				best_old = oi
		if best_old >= 0:
			used_old[best_old] = true
			new_types.append(old_types[best_old])
		else:
			# New trigger — assign active bar type
			new_types.append(BAR_TYPES[_active_bar_type])

	_merged_triggers = new_triggers.duplicate()
	_trigger_types = new_types
	_waveform_editor.queue_redraw()


func _merge_triggers_from_dict(pulse_triggers: Dictionary) -> void:
	## Merge per-bar-type trigger arrays into sorted merged + type arrays.
	var pairs: Array = []  # [[time, type], ...]
	for bar_type in BAR_TYPES:
		var triggers: Array = pulse_triggers.get(bar_type, []) as Array
		for t in triggers:
			pairs.append([float(t), bar_type])
	# Sort by time
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_merged_triggers.clear()
	_trigger_types.clear()
	for pair in pairs:
		_merged_triggers.append(float(pair[0]))
		_trigger_types.append(str(pair[1]))


func _split_triggers_to_dict() -> Dictionary:
	## Split merged triggers back to per-bar-type Dictionary.
	var result: Dictionary = {}
	for i in _merged_triggers.size():
		var bar_type: String = _trigger_types[i] if i < _trigger_types.size() else "shield"
		if not result.has(bar_type):
			result[bar_type] = []
		result[bar_type].append(float(_merged_triggers[i]))
	# Sort each array
	for bar_type in result:
		var arr: Array = result[bar_type]
		arr.sort()
	return result


# ── Loop Browser Events ────────────────────────────────────

func _on_loop_selected(path: String, _category: String) -> void:
	_waveform_editor.set_stream_from_path(path)
	_bars_button.selected = 0
	_prev_loop_progress = -1.0
	_mark_dirty()


func _on_snap_changed(idx: int) -> void:
	var mode: int = int(SNAP_MODES[idx]["value"])
	_waveform_editor.set_snap_mode(mode)


func _on_grid_toggled(pressed: bool) -> void:
	_grid_toggle.text = "ON" if pressed else "OFF"
	_waveform_editor.set_show_beat_grid(pressed)


func _on_bars_changed(idx: int) -> void:
	var bars_val: int = int(BARS_OPTIONS[idx]["value"])
	if bars_val == 0:
		_waveform_editor._auto_detect_bars()
	else:
		_waveform_editor.set_loop_length_bars(bars_val)


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


# ── Data Collection ────────────────────────────────────────

func _collect_power_core_data() -> Dictionary:
	var loop_path: String = _loop_browser.get_selected_path()
	var loop_bars: int = _waveform_editor.get_detected_bars()
	var name_text: String = _name_input.text.strip_edges()
	var id_text: String = _current_id if _current_id != "" else _generate_id(name_text)

	return {
		"id": id_text,
		"display_name": name_text if name_text != "" else id_text,
		"description": "",
		"loop_file_path": loop_path,
		"loop_length_bars": loop_bars,
		"pulse_triggers": _split_triggers_to_dict(),
		"global_pulse_settings": {
			"brightness": _global_brightness_slider.value,
			"brighten_duration": _global_brighten_slider.value,
			"dim_duration": _global_dim_slider.value,
		},
		"pulse_settings": _collect_pulse_overrides(),
		"bar_effects": _collect_bar_effects(),
		"passive_effects": _collect_passive_effects(),
	}


func _collect_pulse_overrides() -> Dictionary:
	var result: Dictionary = {}
	for bar_type in BAR_TYPES:
		var data: Dictionary = _per_bar_overrides.get(bar_type, {}) as Dictionary
		if data.is_empty():
			continue
		var checkbox: CheckBox = data.get("checkbox") as CheckBox
		if checkbox and checkbox.button_pressed:
			var entry: Dictionary = {
				"brightness": (data["brightness"] as HSlider).value,
				"brighten_duration": (data["brighten"] as HSlider).value,
				"dim_duration": (data["dim"] as HSlider).value,
			}
			var disable_cb: CheckBox = data.get("disable_checkbox") as CheckBox
			if disable_cb and disable_cb.button_pressed:
				entry["disabled"] = true
			result[bar_type] = entry
	return result


func _collect_bar_effects() -> Dictionary:
	var result: Dictionary = {}
	for bar_type in BAR_TYPES:
		var slider: HSlider = _mechanics_bar_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0:
			result[bar_type] = slider.value
	return result


func _collect_passive_effects() -> Dictionary:
	var result: Dictionary = {}
	for bar_type in BAR_TYPES:
		var slider: HSlider = _passive_effect_sliders.get(bar_type) as HSlider
		if slider and slider.value != 0.0:
			result[bar_type] = slider.value
	return result


# ── Save / Load / Delete ───────────────────────────────────

func _on_save() -> void:
	if _merged_triggers.is_empty():
		_status_label.text = "Place some pulse triggers first!"
		return

	var data: Dictionary = _collect_power_core_data()
	if _current_id == "":
		_current_id = str(data["id"])
	var id: String = str(data["id"])
	PowerCoreDataManager.save(id, data)
	_status_label.text = "Saved: " + id
	_refresh_load_list()
	_mark_clean()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var pc: PowerCoreData = PowerCoreDataManager.load_by_id(id)
	if not pc:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_power_core(pc)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No power core loaded to delete."
		return
	PowerCoreDataManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_populating = true
	_current_id = ""
	_name_input.text = ""
	_merged_triggers.clear()
	_trigger_types.clear()
	_waveform_editor.set_stream_from_path("")
	_waveform_editor.set_triggers([])
	_bars_button.selected = 0
	_active_bar_type = 0
	_prev_loop_progress = -1.0
	for i in _bar_type_buttons.size():
		_bar_type_buttons[i].button_pressed = (i == 0)
	# Reset pulse settings
	_global_brightness_slider.value = 0.5
	_global_brighten_slider.value = 0.05
	_global_dim_slider.value = 0.3
	for bar_type in BAR_TYPES:
		var data: Dictionary = _per_bar_overrides.get(bar_type, {}) as Dictionary
		if not data.is_empty():
			(data["checkbox"] as CheckBox).button_pressed = false
			var disable_cb: CheckBox = data.get("disable_checkbox") as CheckBox
			if disable_cb:
				disable_cb.button_pressed = false
			(data["brightness"] as HSlider).value = 0.5
			(data["brighten"] as HSlider).value = 0.05
			(data["dim"] as HSlider).value = 0.3
			(data["container"] as VBoxContainer).visible = false
	# Reset mechanics sliders
	for bar_type in BAR_TYPES:
		var be_slider: HSlider = _mechanics_bar_effect_sliders.get(bar_type) as HSlider
		if be_slider:
			be_slider.value = 0.0
		var pe_slider: HSlider = _passive_effect_sliders.get(bar_type) as HSlider
		if pe_slider:
			pe_slider.value = 0.0
	# Reset preview bars
	for i in _preview_bar_brightness.size():
		_preview_bar_brightness[i] = 0.0
	for bar in _preview_bars:
		bar.value = 0.5
	if _component_display and _component_display is ComponentShapeDisplay:
		(_component_display as ComponentShapeDisplay).update_glow([0.0, 0.0, 0.0, 0.0])
	_populating = false
	_mark_clean()
	_status_label.text = "New power core — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select power core)")
	var ids: Array[String] = PowerCoreDataManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_power_core(data: PowerCoreData) -> void:
	_populating = true
	_current_id = data.id
	_name_input.text = data.display_name

	# Load loop
	if data.loop_file_path != "":
		_loop_browser.select_path(data.loop_file_path)
		_waveform_editor.set_stream_from_path(data.loop_file_path)
	else:
		_waveform_editor.set_stream_from_path("")

	# Merge triggers and set on waveform editor
	_merge_triggers_from_dict(data.pulse_triggers)
	_waveform_editor.set_triggers(_merged_triggers)

	_bars_button.selected = 0
	_prev_loop_progress = -1.0

	# Global pulse settings
	_global_brightness_slider.value = float(data.global_pulse_settings.get("brightness", 0.5))
	_global_brighten_slider.value = float(data.global_pulse_settings.get("brighten_duration", 0.05))
	_global_dim_slider.value = float(data.global_pulse_settings.get("dim_duration", 0.3))

	# Per-bar overrides
	for bar_type in BAR_TYPES:
		var override_data: Dictionary = _per_bar_overrides.get(bar_type, {}) as Dictionary
		if override_data.is_empty():
			continue
		var checkbox: CheckBox = override_data["checkbox"] as CheckBox
		if data.pulse_settings.has(bar_type):
			var settings: Dictionary = data.pulse_settings[bar_type] as Dictionary
			checkbox.button_pressed = true
			(override_data["container"] as VBoxContainer).visible = true
			(override_data["brightness"] as HSlider).value = float(settings.get("brightness", 0.5))
			(override_data["brighten"] as HSlider).value = float(settings.get("brighten_duration", 0.05))
			(override_data["dim"] as HSlider).value = float(settings.get("dim_duration", 0.3))
			var disable_cb: CheckBox = override_data.get("disable_checkbox") as CheckBox
			if disable_cb:
				disable_cb.button_pressed = settings.get("disabled", false) as bool
		else:
			checkbox.button_pressed = false
			(override_data["container"] as VBoxContainer).visible = false

	# Mechanics — power cost, bar effects, passive effects
	for bar_type in BAR_TYPES:
		var be_slider: HSlider = _mechanics_bar_effect_sliders.get(bar_type) as HSlider
		if be_slider:
			be_slider.value = float(data.bar_effects.get(bar_type, 0.0))
		var pe_slider: HSlider = _passive_effect_sliders.get(bar_type) as HSlider
		if pe_slider:
			pe_slider.value = float(data.passive_effects.get(bar_type, 0.0))

	_populating = false
	_mark_clean()


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "power_core_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower()
	id = id.replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "power_core_" + str(randi() % 10000)
	return clean


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
	)

	return [slider, value_label]


# ── Dirty Tracking ─────────────────────────────────────────

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


# ── Theme ──────────────────────────────────────────────────

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
	for btn in _bar_type_buttons:
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)
	# Re-tint bar type buttons
	for i in _bar_type_buttons.size():
		if i < BAR_TYPE_COLOR_KEYS.size() and is_instance_valid(_bar_type_buttons[i]):
			var bar_color: Color = ThemeManager.get_color(BAR_TYPE_COLOR_KEYS[i])
			_bar_type_buttons[i].add_theme_color_override("font_color", bar_color)
			_bar_type_buttons[i].add_theme_color_override("font_pressed_color", bar_color)
			_bar_type_buttons[i].add_theme_color_override("font_hover_color", bar_color)
			_bar_type_buttons[i].add_theme_color_override("font_hover_pressed_color", bar_color)
	if _name_input:
		_name_input.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		_name_input.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	# Update preview bar base colors
	var specs: Array = ThemeManager.get_status_bar_specs()
	for i in _preview_bars.size():
		if i < specs.size():
			_preview_bar_base_colors[i] = ThemeManager.resolve_bar_color(specs[i])


# ── Ship Component Shape Display (vents, windows, ports) ──

class ComponentShapeDisplay:
	extends Control
	## Draws a collection of small geometric shapes (rectangles, circles, thin slots)
	## that represent ship vents/windows/ports. Each shape is assigned to a bar type
	## and pulses its glow color when that bar's triggers fire.

	# Shape definition: {type, rect, bar_idx}
	# type: "rect", "circle", "slot_h", "slot_v"
	var _shapes: Array[Dictionary] = []
	var _base_colors: Array[Color] = []  # Per bar type
	var _glow_values: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var _dim_color: Color = Color(0.08, 0.08, 0.12)
	var _outline_color: Color = Color(0.15, 0.15, 0.22)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rebuild_base_colors()
		_generate_shapes()

	func _rebuild_base_colors() -> void:
		_base_colors.clear()
		var color_keys: Array[String] = ["bar_shield", "bar_hull", "bar_thermal", "bar_electric"]
		for key in color_keys:
			_base_colors.append(ThemeManager.get_color(key))

	func _generate_shapes() -> void:
		## Build a deterministic layout of ship component shapes.
		_shapes.clear()
		var w: float = 250.0  # Approximate width
		var h: float = 140.0

		# Row 1: Small rectangular slots (like cooling vents) — 6 across, bar 0 (shield)
		var slot_w: float = 28.0
		var slot_h: float = 6.0
		var slot_gap: float = 8.0
		var row_x: float = 12.0
		var row_y: float = 8.0
		for i in 6:
			_shapes.append({"type": "slot_h", "rect": Rect2(row_x + float(i) * (slot_w + slot_gap), row_y, slot_w, slot_h), "bar_idx": 0})

		# Row 2: Circles (like porthole windows) — 4 across, bar 1 (hull)
		row_y = 28.0
		var circle_r: float = 7.0
		var circle_gap: float = 18.0
		var cx_start: float = 30.0
		for i in 4:
			var cx: float = cx_start + float(i) * (circle_r * 2.0 + circle_gap)
			_shapes.append({"type": "circle", "rect": Rect2(cx - circle_r, row_y, circle_r * 2.0, circle_r * 2.0), "bar_idx": 1})

		# Row 3: Medium rectangles (heat exchangers) — 3 across, bar 2 (thermal)
		row_y = 52.0
		var rect_w: float = 50.0
		var rect_h: float = 14.0
		var rect_gap: float = 16.0
		row_x = 18.0
		for i in 3:
			_shapes.append({"type": "rect", "rect": Rect2(row_x + float(i) * (rect_w + rect_gap), row_y, rect_w, rect_h), "bar_idx": 2})

		# Row 4: Vertical thin slots (capacitor banks) — 8 across, bar 3 (electric)
		row_y = 78.0
		var vslot_w: float = 5.0
		var vslot_h: float = 20.0
		var vslot_gap: float = 6.0
		row_x = 20.0
		for i in 8:
			_shapes.append({"type": "slot_v", "rect": Rect2(row_x + float(i) * (vslot_w + vslot_gap), row_y, vslot_w, vslot_h), "bar_idx": 3})

		# Row 5: Mixed — small squares (shield), tiny circles (hull)
		row_y = 110.0
		var sq_size: float = 10.0
		row_x = 14.0
		for i in 3:
			_shapes.append({"type": "rect", "rect": Rect2(row_x + float(i) * 20.0, row_y, sq_size, sq_size), "bar_idx": 0})
		var tiny_r: float = 4.0
		for i in 3:
			var tx: float = 100.0 + float(i) * 18.0
			_shapes.append({"type": "circle", "rect": Rect2(tx, row_y + 1.0, tiny_r * 2.0, tiny_r * 2.0), "bar_idx": 1})
		# Long thin slot (thermal)
		_shapes.append({"type": "slot_h", "rect": Rect2(168.0, row_y + 2.0, 60.0, 5.0), "bar_idx": 2})

	func update_glow(glow_per_bar: Array[float]) -> void:
		for i in mini(glow_per_bar.size(), _glow_values.size()):
			_glow_values[i] = glow_per_bar[i]
		queue_redraw()

	func _draw() -> void:
		# Background panel
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.06))

		if _base_colors.is_empty():
			_rebuild_base_colors()

		for shape in _shapes:
			var bar_idx: int = int(shape.get("bar_idx", 0))
			var rect: Rect2 = shape["rect"] as Rect2
			var glow: float = _glow_values[bar_idx] if bar_idx < _glow_values.size() else 0.0
			var base: Color = _base_colors[bar_idx] if bar_idx < _base_colors.size() else Color.WHITE

			# Idle = very dim version of the color; pulsed = bright
			var idle_color: Color = base.darkened(0.8)
			idle_color.a = 0.4
			var lit_color: Color = base.lightened(0.3)
			var fill: Color = idle_color.lerp(lit_color, clampf(glow, 0.0, 1.0))

			var shape_type: String = str(shape.get("type", "rect"))
			match shape_type:
				"circle":
					var center: Vector2 = rect.get_center()
					var radius: float = rect.size.x * 0.5
					# Glow halo
					if glow > 0.05:
						var halo: Color = base
						halo.a = glow * 0.3
						draw_circle(center, radius + 3.0, halo)
					draw_circle(center, radius, fill)
					draw_arc(center, radius, 0.0, TAU, 24, _outline_color, 1.0)
				"rect", "slot_h", "slot_v":
					# Glow halo
					if glow > 0.05:
						var halo: Color = base
						halo.a = glow * 0.25
						draw_rect(rect.grow(2.0), halo)
					draw_rect(rect, fill)
					draw_rect(rect, _outline_color, false, 1.0)
