class_name ShieldBubbleEffect
extends Node2D
## Translucent shield bubble (Soft Sphere) that flashes around a ship on shield hit.
## Configurable color, duration, radius, and intensity via exposed vars.

var ship_radius: float = 60.0
var flash_time: float = 0.0
var flash_duration: float = 0.15
var shield_color := Color(0.3, 0.8, 1.0)
var intensity: float = 1.0
var radius_mult: float = 1.0


func trigger() -> void:
	flash_time = flash_duration
	visible = true
	set_process(true)
	queue_redraw()


func _ready() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if flash_time <= 0.0:
		visible = false
		set_process(false)
		return
	flash_time -= delta
	if flash_time < 0.0:
		flash_time = 0.0
	queue_redraw()


func _draw() -> void:
	if flash_time <= 0.0:
		return
	var t: float = flash_time / flash_duration  # 1.0 -> 0.0
	var r: float = ship_radius * radius_mult
	var col := shield_color
	# Outer glow
	col.a = 0.15 * t * intensity
	draw_circle(Vector2.ZERO, r * 1.2, col)
	# Mid fill
	col.a = 0.3 * t * intensity
	draw_circle(Vector2.ZERO, r, col)
	# Bright core
	col.a = 0.5 * t * intensity
	draw_circle(Vector2.ZERO, r * 0.6, col)
