class_name LoopUsageScanner
extends RefCounted
## Scans all data sources to find which loops are in use.
## Returns a Dictionary mapping loop_path -> Array[String] of usage labels.
## Results are cached per frame so multiple LoopBrowser instances don't repeat the work.

static var _cached_usage: Dictionary = {}
static var _cache_frame: int = -1


static func scan() -> Dictionary:
	# Return cached result if already scanned this frame
	var frame: int = Engine.get_process_frames()
	if frame == _cache_frame and not _cached_usage.is_empty():
		return _cached_usage

	var usage: Dictionary = {}  # path -> Array[String]

	# Weapons
	var weapons: Array[WeaponData] = WeaponDataManager.load_all()
	for w in weapons:
		if w.loop_file_path != "":
			var label: String = "Weapon: " + w.display_name
			_add_usage(usage, w.loop_file_path, label)

	# Enemy ships (presence loops)
	var ships: Array[ShipData] = ShipDataManager.load_all_by_type("enemy")
	for s in ships:
		if s.presence_loop_path != "":
			var label: String = "Enemy: " + s.display_name
			_add_usage(usage, s.presence_loop_path, label)

	# Power cores
	var cores: Array = PowerCoreDataManager.load_all()
	for pc in cores:
		var core_path: String = pc.loop_file_path
		if core_path != "":
			var label: String = "Core: " + pc.display_name
			_add_usage(usage, core_path, label)

	# Devices (field emitters + orbital generators)
	var devices: Array = DeviceDataManager.load_all()
	for d in devices:
		var dev_path: String = d.loop_file_path
		if dev_path != "":
			var label: String = "Device: " + d.display_name
			_add_usage(usage, dev_path, label)

	_cached_usage = usage
	_cache_frame = frame
	return usage


static func _add_usage(usage: Dictionary, path: String, label: String) -> void:
	if not usage.has(path):
		usage[path] = []
	var arr: Array = usage[path]
	arr.append(label)
