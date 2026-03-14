extends MarginContainer
## Synth Lab — built-in 80s synthesizer for Dev Studio.
## Two modes: Synth (oscillator + filter + envelope + LFO + unison) and Drums.
## Preview via AudioStreamGenerator, export as WAV to res://assets/audio/samples/.

const NOTES: Array[String] = [
	"C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2",
	"C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3",
	"C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4",
	"C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5",
	"C6",
]

const WAVEFORM_NAMES: Array[String] = ["Sine", "Square", "Saw", "Triangle", "Pulse", "Noise"]
const DRUM_TYPE_NAMES: Array[String] = ["Kick", "Snare", "Hi-Hat", "Tom", "Clap"]
const LFO_TARGET_NAMES: Array[String] = ["Pitch", "Filter", "Amplitude"]
const LFO_SHAPE_NAMES: Array[String] = ["Sine", "Triangle", "Saw", "Square"]
const FILTER_MODE_NAMES: Array[String] = ["Low-Pass", "High-Pass", "Band-Pass"]

const SAMPLE_RATE: float = 44100.0

# Mode
var _is_drum_mode: bool = false

# UI refs — top bar
var _mode_button: OptionButton
var _preset_button: OptionButton
var _save_preset_button: Button
var _delete_preset_button: Button
var _preset_name_input: LineEdit
var _status_label: Label

# UI refs — synth mode
var _synth_params_container: VBoxContainer
var _waveform_button: OptionButton
var _pulse_width_slider: HSlider
var _pulse_width_label: Label
var _pulse_width_row: HBoxContainer
# Amp ADSR
var _amp_attack_slider: HSlider
var _amp_decay_slider: HSlider
var _amp_sustain_slider: HSlider
var _amp_release_slider: HSlider
# Filter
var _filter_cutoff_slider: HSlider
var _filter_resonance_slider: HSlider
# Filter Env
var _filt_env_attack_slider: HSlider
var _filt_env_decay_slider: HSlider
var _filt_env_sustain_slider: HSlider
var _filt_env_release_slider: HSlider
var _filt_env_amount_slider: HSlider
# LFO
var _lfo_rate_slider: HSlider
var _lfo_depth_slider: HSlider
var _lfo_target_button: OptionButton
var _lfo_shape_button: OptionButton
# Unison
var _unison_voices_slider: HSlider
var _unison_detune_slider: HSlider
# Drive
var _drive_slider: HSlider
# Filter mode
var _filter_mode_button: OptionButton
# Chorus
var _chorus_rate_slider: HSlider
var _chorus_depth_slider: HSlider
var _chorus_mix_slider: HSlider
# Analog
var _analog_drift_slider: HSlider
var _stereo_spread_slider: HSlider

# UI refs — drum mode
var _drum_params_container: VBoxContainer
var _drum_type_button: OptionButton
var _drum_sliders: Dictionary = {}

# UI refs — shared
var _note_button: OptionButton
var _duration_slider: HSlider
var _duration_label: Label
var _waveform_display: Control
var _play_button: Button
var _save_wav_button: Button

# Audio preview
var _audio_player: AudioStreamPlayer
var _preview_buffer: PackedFloat32Array
var _playback: AudioStreamGeneratorPlayback
var _section_headers: Array[Label] = []


