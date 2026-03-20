class_name EnemyProjectile
extends Area2D
## Projectile fired by enemies. Moves in a given direction, damages the player on contact.
## Uses collision Layer 8 (enemy projectiles) and detects Layer 1 (player).

var direction: Vector2 = Vector2.DOWN
var speed: float = 300.0
var damage: int = 10
var projectile_color: Color = Color(1.0, 0.3, 0.5)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 10)
	shape.shape = rect
	add_child(shape)

	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position += direction * speed * delta

	# Despawn off-screen
	if position.y > 1200 or position.y < -100 or position.x < -100 or position.x > 2020:
		queue_free()


func _draw() -> void:
	# Draw along direction vector (no node rotation — keeps it simple)
	var half_len: float = 6.0
	var dir_norm: Vector2 = direction.normalized()
	var start: Vector2 = -dir_norm * half_len
	var end: Vector2 = dir_norm * half_len

	# Core line
	draw_line(start, end, projectile_color, 2.0, true)
	# Glow line (wider, transparent)
	var glow_color: Color = Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.4)
	draw_line(start, end, glow_color, 5.0, true)
	# Tip dot
	draw_circle(end, 2.0, projectile_color)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(float(damage))
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(float(damage))
	queue_free()
