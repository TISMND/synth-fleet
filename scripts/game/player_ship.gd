extends Node2D
## Player ship — chrome Stiletto rendering with banking, movement, health, and hardpoint controllers.

signal died
signal died_during_power_loss
signal hull_hit_during_power_loss
signal hull_hit  # Emitted any time hull takes damage (for warning display)
signal power_loss_started
signal power_loss_ended

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
var _device_weapons_suppressed: bool = false  # true while a device is force-disabling weapons
var _device_cores_suppressed: bool = false  # true while a device is force-disabling cores
var _pre_suppress_weapon_states: Array = []  # per-hardpoint active state before suppression
var _pre_suppress_core_states: Array = []  # per-core active state before suppression
var _active_shield_dr: float = 0.0  # current shield damage reduction % from devices
var _active_hull_dr: float = 0.0  # current hull damage reduction % from devices
var _player_area: Area2D = null
var _hud: Control = null
var _weapon_data_per_hp: Array = []
var _space_state: int = 0  # 0=all off, 1=all on

# Banking + rendering
var _bank: float = 0.0
var _ship_renderer: ShipRenderer = null
var _electric_arcs: Array = []  # Active Line2D lightning bolts
var _electric_arc_container: Node2D = null  # Parent for arc lines
var _electric_arc_timer: float = 0.0  # Countdown to next arc spawn
var _electric_arc_max: int = 3  # Max simultaneous arcs
var _is_dead: bool = false  # True once hull reaches 0 — stops all processing
var _death_drifting: bool = false  # Drift/spin during death explosion sequence
var _death_drift_rotation_speed: float = 0.0
var _death_drift_spin_direction: float = 1.0
var _is_invulnerable: bool = false  # Brief immunity during power loss drift
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
var _blackout_lowpass: AudioEffectLowPassFilter = null  # GameAudio bus
var _blackout_reverb: AudioEffectReverb = null  # GameAudio bus
var _blackout_flicker_state: bool = false  # True during hard cut frames — for SFX sync
var _blackout_cue_75: bool = false  # Fired at 75% power
var _blackout_cue_50: bool = false  # Fired at 50% power
var _blackout_cue_25: bool = false  # Fired at 25% power
var _sfx_debug_label: Label = null  # Shows SFX event names on screen when they fire
var _sfx_debug_lines: Array[String] = []
var _sfx_debug_timers: Array[float] = []
var _reboot_label: RichTextLabel = null  # DOS-style text during final death
var _reboot_text_queue: Array[String] = []  # Lines to type out (prefix ">" = fast/scroll phase)
var _reboot_text_index: int = -1  # -1 = cursor blink, 0+ = line index
var _reboot_char_index: int = 0  # Current char in current line
var _reboot_char_timer: float = 0.0  # Timer for typewriter effect
var _reboot_blink_timer: float = 0.0  # Timer for initial cursor blink
var _reboot_scrolling: bool = false  # True once we enter the ">" fast scroll phase
var _reboot_completed_lines: Array[String] = []  # Finished lines for display
var _reboot_typing_player: AudioStreamPlayer = null  # Looping typing sound, start/stop with typing
var _reboot_finished: bool = false  # True once all text is typed — triggers recovery
var _recovery_active: bool = false  # Bar restoration animation in progress
var _recovery_elapsed: float = 0.0
var _shutdown_audio_elapsed: float = 0.0
var _shutdown_audio_done: bool = false
var _recovery_cores_activated: bool = false
var _recovery_pitch_start_time: float = -1.0  # When pitch ramp started
var _recovery_sfx_screen_fired: bool = false
var _recovery_sfx_systems_fired: bool = false
signal blackout_flicker(is_cut: bool)  # Emitted each frame during blackout — hook static SFX here
signal final_power_death()  # Emitted once when power fully dies — for external systems

const RAM_DPS: float = 400.0  # Contact damage per second of overlap — quick pass ≈ 50 damage, sitting = instant death
var _ram_overlapping: Array[Area2D] = []  # Enemies currently overlapping player
var _ram_accumulator: float = 0.0  # Fractional damage accumulator

const THERMAL_COOLING_RATE: float = 15.0  # hp/sec cooling when no heat sources active
const ELECTRIC_THROTTLE_THRESHOLD: float = 40.0  # Start throttling below 4 segments (40 points)
const ELECTRIC_SHIELD_BLEED_MULT: float = 1.5  # Overdraw penalty: 1.5x cost from shields
const BLACKOUT_MAX_SPIN: float = 0.2  # Max radians/sec — gentle drift


func setup(ship: ShipData, loadout: LoadoutData, proj_container: Node2D) -> void:
	add_to_group("player")
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

	# Electric arc container — holds Line2D lightning bolts spawned during crisis
	_electric_arc_container = Node2D.new()
	_electric_arc_container.z_index = 2
	add_child(_electric_arc_container)

	# Universal player hit effects from VFX config
	var vfx: VfxConfig = VfxConfigManager.load_config()
	_setup_hit_field("ShieldField", vfx.player_shield_field_style_id, vfx.player_shield_radius)

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
	_player_area.area_exited.connect(_on_contact_exit)
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


func _setup_hit_field(node_name: String, style_id: String, radius: float) -> void:
	if style_id == "":
		return
	var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
	if not style:
		return
	var field := FieldRenderer.new()
	field.name = node_name
	field._stay_visible = false
	add_child(field)
	field.setup(style, radius)


