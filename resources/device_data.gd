class_name DeviceData
extends Resource
## Type-safe container for device definitions. Populated from JSON at runtime.
## Devices produce field effects (force fields, shields, damage auras, etc.)
## with audio loops and beat-synced pulse triggers.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var loop_file_path: String = ""
@export var loop_length_bars: int = 2
@export var pulse_triggers: Array = []  # Array[float] normalized 0.0–1.0
@export var visual_mode: String = "field"  # "field" or "orbiter"
@export var field_style_id: String = ""
@export var orbiter_style_id: String = ""
@export var orbiter_lifetime: float = 4.0  # seconds before orbiters fade out (0 = infinite)
@export var radius: float = 100.0
@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.3
@export var animation_speed: float = 1.0
@export var device_type: String = "shield_aura"
@export var mechanic_params: Dictionary = {}
@export var bar_effects: Dictionary = {}  # {"shield": 0.5, ...} float delta per trigger hit
@export var passive_effects: Dictionary = {}  # {"shield": 1.5, ...} float delta per second
@export var color_override: Color = Color.WHITE


static func from_dict(data: Dictionary) -> DeviceData:
	var d := DeviceData.new()
	d.id = str(data.get("id", ""))
	d.display_name = str(data.get("display_name", ""))
	d.description = str(data.get("description", ""))
	d.loop_file_path = str(data.get("loop_file_path", ""))
	d.loop_length_bars = int(data.get("loop_length_bars", 2))
	d.visual_mode = str(data.get("visual_mode", "field"))
	d.field_style_id = str(data.get("field_style_id", ""))
	d.orbiter_style_id = str(data.get("orbiter_style_id", ""))
	d.orbiter_lifetime = float(data.get("orbiter_lifetime", 4.0))
	d.radius = float(data.get("radius", 100.0))
	d.fade_in_duration = float(data.get("fade_in_duration", 0.3))
	d.fade_out_duration = float(data.get("fade_out_duration", 0.3))
	d.animation_speed = float(data.get("animation_speed", 1.0))
	d.device_type = str(data.get("device_type", "shield_aura"))
	# Parse pulse_triggers — flat array of floats
	var raw_triggers: Array = data.get("pulse_triggers", []) as Array
	d.pulse_triggers = []
	for t in raw_triggers:
		d.pulse_triggers.append(float(t))
	d.pulse_triggers.sort()

	# Parse mechanic_params
	d.mechanic_params = data.get("mechanic_params", {}) as Dictionary

	# Parse bar_effects
	var raw_bar_effects: Dictionary = data.get("bar_effects", {}) as Dictionary
	d.bar_effects = {}
	for key in raw_bar_effects:
		d.bar_effects[str(key)] = float(raw_bar_effects[key])

	# Parse passive_effects
	var raw_passive: Dictionary = data.get("passive_effects", {}) as Dictionary
	d.passive_effects = {}
	for key in raw_passive:
		d.passive_effects[str(key)] = float(raw_passive[key])

	# Parse color_override
	var color_data: Array = data.get("color_override", []) as Array
	if color_data.size() >= 4:
		d.color_override = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))
	elif color_data.size() >= 3:
		d.color_override = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), 1.0)

	return d


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"loop_file_path": loop_file_path,
		"loop_length_bars": loop_length_bars,
		"pulse_triggers": pulse_triggers,
		"visual_mode": visual_mode,
		"field_style_id": field_style_id,
		"orbiter_style_id": orbiter_style_id,
		"orbiter_lifetime": orbiter_lifetime,
		"radius": radius,
		"fade_in_duration": fade_in_duration,
		"fade_out_duration": fade_out_duration,
		"animation_speed": animation_speed,
		"device_type": device_type,
		"mechanic_params": mechanic_params,
		"bar_effects": bar_effects,
		"passive_effects": passive_effects,
		"color_override": [color_override.r, color_override.g, color_override.b, color_override.a],
	}
