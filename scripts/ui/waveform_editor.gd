class_name WaveformEditor
extends Control
## Visual waveform editor: displays WAV waveform, optional beat grid overlay,
## click-to-place fire triggers in normalized time (0.0–1.0).
## Snap modes: Free, 1/4, 1/8, 1/16. Playback cursor synced to LoopMixer.
## Supports select, drag, and delete of markers.

signal triggers_changed(triggers: Array)
signal play_pause_requested
signal seek_requested(time_normalized: float)

var _stream: AudioStream = null
var _waveform_data: PackedFloat32Array = PackedFloat32Array()
var _loop_length_bars: int = 2
var _fire_triggers: Array = []  # Array[float] — normalized time (0.0–1.0)
var _snap_mode: int = 0  # 0=Free, 4=1/4, 8=1/8, 16=1/16
var _beats_per_bar: int = 4
var _hovered_time: float = -1.0
var _cursor_progress: float = -1.0  # 0.0–1.0 normalized
var _show_cursor: bool = false
var _has_stream: bool = false
var _detected_duration_sec: float = 0.0  # From raw WAV parsing (for bar auto-detection)
var _audition_loop_id: String = ""
var _show_beat_grid: bool = true

# Zoom/scroll state
var _zoom_level: float = 1.0       # 1.0 = full view, higher = zoomed in
var _scroll_offset: float = 0.0    # Normalized left edge of visible area (0.0–1.0)
const ZOOM_STEP: float = 1.3
const ZOOM_MAX: float = 16.0
const SCROLL_STEP: float = 0.05    # Fraction of view range per scroll tick
const VIEWPORT_BAR_HEIGHT: float = 4.0
const RULER_HEIGHT: float = 22.0

# Marker interaction state
enum MarkerState { IDLE, HOVERING, DRAGGING }
var _marker_state: int = MarkerState.IDLE
var _selected_indices: Array[int] = []         # Sorted indices of selected markers
var _drag_original_times: Array[float] = []    # Original times of ALL selected during drag
var _drag_anchor_idx: int = -1                 # Which selected marker the user grabbed
var _clipboard: Array[float] = []              # Copied trigger offsets (relative to leftmost)
var _hovered_idx: int = -1         # Index of marker mouse is near
var _mouse_down: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _ctrl_click_pending_idx: int = -1  # For Ctrl+click toggle on mouse-up
var _ruler_dragging: bool = false
const DRAG_THRESHOLD_PX: float = 5.0
const MARKER_HIT_PX: float = 10.0

# Colors
var _bg_color: Color = Color(0.05, 0.05, 0.1)
var _waveform_color: Color = Color(0.2, 0.6, 0.9, 0.6)
var _grid_color: Color = Color(0.2, 0.2, 0.3)
var _bar_line_color: Color = Color(0.4, 0.4, 0.6)
var _trigger_color: Color = Color(1.0, 0.3, 0.3)
var _cursor_color: Color = Color(0.3, 1.0, 0.5, 0.8)
var _hover_color: Color = Color(1.0, 1.0, 1.0, 0.3)
var _selected_color: Color = Color(1.0, 0.85, 0.2)       # Gold for selected
var _hovered_marker_color: Color = Color(1.0, 0.5, 0.5)   # Light red for hover

# Per-marker color callback: Callable(idx: int) -> Color. Unset = use _trigger_color.
var _marker_color_callback: Callable = Callable()


func set_marker_color_callback(cb: Callable) -> void:
	_marker_color_callback = cb
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 142)
	focus_mode = Control.FOCUS_ALL


func set_stream(stream: AudioStream) -> void:
	_stream = stream
	_has_stream = stream != null
	_generate_waveform_data()
	queue_redraw()


