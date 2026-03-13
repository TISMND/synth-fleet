class_name Projectile
extends Area2D
## A single projectile. Moves in a direction, deals damage on contact, despawns offscreen.

@export var speed: float = 600.0
@export var damage: int = 10

var direction: Vector2 = Vector2.UP


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto-despawn after leaving screen
	var notifier := VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
