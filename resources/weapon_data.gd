class_name WeaponData
extends Resource
## Type-safe container for weapon definitions. Populated from JSON at runtime.
## effect_profile uses v2 format: { version: 2, defaults: { slot: [layers...] }, trigger_overrides: {...} }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var color: String = "#00FFFF"
@export var damage: int = 10
@export var projectile_speed: float = 600.0
@export var power_cost: int = 5
@export var loop_file_path: String = ""
@export var loop_length_bars: int = 2
@export var fire_triggers: Array = []  # Array of float, normalized time 0.0–1.0
@export var fire_pattern: String = "single"
@export var effect_profile: Dictionary = {}
@export var special_effect: String = "none"
@export var direction_deg: float = 0.0
@export var projectile_style_id: String = ""


static func from_dict(data: Dictionary) -> WeaponData:
	var w := WeaponData.new()
	w.id = data.get("id", "")
	w.display_name = data.get("display_name", "")
	w.description = data.get("description", "")
	w.color = data.get("color", "#00FFFF")
	w.damage = int(data.get("damage", 10))
	w.projectile_speed = float(data.get("projectile_speed", 600.0))
	w.power_cost = int(data.get("power_cost", 5))
	w.loop_file_path = data.get("loop_file_path", "")
	w.loop_length_bars = int(data.get("loop_length_bars", 2))
	var triggers: Array = data.get("fire_triggers", [])
	w.fire_triggers = []
	# Migration: if any trigger > 1.0, they're old beat-position format
	var needs_conversion: bool = false
	for t in triggers:
		if float(t) > 1.0:
			needs_conversion = true
			break
	if needs_conversion and w.loop_length_bars > 0:
		var total_beats: float = float(w.loop_length_bars) * 4.0
		for t in triggers:
			w.fire_triggers.append(float(t) / total_beats)
	else:
		for t in triggers:
			w.fire_triggers.append(float(t))
	w.fire_pattern = data.get("fire_pattern", "single")
	w.effect_profile = _migrate_effect_profile(data.get("effect_profile", {}))
	w.special_effect = data.get("special_effect", "none")
	w.direction_deg = float(data.get("direction_deg", 0.0))
	w.projectile_style_id = str(data.get("projectile_style_id", ""))
	return w


## Ensure effect_profile is v2 format. Auto-migrates v1.
static func _migrate_effect_profile(ep: Dictionary) -> Dictionary:
	var version: int = int(ep.get("version", 0))
	if version >= 2:
		return ep
	# v1 or unversioned: each slot is {type, params} — wrap in array under "defaults"
	if ep.is_empty():
		return {"version": 2, "defaults": {}, "trigger_overrides": {}}
	# Check if this is already v2 (has "defaults" key)
	if ep.has("defaults"):
		var result: Dictionary = ep.duplicate(true)
		result["version"] = 2
		return result
	# v1 migration: wrap each slot value in an array
	var defaults: Dictionary = {}
	for slot in ["shape", "motion", "muzzle", "trail", "impact"]:
		var layer_data: Dictionary = ep.get(slot, {}) as Dictionary
		if layer_data.is_empty():
			continue
		var type_val: String = str(layer_data.get("type", "none"))
		if type_val == "none":
			continue
		defaults[slot] = [layer_data]
	return {"version": 2, "defaults": defaults, "trigger_overrides": {}}


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"color": color,
		"damage": damage,
		"projectile_speed": projectile_speed,
		"power_cost": power_cost,
		"loop_file_path": loop_file_path,
		"loop_length_bars": loop_length_bars,
		"fire_triggers": fire_triggers,
		"fire_pattern": fire_pattern,
		"effect_profile": effect_profile,
		"special_effect": special_effect,
		"direction_deg": direction_deg,
		"projectile_style_id": projectile_style_id,
	}