func set_stream_from_path(path: String) -> void:
	## Parse the original WAV file for real PCM waveform data, bypassing Godot's import.
	## Also auto-detects loop length in bars from duration + BPM.
	_waveform_data.clear()
	_detected_duration_sec = 0.0

	if path == "":
		_has_stream = false
		_show_cursor = false
		_loop_length_bars = 2
		queue_redraw()
		return

	# Also load the Godot stream for compatibility
	_stream = load(path) as AudioStream
	_has_stream = _stream != null

	# Parse raw WAV file
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("WaveformEditor: cannot open WAV file: " + path)
		_generate_waveform_data()
		queue_redraw()
		return

	# Read RIFF header
	var riff: String = _read_fourcc(file)
	if riff != "RIFF":
		push_warning("WaveformEditor: not a RIFF file: " + path)
		file.close()
		_generate_waveform_data()
		queue_redraw()
		return

	var _file_size: int = file.get_32()  # file size - 8
	var wave: String = _read_fourcc(file)
	if wave != "WAVE":
		push_warning("WaveformEditor: not a WAVE file: " + path)
		file.close()
		_generate_waveform_data()
		queue_redraw()
		return

	var sample_rate: int = 44100
	var channels: int = 1
	var bits_per_sample: int = 16
	var data_bytes: PackedByteArray = PackedByteArray()

	# Scan chunks
	while file.get_position() < file.get_length() - 8:
		var chunk_id: String = _read_fourcc(file)
		var chunk_size: int = file.get_32()

		if chunk_id == "fmt ":
			var _audio_format: int = file.get_16()  # 1 = PCM
			channels = file.get_16()
			sample_rate = file.get_32()
			var _byte_rate: int = file.get_32()
			var _block_align: int = file.get_16()
			bits_per_sample = file.get_16()
			# Skip any extra fmt bytes
			var fmt_read: int = 16
			if chunk_size > fmt_read:
				file.get_buffer(chunk_size - fmt_read)
		elif chunk_id == "data":
			data_bytes = file.get_buffer(chunk_size)
		else:
			# Skip unknown chunk
			file.get_buffer(chunk_size)
		# Chunks are word-aligned (pad byte if odd size)
		if chunk_size % 2 != 0 and file.get_position() < file.get_length():
			file.get_8()

	file.close()

	if data_bytes.is_empty():
		push_warning("WaveformEditor: no data chunk found in: " + path)
		_generate_waveform_data()
		queue_redraw()
		return

	# Compute duration from raw WAV
	@warning_ignore("integer_division")
	var bytes_per_sample: int = bits_per_sample / 8
	@warning_ignore("integer_division")
	var total_samples: int = data_bytes.size() / (bytes_per_sample * channels)
	_detected_duration_sec = float(total_samples) / float(sample_rate)

	# Downsample to ~512 peak-amplitude values
	var display_count: int = 512
	_waveform_data.resize(display_count)

	for i in display_count:
		var start_sample: int = i * total_samples / display_count
		var end_sample: int = mini((i + 1) * total_samples / display_count, total_samples)
		var peak: float = 0.0
		for s in range(start_sample, end_sample):
			# Read first channel only for display
			var byte_offset: int = s * channels * bytes_per_sample
			if byte_offset + 1 >= data_bytes.size():
				break
			var sample_val: float = 0.0
			if bits_per_sample == 16:
				var raw: int = data_bytes[byte_offset] | (data_bytes[byte_offset + 1] << 8)
				# Sign-extend 16-bit
				if raw >= 32768:
					raw -= 65536
				sample_val = float(raw) / 32768.0
			elif bits_per_sample == 24:
				if byte_offset + 2 < data_bytes.size():
					var raw: int = data_bytes[byte_offset] | (data_bytes[byte_offset + 1] << 8) | (data_bytes[byte_offset + 2] << 16)
					if raw >= 8388608:
						raw -= 16777216
					sample_val = float(raw) / 8388608.0
			elif bits_per_sample == 8:
				sample_val = (float(data_bytes[byte_offset]) - 128.0) / 128.0
			peak = maxf(peak, absf(sample_val))
		_waveform_data[i] = peak

	# Normalize so the loudest peak fills the display
	var max_peak: float = 0.0
	for i2 in display_count:
		max_peak = maxf(max_peak, _waveform_data[i2])
	if max_peak > 0.0:
		var scale: float = 1.0 / max_peak
		for i2 in display_count:
			_waveform_data[i2] *= scale

	# Auto-detect loop length in bars
	_auto_detect_bars()

	# Enable cursor
	_show_cursor = true
	queue_redraw()


func get_detected_bars() -> int:
	return _loop_length_bars


