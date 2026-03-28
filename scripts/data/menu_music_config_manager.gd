class_name MenuMusicConfigManager
extends RefCounted
## Reads/writes menu music layer configuration from res://data/menu_music_config.json

const FILE_PATH := "res://data/menu_music_config.json"


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(FILE_PATH):
		return {"layers": [], "fade_out_duration_ms": 2000}
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if not file:
		return {"layers": [], "fade_out_duration_ms": 2000}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("MenuMusicConfigManager: JSON parse error")
		return {"layers": [], "fade_out_duration_ms": 2000}
	if json.data is Dictionary:
		return json.data
	return {"layers": [], "fade_out_duration_ms": 2000}


static func save_config(data: Dictionary) -> void:
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("MenuMusicConfigManager: failed to save")
		return
	file.store_string(JSON.stringify(data, "\t"))
