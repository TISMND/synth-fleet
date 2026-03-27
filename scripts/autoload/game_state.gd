extends Node
## Persistent game state — credits, owned items, current ship/slot config.
## Saves to user://save_data.json. References weapons/ships by ID only.

const SAVE_PATH := "user://save_data.json"

var credits: int = 0
var owned_weapon_ids: Array[String] = []
var owned_ship_ids: Array[String] = []
var owned_device_ids: Array[String] = []
var current_level: int = 0
var completed_levels: Dictionary = {}  # {"level_1": "A", "level_2": "B"} — level_id → letter grade
var stats: Dictionary = {}

# Ship/slot system
var current_ship_index: int = 4  # default Stiletto
var slot_config: Dictionary = {}
# slot_config structure (typed categories):
# {
#   "weapon_0": {"weapon_id": ""},
#   "weapon_1": {"weapon_id": ""},
#   "core_0":   {"device_id": ""},
#   "field_0":  {"device_id": ""},
#   "field_1":  {"device_id": ""},
#   "particle_0": {"device_id": ""},
# }

# Transient — not saved. Used to pass context between screens.
var current_level_id: String = ""
var return_scene: String = ""
var editing_level_id: String = ""  # Remembers which level was open in the editor
var show_mouse_nav_indicator: bool = true  # Gameplay setting — show diamond at mouse position
var mouse_sensitivity: float = 1.0  # Controls setting — 0.25 to 2.0


func _ready() -> void:
	load_game()
	_load_gameplay_settings()


func _load_gameplay_settings() -> void:
	var path: String = "user://settings/gameplay.json"
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	show_mouse_nav_indicator = bool(data.get("show_mouse_nav_indicator", true))
	mouse_sensitivity = clampf(float(data.get("mouse_sensitivity", 1.0)), 0.25, 2.0)


func _init_slot_config() -> void:
	slot_config = {}
	for i in get_weapon_slot_count():
		slot_config["weapon_" + str(i)] = {"weapon_id": ""}
	for i in get_core_slot_count():
		slot_config["core_" + str(i)] = {"device_id": ""}
	for i in get_field_slot_count():
		slot_config["field_" + str(i)] = {"device_id": ""}
	for i in get_particle_slot_count():
		slot_config["particle_" + str(i)] = {"device_id": ""}


func get_weapon_slot_count() -> int:
	var ship_stats: Dictionary = _get_current_ship_stats()
	return int(ship_stats.get("weapon_slots", 3))


func get_core_slot_count() -> int:
	var ship_stats: Dictionary = _get_current_ship_stats()
	return int(ship_stats.get("core_slots", 1))


func get_field_slot_count() -> int:
	var ship_stats: Dictionary = _get_current_ship_stats()
	return int(ship_stats.get("field_slots", 2))


func get_particle_slot_count() -> int:
	var ship_stats: Dictionary = _get_current_ship_stats()
	return int(ship_stats.get("particle_slots", 1))



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
		"completed_levels": completed_levels,
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
	completed_levels = data.get("completed_levels", {}) as Dictionary
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
	completed_levels = {}
	stats = {}


func complete_level(level_id: String, grade: String) -> void:
	## Record a level completion. Only upgrades the grade (A > B > C > D > F).
	var old_grade: String = str(completed_levels.get(level_id, ""))
	if old_grade == "" or _grade_rank(grade) < _grade_rank(old_grade):
		completed_levels[level_id] = grade
	save_game()


func get_level_grade(level_id: String) -> String:
	return str(completed_levels.get(level_id, ""))


func is_level_completed(level_id: String) -> bool:
	return completed_levels.has(level_id)


func _grade_rank(grade: String) -> int:
	## Lower = better. Used to compare grades.
	match grade:
		"S": return 0
		"A": return 1
		"B": return 2
		"C": return 3
		"D": return 4
		"F": return 5
	return 99


func reset_campaign() -> void:
	current_level = 0
	completed_levels = {}
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


func set_slot_device(slot_key: String, device_id: String, _component_type: String = "") -> void:
	if not slot_config.has(slot_key):
		slot_config[slot_key] = {"device_id": ""}
	slot_config[slot_key]["device_id"] = device_id
	save_game()


func _migrate_slot_config() -> void:
	## Migrate old ext_/int_/dev_ slot_config to typed slots (weapon_/core_/field_).
	var has_old_keys: bool = false
	for key in slot_config:
		if str(key).begins_with("ext_") or str(key).begins_with("int_") or str(key).begins_with("dev_"):
			has_old_keys = true
			break
	if not has_old_keys:
		# Already in new format — just ensure all slots exist
		_pad_missing_slots()
		return

	# Collect items from old format
	var weapons: Array[String] = []
	var cores: Array[String] = []
	var fields: Array[String] = []
	for key in slot_config:
		var _sk: String = str(key)
		var sd: Dictionary = slot_config[key]
		var comp_type: String = str(sd.get("component_type", ""))
		if comp_type == "weapon":
			var wid: String = str(sd.get("weapon_id", ""))
			if wid != "":
				weapons.append(wid)
		elif comp_type == "power_core":
			var did: String = str(sd.get("device_id", ""))
			if did != "":
				cores.append(did)
		elif comp_type == "device":
			var did: String = str(sd.get("device_id", ""))
			if did != "":
				fields.append(did)

	# Build new slot_config
	slot_config = {}
	for i in get_weapon_slot_count():
		var wid: String = weapons[i] if i < weapons.size() else ""
		slot_config["weapon_" + str(i)] = {"weapon_id": wid}
	for i in get_core_slot_count():
		var did: String = cores[i] if i < cores.size() else ""
		slot_config["core_" + str(i)] = {"device_id": did}
	for i in get_field_slot_count():
		var did: String = fields[i] if i < fields.size() else ""
		slot_config["field_" + str(i)] = {"device_id": did}
	for i in get_particle_slot_count():
		slot_config["particle_" + str(i)] = {"device_id": ""}

	save_game()


func _pad_missing_slots() -> void:
	## Ensure all typed slots exist up to the current ship's counts.
	for i in get_weapon_slot_count():
		var k: String = "weapon_" + str(i)
		if not slot_config.has(k):
			slot_config[k] = {"weapon_id": ""}
	for i in get_core_slot_count():
		var k: String = "core_" + str(i)
		if not slot_config.has(k):
			slot_config[k] = {"device_id": ""}
	for i in get_field_slot_count():
		var k: String = "field_" + str(i)
		if not slot_config.has(k):
			slot_config[k] = {"device_id": ""}
	for i in get_particle_slot_count():
		var k: String = "particle_" + str(i)
		if not slot_config.has(k):
			slot_config[k] = {"device_id": ""}


func get_loadout_data() -> LoadoutData:
	## Constructs a LoadoutData from current_ship_index + slot_config.
	## Maps weapon slots → hp_N in hardpoint_assignments.
	var l := LoadoutData.new()
	l.id = "live"
	l.ship_id = ShipRegistry.get_ship_name(current_ship_index).to_lower()
	l.hardpoint_assignments = {}
	for i in get_weapon_slot_count():
		var slot_key: String = "weapon_" + str(i)
		var hp_id: String = "hp_" + str(i)
		var slot_data: Dictionary = slot_config.get(slot_key, {})
		var weapon_id: String = str(slot_data.get("weapon_id", ""))
		l.hardpoint_assignments[hp_id] = {"weapon_id": weapon_id}
	return l
