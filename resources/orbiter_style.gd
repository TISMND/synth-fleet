class_name OrbiterStyle
extends Resource
## Defines the visual style and orbit behavior of a single orbiter object.
## Spawned by triggers — each trigger adds one orbiter with this style.

@export var id: String = ""
@export var display_name: String = ""

# Visual
@export var shader: String = "glow"
@export var shader_params: Dictionary = {}
@export var shape: String = "circle"  # circle, diamond, triangle, star, crescent, hexagon
@export var color: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var size: float = 16.0  # pixel radius
@export var glow_intensity: float = 2.0

# Orbit
@export var orbit_speed: float = 1.0  # revolutions per second
@export var orbit_direction: int = 1  # 1 = CCW, -1 = CW

# Object behavior
@export var spin_speed: float = 0.0  # self-rotation radians/sec
@export var wobble_amount: float = 0.0  # radial oscillation amplitude in pixels
@export var wobble_speed: float = 2.0  # oscillation frequency

# Count
@export var orbiter_count: int = 3  # how many objects orbit simultaneously (1–8)

# Trail
@export var trail_length: int = 0  # 0–8 afterimages
@export var trail_fade: float = 0.6  # opacity decay per afterimage


const SHAPE_NAMES: Array[String] = ["circle", "diamond", "triangle", "star", "crescent", "hexagon"]
const SHADER_NAMES: Array[String] = ["glow", "flame", "electric", "crystal", "plasma", "void"]


static func shape_to_index(shape_name: String) -> int:
	var idx: int = SHAPE_NAMES.find(shape_name)
	return idx if idx >= 0 else 0


static func from_dict(data: Dictionary) -> OrbiterStyle:
	var s := OrbiterStyle.new()
	s.id = str(data.get("id", ""))
	s.display_name = str(data.get("display_name", ""))
	s.shader = str(data.get("shader", "glow"))
	s.shader_params = data.get("shader_params", {}) as Dictionary
	s.shape = str(data.get("shape", "circle"))
	s.glow_intensity = float(data.get("glow_intensity", 2.0))
	s.size = float(data.get("size", 16.0))
	s.orbit_speed = float(data.get("orbit_speed", 1.0))
	s.orbit_direction = int(data.get("orbit_direction", 1))
	s.spin_speed = float(data.get("spin_speed", 0.0))
	s.wobble_amount = float(data.get("wobble_amount", 0.0))
	s.wobble_speed = float(data.get("wobble_speed", 2.0))
	s.orbiter_count = int(data.get("orbiter_count", 3))
	s.trail_length = int(data.get("trail_length", 0))
	s.trail_fade = float(data.get("trail_fade", 0.6))
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
		"shader": shader,
		"shader_params": shader_params,
		"shape": shape,
		"color": [color.r, color.g, color.b, color.a],
		"glow_intensity": glow_intensity,
		"size": size,
		"orbit_speed": orbit_speed,
		"orbit_direction": orbit_direction,
		"spin_speed": spin_speed,
		"wobble_amount": wobble_amount,
		"wobble_speed": wobble_speed,
		"orbiter_count": orbiter_count,
		"trail_length": trail_length,
		"trail_fade": trail_fade,
	}
