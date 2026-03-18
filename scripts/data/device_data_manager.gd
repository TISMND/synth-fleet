class_name DeviceDataManager
extends RefCounted
## Reads/writes device JSON files in user://devices/

const DIR_PATH := "user://devices/"


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


static func ensure_starter_devices() -> void:
	_ensure_dir()
	var existing: Array[String] = list_ids()
	if existing.size() > 0:
		return
	var starters: Array[Dictionary] = [
		{
			"id": "generator_mk_i",
			"display_name": "Generator Mk I",
			"description": "Basic power generator. +5 generator power.",
			"type": "generator",
			"stats_modifiers": {"generator_power": 5},
		},
		{
			"id": "generator_mk_ii",
			"display_name": "Generator Mk II",
			"description": "Improved power generator. +10 generator power.",
			"type": "generator",
			"stats_modifiers": {"generator_power": 10},
		},
		{
			"id": "shield_boost_i",
			"display_name": "Shield Boost I",
			"description": "Basic shield capacitor. +2 shield segments.",
			"type": "shield",
			"stats_modifiers": {"shield_segments": 2},
		},
		{
			"id": "shield_boost_ii",
			"display_name": "Shield Boost II",
			"description": "Advanced shield capacitor. +4 shield segments.",
			"type": "shield",
			"stats_modifiers": {"shield_segments": 4},
		},
	]
	for starter in starters:
		save(str(starter["id"]), starter)