func _flash_hull_hit() -> void:
	if not _ship_renderer:
		return
	var vfx: VfxConfig = VfxConfigManager.load_config()
	var color_arr: Array = vfx.player_hull_flash_color
	var flash_color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), 1.0)
	var intensity: float = vfx.player_hull_flash_intensity
	var duration: float = vfx.player_hull_flash_duration
	var count: int = vfx.player_hull_flash_count
	var step_time: float = duration / (count * 2.0)
	var tween := create_tween()
	for i in count:
		var bright := flash_color * intensity
		bright.a = 1.0
		tween.tween_property(_ship_renderer, "modulate", bright, step_time * 0.1)
		tween.tween_property(_ship_renderer, "modulate", Color.WHITE, step_time * 0.9)
	tween.tween_property(_ship_renderer, "modulate", Color.WHITE, 0.0)


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
	if _is_dead:
		if _death_drifting:
			_process_death_drift(delta)
		return
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
	# Thermal cooling — only when no active component generates heat
	if thermal > 0.0 and not _any_heat_source_active():
		thermal = maxf(thermal - THERMAL_COOLING_RATE * delta, 0.0)

	# Continuous ram damage — DPS while overlapping enemies (Tyrian-style)
	# Clean up freed enemies first
	var i: int = _ram_overlapping.size() - 1
	while i >= 0:
		if not is_instance_valid(_ram_overlapping[i]):
			_ram_overlapping.remove_at(i)
		i -= 1
	if not _ram_overlapping.is_empty():
		_ram_accumulator += RAM_DPS * delta
		if _ram_accumulator >= 1.0:
			var tick: int = int(_ram_accumulator)
			_ram_accumulator -= float(tick)
			take_damage(float(tick))

	# Electric critically low — crisis starts at half a segment (5 points)
	if electric <= 5.0 and not _electric_crisis_active:
		_electric_crisis_active = true
		_play_sfx_cue("electric_sparks", false)
		_play_sfx_cue("powerdown_shields_bleed")
		if _hud and _hud.has_method("start_shield_arcs"):
			_hud.start_shield_arcs()
	elif electric > 5.0 and _electric_crisis_active and not _recovery_active:
		_electric_crisis_active = false
		_clear_electric_arcs()
		if _hud and _hud.has_method("stop_shield_arcs"):
			_hud.stop_shield_arcs()

	# Sporadic electric arcs — spawn jagged Line2D lightning bolts
	if _electric_crisis_active and _electric_arc_container:
		_electric_arc_timer -= delta
		if _electric_arc_timer <= 0.0 and _electric_arcs.size() < _electric_arc_max:
			_spawn_lightning_arc()
			_electric_arc_timer = randf_range(0.08, 0.35)
		_update_electric_arcs(delta)

	# Drift phase — shields critically low during electric crisis, ship loses control
	if _electric_overdraw and electric <= 5.0 and shield <= 10.0:
		if not _drifting:
			_start_drift()
	if _drifting:
		if electric > 0.0 and not _recovery_active:
			_end_drift()
		else:
			_process_drift(delta)
	# Reset overdraw flag — it's set per-frame by apply_bar_effects
	_electric_overdraw = false

	# SFX debug cue fadeout
	_update_sfx_debug(delta)

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
		_electric_crisis_active = false  # Let _process detect and trigger properly
		_electric_overdraw = true
		print("[DEBUG] F9: Forced power death — electric=0, shield=0")
		return
	# DEBUG: F10 = force death during power loss (only works if already drifting/blackout)
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_F10:
		if _drifting or _blackout_active:
			hull = 0.0
			died_during_power_loss.emit()
			print("[DEBUG] F10: Forced death during power loss")
		return

	# Lock all component controls during power death sequence
	if _drifting:
		return

	# Per-slot toggles using dynamic action names from KeyBindingManager
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).is_echo():
		var dbg_pkc: int = (event as InputEventKey).physical_keycode
		print("[INPUT] key pressed: pkc=%d, weapons=%d cores=%d fields=%d controllers=%d" % [
			dbg_pkc, GameState.get_weapon_slot_count(), GameState.get_core_slot_count(),
			GameState.get_field_slot_count(), _hardpoint_controllers.size()])
	# Weapon slots (blocked while device-suppressed)
	if not _device_weapons_suppressed:
		for i in _hardpoint_controllers.size():
			var slot_key: String = "weapon_" + str(i)
			var action: String = KeyBindingManager.get_slot_action(slot_key)
			if event.is_action_pressed(action):
				_hardpoint_controllers[i].toggle()
				_update_hud_hardpoints()
				return

	# Core slots (blocked while device-suppressed)
	if not _device_cores_suppressed:
		for i in _core_controllers.size():
			var slot_key: String = "core_" + str(i)
			var action: String = KeyBindingManager.get_slot_action(slot_key)
			if event.is_action_pressed(action):
				_core_controllers[i].toggle()
				_update_hud_cores()
				return

	# Field slots
	for i in _device_controllers.size():
		var slot_key: String = "field_" + str(i)
		var action: String = KeyBindingManager.get_slot_action(slot_key)
		if event.is_action_pressed(action):
			_device_controllers[i].toggle()
			_update_hud_devices()
			return

	# Space: toggle all on/off (weapons + cores + devices)
	if event.is_action_pressed("hardpoints_max"):
		_space_state = 1 - _space_state
		# When turning everything off, clear suppression state — user explicitly
		# wants everything off, so pre-suppress snapshots should not restore later.
		if _space_state == 0:
			if _device_weapons_suppressed:
				_device_weapons_suppressed = false
				_pre_suppress_weapon_states.clear()
			if _device_cores_suppressed:
				_device_cores_suppressed = false
				_pre_suppress_core_states.clear()
		if not _device_weapons_suppressed:
			for c in _hardpoint_controllers:
				if _space_state == 1:
					c.activate()
				else:
					c.deactivate()
		if not _device_cores_suppressed:
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
		# Clear suppression state first — user explicitly wants everything off,
		# so pre-suppress snapshots are stale and should not restore later.
		if _device_weapons_suppressed:
			_device_weapons_suppressed = false
			_pre_suppress_weapon_states.clear()
		if _device_cores_suppressed:
			_device_cores_suppressed = false
			_pre_suppress_core_states.clear()
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
	# Apply weapon slots (skip if device-suppressed)
	if not _device_weapons_suppressed:
		for i in GameState.get_weapon_slot_count():
			var slot_key: String = "weapon_" + str(i)
			var on: bool = pattern.get(slot_key, false)
			if i < _hardpoint_controllers.size():
				if on:
					_hardpoint_controllers[i].activate()
				else:
					_hardpoint_controllers[i].deactivate()

	# Apply core slots (skip if device-suppressed)
	if not _device_cores_suppressed:
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
	if _is_invulnerable:
		return
	var remaining: float = amount
	if shield > 0.0 and not skips_shields:
		# Shield DR: shields absorb the full hit but take reduced actual damage.
		# With 95% DR, 100 raw damage only costs 5 shield HP.
		var reduction_factor: float = 1.0
		if _active_shield_dr > 0.0:
			reduction_factor = 1.0 - _active_shield_dr / 100.0
		if reduction_factor > 0.0:
			# Max raw damage shields can absorb before depleting
			var max_absorbable: float = shield / reduction_factor
			var absorbed: float = minf(remaining, max_absorbable)
			shield -= absorbed * reduction_factor
			remaining -= absorbed
		else:
			# 100% reduction: shields absorb everything, take no damage
			remaining = 0.0
		SfxPlayer.play("player_shield_hit")
		var shield_field: FieldRenderer = get_node_or_null("ShieldField") as FieldRenderer
		if shield_field:
			shield_field.pulse()
	if remaining > 0.0:
		# Apply hull damage reduction from active devices
		if _active_hull_dr > 0.0:
			remaining *= (1.0 - _active_hull_dr / 100.0)
		hull = maxf(hull - remaining, 0.0)
		SfxPlayer.play("player_hull_hit")
		_flash_hull_hit()
		hull_hit.emit()
		if _drifting or _blackout_active:
			hull_hit_during_power_loss.emit()
	if hull <= 0.0:
		if _drifting or _blackout_active:
			died_during_power_loss.emit()
		else:
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


