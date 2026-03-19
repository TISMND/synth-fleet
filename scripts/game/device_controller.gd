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
var _orbiter_renderer: OrbiterRenderer = null
var _collision_area: Area2D = null

# Fade state
var _fading: bool = false
var _fade_target: float = 0.0
var _fade_speed: float = 0.0
var _current_opacity: float = 0.0


func setup(device: DeviceData, slot_index: int, ship_node: Node2D) -> void:
	device_data = device
	_loop_id = device.id + "_dev_" + str(slot_index)

	# Register loop with LoopMixer (muted by default)
	if device.loop_file_path != "" and not LoopMixer.has_loop(_loop_id):
		LoopMixer.add_loop(_loop_id, device.loop_file_path, "Master", 0.0, true)

	# Create visual renderer as child of ship_node
	if device.visual_mode == "orbiter" and device.orbiter_style_id != "":
		var orb_style: OrbiterStyle = OrbiterStyleManager.load_by_id(device.orbiter_style_id)
		if orb_style:
			_orbiter_renderer = OrbiterRenderer.new()
			ship_node.add_child(_orbiter_renderer)
			_orbiter_renderer.setup(orb_style)
			_orbiter_renderer.set_orbit_radius(device.radius)
			_orbiter_renderer.set_lifetime(device.orbiter_lifetime)
			_orbiter_renderer.set_fade_durations(device.fade_in_duration, device.fade_out_duration)
			_orbiter_renderer.visible = false

	if not _orbiter_renderer:
		# Field mode (default)
		var style: FieldStyle = null
		if device.field_style_id != "":
			style = FieldStyleManager.load_by_id(device.field_style_id)
		if not style:
			style = FieldStyle.new()
			style.color = device.color_override if device.color_override != Color.WHITE else Color(0.0, 1.0, 1.0, 1.0)

		_field_renderer = FieldRenderer.new()
		ship_node.add_child(_field_renderer)
		_field_renderer.setup(style, device.radius, device.animation_speed)
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
	LoopMixer.unmute(_loop_id)
	if _orbiter_renderer:
		_orbiter_renderer.visible = true
	else:
		_start_fade(1.0, device_data.fade_in_duration)
	if _collision_area:
		_collision_area.monitoring = true


func deactivate() -> void:
	if not _active:
		return
	_active = false
	LoopMixer.mute(_loop_id)
	if _orbiter_renderer:
		_orbiter_renderer.remove_all()
		_orbiter_renderer.visible = false
	else:
		_start_fade(0.0, device_data.fade_out_duration)
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
	if _orbiter_renderer and is_instance_valid(_orbiter_renderer):
		_orbiter_renderer.queue_free()
	if _collision_area and is_instance_valid(_collision_area):
		_collision_area.queue_free()


func _start_fade(target: float, duration: float) -> void:
	_fade_target = target
	if duration <= 0.0:
		_current_opacity = target
		if _field_renderer:
			_field_renderer.set_opacity(target)
		_fading = false
	else:
		_fade_speed = absf(target - _current_opacity) / duration
		_fading = true


func _process(delta: float) -> void:
	# Drive fade
	if _fading:
		if _current_opacity < _fade_target:
			_current_opacity = minf(_current_opacity + _fade_speed * delta, _fade_target)
		else:
			_current_opacity = maxf(_current_opacity - _fade_speed * delta, _fade_target)
		if _field_renderer:
			_field_renderer.set_opacity(_current_opacity)
		if absf(_current_opacity - _fade_target) < 0.001:
			_current_opacity = _fade_target
			_fading = false

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

	# Trigger crossing detection (flat pulse_triggers array)
	if device_data.pulse_triggers.is_empty():
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

	# Check each trigger for crossing
	var any_crossed: bool = false
	for t in device_data.pulse_triggers:
		var tval: float = float(t)
		if _trigger_crossed(prev, curr, tval):
			any_crossed = true

	if any_crossed:
		pulse_triggered.emit()
		if _field_renderer:
			_field_renderer.pulse()
		if _orbiter_renderer:
			_orbiter_renderer.spawn_batch()
		if not device_data.bar_effects.is_empty():
			bar_effect_fired.emit(device_data.bar_effects)


func _trigger_crossed(prev: float, curr: float, trigger: float) -> bool:
	if curr >= prev:
		return trigger > prev and trigger <= curr
	else:
		return trigger > prev or trigger <= curr
