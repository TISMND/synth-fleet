class_name PianoRoll
extends Control
## Reusable piano roll Control — Mario Paint Composer-style note grid.
## Click cells to place/remove notes. Supports cooldown blocking via note_duration_cells.

signal pattern_changed(new_pattern: Array)

const NOTE_COUNT: int = 24  # C3–B4
const NOTE_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const LABEL_MARGIN: float = 36.0
const HEADER_HEIGHT: float = 20.0

var loop_length: int = 32
var pattern: Array = []  # length = loop_length, each element: -1 (silent) or 0–23 (note index)
var weapon_color: Color = Color.CYAN
var playback_step: int = -1  # visual cursor, set externally
var note_duration_cells: int = 1  # how many cells one note occupies

var _cell_width: float = 0.0
var _cell_height: float = 0.0
var _hovered_col: int = -1
var _hovered_row: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_init_pattern()
	_recalc_cells()


func _init_pattern() -> void:
	pattern.clear()
	for i in loop_length:
		pattern.append(-1)


func _recalc_cells() -> void:
	var grid_width: float = size.x - LABEL_MARGIN
	var grid_height: float = size.y - HEADER_HEIGHT
	if loop_length > 0:
		_cell_width = grid_width / float(loop_length)
	else:
		_cell_width = 0.0
	if NOTE_COUNT > 0:
		_cell_height = grid_height / float(NOTE_COUNT)
	else:
		_cell_height = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recalc_cells()
		queue_redraw()


# ── Cooldown helpers ─────────────────────────────────────────

static func duration_to_cells(duration_str: String) -> int:
	match duration_str:
		"1/4": return 8
		"1/8": return 4
		"1/16": return 2
		"1/32": return 1
		_: return 4


func _is_in_cooldown(col: int) -> bool:
	## Returns true if col falls within the cooldown zone of a preceding trigger.
	var scan_start: int = maxi(col - (note_duration_cells - 1), 0)
	for c in range(scan_start, col):
		if int(pattern[c]) >= 0:
			return true
	return false


func _sanitize_pattern() -> void:
	## Remove notes whose cooldowns would overlap with a preceding trigger.
	var i: int = 0
	while i < pattern.size():
		if int(pattern[i]) >= 0:
			# Clear any triggers that fall within this note's cooldown zone
			for j in range(i + 1, mini(i + note_duration_cells, pattern.size())):
				pattern[j] = -1
			i += note_duration_cells
		else:
			i += 1


# ── Drawing ──────────────────────────────────────────────────

func _draw() -> void:
	_recalc_cells()
	var grid_x: float = LABEL_MARGIN
	var grid_y: float = HEADER_HEIGHT
	var grid_w: float = size.x - LABEL_MARGIN
	var grid_h: float = size.y - HEADER_HEIGHT

	# 1. Dark background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.12))

	# 2. Row shading
	for r in NOTE_COUNT:
		var note_idx: int = NOTE_COUNT - 1 - r
		var octave_note: int = note_idx % 12
		var row_rect := Rect2(grid_x, grid_y + r * _cell_height, grid_w, _cell_height)

		# Sharps (black keys) get darker bg
		if octave_note in [1, 3, 6, 8, 10]:
			draw_rect(row_rect, Color(0.06, 0.06, 0.09))

		# Middle C highlight (C4 = index 12, visual row 11)
		if note_idx == 12:
			draw_rect(row_rect, Color(0.12, 0.15, 0.2))

	# 3. Grid lines
	for col in loop_length + 1:
		var x: float = grid_x + col * _cell_width
		var line_color: Color = Color(0.35, 0.35, 0.45) if col % 4 == 0 else Color(0.2, 0.2, 0.28)
		draw_line(Vector2(x, grid_y), Vector2(x, grid_y + grid_h), line_color)
	for row in NOTE_COUNT + 1:
		var y: float = grid_y + row * _cell_height
		draw_line(Vector2(grid_x, y), Vector2(grid_x + grid_w, y), Color(0.18, 0.18, 0.25))

	# 4. Step numbers along top header
	for col in loop_length:
		var x: float = grid_x + col * _cell_width
		var num_str: String = str(col + 1)
		var text_color: Color = Color(0.5, 0.5, 0.6) if col % 4 != 0 else Color(0.7, 0.7, 0.8)
		draw_string(ThemeDB.fallback_font, Vector2(x + 3, HEADER_HEIGHT - 4), num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_color)

	# 5. Note labels on left margin (naturals only)
	for r in NOTE_COUNT:
		var note_idx: int = NOTE_COUNT - 1 - r
		var octave_note: int = note_idx % 12
		var octave: int = 3 + note_idx / 12
		if octave_note not in [1, 3, 6, 8, 10]:
			var note_name: String = NOTE_NAMES[octave_note] + str(octave)
			var y: float = grid_y + r * _cell_height + _cell_height * 0.7
			draw_string(ThemeDB.fallback_font, Vector2(2, y), note_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.5, 0.6))

	# 6. Active notes — trigger cells + cooldown tails
	for col in pattern.size():
		var note_val: int = int(pattern[col])
		if note_val < 0 or note_val >= NOTE_COUNT:
			continue
		var visual_row: int = NOTE_COUNT - 1 - note_val
		# Draw trigger cell (solid)
		var cell_rect := Rect2(
			grid_x + col * _cell_width + 1,
			grid_y + visual_row * _cell_height + 1,
			_cell_width - 2,
			_cell_height - 2
		)
		var glow_rect := cell_rect.grow(2.0)
		var glow_color := Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.3)
		draw_rect(glow_rect, glow_color, true)
		draw_rect(cell_rect, weapon_color, true)

		# Draw cooldown tail cells (dimmed)
		for tail in range(1, note_duration_cells):
			var tail_col: int = col + tail
			if tail_col >= loop_length:
				break
			var tail_rect := Rect2(
				grid_x + tail_col * _cell_width + 1,
				grid_y + visual_row * _cell_height + 1,
				_cell_width - 2,
				_cell_height - 2
			)
			var dimmed := Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.2)
			draw_rect(tail_rect, dimmed, true)

	# 7. Playback cursor — semi-transparent vertical column highlight
	if playback_step >= 0 and playback_step < loop_length:
		var cursor_rect := Rect2(
			grid_x + playback_step * _cell_width,
			grid_y,
			_cell_width,
			grid_h
		)
		draw_rect(cursor_rect, Color(1.0, 1.0, 1.0, 0.12))

	# 8. Hover highlight
	if _hovered_col >= 0 and _hovered_col < loop_length and _hovered_row >= 0 and _hovered_row < NOTE_COUNT:
		var hover_rect := Rect2(
			grid_x + _hovered_col * _cell_width + 1,
			grid_y + _hovered_row * _cell_height + 1,
			_cell_width - 2,
			_cell_height - 2
		)
		if _is_in_cooldown(_hovered_col):
			# Blocked — subtle red outline
			draw_rect(hover_rect, Color(1.0, 0.2, 0.2, 0.25), false, 1.0)
		else:
			draw_rect(hover_rect, Color(1.0, 1.0, 1.0, 0.15), false, 1.0)


