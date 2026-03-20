class_name BeamStyle
extends Resource
## Defines a beam's visual style: fill shader, color, dimensions, appearance mode.
## Separate from WeaponData so beam styles can be reused across weapons.

@export var id: String = ""
@export var display_name: String = ""
@export var fill_shader: String = "beam"  # reuse existing shader set
@export var shader_params: Dictionary = {}
@export var color: Color = Color.CYAN
@export var secondary_color: Color = Color(1.0, 0.3, 0.5, 1.0)
@export var glow_intensity: float = 1.5
@export var max_length: float = 400.0
@export var beam_width: float = 16.0
@export var appearance_mode: String = "flow_in"  # "flow_in" | "expand_out"
@export var flip_shader: bool = false  # flip UV.y to reverse shader scroll direction
@export var full_screen_length: bool = false  # if true, beam extends to screen edge
@export var effect_profile: Dictionary = {}  # v2 format: muzzle + impact effect layers


static func from_dict(data: Dictionary) -> BeamStyle:
	var s := BeamStyle.new()
	s.id = str(data.get("id", ""))
	s.display_name = str(data.get("display_name", ""))
	s.fill_shader = str(data.get("fill_shader", "beam"))
	s.shader_params = data.get("shader_params", {}) as Dictionary
	var color_data: Array = data.get("color", []) as Array
	if color_data.size() >= 4:
		s.color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))
	elif color_data.size() >= 3:
		s.color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), 1.0)
	var sec_data: Array = data.get("secondary_color", []) as Array
	if sec_data.size() >= 4:
		s.secondary_color = Color(float(sec_data[0]), float(sec_data[1]), float(sec_data[2]), float(sec_data[3]))
	elif sec_data.size() >= 3:
		s.secondary_color = Color(float(sec_data[0]), float(sec_data[1]), float(sec_data[2]), 1.0)
	s.glow_intensity = float(data.get("glow_intensity", 1.5))
	s.max_length = float(data.get("max_length", 400.0))
	s.beam_width = float(data.get("beam_width", 16.0))
	s.appearance_mode = str(data.get("appearance_mode", "flow_in"))
	s.flip_shader = bool(data.get("flip_shader", false))
	s.full_screen_length = bool(data.get("full_screen_length", false))
	s.effect_profile = data.get("effect_profile", {}) as Dictionary
	return s


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"fill_shader": fill_shader,
		"shader_params": shader_params,
		"color": [color.r, color.g, color.b, color.a],
		"secondary_color": [secondary_color.r, secondary_color.g, secondary_color.b, secondary_color.a],
		"glow_intensity": glow_intensity,
		"max_length": max_length,
		"beam_width": beam_width,
		"appearance_mode": appearance_mode,
		"flip_shader": flip_shader,
		"full_screen_length": full_screen_length,
		"effect_profile": effect_profile,
	}