func _ready() -> void:
	_build_ui()
	_refresh_preset_list()
	_load_preset_by_name("80s Bass")
	ThemeManager.theme_changed.connect(_apply_theme)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# ── Top bar ──
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var mode_label := Label.new()
	mode_label.text = "Mode:"
	top_bar.add_child(mode_label)

	_mode_button = OptionButton.new()
	_mode_button.add_item("Synth")
	_mode_button.add_item("Drums")
	_mode_button.item_selected.connect(_on_mode_changed)
	top_bar.add_child(_mode_button)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.x = 20
	top_bar.add_child(spacer1)

	var preset_label := Label.new()
	preset_label.text = "Preset:"
	top_bar.add_child(preset_label)

	_preset_button = OptionButton.new()
	_preset_button.custom_minimum_size.x = 180
	_preset_button.item_selected.connect(_on_preset_selected)
	top_bar.add_child(_preset_button)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	_preset_name_input = LineEdit.new()
	_preset_name_input.placeholder_text = "Preset name..."
	_preset_name_input.custom_minimum_size.x = 150
	top_bar.add_child(_preset_name_input)

	_save_preset_button = Button.new()
	_save_preset_button.text = "SAVE PRESET"
	_save_preset_button.pressed.connect(_on_save_preset)
	top_bar.add_child(_save_preset_button)

	_delete_preset_button = Button.new()
	_delete_preset_button.text = "DELETE"
	_delete_preset_button.pressed.connect(_on_delete_preset)
	top_bar.add_child(_delete_preset_button)

	# ── Main split ──
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 300
	root.add_child(split)

	# Left: waveform display + playback controls
	var left_panel := _build_left_panel()
	split.add_child(left_panel)

	# Right: parameter panels (scrollable)
	var right_panel := _build_right_panel()
	split.add_child(right_panel)

	# ── Bottom bar ──
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_wav_button = Button.new()
	_save_wav_button.text = "SAVE TO SAMPLES"
	_save_wav_button.custom_minimum_size.x = 200
	_save_wav_button.pressed.connect(_on_save_wav)
	bottom_bar.add_child(_save_wav_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)

	# ── Audio player ──
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	_add_section_header(vbox, "WAVEFORM PREVIEW")

	_waveform_display = _WaveformDisplay.new()
	_waveform_display.custom_minimum_size = Vector2(280, 150)
	_waveform_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_waveform_display)

	_add_separator(vbox)
	_add_section_header(vbox, "PLAYBACK")

	# Note selector
	var note_row := HBoxContainer.new()
	vbox.add_child(note_row)
	var note_label := Label.new()
	note_label.text = "Note:"
	note_label.custom_minimum_size.x = 80
	note_row.add_child(note_label)
	_note_button = OptionButton.new()
	_note_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n in NOTES:
		_note_button.add_item(n)
	_note_button.selected = 24  # C4
	note_row.add_child(_note_button)

	# Duration
	var dur_result: Array = _add_slider_row(vbox, "Duration:", 0.05, 3.0, 0.4, 0.01)
	_duration_slider = dur_result[0]
	_duration_label = dur_result[1]

	_add_separator(vbox)

	# Play button
	_play_button = Button.new()
	_play_button.text = "PLAY PREVIEW"
	_play_button.custom_minimum_size.y = 40
	_play_button.pressed.connect(_on_play)
	vbox.add_child(_play_button)

	return panel


func _build_right_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(container)

	# Synth params
	_synth_params_container = VBoxContainer.new()
	_synth_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_synth_params_container)
	_build_synth_params()

	# Drum params
	_drum_params_container = VBoxContainer.new()
	_drum_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drum_params_container.visible = false
	container.add_child(_drum_params_container)
	_build_drum_params()

	return scroll


