class_name BeamProjectile
extends Node2D
## Sustained beam visual + hitbox attached to hardpoint position.
## Rhythmic: fire_triggers create beam pulses that last beam_duration seconds.

var weapon_color: Color = Color.CYAN
var damage_per_tick: float = 5.0
var beam_duration: float = 0.3
var max_length: float = 400.0
var beam_width: float = 16.0
var scroll_speed: float = 3.0
var projectile_style: ProjectileStyle = null

var _age: float = 0.0
var _damage_accumulator: float = 0.0
var _sprite: Sprite2D = null
var _collision_area: Area2D = null
var _collision_shape: CollisionShape2D = null
var _rect_shape: RectangleShape2D = null
var _already_hit: Array = []


func _ready() -> void:
	_setup_visual()
	_setup_collision()


func _setup_visual() -> void:
	if projectile_style:
		_sprite = VFXFactory.create_styled_sprite(projectile_style, weapon_color)
	else:
		# Fallback: use beam shader
		var style := ProjectileStyle.new()
		style.fill_shader = "beam"
		style.base_scale = Vector2(beam_width, max_length)
		_sprite = VFXFactory.create_styled_sprite(style, weapon_color)

	if _sprite:
		# Beam extends upward: pivot at bottom, sprite centered
		_sprite.position = Vector2(0, -max_length / 2.0)
		add_child(_sprite)


func _setup_collision() -> void:
	_collision_area = Area2D.new()
	_collision_area.collision_layer = 2
	_collision_area.collision_mask = 4
	_collision_shape = CollisionShape2D.new()
	_rect_shape = RectangleShape2D.new()
	_rect_shape.size = Vector2(beam_width, max_length)
	_collision_shape.shape = _rect_shape
	_collision_shape.position = Vector2(0, -max_length / 2.0)
	_collision_area.add_child(_collision_shape)
	add_child(_collision_area)
	_collision_area.area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_age += delta

	# Damage tick with float accumulator (avoids int truncation per CLAUDE.md)
	_damage_accumulator += damage_per_tick * delta
	if _damage_accumulator >= 1.0:
		var tick_damage: int = int(_damage_accumulator)
		_damage_accumulator -= float(tick_damage)
		_apply_damage_to_overlapping(tick_damage)

	# Auto-destroy after duration
	if _age >= beam_duration:
		queue_free()


func _apply_damage_to_overlapping(dmg: int) -> void:
	var areas: Array[Area2D] = _collision_area.get_overlapping_areas()
	for area in areas:
		if area.has_method("take_damage"):
			area.take_damage(dmg)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		var initial_dmg: int = int(maxf(damage_per_tick * 0.1, 1.0))
		area.take_damage(initial_dmg)
