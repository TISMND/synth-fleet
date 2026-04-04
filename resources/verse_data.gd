class_name VerseData
extends Resource
## Defines a verse — a thematic group of levels sharing visual identity.

@export var id: String = ""
@export var display_name: String = ""
@export var background_shader: String = ""  # Path to mid-layer bg shader
@export var deep_background: String = ""  # Path to deep bg image (empty = star field only)


static func from_dict(data: Dictionary) -> VerseData:
	var v := VerseData.new()
	v.id = str(data.get("id", ""))
	v.display_name = str(data.get("display_name", ""))
	v.background_shader = str(data.get("background_shader", ""))
	v.deep_background = str(data.get("deep_background", ""))
	return v


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"background_shader": background_shader,
		"deep_background": deep_background,
	}
