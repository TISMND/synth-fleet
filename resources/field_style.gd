class_name FieldStyle
extends Resource
## Defines a field's visual style: shader type + params + color + pulse settings.
## Separate from DeviceData so styles can be reused across devices.

@export var id: String = ""
@export var display_name: String = ""
@export var field_shader: String = "force_bubble"
@export var shader_params: Dictionary = {}
@export var color: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var glow_intensity: float = 1.5
@export var radius_ratio: float = 0.8
@export var pulse_brightness: float = 2.0
@export var pulse_tint: float = 0.0
@export var pulse_total_duration: float = 0.5
@export var pulse_fade_up: float = 0.05
@export var pulse_fade_out: float = 0.4
@export var ship_tint_strength: float = 0.15
@export var ship_active_hdr: float = 0.2
@export var ship_pulse_hdr: float = 0.5


static func from_dict(data: Dictionary) -> FieldStyle:
	var s := FieldStyle.new()
	s.id = str(data.get("id", ""))
	s.display_name = str(data.get("display_name", ""))
	s.field_shader = str(data.get("field_shader", "force_bubble"))
	s.shader_params = data.get("shader_params", {}) as Dictionary
	s.glow_intensity = float(data.get("glow_intensity", 1.5))
	s.radius_ratio = float(data.get("radius_ratio", 0.8))
	s.pulse_brightness = float(data.get("pulse_brightness", 2.0))
	s.pulse_tint = float(data.get("pulse_tint", 0.0))
	s.pulse_total_duration = float(data.get("pulse_total_duration", data.get("pulse_duration", 0.5)))
	s.pulse_fade_up = float(data.get("pulse_fade_up", 0.05))
	s.pulse_fade_out = float(data.get("pulse_fade_out", data.get("pulse_duration", 0.4)))
	s.ship_tint_strength = float(data.get("ship_tint_strength", 0.15))
	s.ship_active_hdr = float(data.get("ship_active_hdr", data.get("ship_hdr_boost", 0.2)))
	s.ship_pulse_hdr = float(data.get("ship_pulse_hdr", 0.5))
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
		"field_shader": field_shader,
		"shader_params": shader_params,
		"color": [color.r, color.g, color.b, color.a],
		"glow_intensity": glow_intensity,
		"radius_ratio": radius_ratio,
		"pulse_brightness": pulse_brightness,
		"pulse_tint": pulse_tint,
		"pulse_total_duration": pulse_total_duration,
		"pulse_fade_up": pulse_fade_up,
		"pulse_fade_out": pulse_fade_out,
		"ship_tint_strength": ship_tint_strength,
		"ship_active_hdr": ship_active_hdr,
		"ship_pulse_hdr": ship_pulse_hdr,
	}
