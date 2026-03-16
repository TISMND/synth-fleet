class_name WeaponData
extends Resource
## Type-safe container for weapon definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var color: String = "#00FFFF"
@export var damage: int = 10
@export var projectile_speed: float = 600.0
@export var power_cost: int = 5
@export var loop_file_path: String = ""
@export var loop_length_bars: int = 2
@export var fire_triggers: Array = []  # Array of float beat positions
@export var fire_pattern: String = "single"
@export var effect_profile: Dictionary = {}
@export var special_effect: String = "none"
@export var direction_deg: float = 0.0


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
	for t in triggers:
		w.fire_triggers.append(float(t))
	w.fire_pattern = data.get("fire_pattern", "single")
	w.effect_profile = data.get("effect_profile", {})
	w.special_effect = data.get("special_effect", "none")
	w.direction_deg = float(data.get("direction_deg", 0.0))
	return w


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
	}
