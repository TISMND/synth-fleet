class_name BuildingData
extends Resource
## Type-safe container for building definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var level_id: String = ""
@export var hitpoints: float = 100.0
@export var destructible: bool = true
@export var weapon_ids: Array[String] = []  # Weapons attached to this building


static func from_dict(data: Dictionary) -> BuildingData:
	var b := BuildingData.new()
	b.id = data.get("id", "")
	b.display_name = data.get("display_name", "")
	b.level_id = str(data.get("level_id", ""))
	b.hitpoints = float(data.get("hitpoints", 100.0))
	b.destructible = bool(data.get("destructible", true))
	var raw_weapons: Array = data.get("weapon_ids", []) as Array
	var typed_weapons: Array[String] = []
	for w in raw_weapons:
		typed_weapons.append(str(w))
	b.weapon_ids = typed_weapons
	return b


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"level_id": level_id,
		"hitpoints": hitpoints,
		"destructible": destructible,
		"weapon_ids": weapon_ids,
	}
