class_name IntroMusicEditor
extends PopupPanel
## Popup editor for a level's intro music tracks. Drives LevelData.intro_tracks.
## Timeline in bars; each track has start/end bars, fades, volume, and a loop.
## Audition plays the intro via LoopMixer at the level's BPM.

signal tracks_changed

const POPUP_W: int = 960
const POPUP_H: int = 640

const TIMELINE_H: int = 160
const TRACK_H: int = 34
const TRACK_GAP: int = 8
const TIMELINE_LABEL_H: int = 20
const MAX_TRACKS: int = 8

const AUDITION_PREFIX: String = "__intro_audition_"

var _level_data: LevelData = null
var _selected_track_idx: int = -1

var _root_vbox: VBoxContainer
var _header_label: Label
var _bpm_label: Label
var _duration_spin: SpinBox
var _timeline: Control
var _side_panel: VBoxContainer
var _track_label_edit: LineEdit
var _track_loop_label: Label
var _track_browse_btn: Button
var _track_start_spin: SpinBox
var _track_end_spin: SpinBox
var _track_fadein_spin: SpinBox
var _track_fadeout_spin: SpinBox
var _track_volume_spin: SpinBox
var _track_delete_btn: Button
var _add_btn: Button
var _audition_btn: Button
var _audition_running: bool = false
var _audition_timers: Array[SceneTreeTimer] = []

var _loop_browser_popup: PopupPanel = null


func _init() -> void:
	size = Vector2i(POPUP_W, POPUP_H)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.96)
	style.border_color = ThemeManager.get_color("accent")
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	popup_hide.connect(_on_closed)


func _ready() -> void:
	_build_ui()


func open_for_level(level: LevelData) -> void:
	_level_data = level
	_selected_track_idx = -1
	if _level_data and _level_data.intro_tracks.size() > 0:
		_selected_track_idx = 0
	_refresh_all()
	popup_centered()


func _build_ui() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 8)
	add_child(_root_vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	_root_vbox.add_child(header_row)

	_header_label = Label.new()
	_header_label.text = "INTRO MUSIC"
	ThemeManager.apply_text_glow(_header_label, "header")
	header_row.add_child(_header_label)

	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer1)

	_bpm_label = Label.new()
	_bpm_label.text = "BPM: 110"
	ThemeManager.apply_text_glow(_bpm_label, "body")
	header_row.add_child(_bpm_label)

	var dur_label := Label.new()
	dur_label.text = "  DURATION (bars):"
	ThemeManager.apply_text_glow(dur_label, "body")
	header_row.add_child(dur_label)

	_duration_spin = SpinBox.new()
	_duration_spin.min_value = 2
	_duration_spin.max_value = 32
	_duration_spin.step = 1
	_duration_spin.value = 8
	_duration_spin.custom_minimum_size.x = 70
	_duration_spin.value_changed.connect(_on_duration_changed)
	header_row.add_child(_duration_spin)

	_add_btn = Button.new()
	_add_btn.text = "+ ADD TRACK"
	_add_btn.pressed.connect(_on_add_track)
	ThemeManager.apply_button_style(_add_btn)
	header_row.add_child(_add_btn)

	_audition_btn = Button.new()
	_audition_btn.text = "AUDITION"
	_audition_btn.pressed.connect(_on_audition_toggle)
	ThemeManager.apply_button_style(_audition_btn)
	header_row.add_child(_audition_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func() -> void: hide())
	ThemeManager.apply_button_style(close_btn)
	header_row.add_child(close_btn)

	# Timeline
	_timeline = Control.new()
	_timeline.custom_minimum_size.y = TIMELINE_H
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.draw.connect(_draw_timeline)
	_timeline.gui_input.connect(_on_timeline_input)
	_root_vbox.add_child(_timeline)

	var sep := HSeparator.new()
	_root_vbox.add_child(sep)

	# Side panel (selected track editor)
	_side_panel = VBoxContainer.new()
	_side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_panel.add_theme_constant_override("separation", 6)
	_root_vbox.add_child(_side_panel)

	_build_side_panel()


