class_name ShipData
extends Resource
## Type-safe container for ship definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var type: String = "player"  # "player" or "enemy"
@export var grid_size: Vector2i = Vector2i(32, 32)
@export var lines: Array = []  # Array of { from: [x,y], to: [x,y], color: "#hex" }
@export var hardpoints: Array = []  # Array of { id, label, grid_pos: [x,y], direction_deg }
@export var stats: Dictionary = {
	"hull_max": 100,
	"shield_max": 50,
	"speed": 400,
	"generator_power": 10,
	"device_slots": 2,
	"shield_segments": 10,
	"hull_segments": 8,
	"thermal_segments": 6,
	"electric_segments": 8,
}


static func from_dict(data: Dictionary) -> ShipData:
	var s := ShipData.new()
	s.id = data.get("id", "")
	s.display_name = data.get("display_name", "")
	s.type = data.get("type", "player")
	var gs: Array = data.get("grid_size", [32, 32])
	s.grid_size = Vector2i(int(gs[0]), int(gs[1]))
	s.lines = data.get("lines", [])
	s.hardpoints = data.get("hardpoints", [])
	var default_stats: Dictionary = {
		"hull_max": 100,
		"shield_max": 50,
		"speed": 400,
		"generator_power": 10,
		"shield_segments": 10,
		"hull_segments": 8,
		"thermal_segments": 6,
		"electric_segments": 8,
	}
	s.stats = data.get("stats", default_stats)
	# Fill missing segment keys with defaults
	for k in default_stats:
		if not s.stats.has(k):
			s.stats[k] = default_stats[k]
	return s


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"type": type,
		"grid_size": [grid_size.x, grid_size.y],
		"lines": lines,
		"hardpoints": hardpoints,
		"stats": stats,
	}