func _build_synth_params() -> void:
	var form: VBoxContainer = _synth_params_container

	# Oscillator
	_add_section_header(form, "OSCILLATOR")
	var wave_row := HBoxContainer.new()
	form.add_child(wave_row)
	var wave_label := Label.new()
	wave_label.text = "Waveform:"
	wave_label.custom_minimum_size.x = 130
	wave_row.add_child(wave_label)
	_waveform_button = OptionButton.new()
	_waveform_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for w in WAVEFORM_NAMES:
		_waveform_button.add_item(w)
	_waveform_button.selected = 2  # Saw
	_waveform_button.item_selected.connect(_on_waveform_changed)
	wave_row.add_child(_waveform_button)

	var pw_result: Array = _add_slider_row(form, "Pulse Width:", 0.05, 0.95, 0.5, 0.01)
	_pulse_width_slider = pw_result[0]
	_pulse_width_label = pw_result[1]
	_pulse_width_row = pw_result[0].get_parent()
	_pulse_width_row.visible = false  # Only visible for Pulse waveform

	_add_separator(form)

	# Amp Envelope
	_add_section_header(form, "AMP ENVELOPE")
	var aa: Array = _add_slider_row(form, "Attack:", 0.001, 2.0, 0.01, 0.001)
	_amp_attack_slider = aa[0]
	var ad: Array = _add_slider_row(form, "Decay:", 0.001, 2.0, 0.1, 0.001)
	_amp_decay_slider = ad[0]
	var as_r: Array = _add_slider_row(form, "Sustain:", 0.0, 1.0, 0.7, 0.01)
	_amp_sustain_slider = as_r[0]
	var ar: Array = _add_slider_row(form, "Release:", 0.001, 2.0, 0.2, 0.001)
	_amp_release_slider = ar[0]

	_add_separator(form)

	# Filter
	_add_section_header(form, "FILTER")
	var fm_row := HBoxContainer.new()
	form.add_child(fm_row)
	var fm_label := Label.new()
	fm_label.text = "Mode:"
	fm_label.custom_minimum_size.x = 130
	fm_row.add_child(fm_label)
	_filter_mode_button = OptionButton.new()
	_filter_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in FILTER_MODE_NAMES:
		_filter_mode_button.add_item(m)
	fm_row.add_child(_filter_mode_button)

	var fc: Array = _add_slider_row(form, "Cutoff:", 20.0, 20000.0, 8000.0, 10.0)
	_filter_cutoff_slider = fc[0]
	var fr: Array = _add_slider_row(form, "Resonance:", 0.0, 1.0, 0.0, 0.01)
	_filter_resonance_slider = fr[0]

	_add_separator(form)

	# Filter Envelope
	_add_section_header(form, "FILTER ENVELOPE")
	var fea: Array = _add_slider_row(form, "Attack:", 0.001, 2.0, 0.01, 0.001)
	_filt_env_attack_slider = fea[0]
	var fed: Array = _add_slider_row(form, "Decay:", 0.001, 2.0, 0.2, 0.001)
	_filt_env_decay_slider = fed[0]
	var fes: Array = _add_slider_row(form, "Sustain:", 0.0, 1.0, 0.0, 0.01)
	_filt_env_sustain_slider = fes[0]
	var fer: Array = _add_slider_row(form, "Release:", 0.001, 2.0, 0.1, 0.001)
	_filt_env_release_slider = fer[0]
	var fea2: Array = _add_slider_row(form, "Amount:", 0.0, 10000.0, 0.0, 10.0)
	_filt_env_amount_slider = fea2[0]

	_add_separator(form)

	# LFO
	_add_section_header(form, "LFO")
	var lr: Array = _add_slider_row(form, "Rate:", 0.1, 30.0, 2.0, 0.1)
	_lfo_rate_slider = lr[0]
	var ld: Array = _add_slider_row(form, "Depth:", 0.0, 5.0, 0.0, 0.01)
	_lfo_depth_slider = ld[0]

	var lt_row := HBoxContainer.new()
	form.add_child(lt_row)
	var lt_label := Label.new()
	lt_label.text = "Target:"
	lt_label.custom_minimum_size.x = 130
	lt_row.add_child(lt_label)
	_lfo_target_button = OptionButton.new()
	_lfo_target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in LFO_TARGET_NAMES:
		_lfo_target_button.add_item(t)
	lt_row.add_child(_lfo_target_button)

	var ls_row := HBoxContainer.new()
	form.add_child(ls_row)
	var ls_label := Label.new()
	ls_label.text = "Shape:"
	ls_label.custom_minimum_size.x = 130
	ls_row.add_child(ls_label)
	_lfo_shape_button = OptionButton.new()
	_lfo_shape_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in LFO_SHAPE_NAMES:
		_lfo_shape_button.add_item(s)
	ls_row.add_child(_lfo_shape_button)

	_add_separator(form)

	# Unison
	_add_section_header(form, "UNISON / DETUNE")
	var uv: Array = _add_slider_row(form, "Voices:", 1, 5, 1, 1)
	_unison_voices_slider = uv[0]
	var ud: Array = _add_slider_row(form, "Detune (cents):", 0.0, 50.0, 0.0, 0.5)
	_unison_detune_slider = ud[0]

	_add_separator(form)

	# Drive
	_add_section_header(form, "DRIVE")
	var dr: Array = _add_slider_row(form, "Drive:", 0.0, 1.0, 0.0, 0.01)
	_drive_slider = dr[0]

	_add_separator(form)

	# Chorus
	_add_section_header(form, "CHORUS")
	var cr: Array = _add_slider_row(form, "Rate (Hz):", 0.1, 5.0, 0.8, 0.1)
	_chorus_rate_slider = cr[0]
	var cd: Array = _add_slider_row(form, "Depth (ms):", 0.0, 10.0, 3.0, 0.1)
	_chorus_depth_slider = cd[0]
	var cm: Array = _add_slider_row(form, "Mix:", 0.0, 1.0, 0.0, 0.01)
	_chorus_mix_slider = cm[0]

	_add_separator(form)

	# Analog
	_add_section_header(form, "ANALOG")
	var adr: Array = _add_slider_row(form, "Drift:", 0.0, 1.0, 0.0, 0.01)
	_analog_drift_slider = adr[0]
	var ss: Array = _add_slider_row(form, "Stereo Spread:", 0.0, 1.0, 0.5, 0.01)
	_stereo_spread_slider = ss[0]


