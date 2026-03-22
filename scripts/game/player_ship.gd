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
var acceleration: float = 1200.0
var _base_speed: float = 400.0
var _base_accel: float = 1200.0
var _velocity: Vector2 = Vector2.ZERO
var _hardpoint_controllers: Array = []
var _core_controllers: Array = []  # PowerCoreController instances
var _core_data_per_slot: Array = []  # [{label, pc}]
var _device_controllers: Array = []  # DeviceController instances
var _device_data_per_slot: Array = []  # [{label, device}]
var _player_area: Area2D = null
var _hud: Control = null
var _weapon_data_per_hp: Array = []
var _space_state: int = 0  # 0=all off, 1=all on

# Banking + rendering
var _bank: float = 0.0
var _ship_renderer: ShipRenderer = null
var _electric_crisis_particles: GPUParticles2D = null  # Spark particles when electric is depleted
var _electric_crisis_active: bool = false
var _electric_overdraw: bool = false  # True when weapons tried to drain electric below 0
var _shield_at_crisis_start: float = -1.0  # Shield snapshot when engine penalty begins
var _drifting: bool = false  # Spin + coast phase (shields=0 during crisis)
var _drift_timer: float = 0.0  # Seconds since drift started
var _drift_spin_direction: float = 1.0  # +1 or -1, random
var _drift_rotation_speed: float = 0.0  # Current spin speed
var _blackout_active: bool = false  # Full blackout (darkness, HUD dim) — 3s after drift starts
var _blackout_power: float = 1.0  # CRT power level: 1.0=on, 0.0=dead
var _blackout_final_death: bool = false  # True once power hits floor — components off, text starts
var _blackout_overlay: ColorRect = null
var _blackout_lowpass: AudioEffectLowPassFilter = null
var _blackout_reverb: AudioEffectReverb = null
var _blackout_flicker_state: bool = false  # True during hard cut frames — for SFX sync
var _reboot_label: RichTextLabel = null  # DOS-style text during final death
var _reboot_text_queue: Array[String] = []  # Lines to type out (prefix ">" = fast/scroll phase)
var _reboot_text_index: int = -1  # -1 = cursor blink, 0+ = line index
var _reboot_char_index: int = 0  # Current char in current line
var _reboot_char_timer: float = 0.0  # Timer for typewriter effect
var _reboot_blink_timer: float = 0.0  # Timer for initial cursor blink
var _reboot_scrolling: bool = false  # True once we enter the ">" fast scroll phase
var _reboot_completed_lines: Array[String] = []  # Finished lines for display
signal blackout_flicker(is_cut: bool)  # Emitted each frame during blackout — hook static SFX here
signal final_power_death()  # Emitted once when power fully dies — for external systems

const THERMAL_COOLING_RATE: float = 10.0  # hp/sec passive cooling (10x scale)
const ELECTRIC_THROTTLE_THRESHOLD: float = 40.0  # Start throttling below 4 segments (40 points)
const ELECTRIC_SHIELD_BLEED_MULT: float = 1.5  # Overdraw penalty: 1.5x cost from shields
const BLACKOUT_MAX_SPIN: float = 0.2  # Max radians/sec — gentle drift
const BLACKOUT_FADE_SPEED: float = 0.196  # Power drain per second (~5s from 1.0 to 0.02)


