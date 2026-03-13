class_name DeviceData
extends Resource
## Type-safe container for device definitions (generators, shields). Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var type: String = "generator"  # "generator" or "shield"
@export var stats_modifiers: Dictionary = {}


static func from_dict(data: Dictionary) -> DeviceData:
	var d := DeviceData.new()
	d.id = data.get("id", "")
	d.display_name = data.get("display_name", "")
	d.description = data.get("description", "")
	d.type = data.get("type", "generator")
	d.stats_modifiers = data.get("stats_modifiers", {})
	return d


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"type": type,
		"stats_modifiers": stats_modifiers,
	}
