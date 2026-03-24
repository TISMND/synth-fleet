class_name EnemyWeaponController
extends Node
## Enemy firing system using HardpointController for beat-synced, styled projectiles.
## Loads a WeaponData by weapon_id, fires downward (180°) using the weapon's
## loop, triggers, projectile/beam style, and effects — same pipeline as player weapons.

var projectile_color: Color = Color(1.0, 0.3, 0.5)
var weapons_enabled: bool = true

var _controller: HardpointController = null
var _weapon_data: WeaponData = null
var _fire_point: Node2D = null


func setup(ship_data: ShipData, enemy_node: Node2D, _player: Node2D, proj_container: Node2D) -> void:
	# Load weapon data
	if ship_data.weapon_id == "":
		return
	_weapon_data = WeaponDataManager.load_by_id(ship_data.weapon_id)
	if not _weapon_data:
		return

	# Create a fire point at the enemy's position (HardpointController uses global_position)
	_fire_point = Node2D.new()
	enemy_node.add_child(_fire_point)

	# Create HardpointController with the weapon, firing downward (180° + weapon's angle offset)
	_controller = HardpointController.new()
	_controller.is_enemy = true
	_fire_point.add_child(_controller)
	_controller.setup(_weapon_data, 180.0 + _weapon_data.direction_deg, proj_container)

	# Start the new loop synced to any already-playing loop
	var loop_id: String = _controller.get_loop_id()
	if LoopMixer.has_loop(loop_id):
		LoopMixer.start_loop(loop_id)
	if weapons_enabled:
		_controller.activate()


func set_weapons_enabled(enabled: bool) -> void:
	weapons_enabled = enabled
	if _controller:
		if enabled:
			_controller.activate()
		else:
			_controller.deactivate()


func cleanup() -> void:
	if _controller:
		_controller.cleanup()
		_controller = null
	if _fire_point and is_instance_valid(_fire_point):
		_fire_point.queue_free()
		_fire_point = null