func _build_drum_params() -> void:
	var form: VBoxContainer = _drum_params_container

	_add_section_header(form, "DRUM TYPE")
	var type_row := HBoxContainer.new()
	form.add_child(type_row)
	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 130
	type_row.add_child(type_label)
	_drum_type_button = OptionButton.new()
	_drum_type_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for dt in DRUM_TYPE_NAMES:
		_drum_type_button.add_item(dt)
	_drum_type_button.item_selected.connect(_on_drum_type_changed)
	type_row.add_child(_drum_type_button)

	_add_separator(form)
	_add_section_header(form, "PARAMETERS")

	# Dynamic drum param sliders will be added here
	_rebuild_drum_sliders(DrumEngine.DrumType.KICK)


func _rebuild_drum_sliders(drum_type: DrumEngine.DrumType) -> void:
	# Remove old dynamic sliders (everything after the separator + header = index 3 onward)
	var children: Array[Node] = _drum_params_container.get_children()
	for i in range(children.size() - 1, 3, -1):
		children[i].queue_free()
	_drum_sliders.clear()

	var defs: Dictionary = DrumEngine.get_param_defs(drum_type)
	for param_name in defs:
		var bounds: Array = defs[param_name]
		var min_val: float = float(bounds[0])
		var max_val: float = float(bounds[1])
		var default_val: float = float(bounds[2])
		var step_val: float = float(bounds[3])
		var row: Array = _add_slider_row(_drum_params_container, param_name + ":", min_val, max_val, default_val, step_val)
		_drum_sliders[param_name] = row[0]


# ── UI Helpers (matching weapon_builder.gd style) ──────────

func _apply_theme() -> void:
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if _waveform_display:
		_waveform_display.queue_redraw()


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
	value_label.text = _format_slider_value(default_val, step_val)
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		value_label.text = _format_slider_value(val, step_val)
	)

	return [slider, value_label]


func _format_slider_value(val: float, step: float) -> String:
	if step >= 1.0:
		return str(int(val))
	elif step >= 0.1:
		return "%.1f" % val
	elif step >= 0.01:
		return "%.2f" % val
	return "%.3f" % val


# ── Note → Frequency ──────────────────────────────────────

func _note_to_freq(note_name: String) -> float:
	# A4 = 440 Hz, MIDI 69
	var note_names: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var octave: int = int(note_name.right(1))
	var name_part: String = note_name.left(note_name.length() - 1)
	var semitone: int = note_names.find(name_part)
	if semitone < 0:
		semitone = 0
	var midi: int = (octave + 1) * 12 + semitone
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)


