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
@export var audio_sample_path: String = ""
@export var audio_pitch: float = 1.0
@export var note_duration: String = "1/8"
@export var fire_pattern: String = "single"
@export var effect_profile: Dictionary = {}
@export var special_effect: String = "none"


static func from_dict(data: Dictionary) -> WeaponData:
	var w := WeaponData.new()
	w.id = data.get("id", "")
	w.display_name = data.get("display_name", "")
	w.description = data.get("description", "")
	w.color = data.get("color", "#00FFFF")
	w.damage = int(data.get("damage", 10))
	w.projectile_speed = float(data.get("projectile_speed", 600.0))
	w.power_cost = int(data.get("power_cost", 5))
	w.audio_sample_path = data.get("audio_sample_path", "")
	w.audio_pitch = float(data.get("audio_pitch", 1.0))
	w.note_duration = data.get("note_duration", "1/8")
	w.fire_pattern = data.get("fire_pattern", "single")
	w.effect_profile = data.get("effect_profile", {})
	w.special_effect = data.get("special_effect", "none")
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
		"audio_sample_path": audio_sample_path,
		"audio_pitch": audio_pitch,
		"note_duration": note_duration,
		"fire_pattern": fire_pattern,
		"effect_profile": effect_profile,
		"special_effect": special_effect,
	}
