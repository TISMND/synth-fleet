class_name NebulaData
extends Resource
## Type-safe container for nebula definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var style_id: String = "classic_fbm"
@export var shader_params: Dictionary = {}
@export var bar_effects: Dictionary = {}  # bar_name -> float rate per second (negative = drain, positive = fill)
@export var special_effects: Array[String] = []  # e.g. "cloak", "slow", "damage_boost"
@export var key_change_id: String = ""  # references a KeyChangeData preset
@export var event_ids: Array[String] = []  # references GameEventData IDs to trigger periodically
@export var event_interval_min: float = 5.0  # minimum seconds between event triggers
@export var event_interval_max: float = 12.0  # maximum seconds between event triggers


static func default_params() -> Dictionary:
	return {
		"nebula_color": [0.3, 0.4, 0.9, 1.0],
		"secondary_color": [1.0, 0.5, 0.2, 1.0],
		"brightness": 1.5,
		"animation_speed": 0.5,
		"density": 1.5,
		"seed_offset": 0.0,
		"radial_spread": 0.2,
		"bottom_opacity": 1.0,
		"top_opacity": 0.1,
		"veil_contrast": 0.5,
		"wash_opacity": 0.0,
		"storm_enabled": false,
		"storm_frequency": 0.4,
		"storm_strike_size": 0.12,
		"storm_duration": 0.2,
		"storm_glow_diameter": 0.3,
	}


static func from_dict(data: Dictionary) -> NebulaData:
	var n := NebulaData.new()
	n.id = data.get("id", "")
	n.display_name = data.get("display_name", "")
	n.style_id = data.get("style_id", "classic_fbm")
	var params: Dictionary = data.get("shader_params", {})
	var defaults: Dictionary = default_params()
	# Migrate old storm_intensity → storm_frequency
	if params.has("storm_intensity") and not params.has("storm_frequency"):
		params["storm_frequency"] = params["storm_intensity"]
	params.erase("storm_intensity")
	for key in defaults:
		if not params.has(key):
			params[key] = defaults[key]
	n.shader_params = params

	# Bar effects: bar_name -> rate (float, per second)
	var raw_bar_effects: Dictionary = data.get("bar_effects", {})
	var typed_bar_effects: Dictionary = {}
	for key in raw_bar_effects:
		typed_bar_effects[str(key)] = float(raw_bar_effects[key])
	n.bar_effects = typed_bar_effects

	# Special effects: array of string IDs
	var raw_specials: Array = data.get("special_effects", []) as Array
	var typed_specials: Array[String] = []
	for s in raw_specials:
		typed_specials.append(str(s))
	n.special_effects = typed_specials

	# Key change preset
	n.key_change_id = str(data.get("key_change_id", ""))

	# Game events
	var raw_events: Array = data.get("event_ids", []) as Array
	var typed_events: Array[String] = []
	for ev in raw_events:
		typed_events.append(str(ev))
	n.event_ids = typed_events
	n.event_interval_min = float(data.get("event_interval_min", 5.0))
	n.event_interval_max = float(data.get("event_interval_max", 12.0))

	return n


func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id": id,
		"display_name": display_name,
		"style_id": style_id,
		"shader_params": shader_params,
	}
	if bar_effects.size() > 0:
		d["bar_effects"] = bar_effects
	if special_effects.size() > 0:
		d["special_effects"] = special_effects
	if key_change_id != "":
		d["key_change_id"] = key_change_id
	if event_ids.size() > 0:
		d["event_ids"] = event_ids
		d["event_interval_min"] = event_interval_min
		d["event_interval_max"] = event_interval_max
	return d
