class_name LoadoutData
extends Resource
## Type-safe container for loadout definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var ship_id: String = ""
@export var hardpoint_assignments: Dictionary = {}
# hardpoint_assignments structure:
# {
#   "hp_1": {
#     "weapon_id": "laser_pulse_01",
#     "stages": [
#       { "stage_number": 1, "loop_length": 8, "pattern": [...] }
#     ]
#   }
# }


static func from_dict(data: Dictionary) -> LoadoutData:
	var l := LoadoutData.new()
	l.id = data.get("id", "")
	l.ship_id = data.get("ship_id", "")
	l.hardpoint_assignments = data.get("hardpoint_assignments", {})
	return l


func to_dict() -> Dictionary:
	return {
		"id": id,
		"ship_id": ship_id,
		"hardpoint_assignments": hardpoint_assignments,
	}
