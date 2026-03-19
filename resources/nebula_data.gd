class_name NebulaData
extends Resource
## Type-safe container for nebula definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var style_id: String = "classic_fbm"
@export var shader_params: Dictionary = {}


static func default_params() -> Dictionary:
	return {
		"nebula_color": [0.3, 0.4, 0.9, 1.0],
		"secondary_color": [1.0, 0.5, 0.2, 1.0],
		"brightness": 1.5,
		"animation_speed": 0.5,
		"density": 1.5,
		"seed_offset": 0.0,
		"radial_spread": 0.2,
		"bottom_opacity": 1.0,
		"top_opacity": 0.1,
	}


static func from_dict(data: Dictionary) -> NebulaData:
	var n := NebulaData.new()
	n.id = data.get("id", "")
	n.display_name = data.get("display_name", "")
	n.style_id = data.get("style_id", "classic_fbm")
	var params: Dictionary = data.get("shader_params", {})
	var defaults: Dictionary = default_params()
	for key in defaults:
		if not params.has(key):
			params[key] = defaults[key]
	n.shader_params = params
	return n


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"style_id": style_id,
		"shader_params": shader_params,
	}
