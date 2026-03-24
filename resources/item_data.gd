class_name ItemData
extends Resource
## Type-safe container for item definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "powerup"  # "powerup" or "money"
@export var value: float = 100.0  # Money amount or powerup strength
@export var duration: float = 0.0  # Powerup duration in seconds (0 = instant)
@export var effect_type: String = ""  # e.g. "shield_restore", "speed_boost", "damage_boost"


static func from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = data.get("id", "")
	item.display_name = data.get("display_name", "")
	item.category = str(data.get("category", "powerup"))
	item.value = float(data.get("value", 100.0))
	item.duration = float(data.get("duration", 0.0))
	item.effect_type = str(data.get("effect_type", ""))
	return item


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"value": value,
		"duration": duration,
		"effect_type": effect_type,
	}