# ── Input ────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var coords: Vector2i = _mouse_to_grid(event.position)
		_hovered_col = coords.x
		_hovered_row = coords.y
		queue_redraw()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var coords: Vector2i = _mouse_to_grid(mb.position)
			var col: int = coords.x
			var row: int = coords.y
			if col < 0 or col >= loop_length or row < 0 or row >= NOTE_COUNT:
				return
			var note_idx: int = NOTE_COUNT - 1 - row

			# Check if clicking on an existing trigger at this col
			var existing: int = int(pattern[col])
			if existing == note_idx:
				# Toggle off
				pattern[col] = -1
			elif existing >= 0:
				# Replace existing trigger (different note)
				# Clear old cooldown zone's conflicts, then place new
				pattern[col] = note_idx
				# Clear any triggers in the new note's cooldown zone
				for j in range(col + 1, mini(col + note_duration_cells, loop_length)):
					pattern[j] = -1
			else:
				# Empty cell — check if blocked by a preceding trigger's cooldown
				if _is_in_cooldown(col):
					return  # blocked
				# Place the note
				pattern[col] = note_idx
				# Clear any triggers in the new note's cooldown zone
				for j in range(col + 1, mini(col + note_duration_cells, loop_length)):
					pattern[j] = -1

			pattern_changed.emit(pattern)
			queue_redraw()


func _mouse_to_grid(pos: Vector2) -> Vector2i:
	var gx: float = pos.x - LABEL_MARGIN
	var gy: float = pos.y - HEADER_HEIGHT
	if _cell_width <= 0.0 or _cell_height <= 0.0:
		return Vector2i(-1, -1)
	var col: int = int(gx / _cell_width)
	var row: int = int(gy / _cell_height)
	return Vector2i(col, row)


# ── Setters ──────────────────────────────────────────────────

func set_loop_length(n: int) -> void:
	loop_length = n
	while pattern.size() < loop_length:
		pattern.append(-1)
	if pattern.size() > loop_length:
		pattern.resize(loop_length)
	_recalc_cells()
	queue_redraw()


func set_pattern(arr: Array) -> void:
	pattern = arr.duplicate()
	while pattern.size() < loop_length:
		pattern.append(-1)
	if pattern.size() > loop_length:
		pattern.resize(loop_length)
	queue_redraw()


func set_playback_step(step: int) -> void:
	playback_step = step
	queue_redraw()


func set_weapon_color(c: Color) -> void:
	weapon_color = c
	queue_redraw()


func set_note_duration_cells(cells: int) -> void:
	note_duration_cells = maxi(cells, 1)
	_sanitize_pattern()
	queue_redraw()


# ── Static Utility ───────────────────────────────────────────

static func get_pitch_scale(note_index: int) -> float:
	## Index 12 (C4) = 1.0, index 0 (C3) = 0.5, index 23 (B4) ≈ 1.888
	return pow(2.0, float(note_index - 12) / 12.0)
