class_name VfxConfig extends Resource
## Configuration for visual hit effects — Soft Sphere shield + Hard Blink hull flash.
## Player and enemy sections are independent; enemy values are blanket (all enemies share).

# Player Shield (Soft Sphere)
var shield_color_r: float = 0.3
var shield_color_g: float = 0.8
var shield_color_b: float = 1.0
var shield_duration: float = 0.15
var shield_radius_mult: float = 1.0
var shield_intensity: float = 1.0

# Player Hull (Hard Blink)
var hull_peak_r: float = 3.0
var hull_peak_g: float = 3.0
var hull_peak_b: float = 3.0
var hull_duration: float = 0.12
var hull_blink_speed: float = 6.0

# Enemy Shield (Soft Sphere) — blanket for all enemies
var enemy_shield_color_r: float = 1.0
var enemy_shield_color_g: float = 0.3
var enemy_shield_color_b: float = 0.3
var enemy_shield_duration: float = 0.15
var enemy_shield_radius_mult: float = 1.0
var enemy_shield_intensity: float = 1.0

# Enemy Hull (Hard Blink) — blanket for all enemies
var enemy_hull_peak_r: float = 3.0
var enemy_hull_peak_g: float = 3.0
var enemy_hull_peak_b: float = 3.0
var enemy_hull_duration: float = 0.12
var enemy_hull_blink_speed: float = 6.0

# Immune Hit — universal effect when hitting an invulnerable target
var immune_color_r: float = 0.7
var immune_color_g: float = 0.7
var immune_color_b: float = 0.8
var immune_duration: float = 0.1
var immune_radius_mult: float = 0.8
var immune_intensity: float = 0.6


static func from_dict(data: Dictionary) -> VfxConfig:
	var config := VfxConfig.new()
	# Player
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
	# Enemy
	config.enemy_shield_color_r = float(data.get("enemy_shield_color_r", 1.0))
	config.enemy_shield_color_g = float(data.get("enemy_shield_color_g", 0.3))
	config.enemy_shield_color_b = float(data.get("enemy_shield_color_b", 0.3))
	config.enemy_shield_duration = float(data.get("enemy_shield_duration", 0.15))
	config.enemy_shield_radius_mult = float(data.get("enemy_shield_radius_mult", 1.0))
	config.enemy_shield_intensity = float(data.get("enemy_shield_intensity", 1.0))
	config.enemy_hull_peak_r = float(data.get("enemy_hull_peak_r", 3.0))
	config.enemy_hull_peak_g = float(data.get("enemy_hull_peak_g", 3.0))
	config.enemy_hull_peak_b = float(data.get("enemy_hull_peak_b", 3.0))
	config.enemy_hull_duration = float(data.get("enemy_hull_duration", 0.12))
	config.enemy_hull_blink_speed = float(data.get("enemy_hull_blink_speed", 6.0))
	# Immune
	config.immune_color_r = float(data.get("immune_color_r", 0.7))
	config.immune_color_g = float(data.get("immune_color_g", 0.7))
	config.immune_color_b = float(data.get("immune_color_b", 0.8))
	config.immune_duration = float(data.get("immune_duration", 0.1))
	config.immune_radius_mult = float(data.get("immune_radius_mult", 0.8))
	config.immune_intensity = float(data.get("immune_intensity", 0.6))
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
		"enemy_shield_color_r": enemy_shield_color_r,
		"enemy_shield_color_g": enemy_shield_color_g,
		"enemy_shield_color_b": enemy_shield_color_b,
		"enemy_shield_duration": enemy_shield_duration,
		"enemy_shield_radius_mult": enemy_shield_radius_mult,
		"enemy_shield_intensity": enemy_shield_intensity,
		"enemy_hull_peak_r": enemy_hull_peak_r,
		"enemy_hull_peak_g": enemy_hull_peak_g,
		"enemy_hull_peak_b": enemy_hull_peak_b,
		"enemy_hull_duration": enemy_hull_duration,
		"enemy_hull_blink_speed": enemy_hull_blink_speed,
		"immune_color_r": immune_color_r,
		"immune_color_g": immune_color_g,
		"immune_color_b": immune_color_b,
		"immune_duration": immune_duration,
		"immune_radius_mult": immune_radius_mult,
		"immune_intensity": immune_intensity,
	}