func set_loop_length_bars(bars: int) -> void:
	_loop_length_bars = bars
	queue_redraw()


func set_snap_mode(mode: int) -> void:
	## 0 = Free, 4 = 1/4, 8 = 1/8, 16 = 1/16
	_snap_mode = mode


func set_triggers(triggers: Array) -> void:
	_fire_triggers = triggers.duplicate()
	_selected_indices.clear()
	_hovered_idx = -1
	_marker_state = MarkerState.IDLE
	_mouse_down = false
	queue_redraw()


func get_triggers() -> Array:
	return _fire_triggers.duplicate()


func set_show_cursor(show: bool) -> void:
	_show_cursor = show
	queue_redraw()


func set_show_beat_grid(show: bool) -> void:
	_show_beat_grid = show
	queue_redraw()


func set_audition_loop_id(id: String) -> void:
	_audition_loop_id = id


# --- Multi-selection helpers ---

func _is_selected(idx: int) -> bool:
	return idx in _selected_indices


func _clear_selection() -> void:
	_selected_indices.clear()


func _select_only(idx: int) -> void:
	_selected_indices = [idx]


func _toggle_selection(idx: int) -> void:
	var pos: int = _selected_indices.find(idx)
	if pos >= 0:
		_selected_indices.remove_at(pos)
	else:
		_selected_indices.append(idx)
		_selected_indices.sort()


func _process(_delta: float) -> void:
	if not _show_cursor or _audition_loop_id == "":
		return
	var pos_sec: float = LoopMixer.get_playback_position(_audition_loop_id)
	var duration: float = LoopMixer.get_stream_duration(_audition_loop_id)
	if pos_sec < 0.0 or duration <= 0.0:
		return
	_cursor_progress = clampf(pos_sec / duration, 0.0, 1.0)
	queue_redraw()


func _auto_detect_bars() -> void:
	if _detected_duration_sec <= 0.0:
		return
	var bpm: float = 120.0
	if bpm <= 0.0:
		return
	var beats: float = _detected_duration_sec * bpm / 60.0
	var bars_float: float = beats / float(_beats_per_bar)
	# Round to nearest of [1, 2, 4, 8]
	var candidates: Array[int] = [1, 2, 4, 8]
	var best_bars: int = 2
	var best_dist: float = 999.0
	for c in candidates:
		var dist: float = absf(bars_float - float(c))
		if dist < best_dist:
			best_dist = dist
			best_bars = c
	_loop_length_bars = best_bars


func _generate_waveform_data() -> void:
	_waveform_data.clear()
	var sample_count: int = 256
	_waveform_data.resize(sample_count)
	if _stream:
		# Fallback: seeded random waveform for streams loaded via set_stream()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(_stream.resource_path)
		for i in sample_count:
			var t: float = float(i) / float(sample_count)
			var base: float = sin(t * TAU * 4.0) * 0.3
			var detail: float = rng.randf_range(-0.4, 0.4)
			var envelope: float = 1.0 - abs(t - 0.5) * 0.5
			_waveform_data[i] = clampf((base + detail) * envelope, -1.0, 1.0)
	else:
		_waveform_data.fill(0.0)


func _read_fourcc(file: FileAccess) -> String:
	var bytes: PackedByteArray = file.get_buffer(4)
	return bytes.get_string_from_ascii()


