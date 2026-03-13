extends Node2D
## Player ship — renders neon lines from ShipData, handles movement, health, and owns hardpoint controllers.

signal died

var ship_data: ShipData = null
var hull: int = 100
var hull_max: int = 100
var shield: float = 50.0
var shield_max: int = 50
var shield_regen: float = 5.0
var speed: float = 400.0
var _cell_size: float = 3.0
var _hardpoint_controllers: Array = []
var _player_area: Area2D = null
var _hud: CanvasLayer = null
var _weapon_data_per_hp: Array = []


func setup(ship: ShipData, loadout: LoadoutData, proj_container: Node2D) -> void:
	ship_data = ship
	var stats: Dictionary = ship_data.stats
	hull_max = int(stats.get("hull_max", 100))
	hull = hull_max
	shield_max = int(stats.get("shield_max", 50))
	shield = float(shield_max)
	speed = float(stats.get("speed", 400))
	shield_regen = float(stats.get("shield_regen", 5.0))

	# Apply device modifiers
	for slot_key in GameState.device_config:
		var device_id: String = str(GameState.device_config[slot_key])
		if device_id == "":
			continue
		var dev: DeviceData = DeviceDataManager.load_by_id(device_id)
		if dev:
			var mods: Dictionary = dev.stats_modifiers
			shield_max += int(mods.get("shield_max", 0))
			hull_max += int(mods.get("hull_max", 0))
			speed += float(mods.get("speed", 0))
	shield = float(shield_max)
	hull = hull_max

	# Compute grid center for offset
	var grid_center: Vector2 = Vector2(ship_data.grid_size.x / 2.0, ship_data.grid_size.y / 2.0)

	# Create hardpoint controllers from loadout assignments
	var assignments: Dictionary = loadout.hardpoint_assignments
	for hp in ship_data.hardpoints:
		var hp_id: String = str(hp.get("id", ""))
		var gp: Array = hp.get("grid_pos", [0, 0])
		var dir_deg: float = float(hp.get("direction_deg", 0.0))
		var hp_pos: Vector2 = (Vector2(float(gp[0]), float(gp[1])) - grid_center) * _cell_size
		var hp_label: String = str(hp.get("label", hp_id))

		var assignment: Dictionary = assignments.get(hp_id, {})
		var weapon_id: String = str(assignment.get("weapon_id", ""))
		if weapon_id == "":
			continue
		var weapon: WeaponData = WeaponDataManager.load_by_id(weapon_id)
		if not weapon:
			continue

		var stages: Array = assignment.get("stages", [])
		var controller := Node2D.new()
		controller.set_script(load("res://scripts/game/hardpoint_controller.gd"))
		controller.position = hp_pos
		add_child(controller)
		controller.setup(weapon, stages, dir_deg, proj_container)
		# Hardpoints start OFF — no start_sequencer() call
		_hardpoint_controllers.append(controller)
		_weapon_data_per_hp.append({
			"label": hp_label,
			"weapon": weapon,
		})

	# Player collision area for contact damage
	_player_area = Area2D.new()
	_player_area.collision_layer = 1
	_player_area.collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	_player_area.add_child(shape)
	_player_area.area_entered.connect(_on_contact)
	add_child(_player_area)


func _process(delta: float) -> void:
	# Input movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += input_dir * speed * delta
	# Clamp to screen
	position.x = clampf(position.x, 50.0, 1870.0)
	position.y = clampf(position.y, 50.0, 1030.0)
	# Shield regen
	shield = minf(shield + shield_regen * delta, float(shield_max))


func _input(event: InputEvent) -> void:
	# Individual hardpoint toggles (1-9)
	for i in mini(_hardpoint_controllers.size(), 9):
		var action: String = "hardpoint_" + str(i + 1)
		if event.is_action_pressed(action):
			_hardpoint_controllers[i].cycle_stage()
			_update_hud_hardpoints()
			return

	# All hardpoints up
	if event.is_action_pressed("hardpoints_up"):
		for c in _hardpoint_controllers:
			c.raise_stage()
		_update_hud_hardpoints()
		return

	# All hardpoints down
	if event.is_action_pressed("hardpoints_down"):
		for c in _hardpoint_controllers:
			c.lower_stage()
		_update_hud_hardpoints()
		return

	# All hardpoints off
	if event.is_action_pressed("hardpoints_off"):
		for c in _hardpoint_controllers:
			c.set_stage(-1)
		_update_hud_hardpoints()
		return

	# All hardpoints max
	if event.is_action_pressed("hardpoints_max"):
		for c in _hardpoint_controllers:
			c.set_stage(c.get_max_stage())
		_update_hud_hardpoints()
		return


func _update_hud_hardpoints() -> void:
	if not _hud or not _hud.has_method("update_hardpoints"):
		return
	var data: Array = []
	for i in _hardpoint_controllers.size():
		var controller: Node2D = _hardpoint_controllers[i]
		var hp_info: Dictionary = _weapon_data_per_hp[i]
		var weapon: WeaponData = hp_info["weapon"]
		data.append({
			"label": hp_info["label"],
			"weapon_name": weapon.display_name if weapon.display_name != "" else weapon.id,
			"color": Color(weapon.color),
			"stage": controller.get_stage(),
			"max_stage": controller.get_max_stage(),
		})
	_hud.update_hardpoints(data)


func take_damage(amount: int) -> void:
	var remaining: int = amount
	if shield > 0.0:
		var absorbed: int = mini(remaining, int(shield))
		shield -= float(absorbed)
		remaining -= absorbed
	hull -= remaining
	if hull <= 0:
		hull = 0
		died.emit()


func stop_all() -> void:
	for c in _hardpoint_controllers:
		if c.has_method("stop_sequencer"):
			c.stop_sequencer()


func _on_contact(area: Area2D) -> void:
	take_damage(15)


func _draw() -> void:
	if not ship_data:
		return
	var grid_center: Vector2 = Vector2(ship_data.grid_size.x / 2.0, ship_data.grid_size.y / 2.0)
	# Draw ship lines with neon glow
	for line_data in ship_data.lines:
		var from_arr: Array = line_data["from"]
		var to_arr: Array = line_data["to"]
		var col_hex: String = str(line_data.get("color", "#00FFFF"))
		var col: Color = Color(col_hex)
		var a: Vector2 = (Vector2(float(from_arr[0]), float(from_arr[1])) - grid_center) * _cell_size
		var b: Vector2 = (Vector2(float(to_arr[0]), float(to_arr[1])) - grid_center) * _cell_size
		_draw_neon_line(a, b, col)
	# Draw hardpoint markers
	for hp in ship_data.hardpoints:
		var gp: Array = hp.get("grid_pos", [0, 0])
		var pos: Vector2 = (Vector2(float(gp[0]), float(gp[1])) - grid_center) * _cell_size
		draw_circle(pos, 3.0, Color(1.0, 0.7, 0.2, 0.6))


func _draw_neon_line(a: Vector2, b: Vector2, col: Color) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var w: float = 2.0 + 6.0 * t
		var alpha: float = (1.0 - t) * 0.3
		draw_line(a, b, Color(col, alpha), w)
	draw_line(a, b, col, 2.0)
	draw_line(a, b, Color(1, 1, 1, 0.6), 1.0)
