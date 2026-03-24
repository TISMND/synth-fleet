class_name DoodadRegistry
## Static registry of doodad types for background decoration.
## Pure code, no JSON. Same pattern as ShipRegistry.

const TYPES: Dictionary = {
	"water_tower":    {"display_name": "Water Tower",    "index": 0},
	"antenna":        {"display_name": "Antenna",        "index": 1},
	"satellite_dish": {"display_name": "Satellite Dish", "index": 2},
	"ac_cluster":     {"display_name": "AC Cluster",     "index": 3},
	"solar_panels":   {"display_name": "Solar Panels",   "index": 4},
	"rooftop_garden": {"display_name": "Rooftop Garden", "index": 5},
	"crate_stack":    {"display_name": "Crate Stack",    "index": 6},
	"vent_pipe":      {"display_name": "Vent Pipe",      "index": 7},
}


static func get_type_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in TYPES:
		ids.append(str(key))
	return ids


static func get_display_name(type_id: String) -> String:
	if TYPES.has(type_id):
		var entry: Dictionary = TYPES[type_id]
		return str(entry["display_name"])
	return type_id
