class_name WeaponBase
extends Node2D
## Base class for all weapons. Listens to BeatClock, fires on its assigned
## rhythmic subdivision, and triggers AudioManager for the weapon's color.

@export var weapon_data: WeaponData
@export var subdivision: int = 1  ## 1 = quarter, 2 = eighth, 3 = triplet
@export var color_name: String = "cyan"

var _fire_direction: Vector2 = Vector2.UP
var _subdivision_counter: int = 0

@onready var _projectile_scene: PackedScene = preload("res://scenes/game/projectile.tscn")


func _ready() -> void:
	BeatClock.beat_hit.connect(_on_beat_hit)


func _on_beat_hit(_beat_index: int) -> void:
	_subdivision_counter += 1
	if subdivision <= 1 or _subdivision_counter >= subdivision:
		_subdivision_counter = 0
		fire()


func fire() -> void:
	var projectile := _projectile_scene.instantiate() as Node2D
	projectile.global_position = global_position
	projectile.direction = _fire_direction
	if weapon_data:
		projectile.speed = weapon_data.projectile_speed
		projectile.damage = weapon_data.damage
	# Add to scene tree (level root, not weapon mount, so it doesn't follow the ship)
	get_tree().current_scene.add_child(projectile)
	AudioManager.play_color(color_name)


func set_fire_direction(dir: Vector2) -> void:
	_fire_direction = dir.normalized()