const SHUTDOWN_AUDIO_DURATION: float = 1.5  # Seconds to slow down and fade out loops

func _start_drift() -> void:
	_drifting = true
	_drift_timer = 0.0
	power_loss_started.emit()
	_shutdown_audio_elapsed = 0.0
	_play_sfx_cue("powerdown_drift_start")
	_play_sfx_cue("powerdown_engines_dying", false)
	# Deactivate ALL components — total power failure
	# Weapons stop firing, cores stop generating, devices stop regenerating
	for c in _hardpoint_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
	for c in _core_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
	for c in _device_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
	# Start LED bar segment death animation
	if _hud and _hud.has_method("start_power_death_bars"):
		_hud.start_power_death_bars()
	_drift_rotation_speed = 0.0
	_drift_spin_direction = 1.0 if randf() > 0.5 else -1.0


func _process_drift(delta: float) -> void:
	_drift_timer += delta

	# Shutdown audio — slow down and fade out loops over 1.5 seconds
	if not _shutdown_audio_done:
		_shutdown_audio_elapsed += delta
		var sd_t: float = clampf(_shutdown_audio_elapsed / SHUTDOWN_AUDIO_DURATION, 0.0, 1.0)
		LoopMixer.set_all_pitch_scale(lerpf(1.0, 0.2, sd_t))
		LoopMixer.set_all_volume_offset(lerpf(0.0, -40.0, sd_t))
		if sd_t >= 1.0:
			_shutdown_audio_done = true
			LoopMixer.mute_all()
			LoopMixer.set_all_pitch_scale(1.0)
			LoopMixer.set_all_volume_offset(0.0)
			LoopMixer.set_all_pitch_scale(1.0)
			LoopMixer.set_all_volume_offset(0.0)

	# Gradual spin — reaches max over 4 seconds
	_drift_rotation_speed = minf(_drift_rotation_speed + (BLACKOUT_MAX_SPIN / 4.0) * delta, BLACKOUT_MAX_SPIN)
	rotation += _drift_rotation_speed * _drift_spin_direction * delta

	# After delay, trigger blackout (darkness + HUD effects)
	if _drift_timer >= PowerLossSequence.DRIFT_TO_BLACKOUT_DELAY and not _blackout_active:
		_play_sfx_cue("power_failure")
		_play_sfx_cue("powerdown_crt_flicker_start")
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
	# Audio degradation — effects on GameAudio bus only.
	# All game sound (Weapons/SFX/Enemies/Atmosphere) routes through GameAudio.
	# UI bus routes directly to Master, bypassing GameAudio — stays clean.
	var ga_idx: int = AudioServer.get_bus_index("GameAudio")
	if ga_idx >= 0:
		_blackout_lowpass = AudioEffectLowPassFilter.new()
		_blackout_lowpass.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(ga_idx, _blackout_lowpass)
		_blackout_reverb = AudioEffectReverb.new()
		_blackout_reverb.room_size = 0.0
		_blackout_reverb.wet = 0.0
		_blackout_reverb.dry = 1.0
		_blackout_reverb.damping = 0.8
		AudioServer.add_bus_effect(ga_idx, _blackout_reverb)
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
	_blackout_power = maxf(_blackout_power - PowerLossSequence.BLACKOUT_FADE_SPEED * delta, 0.02)

	# Visual — CRT shader
	if _blackout_overlay and _blackout_overlay.material is ShaderMaterial:
		var mat: ShaderMaterial = _blackout_overlay.material as ShaderMaterial
		mat.set_shader_parameter("power", _blackout_power)

	# Audio — effects on GameAudio bus, tied to same power level
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
			_play_sfx_cue("monitor_static")
		_blackout_flicker_state = flicker_now
		blackout_flicker.emit(flicker_now)

	# Staged power-down cues — each fires once at its threshold
	if _blackout_power <= 0.75 and not _blackout_cue_75:
		_blackout_cue_75 = true
		_play_sfx_cue("powerdown_screen_75")
	if _blackout_power <= 0.50 and not _blackout_cue_50:
		_blackout_cue_50 = true
		_play_sfx_cue("powerdown_screen_50")
	if _blackout_power <= 0.25 and not _blackout_cue_25:
		_blackout_cue_25 = true
		_play_sfx_cue("powerdown_screen_25")

	# Final power death — power hit the floor
	if _blackout_power <= 0.03 and not _blackout_final_death:
		_blackout_final_death = true
		_shutdown_all_components()
		_play_sfx_cue("monitor_shutoff")
		_play_sfx_cue("powerdown_final_death")
		# Kill remaining LED segments rapidly — fade to total darkness
		if _hud and _hud.has_method("final_power_death_bars"):
			_hud.final_power_death_bars()
		_start_reboot_sequence()
		final_power_death.emit()

	# Type out reboot text + recovery animation
	if _blackout_final_death:
		_process_reboot_text(delta)
		# Speed ramp runs during text phase if cores activated early
		if _recovery_cores_activated and _recovery_pitch_start_time >= 0.0:
			_recovery_pitch_start_time += delta
			var pitch_t: float = clampf(_recovery_pitch_start_time / PowerLossSequence.RECOVERY_PITCH_DURATION, 0.0, 1.0)
			var pitch_eased: float = pitch_t * pitch_t
			LoopMixer.set_all_pitch_scale(lerpf(PowerLossSequence.RECOVERY_PITCH_START, 1.0, pitch_eased))
	_process_recovery(delta)


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
	_reboot_text_queue = PowerLossSequence.REBOOT_TEXT_LINES.duplicate()
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
	# Text area — padding at top pushes content to bottom, CLI-style scroll up
	_reboot_label.size = Vector2(600, 550)
	_reboot_label.position = Vector2(240, 50)
	_reboot_label.add_theme_font_size_override("normal_font_size", 18)
	# Bright green with HDR boost for bloom
	_reboot_label.add_theme_color_override("default_color", Color(0.3, 1.0, 0.4))
	_reboot_label.modulate = Color(1.9, 1.9, 1.9, 1.0)
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
	# Add to ROOT viewport so HDR modulate produces bloom (root has glow_enabled)
	get_tree().root.add_child(_reboot_label)

	# Typing sound — plays while typing, stops during pauses.
	# Reload SFX cache so any changes made in the SFX editor take effect.
	SfxPlayer.reload()
	_reboot_typing_player = AudioStreamPlayer.new()
	_reboot_typing_player.bus = "UI"
	var cfg: SfxConfig = SfxConfigManager.load_config()
	var thunk_ev: Dictionary = cfg.get_event("reboot_char_thunk")
	var thunk_path: String = str(thunk_ev.get("file_path", ""))
	print("[REBOOT-SFX] thunk_path='%s'" % thunk_path)
	if thunk_path != "":
		# Load fresh (not from SfxPlayer cache) to avoid any stale resource issues
		var stream: AudioStream = load(thunk_path) as AudioStream
		if stream:
			# Enable looping so it plays continuously while typing
			if stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
				(stream as AudioStreamWAV).loop_begin = 0
				(stream as AudioStreamWAV).loop_end = int((stream as AudioStreamWAV).get_length() * float((stream as AudioStreamWAV).mix_rate))
			_reboot_typing_player.stream = stream
			_reboot_typing_player.volume_db = float(thunk_ev.get("volume_db", 0.0))
			print("[REBOOT-SFX] stream loaded OK, length=%.2f bus=%s" % [stream.get_length(), _reboot_typing_player.bus])
		else:
			print("[REBOOT-SFX] FAILED to load stream at path")
	else:
		print("[REBOOT-SFX] no file assigned to reboot_char_thunk")
	add_child(_reboot_typing_player)



