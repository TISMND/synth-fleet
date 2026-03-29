class_name BossDataManager
extends RefCounted
## Reads/writes boss JSON files in res://data/bosses/

const DIR_PATH := "res://data/bosses/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var path: String = DIR_PATH + id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BossDataManager: failed to save %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> BossData:
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("BossDataManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	return BossData.from_dict(data)


static func load_all() -> Array[BossData]:
	_ensure_dir()
	var bosses: Array[BossData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return bosses
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var b: BossData = load_by_id(fname.get_basename())
			if b:
				bosses.append(b)
		fname = dir.get_next()
	dir.list_dir_end()
	return bosses


static func generate_id() -> String:
	var existing: Array[String] = list_ids()
	var idx := 1
	while true:
		var candidate: String = "boss_" + str(idx)
		if candidate not in existing:
			return candidate
		idx += 1
	return "boss_1"


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
