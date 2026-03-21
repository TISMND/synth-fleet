class_name KeyChangeDataManager
extends RefCounted
## Reads/writes key change preset JSON files in res://data/key_changes/

const DIR_PATH := "res://data/key_changes/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(data: KeyChangeData) -> void:
	_ensure_dir()
	var file := FileAccess.open(DIR_PATH + data.id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data.to_dict(), "\t"))


static func load_by_id(id: String) -> KeyChangeData:
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
	return KeyChangeData.from_dict(data)


static func load_all() -> Array[KeyChangeData]:
	_ensure_dir()
	var presets: Array[KeyChangeData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return presets
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var kc: KeyChangeData = load_by_id(fname.get_basename())
			if kc:
				presets.append(kc)
		fname = dir.get_next()
	dir.list_dir_end()
	return presets


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