func _process_reboot_text(delta: float) -> void:
	if not _reboot_label:
		return

	# Phase -1: blinking cursor only
	if _reboot_text_index < 0:
		_reboot_blink_timer += delta
		var blink_on: bool = fmod(_reboot_blink_timer, PowerLossSequence.REBOOT_BLINK_RATE * 2.0) < PowerLossSequence.REBOOT_BLINK_RATE
		# Blink cursor at the same position text will start (bottom of label area)
		_update_reboot_display("", blink_on)
		if _reboot_blink_timer >= PowerLossSequence.REBOOT_BLINK_DURATION:
			_reboot_text_index = 0
			_reboot_char_index = 0
			_reboot_char_timer = 0.0
			_reboot_completed_lines.clear()
		return

	if _reboot_text_index >= _reboot_text_queue.size():
		if not _reboot_finished:
			_reboot_finished = true
			_start_recovery()
		return

	_reboot_char_timer += delta
	var raw_line: String = _reboot_text_queue[_reboot_text_index]

	# Check if this line starts the fast scroll phase
	if raw_line.begins_with(">") and not _reboot_scrolling:
		_reboot_scrolling = true
		_play_sfx_cue("powerup_electric_restored")

	# Strip the ">" prefix for display
	var current_line: String = raw_line.lstrip(">")

	# Empty line = paragraph pause — no display update during wait (prevents jump)
	if current_line == "":
		if _reboot_typing_player and _reboot_typing_player.playing:
			_reboot_typing_player.stop()
		if _reboot_char_timer >= PowerLossSequence.REBOOT_PARAGRAPH_PAUSE:
			_reboot_char_timer = 0.0
			_reboot_completed_lines.append("")
			_reboot_text_index += 1
			_reboot_char_index = 0
			# Display updates on next frame with the new line
		return

	var char_speed: float = PowerLossSequence.REBOOT_CHAR_FAST if _reboot_scrolling else PowerLossSequence.REBOOT_CHAR_SLOW

	# Specific line triggers — fire once when line starts typing
	if _reboot_char_index == 0 and _reboot_char_timer < char_speed:
		if current_line == "Bypassing main reactor safety...":
			# Start the speed spinup early — during text, not after
			if not _recovery_cores_activated:
				_recovery_cores_activated = true
				_recovery_pitch_start_time = 0.0
				LoopMixer.set_all_pitch_scale(PowerLossSequence.RECOVERY_PITCH_START)
				LoopMixer.set_all_volume_offset(0.0)  # Instant full volume — no fade
				for c in _core_controllers:
					if c.has_method("activate"):
						c.activate()
				LoopMixer.start_all()
		elif current_line == "Regenerating power core...":
			_play_sfx_cue("powerup_core_regen")
		elif current_line == "SUCCESS":
			_play_sfx_cue("powerup_restored")

	if _reboot_char_index < current_line.length():
		# Still typing — advance multiple chars per frame if timer allows
		while _reboot_char_timer >= char_speed and _reboot_char_index < current_line.length():
			_reboot_char_timer -= char_speed
			_reboot_char_index += 1
		# Start typing sound if not already playing
		if _reboot_typing_player and not _reboot_typing_player.playing:
			if _reboot_typing_player.stream:
				_reboot_typing_player.play()
				print("[REBOOT-SFX] typing sound STARTED, bus=%s" % _reboot_typing_player.bus)
			else:
				print("[REBOOT-SFX] NO STREAM on typing player!")
		var typed: String = current_line.substr(0, _reboot_char_index)
		_update_reboot_display(typed, true)
	else:
		# Line fully typed — stop typing sound during pause
		if _reboot_typing_player and _reboot_typing_player.playing:
			_reboot_typing_player.stop()
			print("[REBOOT-SFX] typing sound STOPPED (line complete)")
		# Keep cursor visible during pause, then advance
		# both completion AND new line start on same frame = no bump
		var is_header: bool = current_line == current_line.to_upper() and current_line.length() > 2
		var line_pause: float = PowerLossSequence.REBOOT_LINE_PAUSE_FAST if _reboot_scrolling else PowerLossSequence.REBOOT_LINE_PAUSE_SLOW
		var pause: float = PowerLossSequence.REBOOT_HEADER_PAUSE if is_header else line_pause
		if _reboot_char_timer >= pause:
			_reboot_char_timer = 0.0
			_play_sfx_cue("reboot_line_beep")
			_reboot_completed_lines.append(current_line)
			_reboot_text_index += 1
			_reboot_char_index = 0
			# Display with new state immediately — completed line moves up,
			# new empty typing line starts, all in one frame
			_update_reboot_display("", true)
		else:
			# Waiting — keep showing completed line WITH cursor (no bump)
			_update_reboot_display(current_line, true)


