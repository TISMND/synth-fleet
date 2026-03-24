class_name FieldStyleManager
extends RefCounted
## Reads/writes field style JSON files in res://data/field_styles/

const DIR_PATH := "res://data/field_styles/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var path: String = DIR_PATH + id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("FieldStyleManager: failed to save %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> FieldStyle:
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("FieldStyleManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	return FieldStyle.from_dict(data)


static func load_all() -> Array[FieldStyle]:
	_ensure_dir()
	var styles: Array[FieldStyle] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return styles
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var s: FieldStyle = load_by_id(fname.get_basename())
			if s:
				styles.append(s)
		fname = dir.get_next()
	dir.list_dir_end()
	return styles


static func delete(id: String) -> void:
	var path: String = DIR_PATH + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func rename(old_id: String, new_id: String, data: Dictionary) -> void:
	if list_ids().has(new_id) and old_id != new_id:
		push_error("FieldStyleManager: cannot rename to '%s' — ID already exists" % new_id)
		return
	if old_id == new_id:
		save(new_id, data)
		return
	save(new_id, data)
	delete(old_id)
	_update_device_field_references(old_id, new_id)


static func _update_device_field_references(old_id: String, new_id: String) -> void:
	var emitter_ids: Array[String] = FieldEmitterDataManager.list_ids()
	for eid in emitter_ids:
		var device: DeviceData = FieldEmitterDataManager.load_by_id(eid)
		if device and device.field_style_id == old_id:
			device.field_style_id = new_id
			FieldEmitterDataManager.save(eid, device.to_dict())


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
