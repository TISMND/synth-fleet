class_name BarEffectLane
extends Control
## Simple bottom lane for placing bar effect markers at beat positions.
## Single lane, single type (set by parent), same snap/zoom as waveform above.

signal triggers_changed(triggers: Array)

const LANE_HEIGHT: float = 40.0
const MARKER_HIT_PX: float = 12.0

var _triggers: Array = []  # Array of {time: float, type: String, value: float}
var _waveform_ref: WaveformEditor = null
var _snap_mode: int = 0
var _loop_length_bars: int = 2
var _beats_per_bar: int = 4
var _lane_type: String = "thermal"  # What type of marker this lane places
var _lane_color: Color = Color(1.0, 0.5, 0.2)
var _lane_label: String = "THERMAL"
var _default_value: float = 5.0
var _hovered_idx: int = -1
var _hovered_time: float = -1.0
var _selected_indices: Array[int] = []
var _bg_color: Color = Color(0.04, 0.04, 0.08)
var _hover_color: Color = Color(1.0, 1.0, 1.0, 0.3)
var _selected_color: Color = Color(1.0, 0.85, 0.2)

# Drag state
enum MarkerState { IDLE, HOVERING, DRAGGING }
var _marker_state: int = MarkerState.IDLE
var _mouse_down: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_original_times: Array[float] = []
var _drag_anchor_idx: int = -1
const DRAG_THRESHOLD_PX: float = 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, LANE_HEIGHT)
	focus_mode = Control.FOCUS_ALL


func setup(type_key: String, label: String, color: Color, default_val: float) -> void:
	_lane_type = type_key
	_lane_label = label
	_lane_color = color
	_default_value = default_val
	queue_redraw()


func set_waveform_ref(wf: WaveformEditor) -> void:
	_waveform_ref = wf


func set_snap_mode(mode: int) -> void:
	_snap_mode = mode


func set_loop_length_bars(bars: int) -> void:
	_loop_length_bars = bars


func set_default_value(val: float) -> void:
	_default_value = val


func set_triggers(trigs: Array) -> void:
	_triggers = trigs.duplicate(true)
	_selected_indices.clear()
	queue_redraw()


func get_triggers() -> Array:
	return _triggers.duplicate(true)


func clear_triggers() -> void:
	_triggers.clear()
	_selected_indices.clear()
	queue_redraw()
	triggers_changed.emit(_triggers.duplicate(true))


func update_selected_value(new_value: float) -> void:
	for idx in _selected_indices:
		if idx >= 0 and idx < _triggers.size():
			var trig: Dictionary = _triggers[idx] as Dictionary
			trig["value"] = new_value
	triggers_changed.emit(_triggers.duplicate(true))
	queue_redraw()


func _get_zoom() -> float:
	if _waveform_ref:
		return _waveform_ref._zoom_level
	return 1.0


func _get_scroll() -> float:
	if _waveform_ref:
		return _waveform_ref._scroll_offset
	return 0.0


func _time_to_x(t: float) -> float:
	var view_range: float = 1.0 / _get_zoom()
	return (t - _get_scroll()) / view_range * size.x


func _pos_to_time(pos: Vector2) -> float:
	var view_range: float = 1.0 / _get_zoom()
	return clampf(_get_scroll() + (pos.x / size.x) * view_range, 0.0, 1.0)


func _snap_time(t: float) -> float:
	if _snap_mode == 0:
		return t
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return t
	var snap_beats: float = 4.0 / float(_snap_mode)
	return roundf(t * total_beats / snap_beats) * snap_beats / total_beats


func _get_snap_threshold() -> float:
	if _snap_mode == 0:
		if size.x > 0.0:
			return 8.0 / (size.x * _get_zoom())
		return 0.02
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return 0.02
	var snap_beats: float = 4.0 / float(_snap_mode)
	return (snap_beats / total_beats) * 0.5


func _is_selected(idx: int) -> bool:
	return _selected_indices.has(idx)