func _build_side_panel() -> void:
	var title := Label.new()
	title.text = "SELECTED TRACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(title, "header")
	_side_panel.add_child(title)

	# Label row
	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 8)
	_side_panel.add_child(label_row)

	var label_hint := Label.new()
	label_hint.text = "Label:"
	label_hint.custom_minimum_size.x = 80
	label_row.add_child(label_hint)

	_track_label_edit = LineEdit.new()
	_track_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_label_edit.text_changed.connect(_on_label_changed)
	label_row.add_child(_track_label_edit)

	# Loop row
	var loop_row := HBoxContainer.new()
	loop_row.add_theme_constant_override("separation", 8)
	_side_panel.add_child(loop_row)

	var loop_hint := Label.new()
	loop_hint.text = "Loop:"
	loop_hint.custom_minimum_size.x = 80
	loop_row.add_child(loop_hint)

	_track_loop_label = Label.new()
	_track_loop_label.text = "(none)"
	_track_loop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_loop_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	_track_loop_label.clip_text = true
	loop_row.add_child(_track_loop_label)

	_track_browse_btn = Button.new()
	_track_browse_btn.text = "BROWSE..."
	_track_browse_btn.pressed.connect(_on_browse_loop)
	ThemeManager.apply_button_style(_track_browse_btn)
	loop_row.add_child(_track_browse_btn)

	# Numeric row 1 — start/end
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	_side_panel.add_child(row1)

	row1.add_child(_labeled_spin("Start bar:", 0.0, 31.0, 0.25, 0.0, _on_start_changed))
	_track_start_spin = row1.get_child(0).get_child(1) as SpinBox
	row1.add_child(_labeled_spin("End bar:", 0.25, 32.0, 0.25, 4.0, _on_end_changed))
	_track_end_spin = row1.get_child(1).get_child(1) as SpinBox

	# Numeric row 2 — fades
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_side_panel.add_child(row2)

	row2.add_child(_labeled_spin("Fade in (bars):", 0.0, 8.0, 0.25, 0.0, _on_fadein_changed))
	_track_fadein_spin = row2.get_child(0).get_child(1) as SpinBox
	row2.add_child(_labeled_spin("Fade out (bars):", 0.0, 8.0, 0.25, 1.0, _on_fadeout_changed))
	_track_fadeout_spin = row2.get_child(1).get_child(1) as SpinBox

	# Numeric row 3 — volume + delete
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	_side_panel.add_child(row3)

	row3.add_child(_labeled_spin("Volume (dB):", -40.0, 6.0, 0.5, 0.0, _on_volume_changed))
	_track_volume_spin = row3.get_child(0).get_child(1) as SpinBox

	var row3_spacer := Control.new()
	row3_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(row3_spacer)

	_track_delete_btn = Button.new()
	_track_delete_btn.text = "DELETE TRACK"
	_track_delete_btn.pressed.connect(_on_delete_track)
	ThemeManager.apply_button_style(_track_delete_btn)
	row3.add_child(_track_delete_btn)


