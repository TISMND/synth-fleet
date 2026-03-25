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
	"weapon_slots": 3,
	"core_slots": 1,
	"field_slots": 2,
	"particle_slots": 1,
	"shield_regen": 1.0,
}

# Enemy-specific fields (inert for player ships)
@export var visual_id: String = ""          # Drawing template: "sentinel"
@export var weapon_id: String = ""          # References a WeaponData id (must have is_enemy_weapon=true)
@export var hardpoint_offsets: Array = []   # Array of [x, y] offsets for multi-hardpoint enemies (empty = center)
@export var presence_loop_path: String = "" # Audio loop that plays while this enemy type is on screen
@export var explosion_color: Color = Color(1.0, 0.3, 0.5)  # Explosion VFX color
@export var explosion_size: float = 1.0                      # Explosion size multiplier
@export var enable_screen_shake: bool = false                 # Screen shake on death (bosses)

# Hit effects (shared by player and enemy ships)
@export var shield_style_id: String = ""         # Field style for shield hit visual (e.g. "blue_ripple")
@export var hull_flash_opacity: float = 0.5      # White blink overlay opacity (0.0–1.0)
@export var hull_flash_duration: float = 0.1     # Hull flash duration in seconds
@export var hull_blink_speed: float = 8.0        # Hull flash blink cycles per duration

# Level assignment (enemies/bosses)
@export var level: String = "misc"  # "level_1", "level_2", "misc"

# Collision hitbox (shared by player and enemy ships)
@export var collision_shape: String = "circle"  # "circle", "rectangle", "capsule"
@export var collision_width: float = 30.0       # Width (or diameter for circle)
@export var collision_height: float = 30.0      # Height (ignored for circle)


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
	s.weapon_id = data.get("weapon_id", "")
	s.presence_loop_path = data.get("presence_loop_path", "")
	# Explosion settings
	var exp_color: Array = data.get("explosion_color", [1.0, 0.3, 0.5, 1.0])
	if exp_color.size() >= 3:
		var a: float = float(exp_color[3]) if exp_color.size() >= 4 else 1.0
		s.explosion_color = Color(float(exp_color[0]), float(exp_color[1]), float(exp_color[2]), a)
	s.explosion_size = float(data.get("explosion_size", 1.0))
	s.enable_screen_shake = bool(data.get("enable_screen_shake", false))
	s.hardpoint_offsets = data.get("hardpoint_offsets", [])
	# Hit effects
	s.shield_style_id = str(data.get("shield_style_id", ""))
	s.hull_flash_opacity = float(data.get("hull_flash_opacity", 0.5))
	s.hull_flash_duration = float(data.get("hull_flash_duration", 0.12))
	s.hull_blink_speed = float(data.get("hull_blink_speed", 6.0))
	# Level assignment
	s.level = data.get("level", "misc")
	# Collision hitbox
	s.collision_shape = data.get("collision_shape", "circle")
	s.collision_width = float(data.get("collision_width", 30.0))
	s.collision_height = float(data.get("collision_height", 30.0))
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
		d["weapon_id"] = weapon_id
		d["explosion_color"] = [explosion_color.r, explosion_color.g, explosion_color.b, explosion_color.a]
		d["explosion_size"] = explosion_size
		d["enable_screen_shake"] = enable_screen_shake
		if hardpoint_offsets.size() > 0:
			d["hardpoint_offsets"] = hardpoint_offsets
	# Level assignment (saved for all ship types)
	d["level"] = level
	# Collision hitbox (saved for all ship types)
	d["collision_shape"] = collision_shape
	d["collision_width"] = collision_width
	d["collision_height"] = collision_height
	return d
