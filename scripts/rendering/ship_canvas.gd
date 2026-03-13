class_name ShipCanvas
extends Control
## Interactive grid canvas for drawing ship outlines and placing hardpoints.

enum Mode { DRAW_LINE, PLACE_HARDPOINT }

signal lines_changed()
signal hardpoints_changed()
signal hardpoint_edit_requested(index: int, screen_pos: Vector2)

var lines: Array = []
var hardpoints: Array = []
var grid_size: Vector2i = Vector2i(32, 32)
var cell_size: float = 10.0
var offset: Vector2 = Vector2.ZERO
var mirror_enabled: bool = false
var current_line_color: String = "#00FFFF"
var mode: Mode = Mode.DRAW_LINE

var display_only: bool = false

var _draw_start: Vector2i = Vector2i(-1, -1)
var _mouse_grid_pos: Vector2i = Vector2i(0, 0)
var _next_hp_id: int = 0


func _ready() -> void:
	resized.connect(_compute_layout)
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("_compute_layout")


func _compute_layout() -> void:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return
	cell_size = minf(size.x / float(grid_size.x), size.y / float(grid_size.y))
	offset = Vector2(
		(size.x - cell_size * grid_size.x) / 2.0,
		(size.y - cell_size * grid_size.y) / 2.0
	)
	queue_redraw()


func _grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	return offset + Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)


func _pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	var gx: int = roundi((pixel_pos.x - offset.x) / cell_size)
	var gy: int = roundi((pixel_pos.y - offset.y) / cell_size)
	gx = clampi(gx, 0, grid_size.x)
	gy = clampi(gy, 0, grid_size.y)
	return Vector2i(gx, gy)


func _get_mirrored_pos(pos: Vector2i) -> Vector2i:
	return Vector2i(grid_size.x - pos.x, pos.y)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_grid_pos = _pixel_to_grid(event.position)
		queue_redraw()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return

		_mouse_grid_pos = _pixel_to_grid(mb.position)

		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mb)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()


func _handle_left_click(mb: InputEventMouseButton) -> void:
	if mode == Mode.DRAW_LINE:
		if _draw_start == Vector2i(-1, -1):
			_draw_start = _mouse_grid_pos
		else:
			_add_line(_draw_start, _mouse_grid_pos, current_line_color)
			if mirror_enabled:
				var m_from: Vector2i = _get_mirrored_pos(_draw_start)
				var m_to: Vector2i = _get_mirrored_pos(_mouse_grid_pos)
				if m_from != _draw_start or m_to != _mouse_grid_pos:
					_add_line(m_from, m_to, current_line_color)
			_draw_start = Vector2i(-1, -1)
			lines_changed.emit()
		queue_redraw()

	elif mode == Mode.PLACE_HARDPOINT:
		var existing_idx: int = _find_hardpoint_at(_mouse_grid_pos)
		if existing_idx >= 0:
			var hp_pixel: Vector2 = _grid_to_pixel(_mouse_grid_pos)
			var screen_pos: Vector2 = global_position + hp_pixel
			hardpoint_edit_requested.emit(existing_idx, screen_pos)
		else:
			var hp: Dictionary = {
				"id": "hp_" + str(_next_hp_id),
				"label": "HP" + str(_next_hp_id),
				"grid_pos": [_mouse_grid_pos.x, _mouse_grid_pos.y],
				"direction_deg": 0.0,
			}
			_next_hp_id += 1
			hardpoints.append(hp)
			if mirror_enabled:
				var m_pos: Vector2i = _get_mirrored_pos(_mouse_grid_pos)
				if m_pos != _mouse_grid_pos:
					var m_hp: Dictionary = {
						"id": "hp_" + str(_next_hp_id),
						"label": "HP" + str(_next_hp_id),
						"grid_pos": [m_pos.x, m_pos.y],
						"direction_deg": 0.0,
					}
					_next_hp_id += 1
					hardpoints.append(m_hp)
			hardpoints_changed.emit()
			queue_redraw()


