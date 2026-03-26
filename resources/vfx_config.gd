class_name VfxConfig extends Resource
## Configuration for visual hit effects — each hit type uses a FieldStyle + radius.
## Player and enemy sections are independent; enemy values are blanket (all enemies share).

# Player Shield Hit
var player_shield_field_style_id: String = ""
var player_shield_radius: float = 60.0

# Player Hull Hit
var player_hull_field_style_id: String = ""
var player_hull_radius: float = 50.0

# Enemy Shield Hit — blanket for all enemies
var enemy_shield_field_style_id: String = ""
var enemy_shield_radius: float = 50.0

# Enemy Hull Hit — blanket for all enemies
var enemy_hull_field_style_id: String = ""
var enemy_hull_radius: float = 40.0

# Immune Hit — field effect when hitting an invulnerable target (enemy only)
var immune_field_style_id: String = ""
var immune_radius: float = 60.0

# Immune Impact — additional burst at point of contact
var immune_impact_field_style_id: String = ""
var immune_impact_radius: float = 30.0


static func from_dict(data: Dictionary) -> VfxConfig:
	var config := VfxConfig.new()
	# Player
	config.player_shield_field_style_id = str(data.get("player_shield_field_style_id", ""))
	config.player_shield_radius = float(data.get("player_shield_radius", 60.0))
	config.player_hull_field_style_id = str(data.get("player_hull_field_style_id", ""))
	config.player_hull_radius = float(data.get("player_hull_radius", 50.0))
	# Enemy
	config.enemy_shield_field_style_id = str(data.get("enemy_shield_field_style_id", ""))
	config.enemy_shield_radius = float(data.get("enemy_shield_radius", 50.0))
	config.enemy_hull_field_style_id = str(data.get("enemy_hull_field_style_id", ""))
	config.enemy_hull_radius = float(data.get("enemy_hull_radius", 40.0))
	# Immune
	config.immune_field_style_id = str(data.get("immune_field_style_id", ""))
	config.immune_radius = float(data.get("immune_radius", 60.0))
	config.immune_impact_field_style_id = str(data.get("immune_impact_field_style_id", ""))
	config.immune_impact_radius = float(data.get("immune_impact_radius", 30.0))
	return config


func to_dict() -> Dictionary:
	return {
		"player_shield_field_style_id": player_shield_field_style_id,
		"player_shield_radius": player_shield_radius,
		"player_hull_field_style_id": player_hull_field_style_id,
		"player_hull_radius": player_hull_radius,
		"enemy_shield_field_style_id": enemy_shield_field_style_id,
		"enemy_shield_radius": enemy_shield_radius,
		"enemy_hull_field_style_id": enemy_hull_field_style_id,
		"enemy_hull_radius": enemy_hull_radius,
		"immune_field_style_id": immune_field_style_id,
		"immune_radius": immune_radius,
		"immune_impact_field_style_id": immune_impact_field_style_id,
		"immune_impact_radius": immune_impact_radius,
	}