func _find_nearest_trigger_px(pos: Vector2) -> int:
	## Returns index of nearest trigger within MARKER_HIT_PX pixels, or -1.
	var best_idx: int = -1
	var best_dist: float = MARKER_HIT_PX
	for i in _fire_triggers.size():
		var tx: float = _time_to_x(float(_fire_triggers[i]))
		var dist: float = absf(pos.x - tx)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func _place_new_trigger(pos: Vector2) -> void:
	## Place a new trigger at the snapped time corresponding to pos.
	var t: float = _snap_time(_pos_to_time(pos))
	# Don't place if too close to an existing trigger
	var snap_threshold: float = _get_snap_threshold()
	for i in _fire_triggers.size():
		if absf(float(_fire_triggers[i]) - t) < snap_threshold:
			return
	_fire_triggers.append(t)
	_fire_triggers.sort()
	triggers_changed.emit(_fire_triggers.duplicate())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.position.y < RULER_HEIGHT:
					# Ruler click → seek, don't place marker
					_ruler_dragging = true
					var seek_time: float = _pos_to_time(mb.position)
					seek_requested.emit(seek_time)
					accept_event()
					return
				if mb.double_click:
					# Double-click on empty space resets zoom
					var hit_idx: int = _find_nearest_trigger_px(mb.position)
					if hit_idx < 0:
						_zoom_level = 1.0
						_scroll_offset = 0.0
						queue_redraw()
						accept_event()
						return
				_handle_left_down(mb.position)
			else:
				if _ruler_dragging:
					_ruler_dragging = false
					accept_event()
					return
				_handle_left_up(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(mb.position)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if mb.ctrl_pressed:
				# Ctrl + wheel = zoom centered on cursor
				var time_at_cursor: float = _pos_to_time(mb.position)
				var new_zoom: float = _zoom_level
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					new_zoom = minf(_zoom_level * ZOOM_STEP, ZOOM_MAX)
				else:
					new_zoom = maxf(_zoom_level / ZOOM_STEP, 1.0)
				_zoom_level = new_zoom
				# Keep the point under cursor stationary
				var view_range: float = 1.0 / _zoom_level
				var cursor_frac: float = mb.position.x / size.x
				_scroll_offset = clampf(time_at_cursor - cursor_frac * view_range, 0.0, maxf(0.0, 1.0 - view_range))
				queue_redraw()
				accept_event()
			elif _zoom_level > 1.0:
				# Wheel without Ctrl (when zoomed) = horizontal scroll
				var view_range: float = 1.0 / _zoom_level
				var scroll_amount: float = SCROLL_STEP * view_range
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					_scroll_offset = maxf(_scroll_offset - scroll_amount, 0.0)
				else:
					_scroll_offset = minf(_scroll_offset + scroll_amount, maxf(0.0, 1.0 - view_range))
				queue_redraw()
				accept_event()

	elif event is InputEventMouseMotion:
		if _ruler_dragging:
			var seek_time: float = _pos_to_time(event.position)
			seek_requested.emit(seek_time)
			accept_event()
			return
		_handle_mouse_motion(event.position)

	elif event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo:
			if key.keycode == KEY_SPACE:
				play_pause_requested.emit()
				accept_event()
				return
			elif key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE:
				if not _selected_indices.is_empty():
					# Remove in reverse order to preserve indices
					var sorted_desc: Array[int] = _selected_indices.duplicate()
					sorted_desc.sort()
					sorted_desc.reverse()
					for idx in sorted_desc:
						if idx >= 0 and idx < _fire_triggers.size():
							_fire_triggers.remove_at(idx)
					_selected_indices.clear()
					_marker_state = MarkerState.IDLE
					triggers_changed.emit(_fire_triggers.duplicate())
					queue_redraw()
					accept_event()
			elif key.keycode == KEY_HOME:
				_zoom_level = 1.0
				_scroll_offset = 0.0
				queue_redraw()
				accept_event()
			elif key.keycode == KEY_A and key.ctrl_pressed:
				# Ctrl+A — select all
				_selected_indices.clear()
				for i in _fire_triggers.size():
					_selected_indices.append(i)
				queue_redraw()
				accept_event()
			elif key.keycode == KEY_C and key.ctrl_pressed:
				# Ctrl+C — copy selected triggers as relative offsets
				if not _selected_indices.is_empty():
					var times: Array[float] = []
					for idx in _selected_indices:
						if idx >= 0 and idx < _fire_triggers.size():
							times.append(float(_fire_triggers[idx]))
					times.sort()
					var base: float = times[0]
					_clipboard.clear()
					for t in times:
						_clipboard.append(t - base)
				accept_event()
			elif key.keycode == KEY_V and key.ctrl_pressed:
				# Ctrl+V — paste clipboard at hover position
				if not _clipboard.is_empty() and _hovered_time >= 0.0:
					var paste_base: float = _snap_time(_hovered_time)
					var snap_threshold: float = _get_snap_threshold()
					var pasted_times: Array[float] = []
					for offset in _clipboard:
						var t: float = paste_base + offset
						if t < 0.0 or t > 1.0:
							continue
						# Skip if too close to existing trigger
						var too_close: bool = false
						for existing in _fire_triggers:
							if absf(float(existing) - t) < snap_threshold:
								too_close = true
								break
						# Also check against already-pasted triggers
						if not too_close:
							for pt in pasted_times:
								if absf(pt - t) < snap_threshold:
									too_close = true
									break
						if not too_close:
							pasted_times.append(t)
					if not pasted_times.is_empty():
						for t in pasted_times:
							_fire_triggers.append(t)
						_fire_triggers.sort()
						# Select the newly pasted markers
						_selected_indices.clear()
						for t in pasted_times:
							for i in _fire_triggers.size():
								if absf(float(_fire_triggers[i]) - t) < 0.0001 and not _is_selected(i):
									_selected_indices.append(i)
									break
						_selected_indices.sort()
						triggers_changed.emit(_fire_triggers.duplicate())
						queue_redraw()
				accept_event()
			elif key.keycode == KEY_ESCAPE:
				_clear_selection()
				_marker_state = MarkerState.IDLE
				queue_redraw()
				accept_event()


func _handle_left_down(pos: Vector2) -> void:
	grab_focus()
	var ctrl: bool = Input.is_key_pressed(KEY_CTRL)
	var hit_idx: int = _find_nearest_trigger_px(pos)
	_ctrl_click_pending_idx = -1
	if hit_idx >= 0:
		# Near a marker — prepare for potential drag
		_mouse_down = true
		_drag_start_pos = pos
		_hovered_idx = hit_idx
		if ctrl:
			if _is_selected(hit_idx):
				# Ctrl+click on selected: defer toggle to mouse-up (might drag)
				_ctrl_click_pending_idx = hit_idx
			else:
				# Ctrl+click on unselected: add to selection
				_toggle_selection(hit_idx)
		else:
			if not _is_selected(hit_idx):
				# Click on unselected without Ctrl: select only this one
				_select_only(hit_idx)
			# else: already selected, keep group (might drag)
		# Store original times for all selected markers
		_drag_original_times.clear()
		for idx in _selected_indices:
			_drag_original_times.append(float(_fire_triggers[idx]))
		_drag_anchor_idx = hit_idx
		queue_redraw()
	else:
		if not ctrl:
			# Empty space — deselect and place new trigger
			_clear_selection()
			_marker_state = MarkerState.IDLE
			_place_new_trigger(pos)
		else:
			# Ctrl+click empty space — just deselect
			_clear_selection()
			queue_redraw()


func _handle_left_up(pos: Vector2) -> void:
	if _marker_state == MarkerState.DRAGGING:
		# Finalize drag: collect current times of selected, sort triggers, rebuild selection
		var selected_times: Array[float] = []
		for idx in _selected_indices:
			if idx >= 0 and idx < _fire_triggers.size():
				selected_times.append(float(_fire_triggers[idx]))
		_fire_triggers.sort()
		# Rebuild selected indices by matching time values
		_selected_indices.clear()
		for st in selected_times:
			for i in _fire_triggers.size():
				if absf(float(_fire_triggers[i]) - st) < 0.0001 and not _is_selected(i):
					_selected_indices.append(i)
					break
		_selected_indices.sort()
		_marker_state = MarkerState.IDLE
		_mouse_down = false
		triggers_changed.emit(_fire_triggers.duplicate())
		queue_redraw()
	elif _mouse_down:
		# Was a click (no drag)
		var ctrl: bool = Input.is_key_pressed(KEY_CTRL)
		if _ctrl_click_pending_idx >= 0:
			# Ctrl+click on already-selected: toggle off now
			_toggle_selection(_ctrl_click_pending_idx)
		elif not ctrl:
			# Plain click: select only the clicked marker
			_select_only(_hovered_idx)
		_ctrl_click_pending_idx = -1
		_marker_state = MarkerState.IDLE
		_mouse_down = false
		queue_redraw()
	else:
		_mouse_down = false


func _handle_mouse_motion(pos: Vector2) -> void:
	_hovered_time = _pos_to_time(pos)

	if _mouse_down and _marker_state != MarkerState.DRAGGING:
		# Check if we should start dragging
		if pos.distance_to(_drag_start_pos) > DRAG_THRESHOLD_PX:
			_marker_state = MarkerState.DRAGGING
			# Cancel any pending Ctrl toggle since we're dragging
			_ctrl_click_pending_idx = -1
			queue_redraw()
			return

	if _marker_state == MarkerState.DRAGGING:
		# Group drag: move all selected by the same delta
		if not _selected_indices.is_empty() and _drag_anchor_idx >= 0:
			var anchor_pos_in_sel: int = _selected_indices.find(_drag_anchor_idx)
			if anchor_pos_in_sel >= 0 and anchor_pos_in_sel < _drag_original_times.size():
				var anchor_original: float = _drag_original_times[anchor_pos_in_sel]
				var current_mouse_time: float = _snap_time(_pos_to_time(pos))
				var delta: float = current_mouse_time - _snap_time(anchor_original)
				# Clamp delta so no marker leaves 0.0–1.0
				var min_orig: float = 1.0
				var max_orig: float = 0.0
				for ot in _drag_original_times:
					min_orig = minf(min_orig, ot)
					max_orig = maxf(max_orig, ot)
				delta = clampf(delta, -min_orig, 1.0 - max_orig)
				# Apply delta to all selected
				for si in _selected_indices.size():
					var idx: int = _selected_indices[si]
					if idx >= 0 and idx < _fire_triggers.size() and si < _drag_original_times.size():
						_fire_triggers[idx] = clampf(_drag_original_times[si] + delta, 0.0, 1.0)
				queue_redraw()
		return

	# Not dragging — update hover state
	_hovered_idx = _find_nearest_trigger_px(pos)
	if _hovered_idx >= 0:
		_marker_state = MarkerState.HOVERING
	elif not _mouse_down:
		_marker_state = MarkerState.IDLE
	queue_redraw()


func _handle_right_click(pos: Vector2) -> void:
	# Remove nearest trigger within hit range
	var hit_idx: int = _find_nearest_trigger_px(pos)
	if hit_idx >= 0:
		# Update selection: remove if selected, adjust indices > deleted
		var new_selected: Array[int] = []
		for si in _selected_indices:
			if si == hit_idx:
				continue  # Remove from selection
			elif si > hit_idx:
				new_selected.append(si - 1)  # Shift down
			else:
				new_selected.append(si)
		_selected_indices = new_selected
		_fire_triggers.remove_at(hit_idx)
		_hovered_idx = -1
		_marker_state = MarkerState.IDLE
		triggers_changed.emit(_fire_triggers.duplicate())
		queue_redraw()


func _pos_to_time(pos: Vector2) -> float:
	## Convert pixel position to normalized time (0.0–1.0), accounting for zoom/scroll
	var view_range: float = 1.0 / _zoom_level
	return clampf(_scroll_offset + (pos.x / size.x) * view_range, 0.0, 1.0)


func _time_to_x(t: float) -> float:
	## Convert normalized time (0.0–1.0) to pixel X, accounting for zoom/scroll
	var view_range: float = 1.0 / _zoom_level
	return (t - _scroll_offset) / view_range * size.x


func _snap_time(t: float) -> float:
	## Snap normalized time to beat subdivision, or return as-is for Free mode
	if _snap_mode == 0:
		return t
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return t
	var snap_beats: float = 4.0 / float(_snap_mode)
	return roundf(t * total_beats / snap_beats) * snap_beats / total_beats


func _get_snap_threshold() -> float:
	## Minimum distance in normalized time to distinguish triggers
	if _snap_mode == 0:
		# Free mode: use a small pixel-based threshold (account for zoom)
		if size.x > 0.0:
			return 8.0 / (size.x * _zoom_level)
		return 0.02
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return 0.02
	var snap_beats: float = 4.0 / float(_snap_mode)
	return (snap_beats / total_beats) * 0.5


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)

	# Ruler bar at top
	_draw_ruler()

	# Waveform
	_draw_waveform()

	# Beat grid overlay (optional)
	if _show_beat_grid:
		_draw_beat_grid()

	# Hover indicator (hide during drag — the marker itself is feedback)
	if _hovered_time >= 0.0 and _marker_state != MarkerState.DRAGGING:
		var snapped: float = _snap_time(_hovered_time)
		var hx: float = _time_to_x(snapped)
		draw_line(Vector2(hx, RULER_HEIGHT), Vector2(hx, size.y), _hover_color, 2.0)

	# Fire trigger markers (skip off-screen)
	var view_range: float = 1.0 / _zoom_level
	var view_end: float = _scroll_offset + view_range
	for i in _fire_triggers.size():
		var trigger_time: float = float(_fire_triggers[i])
		if trigger_time < _scroll_offset - 0.01 or trigger_time > view_end + 0.01:
			continue
		var tx: float = _time_to_x(trigger_time)

		# Determine color and style based on state
		var color: Color = _trigger_color
		if _marker_color_callback.is_valid():
			color = _marker_color_callback.call(i)
		var line_width: float = 3.0
		var tri_size: float = 6.0

		if _is_selected(i):
			color = _selected_color
			line_width = 4.0
			tri_size = 8.0
		elif i == _hovered_idx and _marker_state == MarkerState.HOVERING:
			color = _hovered_marker_color

		# Vertical line
		draw_line(Vector2(tx, RULER_HEIGHT), Vector2(tx, size.y), color, line_width)

		# Triangle marker at top
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(tx - tri_size, RULER_HEIGHT),
			Vector2(tx + tri_size, RULER_HEIGHT),
			Vector2(tx, RULER_HEIGHT + tri_size * 1.667),
		])
		draw_colored_polygon(tri, color)

		# Glow circle for selected markers
		if _is_selected(i):
			draw_circle(Vector2(tx, RULER_HEIGHT + tri_size * 1.667 + 4.0), 4.0, Color(_selected_color, 0.4))

	# Playback cursor
	if _show_cursor and _cursor_progress >= 0.0:
		var cx: float = _time_to_x(_cursor_progress)
		if cx >= -2.0 and cx <= size.x + 2.0:
			draw_line(Vector2(cx, RULER_HEIGHT), Vector2(cx, size.y), _cursor_color, 2.0)

	# Viewport indicator bar (only when zoomed)
	if _zoom_level > 1.0:
		_draw_viewport_bar()


