extends Node2D
## Player ship — chrome Stiletto rendering with banking, movement, health, and hardpoint controllers.

signal died

var ship_data: ShipData = null
var hull: float = 8.0
var hull_max: float = 8.0
var shield: float = 10.0
var shield_max: float = 10.0
var shield_regen: float = 1.0
var thermal: float = 0.0
var thermal_max: float = 6.0
var electric: float = 8.0
var electric_max: float = 8.0
var speed: float = 400.0
var _hardpoint_controllers: Array = []
var _core_controllers: Array = []  # PowerCoreController instances
var _core_data_per_slot: Array = []  # [{label, pc}]
var _device_controllers: Array = []  # DeviceController instances
var _device_data_per_slot: Array = []  # [{label, device}]
var _player_area: Area2D = null
var _hud: CanvasLayer = null
var _weapon_data_per_hp: Array = []
var _space_state: int = 0  # 0=all off, 1=all on

# Banking + rendering
var _bank: float = 0.0
var _prev_x: float = 0.0
var _ship_renderer: ShipRenderer = null

const THERMAL_COOLING_RATE: float = 1.0  # segments/sec passive cooling


func setup(ship: ShipData, loadout: LoadoutData, proj_container: Node2D) -> void:
	ship_data = ship
	var stats: Dictionary = ship_data.stats
	hull_max = float(stats.get("hull_segments", 8))
	hull = hull_max
	shield_max = float(stats.get("shield_segments", 10))
	shield = shield_max
	thermal_max = float(stats.get("thermal_segments", 6))
	electric_max = float(stats.get("electric_segments", 8))
	speed = float(stats.get("speed", 400))
	shield_regen = float(stats.get("shield_regen", 1.0))

	# Ship renderer
	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = _resolve_ship_id(ship_data)
	_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	add_child(_ship_renderer)

	# VFX hit effects
	var vfx: VfxConfig = VfxConfigManager.load_config()
	_ship_renderer.hull_peak_color = Color(vfx.hull_peak_r, vfx.hull_peak_g, vfx.hull_peak_b, 1.0)
	_ship_renderer.hull_blink_speed = vfx.hull_blink_speed
	_ship_renderer.hull_flash_duration = vfx.hull_duration
	var bubble := ShieldBubbleEffect.new()
	bubble.shield_color = Color(vfx.shield_color_r, vfx.shield_color_g, vfx.shield_color_b)
	bubble.flash_duration = vfx.shield_duration
	bubble.radius_mult = vfx.shield_radius_mult
	bubble.intensity = vfx.shield_intensity
	bubble.ship_radius = ShipRenderer.get_ship_scale(_ship_renderer.ship_id) * 50.0
	bubble.name = "ShieldBubble"
	add_child(bubble)

	# Create hardpoint controllers from loadout assignments — all fire from center
	var assignments: Dictionary = loadout.hardpoint_assignments
	var hp_index: int = 0
	for hp in ship_data.hardpoints:
		var hp_id: String = str(hp.get("id", ""))
		var hp_label: String = str(hp.get("label", hp_id))

		var assignment: Dictionary = assignments.get(hp_id, {})
		var weapon_id: String = str(assignment.get("weapon_id", ""))
		if weapon_id == "":
			hp_index += 1
			continue
		var weapon: WeaponData = WeaponDataManager.load_by_id(weapon_id)
		if not weapon:
			hp_index += 1
			continue
		var controller := Node2D.new()
		controller.set_script(load("res://scripts/game/hardpoint_controller.gd"))
		controller.position = Vector2.ZERO
		add_child(controller)
		controller.setup(weapon, weapon.direction_deg, proj_container, hp_index)
		controller.bar_effect_fired.connect(apply_bar_effects)
		# Hardpoints start deactivated
		_hardpoint_controllers.append(controller)
		_weapon_data_per_hp.append({
			"label": hp_label,
			"weapon": weapon,
		})
		hp_index += 1

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

	_prev_x = position.x

	# Create power core controllers from GameState internal slots
	for i in 3:
		var slot_key: String = "int_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		var pc: PowerCoreData = PowerCoreDataManager.load_by_id(device_id)
		if not pc or pc.loop_file_path == "":
			continue
		var controller := PowerCoreController.new()
		add_child(controller)
		controller.setup(pc, i)
		controller.bar_effect_fired.connect(apply_bar_effects)
		controller.pulse_triggered.connect(_on_core_pulse)
		_core_controllers.append(controller)
		_core_data_per_slot.append({
			"label": "CORE " + str(i + 1),
			"pc": pc,
		})

	# Create device controllers from GameState dev slots
	for i in 2:
		var slot_key: String = "dev_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		var device: DeviceData = DeviceDataManager.load_by_id(device_id)
		if not device or device.loop_file_path == "":
			continue
		var controller := DeviceController.new()
		add_child(controller)
		controller.setup(device, i, self)
		controller.bar_effect_fired.connect(apply_bar_effects)
		_device_controllers.append(controller)
		_device_data_per_slot.append({
			"label": "DEV " + str(i + 1),
			"device": device,
		})


