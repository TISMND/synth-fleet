class_name VfxConfigManager extends RefCounted
## Loads and saves the global VFX config from res://data/vfx_config.json.

const FILE_PATH := "res://data/vfx_config.json"


static func save(config: VfxConfig) -> void:
	var dir := DirAccess.open("res://data")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://data")
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("VfxConfigManager: Could not write to %s" % FILE_PATH)
		return
	file.store_string(JSON.stringify(config.to_dict(), "\t"))
	file.close()


static func load_config() -> VfxConfig:
	if not FileAccess.file_exists(FILE_PATH):
		return VfxConfig.from_dict({})
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("VfxConfigManager: Could not read %s" % FILE_PATH)
		return VfxConfig.from_dict({})
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("VfxConfigManager: JSON parse error in %s" % FILE_PATH)
		return VfxConfig.from_dict({})
	var data: Dictionary = json.data
	return VfxConfig.from_dict(data)
