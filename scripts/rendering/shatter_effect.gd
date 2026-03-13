class_name ShatterEffect
extends Node2D
## Radiating shatter lines that fly outward and fade. Used by shatter_lines impact.

var line_count: int = 6
var line_length: float = 20.0
var lifetime: float = 0.3
var velocity: float = 150.0
var color: Color = Color(0, 1, 1)

var _elapsed: float = 0.0
var _lines: Array[Dictionary] = []
var _additive_mat: CanvasItemMaterial


func _ready() -> void:
	_additive_mat = CanvasItemMaterial.new()
	_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_mat
	# Generate random line directions
	for i in line_count:
		var angle := TAU * float(i) / float(line_count) + randf_range(-0.3, 0.3)
		_lines.append({"angle": angle})


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _elapsed / lifetime
	var alpha := 1.0 - t
	var dist := velocity * _elapsed
	var len := line_length * (1.0 - t * 0.5)

	for line_data in _lines:
		var angle: float = line_data["angle"]
		var dir := Vector2(cos(angle), sin(angle))
		var start := dir * dist
		var end := dir * (dist + len)
		# Glow
		var glow_color := Color(color.r, color.g, color.b, alpha * 0.3)
		draw_line(start, end, glow_color, 6.0, true)
		# Core
		var core_color := color.lerp(Color.WHITE, 0.3)
		core_color.a = alpha
		draw_line(start, end, core_color, 2.0, true)


func set_color(c: Color) -> void:
	color = c
