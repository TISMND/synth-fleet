class_name SfxConfigManager extends RefCounted
## Loads and saves the single global SFX config from res://data/sfx_config.json.

const FILE_PATH := "res://data/sfx_config.json"


static func save(config: SfxConfig) -> void:
	var dir := DirAccess.open("res://data")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://data")
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SfxConfigManager: Could not write to %s" % FILE_PATH)
		return
	file.store_string(JSON.stringify(config.to_dict(), "\t"))
	file.close()


static func load_config() -> SfxConfig:
	if not FileAccess.file_exists(FILE_PATH) and not ResourceLoader.exists(FILE_PATH):
		return SfxConfig.from_dict({})
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("SfxConfigManager: Could not read %s" % FILE_PATH)
		return SfxConfig.from_dict({})
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("SfxConfigManager: JSON parse error in %s: %s" % [FILE_PATH, json.get_error_message()])
		return SfxConfig.from_dict({})
	var data: Dictionary = json.data
	return SfxConfig.from_dict(data)