# ── Rendering ──────────────────────────────────────────────

func _render_current() -> PackedFloat32Array:
	if _is_drum_mode:
		return _render_drum()
	else:
		return _render_synth()


func _render_synth() -> PackedFloat32Array:
	var engine := SynthEngine.new()
	engine.waveform = SynthOscillator.waveform_from_name(
		_waveform_button.get_item_text(_waveform_button.selected))
	engine.pulse_width = _pulse_width_slider.value

	engine.amp_attack = _amp_attack_slider.value
	engine.amp_decay = _amp_decay_slider.value
	engine.amp_sustain = _amp_sustain_slider.value
	engine.amp_release = _amp_release_slider.value

	engine.filter_cutoff = _filter_cutoff_slider.value
	engine.filter_resonance = _filter_resonance_slider.value
	engine.filter_mode = _filter_mode_button.selected
	engine.filter_drive = 0.0  # Pre-filter drive not exposed separately

	engine.filter_env_attack = _filt_env_attack_slider.value
	engine.filter_env_decay = _filt_env_decay_slider.value
	engine.filter_env_sustain = _filt_env_sustain_slider.value
	engine.filter_env_release = _filt_env_release_slider.value
	engine.filter_env_amount = _filt_env_amount_slider.value

	engine.lfo_rate = _lfo_rate_slider.value
	engine.lfo_depth = _lfo_depth_slider.value
	engine.lfo_target = _lfo_target_button.selected as SynthLFO.Target
	engine.lfo_shape = _lfo_shape_button.selected as SynthLFO.Shape

	engine.unison_voices = int(_unison_voices_slider.value)
	engine.unison_detune = _unison_detune_slider.value

	engine.drive = _drive_slider.value
	engine.chorus_rate = _chorus_rate_slider.value
	engine.chorus_depth = _chorus_depth_slider.value
	engine.chorus_mix = _chorus_mix_slider.value
	engine.analog_drift = _analog_drift_slider.value
	engine.stereo_spread = _stereo_spread_slider.value

	var note_name: String = _note_button.get_item_text(_note_button.selected)
	var freq: float = _note_to_freq(note_name)
	var duration: float = _duration_slider.value

	return engine.render_stereo(freq, duration)


func _render_drum() -> PackedFloat32Array:
	var drum_type: DrumEngine.DrumType = _drum_type_button.selected as DrumEngine.DrumType
	var params: Dictionary = {}
	for param_name in _drum_sliders:
		var slider: HSlider = _drum_sliders[param_name]
		params[param_name] = slider.value
	return DrumEngine.render(drum_type, params)


# ── Preview Playback ──────────────────────────────────────

func _play_buffer(buffer: PackedFloat32Array) -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	var is_stereo: bool = not _is_drum_mode
	var num_frames: int = buffer.size() / 2 if is_stereo else buffer.size()
	generator.buffer_length = maxf(float(num_frames) / SAMPLE_RATE + 0.1, 0.5)
	_audio_player.stream = generator
	_audio_player.play()

	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback:
		if is_stereo:
			# Interleaved stereo [L0, R0, L1, R1, ...]
			for i in num_frames:
				_playback.push_frame(Vector2(buffer[i * 2], buffer[i * 2 + 1]))
		else:
			for i in buffer.size():
				_playback.push_frame(Vector2(buffer[i], buffer[i]))


# ── Waveform Display ──────────────────────────────────────

func _update_waveform_display(buffer: PackedFloat32Array) -> void:
	if _waveform_display and _waveform_display is _WaveformDisplay:
		var display: _WaveformDisplay = _waveform_display as _WaveformDisplay
		# For stereo interleaved, extract left channel for display
		if not _is_drum_mode and buffer.size() > 1:
			var left_only := PackedFloat32Array()
			var num_frames: int = buffer.size() / 2
			left_only.resize(num_frames)
			for i in num_frames:
				left_only[i] = buffer[i * 2]
			display.set_buffer(left_only)
		else:
			display.set_buffer(buffer)


