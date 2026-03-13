class_name PreviewBase
extends Control
## Base class for aesthetic preview panels.
## Provides shared shape constants, BeatClock sync, glow parameters, and helpers.

# --- Shape data (match actual game objects) ---
static var SHIP_POINTS := PackedVector2Array([
	Vector2(-12, 16), Vector2(0, -16), Vector2(12, 16), Vector2(0, 10)
])
static var ENEMY_POINTS := PackedVector2Array([
	Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
])
static var PROJECTILE_RECT := Rect2(-2, -6, 4, 12)

# --- Positions within the preview viewport (recalculated on resize) ---
var ship_pos: Vector2 = Vector2(210, 380)
var enemy_pos: Vector2 = Vector2(210, 120)
var projectile_pos: Vector2 = Vector2(210, 250)

# --- Beat pulse state ---
var _pulse_t: float = 0.0
var _time: float = 0.0

# --- Glow parameters (controllable via sliders) ---
var glow_width: float = 14.0
var glow_intensity: float = 1.0
var core_brightness: float = 0.7
var pass_count: int = 4
var pulse_strength: float = 1.0

# --- Colors ---
var ship_color: Color = Color(0.0, 1.0, 1.0)
var enemy_color: Color = Color(1.0, 0.3, 0.3)
var projectile_color: Color = Color(1.0, 0.0, 0.8)

# --- Flicker ---
var flicker_enabled: bool = false


func _ready() -> void:
	BeatClock.beat_hit.connect(_on_beat_hit)
	BeatClock.measure_hit.connect(_on_measure_hit)
	if not BeatClock._running:
		BeatClock.start(120.0)
	resized.connect(_recalculate_positions)
	_recalculate_positions()


func _process(delta: float) -> void:
	_time += delta
	_pulse_t = move_toward(_pulse_t, 0.0, delta * 4.0)
	queue_redraw()


func _on_beat_hit(_beat_index: int) -> void:
	_pulse_t = 1.0


func _on_measure_hit(_measure_index: int) -> void:
	_pulse_t = 1.5


func _recalculate_positions() -> void:
	var vp := get_rect().size
	if vp.x < 1 or vp.y < 1:
		vp = Vector2(420, 500)
	ship_pos = Vector2(vp.x * 0.5, vp.y * 0.76)
	enemy_pos = Vector2(vp.x * 0.5, vp.y * 0.24)
	projectile_pos = Vector2(vp.x * 0.5, vp.y * 0.50)


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
