extends MarginContainer
## Key Change preset editor — create named presets with pitch shift, fade, enter/exit SFX,
## offset timing, reverse, and live preview with measure-boundary triggering.

var _presets: Array[KeyChangeData] = []
var _selected_id: String = ""
var _suppressing_signals: bool = false

# UI refs — list
var _list_container: VBoxContainer
var _create_btn: Button
var _delete_btn: Button
var _editor_panel: VBoxContainer
var _empty_label: Label

# UI refs — identity
var _name_edit: LineEdit

# UI refs — pitch
var _semitone_slider: HSlider
var _semitone_value: Label
var _fade_slider: HSlider
var _fade_value: Label

# UI refs — enter SFX
var _enter_sfx_option: OptionButton
var _enter_vol_slider: HSlider
var _enter_vol_value: Label
var _enter_offset_slider: HSlider
var _enter_offset_value: Label
var _enter_preview_btn: Button

# UI refs — exit SFX
var _exit_sfx_option: OptionButton
var _exit_vol_slider: HSlider
var _exit_vol_value: Label
var _exit_offset_slider: HSlider
var _exit_offset_value: Label
var _exit_reverse_check: CheckBox
var _exit_preview_btn: Button

# UI refs — live preview
var _loop_browser: LoopBrowser
var _play_btn: Button
var _trigger_btn: Button
var _reset_btn: Button
var _status_label: Label

# SFX file list
var _sfx_files: Array[String] = []

# Preview state
var _preview_player: AudioStreamPlayer
var _preview_playing: bool = false
var _pending_shift: int = 0
var _current_shift: int = 0
var _prev_loop_pos: float = -1.0
var _detected_bars: int = 2
var _sfx_scheduled: bool = false


func _ready() -> void:
	_presets = KeyChangeDataManager.load_all()
	_sfx_files = _scan_sfx_files()
	_build_ui()

	if _presets.size() > 0:
		_select_preset(_presets[0].id)
	else:
		_show_empty_state()

	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")


func _exit_tree() -> void:
	# Clean up audio state
	LoopMixer.set_pitch_shift(0.0, 0.0)
	_current_shift = 0
	_pending_shift = 0


func _process(_delta: float) -> void:
	if _pending_shift == _current_shift:
		return
	_check_measure_boundary()


