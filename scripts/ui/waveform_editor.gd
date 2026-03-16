class_name WaveformEditor
extends Control
## Visual waveform editor: displays WAV waveform, beat grid overlay, click-to-place fire triggers.
## Snap-to-subdivision support. Playback cursor synced to BeatClock.

signal triggers_changed(triggers: Array)

var _stream: AudioStream = null
var _waveform_data: PackedFloat32Array = PackedFloat32Array()
var _loop_length_bars: int = 2
var _fire_triggers: Array = []  # Array[float] — beat positions
var _snap_subdivision: int = 4  # 1/4 note snap by default
var _beats_per_bar: int = 4
var _hovered_beat: float = -1.0
var _cursor_beat_pos: float = -1.0
var _show_cursor: bool = false

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
	BeatClock.position_updated.connect(_on_position_updated)


func set_stream(stream: AudioStream) -> void:
	_stream = stream
	_generate_waveform_data()
	queue_redraw()


func set_loop_length_bars(bars: int) -> void:
	_loop_length_bars = bars
	queue_redraw()


func set_snap_subdivision(subdiv: int) -> void:
	_snap_subdivision = subdiv


func set_triggers(triggers: Array) -> void:
	_fire_triggers = triggers.duplicate()
	queue_redraw()


func get_triggers() -> Array:
	return _fire_triggers.duplicate()


func set_show_cursor(show: bool) -> void:
	_show_cursor = show
	queue_redraw()


func _on_position_updated(_beat_pos: float, _bar: int) -> void:
	if not _show_cursor:
		return
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	_cursor_beat_pos = BeatClock.get_loop_beat_position(total_beats)
	queue_redraw()


func _generate_waveform_data() -> void:
	_waveform_data.clear()
	# Generate a simplified waveform representation (256 samples)
	# In a real implementation, you'd read the actual PCM data from the stream
	# For now, generate a visual approximation
	var sample_count: int = 256
	_waveform_data.resize(sample_count)
	if _stream:
		# Use a seeded random based on stream resource path for consistent visuals
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(_stream.resource_path)
		for i in sample_count:
			var t: float = float(i) / float(sample_count)
			# Generate plausible waveform shape
			var base: float = sin(t * TAU * 4.0) * 0.3
			var detail: float = rng.randf_range(-0.4, 0.4)
			var envelope: float = 1.0 - abs(t - 0.5) * 0.5
			_waveform_data[i] = clampf((base + detail) * envelope, -1.0, 1.0)
	else:
		_waveform_data.fill(0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(mb.position)
	elif event is InputEventMouseMotion:
		_hovered_beat = _pos_to_beat(event.position)
		queue_redraw()


func _handle_click(pos: Vector2) -> void:
	var beat: float = _pos_to_beat(pos)
	beat = _snap_beat(beat)
	# Toggle: if trigger exists near this beat, remove it; otherwise add it
	var removed: bool = false
	var snap_threshold: float = _get_snap_size() * 0.5
	for i in range(_fire_triggers.size() - 1, -1, -1):
		if absf(float(_fire_triggers[i]) - beat) < snap_threshold:
			_fire_triggers.remove_at(i)
			removed = true
			break
	if not removed:
		_fire_triggers.append(beat)
		_fire_triggers.sort()
	triggers_changed.emit(_fire_triggers.duplicate())
	queue_redraw()


func _handle_right_click(pos: Vector2) -> void:
	# Remove nearest trigger
	var beat: float = _pos_to_beat(pos)
	var snap_threshold: float = _get_snap_size()
	var best_idx: int = -1
	var best_dist: float = snap_threshold
	for i in _fire_triggers.size():
		var dist: float = absf(float(_fire_triggers[i]) - beat)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	if best_idx >= 0:
		_fire_triggers.remove_at(best_idx)
		triggers_changed.emit(_fire_triggers.duplicate())
		queue_redraw()


func _pos_to_beat(pos: Vector2) -> float:
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	return (pos.x / size.x) * total_beats


func _beat_to_x(beat: float) -> float:
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	return (beat / total_beats) * size.x


func _snap_beat(beat: float) -> float:
	var snap_size: float = _get_snap_size()
	return roundf(beat / snap_size) * snap_size


func _get_snap_size() -> float:
	# snap_subdivision: 4 = quarter note (1 beat), 8 = eighth (0.5), 16 = sixteenth (0.25)
	return 4.0 / float(_snap_subdivision)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)

	var total_beats: float = float(_loop_length_bars * _beats_per_bar)

	# Waveform
	_draw_waveform()

	# Beat grid lines
	var snap_size: float = _get_snap_size()
	var grid_beat: float = 0.0
	while grid_beat < total_beats:
		var x: float = _beat_to_x(grid_beat)
		var is_bar: bool = fmod(grid_beat, float(_beats_per_bar)) < 0.01
		var is_beat: bool = fmod(grid_beat, 1.0) < 0.01
		if is_bar:
			draw_line(Vector2(x, 0), Vector2(x, size.y), _bar_line_color, 2.0)
		elif is_beat:
			draw_line(Vector2(x, 0), Vector2(x, size.y), _grid_color, 1.0)
		else:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(_grid_color, 0.3), 1.0)
		grid_beat += snap_size

	# Hover indicator
	if _hovered_beat >= 0.0:
		var snapped: float = _snap_beat(_hovered_beat)
		var hx: float = _beat_to_x(snapped)
		draw_line(Vector2(hx, 0), Vector2(hx, size.y), _hover_color, 2.0)

	# Fire trigger markers
	for trigger in _fire_triggers:
		var tx: float = _beat_to_x(float(trigger))
		draw_line(Vector2(tx, 0), Vector2(tx, size.y), _trigger_color, 3.0)
		# Triangle marker at top
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(tx - 6, 0),
			Vector2(tx + 6, 0),
			Vector2(tx, 10),
		])
		draw_colored_polygon(tri, _trigger_color)

	# Playback cursor
	if _show_cursor and _cursor_beat_pos >= 0.0:
		var cx: float = _beat_to_x(_cursor_beat_pos)
		draw_line(Vector2(cx, 0), Vector2(cx, size.y), _cursor_color, 2.0)


func _draw_waveform() -> void:
	if _waveform_data.is_empty():
		return
	var mid_y: float = size.y * 0.5
	var amp: float = size.y * 0.35
	var sample_count: int = _waveform_data.size()
	for i in range(sample_count - 1):
		var x0: float = (float(i) / float(sample_count)) * size.x
		var x1: float = (float(i + 1) / float(sample_count)) * size.x
		var y0: float = mid_y - _waveform_data[i] * amp
		var y1: float = mid_y - _waveform_data[i + 1] * amp
		draw_line(Vector2(x0, y0), Vector2(x1, y1), _waveform_color, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered_beat = -1.0
		queue_redraw()
