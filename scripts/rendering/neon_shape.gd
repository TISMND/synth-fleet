class_name NeonShape2D
extends Node2D
## Drop-in neon glow renderer. Add as a child of any entity node.
## Draws multi-pass additive polylines with white-hot cores, synced to BeatClock.

@export var points: PackedVector2Array
@export var color: Color = Color(0, 1, 1)
@export var glow_width: float = 10.0
@export var glow_intensity: float = 1.0
@export var core_brightness: float = 0.7
@export var pass_count: int = 3
@export var closed: bool = true

var _pulse_t: float = 0.0
var _additive_mat: CanvasItemMaterial


func _ready() -> void:
	_additive_mat = CanvasItemMaterial.new()
	_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_mat
	BeatClock.beat_hit.connect(_on_beat_hit)
	BeatClock.measure_hit.connect(_on_measure_hit)


func _process(delta: float) -> void:
	_pulse_t = move_toward(_pulse_t, 0.0, delta * 4.0)
	queue_redraw()


func _on_beat_hit(_beat_index: int) -> void:
	_pulse_t = 1.0


func _on_measure_hit(_measure_index: int) -> void:
	_pulse_t = 1.5


func _draw() -> void:
	var draw_points := PackedVector2Array(points)
	if draw_points.size() < 2:
		return
	if closed and draw_points.size() > 2:
		draw_points.append(draw_points[0])

	var pulse := _pulse_t
	var total_passes := pass_count
	var glow_extra := pulse * 4.0

	for i in range(total_passes):
		var t := float(i) / float(total_passes - 1) if total_passes > 1 else 1.0
		var w := lerpf(glow_width + glow_extra, 2.0, t)
		var base_alpha := lerpf(0.04, 0.85, t * t)
		var alpha := clampf(base_alpha * glow_intensity + pulse * 0.05 * (1.0 - t), 0.0, 1.0)
		var white_blend := 0.0
		if t > 0.6:
			white_blend = remap(t, 0.6, 1.0, 0.0, core_brightness)
		var pass_color := color.lerp(Color.WHITE, white_blend)
		pass_color.a = alpha
		draw_polyline(draw_points, pass_color, w, true)