func _draw_beat_grid() -> void:
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return
	var view_range: float = 1.0 / _zoom_level
	var view_end: float = _scroll_offset + view_range
	# Draw grid lines at beat subdivisions — only visible ones
	var snap_beats: float = 4.0 / float(maxi(_snap_mode, 4))
	# Start from the first beat at or before the visible range
	var first_beat: float = floorf(_scroll_offset * total_beats / snap_beats) * snap_beats
	var beat: float = maxf(first_beat, 0.0)
	while beat < total_beats:
		var t: float = beat / total_beats
		if t > view_end:
			break
		var x: float = _time_to_x(t)
		var is_bar: bool = fmod(beat, float(_beats_per_bar)) < 0.01
		var is_beat: bool = fmod(beat, 1.0) < 0.01
		if is_bar:
			draw_line(Vector2(x, RULER_HEIGHT), Vector2(x, size.y), _bar_line_color, 2.0)
		elif is_beat:
			draw_line(Vector2(x, RULER_HEIGHT), Vector2(x, size.y), _grid_color, 1.0)
		else:
			draw_line(Vector2(x, RULER_HEIGHT), Vector2(x, size.y), Color(_grid_color, 0.3), 1.0)
		beat += snap_beats


func _draw_waveform() -> void:
	if _waveform_data.is_empty():
		return
	var waveform_height: float = size.y - RULER_HEIGHT
	var mid_y: float = RULER_HEIGHT + waveform_height * 0.5
	var amp: float = waveform_height * 0.45
	var sample_count: int = _waveform_data.size()
	var view_range: float = 1.0 / _zoom_level
	# Only draw bins that fall within the visible range
	var first_bin: int = maxi(int(_scroll_offset * sample_count) - 1, 0)
	var last_bin: int = mini(int((_scroll_offset + view_range) * sample_count) + 1, sample_count - 1)
	for i in range(first_bin, last_bin + 1):
		var t: float = float(i) / float(sample_count)
		var x: float = _time_to_x(t)
		var next_t: float = float(i + 1) / float(sample_count)
		var bar_w: float = maxf(_time_to_x(next_t) - x, 1.0)
		var h: float = _waveform_data[i] * amp
		var top: float = mid_y - h
		var bottom: float = mid_y + h
		draw_rect(Rect2(x, top, bar_w, bottom - top), _waveform_color)


