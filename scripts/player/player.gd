extends CharacterBody2D
## Player ship — movement, weapon mounts, health.

signal health_changed(hull: int, shield: int)
signal destroyed()

@export var move_speed: float = 400.0
@export var hull_max: int = 100
@export var shield_max: int = 50
@export var shield_regen_rate: float = 5.0  # per second
@export var shield_regen_delay: float = 2.0  # seconds after last hit

@onready var forward_mount: Marker2D = $ForwardMount
@onready var back_mount: Marker2D = $BackMount
@onready var left_mount: Marker2D = $LeftMount
@onready var right_mount: Marker2D = $RightMount
@onready var special_mount: Marker2D = $SpecialMount

var hull: int
var shield: int
var _shield_regen_timer: float = 0.0
var _weapons: Dictionary = {}  # mount_name -> WeaponBase node

# Screen bounds (set in _ready based on viewport)
var _bounds: Rect2


func _ready() -> void:
	hull = hull_max
	shield = shield_max
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

	# Shield regen
	if _shield_regen_timer > 0.0:
		_shield_regen_timer -= delta
	elif shield < shield_max:
		shield = mini(shield + int(shield_regen_rate * delta), shield_max)
		health_changed.emit(hull, shield)


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
