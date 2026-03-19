class_name VfxConfig extends Resource
## Configuration for visual hit effects — Soft Sphere shield + Hard Blink hull flash.

# Shield (Soft Sphere)
var shield_color_r: float = 0.3
var shield_color_g: float = 0.8
var shield_color_b: float = 1.0
var shield_duration: float = 0.15
var shield_radius_mult: float = 1.0
var shield_intensity: float = 1.0

# Hull (Hard Blink)
var hull_peak_r: float = 3.0
var hull_peak_g: float = 3.0
var hull_peak_b: float = 3.0
var hull_duration: float = 0.12
var hull_blink_speed: float = 6.0


static func from_dict(data: Dictionary) -> VfxConfig:
	var config := VfxConfig.new()
	config.shield_color_r = float(data.get("shield_color_r", 0.3))
	config.shield_color_g = float(data.get("shield_color_g", 0.8))
	config.shield_color_b = float(data.get("shield_color_b", 1.0))
	config.shield_duration = float(data.get("shield_duration", 0.15))
	config.shield_radius_mult = float(data.get("shield_radius_mult", 1.0))
	config.shield_intensity = float(data.get("shield_intensity", 1.0))
	config.hull_peak_r = float(data.get("hull_peak_r", 3.0))
	config.hull_peak_g = float(data.get("hull_peak_g", 3.0))
	config.hull_peak_b = float(data.get("hull_peak_b", 3.0))
	config.hull_duration = float(data.get("hull_duration", 0.12))
	config.hull_blink_speed = float(data.get("hull_blink_speed", 6.0))
	return config


func to_dict() -> Dictionary:
	return {
		"shield_color_r": shield_color_r,
		"shield_color_g": shield_color_g,
		"shield_color_b": shield_color_b,
		"shield_duration": shield_duration,
		"shield_radius_mult": shield_radius_mult,
		"shield_intensity": shield_intensity,
		"hull_peak_r": hull_peak_r,
		"hull_peak_g": hull_peak_g,
		"hull_peak_b": hull_peak_b,
		"hull_duration": hull_duration,
		"hull_blink_speed": hull_blink_speed,
	}