func _update_reboot_display(typed_portion: String, show_cursor: bool) -> void:
	if not _reboot_label:
		return
	# Build content lines
	var content_lines: Array[String] = []
	for completed in _reboot_completed_lines:
		content_lines.append(completed)
	# Current typing line
	var current: String = typed_portion
	if show_cursor:
		current += "[color=#228833]\u2588[/color]"
	if current.length() > 0:
		content_lines.append(current)

	# Pad with empty lines at top so content anchors to bottom of label area.
	# This makes new lines push the block upward like a CLI terminal.
	var line_height: float = 20.0  # Approximate line height at font_size 16
	var label_height: float = _reboot_label.size.y
	var max_visible: int = int(label_height / line_height)
	var pad_count: int = maxi(max_visible - content_lines.size(), 0)

	var padded: String = ""
	for i in pad_count:
		padded += "\n"
	padded += "\n".join(content_lines)
	_reboot_label.text = padded


# ── Power-loss death helpers ─────────────────────────────────────────────

func corrupt_reboot_text(severity: float) -> void:
	## Replace random characters in the reboot label with static glitch symbols.
	if not _reboot_label:
		return
	var text: String = _reboot_label.text
	var corrupted: String = ""
	var glitch_chars: Array[String] = ["#", "@", "$", "%", "&", "!", "~", "^", "*", "?"]
	for ch in text:
		if ch == "\n" or ch == " " or ch == "[" or ch == "]" or ch == "/":
			corrupted += ch
		elif randf() < severity:
			corrupted += glitch_chars[randi() % glitch_chars.size()]
		else:
			corrupted += ch
	_reboot_label.text = corrupted


func cleanup_power_loss() -> void:
	## Clean up all power-loss state and nodes for scene exit.
	if _reboot_label and is_instance_valid(_reboot_label):
		_reboot_label.queue_free()
		_reboot_label = null
	if _reboot_typing_player and is_instance_valid(_reboot_typing_player):
		_reboot_typing_player.stop()
		_reboot_typing_player.queue_free()
		_reboot_typing_player = null
	_remove_blackout_audio()
	_drifting = false
	_blackout_active = false
	_recovery_active = false
	_reboot_finished = false


# ── Recovery sequence — bars animate back up after reboot completes ──────────

func _start_recovery() -> void:
	_recovery_active = true
	_recovery_elapsed = 0.0
	_recovery_cores_activated = false
	_recovery_sfx_screen_fired = false
	_recovery_sfx_systems_fired = false
	_play_sfx_cue("powerup_bars_charging")
	print("[RECOVERY] started — electric_max=%.0f shield_max=%.0f" % [electric_max, shield_max])


