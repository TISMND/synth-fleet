class_name LevelData
extends Resource
## Defines a complete level — BPM, scroll speed, length, and encounter placements.

@export var id: String = ""
@export var display_name: String = ""
@export var bpm: float = 110.0
@export var scroll_speed: float = 80.0
@export var level_length: float = 10000.0
@export var encounters: Array = []  # Array of encounter dicts


static func from_dict(data: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.id = data.get("id", "")
	l.display_name = data.get("display_name", "")
	l.bpm = float(data.get("bpm", 110.0))
	l.scroll_speed = float(data.get("scroll_speed", 80.0))
	l.level_length = float(data.get("level_length", 10000.0))
	var raw_enc: Array = data.get("encounters", [])
	l.encounters = []
	for enc in raw_enc:
		l.encounters.append({
			"path_id": str(enc.get("path_id", "")),
			"formation_id": str(enc.get("formation_id", "")),
			"ship_id": str(enc.get("ship_id", "enemy_1")),
			"speed": float(enc.get("speed", 200.0)),
			"count": int(enc.get("count", 1)),
			"spacing": float(enc.get("spacing", 200.0)),
			"trigger_y": float(enc.get("trigger_y", 0.0)),
			"x_offset": float(enc.get("x_offset", 0.0)),
			"rotate_with_path": bool(enc.get("rotate_with_path", false)),
			"is_melee": bool(enc.get("is_melee", false)),
			"turn_speed": float(enc.get("turn_speed", 90.0)),
		})
	return l


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"bpm": bpm,
		"scroll_speed": scroll_speed,
		"level_length": level_length,
		"encounters": encounters,
	}


func get_encounter(index: int) -> Dictionary:
	return encounters[index]
