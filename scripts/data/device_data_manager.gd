class_name DeviceDataManager
extends RefCounted
## Read-only facade that searches both field_emitters/ and orbital_generators/
## for device loading. Editing is done through type-specific managers.


static func load_by_id(id: String) -> DeviceData:
	var device: DeviceData = FieldEmitterDataManager.load_by_id(id)
	if device:
		return device
	device = OrbitalGeneratorDataManager.load_by_id(id)
	if device:
		return device
	# Fallback: check legacy res://data/devices/ for migration
	var legacy_path: String = "res://data/devices/" + id + ".json"
	if FileAccess.file_exists(legacy_path):
		var file := FileAccess.open(legacy_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) != OK:
				push_warning("DeviceDataManager: JSON parse error in %s: %s" % [legacy_path, json.get_error_message()])
				return null
			var data: Dictionary = json.data
			return DeviceData.from_dict(data)
	return null


static func load_all() -> Array[DeviceData]:
	var devices: Array[DeviceData] = []
	devices.append_array(FieldEmitterDataManager.load_all())
	devices.append_array(OrbitalGeneratorDataManager.load_all())
	return devices


static func list_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(FieldEmitterDataManager.list_ids())
	ids.append_array(OrbitalGeneratorDataManager.list_ids())
	return ids
