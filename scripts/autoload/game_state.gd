extends Node
## Persistent game state — credits, owned items, current ship/slot config.
## Saves to user://save_data.json. References weapons/ships by ID only.

const SAVE_PATH := "user://save_data.json"

var credits: int = 0
var owned_weapon_ids: Array[String] = []
var owned_ship_ids: Array[String] = []
var owned_device_ids: Array[String] = []
var current_level: int = 0
var stats: Dictionary = {}

# Ship/slot system
var current_ship_index: int = 4  # default Stiletto
var slot_config: Dictionary = {}
# slot_config structure (2-category: external + internal):
# {
#   "ext_0": {"weapon_id": "", "device_id": "", "component_type": ""},
#   "ext_1": {"weapon_id": "", "device_id": "", "component_type": ""},
#   "ext_2": {"weapon_id": "", "device_id": "", "component_type": ""},
#   "int_0": {"device_id": "", "component_type": ""},
#   "int_1": {"device_id": "", "component_type": ""},
#   "int_2": {"device_id": "", "component_type": ""},
# }
# component_type: "weapon", "power_core", "device", or "" (empty)

# Transient — not saved. Used to pass context between screens.
var _editing_slot_key: String = ""
var _editing_device_slot: int = -1
var current_level_id: String = ""
var return_scene: String = ""


func _ready() -> void:
	load_game()


func _init_slot_config() -> void:
	slot_config = {}
	var ext_count: int = get_external_slot_count()
	var int_count: int = get_internal_slot_count()
	for i in ext_count:
		slot_config["ext_" + str(i)] = {"weapon_id": "", "device_id": "", "component_type": ""}
	for i in int_count:
		slot_config["int_" + str(i)] = {"device_id": "", "component_type": ""}


func get_external_slot_count() -> int:
	var ship_stats: Dictionary = _get_current_ship_stats()
	return int(ship_stats.get("external_slots", 3))


func get_internal_slot_count() -> int:
	var ship_stats: Dictionary = _get_current_ship_stats()
	return int(ship_stats.get("internal_slots", 3))


func _get_current_ship_stats() -> Dictionary:
	var ship_id: String = ShipRegistry.get_ship_name(current_ship_index).to_lower()
	var override: ShipData = ShipDataManager.load_by_id(ship_id)
	if override:
		return override.stats
	if current_ship_index < ShipRegistry.SHIP_STATS.size():
		return ShipRegistry.SHIP_STATS[current_ship_index]
	return ShipData.new().stats


func save_game() -> void:
	var data: Dictionary = {
		"credits": credits,
		"owned_weapon_ids": owned_weapon_ids,
		"owned_ship_ids": owned_ship_ids,
		"owned_device_ids": owned_device_ids,
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
	var dids: Array = data.get("owned_device_ids", [])
	owned_device_ids.clear()
	for did in dids:
		owned_device_ids.append(str(did))
	current_level = int(data.get("current_level", 0))
	stats = data.get("stats", {})

	current_ship_index = int(data.get("current_ship_index", 4))
	var saved_slots: Dictionary = data.get("slot_config", {})
	if saved_slots.size() > 0:
		slot_config = saved_slots
		_migrate_slot_config()
	else:
		_init_slot_config()


func _set_defaults() -> void:
	credits = 0
	owned_weapon_ids = []
	owned_ship_ids = []
	owned_device_ids = []
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
		slot_config[slot_key] = {"weapon_id": "", "device_id": "", "component_type": ""}
	slot_config[slot_key]["weapon_id"] = weapon_id
	slot_config[slot_key]["device_id"] = ""
	slot_config[slot_key]["component_type"] = "weapon" if weapon_id != "" else ""
	save_game()


func set_slot_device(slot_key: String, device_id: String, component_type: String = "device") -> void:
	if not slot_config.has(slot_key):
		if slot_key.begins_with("ext_"):
			slot_config[slot_key] = {"weapon_id": "", "device_id": "", "component_type": ""}
		else:
			slot_config[slot_key] = {"device_id": "", "component_type": ""}
	slot_config[slot_key]["device_id"] = device_id
	if slot_key.begins_with("ext_"):
		slot_config[slot_key]["weapon_id"] = ""
	slot_config[slot_key]["component_type"] = component_type if device_id != "" else ""
	save_game()


func _migrate_slot_config() -> void:
	## Migrate old 3-category slot_config (ext/int/dev) to 2-category (ext/int).
	## Moves dev_N items into first available int_N slots, then removes dev_N keys.
	var dev_items: Array[String] = []
	var dev_keys_to_remove: Array[String] = []
	for key in slot_config:
		if str(key).begins_with("dev_"):
			var device_id: String = str(slot_config[key].get("device_id", ""))
			if device_id != "":
				dev_items.append(device_id)
			dev_keys_to_remove.append(str(key))

	if dev_keys_to_remove.is_empty():
		return  # No migration needed

	# Place dev items into available int slots
	var int_count: int = get_internal_slot_count()
	for device_id in dev_items:
		for i in int_count:
			var int_key: String = "int_" + str(i)
			if not slot_config.has(int_key):
				slot_config[int_key] = {"device_id": "", "component_type": ""}
			var existing_id: String = str(slot_config[int_key].get("device_id", ""))
			if existing_id == "":
				slot_config[int_key]["device_id"] = device_id
				slot_config[int_key]["component_type"] = "device"
				break

	# Remove old dev keys
	for key in dev_keys_to_remove:
		slot_config.erase(key)

	# Ensure ext slots have the full schema
	var ext_count: int = get_external_slot_count()
	for i in ext_count:
		var ext_key: String = "ext_" + str(i)
		if slot_config.has(ext_key):
			var sd: Dictionary = slot_config[ext_key]
			if not sd.has("device_id"):
				sd["device_id"] = ""
			if not sd.has("component_type"):
				var wid: String = str(sd.get("weapon_id", ""))
				sd["component_type"] = "weapon" if wid != "" else ""

	# Ensure int slots have component_type
	for i in int_count:
		var int_key: String = "int_" + str(i)
		if slot_config.has(int_key):
			var sd: Dictionary = slot_config[int_key]
			if not sd.has("component_type"):
				var did: String = str(sd.get("device_id", ""))
				sd["component_type"] = "power_core" if did != "" else ""

	save_game()


func get_loadout_data() -> LoadoutData:
	## Constructs a LoadoutData from current_ship_index + slot_config
	## Maps ext slots with weapon component_type → hp_N in hardpoint_assignments.
	var l := LoadoutData.new()
	l.id = "live"
	l.ship_id = ShipRegistry.get_ship_name(current_ship_index).to_lower()
	l.hardpoint_assignments = {}
	var hp_index: int = 0
	for i in get_external_slot_count():
		var slot_key: String = "ext_" + str(i)
		var hp_id: String = "hp_" + str(hp_index)
		var slot_data: Dictionary = slot_config.get(slot_key, {})
		var comp_type: String = str(slot_data.get("component_type", ""))
		var weapon_id: String = ""
		if comp_type == "weapon":
			weapon_id = str(slot_data.get("weapon_id", ""))
		l.hardpoint_assignments[hp_id] = {"weapon_id": weapon_id}
		hp_index += 1
	return l
