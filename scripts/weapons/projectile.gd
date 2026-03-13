class_name Projectile
extends Area2D
## A single projectile. Moves in a direction, deals damage on contact, despawns offscreen.

@export var speed: float = 600.0
@export var damage: int = 10

var direction: Vector2 = Vector2.UP
var neon_color: Color = Color(0, 1, 1)

var _impact_scene: PackedScene


func _ready() -> void:
	_impact_scene = preload("res://scenes/effects/impact_burst.tscn")
	body_entered.connect(_on_body_entered)
	# Auto-despawn after leaving screen
	var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
	notifier.screen_exited.connect(queue_free)
	# Apply neon color to NeonShape2D child and trail
	var neon := $NeonSprite as NeonShape2D
	if neon:
		neon.color = neon_color
	var trail := $Trail as GPUParticles2D
	if trail:
		var mat := trail.process_material as ParticleProcessMaterial
		if mat:
			mat = mat.duplicate() as ParticleProcessMaterial
			mat.color = Color(neon_color.r, neon_color.g, neon_color.b, 0.6)
			trail.process_material = mat


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	var impact := _impact_scene.instantiate() as GPUParticles2D
	impact.global_position = global_position
	if impact.has_method("set_color"):
		impact.set_color(neon_color)
	get_tree().current_scene.add_child(impact)