func _draw_ruler() -> void:
	# Ruler background (slightly lighter than waveform bg)
	draw_rect(Rect2(0, 0, size.x, RULER_HEIGHT), Color(0.08, 0.08, 0.14))
	# Bottom edge line
	draw_line(Vector2(0, RULER_HEIGHT), Vector2(size.x, RULER_HEIGHT), Color(0.25, 0.25, 0.4), 1.0)

	# Beat tick marks and bar numbers
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return
	var view_range: float = 1.0 / _zoom_level
	var view_end: float = _scroll_offset + view_range

	# Draw ticks at beat level (or finer if zoomed enough)
	var tick_beats: float = 1.0
	if _zoom_level >= 4.0:
		tick_beats = 0.5

	var first_beat: float = floorf(_scroll_offset * total_beats / tick_beats) * tick_beats
	var beat: float = maxf(first_beat, 0.0)
	while beat < total_beats:
		var t: float = beat / total_beats
		if t > view_end:
			break
		var x: float = _time_to_x(t)
		var is_bar: bool = fmod(beat, float(_beats_per_bar)) < 0.01
		var is_beat: bool = fmod(beat, 1.0) < 0.01

		if is_bar:
			draw_line(Vector2(x, 4), Vector2(x, RULER_HEIGHT - 2), Color(0.5, 0.5, 0.7), 2.0)
			var bar_num: int = int(beat / float(_beats_per_bar)) + 1
			var rp_font: Font = ThemeManager.get_font("body")
			if rp_font:
				draw_string(rp_font, Vector2(x + 3, 13), str(bar_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.8))
		elif is_beat:
			draw_line(Vector2(x, 8), Vector2(x, RULER_HEIGHT - 2), Color(0.3, 0.3, 0.5), 1.0)
		else:
			draw_line(Vector2(x, 12), Vector2(x, RULER_HEIGHT - 2), Color(0.2, 0.2, 0.35), 1.0)
		beat += tick_beats

	# Playhead indicator in ruler
	if _show_cursor and _cursor_progress >= 0.0:
		var cx: float = _time_to_x(_cursor_progress)
		if cx >= -2.0 and cx <= size.x + 2.0:
			var tri: PackedVector2Array = PackedVector2Array([
				Vector2(cx - 5, 0),
				Vector2(cx + 5, 0),
				Vector2(cx, 8),
			])
			draw_colored_polygon(tri, _cursor_color)