func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	add_child(split)

	# --- Left panel: preset list ---
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size.x = 260
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 8)
	split.add_child(left_panel)

	var header := Label.new()
	header.text = "KEY CHANGES"
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
	_editor_panel.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_editor_panel)

	# --- Identity ---
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name"
	name_lbl.custom_minimum_size.x = 120
	name_row.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)

	# --- Pitch Shift section ---
	var pitch_header := Label.new()
	pitch_header.text = "PITCH SHIFT"
	pitch_header.name = "PitchHeader"
	_editor_panel.add_child(pitch_header)

	_semitone_slider = _add_slider_row("Semitones", -6.0, 6.0, 1.0, 0.0)
	_semitone_slider.value_changed.connect(_on_semitone_changed)

	_fade_slider = _add_slider_row("Fade Duration", 0.01, 1.0, 0.01, 0.15)
	_fade_slider.value_changed.connect(_on_fade_changed)

	# --- Enter SFX section ---
	var enter_header := Label.new()
	enter_header.text = "ENTER SFX"
	enter_header.name = "EnterHeader"
	_editor_panel.add_child(enter_header)

	_enter_sfx_option = _add_sfx_option_row("File")
	_enter_sfx_option.item_selected.connect(_on_enter_sfx_selected)

	_enter_vol_slider = _add_slider_row("Volume", -40.0, 6.0, 0.5, 0.0)
	_enter_vol_slider.value_changed.connect(_on_enter_vol_changed)

	_enter_offset_slider = _add_slider_row("Offset", 0.0, 1.0, 0.01, 0.0)
	_enter_offset_slider.value_changed.connect(_on_enter_offset_changed)

	var enter_preview_row := HBoxContainer.new()
	enter_preview_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(enter_preview_row)
	var enter_spacer := Control.new()
	enter_spacer.custom_minimum_size.x = 120
	enter_preview_row.add_child(enter_spacer)
	_enter_preview_btn = Button.new()
	_enter_preview_btn.text = "PREVIEW ENTER SFX"
	_enter_preview_btn.pressed.connect(_on_preview_enter)
	enter_preview_row.add_child(_enter_preview_btn)

	# --- Exit SFX section ---
	var exit_header := Label.new()
	exit_header.text = "EXIT SFX"
	exit_header.name = "ExitHeader"
	_editor_panel.add_child(exit_header)

	_exit_sfx_option = _add_sfx_option_row("File")
	_exit_sfx_option.item_selected.connect(_on_exit_sfx_selected)

	_exit_vol_slider = _add_slider_row("Volume", -40.0, 6.0, 0.5, 0.0)
	_exit_vol_slider.value_changed.connect(_on_exit_vol_changed)

	_exit_offset_slider = _add_slider_row("Offset", 0.0, 1.0, 0.01, 0.0)
	_exit_offset_slider.value_changed.connect(_on_exit_offset_changed)

	_exit_reverse_check = CheckBox.new()
	_exit_reverse_check.text = "Reverse Exit SFX"
	_exit_reverse_check.toggled.connect(_on_reverse_toggled)
	var reverse_row := HBoxContainer.new()
	reverse_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(reverse_row)
	var rev_spacer := Control.new()
	rev_spacer.custom_minimum_size.x = 120
	reverse_row.add_child(rev_spacer)
	reverse_row.add_child(_exit_reverse_check)

	var exit_preview_row := HBoxContainer.new()
	exit_preview_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(exit_preview_row)
	var exit_spacer := Control.new()
	exit_spacer.custom_minimum_size.x = 120
	exit_preview_row.add_child(exit_spacer)
	_exit_preview_btn = Button.new()
	_exit_preview_btn.text = "PREVIEW EXIT SFX"
	_exit_preview_btn.pressed.connect(_on_preview_exit)
	exit_preview_row.add_child(_exit_preview_btn)

	# --- Live Preview section ---
	var preview_header := Label.new()
	preview_header.text = "LIVE PREVIEW"
	preview_header.name = "PreviewHeader"
	_editor_panel.add_child(preview_header)

	# Build control buttons BEFORE LoopBrowser — LoopBrowser emits loop_selected
	# during its _ready(), and _on_loop_selected references _play_btn.
	var control_row := HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 8)
	control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_editor_panel.add_child(control_row)

	_play_btn = Button.new()
	_play_btn.text = "PLAY"
	_play_btn.toggle_mode = true
	_play_btn.pressed.connect(_on_play_toggle)
	control_row.add_child(_play_btn)

	_trigger_btn = Button.new()
	_trigger_btn.text = "TRIGGER KEY CHANGE"
	_trigger_btn.pressed.connect(_on_trigger)
	control_row.add_child(_trigger_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "RESET"
	_reset_btn.pressed.connect(_on_reset)
	control_row.add_child(_reset_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.name = "StatusLabel"
	_editor_panel.add_child(_status_label)

	# LoopBrowser added last — its _ready() emits loop_selected which needs _play_btn
	_loop_browser = LoopBrowser.new()
	_loop_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loop_browser.loop_selected.connect(_on_loop_selected)
	_editor_panel.add_child(_loop_browser)

	# SFX preview player
	_preview_player = AudioStreamPlayer.new()
	add_child(_preview_player)

	# Empty state
	_empty_label = Label.new()
	_empty_label.text = "No key change presets yet. Click + CREATE NEW to get started."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_panel.add_child(_empty_label)
	_empty_label.visible = false

	_rebuild_list()


func _add_slider_row(label_text: String, min_val: float, max_val: float, step: float, default_val: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	row.add_child(slider)

	var value_lbl := Label.new()
	value_lbl.text = str(snapped(default_val, step))
	value_lbl.custom_minimum_size.x = 60
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)

	# Store value label refs
	if label_text == "Semitones":
		_semitone_value = value_lbl
	elif label_text == "Fade Duration":
		_fade_value = value_lbl
	elif label_text == "Volume" and _enter_vol_value == null:
		_enter_vol_value = value_lbl
	elif label_text == "Volume":
		_exit_vol_value = value_lbl
	elif label_text == "Offset" and _enter_offset_value == null:
		_enter_offset_value = value_lbl
	elif label_text == "Offset":
		_exit_offset_value = value_lbl

	return slider


func _add_sfx_option_row(label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	row.add_child(lbl)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("(none)")
	for f in _sfx_files:
		option.add_item(f.get_file())
	row.add_child(option)

	return option


# --- List management ---

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	for preset in _presets:
		var btn := Button.new()
		btn.text = preset.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (preset.id == _selected_id)
		btn.pressed.connect(_on_list_item_pressed.bind(preset.id))
		btn.name = "ListItem_" + preset.id
		_list_container.add_child(btn)
		ThemeManager.apply_button_style(btn)
	_delete_btn.disabled = (_selected_id == "")


func _show_empty_state() -> void:
	_selected_id = ""
	_empty_label.visible = true
	for child in _editor_panel.get_children():
		if child != _empty_label and child != _preview_player:
			child.visible = false
	_delete_btn.disabled = true


func _show_editor_state() -> void:
	_empty_label.visible = false
	for child in _editor_panel.get_children():
		child.visible = true
	_empty_label.visible = false


func _select_preset(id: String) -> void:
	_selected_id = id
	_show_editor_state()

	var data: KeyChangeData = _get_preset_by_id(id)
	if not data:
		_show_empty_state()
		return

	_suppressing_signals = true

	_name_edit.text = data.display_name

	_semitone_slider.value = data.semitones
	_semitone_value.text = _format_semitones(data.semitones)

	_fade_slider.value = data.fade_duration
	_fade_value.text = str(snapped(data.fade_duration, 0.01)) + "s"

	# Enter SFX
	_select_sfx_option(_enter_sfx_option, data.enter_sfx_path)
	_enter_vol_slider.value = data.enter_sfx_volume_db
	_enter_vol_value.text = str(snapped(data.enter_sfx_volume_db, 0.5)) + " dB"
	_enter_offset_slider.value = data.enter_sfx_offset
	_enter_offset_value.text = str(snapped(data.enter_sfx_offset, 0.01)) + "s"

	# Exit SFX
	_select_sfx_option(_exit_sfx_option, data.exit_sfx_path)
	_exit_vol_slider.value = data.exit_sfx_volume_db
	_exit_vol_value.text = str(snapped(data.exit_sfx_volume_db, 0.5)) + " dB"
	_exit_offset_slider.value = data.exit_sfx_offset
	_exit_offset_value.text = str(snapped(data.exit_sfx_offset, 0.01)) + "s"
	_exit_reverse_check.button_pressed = data.reverse_exit_sfx

	_suppressing_signals = false
	_update_list_selection()


func _select_sfx_option(option: OptionButton, path: String) -> void:
	if path == "":
		option.selected = 0
		return
	var file_name: String = path.get_file()
	for i in range(1, option.get_item_count()):
		if option.get_item_text(i) == file_name:
			option.selected = i
			return
	option.selected = 0


func _get_sfx_path_from_option(option: OptionButton) -> String:
	var idx: int = option.selected
	if idx <= 0:
		return ""
	var file_name: String = option.get_item_text(idx)
	return "res://assets/audio/sfx/" + file_name


func _update_list_selection() -> void:
	for child in _list_container.get_children():
		if child is Button:
			var btn_id: String = child.name.replace("ListItem_", "")
			child.button_pressed = (btn_id == _selected_id)


func _get_preset_by_id(id: String) -> KeyChangeData:
	for p in _presets:
		if p.id == id:
			return p
	return null


func _generate_unique_id() -> String:
	var existing: Array[String] = []
	for p in _presets:
		existing.append(p.id)
	var counter: int = 1
	while true:
		var candidate: String = "key_change_" + str(counter)
		if candidate not in existing:
			return candidate
		counter += 1
	return "key_change_1"


func _auto_save() -> void:
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		KeyChangeDataManager.save(data)


func _scan_sfx_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open("res://assets/audio/sfx/")
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower: String = file_name.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				files.append("res://assets/audio/sfx/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


static func _format_semitones(st: int) -> String:
	if st == 0:
		return "0 st"
	elif st > 0:
		return "+" + str(st) + " st"
	else:
		return str(st) + " st"


# --- Measure boundary detection (mirrors game.gd logic) ---

func _auto_detect_bars_from_duration(duration_sec: float) -> int:
	if duration_sec <= 0.0:
		return 2
	var bpm: float = 120.0
	var beats: float = duration_sec * bpm / 60.0
	var bars_float: float = beats / 4.0
	var candidates: Array[int] = [1, 2, 4, 8]
	var best: int = 2
	var best_dist: float = 999.0
	for c in candidates:
		var dist: float = absf(bars_float - float(c))
		if dist < best_dist:
			best_dist = dist
			best = c
	return best


func _check_measure_boundary() -> void:
	var audition_id: String = "loop_browser_audition"
	if not LoopMixer.has_loop(audition_id):
		# No loop playing — apply immediately as fallback
		_apply_shift_now()
		return
	var pos_sec: float = LoopMixer.get_playback_position(audition_id)
	var duration: float = LoopMixer.get_stream_duration(audition_id)
	if duration <= 0.0 or pos_sec < 0.0:
		return
	var curr_norm: float = pos_sec / duration
	if _prev_loop_pos < 0.0:
		_prev_loop_pos = curr_norm
		return
	var measure_size: float = 1.0 / float(maxi(_detected_bars, 1))
	var crossed: bool = false
	if curr_norm >= _prev_loop_pos:
		var prev_measure: int = int(_prev_loop_pos / measure_size)
		var curr_measure: int = int(curr_norm / measure_size)
		crossed = curr_measure > prev_measure
	else:
		crossed = true

	# Schedule SFX before the boundary if not already done
	if not _sfx_scheduled and not crossed:
		var time_in_measure: float = fmod(curr_norm, measure_size)
		var time_to_boundary_sec: float = (measure_size - time_in_measure) * duration
		var data: KeyChangeData = _get_preset_by_id(_selected_id)
		if data and data.enter_sfx_path != "" and time_to_boundary_sec <= data.enter_sfx_offset:
			_play_sfx(data.enter_sfx_path, data.enter_sfx_volume_db, false)
			_sfx_scheduled = true

	_prev_loop_pos = curr_norm
	if crossed:
		_apply_shift_now()


func _apply_shift_now() -> void:
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	var fade: float = data.fade_duration if data else 0.15
	_current_shift = _pending_shift
	LoopMixer.set_pitch_shift(float(_current_shift), fade)
	_sfx_scheduled = false
	if _current_shift == 0:
		_status_label.text = "Pitch reset to normal"
	else:
		_status_label.text = "Key shifted " + _format_semitones(_current_shift)


func _play_sfx(path: String, volume_db: float, reverse: bool) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if not stream:
		return
	if reverse and stream is AudioStreamWAV:
		stream = KeyChangeData.make_reversed_stream(stream as AudioStreamWAV)
	AudioManager.play_sample(stream, 1.0, volume_db)


# --- Signal handlers ---

func _on_create_new() -> void:
	var id: String = _generate_unique_id()
	var counter: int = _presets.size() + 1
	var data := KeyChangeData.new()
	data.id = id
	data.display_name = "Key Change " + str(counter)
	data.fade_duration = 0.15
	KeyChangeDataManager.save(data)
	_presets.append(data)
	_rebuild_list()
	_select_preset(id)


func _on_delete() -> void:
	if _selected_id == "":
		return
	KeyChangeDataManager.delete(_selected_id)
	var idx: int = -1
	for i in range(_presets.size()):
		if _presets[i].id == _selected_id:
			idx = i
			break
	if idx >= 0:
		_presets.remove_at(idx)
	if _presets.size() > 0:
		var new_idx: int = mini(idx, _presets.size() - 1)
		_rebuild_list()
		_select_preset(_presets[new_idx].id)
	else:
		_selected_id = ""
		_rebuild_list()
		_show_empty_state()


func _on_list_item_pressed(id: String) -> void:
	_select_preset(id)


func _on_name_changed(new_name: String) -> void:
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.display_name = new_name
		_auto_save()
		for child in _list_container.get_children():
			if child is Button and child.name == "ListItem_" + _selected_id:
				child.text = new_name


func _on_semitone_changed(val: float) -> void:
	_semitone_value.text = _format_semitones(int(val))
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.semitones = int(val)
		_auto_save()


func _on_fade_changed(val: float) -> void:
	_fade_value.text = str(snapped(val, 0.01)) + "s"
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.fade_duration = val
		_auto_save()


func _on_enter_sfx_selected(_idx: int) -> void:
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.enter_sfx_path = _get_sfx_path_from_option(_enter_sfx_option)
		_auto_save()


func _on_enter_vol_changed(val: float) -> void:
	_enter_vol_value.text = str(snapped(val, 0.5)) + " dB"
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.enter_sfx_volume_db = val
		_auto_save()


func _on_enter_offset_changed(val: float) -> void:
	_enter_offset_value.text = str(snapped(val, 0.01)) + "s"
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.enter_sfx_offset = val
		_auto_save()


func _on_exit_sfx_selected(_idx: int) -> void:
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.exit_sfx_path = _get_sfx_path_from_option(_exit_sfx_option)
		_auto_save()


func _on_exit_vol_changed(val: float) -> void:
	_exit_vol_value.text = str(snapped(val, 0.5)) + " dB"
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.exit_sfx_volume_db = val
		_auto_save()


func _on_exit_offset_changed(val: float) -> void:
	_exit_offset_value.text = str(snapped(val, 0.01)) + "s"
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.exit_sfx_offset = val
		_auto_save()


func _on_reverse_toggled(toggled_on: bool) -> void:
	if _suppressing_signals:
		return
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data:
		data.reverse_exit_sfx = toggled_on
		_auto_save()


func _on_preview_enter() -> void:
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data and data.enter_sfx_path != "":
		_play_sfx(data.enter_sfx_path, data.enter_sfx_volume_db, false)


func _on_preview_exit() -> void:
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if data and data.exit_sfx_path != "":
		_play_sfx(data.exit_sfx_path, data.exit_sfx_volume_db, data.reverse_exit_sfx)


func _on_loop_selected(path: String, _category: String) -> void:
	# Auto-detect bars from the loop duration for measure boundary detection
	var duration: float = LoopMixer.get_stream_duration("loop_browser_audition")
	if duration > 0.0:
		_detected_bars = _auto_detect_bars_from_duration(duration)
	_preview_playing = true
	_play_btn.button_pressed = true
	_play_btn.text = "STOP"
	_prev_loop_pos = -1.0


func _on_play_toggle() -> void:
	if _play_btn.button_pressed:
		# LoopBrowser auto-starts on loop selection — if already has a loop, just unmute
		var audition_id: String = "loop_browser_audition"
		if LoopMixer.has_loop(audition_id):
			LoopMixer.unmute(audition_id)
			_preview_playing = true
			_play_btn.text = "STOP"
		else:
			_play_btn.button_pressed = false
	else:
		var audition_id: String = "loop_browser_audition"
		if LoopMixer.has_loop(audition_id):
			LoopMixer.mute(audition_id)
		_preview_playing = false
		_play_btn.text = "PLAY"


func _on_trigger() -> void:
	var data: KeyChangeData = _get_preset_by_id(_selected_id)
	if not data:
		return
	if _current_shift == 0:
		# Shift into the key change
		_pending_shift = data.semitones
		_status_label.text = "Waiting for measure boundary..."
		_sfx_scheduled = false
		_prev_loop_pos = -1.0
	else:
		# Shift back to normal
		_pending_shift = 0
		_status_label.text = "Waiting for measure boundary (reset)..."
		_sfx_scheduled = false
		_prev_loop_pos = -1.0


func _on_reset() -> void:
	_pending_shift = 0
	_current_shift = 0
	_sfx_scheduled = false
	LoopMixer.set_pitch_shift(0.0, 0.05)
	_status_label.text = "Pitch reset to normal"


# --- Theme ---

func _apply_theme() -> void:
	ThemeManager.apply_button_style(_create_btn)
	ThemeManager.apply_button_style(_delete_btn)
	ThemeManager.apply_button_style(_enter_preview_btn)
	ThemeManager.apply_button_style(_exit_preview_btn)
	ThemeManager.apply_button_style(_play_btn)
	ThemeManager.apply_button_style(_trigger_btn)
	ThemeManager.apply_button_style(_reset_btn)
	ThemeManager.apply_button_style(_exit_reverse_check)

	for child in _list_container.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child)

	# Header labels in editor panel
	for child in _editor_panel.get_children():
		if child is Label and child.name.ends_with("Header") or child.name == "ListHeader" or child.name == "StatusLabel":
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")

	# Left panel header
	for child in get_children():
		if child is HSplitContainer:
			var left: VBoxContainer = child.get_child(0) as VBoxContainer
			if left:
				for sub in left.get_children():
					if sub is Label:
						ThemeManager.apply_text_glow(sub, "header")

	ThemeManager.apply_text_glow(_empty_label, "body")
