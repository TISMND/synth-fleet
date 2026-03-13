class_name SoundTagManager
extends RefCounted
## Manages tags for audio sample files. Stores as JSON in the project's samples folder.
## Schema: { "file_tags": { path: [tags] }, "tag_palette": { tag: "#hex" } }

const TAG_FILE := "res://assets/audio/samples/sound_tags.json"

static var _file_tags: Dictionary = {}
static var _tag_palette: Dictionary = {}
static var _loaded: bool = false


static func load_tags() -> void:
	_file_tags = {}
	_tag_palette = {}
	_loaded = true
	if not FileAccess.file_exists(TAG_FILE):
		return
	var file := FileAccess.open(TAG_FILE, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary:
		return
	var dict: Dictionary = data
	# Backward-compatible: if root has "file_tags" key, use new schema
	if dict.has("file_tags"):
		var ft: Variant = dict.get("file_tags", {})
		if ft is Dictionary:
			_file_tags = ft
		var tp: Variant = dict.get("tag_palette", {})
		if tp is Dictionary:
			_tag_palette = tp
	else:
		# Legacy: entire dict is file_tags
		_file_tags = dict


static func save_tags() -> void:
	var file := FileAccess.open(TAG_FILE, FileAccess.WRITE)
	if file:
		var data: Dictionary = {
			"file_tags": _file_tags,
			"tag_palette": _tag_palette
		}
		file.store_string(JSON.stringify(data, "\t"))


static func get_tags_for(path: String) -> Array[String]:
	if not _loaded:
		load_tags()
	var result: Array[String] = []
	var raw: Variant = _file_tags.get(path, [])
	if raw is Array:
		for item in raw:
			result.append(str(item))
	return result


static func set_tags_for(path: String, tags: Array[String]) -> void:
	if not _loaded:
		load_tags()
	if tags.is_empty():
		_file_tags.erase(path)
	else:
		_file_tags[path] = tags
	save_tags()


static func rename_path(old_path: String, new_path: String) -> void:
	if not _loaded:
		load_tags()
	if old_path in _file_tags:
		_file_tags[new_path] = _file_tags[old_path]
		_file_tags.erase(old_path)
		save_tags()


static func all_tag_names() -> Array[String]:
	if not _loaded:
		load_tags()
	var tag_set: Dictionary = {}
	for path in _file_tags:
		var tags: Variant = _file_tags[path]
		if tags is Array:
			for t in tags:
				tag_set[str(t)] = true
	# Also include palette tags
	for t in _tag_palette:
		tag_set[str(t)] = true
	var result: Array[String] = []
	for t in tag_set:
		result.append(str(t))
	result.sort()
	return result


# ── Palette methods ──────────────────────────────────────────

static func get_palette() -> Dictionary:
	if not _loaded:
		load_tags()
	return _tag_palette.duplicate()


static func set_palette_entry(tag: String, color_hex: String) -> void:
	if not _loaded:
		load_tags()
	_tag_palette[tag] = color_hex
	save_tags()


static func remove_palette_entry(tag: String) -> void:
	if not _loaded:
		load_tags()
	_tag_palette.erase(tag)
	save_tags()


static func get_tag_color(tag: String) -> Color:
	if not _loaded:
		load_tags()
	var hex: Variant = _tag_palette.get(tag, "")
	if hex is String and hex != "":
		return Color.from_string(hex, Color(0.4, 0.75, 1.0))
	# Fallback: generate a deterministic color from the tag name
	var h: float = float(tag.hash() & 0xFFFF) / 65535.0
	return Color.from_hsv(h, 0.5, 0.85)