func _labeled_spin(label_text: String, minv: float, maxv: float, step: float, initial: float, cb: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 110
	box.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = minv
	spin.max_value = maxv
	spin.step = step
	spin.value = initial
	spin.custom_minimum_size.x = 80
	spin.value_changed.connect(cb)
	box.add_child(spin)
	return box


# ── Data access ────────────────────────────────────────────────

func _tracks() -> Array:
	if not _level_data:
		return []
	return _level_data.intro_tracks


func _selected_track() -> Dictionary:
	var arr: Array = _tracks()
	if _selected_track_idx < 0 or _selected_track_idx >= arr.size():
		return {}
	return arr[_selected_track_idx]


func _refresh_all() -> void:
	if _level_data:
		_header_label.text = "INTRO MUSIC — " + _level_data.display_name
		_bpm_label.text = "BPM: %d" % int(_level_data.bpm)
		_duration_spin.set_value_no_signal(float(_level_data.intro_duration_bars))
	_timeline.queue_redraw()
	_refresh_side_panel()


func _refresh_side_panel() -> void:
	var tr: Dictionary = _selected_track()
	var enabled: bool = not tr.is_empty()
	_track_label_edit.editable = enabled
	_track_browse_btn.disabled = not enabled
	_track_start_spin.editable = enabled
	_track_end_spin.editable = enabled
	_track_fadein_spin.editable = enabled
	_track_fadeout_spin.editable = enabled
	_track_volume_spin.editable = enabled
	_track_delete_btn.disabled = not enabled
	if not enabled:
		_track_label_edit.text = ""
		_track_loop_label.text = "(no track selected)"
		return
	_track_label_edit.text = str(tr.get("label", ""))
	var path: String = str(tr.get("loop_path", ""))
	_track_loop_label.text = path.get_file() if path != "" else "(none)"
	_track_start_spin.set_value_no_signal(float(tr.get("start_bar", 0.0)))
	_track_end_spin.set_value_no_signal(float(tr.get("end_bar", 4.0)))
	_track_fadein_spin.set_value_no_signal(float(tr.get("fade_in_bars", 0.0)))
	_track_fadeout_spin.set_value_no_signal(float(tr.get("fade_out_bars", 1.0)))
	_track_volume_spin.set_value_no_signal(float(tr.get("volume_db", 0.0)))


func _commit() -> void:
	tracks_changed.emit()


# ── Side panel callbacks ──────────────────────────────────────

func _on_label_changed(new_text: String) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["label"] = new_text
	_timeline.queue_redraw()
	_commit()


func _on_start_changed(v: float) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["start_bar"] = v
	var end_v: float = float(tr.get("end_bar", 4.0))
	if end_v <= v:
		tr["end_bar"] = v + 0.25
		_track_end_spin.set_value_no_signal(v + 0.25)
	_timeline.queue_redraw()
	_commit()


func _on_end_changed(v: float) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["end_bar"] = v
	var start_v: float = float(tr.get("start_bar", 0.0))
	if start_v >= v:
		tr["start_bar"] = v - 0.25
		_track_start_spin.set_value_no_signal(v - 0.25)
	_timeline.queue_redraw()
	_commit()


func _on_fadein_changed(v: float) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["fade_in_bars"] = v
	_timeline.queue_redraw()
	_commit()


func _on_fadeout_changed(v: float) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["fade_out_bars"] = v
	_timeline.queue_redraw()
	_commit()


func _on_volume_changed(v: float) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["volume_db"] = v
	_commit()


func _on_duration_changed(v: float) -> void:
	if not _level_data:
		return
	_level_data.intro_duration_bars = int(v)
	_timeline.queue_redraw()
	_commit()


func _on_add_track() -> void:
	if not _level_data:
		return
	var arr: Array = _tracks()
	if arr.size() >= MAX_TRACKS:
		return
	var new_track: Dictionary = {
		"loop_path": "",
		"label": "Track %d" % (arr.size() + 1),
		"start_bar": 0.0,
		"end_bar": 4.0,
		"fade_in_bars": 0.0,
		"fade_out_bars": 1.0,
		"volume_db": 0.0,
	}
	arr.append(new_track)
	_selected_track_idx = arr.size() - 1
	_refresh_all()
	_commit()


func _on_delete_track() -> void:
	if not _level_data or _selected_track_idx < 0:
		return
	var arr: Array = _tracks()
	if _selected_track_idx >= arr.size():
		return
	arr.remove_at(_selected_track_idx)
	if _selected_track_idx >= arr.size():
		_selected_track_idx = arr.size() - 1
	_refresh_all()
	_commit()


# ── Loop browser popup ────────────────────────────────────────

func _on_browse_loop() -> void:
	if _selected_track().is_empty():
		return
	if _loop_browser_popup == null:
		_loop_browser_popup = PopupPanel.new()
		_loop_browser_popup.size = Vector2i(420, 320)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.08, 0.98)
		style.border_color = ThemeManager.get_color("accent")
		style.border_width_bottom = 1
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		_loop_browser_popup.add_theme_stylebox_override("panel", style)
		var browser := LoopBrowser.new()
		browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
		browser.loop_selected.connect(_on_loop_browser_selected)
		_loop_browser_popup.add_child(browser)
		add_child(_loop_browser_popup)
	_loop_browser_popup.popup_centered()


func _on_loop_browser_selected(path: String, _category: String) -> void:
	var tr: Dictionary = _selected_track()
	if tr.is_empty():
		return
	tr["loop_path"] = path
	_track_loop_label.text = path.get_file()
	_timeline.queue_redraw()
	_commit()


