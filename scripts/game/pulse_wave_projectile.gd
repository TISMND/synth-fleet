class_name PulseWaveProjectile
extends Area2D
## Expanding ring projectile that damages enemies as it passes through them.

var weapon_color: Color = Color.CYAN
var damage: int = 10
var expansion_rate: float = 200.0
var max_radius: float = 300.0
var lifetime: float = 1.0
var ring_width: float = 8.0
var projectile_style: ProjectileStyle = null
var skips_shields: bool = false

var _age: float = 0.0
var _current_radius: float = 0.0
var _collision_shape: CollisionShape2D = null
var _circle_shape: CircleShape2D = null
var _already_hit: Array = []
var _sprite: Sprite2D = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4

	_collision_shape = CollisionShape2D.new()
	_circle_shape = CircleShape2D.new()
	_circle_shape.radius = 1.0
	_collision_shape.shape = _circle_shape
	add_child(_collision_shape)

	area_entered.connect(_on_area_entered)

	# Visual: styled sprite scaled over time
	if projectile_style:
		_sprite = VFXFactory.create_styled_sprite(projectile_style, weapon_color)
	if _sprite:
		_sprite.scale = Vector2(0.1, 0.1)
		add_child(_sprite)


func _process(delta: float) -> void:
	_age += delta
	_current_radius += expansion_rate * delta

	# Update collision
	_circle_shape.radius = _current_radius

	# Update visual scale
	if _sprite:
		var scale_factor: float = _current_radius / maxf(max_radius, 1.0) * 4.0
		_sprite.scale = Vector2(scale_factor, scale_factor)
		# Fade out as it expands
		_sprite.modulate.a = clampf(1.0 - _current_radius / max_radius, 0.1, 1.0)

	# Auto-free conditions
	if _current_radius >= max_radius or _age >= lifetime:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	if _sprite:
		return
	# Fallback drawing if no styled sprite
	var hdr: float = 2.0
	var outer_r: float = _current_radius
	var inner_r: float = maxf(_current_radius - ring_width, 0.0)
	var alpha: float = clampf(1.0 - _current_radius / max_radius, 0.1, 1.0)

	# Outer glow ring
	draw_arc(Vector2.ZERO, outer_r + 2.0, 0, TAU, 48,
		Color(weapon_color.r * hdr, weapon_color.g * hdr, weapon_color.b * hdr, alpha * 0.4), 4.0)
	# Core ring
	draw_arc(Vector2.ZERO, (outer_r + inner_r) / 2.0, 0, TAU, 48,
		Color(weapon_color.r * hdr, weapon_color.g * hdr, weapon_color.b * hdr, alpha), ring_width)
	# White hot center line
	draw_arc(Vector2.ZERO, (outer_r + inner_r) / 2.0, 0, TAU, 48,
		Color(2.0, 2.0, 2.0, alpha * 0.5), ring_width * 0.3)


func _on_area_entered(area: Area2D) -> void:
	if area in _already_hit:
		return
	_already_hit.append(area)
	if area.has_method("take_damage"):
		area.take_damage(damage, skips_shields)
