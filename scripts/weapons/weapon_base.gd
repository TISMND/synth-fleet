class_name WeaponBase
extends Node2D
## Base class for all weapons. Listens to BeatClock, fires on its assigned
## rhythmic subdivision, and triggers AudioManager for the weapon's color.

@export var weapon_data: WeaponData
@export var subdivision: int = 1  ## 1 = quarter, 2 = eighth, 3 = triplet
@export var color_name: String = "cyan"

var _fire_direction: Vector2 = Vector2.UP
var _subdivision_counter: int = 0

var _projectile_scene: PackedScene

# Pattern playback
var pattern: WeaponPattern = null
var preview_mode: bool = false
var _pattern_slot: int = 0
var _eighth_tick: int = 0  # counts eighth-note ticks within a beat


func _ready() -> void:
	_projectile_scene = preload("res://scenes/game/projectile.tscn")
	BeatClock.beat_hit.connect(_on_beat_hit)


func _on_beat_hit(_beat_index: int) -> void:
	if pattern:
		# Pattern mode: fire two eighth notes per beat
		_fire_pattern_slot()
		# Schedule the second eighth note halfway through the beat
		var half_beat := BeatClock.get_beat_duration() / 2.0
		get_tree().create_timer(half_beat, false).timeout.connect(_fire_pattern_slot)
	else:
		# Legacy mode: fire on subdivision
		_subdivision_counter += 1
		if subdivision <= 1 or _subdivision_counter >= subdivision:
			_subdivision_counter = 0
			fire()


func _fire_pattern_slot() -> void:
	if not pattern:
		return
	var slot_data: Dictionary = pattern.slots[_pattern_slot]
	if not slot_data.is_empty():
		var note_color: String = slot_data.get("color", color_name)
		var note_pitch: float = slot_data.get("pitch", 1.0)
		var dir_deg: float = slot_data.get("direction_deg", 0.0)
		var dir := Vector2.UP.rotated(deg_to_rad(dir_deg))
		fire(note_color, note_pitch, dir)
	_pattern_slot = (_pattern_slot + 1) % WeaponPattern.SLOTS


func fire(override_color: String = "", override_pitch: float = 1.0, override_direction: Vector2 = Vector2.ZERO) -> void:
	if not preview_mode:
		var player := _get_player()
		if player and weapon_data:
			if not player.spend_energy(weapon_data.power_cost):
				return
	var projectile := _projectile_scene.instantiate() as Node2D
	projectile.global_position = global_position
	if override_direction != Vector2.ZERO:
		projectile.direction = override_direction
	else:
		projectile.direction = _fire_direction
	if weapon_data:
		projectile.speed = weapon_data.projectile_speed
		projectile.damage = weapon_data.damage
	# Add to scene tree (level root, not weapon mount, so it doesn't follow the ship)
	get_tree().current_scene.add_child(projectile)
	var c: String = override_color if override_color != "" else color_name
	AudioManager.play_color(c, 0.0, override_pitch)


func _get_player() -> CharacterBody2D:
	if preview_mode:
		return null
	# Weapon -> Mount -> Player
	var mount := get_parent()
	if mount:
		return mount.get_parent() as CharacterBody2D
	return null


func set_fire_direction(dir: Vector2) -> void:
	_fire_direction = dir.normalized()


func load_pattern_from_slots(slot_array: Array) -> void:
	pattern = WeaponPattern.new()
	for i in mini(slot_array.size(), WeaponPattern.SLOTS):
		if slot_array[i] is Dictionary and not slot_array[i].is_empty():
			pattern.slots[i] = slot_array[i].duplicate()
	_pattern_slot = 0
