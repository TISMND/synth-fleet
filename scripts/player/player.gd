extends CharacterBody2D
## Player ship — movement, weapon mounts, health, energy.

signal health_changed(hull: int, shield: int)
signal energy_changed(current: int, maximum: int)
signal destroyed()

@export var move_speed: float = 400.0
@export var hull_max: int = 100
@export var shield_max: int = 50
@export var shield_regen_rate: float = 5.0  # per second
@export var shield_regen_delay: float = 2.0  # seconds after last hit
@export var energy_multiplier: int = 5

var forward_mount: Marker2D
var back_mount: Marker2D
var left_mount: Marker2D
var right_mount: Marker2D
var special_mount: Marker2D

var hull: int
var shield: int
var _shield_regen_timer: float = 0.0
var _shield_regen_accum: float = 0.0
var _weapons: Dictionary = {}  # mount_name -> WeaponBase node

var current_energy: int
var max_energy: int
var energy_regen_rate: float
var _energy_regen_accum: float = 0.0

# Screen bounds (set in _ready based on viewport)
var _bounds: Rect2


func _ready() -> void:
	forward_mount = $ForwardMount
	back_mount = $BackMount
	left_mount = $LeftMount
	right_mount = $RightMount
	special_mount = $SpecialMount

	hull = hull_max
	shield = shield_max

	max_energy = GameState.generator_power * energy_multiplier
	energy_regen_rate = float(GameState.generator_power)
	current_energy = max_energy

	var vp_size := get_viewport().get_visible_rect().size
	# Inset by 16px so sprite doesn't clip edge
	_bounds = Rect2(16, 16, vp_size.x - 32, vp_size.y - 32)


func _physics_process(delta: float) -> void:
	# Movement
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"),
	)
	if input.length() > 1.0:
		input = input.normalized()
	velocity = input * move_speed
	move_and_slide()

	# Clamp to screen bounds
	global_position = global_position.clamp(_bounds.position, _bounds.end)

	# Shield regen (float accumulator to avoid int truncation)
	if _shield_regen_timer > 0.0:
		_shield_regen_timer -= delta
	elif shield < shield_max:
		_shield_regen_accum += shield_regen_rate * delta
		var regen_amount := int(_shield_regen_accum)
		if regen_amount > 0:
			_shield_regen_accum -= regen_amount
			shield = mini(shield + regen_amount, shield_max)
			health_changed.emit(hull, shield)

	# Energy regen
	if current_energy < max_energy:
		_energy_regen_accum += energy_regen_rate * delta
		var energy_amount := int(_energy_regen_accum)
		if energy_amount > 0:
			_energy_regen_accum -= energy_amount
			current_energy = mini(current_energy + energy_amount, max_energy)
			energy_changed.emit(current_energy, max_energy)


func can_spend_energy(amount: int) -> bool:
	return current_energy >= amount


func spend_energy(amount: int) -> bool:
	if current_energy < amount:
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	return true


func take_damage(amount: int) -> void:
	_shield_regen_timer = shield_regen_delay
	var remaining := amount
	if shield > 0:
		var absorbed := mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0:
		hull -= remaining
	health_changed.emit(hull, shield)
	if hull <= 0:
		destroyed.emit()


func attach_weapon(mount_name: String, weapon_node: Node) -> void:
	var mount: Marker2D = get_node_or_null(mount_name.capitalize() + "Mount")
	if not mount:
		push_warning("No mount named: " + mount_name)
		return
	if mount_name in _weapons:
		_weapons[mount_name].queue_free()
	mount.add_child(weapon_node)
	_weapons[mount_name] = weapon_node