func _process_recovery(delta: float) -> void:
	if not _recovery_active:
		return
	_recovery_elapsed += delta
	var t: float = clampf(_recovery_elapsed / PowerLossSequence.RECOVERY_DURATION, 0.0, 1.0)

	# Animate electric from 0 to 50% (penalty for power failure)
	electric = lerpf(0.0, electric_max * 0.5, t)
	# Animate shield from 0 to 25%
	shield = lerpf(0.0, shield_max * 0.25, t)
	if int(t * 10) != int((t - delta / PowerLossSequence.RECOVERY_DURATION) * 10):
		print("[RECOVERY] t=%.2f elec=%.0f/%.0f shield=%.0f/%.0f" % [t, electric, electric_max, shield, shield_max])
	# Thermal stays at 0
	thermal = 0.0
	# Hull stays at whatever it was (protected at min 10 during power death)

	# Gradually unwind ship rotation back to 0
	rotation = lerpf(rotation, 0.0, delta * 2.0)
	# Slow drift to a stop
	_drift_rotation_speed = lerpf(_drift_rotation_speed, 0.0, delta * 3.0)

	# Reactivate power cores early — loops start at very low pitch/speed and ramp up
	if t >= 0.01 and not _recovery_cores_activated:
		_recovery_cores_activated = true
		# Set all loop players to very low pitch BEFORE activating
		LoopMixer.set_all_pitch_scale(PowerLossSequence.RECOVERY_PITCH_START)
		LoopMixer.set_all_volume_offset(PowerLossSequence.RECOVERY_VOLUME_START)
		for c in _core_controllers:
			if c.has_method("activate"):
				c.activate()
		LoopMixer.start_all()
		_recovery_pitch_start_time = _recovery_elapsed

	# Speed ramp continues from text phase into recovery phase
	if _recovery_pitch_start_time >= 0.0:
		_recovery_pitch_start_time += delta
		var pitch_t: float = clampf(_recovery_pitch_start_time / PowerLossSequence.RECOVERY_PITCH_DURATION, 0.0, 1.0)
		var pitch_eased: float = pitch_t * pitch_t
		LoopMixer.set_all_pitch_scale(lerpf(PowerLossSequence.RECOVERY_PITCH_START, 1.0, pitch_eased))

	# Staged SFX during recovery
	if t >= 0.5 and not _recovery_sfx_screen_fired:
		_recovery_sfx_screen_fired = true
		_play_sfx_cue("powerup_screen_on")
	if t >= 0.9 and not _recovery_sfx_systems_fired:
		_recovery_sfx_systems_fired = true
		_play_sfx_cue("powerup_systems_online")

	# Reverse the bar kill masks — bring segments back per-bar
	if _hud and _hud.has_method("set_power_recovery_ratio"):
		var targets: Dictionary = {
			"ELECTRIC": 0.5,   # 50% restore (penalty)
			"SHIELD": 0.25,    # 25% restore (penalty)
			"THERMAL": 0.0,    # Stays dark
			"HULL": hull / maxf(hull_max, 1.0),  # Whatever hull is at
		}
		_hud.set_power_recovery_ratio(t, targets)

	if t >= 1.0:
		_recovery_active = false
		_restore_loop_playback()
		_end_drift()
		power_loss_ended.emit()


func _restore_loop_playback() -> void:
	LoopMixer.set_all_pitch_scale(1.0)
	LoopMixer.set_all_volume_offset(0.0)
	_recovery_pitch_start_time = -1.0


## ── Procedural lightning arcs ────────────────────────────────────────────────

func _spawn_lightning_arc() -> void:
	## Create a jagged Line2D bolt between two random points on the ship hull.
	var ship_radius: float = 40.0
	# Random start and end points around the ship
	var angle_start: float = randf() * TAU
	var angle_end: float = angle_start + randf_range(1.5, 4.0)  # Span at least ~90 degrees
	var r_start: float = randf_range(ship_radius * 0.3, ship_radius * 0.9)
	var r_end: float = randf_range(ship_radius * 0.3, ship_radius * 1.1)
	var start_pos: Vector2 = Vector2(cos(angle_start), sin(angle_start)) * r_start
	var end_pos: Vector2 = Vector2(cos(angle_end), sin(angle_end)) * r_end

	# Build jagged path between start and end
	var segments: int = randi_range(5, 10)
	var points: PackedVector2Array = PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var base_pos: Vector2 = start_pos.lerp(end_pos, t)
		if i > 0 and i < segments:
			# Jitter perpendicular to the line
			var perp: Vector2 = (end_pos - start_pos).normalized().rotated(PI / 2.0)
			base_pos += perp * randf_range(-15.0, 15.0)
		points.append(base_pos)

	var line := Line2D.new()
	line.points = points
	line.width = randf_range(1.0, 2.5)
	line.default_color = Color(0.6, 0.8, 1.0, 1.0)
	line.antialiased = true
	# HDR bloom — bright white-blue core
	line.modulate = Color(2.75, 2.75, 2.75, 1.0)
	_electric_arc_container.add_child(line)
	_electric_arcs.append({"line": line, "life": randf_range(0.04, 0.12), "age": 0.0})


func _update_electric_arcs(delta: float) -> void:
	var i: int = _electric_arcs.size() - 1
	while i >= 0:
		var arc: Dictionary = _electric_arcs[i]
		arc["age"] = float(arc["age"]) + delta
		var life: float = float(arc["life"])
		var age: float = float(arc["age"])
		if age >= life:
			# Arc expired — remove
			var line: Line2D = arc["line"]
			line.queue_free()
			_electric_arcs.remove_at(i)
		else:
			# Fade out over lifetime
			var line: Line2D = arc["line"]
			var fade: float = 1.0 - (age / life)
			line.modulate.a = fade * 2.0  # HDR fade
		i -= 1


func _clear_electric_arcs() -> void:
	for arc in _electric_arcs:
		var line: Line2D = arc["line"]
		if is_instance_valid(line):
			line.queue_free()
	_electric_arcs.clear()



## SFX visual cue — shows sci-fi status text on screen when triggered
func _play_sfx_cue(event_id: String, use_ui_bus: bool = true) -> void:
	if use_ui_bus:
		SfxPlayer.play_ui(event_id)
	else:
		SfxPlayer.play(event_id)
	# Show on-screen label with sci-fi display name
	var display: String = str(PowerLossSequence.CUE_DISPLAY_LABELS.get(event_id, ""))
	if display == "":
		return
	if not _sfx_debug_label:
		_sfx_debug_label = Label.new()
		_sfx_debug_label.position = Vector2(1400, 60)
		_sfx_debug_label.size = Vector2(500, 400)
		_sfx_debug_label.z_index = 100
		_sfx_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sfx_debug_label.add_theme_font_size_override("font_size", 12)
		_sfx_debug_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 0.9))
		get_tree().root.add_child(_sfx_debug_label)
	_sfx_debug_lines.append(">> " + display)
	_sfx_debug_timers.append(3.0)
	_rebuild_sfx_debug()


