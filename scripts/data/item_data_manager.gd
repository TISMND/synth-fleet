class_name ItemDataManager
extends RefCounted
## Reads/writes item definition JSON files in res://data/items/

const DIR_PATH := "res://data/items/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(data: ItemData) -> void:
	_ensure_dir()
	var path: String = DIR_PATH + data.id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("ItemDataManager: failed to save %s" % path)
		return
	file.store_string(JSON.stringify(data.to_dict(), "\t"))


static func load_by_id(id: String) -> ItemData:
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ItemDataManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	return ItemData.from_dict(data)


static func load_all() -> Array[ItemData]:
	_ensure_dir()
	var items: Array[ItemData] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return items
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var item: ItemData = load_by_id(fname.get_basename())
			if item:
				items.append(item)
		fname = dir.get_next()
	dir.list_dir_end()
	return items


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
