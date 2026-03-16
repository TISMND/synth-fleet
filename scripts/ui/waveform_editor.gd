class_name WaveformEditor
extends Control
## Visual waveform editor: displays WAV waveform, optional beat grid overlay,
## click-to-place fire triggers in normalized time (0.0–1.0).
## Snap modes: Free, 1/4, 1/8, 1/16. Playback cursor synced to LoopMixer.

signal triggers_changed(triggers: Array)

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

# Colors
var _bg_color: Color = Color(0.05, 0.05, 0.1)
var _waveform_color: Color = Color(0.2, 0.6, 0.9, 0.6)
var _grid_color: Color = Color(0.2, 0.2, 0.3)
var _bar_line_color: Color = Color(0.4, 0.4, 0.6)
var _trigger_color: Color = Color(1.0, 0.3, 0.3)
var _cursor_color: Color = Color(0.3, 1.0, 0.5, 0.8)
var _hover_color: Color = Color(1.0, 1.0, 1.0, 0.3)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 120)


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
	var bytes_per_sample: int = bits_per_sample / 8
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
	var bpm: float = BeatClock.bpm
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(mb.position)
	elif event is InputEventMouseMotion:
		_hovered_time = _pos_to_time(event.position)
		queue_redraw()


func _handle_click(pos: Vector2) -> void:
	var t: float = _pos_to_time(pos)
	t = _snap_time(t)
	# Toggle: if trigger exists near this time, remove it; otherwise add it
	var removed: bool = false
	var snap_threshold: float = _get_snap_threshold()
	for i in range(_fire_triggers.size() - 1, -1, -1):
		if absf(float(_fire_triggers[i]) - t) < snap_threshold:
			_fire_triggers.remove_at(i)
			removed = true
			break
	if not removed:
		_fire_triggers.append(t)
		_fire_triggers.sort()
	triggers_changed.emit(_fire_triggers.duplicate())
	queue_redraw()


func _handle_right_click(pos: Vector2) -> void:
	# Remove nearest trigger
	var t: float = _pos_to_time(pos)
	var snap_threshold: float = _get_snap_threshold() * 2.0
	var best_idx: int = -1
	var best_dist: float = snap_threshold
	for i in _fire_triggers.size():
		var dist: float = absf(float(_fire_triggers[i]) - t)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	if best_idx >= 0:
		_fire_triggers.remove_at(best_idx)
		triggers_changed.emit(_fire_triggers.duplicate())
		queue_redraw()


func _pos_to_time(pos: Vector2) -> float:
	## Convert pixel position to normalized time (0.0–1.0)
	return clampf(pos.x / size.x, 0.0, 1.0)


func _time_to_x(t: float) -> float:
	## Convert normalized time (0.0–1.0) to pixel X
	return t * size.x


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
		# Free mode: use a small pixel-based threshold
		if size.x > 0.0:
			return 8.0 / size.x
		return 0.02
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return 0.02
	var snap_beats: float = 4.0 / float(_snap_mode)
	return (snap_beats / total_beats) * 0.5


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)

	# Waveform
	_draw_waveform()

	# Beat grid overlay (optional)
	if _show_beat_grid:
		_draw_beat_grid()

	# Hover indicator
	if _hovered_time >= 0.0:
		var snapped: float = _snap_time(_hovered_time)
		var hx: float = _time_to_x(snapped)
		draw_line(Vector2(hx, 0), Vector2(hx, size.y), _hover_color, 2.0)

	# Fire trigger markers
	for trigger in _fire_triggers:
		var tx: float = _time_to_x(float(trigger))
		draw_line(Vector2(tx, 0), Vector2(tx, size.y), _trigger_color, 3.0)
		# Triangle marker at top
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(tx - 6, 0),
			Vector2(tx + 6, 0),
			Vector2(tx, 10),
		])
		draw_colored_polygon(tri, _trigger_color)

	# Playback cursor
	if _show_cursor and _cursor_progress >= 0.0:
		var cx: float = _time_to_x(_cursor_progress)
		draw_line(Vector2(cx, 0), Vector2(cx, size.y), _cursor_color, 2.0)


func _draw_beat_grid() -> void:
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return
	# Draw grid lines at beat subdivisions
	var snap_beats: float = 4.0 / float(maxi(_snap_mode, 4))
	var beat: float = 0.0
	while beat < total_beats:
		var t: float = beat / total_beats
		var x: float = _time_to_x(t)
		var is_bar: bool = fmod(beat, float(_beats_per_bar)) < 0.01
		var is_beat: bool = fmod(beat, 1.0) < 0.01
		if is_bar:
			draw_line(Vector2(x, 0), Vector2(x, size.y), _bar_line_color, 2.0)
		elif is_beat:
			draw_line(Vector2(x, 0), Vector2(x, size.y), _grid_color, 1.0)
		else:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(_grid_color, 0.3), 1.0)
		beat += snap_beats


func _draw_waveform() -> void:
	if _waveform_data.is_empty():
		return
	var mid_y: float = size.y * 0.5
	var amp: float = size.y * 0.45
	var sample_count: int = _waveform_data.size()
	# Draw as mirrored filled bars for a bold waveform display
	for i in sample_count:
		var x: float = (float(i) / float(sample_count)) * size.x
		var bar_w: float = maxf(size.x / float(sample_count), 1.0)
		var h: float = _waveform_data[i] * amp
		var top: float = mid_y - h
		var bottom: float = mid_y + h
		draw_rect(Rect2(x, top, bar_w, bottom - top), _waveform_color)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered_time = -1.0
		queue_redraw()
