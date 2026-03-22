class_name FieldEmitterDataManager
extends RefCounted
## Reads/writes field emitter device JSON files in res://data/field_emitters/

const DIR_PATH := "res://data/field_emitters/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var file := FileAccess.open(DIR_PATH + id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> DeviceData:
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	var data: Dictionary = json.data
	return DeviceData.from_dict(data)


static func load_all() -> Array[DeviceData]:
	_ensure_dir()
	var devices: Array[DeviceData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return devices
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var d: DeviceData = load_by_id(fname.get_basename())
			if d:
				devices.append(d)
		fname = dir.get_next()
	dir.list_dir_end()
	return devices


static func rename(old_id: String, new_id: String, data: Dictionary) -> void:
	if old_id == new_id:
		save(new_id, data)
		return
	save(new_id, data)
	delete(old_id)
	# Update GameState references (owned devices + slot assignments)
	var idx: int = GameState.owned_device_ids.find(old_id)
	if idx >= 0:
		GameState.owned_device_ids[idx] = new_id
	for slot_key in GameState.slot_config:
		if not slot_key.begins_with("field_"):
			continue
		var slot_data: Dictionary = GameState.slot_config[slot_key] as Dictionary
		if str(slot_data.get("device_id", "")) == old_id:
			slot_data["device_id"] = new_id
	GameState.save_game()


static func delete(id: String) -> void:
	var path: String = DIR_PATH + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


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
