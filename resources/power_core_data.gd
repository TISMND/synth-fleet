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
@export var bar_effects: Dictionary = {}  # LEGACY — {"shield": -0.5, ...} flat delta per trigger (replaced by bar_effect_triggers)
@export var bar_effect_triggers: Array = []  # [{time: float, type: String, value: float}, ...] per-beat bar effects
@export var passive_effects: Dictionary = {}  # {"shield": 1.5, "thermal": -0.3, ...} float delta per second
@export var equip_slot: String = "internal"  # always "internal"


static func from_dict(data: Dictionary) -> PowerCoreData:
	var pc := PowerCoreData.new()
	pc.id = data.get("id", "")
	pc.display_name = data.get("display_name", "")
	pc.description = data.get("description", "")
	pc.loop_file_path = data.get("loop_file_path", "")
	pc.loop_length_bars = int(data.get("loop_length_bars", 2))
	var raw_bar_effects: Dictionary = data.get("bar_effects", {}) as Dictionary
	pc.bar_effects = {}
	for key in raw_bar_effects:
		pc.bar_effects[str(key)] = float(raw_bar_effects[key])

	var raw_passive: Dictionary = data.get("passive_effects", {}) as Dictionary
	pc.passive_effects = {}
	for key in raw_passive:
		pc.passive_effects[str(key)] = float(raw_passive[key])

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

	# Bar effect triggers (independent per-beat bar effects)
	var raw_bet: Array = data.get("bar_effect_triggers", []) as Array
	pc.bar_effect_triggers = []
	for entry in raw_bet:
		var d: Dictionary = entry as Dictionary
		pc.bar_effect_triggers.append({
			"time": float(d.get("time", 0.0)),
			"type": str(d.get("type", "thermal")),
			"value": float(d.get("value", 0.0)),
		})

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
		"bar_effects": bar_effects,
		"bar_effect_triggers": bar_effect_triggers,
		"passive_effects": passive_effects,
	}