func _handle_right_click() -> void:
	if mode == Mode.DRAW_LINE:
		if _draw_start != Vector2i(-1, -1):
			_draw_start = Vector2i(-1, -1)
			queue_redraw()
		else:
			var idx: int = _find_line_near_point(_mouse_grid_pos)
			if idx >= 0:
				if mirror_enabled:
					var line_data: Dictionary = lines[idx]
					var from_arr: Array = line_data["from"]
					var to_arr: Array = line_data["to"]
					var m_from: Vector2i = _get_mirrored_pos(Vector2i(int(from_arr[0]), int(from_arr[1])))
					var m_to: Vector2i = _get_mirrored_pos(Vector2i(int(to_arr[0]), int(to_arr[1])))
					var mirror_idx: int = _find_matching_line(m_from, m_to)
					if mirror_idx >= 0 and mirror_idx != idx:
						if mirror_idx > idx:
							lines.remove_at(mirror_idx)
							lines.remove_at(idx)
						else:
							lines.remove_at(idx)
							lines.remove_at(mirror_idx)
					else:
						lines.remove_at(idx)
				else:
					lines.remove_at(idx)
				lines_changed.emit()
				queue_redraw()

	elif mode == Mode.PLACE_HARDPOINT:
		var idx: int = _find_hardpoint_at(_mouse_grid_pos)
		if idx >= 0:
			if mirror_enabled:
				var hp: Dictionary = hardpoints[idx]
				var hp_pos_arr: Array = hp["grid_pos"]
				var m_pos: Vector2i = _get_mirrored_pos(Vector2i(int(hp_pos_arr[0]), int(hp_pos_arr[1])))
				var mirror_idx: int = _find_hardpoint_at(m_pos)
				if mirror_idx >= 0 and mirror_idx != idx:
					if mirror_idx > idx:
						hardpoints.remove_at(mirror_idx)
						hardpoints.remove_at(idx)
					else:
						hardpoints.remove_at(idx)
						hardpoints.remove_at(mirror_idx)
				else:
					hardpoints.remove_at(idx)
			else:
				hardpoints.remove_at(idx)
			hardpoints_changed.emit()
			queue_redraw()


func _add_line(from: Vector2i, to: Vector2i, color: String) -> void:
	lines.append({
		"from": [from.x, from.y],
		"to": [to.x, to.y],
		"color": color,
	})


func _find_hardpoint_at(pos: Vector2i) -> int:
	for i in hardpoints.size():
		var hp: Dictionary = hardpoints[i]
		var gp: Array = hp["grid_pos"]
		if int(gp[0]) == pos.x and int(gp[1]) == pos.y:
			return i
	return -1


func _find_line_near_point(pos: Vector2i) -> int:
	var best_idx: int = -1
	var best_dist: float = 1.5  # threshold in grid units
	var p: Vector2 = Vector2(pos)
	for i in lines.size():
		var line_data: Dictionary = lines[i]
		var from_arr: Array = line_data["from"]
		var to_arr: Array = line_data["to"]
		var a: Vector2 = Vector2(float(from_arr[0]), float(from_arr[1]))
		var b: Vector2 = Vector2(float(to_arr[0]), float(to_arr[1]))
		var dist: float = _point_to_segment_dist(p, a, b)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func _find_matching_line(from: Vector2i, to: Vector2i) -> int:
	for i in lines.size():
		var line_data: Dictionary = lines[i]
		var fa: Array = line_data["from"]
		var ta: Array = line_data["to"]
		var lf: Vector2i = Vector2i(int(fa[0]), int(fa[1]))
		var lt: Vector2i = Vector2i(int(ta[0]), int(ta[1]))
		if (lf == from and lt == to) or (lf == to and lt == from):
			return i
	return -1


func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)


# ── Drawing ──────────────────────────────────────────────

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 1.0))

	if cell_size <= 0:
		return

	if not display_only:
		# Grid lines
		var grid_color: Color = Color(0.12, 0.12, 0.18, 0.4)
		var grid_color_major: Color = Color(0.18, 0.18, 0.25, 0.5)
		var dot_color: Color = Color(0.25, 0.25, 0.35, 0.6)

		for x in range(0, grid_size.x + 1):
			var px: float = offset.x + x * cell_size
			var col: Color = grid_color_major if x % 8 == 0 else grid_color
			draw_line(Vector2(px, offset.y), Vector2(px, offset.y + grid_size.y * cell_size), col, 1.0)
		for y in range(0, grid_size.y + 1):
			var py: float = offset.y + y * cell_size
			var col: Color = grid_color_major if y % 8 == 0 else grid_color
			draw_line(Vector2(offset.x, py), Vector2(offset.x + grid_size.x * cell_size, py), col, 1.0)

		# Grid intersection dots
		for x in range(0, grid_size.x + 1):
			for y in range(0, grid_size.y + 1):
				draw_circle(_grid_to_pixel(Vector2i(x, y)), 1.5, dot_color)

		# Mirror center axis
		if mirror_enabled:
			var cx: float = offset.x + (grid_size.x / 2.0) * cell_size
			draw_line(
				Vector2(cx, offset.y),
				Vector2(cx, offset.y + grid_size.y * cell_size),
				Color(1.0, 0.4, 0.4, 0.35), 2.0
			)

	# Ship lines with neon glow
	for line_data in lines:
		var from_arr: Array = line_data["from"]
		var to_arr: Array = line_data["to"]
		var col_hex: String = str(line_data.get("color", "#00FFFF"))
		var col: Color = Color(col_hex)
		var a: Vector2 = _grid_to_pixel(Vector2i(int(from_arr[0]), int(from_arr[1])))
		var b: Vector2 = _grid_to_pixel(Vector2i(int(to_arr[0]), int(to_arr[1])))
		_draw_neon_line(a, b, col)

	# Hardpoint markers
	for hp in hardpoints:
		var gp: Array = hp["grid_pos"]
		var pos: Vector2 = _grid_to_pixel(Vector2i(int(gp[0]), int(gp[1])))
		var dir_deg: float = float(hp.get("direction_deg", 0.0))
		_draw_hardpoint(pos, dir_deg)

	if not display_only:
		# In-progress line ghost
		if _draw_start != Vector2i(-1, -1):
			var a: Vector2 = _grid_to_pixel(_draw_start)
			var b: Vector2 = _grid_to_pixel(_mouse_grid_pos)
			_draw_dashed_line(a, b, Color(1, 1, 1, 0.5))
			if mirror_enabled:
				var ma: Vector2 = _grid_to_pixel(_get_mirrored_pos(_draw_start))
				var mb: Vector2 = _grid_to_pixel(_get_mirrored_pos(_mouse_grid_pos))
				if ma != a or mb != b:
					_draw_dashed_line(ma, mb, Color(1, 1, 1, 0.3))

		# Cursor crosshair
		var cursor_pos: Vector2 = _grid_to_pixel(_mouse_grid_pos)
		var ch_size: float = cell_size * 0.4
		var ch_color: Color = Color(1, 1, 1, 0.7)
		draw_line(cursor_pos - Vector2(ch_size, 0), cursor_pos + Vector2(ch_size, 0), ch_color, 1.0)
		draw_line(cursor_pos - Vector2(0, ch_size), cursor_pos + Vector2(0, ch_size), ch_color, 1.0)


