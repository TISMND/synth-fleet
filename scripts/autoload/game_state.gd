extends Node
## Persistent game state — credits, owned items, current loadout.
## Saves to user://save_data.json. References weapons/ships/loadouts by ID only.

const SAVE_PATH := "user://save_data.json"

var credits: int = 0
var owned_weapon_ids: Array[String] = []
var owned_ship_ids: Array[String] = []
var current_loadout_id: String = ""
var current_level: int = 0
var stats: Dictionary = {}


func _ready() -> void:
	load_game()


func save_game() -> void:
	var data: Dictionary = {
		"credits": credits,
		"owned_weapon_ids": owned_weapon_ids,
		"owned_ship_ids": owned_ship_ids,
		"current_loadout_id": current_loadout_id,
		"current_level": current_level,
		"stats": stats,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


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
	credits = int(data.get("credits", 0))
	var wids: Array = data.get("owned_weapon_ids", [])
	owned_weapon_ids.clear()
	for wid in wids:
		owned_weapon_ids.append(str(wid))
	var sids: Array = data.get("owned_ship_ids", [])
	owned_ship_ids.clear()
	for sid in sids:
		owned_ship_ids.append(str(sid))
	current_loadout_id = str(data.get("current_loadout_id", ""))
	current_level = int(data.get("current_level", 0))
	stats = data.get("stats", {})


func _set_defaults() -> void:
	credits = 0
	owned_weapon_ids = []
	owned_ship_ids = []
	current_loadout_id = ""
	current_level = 0
	stats = {}


func reset_campaign() -> void:
	current_level = 0
	save_game()


func add_credits(amount: int) -> void:
	credits += amount
	save_game()


func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	save_game()
	return true
