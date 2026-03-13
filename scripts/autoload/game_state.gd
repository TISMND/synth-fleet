extends Node
## Persistent game state — credits, owned weapons/ships, current loadout.
## Lives across scene changes. Saves to user:// for session persistence.

const SAVE_PATH := "user://save_data.json"

var credits: int = 0
var owned_weapons: Array[String] = []
var owned_ships: Array[String] = []
var current_ship: String = "default"
var current_loadout: Dictionary = {
	"forward": "",
	"back": "",
	"left": "",
	"right": "",
	"special": "",
}

# Player stats
var hull_max: int = 100
var shield_max: int = 50
var generator_power: int = 10

# mount_name -> Array of slot dicts (serialized WeaponPattern)
var weapon_patterns: Dictionary = {}


func _ready() -> void:
	load_game()


func save_game() -> void:
	var data := {
		"credits": credits,
		"owned_weapons": owned_weapons,
		"owned_ships": owned_ships,
		"current_ship": current_ship,
		"current_loadout": current_loadout,
		"weapon_patterns": weapon_patterns,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_set_defaults()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_set_defaults()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_set_defaults()
		return
	var data: Dictionary = json.data
	credits = data.get("credits", 0)
	owned_weapons.assign(data.get("owned_weapons", []))
	owned_ships.assign(data.get("owned_ships", []))
	current_ship = data.get("current_ship", "default")
	current_loadout = data.get("current_loadout", current_loadout)
	weapon_patterns = data.get("weapon_patterns", {})
	if weapon_patterns.is_empty():
		_set_default_patterns()


func _set_defaults() -> void:
	credits = 0
	owned_weapons = ["basic_pulse"]
	owned_ships = ["default"]
	current_ship = "default"
	current_loadout = {
		"forward": "basic_pulse",
		"back": "",
		"left": "",
		"right": "",
		"special": "",
	}
	# Default pattern: notes on beats 1 and 3 (slots 0 and 4)
	var default_slots: Array = []
	for i in 8:
		default_slots.append({})
	default_slots[0] = { "color": "cyan", "pitch": 1.0, "direction_deg": 0.0 }
	default_slots[4] = { "color": "cyan", "pitch": 1.0, "direction_deg": 0.0 }
	weapon_patterns = { "forward": default_slots }


func _set_default_patterns() -> void:
	var default_slots: Array = []
	for i in 8:
		default_slots.append({})
	default_slots[0] = { "color": "cyan", "pitch": 1.0, "direction_deg": 0.0 }
	default_slots[4] = { "color": "cyan", "pitch": 1.0, "direction_deg": 0.0 }
	weapon_patterns = { "forward": default_slots }
