class_name NebulaDataManager
extends RefCounted
## Reads/writes nebula definition JSON files in res://data/nebula_definitions/

const DIR_PATH := "res://data/nebula_definitions/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(data: NebulaData) -> void:
	_ensure_dir()
	var path: String = DIR_PATH + data.id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("NebulaDataManager: failed to save %s" % path)
		return
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
		push_warning("NebulaDataManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
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


static func rename(old_id: String, new_id: String, data: NebulaData) -> void:
	if list_ids().has(new_id) and old_id != new_id:
		push_error("NebulaDataManager: cannot rename to '%s' — ID already exists" % new_id)
		return
	if old_id == new_id:
		save(data)
		return
	save(data)
	delete(old_id)
	_update_level_nebula_references(old_id, new_id)


static func _update_level_nebula_references(old_id: String, new_id: String) -> void:
	var level_ids: Array[String] = LevelDataManager.list_ids()
	for lid in level_ids:
		var level: LevelData = LevelDataManager.load_by_id(lid)
		if not level:
			continue
		var changed: bool = false
		for placement in level.nebula_placements:
			if placement.get("nebula_id", "") == old_id:
				placement["nebula_id"] = new_id
				changed = true
		if changed:
			LevelDataManager.save(lid, level.to_dict())


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
