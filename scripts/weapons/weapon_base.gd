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
var _muzzle_flash_scene: PackedScene
var _ring_effect_scene: PackedScene

const COLOR_MAP := {
	"cyan": Color(0, 1, 1),
	"magenta": Color(1, 0, 1),
	"yellow": Color(1, 1, 0),
	"green": Color(0, 1, 0.5),
	"orange": Color(1, 0.5, 0),
	"red": Color(1, 0.2, 0.2),
	"blue": Color(0.3, 0.3, 1),
	"white": Color(1, 1, 1),
}

# Pattern playback
var pattern: WeaponPattern = null
var preview_mode: bool = false
var _pattern_slot: int = 0
var _eighth_tick: int = 0  # counts eighth-note ticks within a beat


func _ready() -> void:
	_projectile_scene = preload("res://scenes/game/projectile.tscn")
	_muzzle_flash_scene = preload("res://scenes/effects/muzzle_flash.tscn")
	_ring_effect_scene = preload("res://scenes/effects/ring_effect.tscn")
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
		if weapon_data.effect_profile:
			projectile.effect_profile = weapon_data.effect_profile
	var c: String = override_color if override_color != "" else color_name
	# Set neon color on projectile
	if COLOR_MAP.has(c):
		projectile.neon_color = COLOR_MAP[c]
	# Add to scene tree (level root, not weapon mount, so it doesn't follow the ship)
	get_tree().current_scene.add_child(projectile)
	# Muzzle flash
	if not preview_mode:
		_spawn_muzzle_flash(c)
	if weapon_data:
		AudioManager.play_weapon_sound(weapon_data, c, override_pitch)
	else:
		AudioManager.play_color(c, 0.0, override_pitch)


func _get_player() -> CharacterBody2D:
	if preview_mode:
		return null
	# Weapon -> Mount -> Player
	var mount: Node = get_parent()
	if mount:
		return mount.get_parent() as CharacterBody2D
	return null


func _spawn_muzzle_flash(c: String) -> void:
	var col: Color = COLOR_MAP.get(c, Color(0, 1, 1))
	var ep: EffectProfile = weapon_data.effect_profile if weapon_data else null

	if ep and ep.muzzle_type != "none":
		_spawn_profile_muzzle(ep, col)
		return

	if ep and ep.muzzle_type == "none":
		return

	# Default muzzle flash
	var flash := _muzzle_flash_scene.instantiate() as GPUParticles2D
	flash.global_position = global_position
	if flash.has_method("set_color"):
		flash.set_color(col)
	get_tree().current_scene.add_child(flash)


func _spawn_profile_muzzle(ep: EffectProfile, col: Color) -> void:
	var mp := ep.muzzle_params
	match ep.muzzle_type:
		"radial_burst":
			var md := EffectProfile.get_muzzle_defaults("radial_burst")
			var flash := _muzzle_flash_scene.instantiate() as GPUParticles2D
			flash.global_position = global_position
			flash.amount = int(mp.get("particle_count", md["particle_count"]))
			flash.lifetime = mp.get("lifetime", md["lifetime"])
			var mat := flash.process_material as ParticleProcessMaterial
			if mat:
				mat = mat.duplicate() as ParticleProcessMaterial
				mat.color = col
				mat.spread = mp.get("spread_angle", md["spread_angle"]) / 2.0
				mat.initial_velocity_max = mp.get("velocity_max", md["velocity_max"])
				mat.initial_velocity_min = mat.initial_velocity_max * 0.5
				flash.process_material = mat
			get_tree().current_scene.add_child(flash)
		"directional_flash":
			var md := EffectProfile.get_muzzle_defaults("directional_flash")
			var flash := _muzzle_flash_scene.instantiate() as GPUParticles2D
			flash.global_position = global_position
			flash.amount = int(mp.get("particle_count", md["particle_count"]))
			flash.lifetime = mp.get("lifetime", md["lifetime"])
			var mat := flash.process_material as ParticleProcessMaterial
			if mat:
				mat = mat.duplicate() as ParticleProcessMaterial
				mat.color = col
				mat.spread = mp.get("spread_angle", md["spread_angle"]) / 2.0
				mat.initial_velocity_max = mp.get("velocity_max", md["velocity_max"])
				mat.initial_velocity_min = mat.initial_velocity_max * 0.6
				flash.process_material = mat
			get_tree().current_scene.add_child(flash)
		"ring_pulse":
			var md := EffectProfile.get_muzzle_defaults("ring_pulse")
			var ring := _ring_effect_scene.instantiate() as RingEffect
			ring.global_position = global_position
			ring.radius_end = mp.get("radius_end", md["radius_end"])
			ring.lifetime = mp.get("lifetime", md["lifetime"])
			ring.segments = int(mp.get("segments", md["segments"]))
			ring.line_width = mp.get("line_width", md["line_width"])
			ring.set_color(col)
			get_tree().current_scene.add_child(ring)
		"spiral_burst":
			var md := EffectProfile.get_muzzle_defaults("spiral_burst")
			var flash := _muzzle_flash_scene.instantiate() as GPUParticles2D
			flash.global_position = global_position
			flash.amount = int(mp.get("particle_count", md["particle_count"]))
			flash.lifetime = mp.get("lifetime", md["lifetime"])
			var mat := flash.process_material as ParticleProcessMaterial
			if mat:
				mat = mat.duplicate() as ParticleProcessMaterial
				mat.color = col
				mat.spread = 180.0
				mat.initial_velocity_max = mp.get("velocity_max", md["velocity_max"])
				mat.initial_velocity_min = mat.initial_velocity_max * 0.5
				mat.angular_velocity_max = mp.get("spiral_speed", md["spiral_speed"]) * 60.0
				flash.process_material = mat
			get_tree().current_scene.add_child(flash)


func set_fire_direction(dir: Vector2) -> void:
	_fire_direction = dir.normalized()


func load_pattern_from_slots(slot_array: Array) -> void:
	pattern = WeaponPattern.new()
	for i in mini(slot_array.size(), WeaponPattern.SLOTS):
		if slot_array[i] is Dictionary and not slot_array[i].is_empty():
			pattern.slots[i] = slot_array[i].duplicate()
	_pattern_slot = 0
