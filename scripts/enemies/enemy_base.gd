class_name EnemyBase
extends CharacterBody2D
## Base enemy — has health, moves, drops credits on death.

signal destroyed(enemy: EnemyBase)

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var credit_value: int = 10

var health: int

var _death_scene: PackedScene


func _ready() -> void:
	health = max_health
	_death_scene = preload("res://scenes/effects/enemy_death.tscn")


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	GameState.credits += credit_value
	destroyed.emit(self)
	_spawn_death_effect()
	queue_free()


func _spawn_death_effect() -> void:
	var effect := _death_scene.instantiate() as GPUParticles2D
	effect.global_position = global_position
	# Use enemy's neon color if available
	var neon := get_node_or_null("NeonSprite") as NeonShape2D
	if neon and effect.has_method("set_color"):
		effect.set_color(neon.color)
	get_tree().current_scene.add_child(effect)


func _physics_process(delta: float) -> void:
	# Default: drift downward
	velocity = Vector2.DOWN * move_speed
	move_and_slide()

	# Despawn if off bottom of screen
	if global_position.y > get_viewport().get_visible_rect().size.y + 64:
		queue_free()