func _draw_neon_line(a: Vector2, b: Vector2, col: Color) -> void:
	# Glow passes
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var w: float = 2.0 + 6.0 * t
		var alpha: float = (1.0 - t) * 0.3
		draw_line(a, b, Color(col, alpha), w)
	# Core
	draw_line(a, b, col, 2.0)
	# Bright center
	draw_line(a, b, Color(1, 1, 1, 0.6), 1.0)


func _draw_hardpoint(pos: Vector2, dir_deg: float) -> void:
	var hp_color: Color = Color(1.0, 0.7, 0.2, 0.9)
	var hp_glow: Color = Color(1.0, 0.5, 0.1, 0.3)
	draw_circle(pos, cell_size * 0.4, hp_glow)
	draw_circle(pos, cell_size * 0.25, hp_color)
	# Direction arrow
	var dir_rad: float = deg_to_rad(dir_deg - 90.0)  # 0 deg = up
	var arrow_end: Vector2 = pos + Vector2(cos(dir_rad), sin(dir_rad)) * cell_size * 0.6
	draw_line(pos, arrow_end, hp_color, 2.0)
	# Arrowhead
	var perp: Vector2 = Vector2(-sin(dir_rad), cos(dir_rad)) * cell_size * 0.15
	var back: Vector2 = arrow_end - Vector2(cos(dir_rad), sin(dir_rad)) * cell_size * 0.2
	draw_line(arrow_end, back + perp, hp_color, 1.5)
	draw_line(arrow_end, back - perp, hp_color, 1.5)


func _draw_dashed_line(a: Vector2, b: Vector2, col: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	var dir: Vector2 = (b - a).normalized()
	var dash_len: float = 6.0
	var gap_len: float = 4.0
	var d: float = 0.0
	while d < length:
		var seg_end: float = minf(d + dash_len, length)
		draw_line(a + dir * d, a + dir * seg_end, col, 1.0)
		d = seg_end + gap_len


# ── Setters ──────────────────────────────────────────────

func set_lines(arr: Array) -> void:
	lines = arr
	queue_redraw()


func set_hardpoints(arr: Array) -> void:
	hardpoints = arr
	_next_hp_id = 0
	for hp in hardpoints:
		var hp_id: String = str(hp.get("id", ""))
		if hp_id.begins_with("hp_"):
			var num_str: String = hp_id.substr(3)
			if num_str.is_valid_int():
				var num: int = num_str.to_int()
				if num >= _next_hp_id:
					_next_hp_id = num + 1
	queue_redraw()


func set_grid_size(new_size: Vector2i) -> void:
	# Remove lines/hardpoints outside new bounds
	var filtered_lines: Array = []
	for line_data in lines:
		var from_arr: Array = line_data["from"]
		var to_arr: Array = line_data["to"]
		if int(from_arr[0]) <= new_size.x and int(from_arr[1]) <= new_size.y \
			and int(to_arr[0]) <= new_size.x and int(to_arr[1]) <= new_size.y:
			filtered_lines.append(line_data)
	var removed_lines: int = lines.size() - filtered_lines.size()
	lines = filtered_lines

	var filtered_hps: Array = []
	for hp in hardpoints:
		var gp: Array = hp["grid_pos"]
		if int(gp[0]) <= new_size.x and int(gp[1]) <= new_size.y:
			filtered_hps.append(hp)
	var removed_hps: int = hardpoints.size() - filtered_hps.size()
	hardpoints = filtered_hps

	grid_size = new_size
	_compute_layout()

	if removed_lines > 0:
		lines_changed.emit()
	if removed_hps > 0:
		hardpoints_changed.emit()


func set_mirror(enabled: bool) -> void:
	mirror_enabled = enabled
	queue_redraw()


func set_line_color(color: String) -> void:
	current_line_color = color
	queue_redraw()
