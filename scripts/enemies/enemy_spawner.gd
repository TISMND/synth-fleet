extends Node
## Reads a level config and spawns enemy waves on a timer.
## For now, spawns placeholder enemies at regular intervals.

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_y: float = -40.0

var _timer: float = 0.0
var _spawning: bool = false


func start_spawning() -> void:
	_spawning = true
	_timer = 0.0


func stop_spawning() -> void:
	_spawning = false


func _process(delta: float) -> void:
	if not _spawning or enemy_scene == null:
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer -= spawn_interval
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	var vp_width := get_viewport().get_visible_rect().size.x
	enemy.global_position = Vector2(randf_range(40.0, vp_width - 40.0), spawn_y)
	get_tree().current_scene.add_child(enemy)
