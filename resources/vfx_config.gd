class_name VfxConfig extends Resource
## Configuration for visual hit effects.
## Shield hits use a FieldStyle + radius (field overlay on ship).
## Hull hits use a brightness/alpha flicker on the existing ship sprite.
## Immune hit uses a FieldStyle + radius; immune impact uses a ProjectileStyle for burst effects.

# Player Shield Hit — field overlay
var player_shield_field_style_id: String = ""
var player_shield_ratio: float = 1.82

# Player Hull Hit — ship flicker
var player_hull_flash_color: Array = [1.0, 1.0, 1.0, 1.0]
var player_hull_flash_intensity: float = 2.0
var player_hull_flash_duration: float = 0.3
var player_hull_flash_count: int = 3

# Enemy Shield Hit — field overlay (blanket for all enemies)
var enemy_shield_field_style_id: String = ""
var enemy_shield_ratio: float = 1.83

# Enemy Hull Hit — ship flicker (blanket for all enemies)
var enemy_hull_flash_color: Array = [1.0, 1.0, 1.0, 1.0]
var enemy_hull_flash_intensity: float = 2.0
var enemy_hull_flash_duration: float = 0.3
var enemy_hull_flash_count: int = 3

# Immune Hit — field effect when hitting an invulnerable target
var immune_field_style_id: String = ""
var immune_ratio: float = 1.35

# Immune Impact — projectile-style burst at point of contact
var immune_impact_projectile_style_id: String = ""
var immune_impact_scale: float = 1.0


static func from_dict(data: Dictionary) -> VfxConfig:
	var config := VfxConfig.new()
	# Player Shield
	config.player_shield_field_style_id = str(data.get("player_shield_field_style_id", ""))
	config.player_shield_ratio = float(data.get("player_shield_ratio", 1.82))
	# Player Hull
	config.player_hull_flash_color = _parse_color_array(data.get("player_hull_flash_color", [1.0, 1.0, 1.0, 1.0]))
	config.player_hull_flash_intensity = float(data.get("player_hull_flash_intensity", 2.0))
	config.player_hull_flash_duration = float(data.get("player_hull_flash_duration", 0.3))
	config.player_hull_flash_count = int(data.get("player_hull_flash_count", 3))
	# Enemy Shield
	config.enemy_shield_field_style_id = str(data.get("enemy_shield_field_style_id", ""))
	config.enemy_shield_ratio = float(data.get("enemy_shield_ratio", 1.83))
	# Enemy Hull
	config.enemy_hull_flash_color = _parse_color_array(data.get("enemy_hull_flash_color", [1.0, 1.0, 1.0, 1.0]))
	config.enemy_hull_flash_intensity = float(data.get("enemy_hull_flash_intensity", 2.0))
	config.enemy_hull_flash_duration = float(data.get("enemy_hull_flash_duration", 0.3))
	config.enemy_hull_flash_count = int(data.get("enemy_hull_flash_count", 3))
	# Immune
	config.immune_field_style_id = str(data.get("immune_field_style_id", ""))
	config.immune_ratio = float(data.get("immune_ratio", 1.35))
	# Immune Impact
	config.immune_impact_projectile_style_id = str(data.get("immune_impact_projectile_style_id", ""))
	config.immune_impact_scale = float(data.get("immune_impact_scale", 1.0))
	return config


func to_dict() -> Dictionary:
	return {
		"player_shield_field_style_id": player_shield_field_style_id,
		"player_shield_ratio": player_shield_ratio,
		"player_hull_flash_color": player_hull_flash_color,
		"player_hull_flash_intensity": player_hull_flash_intensity,
		"player_hull_flash_duration": player_hull_flash_duration,
		"player_hull_flash_count": player_hull_flash_count,
		"enemy_shield_field_style_id": enemy_shield_field_style_id,
		"enemy_shield_ratio": enemy_shield_ratio,
		"enemy_hull_flash_color": enemy_hull_flash_color,
		"enemy_hull_flash_intensity": enemy_hull_flash_intensity,
		"enemy_hull_flash_duration": enemy_hull_flash_duration,
		"enemy_hull_flash_count": enemy_hull_flash_count,
		"immune_field_style_id": immune_field_style_id,
		"immune_ratio": immune_ratio,
		"immune_impact_projectile_style_id": immune_impact_projectile_style_id,
		"immune_impact_scale": immune_impact_scale,
	}


static func _parse_color_array(val: Variant) -> Array:
	if val is Array and val.size() >= 4:
		return [float(val[0]), float(val[1]), float(val[2]), float(val[3])]
	return [1.0, 1.0, 1.0, 1.0]
