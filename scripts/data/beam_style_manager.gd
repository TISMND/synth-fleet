class_name BeamStyleManager
extends RefCounted
## Reads/writes beam style JSON files in res://data/beam_styles/

const DIR_PATH := "res://data/beam_styles/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var path: String = DIR_PATH + id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BeamStyleManager: failed to save %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> BeamStyle:
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("BeamStyleManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	return BeamStyle.from_dict(data)


static func load_all() -> Array[BeamStyle]:
	_ensure_dir()
	var styles: Array[BeamStyle] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return styles
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var s: BeamStyle = load_by_id(fname.get_basename())
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
		push_error("BeamStyleManager: cannot rename to '%s' — ID already exists" % new_id)
		return
	if old_id == new_id:
		save(new_id, data)
		return
	save(new_id, data)
	delete(old_id)
	_update_weapon_beam_references(old_id, new_id)


static func _update_weapon_beam_references(old_id: String, new_id: String) -> void:
	var weapon_ids: Array[String] = WeaponDataManager.list_ids()
	for wid in weapon_ids:
		var weapon: WeaponData = WeaponDataManager.load_by_id(wid)
		if weapon and weapon.beam_style_id == old_id:
			weapon.beam_style_id = new_id
			WeaponDataManager.save(wid, weapon.to_dict())


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