func setup(ship: ShipData, loadout: LoadoutData, proj_container: Node2D) -> void:
	ship_data = ship
	var stats: Dictionary = ship_data.stats
	hull_max = float(stats.get("hull_hp", float(stats.get("hull_segments", 8)) * 10.0))
	hull = hull_max
	shield_max = float(stats.get("shield_hp", float(stats.get("shield_segments", 10)) * 10.0))
	shield = shield_max
	thermal_max = float(stats.get("thermal_hp", float(stats.get("thermal_segments", 6)) * 10.0))
	electric_max = float(stats.get("electric_hp", float(stats.get("electric_segments", 8)) * 10.0))
	electric = electric_max
	speed = float(stats.get("speed", 400))
	acceleration = float(stats.get("acceleration", 1200))
	_base_speed = speed
	_base_accel = acceleration
	shield_regen = float(stats.get("shield_regen", 1.0))

	# Ship renderer
	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = _resolve_ship_id(ship_data)
	_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	add_child(_ship_renderer)

	# Electric crisis VFX — spark particles when electric is depleted
	_electric_crisis_particles = GPUParticles2D.new()
	_electric_crisis_particles.z_index = 2
	_electric_crisis_particles.emitting = false
	_electric_crisis_particles.amount = 20
	_electric_crisis_particles.lifetime = 0.4
	_electric_crisis_particles.explosiveness = 0.0
	_electric_crisis_particles.randomness = 1.0
	_electric_crisis_particles.texture = VFXFactory.get_soft_circle()
	_electric_crisis_particles.scale = Vector2(0.6, 0.6)
	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_mat.emission_sphere_radius = 30.0
	spark_mat.direction = Vector3(0, 0, 0)
	spark_mat.spread = 180.0
	spark_mat.initial_velocity_min = 40.0
	spark_mat.initial_velocity_max = 120.0
	spark_mat.gravity = Vector3(0, 0, 0)
	spark_mat.damping_min = 60.0
	spark_mat.damping_max = 100.0
	spark_mat.scale_min = 0.3
	spark_mat.scale_max = 1.0
	var fade_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	fade_curve.curve = curve
	spark_mat.scale_curve = fade_curve
	spark_mat.color = Color(0.4, 0.7, 1.0, 0.9)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.6, 0.8, 1.0, 1.0))
	color_ramp.set_color(1, Color(0.2, 0.4, 1.0, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	spark_mat.color_ramp = color_tex
	_electric_crisis_particles.process_material = spark_mat
	add_child(_electric_crisis_particles)

	# Per-ship hull flash settings
	_ship_renderer.hull_flash_opacity = ship.hull_flash_opacity
	_ship_renderer.hull_blink_speed = ship.hull_blink_speed
	_ship_renderer.hull_flash_duration = ship.hull_flash_duration
	# Per-ship shield hit visual via FieldRenderer
	if ship.shield_style_id != "":
		var style: FieldStyle = FieldStyleManager.load_by_id(ship.shield_style_id)
		if style:
			var fr := FieldRenderer.new()
			var ship_radius: float = ShipRenderer.get_ship_scale(_ship_renderer.ship_id) * 50.0
			fr.setup(style, ship_radius)
			fr._stay_visible = false
			fr.visible = false
			fr.name = "ShieldField"
			add_child(fr)

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
	_player_area.collision_mask = 4 | 8  # Enemies (4) + Enemy projectiles (8)
	var col_result: Dictionary = _make_collision_shape(ship_data)
	var col_shape := CollisionShape2D.new()
	col_shape.shape = col_result["shape"]
	col_shape.rotation = float(col_result["rotation"])
	_player_area.add_child(col_shape)
	_player_area.area_entered.connect(_on_contact)
	add_child(_player_area)

	# Create core controllers from core_N slots
	for i in GameState.get_core_slot_count():
		var slot_key: String = "core_" + str(i)
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

	# Create device controllers from field_N slots
	var device_slot_idx: int = 0
	for i in GameState.get_field_slot_count():
		var slot_key: String = "field_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var device_id: String = str(slot_data.get("device_id", ""))
		if device_id == "":
			continue
		var device: DeviceData = DeviceDataManager.load_by_id(device_id)
		if not device or device.loop_file_path == "":
			continue
		var controller := DeviceController.new()
		add_child(controller)
		controller.setup(device, device_slot_idx, self)
		controller.bar_effect_fired.connect(apply_bar_effects)
		_device_controllers.append(controller)
		_device_data_per_slot.append({
			"label": "FIELD " + str(i + 1),
			"device": device,
		})
		device_slot_idx += 1

	# Apply persisted per-slot volumes from hangar settings
	_apply_stored_volumes()


func _apply_stored_volumes() -> void:
	# Weapon slots (weapon_N)
	for i in GameState.get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
		var slot_data: Dictionary = GameState.slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		if weapon_id == "":
			continue
		if i < _hardpoint_controllers.size():
			var loop_id: String = _hardpoint_controllers[i]._loop_id
			var vol: float = KeyBindingManager.get_slot_volume(slot_key)
			if loop_id != "" and vol != 0.0:
				LoopMixer.set_volume(loop_id, vol)

	# Core slots (core_N)
	for i in GameState.get_core_slot_count():
		var slot_key: String = "core_" + str(i)
		if i < _core_controllers.size():
			var loop_id: String = _core_controllers[i]._loop_id
			var vol: float = KeyBindingManager.get_slot_volume(slot_key)
			if loop_id != "" and vol != 0.0:
				LoopMixer.set_volume(loop_id, vol)

	# Field/device slots (field_N)
	for i in GameState.get_field_slot_count():
		var slot_key: String = "field_" + str(i)
		if i < _device_controllers.size():
			var loop_id: String = _device_controllers[i]._loop_id
			var vol: float = KeyBindingManager.get_slot_volume(slot_key)
			if loop_id != "" and vol != 0.0:
				LoopMixer.set_volume(loop_id, vol)


func _process(delta: float) -> void:
	# Apply device modifiers to speed/accel
	_apply_device_modifiers()

	# Electric engine penalty — kicks in once shield bleed starts (electric=0, shields draining).
	# Curve goes from full speed at crisis start → zero at shields=0, regardless of
	# what shield level was when the crisis began. Soft exponential (^0.9).
	if electric <= 0.0 and _electric_crisis_active:
		# Snapshot shield level when penalty first kicks in
		if _shield_at_crisis_start < 0.0:
			_shield_at_crisis_start = maxf(shield, 1.0)  # At least 1 to avoid div/0
		var ratio: float = clampf(shield / _shield_at_crisis_start, 0.0, 1.0)
		# Floor at 15% — engines never fully die from throttle, blackout drift takes over
		var throttle: float = maxf(sqrt(ratio), 0.15)
		speed *= throttle
		acceleration *= throttle
	elif _shield_at_crisis_start >= 0.0 and electric > 0.0:
		# Crisis over — reset snapshot
		_shield_at_crisis_start = -1.0

	# Drift/blackout — control cut, existing velocity coasts for a long time
	if _drifting:
		speed = 0.0
		acceleration = 6.0  # ~10 seconds to stop from 60px/s

	# Acceleration-based movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity: Vector2 = input_dir * speed
	_velocity = _velocity.move_toward(target_velocity, acceleration * delta)
	position += _velocity * delta
	# Clamp to screen — kill velocity on axis if clamped
	var clamped_x: float = clampf(position.x, 50.0, 1870.0)
	var clamped_y: float = clampf(position.y, 50.0, 936.0)
	if position.x != clamped_x:
		_velocity.x = 0.0
		position.x = clamped_x
	if position.y != clamped_y:
		_velocity.y = 0.0
		position.y = clamped_y
	# Shield regen is component-based only (no auto-regen)
	# Passive thermal cooling
	thermal = maxf(thermal - THERMAL_COOLING_RATE * delta, 0.0)

	# Electric depleted — spark particles
	if electric <= 0.0 and not _electric_crisis_active:
		_electric_crisis_active = true
		SfxPlayer.play("electric_sparks")
		if _electric_crisis_particles:
			_electric_crisis_particles.emitting = true
	elif electric > 0.0 and _electric_crisis_active:
		_electric_crisis_active = false
		if _electric_crisis_particles:
			_electric_crisis_particles.emitting = false

	# Drift phase — shields hit 0 during electric crisis, ship loses control
	if _electric_overdraw and electric <= 0.0 and shield <= 0.0:
		if not _drifting:
			_start_drift()
	if _drifting:
		if electric > 0.0:
			_end_drift()
		else:
			_process_drift(delta)
	# Reset overdraw flag — it's set per-frame by apply_bar_effects
	_electric_overdraw = false

	# Banking animation from horizontal velocity
	var target_bank: float = clampf(-_velocity.x / maxf(speed, 1.0), -1.0, 1.0)
	_bank = lerpf(_bank, target_bank, minf(delta * 8.0, 1.0))
	if _ship_renderer:
		_ship_renderer.bank = _bank

	# Composite ship tint from all active field devices
	if _ship_renderer and not _device_controllers.is_empty():
		var combined_r: float = 1.0
		var combined_g: float = 1.0
		var combined_b: float = 1.0
		for dc in _device_controllers:
			var controller: DeviceController = dc as DeviceController
			if controller:
				var tint: Color = controller.get_ship_tint()
				combined_r *= tint.r
				combined_g *= tint.g
				combined_b *= tint.b
		_ship_renderer.modulate = Color(combined_r, combined_g, combined_b, _ship_renderer.modulate.a)


func _input(event: InputEvent) -> void:
	# DEBUG: F9 = force power death (zero electric + shields, trigger overdraw)
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_F9:
		electric = 0.0
		shield = 0.0
		_electric_crisis_active = true
		_electric_overdraw = true
		if _electric_crisis_particles:
			_electric_crisis_particles.emitting = true
		print("[DEBUG] F9: Forced power death — electric=0, shield=0")
		return

	# Per-slot toggles using dynamic action names from KeyBindingManager
	# Weapon slots
	for i in GameState.get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
		var action: String = KeyBindingManager.get_slot_action(slot_key)
		if event.is_action_pressed(action):
			if i < _hardpoint_controllers.size():
				_hardpoint_controllers[i].toggle()
				_update_hud_hardpoints()
			return

	# Core slots
	for i in GameState.get_core_slot_count():
		var slot_key: String = "core_" + str(i)
		var action: String = KeyBindingManager.get_slot_action(slot_key)
		if event.is_action_pressed(action):
			if i < _core_controllers.size():
				_core_controllers[i].toggle()
				_update_hud_cores()
			return

	# Field slots
	for i in GameState.get_field_slot_count():
		var slot_key: String = "field_" + str(i)
		var action: String = KeyBindingManager.get_slot_action(slot_key)
		if event.is_action_pressed(action):
			if i < _device_controllers.size():
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


func _slot_key_from_label(label: String) -> String:
	## Converts a label like "CORE 2" or "FIELD 3" or "WEAPON 1" back to a slot key.
	if label.begins_with("CORE "):
		return "core_" + str(int(label.replace("CORE ", "")) - 1)
	elif label.begins_with("FIELD "):
		return "field_" + str(int(label.replace("FIELD ", "")) - 1)
	elif label.begins_with("WEAPON "):
		return "weapon_" + str(int(label.replace("WEAPON ", "")) - 1)
	return ""


func _apply_combo_pattern(pattern: Dictionary) -> void:
	# Apply weapon slots
	for i in GameState.get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
		var on: bool = pattern.get(slot_key, false)
		if i < _hardpoint_controllers.size():
			if on:
				_hardpoint_controllers[i].activate()
			else:
				_hardpoint_controllers[i].deactivate()

	# Apply core slots
	for i in GameState.get_core_slot_count():
		var slot_key: String = "core_" + str(i)
		var on: bool = pattern.get(slot_key, false)
		if i < _core_controllers.size():
			if on:
				_core_controllers[i].activate()
			else:
				_core_controllers[i].deactivate()

	# Apply field slots
	for i in GameState.get_field_slot_count():
		var slot_key: String = "field_" + str(i)
		var on: bool = pattern.get(slot_key, false)
		if i < _device_controllers.size():
			if on:
				_device_controllers[i].activate()
			else:
				_device_controllers[i].deactivate()

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


func take_damage(amount: float, skips_shields: bool = false) -> void:
	var remaining: float = amount
	if shield > 0.0 and not skips_shields:
		var absorbed: float = minf(remaining, shield)
		shield -= absorbed
		remaining -= absorbed
		SfxPlayer.play("player_shield_hit")
		var shield_field: FieldRenderer = get_node_or_null("ShieldField") as FieldRenderer
		if shield_field:
			shield_field.pulse()
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
		var slot_key: String = _slot_key_from_label(core_info["label"])
		var key_label: String = KeyBindingManager.get_key_label_for_slot(slot_key)
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
		var slot_key: String = _slot_key_from_label(dev_info["label"])
		var key_label: String = KeyBindingManager.get_key_label_for_slot(slot_key)
		data.append({
			"label": dev_info["label"],
			"device_name": device.display_name if device.display_name != "" else device.id,
			"color": _get_device_color(device),
			"active": controller.is_active(),
			"key": key_label,
		})
	_hud.update_devices(data)


# ── Drift + Blackout — electric power failure cascade ────────────────────────
# Phase 1: DRIFT — shields hit 0 from electric overdraw. Ship spins, coasts, no control.
# Phase 2: BLACKOUT — 3 seconds after drift starts. Screen darkens, HUD dims, thermal dumps.
#           (Placeholder for future CRT distortion + LED bar death animations.)

const DRIFT_TO_BLACKOUT_DELAY: float = 1.0  # Seconds of drift before blackout begins

func _start_drift() -> void:
	_drifting = true
	_drift_timer = 0.0
	_drift_rotation_speed = 0.0
	_drift_spin_direction = 1.0 if randf() > 0.5 else -1.0


func _process_drift(delta: float) -> void:
	_drift_timer += delta

	# Gradual spin — reaches max over 4 seconds
	_drift_rotation_speed = minf(_drift_rotation_speed + (BLACKOUT_MAX_SPIN / 4.0) * delta, BLACKOUT_MAX_SPIN)
	rotation += _drift_rotation_speed * _drift_spin_direction * delta

	# After delay, trigger blackout (darkness + HUD effects)
	if _drift_timer >= DRIFT_TO_BLACKOUT_DELAY and not _blackout_active:
		SfxPlayer.play("power_failure")
		_start_blackout()

	if _blackout_active:
		_process_blackout(delta)


func _start_blackout() -> void:
	_blackout_active = true
	_blackout_power = 1.0  # Starts fully powered, decays toward 0
	print("[BLACKOUT] started — power=1.0, overlay will be added to viewport")
	# Dump thermal to zero (mercy: they'll need heat to generate electric)
	thermal = 0.0
	# HUD bars stay fully visible — LED bar shutdown animation handled separately
	# Audio degradation — low-pass + reverb on Master, tied to _blackout_power
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		_blackout_lowpass = AudioEffectLowPassFilter.new()
		_blackout_lowpass.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(master_idx, _blackout_lowpass)
		_blackout_reverb = AudioEffectReverb.new()
		_blackout_reverb.room_size = 0.0
		_blackout_reverb.wet = 0.0
		_blackout_reverb.dry = 1.0
		_blackout_reverb.damping = 0.8
		AudioServer.add_bus_effect(master_idx, _blackout_reverb)
	# CRT power death overlay — inside game SubViewport. Alpha-blended black overlay
	# with distortion effects. HUD is on root viewport, unaffected.
	if not _blackout_overlay:
		var vp: Viewport = get_viewport()
		if vp:
			_blackout_overlay = ColorRect.new()
			_blackout_overlay.color = Color(0, 0, 0, 0)  # Transparent fallback if shader fails
			_blackout_overlay.z_index = 45
			_blackout_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_blackout_overlay.size = Vector2(1920, 1080)
			var shader: Shader = load("res://assets/shaders/crt_power_death.gdshader") as Shader
			if shader:
				var mat := ShaderMaterial.new()
				mat.shader = shader
				mat.set_shader_parameter("power", 1.0)
				_blackout_overlay.material = mat
			vp.add_child(_blackout_overlay)


func _process_blackout(delta: float) -> void:
	# Drive power level down — takes ~5 seconds to reach near-zero
	_blackout_power = maxf(_blackout_power - BLACKOUT_FADE_SPEED * delta, 0.02)

	# Visual — CRT shader
	if _blackout_overlay and _blackout_overlay.material is ShaderMaterial:
		var mat: ShaderMaterial = _blackout_overlay.material as ShaderMaterial
		mat.set_shader_parameter("power", _blackout_power)

	# Audio — tied to same power level
	var decay: float = 1.0 - _blackout_power
	if _blackout_lowpass:
		_blackout_lowpass.cutoff_hz = lerpf(20500.0, 600.0, decay * decay)
	if _blackout_reverb:
		_blackout_reverb.wet = decay * 0.7
		_blackout_reverb.dry = lerpf(1.0, 0.3, decay)
		_blackout_reverb.room_size = lerpf(0.0, 0.9, decay)

	# Flicker detection — mirrors shader's hard cut logic for SFX sync
	# (flickers fade out near death, matching shader's flicker_fade)
	var t: float = Time.get_ticks_msec() / 1000.0
	var flicker_fade: float = smoothstepf(0.85, 0.65, decay)
	var cut_freq: float = decay * 0.7 * flicker_fade
	var cut_roll: float = _hash_float(t * 10.0, 7.0)
	var cut_hold: float = _hash_float(t * 10.0, 19.0)
	var is_cut: bool = cut_roll < cut_freq and cut_hold < (0.4 + decay * 0.4)
	var sustained_roll: float = _hash_float(t * 2.0, 31.0)
	var sustained_cut: bool = decay > 0.5 and decay < 0.8 and sustained_roll < (decay - 0.4) * 0.9
	var flicker_now: bool = is_cut or sustained_cut
	if flicker_now != _blackout_flicker_state:
		# Flicker state changed — trigger SFX
		if flicker_now:
			SfxPlayer.play("monitor_static")
		_blackout_flicker_state = flicker_now
		blackout_flicker.emit(flicker_now)

	# Final power death — power hit the floor
	if _blackout_power <= 0.03 and not _blackout_final_death:
		_blackout_final_death = true
		_shutdown_all_components()
		SfxPlayer.play("monitor_shutoff")
		_start_reboot_sequence()
		final_power_death.emit()

	# Type out reboot text
	if _blackout_final_death:
		_process_reboot_text(delta)


func smoothstepf(edge0: float, edge1: float, x: float) -> float:
	var t_val: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t_val * t_val * (3.0 - 2.0 * t_val)


func _shutdown_all_components() -> void:
	# Kill all weapons, cores, devices — full power failure
	for c in _hardpoint_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
	for c in _core_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
	for c in _device_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
	# Mute all loops
	LoopMixer.mute_all()


func _start_reboot_sequence() -> void:
	# Lines prefixed with ">" are in the fast/scrolling reboot phase
	_reboot_text_queue = [
		"SYSTEM POWER FAILURE",
		"",
		"Diagnosing subsystems...",
		"Main reactor .......... OFFLINE",
		"Aux reactor ........... OFFLINE",
		"Backup capacitor ...... 2%%",
		"Shield generator ...... OFFLINE",
		"Weapon bus ............ NO SIGNAL",
		"Navigation ............ OFFLINE",
		"Life support .......... MINIMAL",
		"",
		">Rerouting emergency power...",
		">Activating backup capacitor...",
		">Bypassing main reactor safety...",
		">Shield generator: STANDBY",
		">Weapon bus: LOCKED",
		">Navigation: RECOVERING",
		">Thermal vents: PURGING",
		">Capacitor charge: 4%%... 8%%... 15%%",
		">Core restart sequence initiated...",
		">Regenerating power core...",
	]
	_reboot_text_index = -1  # -1 = cursor blink phase
	_reboot_char_index = 0
	_reboot_char_timer = 0.0
	_reboot_blink_timer = 0.0
	_reboot_scrolling = false

	# Create text label — on root viewport so it sits above the CRT overlay
	# Uses HDR color for bloom glow
	_reboot_label = RichTextLabel.new()
	_reboot_label.bbcode_enabled = true
	_reboot_label.scroll_active = false
	_reboot_label.z_index = 48  # Above CRT overlay (45), below HUD (50)
	_reboot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reboot_label.position = Vector2(120, 200)
	_reboot_label.size = Vector2(600, 500)
	_reboot_label.add_theme_font_size_override("normal_font_size", 16)
	# Bright green — HDR modulate for bloom glow
	_reboot_label.add_theme_color_override("default_color", Color(0.3, 1.0, 0.4))
	_reboot_label.modulate = Color(2.0, 2.0, 2.0, 1.0)  # HDR boost for bloom
	var mono_font: Font = ThemeManager.get_font("font_body")
	if mono_font:
		_reboot_label.add_theme_font_override("normal_font", mono_font)
	# CRT scanlines on the text itself
	var scanline_shader: Shader = load("res://assets/shaders/crt_scanline_text.gdshader") as Shader
	if scanline_shader:
		var scan_mat := ShaderMaterial.new()
		scan_mat.shader = scanline_shader
		_reboot_label.material = scan_mat
	_reboot_label.text = ""
	get_viewport().add_child(_reboot_label)


const REBOOT_BLINK_DURATION: float = 3.0  # Seconds of cursor blinking before text starts
const REBOOT_BLINK_RATE: float = 0.5  # Cursor blink toggle interval
const REBOOT_CHAR_SLOW: float = 0.043  # Seconds per char — diagnosis phase (140% of 0.06)
const REBOOT_CHAR_FAST: float = 0.018  # Seconds per char — reboot phase (140% of 0.025)
const REBOOT_LINE_PAUSE_SLOW: float = 0.5  # Pause between lines — diagnosis
const REBOOT_LINE_PAUSE_FAST: float = 0.2  # Pause between lines — reboot (faster turnover)
const REBOOT_HEADER_PAUSE: float = 1.0  # Longer pause after ALL-CAPS lines
const REBOOT_PARAGRAPH_PAUSE: float = 0.8  # Pause for empty lines
const REBOOT_MAX_VISIBLE_LINES: int = 14  # Max lines before scrolling

func _process_reboot_text(delta: float) -> void:
	if not _reboot_label:
		return

	# Phase -1: blinking cursor only
	if _reboot_text_index < 0:
		_reboot_blink_timer += delta
		var blink_on: bool = fmod(_reboot_blink_timer, REBOOT_BLINK_RATE * 2.0) < REBOOT_BLINK_RATE
		_reboot_label.text = "\u2588" if blink_on else ""
		if _reboot_blink_timer >= REBOOT_BLINK_DURATION:
			_reboot_text_index = 0
			_reboot_char_index = 0
			_reboot_char_timer = 0.0
			_reboot_completed_lines.clear()
		return

	if _reboot_text_index >= _reboot_text_queue.size():
		return  # All lines typed

	_reboot_char_timer += delta
	var raw_line: String = _reboot_text_queue[_reboot_text_index]

	# Check if this line starts the fast scroll phase
	if raw_line.begins_with(">") and not _reboot_scrolling:
		_reboot_scrolling = true

	# Strip the ">" prefix for display
	var current_line: String = raw_line.lstrip(">")

	# Empty line = paragraph pause
	if current_line == "":
		if _reboot_char_timer >= REBOOT_PARAGRAPH_PAUSE:
			_reboot_char_timer = 0.0
			_reboot_completed_lines.append("")
			_reboot_text_index += 1
			_reboot_char_index = 0
			_update_reboot_display("", false)
		return

	var char_speed: float = REBOOT_CHAR_FAST if _reboot_scrolling else REBOOT_CHAR_SLOW

	if _reboot_char_index < current_line.length():
		if _reboot_char_timer >= char_speed:
			_reboot_char_timer -= char_speed
			_reboot_char_index += 1
			SfxPlayer.play("reboot_char_thunk")
			var typed: String = current_line.substr(0, _reboot_char_index)
			_update_reboot_display(typed, true)
	else:
		# Line complete — show without cursor during pause, then advance
		_update_reboot_display(current_line, false)
		var is_header: bool = current_line == current_line.to_upper() and current_line.length() > 2
		var line_pause: float = REBOOT_LINE_PAUSE_FAST if _reboot_scrolling else REBOOT_LINE_PAUSE_SLOW
		var pause: float = REBOOT_HEADER_PAUSE if is_header else line_pause
		if _reboot_char_timer >= pause:
			_reboot_char_timer = 0.0
			SfxPlayer.play("reboot_line_beep")
			_reboot_completed_lines.append(current_line)
			_reboot_text_index += 1
			_reboot_char_index = 0


func _update_reboot_display(typed_portion: String, show_cursor: bool) -> void:
	if not _reboot_label:
		return
	# Build visible lines — scroll if too many
	var visible_lines: Array[String] = []
	for completed in _reboot_completed_lines:
		visible_lines.append(completed)

	# Add current typing line
	var current: String = typed_portion
	if show_cursor:
		current += "\u2588"
	visible_lines.append(current)

	# Scroll — keep only the last N lines
	while visible_lines.size() > REBOOT_MAX_VISIBLE_LINES:
		visible_lines.remove_at(0)

	_reboot_label.text = "\n".join(visible_lines)


## Hash matching the shader's hash function — keeps GDScript flicker detection in sync
func _hash_float(x: float, seed: float) -> float:
	var p := Vector3(fmod(abs(x), 1000.0) * 0.1031, fmod(abs(seed), 1000.0) * 0.1031, fmod(abs(x), 1000.0) * 0.1031)
	p = Vector3(fmod(p.x, 1.0), fmod(p.y, 1.0), fmod(p.z, 1.0))
	var d: float = p.x * (p.y + 33.33) + p.y * (p.z + 33.33) + p.z * (p.x + 33.33)
	return fmod(abs(d), 1.0)


func _end_drift() -> void:
	_drifting = false
	_drift_timer = 0.0
	_drift_rotation_speed = 0.0
	rotation = 0.0
	if _blackout_active:
		_blackout_active = false
		# HUD restoration handled by LED bar system when ready
		# Power-up: tween CRT overlay + audio back to normal
		var recovery_power: float = _blackout_power
		var lp_ref: AudioEffectLowPassFilter = _blackout_lowpass
		var rv_ref: AudioEffectReverb = _blackout_reverb
		if _blackout_overlay and _blackout_overlay.material is ShaderMaterial:
			var mat: ShaderMaterial = _blackout_overlay.material as ShaderMaterial
			var tween: Tween = create_tween()
			tween.tween_method(func(v: float) -> void:
				mat.set_shader_parameter("power", v)
				var d: float = 1.0 - v
				if lp_ref:
					lp_ref.cutoff_hz = lerpf(20500.0, 600.0, d * d)
				if rv_ref:
					rv_ref.wet = d * 0.7
					rv_ref.dry = lerpf(1.0, 0.3, d)
					rv_ref.room_size = lerpf(0.0, 0.9, d)
			, recovery_power, 1.0, 0.5)
			var overlay_ref: ColorRect = _blackout_overlay
			tween.tween_callback(func() -> void:
				overlay_ref.queue_free()
				_remove_blackout_audio()
			)
			_blackout_overlay = null
		else:
			if _blackout_overlay:
				_blackout_overlay.queue_free()
				_blackout_overlay = null
			_remove_blackout_audio()
		_blackout_power = 1.0
		_blackout_flicker_state = false
		_blackout_final_death = false
		_reboot_scrolling = false
		_reboot_completed_lines.clear()
		# Remove reboot text
		if _reboot_label and is_instance_valid(_reboot_label):
			_reboot_label.queue_free()
			_reboot_label = null


func _remove_blackout_audio() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(master_idx) - 1, -1, -1):
		var fx: AudioEffect = AudioServer.get_bus_effect(master_idx, i)
		if fx == _blackout_lowpass or fx == _blackout_reverb:
			AudioServer.remove_bus_effect(master_idx, i)
	_blackout_lowpass = null
	_blackout_reverb = null


func _get_device_color(device: DeviceData) -> Color:
	if device.field_style_id != "":
		var style: FieldStyle = FieldStyleManager.load_by_id(device.field_style_id)
		if style:
			return style.color
	return Color(0.0, 0.8, 1.0)


func _apply_device_modifiers() -> void:
	var speed_pct: float = 0.0
	var accel_pct: float = 0.0
	for i in _device_controllers.size():
		var controller: DeviceController = _device_controllers[i]
		if not controller.is_active():
			continue
		var device: DeviceData = _device_data_per_slot[i]["device"]
		speed_pct += device.speed_modifier
		accel_pct += device.accel_modifier
	speed = _base_speed * maxf(1.0 + speed_pct / 100.0, 0.1)
	acceleration = _base_accel * maxf(1.0 + accel_pct / 100.0, 0.1)


func _exit_tree() -> void:
	# Always clean up bus effects — they persist on the Master bus across scene changes
	_remove_blackout_audio()
	if _blackout_overlay and is_instance_valid(_blackout_overlay):
		_blackout_overlay.queue_free()
		_blackout_overlay = null
	if _reboot_label and is_instance_valid(_reboot_label):
		_reboot_label.queue_free()
		_reboot_label = null


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
				if delta_val < 0.0 and electric + delta_val < 0.0:
					# Electric overdraw — absorb what electric has, bleed the rest to shields
					var overflow: float = -(electric + delta_val)  # positive amount of overdraw
					electric = 0.0
					_electric_overdraw = true
					var shield_cost: float = overflow * ELECTRIC_SHIELD_BLEED_MULT
					shield = maxf(shield - shield_cost, 0.0)
					# Trigger shield drain wave for the bleed
					if _hud and _hud.has_method("trigger_drain_wave"):
						_hud.trigger_drain_wave("SHIELD")
				else:
					electric = clampf(electric + delta_val, 0.0, electric_max)
		# Trigger HUD wave based on intended delta, even when clamped at min/max
		if _hud and delta_val != 0.0:
			var hud_bar_name: String = str(bar_type).to_upper()
			if delta_val > 0.0 and _hud.has_method("trigger_gain_wave"):
				_hud.trigger_gain_wave(hud_bar_name)
			elif delta_val < 0.0 and _hud.has_method("trigger_drain_wave"):
				_hud.trigger_drain_wave(hud_bar_name)


func _on_contact(area: Area2D) -> void:
	# Enemy projectiles handle their own damage via their _on_area_entered
	if area is EnemyProjectile:
		return
	take_damage(15.0)


static func _make_collision_shape(ship: ShipData) -> Dictionary:
	## Returns {"shape": Shape2D, "rotation": float} — rotation needed for horizontal capsules.
	var w: float = ship.collision_width if ship else 30.0
	var h: float = ship.collision_height if ship else 30.0
	match ship.collision_shape if ship else "circle":
		"rectangle":
			var rect := RectangleShape2D.new()
			rect.size = Vector2(w, h)
			return {"shape": rect, "rotation": 0.0}
		"capsule":
			var cap := CapsuleShape2D.new()
			if w > h:
				# Horizontal capsule: build vertical then rotate 90°
				cap.radius = h * 0.5
				cap.height = maxf(w, h)
				return {"shape": cap, "rotation": PI * 0.5}
			else:
				cap.radius = w * 0.5
				cap.height = maxf(h, w)
				return {"shape": cap, "rotation": 0.0}
		_:  # "circle"
			var circle := CircleShape2D.new()
			circle.radius = w * 0.5
			return {"shape": circle, "rotation": 0.0}


static func _resolve_ship_id(ship: ShipData) -> int:
	var name_to_id: Dictionary = {
		"switchblade": 0, "phantom": 1, "mantis": 2, "corsair": 3,
		"stiletto": 4, "trident": 5, "orrery": 6, "dreadnought": 7, "bastion": 8,
	}
	var ship_id_str: String = ship.id.to_lower() if ship else ""
	if name_to_id.has(ship_id_str):
		return int(name_to_id[ship_id_str])
	return 4  # Default to stiletto
