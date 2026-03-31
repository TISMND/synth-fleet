class_name ItemData
extends Resource
## Type-safe container for item definitions. Populated from JSON at runtime.

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "powerup"  # "powerup" or "money"
@export var value: float = 100.0  # Money amount or powerup strength
@export var duration: float = 0.0  # Powerup duration in seconds (0 = instant)
@export var effect_type: String = ""  # e.g. "shield_restore", "speed_boost", "damage_boost"

# Visual properties
@export var visual_shape: String = "coin"  # coin, diamond, gem_round, gem_oval, crystal, bar, chip, star, circle
@export var primary_color: String = "#FFD700"  # Main fill color (hex)
@export var secondary_color: String = "#DAA520"  # Accent/highlight color (hex)
@export var glow_color: String = "#FFEC80"  # Glow/shimmer color (hex)
@export var icon: String = ""  # Powerup icon: shield, cross, arrow_up, sword, snowflake, bolt, star, magnet
@export var animation_style: String = "shimmer"  # spin, pulse, shimmer, bob, static
@export var size_class: String = "medium"  # "small", "medium", "large"


static func from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = data.get("id", "")
	item.display_name = data.get("display_name", "")
	item.category = str(data.get("category", "powerup"))
	item.value = float(data.get("value", 100.0))
	item.duration = float(data.get("duration", 0.0))
	item.effect_type = str(data.get("effect_type", ""))
	item.visual_shape = str(data.get("visual_shape", "coin"))
	item.primary_color = str(data.get("primary_color", "#FFD700"))
	item.secondary_color = str(data.get("secondary_color", "#DAA520"))
	item.glow_color = str(data.get("glow_color", "#FFEC80"))
	item.icon = str(data.get("icon", ""))
	item.animation_style = str(data.get("animation_style", "shimmer"))
	item.size_class = str(data.get("size_class", "medium"))
	return item


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"value": value,
		"duration": duration,
		"effect_type": effect_type,
		"visual_shape": visual_shape,
		"primary_color": primary_color,
		"secondary_color": secondary_color,
		"glow_color": glow_color,
		"icon": icon,
		"animation_style": animation_style,
		"size_class": size_class,
	}
