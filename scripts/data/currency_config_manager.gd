class_name CurrencyConfigManager
extends RefCounted
## Persists currency display settings (shard/coin scale) to user://.

const SAVE_PATH: String = "user://settings/currency_config.json"

static var _cache: Dictionary = {}


static func load_config() -> Dictionary:
	if _cache.size() > 0:
		return _cache
	if not FileAccess.file_exists(SAVE_PATH):
		_cache = _defaults()
		return _cache
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_cache = _defaults()
		return _cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed as Dictionary
		_cache = {
			"shard_scale": float(d.get("shard_scale", 32.0)),
			"coin_scale": float(d.get("coin_scale", 32.0)),
			"pickup_radius": float(d.get("pickup_radius", 16.0)),
		}
	else:
		_cache = _defaults()
	return _cache


static func save_config(data: Dictionary) -> void:
	_cache = data
	var dir_path: String = SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


static func get_scale_for_item(item: ItemData) -> float:
	var cfg: Dictionary = load_config()
	if item.visual_shape.contains("coin"):
		return float(cfg.get("coin_scale", 32.0))
	return float(cfg.get("shard_scale", 32.0))


static func get_pickup_radius() -> float:
	var cfg: Dictionary = load_config()
	return float(cfg.get("pickup_radius", 16.0))


static func _defaults() -> Dictionary:
	return {"shard_scale": 32.0, "coin_scale": 32.0, "pickup_radius": 16.0}
