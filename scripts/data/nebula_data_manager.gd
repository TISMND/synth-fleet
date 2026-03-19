class_name NebulaDataManager
extends RefCounted
## Reads/writes nebula definition JSON files in res://data/nebula_definitions/

const DIR_PATH := "res://data/nebula_definitions/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(data: NebulaData) -> void:
	_ensure_dir()
	var file := FileAccess.open(DIR_PATH + data.id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data.to_dict(), "\t"))


static func load_by_id(id: String) -> NebulaData:
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
	return NebulaData.from_dict(data)


static func load_all() -> Array[NebulaData]:
	_ensure_dir()
	var nebulas: Array[NebulaData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return nebulas
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var n: NebulaData = load_by_id(fname.get_basename())
			if n:
				nebulas.append(n)
		fname = dir.get_next()
	dir.list_dir_end()
	return nebulas


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
