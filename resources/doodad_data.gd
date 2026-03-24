class_name DoodadData
extends Resource
## Type-safe container for doodad definitions. Populated from JSON at runtime.
## Doodads are decorative objects — no hitpoints, no weapons, just placement.

@export var id: String = ""
@export var display_name: String = ""
@export var level_id: String = ""
@export var doodad_type: String = ""  # References DoodadRegistry type id
@export var scale: float = 1.0


static func from_dict(data: Dictionary) -> DoodadData:
	var d := DoodadData.new()
	d.id = data.get("id", "")
	d.display_name = data.get("display_name", "")
	d.level_id = str(data.get("level_id", ""))
	d.doodad_type = str(data.get("doodad_type", ""))
	d.scale = float(data.get("scale", 1.0))
	return d


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"level_id": level_id,
		"doodad_type": doodad_type,
		"scale": scale,
	}
