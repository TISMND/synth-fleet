extends Node
## Persistent game state — credits, owned items, current ship/slot config.
## Saves to user://save_data.json. References weapons/ships by ID only.

const SAVE_PATH := "user://save_data.json"

var credits: int = 0
var owned_weapon_ids: Array[String] = []
var owned_ship_ids: Array[String] = []
var current_level: int = 0
var stats: Dictionary = {}

# Ship/slot system
var current_ship_index: int = 4  # default Stiletto
var slot_config: Dictionary = {}
# slot_config structure:
# {
#   "ext_0": {"weapon_id": ""},
#   "ext_1": {"weapon_id": ""},
#   "ext_2": {"weapon_id": ""},
#   "int_0": {"device_id": ""},
#   "int_1": {"device_id": ""},
#   "int_2": {"device_id": ""},
# }

# Transient — not saved. Used to pass context between screens.
var _editing_slot_key: String = ""
var _editing_device_slot: int = -1


func _ready() -> void:
	load_game()


func _init_slot_config() -> void:
	slot_config = {
		"ext_0": {"weapon_id": ""},
		"ext_1": {"weapon_id": ""},
		"ext_2": {"weapon_id": ""},
		"int_0": {"device_id": ""},
		"int_1": {"device_id": ""},
		"int_2": {"device_id": ""},
	}


func save_game() -> void:
	var data: Dictionary = {
		"credits": credits,
		"owned_weapon_ids": owned_weapon_ids,
		"owned_ship_ids": owned_ship_ids,
		"current_ship_index": current_ship_index,
		"slot_config": slot_config,
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
	current_level = int(data.get("current_level", 0))
	stats = data.get("stats", {})

	current_ship_index = int(data.get("current_ship_index", 4))
	var saved_slots: Dictionary = data.get("slot_config", {})
	if saved_slots.size() > 0:
		slot_config = saved_slots
	else:
		_init_slot_config()


func _set_defaults() -> void:
	credits = 0
	owned_weapon_ids = []
	owned_ship_ids = []
	current_ship_index = 4
	_init_slot_config()
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


# ── New Ship / Slot helpers (auto-save) ──────────────────────

func set_ship_index(idx: int) -> void:
	current_ship_index = idx
	_init_slot_config()
	save_game()


func set_slot_weapon(slot_key: String, weapon_id: String) -> void:
	if not slot_config.has(slot_key):
		slot_config[slot_key] = {"weapon_id": ""}
	slot_config[slot_key]["weapon_id"] = weapon_id
	save_game()


func set_slot_device(slot_key: String, device_id: String) -> void:
	if not slot_config.has(slot_key):
		slot_config[slot_key] = {"device_id": ""}
	slot_config[slot_key]["device_id"] = device_id
	save_game()


func get_loadout_data() -> LoadoutData:
	## Constructs a LoadoutData from current_ship_index + slot_config
	## Maps ext_0/1/2 → hp_0/1/2 in hardpoint_assignments.
	var l := LoadoutData.new()
	l.id = "live"
	l.ship_id = ShipRegistry.get_ship_name(current_ship_index).to_lower()
	l.hardpoint_assignments = {}
	for i in 3:
		var slot_key: String = "ext_" + str(i)
		var hp_id: String = "hp_" + str(i)
		var slot_data: Dictionary = slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		l.hardpoint_assignments[hp_id] = {"weapon_id": weapon_id}
	return l
