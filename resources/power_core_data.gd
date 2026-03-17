class_name PowerCoreData
extends Resource
## Type-safe container for power core definitions. Populated from JSON at runtime.
## Power cores pulse status bars (shield/hull/thermal/electric) at beat-synced trigger positions.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var loop_file_path: String = ""
@export var loop_length_bars: int = 2
@export var pulse_triggers: Dictionary = {}  # {"shield": [0.0, 0.5], "hull": [0.25], ...}
@export var global_pulse_settings: Dictionary = {"brightness": 0.5, "brighten_duration": 0.05, "dim_duration": 0.3}
@export var pulse_settings: Dictionary = {}  # Per-bar overrides keyed by bar type, same shape as global
@export var power_cost: int = 5


static func from_dict(data: Dictionary) -> PowerCoreData:
	var pc := PowerCoreData.new()
	pc.id = data.get("id", "")
	pc.display_name = data.get("display_name", "")
	pc.description = data.get("description", "")
	pc.loop_file_path = data.get("loop_file_path", "")
	pc.loop_length_bars = int(data.get("loop_length_bars", 2))
	pc.power_cost = int(data.get("power_cost", 5))

	# Parse pulse_triggers — ensure all values are Array[float]
	var raw_triggers: Dictionary = data.get("pulse_triggers", {}) as Dictionary
	pc.pulse_triggers = {}
	for bar_type in raw_triggers:
		var raw_arr: Array = raw_triggers[bar_type] as Array
		var arr: Array = []
		for t in raw_arr:
			arr.append(float(t))
		arr.sort()
		pc.pulse_triggers[str(bar_type)] = arr

	# Parse global pulse settings
	var raw_global: Dictionary = data.get("global_pulse_settings", {}) as Dictionary
	pc.global_pulse_settings = {
		"brightness": float(raw_global.get("brightness", 0.5)),
		"brighten_duration": float(raw_global.get("brighten_duration", 0.05)),
		"dim_duration": float(raw_global.get("dim_duration", 0.3)),
	}

	# Parse per-bar pulse settings overrides
	var raw_settings: Dictionary = data.get("pulse_settings", {}) as Dictionary
	pc.pulse_settings = {}
	for bar_type in raw_settings:
		var raw_bar: Dictionary = raw_settings[bar_type] as Dictionary
		pc.pulse_settings[str(bar_type)] = {
			"brightness": float(raw_bar.get("brightness", 0.5)),
			"brighten_duration": float(raw_bar.get("brighten_duration", 0.05)),
			"dim_duration": float(raw_bar.get("dim_duration", 0.3)),
		}

	return pc


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"loop_file_path": loop_file_path,
		"loop_length_bars": loop_length_bars,
		"pulse_triggers": pulse_triggers,
		"global_pulse_settings": global_pulse_settings,
		"pulse_settings": pulse_settings,
		"power_cost": power_cost,
	}
