class_name RibbonTrail
extends Line2D
## Ribbon trail that records parent global_position each frame and tapers width.

var trail_length: int = 10
var width_start: float = 3.0
var width_end: float = 0.0
var trail_color: Color = Color(0, 1, 1, 0.6)

var _additive_mat: CanvasItemMaterial


func _ready() -> void:
	_additive_mat = CanvasItemMaterial.new()
	_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_mat
	width = width_start
	default_color = trail_color
	# Width curve: taper from width_start to width_end
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, width_end / maxf(width_start, 0.01)))
	width_curve = curve
	# Use local coords = false so points are in global space
	top_level = true


func _process(_delta: float) -> void:
	var parent := get_parent()
	if not parent:
		return
	# Add current position to front
	add_point(parent.global_position, 0)
	# Trim excess points
	while get_point_count() > trail_length:
		remove_point(get_point_count() - 1)


func set_color(c: Color) -> void:
	trail_color = Color(c.r, c.g, c.b, 0.6)
	default_color = trail_color
