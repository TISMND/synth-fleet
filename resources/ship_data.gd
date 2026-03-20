class_name ShipData
extends Resource
## Type-safe container for ship definitions. Populated from JSON at runtime.

const DEFAULT_SEGMENTS: Dictionary = {
	"SHIELD": 10, "HULL": 8, "THERMAL": 6, "ELECTRIC": 8
}
const DEFAULT_HP: Dictionary = {
	"SHIELD": 100, "HULL": 80, "THERMAL": 60, "ELECTRIC": 80
}

@export var id: String = ""
@export var display_name: String = ""
@export var type: String = "player"  # "player" or "enemy"
@export var render_mode: String = "chrome"  # "neon" or "chrome"
@export var grid_size: Vector2i = Vector2i(32, 32)
@export var lines: Array = []  # Array of { from: [x,y], to: [x,y], color: "#hex" }
@export var hardpoints: Array = []  # Array of { id, label, grid_pos: [x,y], direction_deg }
@export var stats: Dictionary = {
	"hull_segments": 8,
	"shield_segments": 10,
	"thermal_segments": 6,
	"electric_segments": 8,
	"speed": 400,
	"acceleration": 1200,
	"device_slots": 2,
	"shield_regen": 1.0,
}

# Enemy-specific fields (inert for player ships)
@export var visual_id: String = ""          # Drawing template: "sentinel"
@export var fire_pattern: String = "straight"  # "straight", "turret", "burst"
@export var burst_directions: int = 4       # Only used when fire_pattern == "burst"
@export var fire_rate: float = 1.5          # Seconds between shots
@export var enemy_damage: int = 10          # Damage per enemy projectile
@export var projectile_speed: float = 300.0
@export var weapon_id: String = ""          # Future: enemy weapon definitions
@export var presence_loop_path: String = "" # Audio loop that plays while this enemy type is on screen
@export var explosion_color: Color = Color(1.0, 0.3, 0.5)  # Explosion VFX color
@export var explosion_size: float = 1.0                      # Explosion size multiplier
@export var enable_screen_shake: bool = false                 # Screen shake on death (bosses)


static func from_dict(data: Dictionary) -> ShipData:
	var s := ShipData.new()
	s.id = data.get("id", "")
	s.display_name = data.get("display_name", "")
	s.type = data.get("type", "player")
	s.render_mode = data.get("render_mode", "chrome")
	var gs: Array = data.get("grid_size", [32, 32])
	s.grid_size = Vector2i(int(gs[0]), int(gs[1]))
	s.lines = data.get("lines", [])
	s.hardpoints = data.get("hardpoints", [])
	var base_stats: Dictionary = ShipData.new().stats
	s.stats = data.get("stats", base_stats)
	# Fill missing keys with defaults
	for k in base_stats:
		if not s.stats.has(k):
			s.stats[k] = base_stats[k]

	# Enemy-specific fields
	s.visual_id = data.get("visual_id", "")
	s.fire_pattern = data.get("fire_pattern", "straight")
	s.burst_directions = int(data.get("burst_directions", 4))
	s.fire_rate = float(data.get("fire_rate", 1.5))
	s.enemy_damage = int(data.get("enemy_damage", 10))
	s.projectile_speed = float(data.get("projectile_speed", 300.0))
	s.weapon_id = data.get("weapon_id", "")
	s.presence_loop_path = data.get("presence_loop_path", "")
	# Explosion settings
	var exp_color: Array = data.get("explosion_color", [1.0, 0.3, 0.5, 1.0])
	if exp_color.size() >= 3:
		var a: float = float(exp_color[3]) if exp_color.size() >= 4 else 1.0
		s.explosion_color = Color(float(exp_color[0]), float(exp_color[1]), float(exp_color[2]), a)
	s.explosion_size = float(data.get("explosion_size", 1.0))
	s.enable_screen_shake = bool(data.get("enable_screen_shake", false))
	return s


func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id": id,
		"display_name": display_name,
		"type": type,
		"render_mode": render_mode,
		"grid_size": [grid_size.x, grid_size.y],
		"lines": lines,
		"hardpoints": hardpoints,
		"stats": stats,
	}
	if type == "enemy":
		d["visual_id"] = visual_id
		d["fire_pattern"] = fire_pattern
		d["burst_directions"] = burst_directions
		d["fire_rate"] = fire_rate
		d["enemy_damage"] = enemy_damage
		d["projectile_speed"] = projectile_speed
		d["weapon_id"] = weapon_id
		if presence_loop_path != "":
			d["presence_loop_path"] = presence_loop_path
		d["explosion_color"] = [explosion_color.r, explosion_color.g, explosion_color.b, explosion_color.a]
		d["explosion_size"] = explosion_size
		d["enable_screen_shake"] = enable_screen_shake
	return d
