class_name WeaponDataManager
extends RefCounted
## Reads/writes weapon JSON files in res://data/weapons/

const DIR_PATH := "res://data/weapons/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var path: String = DIR_PATH + id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("WeaponDataManager: failed to save %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> WeaponData:
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("WeaponDataManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	return WeaponData.from_dict(data)


static func load_all() -> Array[WeaponData]:
	_ensure_dir()
	var weapons: Array[WeaponData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return weapons
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var w: WeaponData = load_by_id(fname.get_basename())
			if w:
				weapons.append(w)
		fname = dir.get_next()
	dir.list_dir_end()
	return weapons


static func delete(id: String) -> void:
	var path: String = DIR_PATH + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Rename a weapon: save under new_id, delete old_id, update GameState references.
static func rename(old_id: String, new_id: String, data: Dictionary) -> void:
	if list_ids().has(new_id) and old_id != new_id:
		push_error("WeaponDataManager: cannot rename to '%s' — ID already exists" % new_id)
		return
	if old_id == new_id:
		save(new_id, data)
		return
	# Save new file
	save(new_id, data)
	# Delete old file
	delete(old_id)
	# Update GameState references (owned weapons + slot assignments)
	_update_game_state_references(old_id, new_id)


static func _update_game_state_references(old_id: String, new_id: String) -> void:
	# Update owned_weapon_ids
	var idx: int = GameState.owned_weapon_ids.find(old_id)
	if idx >= 0:
		GameState.owned_weapon_ids[idx] = new_id
	# Update slot assignments
	for slot_key in GameState.slot_config:
		var slot_data: Dictionary = GameState.slot_config[slot_key] as Dictionary
		if str(slot_data.get("weapon_id", "")) == old_id:
			slot_data["weapon_id"] = new_id
	GameState.save_game()


static func list_ids() -> Array[String]:
	_ensure_dir()
	var ids: Array[String] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return ids
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			ids.append(fname.get_basename())
		fname = dir.get_next()
	dir.list_dir_end()
	return ids
