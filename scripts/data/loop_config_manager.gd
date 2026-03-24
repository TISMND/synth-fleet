class_name LoopConfigManager
extends RefCounted
## Manages per-loop display names and base volume levels.
## Stored in res://data/loop_config.json (git-tracked, dev-authored).

const FILE_PATH := "res://data/loop_config.json"

static var _config: Dictionary = {}
static var _loaded: bool = false


static func _load_if_needed() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE_PATH):
		_config = {}
		return
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		_config = {}
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	if err != OK:
		push_warning("LoopConfigManager: JSON parse error in %s: %s" % [FILE_PATH, json.get_error_message()])
		_config = {}
		return
	var data: Variant = json.data
	if data is Dictionary:
		_config = data as Dictionary
	else:
		_config = {}


static func save() -> void:
	var dir := DirAccess.open("res://data")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://data")
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LoopConfigManager: failed to save %s" % FILE_PATH)
		return
	file.store_string(JSON.stringify(_config, "\t"))


static func get_entry(loop_path: String) -> Dictionary:
	_load_if_needed()
	if _config.has(loop_path):
		return _config[loop_path] as Dictionary
	return {}


static func get_volume(loop_path: String) -> float:
	var entry: Dictionary = get_entry(loop_path)
	return float(entry.get("volume_db", 0.0))


static func set_volume(loop_path: String, volume_db: float) -> void:
	_load_if_needed()
	if not _config.has(loop_path):
		_config[loop_path] = {"display_name": _default_display_name(loop_path), "volume_db": volume_db}
	else:
		var entry: Dictionary = _config[loop_path] as Dictionary
		entry["volume_db"] = volume_db
	save()


static func get_display_name(loop_path: String) -> String:
	var entry: Dictionary = get_entry(loop_path)
	var name: String = str(entry.get("display_name", ""))
	if name == "":
		return _default_display_name(loop_path)
	return name


static func set_display_name(loop_path: String, display_name: String) -> void:
	_load_if_needed()
	if not _config.has(loop_path):
		_config[loop_path] = {"display_name": display_name, "volume_db": 0.0}
	else:
		var entry: Dictionary = _config[loop_path] as Dictionary
		entry["display_name"] = display_name
	save()


static func migrate_path(old_path: String, new_path: String) -> void:
	## Move config entry from old_path to new_path after a file rename.
	_load_if_needed()
	if _config.has(old_path):
		var entry: Dictionary = _config[old_path] as Dictionary
		_config[new_path] = entry
		_config.erase(old_path)
		save()


static func reload() -> void:
	_loaded = false
	_config = {}


static func get_all() -> Dictionary:
	_load_if_needed()
	return _config


static func _default_display_name(loop_path: String) -> String:
	## Derive a readable name from the filename.
	## Splice filenames are like "Artist - BPM - Key - Name.wav"
	## We keep just the last segment (the meaningful name).
	var filename: String = loop_path.get_file().get_basename()
	var parts: PackedStringArray = filename.split(" - ")
	if parts.size() >= 2:
		return parts[parts.size() - 1].strip_edges()
	return filename