# ── Events ─────────────────────────────────────────────────

func _on_mode_changed(idx: int) -> void:
	_is_drum_mode = idx == 1
	_synth_params_container.visible = not _is_drum_mode
	_drum_params_container.visible = _is_drum_mode
	# Hide note selector in drum mode
	_note_button.get_parent().visible = not _is_drum_mode
	_refresh_preset_list()


func _on_waveform_changed(idx: int) -> void:
	_pulse_width_row.visible = (idx == 4)  # Pulse


func _on_drum_type_changed(idx: int) -> void:
	_rebuild_drum_sliders(idx as DrumEngine.DrumType)


func _on_play() -> void:
	_preview_buffer = _render_current()
	_update_waveform_display(_preview_buffer)
	_play_buffer(_preview_buffer)
	var frame_count: int = _preview_buffer.size() / 2 if not _is_drum_mode else _preview_buffer.size()
	var ch_label: String = "stereo" if not _is_drum_mode else "mono"
	_status_label.text = "Playing preview (%d frames, %s)" % [frame_count, ch_label]


func _on_save_wav() -> void:
	var buffer: PackedFloat32Array = _render_current()
	if buffer.is_empty():
		_status_label.text = "Nothing to save — render first."
		return

	# Generate filename
	var fname: String = _generate_wav_filename()
	var path: String = "res://assets/audio/samples/" + fname
	var err: int
	if not _is_drum_mode:
		err = WavExporter.save_wav_stereo(buffer, path)
	else:
		err = WavExporter.save_wav(buffer, path)
	if err == OK:
		_status_label.text = "Saved: " + fname
	else:
		_status_label.text = "Save failed (error " + str(err) + ")"


func _generate_wav_filename() -> String:
	var parts: Array[String] = []
	if _is_drum_mode:
		parts.append(DRUM_TYPE_NAMES[_drum_type_button.selected])
	else:
		parts.append(WAVEFORM_NAMES[_waveform_button.selected])
		parts.append(_note_button.get_item_text(_note_button.selected))
	# Add preset name if set
	var pname: String = _preset_name_input.text.strip_edges()
	if pname != "":
		parts.append(pname.replace(" ", "_"))
	# Timestamp for uniqueness
	parts.append(str(Time.get_unix_time_from_system()).replace(".", "_"))
	return "synth_" + "_".join(parts) + ".wav"


func _on_preset_selected(idx: int) -> void:
	if idx <= 0:
		return
	var preset_name: String = _preset_button.get_item_text(idx)
	_load_preset_by_name(preset_name)


func _on_save_preset() -> void:
	var pname: String = _preset_name_input.text.strip_edges()
	if pname == "":
		_status_label.text = "Enter a preset name first."
		return
	if SynthPresetManager.is_builtin(pname):
		_status_label.text = "Cannot overwrite a built-in preset."
		return
	var data: Dictionary = _collect_preset_data()
	SynthPresetManager.save_preset(pname, data)
	_refresh_preset_list()
	_status_label.text = "Preset saved: " + pname


func _on_delete_preset() -> void:
	var pname: String = _preset_name_input.text.strip_edges()
	if pname == "":
		_status_label.text = "Enter preset name to delete."
		return
	if SynthPresetManager.is_builtin(pname):
		_status_label.text = "Cannot delete a built-in preset."
		return
	SynthPresetManager.delete_preset(pname)
	_refresh_preset_list()
	_status_label.text = "Deleted preset: " + pname


# ── Preset save/load ──────────────────────────────────────