func _update_sfx_debug(delta: float) -> void:
	if _sfx_debug_timers.is_empty():
		return
	var changed: bool = false
	for i in range(_sfx_debug_timers.size() - 1, -1, -1):
		_sfx_debug_timers[i] -= delta
		if _sfx_debug_timers[i] <= 0.0:
			_sfx_debug_timers.remove_at(i)
			_sfx_debug_lines.remove_at(i)
			changed = true
	if changed:
		_rebuild_sfx_debug()


func _rebuild_sfx_debug() -> void:
	if _sfx_debug_label:
		_sfx_debug_label.text = "\n".join(_sfx_debug_lines)


## Hash matching the shader's hash function — keeps GDScript flicker detection in sync
func _hash_float(x: float, hash_seed: float) -> float:
	var p := Vector3(fmod(abs(x), 1000.0) * 0.1031, fmod(abs(hash_seed), 1000.0) * 0.1031, fmod(abs(x), 1000.0) * 0.1031)
	p = Vector3(fmod(p.x, 1.0), fmod(p.y, 1.0), fmod(p.z, 1.0))
	var d: float = p.x * (p.y + 33.33) + p.y * (p.z + 33.33) + p.z * (p.x + 33.33)
	return fmod(abs(d), 1.0)


func _end_drift() -> void:
	_drifting = false
	_drift_timer = 0.0
	_drift_rotation_speed = 0.0
	rotation = 0.0
	# Always reset crisis-level flags (even if blackout wasn't reached)
	_electric_crisis_active = false
	_shield_at_crisis_start = -1.0
	_shutdown_audio_done = false
	_clear_electric_arcs()
	if _hud and _hud.has_method("stop_shield_arcs"):
		_hud.stop_shield_arcs()
	# Restore LED bar segments
	if _hud and _hud.has_method("stop_power_death_bars"):
		_hud.stop_power_death_bars()
	if _blackout_active:
		_blackout_active = false
		# Power-up: tween CRT overlay + audio back to normal
		var recovery_power: float = _blackout_power
		if _blackout_overlay and _blackout_overlay.material is ShaderMaterial:
			var mat: ShaderMaterial = _blackout_overlay.material as ShaderMaterial
			var tween: Tween = create_tween()
			tween.tween_method(func(v: float) -> void:
				mat.set_shader_parameter("power", v)
			, recovery_power, 1.0, 2.0)  # Slow power-up matches recovery duration
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
		_blackout_cue_75 = false
		_blackout_cue_50 = false
		_blackout_cue_25 = false
		_reboot_scrolling = false
		_reboot_finished = false
		_recovery_active = false
		_recovery_elapsed = 0.0
		_recovery_cores_activated = false
		_reboot_completed_lines.clear()
		# Remove reboot text + typing sound
		if _reboot_typing_player and is_instance_valid(_reboot_typing_player):
			_reboot_typing_player.stop()
			_reboot_typing_player.queue_free()
			_reboot_typing_player = null
		if _reboot_label and is_instance_valid(_reboot_label):
			_reboot_label.queue_free()
			_reboot_label = null


func _remove_blackout_audio() -> void:
	# Remove effects from GameAudio bus
	var ga_idx: int = AudioServer.get_bus_index("GameAudio")
	if ga_idx >= 0:
		for i in range(AudioServer.get_bus_effect_count(ga_idx) - 1, -1, -1):
			var fx: AudioEffect = AudioServer.get_bus_effect(ga_idx, i)
			if fx == _blackout_lowpass or fx == _blackout_reverb:
				AudioServer.remove_bus_effect(ga_idx, i)
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
	var shield_dr: float = 0.0
	var hull_dr: float = 0.0
	var wants_suppress_weapons: bool = false
	var wants_suppress_cores: bool = false
	for i in _device_controllers.size():
		var controller: DeviceController = _device_controllers[i]
		if not controller.is_active():
			continue
		var device: DeviceData = _device_data_per_slot[i]["device"]
		speed_pct += device.speed_modifier
		accel_pct += device.accel_modifier
		shield_dr += device.shield_damage_reduction
		hull_dr += device.hull_damage_reduction
		if device.disable_weapons:
			wants_suppress_weapons = true
		if device.disable_power_cores:
			wants_suppress_cores = true
	speed = _base_speed * maxf(1.0 + speed_pct / 100.0, 0.0)
	acceleration = _base_accel * maxf(1.0 + accel_pct / 100.0, 0.0)
	_active_shield_dr = clampf(shield_dr, 0.0, 100.0)
	_active_hull_dr = clampf(hull_dr, 0.0, 100.0)

	# Weapon suppression — snapshot states on suppress, restore on release
	if wants_suppress_weapons and not _device_weapons_suppressed:
		_device_weapons_suppressed = true
		_pre_suppress_weapon_states.clear()
		for ctrl in _hardpoint_controllers:
			var hc: HardpointController = ctrl as HardpointController
			_pre_suppress_weapon_states.append(hc.is_active() if hc else false)
			if hc and hc.is_active():
				hc.deactivate()
		_update_hud_hardpoints()
	elif not wants_suppress_weapons and _device_weapons_suppressed:
		_device_weapons_suppressed = false
		for i in _hardpoint_controllers.size():
			if i < _pre_suppress_weapon_states.size() and _pre_suppress_weapon_states[i]:
				var hc: HardpointController = _hardpoint_controllers[i] as HardpointController
				if hc:
					hc.activate()
		_pre_suppress_weapon_states.clear()
		_update_hud_hardpoints()

	# Core suppression — same pattern
	if wants_suppress_cores and not _device_cores_suppressed:
		_device_cores_suppressed = true
		_pre_suppress_core_states.clear()
		for ctrl in _core_controllers:
			var cc: PowerCoreController = ctrl as PowerCoreController
			_pre_suppress_core_states.append(cc.is_active() if cc else false)
			if cc and cc.is_active():
				cc.deactivate()
		_update_hud_cores()
	elif not wants_suppress_cores and _device_cores_suppressed:
		_device_cores_suppressed = false
		for i in _core_controllers.size():
			if i < _pre_suppress_core_states.size() and _pre_suppress_core_states[i]:
				var cc: PowerCoreController = _core_controllers[i] as PowerCoreController
				if cc:
					cc.activate()
		_pre_suppress_core_states.clear()
		_update_hud_cores()