func _find_nearest_marker(pos: Vector2) -> int:
	var best_idx: int = -1
	var best_dist: float = MARKER_HIT_PX
	for i in _triggers.size():
		var trig: Dictionary = _triggers[i] as Dictionary
		var tx: float = _time_to_x(float(trig.get("time", 0.0)))
		var dx: float = absf(pos.x - tx)
		if dx < best_dist:
			best_dist = dx
			best_idx = i
	return best_idx


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_press(mb.position, mb.ctrl_pressed)
			else:
				_on_left_release()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_handle_right_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _waveform_ref:
				_waveform_ref._gui_input(event)
				queue_redraw()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_hovered_time = _pos_to_time(mm.position)
		if _marker_state == MarkerState.DRAGGING:
			_handle_drag(mm.position)
		else:
			var nearest: int = _find_nearest_marker(mm.position)
			if nearest != _hovered_idx:
				_hovered_idx = nearest
				_marker_state = MarkerState.HOVERING if nearest >= 0 else MarkerState.IDLE
		queue_redraw()

	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed:
			if ke.keycode == KEY_DELETE or ke.keycode == KEY_BACKSPACE:
				_delete_selected()
			elif ke.keycode == KEY_ESCAPE:
				_selected_indices.clear()
				queue_redraw()
			elif ke.keycode == KEY_A and ke.ctrl_pressed:
				_selected_indices.clear()
				for i in _triggers.size():
					_selected_indices.append(i)
				queue_redraw()


func _on_left_press(pos: Vector2, ctrl: bool) -> void:
	_mouse_down = true
	_drag_start_pos = pos
	var nearest: int = _find_nearest_marker(pos)
	if nearest >= 0:
		if ctrl:
			if _is_selected(nearest):
				_selected_indices.erase(nearest)
			else:
				_selected_indices.append(nearest)
				_selected_indices.sort()
		else:
			if not _is_selected(nearest):
				_selected_indices = [nearest]
		_hovered_idx = nearest
		_marker_state = MarkerState.HOVERING
		_drag_anchor_idx = _selected_indices.find(nearest)
		_drag_original_times.clear()
		for idx in _selected_indices:
			var trig: Dictionary = _triggers[idx] as Dictionary
			_drag_original_times.append(float(trig.get("time", 0.0)))
		queue_redraw()
	else:
		if not ctrl:
			_selected_indices.clear()
		_place_new_trigger(pos)


func _on_left_release() -> void:
	_mouse_down = false
	if _marker_state == MarkerState.DRAGGING:
		_marker_state = MarkerState.IDLE
		triggers_changed.emit(_triggers.duplicate(true))
	queue_redraw()


func _handle_drag(pos: Vector2) -> void:
	if not _mouse_down or _selected_indices.is_empty():
		return
	if _marker_state != MarkerState.DRAGGING:
		if pos.distance_to(_drag_start_pos) < DRAG_THRESHOLD_PX:
			return
		_marker_state = MarkerState.DRAGGING

	var anchor_sel_idx: int = _drag_anchor_idx
	if anchor_sel_idx < 0 or anchor_sel_idx >= _selected_indices.size():
		return
	var anchor_orig: float = _drag_original_times[anchor_sel_idx]
	var current_time: float = _snap_time(_pos_to_time(pos))
	var delta_t: float = current_time - anchor_orig
	for si in _selected_indices.size():
		var orig: float = _drag_original_times[si]
		if orig + delta_t < 0.0:
			delta_t = -orig
		if orig + delta_t > 1.0:
			delta_t = 1.0 - orig
	for si in _selected_indices.size():
		var idx: int = _selected_indices[si]
		var trig: Dictionary = _triggers[idx] as Dictionary
		trig["time"] = _drag_original_times[si] + delta_t
	queue_redraw()


func _handle_right_click(pos: Vector2) -> void:
	var nearest: int = _find_nearest_marker(pos)
	if nearest >= 0:
		_triggers.remove_at(nearest)
		var new_sel: Array[int] = []
		for si in _selected_indices:
			if si < nearest:
				new_sel.append(si)
			elif si > nearest:
				new_sel.append(si - 1)
		_selected_indices = new_sel
		_hovered_idx = -1
		queue_redraw()
		triggers_changed.emit(_triggers.duplicate(true))


func _place_new_trigger(pos: Vector2) -> void:
	var t: float = _snap_time(_pos_to_time(pos))
	var threshold: float = _get_snap_threshold()
	for trig in _triggers:
		var existing: Dictionary = trig as Dictionary
		if absf(float(existing.get("time", 0.0)) - t) < threshold:
			return
	var new_trig: Dictionary = {
		"time": t,
		"type": _lane_type,
		"value": _default_value,
	}
	_triggers.append(new_trig)
	_sort_triggers()
	var new_idx: int = -1
	for i in _triggers.size():
		var check: Dictionary = _triggers[i] as Dictionary
		if absf(float(check.get("time", -1.0)) - t) < 0.001:
			new_idx = i
			break
	if new_idx >= 0:
		_selected_indices = [new_idx]
	queue_redraw()
	triggers_changed.emit(_triggers.duplicate(true))


