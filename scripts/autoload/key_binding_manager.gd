extends Node
## KeyBindingManager — persists slot key bindings and combo presets to user://settings/keybindings.json.
## Applies bindings to Godot InputMap at runtime.

signal bindings_changed

const SAVE_PATH := "user://settings/keybindings.json"

# Default physical keycodes per slot type (indexed)
const WEAPON_DEFAULT_KEYS: Array = [
	{"physical_keycode": 49, "label": "1"},  # 1
	{"physical_keycode": 50, "label": "2"},  # 2
	{"physical_keycode": 51, "label": "3"},  # 3
	{"physical_keycode": 52, "label": "4"},  # 4
	{"physical_keycode": 53, "label": "5"},  # 5
	{"physical_keycode": 54, "label": "6"},  # 6
]
const CORE_DEFAULT_KEYS: Array = [
	{"physical_keycode": 69, "label": "E"},  # E
	{"physical_keycode": 82, "label": "R"},  # R
]
const FIELD_DEFAULT_KEYS: Array = [
	{"physical_keycode": 70, "label": "F"},  # F
	{"physical_keycode": 71, "label": "G"},  # G
	{"physical_keycode": 84, "label": "T"},  # T
	{"physical_keycode": 86, "label": "V"},  # V
]
const PARTICLE_DEFAULT_KEYS: Array = [
	{"physical_keycode": 72, "label": "H"},  # H
	{"physical_keycode": 74, "label": "J"},  # J
]

# Reserved physical keycodes (WASD, arrows, Escape, Space, C)
const RESERVED_KEYS: Array = [
	65, 87, 83, 68,  # A W S D
	4194319, 4194320, 4194321, 4194322,  # arrows
	4194305,  # Escape
	32,  # Space
	67,  # C
]

var _bindings: Dictionary = {}  # slot_key -> {physical_keycode, label}
var _combo_presets: Array = []  # [{label, physical_keycode, key_label, pattern}]
var _slot_volumes: Dictionary = {}  # slot_key -> float (dB, default 0.0)

# Old-to-new key migration map (built once during load)
var _old_key_remap: Dictionary = {}


func _ready() -> void:
	load_bindings()
	apply_to_input_map()


func get_slot_action(slot_key: String) -> String:
	## Returns the InputMap action name for a slot key (e.g. "weapon_0" -> "slot_weapon_0").
	return "slot_" + slot_key


func get_default_binding(slot_key: String) -> Dictionary:
	## Returns the default key binding for a given slot key.
	if slot_key.begins_with("weapon_"):
		var idx: int = int(slot_key.replace("weapon_", ""))
		if idx < WEAPON_DEFAULT_KEYS.size():
			return WEAPON_DEFAULT_KEYS[idx]
	elif slot_key.begins_with("core_"):
		var idx: int = int(slot_key.replace("core_", ""))
		if idx < CORE_DEFAULT_KEYS.size():
			return CORE_DEFAULT_KEYS[idx]
	elif slot_key.begins_with("field_"):
		var idx: int = int(slot_key.replace("field_", ""))
		if idx < FIELD_DEFAULT_KEYS.size():
			return FIELD_DEFAULT_KEYS[idx]
	elif slot_key.begins_with("particle_"):
		var idx: int = int(slot_key.replace("particle_", ""))
		if idx < PARTICLE_DEFAULT_KEYS.size():
			return PARTICLE_DEFAULT_KEYS[idx]
	return {"physical_keycode": 0, "label": "?"}


func _build_default_bindings() -> Dictionary:
	var defaults: Dictionary = {}
	for i in mini(6, WEAPON_DEFAULT_KEYS.size()):
		defaults["weapon_" + str(i)] = WEAPON_DEFAULT_KEYS[i].duplicate()
	for i in mini(3, CORE_DEFAULT_KEYS.size()):
		defaults["core_" + str(i)] = CORE_DEFAULT_KEYS[i].duplicate()
	for i in mini(4, FIELD_DEFAULT_KEYS.size()):
		defaults["field_" + str(i)] = FIELD_DEFAULT_KEYS[i].duplicate()
	for i in mini(2, PARTICLE_DEFAULT_KEYS.size()):
		defaults["particle_" + str(i)] = PARTICLE_DEFAULT_KEYS[i].duplicate()
	return defaults


func _remap_old_slot_key(old_key: String) -> String:
	## Convert old ext_/int_ slot keys to new typed keys. Returns "" if not migratable.
	if old_key.begins_with("ext_"):
		# ext slots were weapons
		return "weapon_" + old_key.replace("ext_", "")
	elif old_key.begins_with("int_"):
		# int_0 was typically core, int_1+ were fields, but we can't perfectly
		# distinguish. Map int_0 -> core_0, int_1 -> field_0, int_2 -> field_1, etc.
		var idx: int = int(old_key.replace("int_", ""))
		if idx == 0:
			return "core_0"
		else:
			return "field_" + str(idx - 1)
	return ""