func _collect_preset_data() -> Dictionary:
	var data: Dictionary = {}
	if _is_drum_mode:
		data["mode"] = "drum"
		data["drum_type"] = DRUM_TYPE_NAMES[_drum_type_button.selected]
		var params: Dictionary = {}
		for param_name in _drum_sliders:
			var slider: HSlider = _drum_sliders[param_name]
			params[param_name] = slider.value
		data["drum_params"] = params
	else:
		data["mode"] = "synth"
		data["waveform"] = WAVEFORM_NAMES[_waveform_button.selected]
		data["pulse_width"] = _pulse_width_slider.value
		data["amp_attack"] = _amp_attack_slider.value
		data["amp_decay"] = _amp_decay_slider.value
		data["amp_sustain"] = _amp_sustain_slider.value
		data["amp_release"] = _amp_release_slider.value
		data["filter_cutoff"] = _filter_cutoff_slider.value
		data["filter_resonance"] = _filter_resonance_slider.value
		data["filter_env_attack"] = _filt_env_attack_slider.value
		data["filter_env_decay"] = _filt_env_decay_slider.value
		data["filter_env_sustain"] = _filt_env_sustain_slider.value
		data["filter_env_release"] = _filt_env_release_slider.value
		data["filter_env_amount"] = _filt_env_amount_slider.value
		data["lfo_rate"] = _lfo_rate_slider.value
		data["lfo_depth"] = _lfo_depth_slider.value
		data["lfo_target"] = LFO_TARGET_NAMES[_lfo_target_button.selected]
		data["lfo_shape"] = LFO_SHAPE_NAMES[_lfo_shape_button.selected]
		data["unison_voices"] = int(_unison_voices_slider.value)
		data["unison_detune"] = _unison_detune_slider.value
		data["filter_mode"] = FILTER_MODE_NAMES[_filter_mode_button.selected]
		data["drive"] = _drive_slider.value
		data["chorus_rate"] = _chorus_rate_slider.value
		data["chorus_depth"] = _chorus_depth_slider.value
		data["chorus_mix"] = _chorus_mix_slider.value
		data["analog_drift"] = _analog_drift_slider.value
		data["stereo_spread"] = _stereo_spread_slider.value
		data["note"] = _note_button.get_item_text(_note_button.selected)
		data["duration"] = _duration_slider.value
	return data


func _load_preset_by_name(preset_name: String) -> void:
	var data: Dictionary = SynthPresetManager.load_preset(preset_name)
	if data.is_empty():
		_status_label.text = "Preset not found: " + preset_name
		return
	_apply_preset(data)
	_preset_name_input.text = preset_name
	_status_label.text = "Loaded: " + preset_name


