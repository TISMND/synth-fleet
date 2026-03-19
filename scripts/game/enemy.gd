class_name Enemy
extends Area2D
## Enemy that drifts down the screen or follows a flight path curve.
## Takes damage from projectiles, awards credits on death.

var health: int = 30
var drift_speed: float = 100.0
var enemy_color: Color = Color(1.0, 0.3, 0.5)

# Path-following mode (set externally; null = drift mode)
var path_curve: Curve2D = null
var path_speed: float = 200.0
var path_progress: float = 0.0  # distance traveled along curve
var path_offset: Vector2 = Vector2.ZERO  # formation slot offset
var path_origin: Vector2 = Vector2.ZERO  # x_offset from level encounter


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	if path_curve != null and path_curve.point_count >= 2:
		# Path-following mode
		path_progress += path_speed * delta
		var total_len: float = path_curve.get_baked_length()
		if path_progress >= total_len:
			queue_free()
			return
		var curve_pos: Vector2 = path_curve.sample_baked(path_progress)
		position = curve_pos + path_offset + path_origin
		# Despawn if off screen
		if position.y > 1200 or position.y < -200 or position.x < -200 or position.x > 2120:
			queue_free()
	else:
		# Drift mode (legacy)
		position.y += drift_speed * delta
		if position.y > 1130:
			queue_free()


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		GameState.add_credits(10)
		queue_free()


func _draw() -> void:
	# Neon diamond shape
	var s: float = 18.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -s),
		Vector2(s * 0.7, 0),
		Vector2(0, s),
		Vector2(-s * 0.7, 0),
	])
	# Glow passes
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var alpha: float = (1.0 - t) * 0.25
		var glow_scale: float = 1.0 + t * 0.5
		var glow_points: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_points.append(p * glow_scale)
		draw_colored_polygon(glow_points, Color(enemy_color, alpha))
	# Core
	draw_colored_polygon(points, enemy_color)
	# Bright center
	var inner: float = s * 0.4
	var inner_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -inner),
		Vector2(inner * 0.7, 0),
		Vector2(0, inner),
		Vector2(-inner * 0.7, 0),
	])
	draw_colored_polygon(inner_points, Color(1, 1, 1, 0.4))
