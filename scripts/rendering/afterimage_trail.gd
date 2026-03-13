class_name AfterimageTrail
extends Node2D
## Spawns fading NeonShape2D copies at intervals behind the projectile.

var afterimage_count: int = 5
var spacing_frames: int = 2
var fade_speed: float = 3.0
var shape_points: PackedVector2Array = PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(2, 6), Vector2(-2, 6)])
var trail_color: Color = Color(0, 1, 1)

var _frame_counter: int = 0
var _images: Array[Dictionary] = []


func _ready() -> void:
	top_level = true


func _process(delta: float) -> void:
	var parent := get_parent()
	if not parent:
		return

	_frame_counter += 1
	if _frame_counter >= spacing_frames:
		_frame_counter = 0
		_images.append({"pos": parent.global_position, "alpha": 1.0})
		if _images.size() > afterimage_count:
			_images.pop_front()

	# Fade all images
	var to_remove: Array[int] = []
	for i in _images.size():
		_images[i]["alpha"] -= delta * fade_speed
		if _images[i]["alpha"] <= 0.0:
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		_images.remove_at(idx)

	queue_redraw()


func _draw() -> void:
	for img in _images:
		var pos: Vector2 = img["pos"] - global_position
		var alpha: float = img["alpha"]
		var pts := PackedVector2Array()
		for p in shape_points:
			pts.append(p + pos)
		if pts.size() > 0:
			pts.append(pts[0])
		var c := Color(trail_color.r, trail_color.g, trail_color.b, alpha * 0.4)
		draw_polyline(pts, c, 2.0, true)


func set_color(c: Color) -> void:
	trail_color = c
