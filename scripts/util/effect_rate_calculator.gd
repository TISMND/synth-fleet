class_name EffectRateCalculator
extends RefCounted
## Calculates "segments per minute" stats for any component with bar_effects + triggers.
## Works for weapons, power cores, and devices.
## Values are in segments/min (10 points = 1 segment).

const BAR_TYPES: Array[String] = ["shield", "hull", "thermal", "electric"]
const POINTS_PER_SEGMENT: float = 10.0


## Get the duration of a WAV file in seconds.
## Prefers LoopMixer's cached pre-mutation duration to avoid resource-cache coupling.
static func get_loop_duration(loop_path: String) -> float:
	if loop_path == "":
		return 0.0
	# Use LoopMixer's clean cached duration when available (game context)
	var cached: float = LoopMixer.get_cached_duration_by_path(loop_path)
	if cached > 0.0:
		return cached
	# Fallback: load directly (dev studio context where LoopMixer hasn't loaded the stream)
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
		return float(wav.data.size()) / float(bytes_per_sample * channels) / float(wav.mix_rate)
	return stream.get_length()


## Convert raw points/min to segments/min.
static func _to_segments(points_per_min: float) -> float:
	return points_per_min / POINTS_PER_SEGMENT


## Calculate segments/minute for a weapon.
## Beams emit bar_effects every 0.25s for beam_duration per trigger (continuous draw).
## Projectiles emit bar_effects once per trigger (one-shot).
## Returns { "shield": -3.0, "thermal": 4.5, ... }
static func calc_weapon(weapon: WeaponData) -> Dictionary:
	var result: Dictionary = {}
	if weapon.bar_effects.is_empty() or weapon.fire_triggers.is_empty():
		return result
	var duration: float = get_loop_duration(weapon.loop_file_path)
	if duration <= 0.0:
		return result
	var triggers_per_min: float = float(weapon.fire_triggers.size()) / (duration / 60.0)
	# Beams emit bar_effects repeatedly (every 0.25s) over beam_duration per trigger
	var emissions_per_trigger: float = 1.0
	if weapon.beam_style_id != "":
		emissions_per_trigger = maxf(weapon.beam_duration / 0.25, 1.0)
	# Mirror mode fires twice per trigger (both +dir and -dir)
	var mirror_mult: float = 2.0 if weapon.mirror_mode == "mirror" else 1.0
	for bar_type in weapon.bar_effects:
		var val: float = float(weapon.bar_effects[bar_type])
		if not is_zero_approx(val):
			result[str(bar_type)] = _to_segments(val * triggers_per_min * emissions_per_trigger * mirror_mult)
	return result


## Calculate segments/minute for a power core.
## Both bar_effect_triggers AND legacy bar_effects apply simultaneously
## (matching PowerCoreController game logic).
## Also includes passive_effects (converted to per-minute).
static func calc_power_core(core: PowerCoreData) -> Dictionary:
	var result: Dictionary = {}
	var duration: float = get_loop_duration(core.loop_file_path)

	if duration > 0.0:
		var loops_per_min: float = 60.0 / duration

		# bar_effect_triggers: independent per-beat effects (sum per type per loop, × loops/min)
		if not core.bar_effect_triggers.is_empty():
			var per_type: Dictionary = {}
			for entry in core.bar_effect_triggers:
				var d: Dictionary = entry as Dictionary
				var t: String = str(d.get("type", ""))
				var v: float = float(d.get("value", 0.0))
				if t != "" and not is_zero_approx(v):
					per_type[t] = float(per_type.get(t, 0.0)) + v
			for bar_type in per_type:
				result[str(bar_type)] = _to_segments(float(per_type[bar_type]) * loops_per_min)

		# Legacy bar_effects: fire on each pulse_trigger per bar type
		if not core.bar_effects.is_empty():
			for bar_type in core.pulse_triggers:
				var triggers: Array = core.pulse_triggers[bar_type] as Array
				if triggers.is_empty():
					continue
				var effect_val: float = float(core.bar_effects.get(str(bar_type), 0.0))
				if is_zero_approx(effect_val):
					continue
				var triggers_per_min: float = float(triggers.size()) * loops_per_min
				var seg_per_min: float = _to_segments(effect_val * triggers_per_min)
				result[str(bar_type)] = float(result.get(str(bar_type), 0.0)) + seg_per_min

	# Add passive effects (per-second → per-minute → segments)
	for bar_type in core.passive_effects:
		var val: float = _to_segments(float(core.passive_effects[bar_type]) * 60.0)
		if not is_zero_approx(val):
			result[str(bar_type)] = float(result.get(str(bar_type), 0.0)) + val

	return result


## Calculate segments/minute for a device (field emitter, etc.).
static func calc_device(device: DeviceData) -> Dictionary:
	var result: Dictionary = {}
	var duration: float = get_loop_duration(device.loop_file_path)

	if duration > 0.0 and not device.bar_effects.is_empty() and not device.pulse_triggers.is_empty():
		var triggers_per_min: float = float(device.pulse_triggers.size()) / (duration / 60.0)
		for bar_type in device.bar_effects:
			var val: float = float(device.bar_effects[bar_type])
			if not is_zero_approx(val):
				result[str(bar_type)] = _to_segments(val * triggers_per_min)

	# Add passive effects (per-second → per-minute → segments)
	for bar_type in device.passive_effects:
		var val: float = _to_segments(float(device.passive_effects[bar_type]) * 60.0)
		if not is_zero_approx(val):
			result[str(bar_type)] = float(result.get(str(bar_type), 0.0)) + val

	return result


## Format a rates dictionary into a compact display string.
## Returns something like "SHD -3  HUL +1  THR +4"
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
		var sign_str: String = "+" if val > 0 else ""
		parts.append(label + " " + sign_str + str(roundi(val)) + " seg/m")
	return "  ".join(parts)


## Get the color for a bar type.
static func get_bar_color(bar_type: String) -> Color:
	match bar_type:
		"shield": return ThemeManager.get_color("bar_shield")
		"hull": return ThemeManager.get_color("bar_hull")
		"thermal": return ThemeManager.get_color("bar_thermal")
		"electric": return ThemeManager.get_color("bar_electric")
	return Color.WHITE