func _process(delta: float) -> void:
	# Input movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += input_dir * speed * delta
	# Clamp to screen
	position.x = clampf(position.x, 50.0, 1870.0)
	position.y = clampf(position.y, 50.0, 936.0)
	# Shield regen
	shield = minf(shield + shield_regen * delta, shield_max)
	# Passive thermal cooling
	thermal = maxf(thermal - THERMAL_COOLING_RATE * delta, 0.0)

	# Banking animation from horizontal velocity
	var velocity_x: float = (position.x - _prev_x) / maxf(delta, 0.001)
	_prev_x = position.x
	var target_bank: float = clampf(-velocity_x / maxf(speed, 1.0), -1.0, 1.0)
	_bank = lerpf(_bank, target_bank, minf(delta * 8.0, 1.0))
	if _ship_renderer:
		_ship_renderer.bank = _bank


func _input(event: InputEvent) -> void:
	# Individual hardpoint toggles (1-9)
	for i in mini(_hardpoint_controllers.size(), 9):
		var action: String = "hardpoint_" + str(i + 1)
		if event.is_action_pressed(action):
			_hardpoint_controllers[i].toggle()
			_update_hud_hardpoints()
			return

	# Power core toggles (E=core_1, R=core_2, F=core_3)
	for i in mini(_core_controllers.size(), 3):
		var action: String = "core_" + str(i + 1)
		if event.is_action_pressed(action):
			_core_controllers[i].toggle()
			_update_hud_cores()
			return

	# Device toggles (T=device_1, G=device_2)
	for i in mini(_device_controllers.size(), 2):
		var action: String = "device_" + str(i + 1)
		if event.is_action_pressed(action):
			_device_controllers[i].toggle()
			_update_hud_devices()
			return

	# Space: toggle all on/off (weapons + cores)
	if event.is_action_pressed("hardpoints_max"):
		_space_state = 1 - _space_state
		for c in _hardpoint_controllers:
			if _space_state == 1:
				c.activate()
			else:
				c.deactivate()
		for c in _core_controllers:
			if _space_state == 1:
				c.activate()
			else:
				c.deactivate()
		for c in _device_controllers:
			if _space_state == 1:
				c.activate()
			else:
				c.deactivate()
		_update_hud_hardpoints()
		_update_hud_cores()
		_update_hud_devices()
		return

	# Deactivate all (C)
	if event.is_action_pressed("hardpoints_off"):
		for c in _hardpoint_controllers:
			c.deactivate()
		for c in _core_controllers:
			c.deactivate()
		for c in _device_controllers:
			c.deactivate()
		_update_hud_hardpoints()
		_update_hud_cores()
		_update_hud_devices()
		return

	# Combo presets
	var presets: Array = KeyBindingManager.get_combo_presets()
	for pi in presets.size():
		var action: String = "combo_preset_" + str(pi)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			_apply_combo_pattern(presets[pi].get("pattern", {}) as Dictionary)
			return


func _apply_combo_pattern(pattern: Dictionary) -> void:
	# Apply ext slots to hardpoint controllers
	var hp_idx: int = 0
	for i in 3:
		var slot_key: String = "ext_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id == "":
			continue
		if hp_idx < _hardpoint_controllers.size():
			var on: bool = pattern.get(slot_key, false)
			if on:
				_hardpoint_controllers[hp_idx].activate()
			else:
				_hardpoint_controllers[hp_idx].deactivate()
		hp_idx += 1

	# Apply int slots to core controllers
	var core_idx: int = 0
	for i in 3:
		var slot_key: String = "int_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		if core_idx < _core_controllers.size():
			var on: bool = pattern.get(slot_key, false)
			if on:
				_core_controllers[core_idx].activate()
			else:
				_core_controllers[core_idx].deactivate()
		core_idx += 1

	# Apply dev slots to device controllers
	var dev_idx: int = 0
	for i in 2:
		var slot_key: String = "dev_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		if dev_idx < _device_controllers.size():
			var on: bool = pattern.get(slot_key, false)
			if on:
				_device_controllers[dev_idx].activate()
			else:
				_device_controllers[dev_idx].deactivate()
		dev_idx += 1

	_update_hud_hardpoints()
	_update_hud_cores()
	_update_hud_devices()


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
			"color": Color.CYAN,
			"active": controller.is_active(),
		})
	_hud.update_hardpoints(data)


