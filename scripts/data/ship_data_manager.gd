class_name ShipDataManager
extends RefCounted
## Reads/writes ship JSON files in user://ships/

const DIR_PATH := "user://ships/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var file := FileAccess.open(DIR_PATH + id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> ShipData:
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
	return ShipData.from_dict(data)


static func load_all() -> Array[ShipData]:
	_ensure_dir()
	var ships: Array[ShipData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return ships
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var s: ShipData = load_by_id(fname.get_basename())
			if s:
				ships.append(s)
		fname = dir.get_next()
	dir.list_dir_end()
	return ships


static func load_all_by_type(ship_type: String) -> Array[ShipData]:
	var all: Array[ShipData] = load_all()
	var filtered: Array[ShipData] = []
	for s in all:
		if s.type == ship_type:
			filtered.append(s)
	return filtered


static func generate_id(prefix: String) -> String:
	var existing: Array[String] = list_ids()
	var idx := 1
	while true:
		var candidate: String = prefix + "_" + str(idx)
		if candidate not in existing:
			return candidate
		idx += 1
	return prefix + "_1"


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
