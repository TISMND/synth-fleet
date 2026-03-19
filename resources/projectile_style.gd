class_name ProjectileStyle
extends Resource
## Defines a projectile's visual style: shape mask + fill shader + archetype.
## Separate from WeaponData so styles can be reused across weapons.

@export var id: String = ""
@export var display_name: String = ""
@export var archetype: String = "bullet"  # "bullet" | "beam" | "pulse_wave"
@export var mask_path: String = ""  # path to PNG in res://data/projectile_masks/
@export var fill_shader: String = "energy"  # "energy" | "plasma" | "beam" | "fire" | "electric" | "void"
@export var shader_params: Dictionary = {}
@export var glow_intensity: float = 1.5
@export var base_scale: Vector2 = Vector2(24, 32)
@export var archetype_params: Dictionary = {}
@export var color: Color = Color.CYAN


static func from_dict(data: Dictionary) -> ProjectileStyle:
	var s := ProjectileStyle.new()
	s.id = str(data.get("id", ""))
	s.display_name = str(data.get("display_name", ""))
	s.archetype = str(data.get("archetype", "bullet"))
	s.mask_path = str(data.get("mask_path", ""))
	s.fill_shader = str(data.get("fill_shader", "energy"))
	s.shader_params = data.get("shader_params", {}) as Dictionary
	s.glow_intensity = float(data.get("glow_intensity", 1.5))
	var scale_data: Array = data.get("base_scale", [24, 32]) as Array
	if scale_data.size() >= 2:
		s.base_scale = Vector2(float(scale_data[0]), float(scale_data[1]))
	s.archetype_params = data.get("archetype_params", {}) as Dictionary
	var color_data: Array = data.get("color", []) as Array
	if color_data.size() >= 4:
		s.color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))
	elif color_data.size() >= 3:
		s.color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), 1.0)
	return s


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"archetype": archetype,
		"mask_path": mask_path,
		"fill_shader": fill_shader,
		"shader_params": shader_params,
		"glow_intensity": glow_intensity,
		"base_scale": [base_scale.x, base_scale.y],
		"archetype_params": archetype_params,
		"color": [color.r, color.g, color.b, color.a],
	}
