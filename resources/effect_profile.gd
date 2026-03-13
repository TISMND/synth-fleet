class_name EffectProfile
extends Resource
## Composable visual effect profile for weapons.
## Each layer (muzzle, shape, trail, impact) has a type and parameter dictionary.

@export var id: String = ""
@export var display_name: String = ""

# Motion: "none", "sine_wave", "corkscrew", "wobble"
@export var motion_type: String = "none"
@export var motion_params: Dictionary = {}

# Muzzle: "none", "radial_burst", "directional_flash", "ring_pulse", "spiral_burst"
@export var muzzle_type: String = "radial_burst"
@export var muzzle_params: Dictionary = {}

# Shape: "rect", "streak", "orb", "diamond", "arrow", "pulse_orb"
@export var shape_type: String = "rect"
@export var shape_params: Dictionary = {}

# Trail: "none", "particle", "ribbon", "afterimage", "sparkle", "sine_ribbon"
@export var trail_type: String = "particle"
@export var trail_params: Dictionary = {}

# Impact: "none", "burst", "ring_expand", "shatter_lines", "nova_flash", "ripple"
@export var impact_type: String = "burst"
@export var impact_params: Dictionary = {}


## Generate projectile shape points from shape_type and shape_params.
func get_shape_points() -> PackedVector2Array:
	var p := shape_params
	match shape_type:
		"rect":
			var w: float = p.get("width", 4.0)
			var h: float = p.get("height", 12.0)
			return PackedVector2Array([
				Vector2(-w / 2.0, -h / 2.0),
				Vector2(w / 2.0, -h / 2.0),
				Vector2(w / 2.0, h / 2.0),
				Vector2(-w / 2.0, h / 2.0),
			])
		"streak":
			var w: float = p.get("width", 1.5)
			var l: float = p.get("length", 24.0)
			return PackedVector2Array([
				Vector2(-w / 2.0, -l / 2.0),
				Vector2(w / 2.0, -l / 2.0),
				Vector2(w / 2.0, l / 2.0),
				Vector2(-w / 2.0, l / 2.0),
			])
		"orb":
			var radius: float = p.get("radius", 5.0)
			var segments: int = int(p.get("segments", 8))
			var pts := PackedVector2Array()
			for i in segments:
				var angle := TAU * float(i) / float(segments)
				pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
			return pts
		"diamond":
			var w: float = p.get("width", 6.0)
			var h: float = p.get("height", 14.0)
			return PackedVector2Array([
				Vector2(0, -h / 2.0),
				Vector2(w / 2.0, 0),
				Vector2(0, h / 2.0),
				Vector2(-w / 2.0, 0),
			])
		"arrow":
			var w: float = p.get("width", 8.0)
			var h: float = p.get("height", 14.0)
			var notch: float = p.get("notch", 4.0)
			return PackedVector2Array([
				Vector2(0, -h / 2.0),
				Vector2(w / 2.0, h / 2.0),
				Vector2(0, h / 2.0 - notch),
				Vector2(-w / 2.0, h / 2.0),
			])
		"pulse_orb":
			var radius: float = p.get("radius", 6.0)
			var segments: int = int(p.get("segments", 12))
			var pts := PackedVector2Array()
			for i in segments:
				var angle := TAU * float(i) / float(segments)
				pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
			return pts
	# Fallback: default rect
	return PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(2, 6), Vector2(-2, 6)])


## Get muzzle parameter defaults for a given type.
static func get_muzzle_defaults(type: String) -> Dictionary:
	match type:
		"radial_burst":
			return {"particle_count": 16, "lifetime": 0.15, "spread_angle": 180.0, "velocity_max": 80.0}
		"directional_flash":
			return {"particle_count": 12, "lifetime": 0.12, "spread_angle": 30.0, "velocity_max": 120.0}
		"ring_pulse":
			return {"radius_end": 30.0, "lifetime": 0.2, "segments": 16, "line_width": 4.0}
		"spiral_burst":
			return {"particle_count": 16, "lifetime": 0.2, "spiral_speed": 8.0, "velocity_max": 80.0}
	return {}


static func get_motion_defaults(type: String) -> Dictionary:
	match type:
		"sine_wave":
			return {"amplitude": 8.0, "frequency": 3.0, "phase_offset": 0.0}
		"corkscrew":
			return {"amplitude": 6.0, "frequency": 4.0, "phase_offset": 0.0}
		"wobble":
			return {"amplitude": 3.0, "frequency": 6.0, "phase_offset": 0.0}
	return {}


## Get trail parameter defaults for a given type.
static func get_trail_defaults(type: String) -> Dictionary:
	match type:
		"particle":
			return {"amount": 10, "lifetime": 0.3, "spread": 15.0, "velocity_max": 40.0}
		"ribbon":
			return {"length": 10, "width_start": 3.0, "width_end": 0.0}
		"afterimage":
			return {"count": 5, "spacing_frames": 2, "fade_speed": 3.0}
		"sparkle":
			return {"amount": 12, "lifetime": 0.25, "velocity_max": 30.0}
		"sine_ribbon":
			return {"length": 12, "width_start": 3.0, "width_end": 0.5, "wave_amplitude": 4.0, "wave_frequency": 5.0}
	return {}


## Get impact parameter defaults for a given type.
static func get_impact_defaults(type: String) -> Dictionary:
	match type:
		"burst":
			return {"particle_count": 24, "lifetime": 0.3, "velocity_max": 120.0}
		"ring_expand":
			return {"radius_end": 40.0, "lifetime": 0.25, "segments": 16}
		"shatter_lines":
			return {"line_count": 6, "line_length": 20.0, "lifetime": 0.3, "velocity": 150.0}
		"nova_flash":
			return {"radius": 50.0, "lifetime": 0.12, "intensity": 1.0}
		"ripple":
			return {"ring_count": 3, "radius_end": 35.0, "lifetime": 0.4, "segments": 16, "stagger": 0.08}
	return {}


## Get shape parameter defaults for a given type.
static func get_shape_defaults(type: String) -> Dictionary:
	match type:
		"rect":
			return {"width": 4.0, "height": 12.0}
		"streak":
			return {"width": 1.5, "length": 24.0}
		"orb":
			return {"radius": 5.0, "segments": 8}
		"diamond":
			return {"width": 6.0, "height": 14.0}
		"arrow":
			return {"width": 8.0, "height": 14.0, "notch": 4.0}
		"pulse_orb":
			return {"radius": 6.0, "segments": 12, "pulse_speed": 4.0, "pulse_amount": 1.5}
	return {}


## Get shared shape glow defaults.
static func get_shape_glow_defaults() -> Dictionary:
	return {"glow_width": 6.0, "glow_intensity": 1.0, "core_brightness": 0.7, "pass_count": 3}
