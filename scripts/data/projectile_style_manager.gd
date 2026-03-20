class_name ProjectileStyleManager
extends RefCounted
## Reads/writes projectile style JSON files in res://data/projectile_styles/
## Also manages mask PNGs in res://data/projectile_masks/

const DIR_PATH := "res://data/projectile_styles/"
const MASKS_DIR := "res://data/projectile_masks/"


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func _ensure_masks_dir() -> void:
	DirAccess.make_dir_recursive_absolute(MASKS_DIR)


static func save(id: String, data: Dictionary) -> void:
	_ensure_dir()
	data["id"] = id
	var file := FileAccess.open(DIR_PATH + id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


static func load_by_id(id: String) -> ProjectileStyle:
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
	return ProjectileStyle.from_dict(data)


static func load_all() -> Array[ProjectileStyle]:
	_ensure_dir()
	var styles: Array[ProjectileStyle] = []
	var dir := DirAccess.open(DIR_PATH)
	if not dir:
		return styles
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var s: ProjectileStyle = load_by_id(fname.get_basename())
			if s:
				styles.append(s)
		fname = dir.get_next()
	dir.list_dir_end()
	return styles


static func delete(id: String) -> void:
	var path: String = DIR_PATH + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Rename a style: save under new_id, delete old_id, update all weapon references.
static func rename(old_id: String, new_id: String, data: Dictionary) -> void:
	if old_id == new_id:
		save(new_id, data)
		return
	# Save new file
	save(new_id, data)
	# Delete old file
	delete(old_id)
	# Update all weapons that reference this style
	_update_weapon_style_references(old_id, new_id)


static func _update_weapon_style_references(old_id: String, new_id: String) -> void:
	var weapon_ids: Array[String] = WeaponDataManager.list_ids()
	for wid in weapon_ids:
		var weapon: WeaponData = WeaponDataManager.load_by_id(wid)
		if weapon and weapon.projectile_style_id == old_id:
			weapon.projectile_style_id = new_id
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


static func list_masks() -> Array[String]:
	_ensure_masks_dir()
	var masks: Array[String] = []
	var dir := DirAccess.open(MASKS_DIR)
	if not dir:
		return masks
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".png") or fname.ends_with(".PNG"):
			masks.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return masks


static func import_mask(source_path: String, target_name: String) -> String:
	_ensure_masks_dir()
	if not target_name.ends_with(".png"):
		target_name += ".png"
	var target_path: String = MASKS_DIR + target_name
	var img := Image.new()
	var err: Error = img.load(source_path)
	if err != OK:
		return ""
	err = img.save_png(target_path)
	if err != OK:
		return ""
	return target_path
