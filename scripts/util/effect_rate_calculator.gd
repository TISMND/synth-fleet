class_name EffectRateCalculator
extends RefCounted
## Calculates "effects per minute" stats for any component with bar_effects + triggers.
## Works for weapons, power cores, and devices.

const BAR_TYPES: Array[String] = ["shield", "hull", "thermal", "electric"]


## Get the duration of a WAV file in seconds (without loading into LoopMixer).
static func get_loop_duration(loop_path: String) -> float:
	if loop_path == "":
		return 0.0
	var stream: AudioStream = load(loop_path) as AudioStream
	if not stream:
		return 0.0
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		var duration: float = wav.get_length()
		if duration > 0.0:
			return duration
		# Fallback: byte math
		var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels: int = 2 if wav.stereo else 1
		return float(wav.data.size() / (bytes_per_sample * channels)) / float(wav.mix_rate)
	return stream.get_length()


## Calculate effects/minute for a weapon.
## Returns { "shield": -30.0, "hull": 0.0, ... } — negative = drain, positive = regen.
static func calc_weapon(weapon: WeaponData) -> Dictionary:
	var result: Dictionary = {}
	if weapon.bar_effects.is_empty() or weapon.fire_triggers.is_empty():
		return result
	var duration: float = get_loop_duration(weapon.loop_file_path)
	if duration <= 0.0:
		return result
	var triggers_per_min: float = float(weapon.fire_triggers.size()) / (duration / 60.0)
	for bar_type in weapon.bar_effects:
		var val: float = float(weapon.bar_effects[bar_type])
		if not is_zero_approx(val):
			result[str(bar_type)] = val * triggers_per_min
	return result


## Calculate effects/minute for a power core.
## Handles both bar_effect_triggers (new) and legacy bar_effects.
## Also includes passive_effects (converted to per-minute).
static func calc_power_core(core: PowerCoreData) -> Dictionary:
	var result: Dictionary = {}
	var duration: float = get_loop_duration(core.loop_file_path)

	if duration > 0.0:
		if not core.bar_effect_triggers.is_empty():
			# New format: independent per-beat effects
			var per_type: Dictionary = {}
			for entry in core.bar_effect_triggers:
				var d: Dictionary = entry as Dictionary
				var t: String = str(d.get("type", ""))
				var v: float = float(d.get("value", 0.0))
				if t != "" and not is_zero_approx(v):
					per_type[t] = float(per_type.get(t, 0.0)) + v
			var loops_per_min: float = 60.0 / duration
			for bar_type in per_type:
				result[str(bar_type)] = float(per_type[bar_type]) * loops_per_min
		elif not core.bar_effects.is_empty():
			# Legacy: bar_effects fire on each pulse_trigger
			var total_triggers: int = 0
			for bar_type in core.pulse_triggers:
				var triggers: Array = core.pulse_triggers[bar_type] as Array
				total_triggers = maxi(total_triggers, triggers.size())
			if total_triggers > 0:
				var triggers_per_min: float = float(total_triggers) / (duration / 60.0)
				for bar_type in core.bar_effects:
					var val: float = float(core.bar_effects[bar_type])
					if not is_zero_approx(val):
						result[str(bar_type)] = val * triggers_per_min

	# Add passive effects (per-second → per-minute)
	for bar_type in core.passive_effects:
		var val: float = float(core.passive_effects[bar_type]) * 60.0
		if not is_zero_approx(val):
			result[str(bar_type)] = float(result.get(str(bar_type), 0.0)) + val

	return result


## Calculate effects/minute for a device (field emitter, etc.).
static func calc_device(device: DeviceData) -> Dictionary:
	var result: Dictionary = {}
	var duration: float = get_loop_duration(device.loop_file_path)

	if duration > 0.0 and not device.bar_effects.is_empty() and not device.pulse_triggers.is_empty():
		var triggers_per_min: float = float(device.pulse_triggers.size()) / (duration / 60.0)
		for bar_type in device.bar_effects:
			var val: float = float(device.bar_effects[bar_type])
			if not is_zero_approx(val):
				result[str(bar_type)] = val * triggers_per_min

	# Add passive effects (per-second → per-minute)
	for bar_type in device.passive_effects:
		var val: float = float(device.passive_effects[bar_type]) * 60.0
		if not is_zero_approx(val):
			result[str(bar_type)] = float(result.get(str(bar_type), 0.0)) + val

	return result


## Format an effects/minute dictionary into a display string.
## Returns something like "SHD -30/m  HUL +12/m  THR +45/m"
static func format_rates(rates: Dictionary) -> String:
	if rates.is_empty():
		return ""
	var abbrev: Dictionary = {"shield": "SHD", "hull": "HUL", "thermal": "THR", "electric": "ELC"}
	var parts: Array[String] = []
	for bar_type in BAR_TYPES:
		if not rates.has(bar_type):
			continue
		var val: float = float(rates[bar_type])
		var label: String = str(abbrev.get(bar_type, bar_type.to_upper()))
		var sign: String = "+" if val > 0 else ""
		parts.append(label + " " + sign + str(int(val)) + "/m")
	return "  ".join(parts)


## Get the color for a bar type.
static func get_bar_color(bar_type: String) -> Color:
	match bar_type:
		"shield": return ThemeManager.get_color("bar_shield")
		"hull": return ThemeManager.get_color("bar_hull")
		"thermal": return ThemeManager.get_color("bar_thermal")
		"electric": return ThemeManager.get_color("bar_electric")
	return Color.WHITE
