extends Node
## Static registry of all 9 ships with metadata. No JSON, no user:// — pure code.

const SHIP_COUNT := 9

const SHIP_NAMES: Array[String] = [
	"Switchblade", "Phantom", "Mantis", "Corsair", "Stiletto",
	"Trident", "Orrery", "Dreadnought", "Bastion",
]

# Per-ship stats for gameplay variety
const SHIP_STATS: Array[Dictionary] = [
	# 0 Switchblade — fast, fragile interceptor
	{"hull_max": 80, "shield_max": 40, "speed": 520, "generator_power": 12, "shield_regen": 6.0},
	# 1 Phantom — stealth, balanced
	{"hull_max": 90, "shield_max": 60, "speed": 460, "generator_power": 14, "shield_regen": 7.0},
	# 2 Mantis — wide wings, good shields
	{"hull_max": 100, "shield_max": 70, "speed": 400, "generator_power": 16, "shield_regen": 5.0},
	# 3 Corsair — asymmetric, high power
	{"hull_max": 110, "shield_max": 50, "speed": 440, "generator_power": 18, "shield_regen": 4.0},
	# 4 Stiletto — default all-rounder
	{"hull_max": 100, "shield_max": 50, "speed": 400, "generator_power": 15, "shield_regen": 5.0},
	# 5 Trident — 3-prong, good hardpoints
	{"hull_max": 120, "shield_max": 55, "speed": 380, "generator_power": 20, "shield_regen": 4.5},
	# 6 Orrery — exotic, high shields
	{"hull_max": 85, "shield_max": 90, "speed": 360, "generator_power": 22, "shield_regen": 8.0},
	# 7 Dreadnought — heavy capital, slow
	{"hull_max": 200, "shield_max": 80, "speed": 280, "generator_power": 25, "shield_regen": 3.0},
	# 8 Bastion — fortress, max hull
	{"hull_max": 250, "shield_max": 60, "speed": 240, "generator_power": 22, "shield_regen": 2.5},
]

const SHIP_SCALES: Array[float] = [
	1.2, 1.4, 1.4, 1.4, 1.4, 1.4, 1.7, 1.9, 1.8,
]

# Generic hardpoint positions per ship (center-front, left-wing, right-wing)
# in grid coordinates relative to a 32x32 grid
const SHIP_HARDPOINTS: Array[Array] = [
	# 0 Switchblade
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 8], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 14], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 14], "direction_deg": 0.0}],
	# 1 Phantom
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 6], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [10, 14], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [22, 14], "direction_deg": 0.0}],
	# 2 Mantis
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 8], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [6, 14], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [26, 14], "direction_deg": 0.0}],
	# 3 Corsair
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 6], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 14], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 14], "direction_deg": 0.0}],
	# 4 Stiletto
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 10], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 16], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 16], "direction_deg": 0.0}],
	# 5 Trident
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 6], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 16], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 16], "direction_deg": 0.0}],
	# 6 Orrery
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 10], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 16], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 16], "direction_deg": 0.0}],
	# 7 Dreadnought
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 6], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 12], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 12], "direction_deg": 0.0}],
	# 8 Bastion
	[{"id": "hp_0", "label": "CENTER", "grid_pos": [16, 6], "direction_deg": 0.0},
	 {"id": "hp_1", "label": "LEFT", "grid_pos": [8, 14], "direction_deg": 0.0},
	 {"id": "hp_2", "label": "RIGHT", "grid_pos": [24, 14], "direction_deg": 0.0}],
]


func get_ship(index: int) -> Dictionary:
	if index < 0 or index >= SHIP_COUNT:
		index = 4
	return {
		"name": SHIP_NAMES[index],
		"stats": SHIP_STATS[index],
		"scale": SHIP_SCALES[index],
		"hardpoints": SHIP_HARDPOINTS[index],
	}


func get_count() -> int:
	return SHIP_COUNT


func get_ship_name(index: int) -> String:
	if index < 0 or index >= SHIP_COUNT:
		return "Unknown"
	return SHIP_NAMES[index]


func build_ship_data(index: int) -> ShipData:
	if index < 0 or index >= SHIP_COUNT:
		index = 4
	var ship := ShipData.new()
	ship.id = SHIP_NAMES[index].to_lower()
	ship.display_name = SHIP_NAMES[index]
	ship.grid_size = Vector2i(32, 32)
	ship.lines = []
	ship.hardpoints = []
	for hp in SHIP_HARDPOINTS[index]:
		ship.hardpoints.append(hp.duplicate(true))
	ship.stats = SHIP_STATS[index].duplicate()
	return ship