func _apply_preset(data: Dictionary) -> void:
	var mode: String = str(data.get("mode", "synth"))
	if mode == "drum":
		_is_drum_mode = true
		_mode_button.selected = 1
		_synth_params_container.visible = false
		_drum_params_container.visible = true
		_note_button.get_parent().visible = false

		var type_name: String = str(data.get("drum_type", "Kick"))
		var type_idx: int = DRUM_TYPE_NAMES.find(type_name)
		if type_idx >= 0:
			_drum_type_button.selected = type_idx
		_rebuild_drum_sliders(DrumEngine.type_from_name(type_name))

		var params: Dictionary = data.get("drum_params", {})
		for param_name in params:
			if param_name in _drum_sliders:
				var slider: HSlider = _drum_sliders[param_name]
				slider.value = float(params[param_name])
	else:
		_is_drum_mode = false
		_mode_button.selected = 0
		_synth_params_container.visible = true
		_drum_params_container.visible = false
		_note_button.get_parent().visible = true

		var wave_name: String = str(data.get("waveform", "Saw"))
		var wave_idx: int = WAVEFORM_NAMES.find(wave_name)
		if wave_idx >= 0:
			_waveform_button.selected = wave_idx
		_pulse_width_row.visible = (wave_idx == 4)
		_pulse_width_slider.value = float(data.get("pulse_width", 0.5))

		_amp_attack_slider.value = float(data.get("amp_attack", 0.01))
		_amp_decay_slider.value = float(data.get("amp_decay", 0.1))
		_amp_sustain_slider.value = float(data.get("amp_sustain", 0.7))
		_amp_release_slider.value = float(data.get("amp_release", 0.2))

		_filter_cutoff_slider.value = float(data.get("filter_cutoff", 8000.0))
		_filter_resonance_slider.value = float(data.get("filter_resonance", 0.0))

		_filt_env_attack_slider.value = float(data.get("filter_env_attack", 0.01))
		_filt_env_decay_slider.value = float(data.get("filter_env_decay", 0.2))
		_filt_env_sustain_slider.value = float(data.get("filter_env_sustain", 0.0))
		_filt_env_release_slider.value = float(data.get("filter_env_release", 0.1))
		_filt_env_amount_slider.value = float(data.get("filter_env_amount", 0.0))

		_lfo_rate_slider.value = float(data.get("lfo_rate", 2.0))
		_lfo_depth_slider.value = float(data.get("lfo_depth", 0.0))
		var lt_name: String = str(data.get("lfo_target", "Pitch"))
		var lt_idx: int = LFO_TARGET_NAMES.find(lt_name)
		if lt_idx >= 0:
			_lfo_target_button.selected = lt_idx
		var ls_name: String = str(data.get("lfo_shape", "Sine"))
		var ls_idx: int = LFO_SHAPE_NAMES.find(ls_name)
		if ls_idx >= 0:
			_lfo_shape_button.selected = ls_idx

		_unison_voices_slider.value = float(data.get("unison_voices", 1))
		_unison_detune_slider.value = float(data.get("unison_detune", 0.0))

		var fm_name: String = str(data.get("filter_mode", "Low-Pass"))
		var fm_idx: int = FILTER_MODE_NAMES.find(fm_name)
		if fm_idx >= 0:
			_filter_mode_button.selected = fm_idx
		else:
			_filter_mode_button.selected = 0

		_drive_slider.value = float(data.get("drive", 0.0))
		_chorus_rate_slider.value = float(data.get("chorus_rate", 0.8))
		_chorus_depth_slider.value = float(data.get("chorus_depth", 3.0))
		_chorus_mix_slider.value = float(data.get("chorus_mix", 0.0))
		_analog_drift_slider.value = float(data.get("analog_drift", 0.0))
		_stereo_spread_slider.value = float(data.get("stereo_spread", 0.5))

		var note_name: String = str(data.get("note", "C4"))
		var note_idx: int = NOTES.find(note_name)
		if note_idx >= 0:
			_note_button.selected = note_idx

		_duration_slider.value = float(data.get("duration", 0.4))


func _refresh_preset_list() -> void:
	_preset_button.clear()
	_preset_button.add_item("(select preset)")
	var names: Array[String] = SynthPresetManager.list_all_names()
	for pname in names:
		# Filter by current mode
		var data: Dictionary = SynthPresetManager.load_preset(pname)
		var mode: String = str(data.get("mode", "synth"))
		if _is_drum_mode and mode == "drum":
			_preset_button.add_item(pname)
		elif not _is_drum_mode and mode == "synth":
			_preset_button.add_item(pname)


# ── Inner class: Waveform display ─────────────────────────

class _WaveformDisplay extends Control:
	var _buffer: PackedFloat32Array

	func set_buffer(buf: PackedFloat32Array) -> void:
		_buffer = buf
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		# Background
		draw_rect(rect, ThemeManager.get_color("panel"))
		# Center line
		var center_y: float = rect.size.y / 2.0
		var dim_color: Color = ThemeManager.get_color("dimmed")
		dim_color.a = 0.4
		draw_line(Vector2(0, center_y), Vector2(rect.size.x, center_y), dim_color, 1.0)

		if _buffer.is_empty():
			return

		# Draw waveform
		var points := PackedVector2Array()
		var step: int = maxi(1, _buffer.size() / int(rect.size.x))
		var x_scale: float = rect.size.x / float(_buffer.size() / step)
		for i in range(0, _buffer.size(), step):
			var x: float = float(i / step) * x_scale
			var y: float = center_y - _buffer[i] * center_y * 0.9
			points.append(Vector2(x, y))

		if points.size() >= 2:
			var wave_color: Color = ThemeManager.get_color("header")
			wave_color.a = 0.9
			draw_polyline(points, wave_color, 1.5, true)