func load_bindings() -> void:
	_bindings = _build_default_bindings()
	_combo_presets.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return

	var data: Dictionary = json.data as Dictionary if json.data is Dictionary else {}

	# Load slot bindings — migrate old ext_/int_/dev_ keys to typed keys
	var saved_bindings: Dictionary = data.get("bindings", {}) as Dictionary if data.get("bindings") is Dictionary else {}
	for slot_key in saved_bindings:
		var sk: String = str(slot_key)
		if sk.begins_with("dev_"):
			continue  # Old 3-category system — skip
		# Migrate old keys
		var target_key: String = sk
		if sk.begins_with("ext_") or sk.begins_with("int_"):
			target_key = _remap_old_slot_key(sk)
			if target_key == "":
				continue
		var entry: Dictionary = saved_bindings[slot_key] as Dictionary if saved_bindings[slot_key] is Dictionary else {}
		if entry.has("physical_keycode") and entry.has("label"):
			_bindings[target_key] = {
				"physical_keycode": int(entry["physical_keycode"]),
				"label": str(entry["label"]),
			}

	# Load slot volumes — migrate old keys
	_slot_volumes.clear()
	var saved_volumes: Dictionary = data.get("slot_volumes", {}) as Dictionary if data.get("slot_volumes") is Dictionary else {}
	for slot_key in saved_volumes:
		var sk: String = str(slot_key)
		var target_key: String = sk
		if sk.begins_with("ext_") or sk.begins_with("int_"):
			target_key = _remap_old_slot_key(sk)
			if target_key == "":
				continue
		_slot_volumes[target_key] = float(saved_volumes[slot_key])

	# Load combo presets — migrate pattern keys
	var saved_presets: Array = data.get("combo_presets", []) as Array if data.get("combo_presets") is Array else []
	for preset in saved_presets:
		var p: Dictionary = preset as Dictionary if preset is Dictionary else {}
		if p.has("label") and p.has("pattern"):
			var old_pattern: Dictionary = p["pattern"] as Dictionary if p["pattern"] is Dictionary else {}
			var new_pattern: Dictionary = {}
			for pk in old_pattern:
				var psk: String = str(pk)
				if psk.begins_with("ext_") or psk.begins_with("int_"):
					var mapped: String = _remap_old_slot_key(psk)
					if mapped != "":
						new_pattern[mapped] = old_pattern[pk]
				else:
					new_pattern[psk] = old_pattern[pk]
			_combo_presets.append({
				"label": str(p.get("label", "")),
				"physical_keycode": int(p.get("physical_keycode", 0)),
				"key_label": str(p.get("key_label", "")),
				"pattern": new_pattern,
			})


func save_bindings() -> void:
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("user://settings")

	var data: Dictionary = {
		"bindings": _bindings,
		"combo_presets": _combo_presets,
		"slot_volumes": _slot_volumes,
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("KeyBindingManager: failed to save to " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func apply_to_input_map() -> void:
	for slot_key in _bindings:
		var action: String = get_slot_action(slot_key)
		var binding: Dictionary = _bindings[slot_key]
		var pkc: int = int(binding["physical_keycode"])
		if pkc == 0:
			continue
		_remap_action(action, pkc)

	# Register combo preset actions
	_apply_combo_actions()


func _remap_action(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, ev)


func _apply_combo_actions() -> void:
	# Remove old combo actions
	for i in 20:
		var action: String = "combo_preset_" + str(i)
		if InputMap.has_action(action):
			InputMap.erase_action(action)

	# Register current combo presets
	for i in _combo_presets.size():
		var preset: Dictionary = _combo_presets[i]
		var pkc: int = int(preset["physical_keycode"])
		if pkc == 0:
			continue
		var action: String = "combo_preset_" + str(i)
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = pkc as Key
		InputMap.action_add_event(action, ev)


func set_slot_key(slot_key: String, physical_keycode: int, label: String) -> void:
	_bindings[slot_key] = {"physical_keycode": physical_keycode, "label": label}
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func get_key_label_for_slot(slot_key: String) -> String:
	if _bindings.has(slot_key):
		var binding: Dictionary = _bindings[slot_key]
		return str(binding["label"])
	return "?"


func is_key_reserved(physical_keycode: int) -> bool:
	return physical_keycode in RESERVED_KEYS


func is_key_conflicting(physical_keycode: int, exclude_slot: String = "") -> String:
	## Returns the slot_key that already uses this keycode, or "" if none.
	for slot_key in _bindings:
		if slot_key == exclude_slot:
			continue
		var binding: Dictionary = _bindings[slot_key]
		if int(binding["physical_keycode"]) == physical_keycode:
			return slot_key
	# Check combo presets too
	for i in _combo_presets.size():
		var preset: Dictionary = _combo_presets[i]
		if int(preset["physical_keycode"]) == physical_keycode:
			return "combo_" + str(i)
	return ""


func add_combo_preset(label: String, pattern: Dictionary, physical_keycode: int, key_label: String) -> void:
	_combo_presets.append({
		"label": label,
		"physical_keycode": physical_keycode,
		"key_label": key_label,
		"pattern": pattern,
	})
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func remove_combo_preset(index: int) -> void:
	if index < 0 or index >= _combo_presets.size():
		return
	_combo_presets.remove_at(index)
	apply_to_input_map()
	save_bindings()
	bindings_changed.emit()


func get_combo_presets() -> Array:
	return _combo_presets


func set_slot_volume(slot_key: String, volume_db: float) -> void:
	_slot_volumes[slot_key] = volume_db
	save_bindings()
	bindings_changed.emit()


func get_slot_volume(slot_key: String) -> float:
	return float(_slot_volumes.get(slot_key, 0.0))


func get_all_slot_keys() -> Array:
	return _bindings.keys()
