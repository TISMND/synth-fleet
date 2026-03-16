extends Node
## Persistent game state — credits, owned items, current ship/hardpoint config.
## Saves to user://save_data.json. References weapons/ships by ID only.

const SAVE_PATH := "user://save_data.json"

var credits: int = 0
var owned_weapon_ids: Array[String] = []
var owned_ship_ids: Array[String] = []
var current_loadout_id: String = ""  # kept for backward compat, unused in main flow
var current_ship_id: String = ""
var hardpoint_config: Dictionary = {}
# hardpoint_config structure:
# {
#   "hp_1": {
#     "weapon_id": "bass_synth_01"
#   }
# }
var device_config: Dictionary = {}
# device_config structure:
# {
#   "slot_0": "generator_mk_i",
#   "slot_1": ""
# }
var current_level: int = 0
var stats: Dictionary = {}

# Transient — not saved. Used to pass context between screens.
var _editing_hp_id: String = ""
var _editing_device_slot: int = -1


func _ready() -> void:
	DeviceDataManager.ensure_starter_devices()
	load_game()


func save_game() -> void:
	var data: Dictionary = {
		"credits": credits,
		"owned_weapon_ids": owned_weapon_ids,
		"owned_ship_ids": owned_ship_ids,
		"current_loadout_id": current_loadout_id,
		"current_ship_id": current_ship_id,
		"hardpoint_config": hardpoint_config,
		"device_config": device_config,
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
	current_ship_id = str(data.get("current_ship_id", ""))
	hardpoint_config = data.get("hardpoint_config", {})
	device_config = data.get("device_config", {})
	current_level = int(data.get("current_level", 0))
	stats = data.get("stats", {})


func _set_defaults() -> void:
	credits = 0
	owned_weapon_ids = []
	owned_ship_ids = []
	current_loadout_id = ""
	current_ship_id = ""
	hardpoint_config = {}
	device_config = {}
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


# ── Ship / Hardpoint helpers (auto-save) ─────────────────────

func set_ship(id: String) -> void:
	current_ship_id = id
	hardpoint_config = {}
	device_config = {}
	save_game()


func set_hardpoint_weapon(hp_id: String, weapon_id: String) -> void:
	if not hardpoint_config.has(hp_id):
		hardpoint_config[hp_id] = {"weapon_id": ""}
	hardpoint_config[hp_id]["weapon_id"] = weapon_id
	save_game()


# ── Device helpers (auto-save) ───────────────────────────────

func set_device(slot: int, device_id: String) -> void:
	device_config["slot_" + str(slot)] = device_id
	save_game()


func get_loadout_data() -> LoadoutData:
	## Constructs a LoadoutData from current_ship_id + hardpoint_config
	## so player_ship.setup() still receives LoadoutData unchanged.
	var l := LoadoutData.new()
	l.id = "live"
	l.ship_id = current_ship_id
	l.hardpoint_assignments = hardpoint_config.duplicate(true)
	return l
