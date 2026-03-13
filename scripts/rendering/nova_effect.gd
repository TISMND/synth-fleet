class_name NovaEffect
extends Node2D
## Expanding filled circle nova flash. Fast additive fade. Used by nova_flash impact.

var radius: float = 50.0
var lifetime: float = 0.12
var intensity: float = 1.0
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
	var current_radius := lerpf(radius * 0.3, radius, t)
	var alpha := (1.0 - t) * intensity

	# Outer glow
	var glow_color := Color(color.r, color.g, color.b, alpha * 0.2)
	draw_circle(Vector2.ZERO, current_radius * 1.5, glow_color)
	# Main fill
	var main_color := color.lerp(Color.WHITE, 0.5)
	main_color.a = alpha
	draw_circle(Vector2.ZERO, current_radius, main_color)
	# Bright core
	var core_color := Color.WHITE
	core_color.a = alpha * 0.8
	draw_circle(Vector2.ZERO, current_radius * 0.3, core_color)


func set_color(c: Color) -> void:
	color = c
