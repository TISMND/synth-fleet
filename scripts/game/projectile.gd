class_name Projectile
extends Area2D
## Projectile fired by hardpoints. Moves in a direction, damages enemies, self-destructs off-screen.

var direction: Vector2 = Vector2.UP
var speed: float = 600.0
var damage: int = 10
var weapon_color: Color = Color.CYAN
var is_wave: bool = false
var _wave_time: float = 0.0
var _base_x: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 12)
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_base_x = position.x


func _process(delta: float) -> void:
	position += direction * speed * delta
	if is_wave:
		_wave_time += delta * 8.0
		position.x = _base_x + sin(_wave_time) * 30.0
		_base_x += direction.x * speed * delta
	if position.y < -50 or position.y > 1130 or position.x < -50 or position.x > 1970:
		queue_free()


func _draw() -> void:
	var half_w: float = 2.0
	var half_h: float = 6.0
	if is_wave:
		half_w = 3.0
		half_h = 4.0
	# Glow passes
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var grow: float = 2.0 + 4.0 * t
		var alpha: float = (1.0 - t) * 0.3
		draw_rect(
			Rect2(-half_w - grow, -half_h - grow, (half_w + grow) * 2, (half_h + grow) * 2),
			Color(weapon_color, alpha)
		)
	# Core
	draw_rect(Rect2(-half_w, -half_h, half_w * 2, half_h * 2), weapon_color)
	# Bright center
	draw_rect(Rect2(-1, -half_h + 1, 2, half_h * 2 - 2), Color(1, 1, 1, 0.6))


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	queue_free()
