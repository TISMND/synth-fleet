class_name EnemyBase
extends CharacterBody2D
## Base enemy — has health, moves, drops credits on death.

signal destroyed(enemy: EnemyBase)

@export var max_health: int = 30
@export var move_speed: float = 100.0
@export var credit_value: int = 10

var health: int


func _ready() -> void:
	health = max_health


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	GameState.credits += credit_value
	destroyed.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	# Default: drift downward
	velocity = Vector2.DOWN * move_speed
	move_and_slide()

	# Despawn if off bottom of screen
	if global_position.y > get_viewport().get_visible_rect().size.y + 64:
		queue_free()
