extends Node
## AudioBusSetup — ensures audio buses exist and loads saved volume settings at startup.
## Must be an autoload so settings apply before any scene plays audio.

const SETTINGS_PATH := "user://settings/audio.json"

const BUS_NAMES: Array[String] = ["Weapons", "Enemies", "Atmosphere", "SFX", "UI"]


func _ready() -> void:
	_ensure_buses()
	_load_volumes()


func _ensure_buses() -> void:
	for bus_name in BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			var new_idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(new_idx, bus_name)
			AudioServer.set_bus_send(new_idx, "Master")


func _load_volumes() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return
	var data: Dictionary = json.data
	for bus_name_key in data:
		var bus_idx: int = AudioServer.get_bus_index(str(bus_name_key))
		if bus_idx < 0:
			continue
		var val: float = float(data.get(bus_name_key, 100.0))
		var linear: float = val / 100.0
		if linear <= 0.0:
			AudioServer.set_bus_volume_db(bus_idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
