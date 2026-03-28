class_name DeviceController
extends Node
## Per-device controller. Tracks loop playback, detects pulse trigger crossings,
## manages FieldRenderer visual + collision Area2D. Audio handled by LoopMixer.

signal bar_effect_fired(effects: Dictionary)
signal pulse_triggered()

var device_data: DeviceData = null
var _active: bool = false
var _loop_id: String = ""
var _prev_loop_pos: float = -1.0
var _field_renderer: FieldRenderer = null
var _collision_area: Area2D = null
var _field_style: FieldStyle = null

# Active envelope state (per-trigger field visibility)
var _active_envelope_active: bool = false
var _active_envelope_elapsed: float = 0.0


func setup(device: DeviceData, slot_index: int, ship_node: Node2D) -> void:
	device_data = device
	_loop_id = device.id + "_dev_" + str(slot_index)

	# Register loop with LoopMixer (muted by default)
	if device.loop_file_path != "" and not LoopMixer.has_loop(_loop_id):
		LoopMixer.add_loop(_loop_id, device.loop_file_path, "Weapons", 0.0, true)

	# Create visual renderer as child of ship_node
	var style: FieldStyle = null
	if device.field_style_id != "":
		style = FieldStyleManager.load_by_id(device.field_style_id)
	if not style:
		style = FieldStyle.new()
		style.color = Color(0.0, 1.0, 1.0, 1.0)
	_field_style = style

	_field_renderer = FieldRenderer.new()
	ship_node.add_child(_field_renderer)
	_field_renderer.setup(style, device.radius)
	_field_renderer.set_pulse_timing(device.pulse_total_duration, device.pulse_fade_up, device.pulse_fade_out)
	_field_renderer.set_opacity(0.0)

	# Create collision Area2D on layer 8
	_collision_area = Area2D.new()
	_collision_area.collision_layer = 128  # layer 8
	_collision_area.collision_mask = 4     # enemies
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = device.radius
	shape.shape = circle
	_collision_area.add_child(shape)
	_collision_area.monitoring = false  # starts disabled
	ship_node.add_child(_collision_area)


func activate() -> void:
	if _active:
		return
	_active = true
	_prev_loop_pos = -1.0
	var fade_ms: int = _get_fade_in_ms()
	LoopMixer.unmute(_loop_id, fade_ms)
	# Always-on mode: field is permanently visible when device is active
	if _field_renderer and device_data.active_always_on:
		_field_renderer.set_opacity(1.0)
	if _collision_area:
		_collision_area.monitoring = true


func deactivate() -> void:
	if not _active:
		return
	_active = false
	var fade_ms: int = _get_fade_out_ms()
	LoopMixer.mute(_loop_id, fade_ms)
	# Kill active envelope and hide field immediately
	_active_envelope_active = false
	if _field_renderer:
		_field_renderer.set_opacity(0.0)
	if _collision_area:
		_collision_area.monitoring = false


func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()


func is_active() -> bool:
	return _active


func cleanup() -> void:
	LoopMixer.remove_loop(_loop_id)
	if _field_renderer and is_instance_valid(_field_renderer):
		_field_renderer.queue_free()
	if _collision_area and is_instance_valid(_collision_area):
		_collision_area.queue_free()


func _get_fade_in_ms() -> int:
	if not device_data or device_data.transition_mode != "fade":
		return 0
	return device_data.fade_in_ms


func _get_fade_out_ms() -> int:
	if not device_data or device_data.transition_mode != "fade":
		return 0
	return device_data.fade_out_ms


