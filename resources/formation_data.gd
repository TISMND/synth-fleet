class_name FormationData
extends Resource
## Defines a formation — a set of ship slots arranged relative to a center point.

@export var id: String = ""
@export var display_name: String = ""
@export var slots: Array = []  # Array of { "offset": [x, y] }


static func from_dict(data: Dictionary) -> FormationData:
	var f := FormationData.new()
	f.id = data.get("id", "")
	f.display_name = data.get("display_name", "")
	var raw_slots: Array = data.get("slots", [])
	f.slots = []
	for slot in raw_slots:
		var off: Array = slot.get("offset", [0, 0])
		f.slots.append({
			"offset": [float(off[0]), float(off[1])],
		})
	return f


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"slots": slots,
	}


func get_slot_offset(index: int) -> Vector2:
	var slot: Dictionary = slots[index]
	var off: Array = slot["offset"]
	return Vector2(float(off[0]), float(off[1]))


