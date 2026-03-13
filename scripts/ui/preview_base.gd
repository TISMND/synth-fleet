class_name PreviewBase
extends Control
## Base class for aesthetic preview panels.
## Provides shared shape constants, BeatClock sync, perspective grid, and helpers.

# --- Shape data (match actual game objects) ---
static var SHIP_POINTS := PackedVector2Array([
	Vector2(-12, 16), Vector2(0, -16), Vector2(12, 16), Vector2(0, 10)
])
static var ENEMY_POINTS := PackedVector2Array([
	Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
])
static var PROJECTILE_RECT := Rect2(-2, -6, 4, 12)

# --- Positions within the preview viewport ---
var ship_pos: Vector2 = Vector2(210, 380)
var enemy_pos: Vector2 = Vector2(210, 120)
var projectile_pos: Vector2 = Vector2(210, 250)

# --- Beat pulse state ---
var _pulse_t: float = 0.0
var _time: float = 0.0

# --- Grid settings ---
var _grid_scroll_speed: float = 80.0
var _grid_h_spacing: float = 40.0
var _grid_vanish_y: float = 30.0
var _grid_num_v_lines: int = 12


func _ready() -> void:
	BeatClock.beat_hit.connect(_on_beat_hit)
	BeatClock.measure_hit.connect(_on_measure_hit)
	if not BeatClock._running:
		BeatClock.start(120.0)


func _process(delta: float) -> void:
	_time += delta
	_pulse_t = move_toward(_pulse_t, 0.0, delta * 4.0)
	queue_redraw()


func _on_beat_hit(_beat_index: int) -> void:
	_pulse_t = 1.0


func _on_measure_hit(_measure_index: int) -> void:
	_pulse_t = 1.5


# --- Helpers ---

## Returns a closed version of a polygon (first point appended at end).
func closed_poly(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if closed.size() > 0:
		closed.append(closed[0])
	return closed


## Returns points offset by a position.
func offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + offset)
	return result


## Draw a perspective grid background.
func draw_grid(color: Color) -> void:
	var vp_size := get_rect().size
	if vp_size.x == 0 or vp_size.y == 0:
		vp_size = Vector2(420, 500)

	var vanish := Vector2(vp_size.x * 0.5, _grid_vanish_y)

	# Vertical converging lines
	var spread := vp_size.x * 1.5
	for i in range(_grid_num_v_lines + 1):
		var t := float(i) / float(_grid_num_v_lines)
		var bottom_x := -spread * 0.25 + spread * t * 0.5 + vp_size.x * 0.5 - spread * 0.25
		bottom_x = lerp(-spread * 0.5 + vp_size.x * 0.5, spread * 0.5 + vp_size.x * 0.5, t)
		draw_line(vanish, Vector2(bottom_x, vp_size.y), color, 1.0, true)

	# Horizontal scrolling lines
	var num_h_lines := int(vp_size.y / _grid_h_spacing) + 2
	var scroll_offset := fmod(_time * _grid_scroll_speed, _grid_h_spacing)

	for i in range(num_h_lines):
		# Lines get closer together near vanishing point (perspective)
		var raw_y := float(i) / float(num_h_lines)
		var y := _grid_vanish_y + (raw_y * raw_y) * (vp_size.y - _grid_vanish_y)
		y += scroll_offset * raw_y  # scroll faster at bottom
		if y < _grid_vanish_y or y > vp_size.y:
			continue

		# Width at this y
		var progress := (y - _grid_vanish_y) / (vp_size.y - _grid_vanish_y)
		var half_w := progress * spread * 0.5
		var cx := vp_size.x * 0.5
		draw_line(
			Vector2(cx - half_w, y),
			Vector2(cx + half_w, y),
			color, 1.0, true
		)