# ── Timeline drawing ──────────────────────────────────────────

func _bar_width() -> float:
	if not _level_data:
		return 40.0
	var bars: int = max(_level_data.intro_duration_bars, 1)
	return (_timeline.size.x - 20.0) / float(bars)


func _draw_timeline() -> void:
	if not _level_data:
		return
	var w: float = _timeline.size.x
	var h: float = _timeline.size.y
	var bars: int = max(_level_data.intro_duration_bars, 1)
	var bw: float = _bar_width()
	var left_pad: float = 10.0
	var accent: Color = ThemeManager.get_color("accent")
	var dim: Color = ThemeManager.get_color("disabled")
	var text_col: Color = ThemeManager.get_color("text")

	# Background
	_timeline.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.08, 0.08, 0.14, 1.0), true)

	# Bar grid + labels
	var grid_top: float = TIMELINE_LABEL_H
	var grid_bottom: float = h - 4.0
	for b in range(bars + 1):
		var x: float = left_pad + float(b) * bw
		var col: Color = Color(accent.r, accent.g, accent.b, 0.35 if b % 4 == 0 else 0.15)
		_timeline.draw_line(Vector2(x, grid_top), Vector2(x, grid_bottom), col, 1.0)
		if b < bars + 1:
			var font: Font = ThemeDB.fallback_font
			var lbl: String = str(b)
			_timeline.draw_string(font, Vector2(x + 2.0, TIMELINE_LABEL_H - 4.0), lbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(dim.r, dim.g, dim.b, 0.8))

	# Tracks
	var arr: Array = _tracks()
	var row_y: float = grid_top + 6.0
	for i in range(arr.size()):
		var tr: Dictionary = arr[i]
		var s_bar: float = float(tr.get("start_bar", 0.0))
		var e_bar: float = float(tr.get("end_bar", 4.0))
		var fi: float = float(tr.get("fade_in_bars", 0.0))
		var fo: float = float(tr.get("fade_out_bars", 1.0))
		var s_x: float = left_pad + s_bar * bw
		var e_x: float = left_pad + e_bar * bw
		var tr_rect := Rect2(Vector2(s_x, row_y), Vector2(maxf(e_x - s_x, 2.0), TRACK_H))
		var is_sel: bool = (i == _selected_track_idx)
		var body_col: Color = Color(accent.r * 0.8, accent.g * 0.8, accent.b * 0.8, 0.45 if is_sel else 0.28)
		_timeline.draw_rect(tr_rect, body_col, true)
		# Fade-in taper
		if fi > 0.0:
			var fi_w: float = minf(fi * bw, e_x - s_x)
			var pts_in := PackedVector2Array([
				Vector2(s_x, row_y + TRACK_H),
				Vector2(s_x, row_y),
				Vector2(s_x + fi_w, row_y),
				Vector2(s_x + fi_w, row_y + TRACK_H),
			])
			_timeline.draw_colored_polygon(pts_in, Color(0.0, 0.0, 0.0, 0.25))
			_timeline.draw_line(Vector2(s_x, row_y + TRACK_H), Vector2(s_x + fi_w, row_y), accent, 1.5)
		# Fade-out taper
		if fo > 0.0:
			var fo_w: float = minf(fo * bw, e_x - s_x)
			_timeline.draw_line(Vector2(e_x - fo_w, row_y), Vector2(e_x, row_y + TRACK_H), accent, 1.5)
		# Border
		_timeline.draw_rect(tr_rect, Color(accent.r, accent.g, accent.b, 0.9 if is_sel else 0.5), false, 1.5 if is_sel else 1.0)
		# Label
		var font: Font = ThemeDB.fallback_font
		var label: String = str(tr.get("label", "Track"))
		var path: String = str(tr.get("loop_path", ""))
		if path == "":
			label += "  (no loop)"
		_timeline.draw_string(font, Vector2(s_x + 6.0, row_y + TRACK_H * 0.62), label,
			HORIZONTAL_ALIGNMENT_LEFT, maxf(e_x - s_x - 10.0, 10.0), 12, text_col)
		row_y += TRACK_H + TRACK_GAP


