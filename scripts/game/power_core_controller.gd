class_name PowerCoreController
extends Node
## Per-power-core controller. Tracks loop playback, detects pulse trigger crossings,
## applies bar_effects per hit and passive_effects per second while active.
## Audio handled by LoopMixer (mute/unmute), same pattern as HardpointController.

signal bar_effect_fired(effects: Dictionary)
signal pulse_triggered(bar_types: Array)  # Which bars pulsed on trigger hit

var power_core_data: PowerCoreData = null
var _active: bool = false
var _loop_id: String = ""
var _prev_loop_pos: float = -1.0

# Flattened triggers for fast crossing detection
var _sorted_triggers: Array = []       # Array of [float time, String bar_type]
var _sorted_bar_effect_triggers: Array = []  # Array of {time, type, value} sorted by time


func setup(pc: PowerCoreData, slot_index: int) -> void:
	power_core_data = pc
	_loop_id = pc.id + "_core_" + str(slot_index)
	_rebuild_triggers()

	# Register loop with LoopMixer (muted by default)
	if pc.loop_file_path != "" and not LoopMixer.has_loop(_loop_id):
		LoopMixer.add_loop(_loop_id, pc.loop_file_path, "Master", 0.0, true)


func _rebuild_triggers() -> void:
	_sorted_triggers.clear()
	for bar_type in power_core_data.pulse_triggers:
		var triggers: Array = power_core_data.pulse_triggers[bar_type] as Array
		for t in triggers:
			_sorted_triggers.append([float(t), str(bar_type)])
	_sorted_triggers.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	# Build sorted bar effect triggers
	_sorted_bar_effect_triggers.clear()
	for bet in power_core_data.bar_effect_triggers:
		var d: Dictionary = bet as Dictionary
		_sorted_bar_effect_triggers.append(d.duplicate())
	_sorted_bar_effect_triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)


func activate() -> void:
	if _active:
		return
	_active = true
	_prev_loop_pos = -1.0
	LoopMixer.unmute(_loop_id)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	LoopMixer.mute(_loop_id)


func toggle() -> void:
	if _active:
		deactivate()
	else:
		activate()


func is_active() -> bool:
	return _active


func cleanup() -> void:
	LoopMixer.remove_loop(_loop_id)


func _process(delta: float) -> void:
	if not _active or not power_core_data:
		return

	# Passive effects — apply per second while active
	if not power_core_data.passive_effects.is_empty():
		var passive_delta: Dictionary = {}
		for bar_type in power_core_data.passive_effects:
			var rate: float = float(power_core_data.passive_effects[bar_type])
			if rate != 0.0:
				passive_delta[str(bar_type)] = rate * delta
		if not passive_delta.is_empty():
			bar_effect_fired.emit(passive_delta)

	# Trigger crossing detection
	var has_pulse: bool = not _sorted_triggers.is_empty()
	var has_bar_effects: bool = not _sorted_bar_effect_triggers.is_empty()
	if not has_pulse and not has_bar_effects:
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

	# Check pulse triggers for crossing (visual pulse only)
	var pulsed_bars: Array = []
	for trigger_pair in _sorted_triggers:
		var t: float = float(trigger_pair[0])
		if _trigger_crossed(prev, curr, t):
			var bar_type: String = str(trigger_pair[1])
			if not pulsed_bars.has(bar_type):
				pulsed_bars.append(bar_type)

	if not pulsed_bars.is_empty():
		pulse_triggered.emit(pulsed_bars)

	# Check bar effect triggers (independent of pulse triggers)
	var hit_effects: Dictionary = {}
	for bet in _sorted_bar_effect_triggers:
		var bet_dict: Dictionary = bet as Dictionary
		var t: float = float(bet_dict.get("time", 0.0))
		if _trigger_crossed(prev, curr, t):
			var effect_type: String = str(bet_dict.get("type", ""))
			var effect_value: float = float(bet_dict.get("value", 0.0))
			if effect_type != "" and effect_value != 0.0:
				var existing: float = float(hit_effects.get(effect_type, 0.0))
				hit_effects[effect_type] = existing + effect_value

	# Apply legacy bar_effects only for the specific bar types that pulsed
	if not pulsed_bars.is_empty() and not power_core_data.bar_effects.is_empty():
		for pulsed_type in pulsed_bars:
			var key: String = str(pulsed_type)
			if power_core_data.bar_effects.has(key):
				var val: float = float(power_core_data.bar_effects[key])
				if val != 0.0:
					var existing: float = float(hit_effects.get(key, 0.0))
					hit_effects[key] = existing + val

	if not hit_effects.is_empty():
		bar_effect_fired.emit(hit_effects)


func _trigger_crossed(prev: float, curr: float, trigger: float) -> bool:
	if curr >= prev:
		return trigger > prev and trigger <= curr
	else:
		return trigger > prev or trigger <= curr