func _sort_triggers() -> void:
	_triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)


func _delete_selected() -> void:
	if _selected_indices.is_empty():
		return
	var sorted_desc: Array[int] = _selected_indices.duplicate()
	sorted_desc.sort()
	sorted_desc.reverse()
	for idx in sorted_desc:
		if idx >= 0 and idx < _triggers.size():
			_triggers.remove_at(idx)
	_selected_indices.clear()
	queue_redraw()
	triggers_changed.emit(_triggers.duplicate(true))


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)

	# Top separator
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(0.25, 0.25, 0.4), 1.0)

	# Lane label on left
	var font: Font = ThemeManager.get_font("body")
	if font:
		draw_string(font, Vector2(4, size.y * 0.5 + 4), _lane_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(_lane_color, 0.6))

	# Beat grid
	_draw_beat_grid()

	# Hover indicator
	if _hovered_time >= 0.0 and _marker_state != MarkerState.DRAGGING:
		var snapped: float = _snap_time(_hovered_time)
		var hx: float = _time_to_x(snapped)
		draw_line(Vector2(hx, 2), Vector2(hx, size.y - 2), _hover_color, 2.0)

	# Markers
	var mid_y: float = size.y * 0.5
	var view_range: float = 1.0 / _get_zoom()
	var view_end: float = _get_scroll() + view_range
	for i in _triggers.size():
		var trig: Dictionary = _triggers[i] as Dictionary
		var t: float = float(trig.get("time", 0.0))
		if t < _get_scroll() - 0.01 or t > view_end + 0.01:
			continue
		var tx: float = _time_to_x(t)
		var color: Color = _lane_color
		var marker_w: float = 3.0
		var tri_size: float = 6.0

		if _is_selected(i):
			color = _selected_color
			marker_w = 4.0
			tri_size = 8.0
		elif i == _hovered_idx and _marker_state == MarkerState.HOVERING:
			color = color.lightened(0.3)

		# Vertical line
		draw_line(Vector2(tx, 2), Vector2(tx, size.y - 2), color, marker_w)

		# Triangle marker at top (pointing down)
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(tx - tri_size, 2),
			Vector2(tx + tri_size, 2),
			Vector2(tx, 2 + tri_size * 1.5),
		])
		draw_colored_polygon(tri, color)

		# Value text for selected markers
		if _is_selected(i) and font:
			var val: float = float(trig.get("value", 0.0))
			var val_text: String = "%+.1f" % val
			draw_string(font, Vector2(tx + 6, size.y - 4), val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _selected_color)

	# Playback cursor
	if _waveform_ref and _waveform_ref._show_cursor and _waveform_ref._cursor_progress >= 0.0:
		var cx: float = _time_to_x(_waveform_ref._cursor_progress)
		if cx >= -2.0 and cx <= size.x + 2.0:
			draw_line(Vector2(cx, 0), Vector2(cx, size.y), Color(0.3, 1.0, 0.5, 0.5), 1.0)


func _draw_beat_grid() -> void:
	var total_beats: float = float(_loop_length_bars * _beats_per_bar)
	if total_beats <= 0.0:
		return
	var view_range: float = 1.0 / _get_zoom()
	var view_end: float = _get_scroll() + view_range
	var snap_beats: float = 4.0 / float(maxi(_snap_mode, 4))
	var first_beat: float = floorf(_get_scroll() * total_beats / snap_beats) * snap_beats
	var beat: float = maxf(first_beat, 0.0)
	while beat < total_beats:
		var t: float = beat / total_beats
		if t > view_end:
			break
		var x: float = _time_to_x(t)
		var is_bar: bool = fmod(beat, float(_beats_per_bar)) < 0.01
		var is_beat: bool = fmod(beat, 1.0) < 0.01
		if is_bar:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.2, 0.35), 1.0)
		elif is_beat:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.1, 0.1, 0.18), 1.0)
		beat += snap_beats


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered_time = -1.0
		_hovered_idx = -1
		if _marker_state == MarkerState.DRAGGING:
			for si in _selected_indices.size():
				var idx: int = _selected_indices[si]
				if idx >= 0 and idx < _triggers.size() and si < _drag_original_times.size():
					var trig: Dictionary = _triggers[idx] as Dictionary
					trig["time"] = _drag_original_times[si]
			_mouse_down = false
			_marker_state = MarkerState.IDLE
		elif _marker_state == MarkerState.HOVERING:
			_marker_state = MarkerState.IDLE
		queue_redraw()


func _process(_delta: float) -> void:
	if _waveform_ref:
		queue_redraw()