func _on_timeline_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# Hit test against track rows
	var arr: Array = _tracks()
	var grid_top: float = TIMELINE_LABEL_H + 6.0
	var y: float = mb.position.y
	if y < grid_top:
		return
	var row_idx: int = int((y - grid_top) / float(TRACK_H + TRACK_GAP))
	if row_idx < 0 or row_idx >= arr.size():
		return
	# Also verify horizontal hit
	var bw: float = _bar_width()
	var left_pad: float = 10.0
	var tr: Dictionary = arr[row_idx]
	var s_x: float = left_pad + float(tr.get("start_bar", 0.0)) * bw
	var e_x: float = left_pad + float(tr.get("end_bar", 4.0)) * bw
	if mb.position.x < s_x or mb.position.x > e_x:
		# Out of bar range — still select the row (helpful if tracks are thin)
		pass
	_selected_track_idx = row_idx
	_refresh_side_panel()
	_timeline.queue_redraw()


# ── Audition ──────────────────────────────────────────────────

func _on_audition_toggle() -> void:
	if _audition_running:
		_stop_audition()
	else:
		_start_audition()


func _start_audition() -> void:
	if not _level_data or _tracks().is_empty():
		return
	_stop_audition()  # clear any stragglers
	_audition_running = true
	_audition_btn.text = "STOP"
	var bpm: float = _level_data.bpm if _level_data.bpm > 0.0 else 110.0
	var bar_dur: float = 60.0 / bpm * 4.0
	var arr: Array = _tracks()
	# Register all tracks muted
	for i in range(arr.size()):
		var tr: Dictionary = arr[i]
		var path: String = str(tr.get("loop_path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var loop_id: String = AUDITION_PREFIX + str(i)
		var vol: float = float(tr.get("volume_db", 0.0))
		if LoopMixer.has_loop(loop_id):
			LoopMixer.remove_loop(loop_id)
		LoopMixer.add_loop(loop_id, path, "Atmosphere", vol, true)
	LoopMixer.start_all()
	# Schedule fades
	var max_end_t: float = 0.0
	for i in range(arr.size()):
		var tr: Dictionary = arr[i]
		var loop_id: String = AUDITION_PREFIX + str(i)
		if not LoopMixer.has_loop(loop_id):
			continue
		var start_t: float = float(tr.get("start_bar", 0.0)) * bar_dur
		var end_t: float = float(tr.get("end_bar", 4.0)) * bar_dur
		var fade_in_ms: int = int(float(tr.get("fade_in_bars", 0.0)) * bar_dur * 1000.0)
		var fade_out_ms: int = int(float(tr.get("fade_out_bars", 1.0)) * bar_dur * 1000.0)
		max_end_t = maxf(max_end_t, end_t + float(fade_out_ms) / 1000.0 + 0.1)
		if start_t <= 0.0:
			LoopMixer.unmute(loop_id, fade_in_ms)
		else:
			var t1: SceneTreeTimer = get_tree().create_timer(start_t)
			_audition_timers.append(t1)
			t1.timeout.connect(func() -> void:
				if _audition_running and LoopMixer.has_loop(loop_id):
					LoopMixer.unmute(loop_id, fade_in_ms)
			)
		var t2: SceneTreeTimer = get_tree().create_timer(end_t)
		_audition_timers.append(t2)
		t2.timeout.connect(func() -> void:
			if _audition_running and LoopMixer.has_loop(loop_id):
				LoopMixer.mute(loop_id, fade_out_ms)
		)
	# Auto-stop when the longest track finishes fading out
	if max_end_t > 0.0:
		var t_done: SceneTreeTimer = get_tree().create_timer(max_end_t)
		_audition_timers.append(t_done)
		t_done.timeout.connect(func() -> void:
			if _audition_running:
				_stop_audition()
		)


func _stop_audition() -> void:
	_audition_running = false
	_audition_btn.text = "AUDITION"
	_audition_timers.clear()
	if not _level_data:
		return
	var arr: Array = _tracks()
	for i in range(arr.size()):
		var loop_id: String = AUDITION_PREFIX + str(i)
		if LoopMixer.has_loop(loop_id):
			LoopMixer.remove_loop(loop_id)


func _on_closed() -> void:
	_stop_audition()