func _exit_tree() -> void:
	# Always clean up bus effects — they persist across scene changes
	_remove_blackout_audio()
	_restore_loop_playback()
	_clear_electric_arcs()
	if _blackout_overlay and is_instance_valid(_blackout_overlay):
		_blackout_overlay.queue_free()
		_blackout_overlay = null
	if _reboot_typing_player and is_instance_valid(_reboot_typing_player):
		_reboot_typing_player.stop()
		_reboot_typing_player.queue_free()
		_reboot_typing_player = null
	if _reboot_label and is_instance_valid(_reboot_label):
		_reboot_label.queue_free()
		_reboot_label = null
	if _sfx_debug_label and is_instance_valid(_sfx_debug_label):
		_sfx_debug_label.queue_free()
		_sfx_debug_label = null


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


func _any_heat_source_active() -> bool:
	## Returns true if any active component generates positive thermal.
	for ctrl in _hardpoint_controllers:
		var hc: HardpointController = ctrl as HardpointController
		if hc and hc.is_active() and hc.weapon_data:
			var th: float = float(hc.weapon_data.bar_effects.get("thermal", 0.0))
			if th > 0.0:
				return true
	for ctrl in _core_controllers:
		var cc: PowerCoreController = ctrl as PowerCoreController
		if cc and cc.is_active() and cc.power_core_data:
			# Check legacy bar_effects
			var th: float = float(cc.power_core_data.bar_effects.get("thermal", 0.0))
			if th > 0.0:
				return true
			# Check bar_effect_triggers for any positive thermal
			for bet in cc.power_core_data.bar_effect_triggers:
				var d: Dictionary = bet as Dictionary
				if str(d.get("type", "")) == "thermal" and float(d.get("value", 0.0)) > 0.0:
					return true
			# Check passive_effects
			var pth: float = float(cc.power_core_data.passive_effects.get("thermal", 0.0))
			if pth > 0.0:
				return true
	for ctrl in _device_controllers:
		var dc: DeviceController = ctrl as DeviceController
		if dc and dc.is_active() and dc.device_data:
			var th: float = float(dc.device_data.bar_effects.get("thermal", 0.0))
			if th > 0.0:
				return true
			# Check passive_effects for continuous heat generation
			var pth: float = float(dc.device_data.passive_effects.get("thermal", 0.0))
			if pth > 0.0:
				return true
	return false


func disable_for_death() -> void:
	_is_dead = true
	_death_drifting = true
	# Carry over existing spin if already drifting from power loss, otherwise start fresh
	if _drifting:
		_death_drift_rotation_speed = _drift_rotation_speed
		_death_drift_spin_direction = _drift_spin_direction
	else:
		_death_drift_rotation_speed = 0.0
		_death_drift_spin_direction = 1.0 if randf() > 0.5 else -1.0
	stop_all()
	if _player_area:
		_player_area.set_deferred("monitoring", false)
		_player_area.set_deferred("monitorable", false)


const DEATH_DRIFT_MAX_SPIN: float = 0.2  # rad/sec — same as power loss drift
const DEATH_DRIFT_SPIN_RAMP: float = 4.0  # seconds to reach max spin
const DEATH_DRIFT_DECEL: float = 6.0  # px/s² coast deceleration


func _process_death_drift(delta: float) -> void:
	# Coast existing velocity to a slow stop
	_velocity = _velocity.move_toward(Vector2.ZERO, DEATH_DRIFT_DECEL * delta)
	position += _velocity * delta
	# Clamp to screen
	var clamped_x: float = clampf(position.x, 50.0, 1870.0)
	var clamped_y: float = clampf(position.y, 50.0, 936.0)
	if position.x != clamped_x:
		_velocity.x = 0.0
		position.x = clamped_x
	if position.y != clamped_y:
		_velocity.y = 0.0
		position.y = clamped_y
	# Gradual spin — ramps up to max over DEATH_DRIFT_SPIN_RAMP seconds
	_death_drift_rotation_speed = minf(_death_drift_rotation_speed + (DEATH_DRIFT_MAX_SPIN / DEATH_DRIFT_SPIN_RAMP) * delta, DEATH_DRIFT_MAX_SPIN)
	rotation += _death_drift_rotation_speed * _death_drift_spin_direction * delta


func apply_bar_effects(effects: Dictionary) -> void:
	if _is_dead:
		return
	for bar_type in effects:
		var delta_val: float = float(effects[bar_type])
		match str(bar_type):
			"shield":
				shield = clampf(shield + delta_val, 0.0, shield_max)
			"hull":
				hull = clampf(hull + delta_val, 0.0, hull_max)
			"thermal":
				if delta_val > 0.0 and thermal + delta_val > thermal_max:
					# Thermal overflow — excess heat damages hull directly (bypasses shields)
					var overflow: float = (thermal + delta_val) - thermal_max
					thermal = thermal_max
					hull = maxf(hull - overflow, 0.0)
					hull_hit.emit()
					if _hud and _hud.has_method("trigger_drain_wave"):
						_hud.trigger_drain_wave("HULL")
					if hull <= 0.0:
						died.emit()
				else:
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
	# Track enemy for continuous ram damage (DPS while overlapping)
	if area not in _ram_overlapping:
		_ram_overlapping.append(area)


func _on_contact_exit(area: Area2D) -> void:
	var idx: int = _ram_overlapping.find(area)
	if idx >= 0:
		_ram_overlapping.remove_at(idx)


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