func take_damage(amount: float) -> void:
	var remaining: float = amount
	if shield > 0.0:
		var absorbed: float = minf(remaining, shield)
		shield -= absorbed
		remaining -= absorbed
		SfxPlayer.play("player_shield_hit")
		var bubble: ShieldBubbleEffect = get_node_or_null("ShieldBubble") as ShieldBubbleEffect
		if bubble:
			bubble.trigger()
	if remaining > 0.0:
		hull = maxf(hull - remaining, 0.0)
		SfxPlayer.play("player_hull_hit")
		if _ship_renderer:
			_ship_renderer.trigger_hull_flash()
	if hull <= 0.0:
		died.emit()


func _update_hud_cores() -> void:
	if not _hud or not _hud.has_method("update_cores"):
		return
	var data: Array = []
	for i in _core_controllers.size():
		var controller: PowerCoreController = _core_controllers[i]
		var core_info: Dictionary = _core_data_per_slot[i]
		var pc: PowerCoreData = core_info["pc"]
		var key_label: String = KeyBindingManager.get_key_label_for_slot("int_" + str(i))
		data.append({
			"label": core_info["label"],
			"core_name": pc.display_name if pc.display_name != "" else pc.id,
			"color": Color(0.6, 0.4, 1.0),
			"active": controller.is_active(),
			"key": key_label,
		})
	_hud.update_cores(data)


func _on_core_pulse(bar_types: Array) -> void:
	if not _hud or not _hud.has_method("pulse_bar"):
		return
	for bar_type in bar_types:
		_hud.pulse_bar(str(bar_type).to_upper())


func _update_hud_devices() -> void:
	if not _hud or not _hud.has_method("update_devices"):
		return
	var data: Array = []
	for i in _device_controllers.size():
		var controller: DeviceController = _device_controllers[i]
		var dev_info: Dictionary = _device_data_per_slot[i]
		var device: DeviceData = dev_info["device"]
		var key_label: String = KeyBindingManager.get_key_label_for_slot("dev_" + str(i))
		data.append({
			"label": dev_info["label"],
			"device_name": device.display_name if device.display_name != "" else device.id,
			"color": device.color_override if device.color_override != Color.WHITE else Color(0.0, 0.8, 1.0),
			"active": controller.is_active(),
			"key": key_label,
		})
	_hud.update_devices(data)


func stop_all() -> void:
	for c in _hardpoint_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
		if c.has_method("cleanup"):
			c.cleanup()
	for c in _core_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
		if c.has_method("cleanup"):
			c.cleanup()
	for c in _device_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
		if c.has_method("cleanup"):
			c.cleanup()


func apply_bar_effects(effects: Dictionary) -> void:
	for bar_type in effects:
		var delta_val: float = float(effects[bar_type])
		match str(bar_type):
			"shield":
				shield = clampf(shield + delta_val, 0.0, shield_max)
			"hull":
				hull = clampf(hull + delta_val, 0.0, hull_max)
			"thermal":
				thermal = clampf(thermal + delta_val, 0.0, thermal_max)
			"electric":
				electric = clampf(electric + delta_val, 0.0, electric_max)


func _on_contact(area: Area2D) -> void:
	take_damage(1.5)


static func _resolve_ship_id(ship: ShipData) -> int:
	var name_to_id: Dictionary = {
		"switchblade": 0, "phantom": 1, "mantis": 2, "corsair": 3,
		"stiletto": 4, "trident": 5, "orrery": 6, "dreadnought": 7, "bastion": 8,
	}
	var ship_id_str: String = ship.id.to_lower() if ship else ""
	if name_to_id.has(ship_id_str):
		return int(name_to_id[ship_id_str])
	return 4  # Default to stiletto