func _draw_viewport_bar() -> void:
	## Draw a small indicator bar at the bottom showing current viewport within the full loop.
	var bar_y: float = size.y - VIEWPORT_BAR_HEIGHT
	# Track background
	draw_rect(Rect2(0, bar_y, size.x, VIEWPORT_BAR_HEIGHT), Color(0.15, 0.15, 0.25, 0.8))
	# Viewport thumb
	var view_range: float = 1.0 / _zoom_level
	var thumb_x: float = _scroll_offset * size.x
	var thumb_w: float = view_range * size.x
	draw_rect(Rect2(thumb_x, bar_y, thumb_w, VIEWPORT_BAR_HEIGHT), Color(0.5, 0.7, 1.0, 0.6))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered_time = -1.0
		_hovered_idx = -1
		if _marker_state == MarkerState.DRAGGING:
			# Cancel drag — restore all original times
			for si in _selected_indices.size():
				var idx: int = _selected_indices[si]
				if idx >= 0 and idx < _fire_triggers.size() and si < _drag_original_times.size():
					_fire_triggers[idx] = _drag_original_times[si]
			_mouse_down = false
			_marker_state = MarkerState.IDLE
		elif _marker_state == MarkerState.HOVERING:
			_marker_state = MarkerState.IDLE
		queue_redraw()
