class_name Enemy
extends Area2D
## Enemy that drifts down the screen. Takes damage from projectiles, awards credits on death.

var health: int = 30
var drift_speed: float = 100.0
var enemy_color: Color = Color(1.0, 0.3, 0.5)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
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