func _process(delta: float) -> void:
	# Always-on mode: keep opacity at 1.0, skip envelope
	if _field_renderer and device_data and device_data.active_always_on and _active:
		_field_renderer.set_opacity(1.0)
	# Drive active envelope (per-trigger field visibility)
	elif _active_envelope_active and _field_renderer and device_data:
		var total_dur: float = device_data.active_total_duration
		var fade_in: float = device_data.active_fade_in
		var fade_out: float = device_data.active_fade_out
		if fade_in + fade_out > total_dur:
			var ratio: float = total_dur / maxf(fade_in + fade_out, 0.001)
			fade_in *= ratio
			fade_out *= ratio
		_active_envelope_elapsed += delta
		if _active_envelope_elapsed >= total_dur:
			_active_envelope_active = false
			_field_renderer.set_opacity(0.0)
		else:
			var fade_out_start: float = total_dur - fade_out
			var envelope: float
			if _active_envelope_elapsed < fade_in:
				envelope = _active_envelope_elapsed / maxf(fade_in, 0.001)
			elif _active_envelope_elapsed < fade_out_start:
				envelope = 1.0
			else:
				var remaining: float = total_dur - _active_envelope_elapsed
				envelope = remaining / maxf(fade_out, 0.001)
			_field_renderer.set_opacity(clampf(envelope, 0.0, 1.0))

	if not _active or not device_data:
		return

	# Passive effects — apply per second while active
	if not device_data.passive_effects.is_empty():
		var passive_delta: Dictionary = {}
		for bar_type in device_data.passive_effects:
			var rate: float = float(device_data.passive_effects[bar_type])
			if rate != 0.0:
				passive_delta[str(bar_type)] = rate * delta
		if not passive_delta.is_empty():
			bar_effect_fired.emit(passive_delta)

	# Trigger crossing detection
	var has_functional: bool = not device_data.pulse_triggers.is_empty()
	var has_cosmetic: bool = _field_renderer != null and not device_data.visual_pulse_triggers.is_empty()
	if not has_functional and not has_cosmetic:
		return

	var pos_sec: float = LoopMixer.get_playback_position(_loop_id)
	var duration: float = LoopMixer.get_stream_duration(_loop_id)
	if pos_sec < 0.0 or duration <= 0.0:
		return

	var curr: float = pos_sec / duration

	if _prev_loop_pos < 0.0:
		_prev_loop_pos = curr
		return

	var prev: float = _prev_loop_pos
	_prev_loop_pos = curr

	# Pass 1: Functional triggers (pulse_triggers) — bar_effects, signal
	if has_functional:
		var any_crossed: bool = false
		for t in device_data.pulse_triggers:
			var tval: float = float(t)
			if _trigger_crossed(prev, curr, tval):
				any_crossed = true
		if any_crossed:
			pulse_triggered.emit()
			# Start active envelope — field becomes visible
			if _field_renderer:
				_active_envelope_active = true
				_active_envelope_elapsed = 0.0
			if not device_data.bar_effects.is_empty():
				bar_effect_fired.emit(device_data.bar_effects)

	# Pass 2: Cosmetic triggers (visual_pulse_triggers) — field shader pulse only
	if has_cosmetic:
		for t in device_data.visual_pulse_triggers:
			var tval: float = float(t)
			if _trigger_crossed(prev, curr, tval):
				_field_renderer.pulse()
				break  # One pulse per frame is enough


## Returns the ship tint Color this device wants to apply (RGB modulate).
## Returns null-equivalent Color(1,1,1,1) if inactive or no field style.
func get_ship_tint() -> Color:
	if not _active or not _field_style or not _field_renderer:
		return Color(1.0, 1.0, 1.0, 1.0)
	var pulse_val: float = _field_renderer.get_pulse_intensity()
	var active_hdr: float = _field_style.ship_active_hdr
	var pulse_hdr: float = _field_style.ship_pulse_hdr
	var bright: float = 1.0 + active_hdr + pulse_val * pulse_hdr
	var field_col: Color = _field_style.color
	var tint_strength: float = _field_style.ship_tint_strength
	var tint_scaled: float = tint_strength * (_field_style.glow_intensity / 1.5)
	var r: float = lerpf(bright, field_col.r * bright * 1.5, tint_scaled)
	var g: float = lerpf(bright, field_col.g * bright * 1.5, tint_scaled)
	var b: float = lerpf(bright, field_col.b * bright * 1.5, tint_scaled)
	return Color(r, g, b, 1.0)


func _trigger_crossed(prev: float, curr: float, trigger: float) -> bool:
	if curr >= prev:
		return trigger > prev and trigger <= curr
	else:
		return trigger > prev or trigger <= curr
