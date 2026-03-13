class_name RingEffect
extends Node2D
## Expanding neon ring effect. Used by ring_pulse muzzle and ring_expand impact.
## Draws via _draw() polyline circle, auto-frees after lifetime.

var radius_end: float = 30.0
var lifetime: float = 0.2
var segments: int = 16
var line_width: float = 4.0
var color: Color = Color(0, 1, 1)

var _elapsed: float = 0.0
var _additive_mat: CanvasItemMaterial


func _ready() -> void:
	_additive_mat = CanvasItemMaterial.new()
	_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_mat


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _elapsed / lifetime
	var radius := lerpf(0.0, radius_end, t)
	var alpha := 1.0 - t

	var pts := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	var w := line_width * (1.0 - t * 0.5)
	# Glow pass
	var glow_color := Color(color.r, color.g, color.b, alpha * 0.3)
	draw_polyline(pts, glow_color, w * 3.0, true)
	# Core pass
	var core_color := color.lerp(Color.WHITE, 0.4)
	core_color.a = alpha
	draw_polyline(pts, core_color, w, true)


func set_color(c: Color) -> void:
	color = c
