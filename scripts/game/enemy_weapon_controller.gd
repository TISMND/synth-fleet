class_name EnemyWeaponController
extends Node
## Enemy firing system using HardpointController for beat-synced, styled projectiles.
## Loads a WeaponData by weapon_id, fires downward (180°) using the weapon's
## loop, triggers, projectile/beam style, and effects — same pipeline as player weapons.
## Supports multiple hardpoint offsets — same weapon duplicated at each position.

var projectile_color: Color = Color(1.0, 0.3, 0.5)
var weapons_enabled: bool = true

var _controllers: Array[HardpointController] = []
var _weapon_data: WeaponData = null
var _fire_points: Array[Node2D] = []


func setup(ship_data: ShipData, enemy_node: Node2D, _player: Node2D, proj_container: Node2D) -> void:
	# Load weapon data
	if ship_data.weapon_id == "":
		return
	_weapon_data = WeaponDataManager.load_by_id(ship_data.weapon_id)
	if not _weapon_data:
		return

	# Determine fire point offsets — empty array means single center hardpoint
	var offsets: Array = ship_data.hardpoint_offsets
	if offsets.size() == 0:
		offsets = [[0, 0]]

	# Create a fire point + HardpointController at each offset
	for offset in offsets:
		var ox: float = float(offset[0]) if offset is Array and offset.size() >= 1 else 0.0
		var oy: float = float(offset[1]) if offset is Array and offset.size() >= 2 else 0.0

		var fire_point := Node2D.new()
		fire_point.position = Vector2(ox, oy)
		enemy_node.add_child(fire_point)
		_fire_points.append(fire_point)

		var controller := HardpointController.new()
		controller.is_enemy = true
		fire_point.add_child(controller)
		controller.setup(_weapon_data, 180.0 + _weapon_data.direction_deg, proj_container)
		_controllers.append(controller)

	_start_loops_and_activate()


func setup_with_overrides(ship_data: ShipData, overrides: Array, enemy_node: Node2D, _player: Node2D, proj_container: Node2D) -> void:
	## Setup with per-hardpoint weapon overrides from BossData.
	## Each override: {hardpoint_index: int, weapon_id: String}
	var offsets: Array = ship_data.hardpoint_offsets
	if offsets.size() == 0:
		offsets = [[0, 0]]

	# Build a map of hardpoint_index → weapon_id from overrides
	var override_map: Dictionary = {}
	for ovr in overrides:
		var d: Dictionary = ovr as Dictionary
		var idx: int = int(d.get("hardpoint_index", 0))
		var wid: String = str(d.get("weapon_id", ""))
		if wid != "":
			override_map[idx] = wid

	# Create a fire point + HardpointController at each hardpoint that has an override
	for i in range(offsets.size()):
		if not override_map.has(i):
			continue
		var weapon_id: String = override_map[i]
		var weapon: WeaponData = WeaponDataManager.load_by_id(weapon_id)
		if not weapon:
			push_warning("EnemyWeaponController: weapon '%s' not found for hardpoint %d" % [weapon_id, i])
			continue

		var offset: Variant = offsets[i]
		var ox: float = float(offset[0]) if offset is Array and offset.size() >= 1 else 0.0
		var oy: float = float(offset[1]) if offset is Array and offset.size() >= 2 else 0.0

		var fire_point := Node2D.new()
		fire_point.position = Vector2(ox, oy)
		enemy_node.add_child(fire_point)
		_fire_points.append(fire_point)

		var controller := HardpointController.new()
		controller.is_enemy = true
		fire_point.add_child(controller)
		controller.setup(weapon, 180.0 + weapon.direction_deg, proj_container)
		_controllers.append(controller)

	_start_loops_and_activate()


func _start_loops_and_activate() -> void:
	# Start loops and activate controllers
	for c in _controllers:
		var loop_id: String = c.get_loop_id()
		if LoopMixer.has_loop(loop_id):
			LoopMixer.start_loop(loop_id)
	if weapons_enabled:
		for c in _controllers:
			c.activate()


func set_weapons_enabled(enabled: bool) -> void:
	weapons_enabled = enabled
	for c in _controllers:
		if enabled:
			c.activate()
		else:
			c.deactivate()


func cleanup() -> void:
	for c in _controllers:
		c.cleanup()
	_controllers.clear()
	for fp in _fire_points:
		if fp and is_instance_valid(fp):
			fp.queue_free()
	_fire_points.clear()
