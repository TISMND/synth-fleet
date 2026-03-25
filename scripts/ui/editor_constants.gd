class_name EditorConstants
## Shared constants for weapon/power-core/projectile editor tabs.

const SNAP_MODES: Array[Dictionary] = [
	{"label": "Free", "value": 0},
	{"label": "1/4", "value": 4},
	{"label": "1/8", "value": 8},
	{"label": "1/16", "value": 16},
]
const BARS_OPTIONS: Array[Dictionary] = [
	{"label": "Auto", "value": 0},
	{"label": "1", "value": 1},
	{"label": "2", "value": 2},
	{"label": "4", "value": 4},
	{"label": "8", "value": 8},
]

const EFFECT_SLOTS: Array[String] = ["muzzle", "trail", "impact"]
const EFFECT_SLOT_LABELS: Dictionary = {
	"muzzle": "MUZZLE FLASH",
	"trail": "TRAIL",
	"impact": "IMPACT",
}

const EFFECT_TYPES: Dictionary = {
	"muzzle": ["none", "radial_burst", "directional_flash", "ring_pulse", "spiral_burst"],
	"trail": ["none", "particle", "ribbon", "afterimage", "sparkle", "sine_ribbon"],
	"impact": ["none", "burst", "ring_expand", "shatter_lines", "nova_flash", "ripple"],
}

const EFFECT_PARAM_DEFS: Dictionary = {
	"muzzle": {
		"none": {},
		"radial_burst": {"particle_count": [1, 40, 6, 1], "lifetime": [0.05, 2.0, 0.25, 0.05], "spread_angle": [10.0, 360.0, 360.0, 5.0]},
		"directional_flash": {"particle_count": [1, 20, 4, 1], "lifetime": [0.05, 1.0, 0.15, 0.05], "spread_angle": [5.0, 180.0, 30.0, 5.0]},
		"ring_pulse": {"particle_count": [2, 40, 8, 1], "lifetime": [0.05, 1.5, 0.25, 0.05], "spread_angle": [90.0, 360.0, 360.0, 5.0]},
		"spiral_burst": {"particle_count": [2, 32, 8, 1], "lifetime": [0.05, 2.0, 0.3, 0.05], "spread_angle": [90.0, 360.0, 360.0, 5.0]},
	},
	"trail": {
		"none": {},
		"particle": {"amount": [1, 32, 8, 1], "lifetime": [0.02, 1.5, 0.2, 0.02]},
		"ribbon": {"width_start": [0.5, 24.0, 4.0, 0.5], "width_end": [0.0, 12.0, 0.0, 0.5], "length": [2, 60, 20, 1]},
		"afterimage": {"amount": [1, 16, 4, 1], "lifetime": [0.02, 1.0, 0.15, 0.02]},
		"sparkle": {"amount": [1, 24, 6, 1], "lifetime": [0.02, 1.0, 0.25, 0.02]},
		"sine_ribbon": {"width_start": [0.5, 20.0, 3.0, 0.5], "width_end": [0.0, 12.0, 0.0, 0.5], "length": [2, 60, 20, 1], "amplitude": [0.5, 40.0, 5.0, 0.5], "frequency": [0.5, 20.0, 4.0, 0.5], "speed": [0.0, 10.0, 3.0, 0.5]},
	},
	"impact": {
		"none": {},
		"burst": {"particle_count": [1, 40, 8, 1], "lifetime": [0.05, 2.0, 0.3, 0.05], "radius": [2.0, 100.0, 20.0, 1.0], "speed_scale": [0.1, 5.0, 1.0, 0.1]},
		"ring_expand": {"particle_count": [2, 48, 12, 1], "lifetime": [0.05, 1.5, 0.25, 0.05], "radius": [4.0, 100.0, 30.0, 1.0], "speed_scale": [0.1, 5.0, 1.0, 0.1]},
		"shatter_lines": {"particle_count": [1, 24, 6, 1], "lifetime": [0.05, 1.5, 0.25, 0.05], "radius": [2.0, 80.0, 25.0, 1.0], "speed_scale": [0.1, 5.0, 1.0, 0.1]},
		"nova_flash": {"particle_count": [2, 40, 10, 1], "lifetime": [0.1, 2.0, 0.4, 0.05], "radius": [5.0, 120.0, 40.0, 1.0], "speed_scale": [0.1, 5.0, 1.0, 0.1]},
		"ripple": {"particle_count": [1, 32, 8, 1], "lifetime": [0.05, 2.0, 0.3, 0.05], "radius": [4.0, 100.0, 35.0, 1.0], "speed_scale": [0.1, 5.0, 1.0, 0.1]},
	},
}
