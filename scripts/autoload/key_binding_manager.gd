extends Node
## KeyBindingManager — persists slot key bindings and combo presets to user://settings/keybindings.json.
## Applies bindings to Godot InputMap at runtime.

signal bindings_changed

const SAVE_PATH := "user://settings/keybindings.json"
const BINDINGS_VERSION: int = 3  # Increment to force re-initialization of key bindings

# Default physical keycodes per slot type (indexed)
## All component slots share sequential number keys.
## Keys 1-9 then 0 covers up to 10 total slots.
## HUD displays matching sequential numbers.
const ALL_DEFAULT_KEYS: Array = [
	{"physical_keycode": 49, "label": "1"},
	{"physical_keycode": 50, "label": "2"},
	{"physical_keycode": 51, "label": "3"},
	{"physical_keycode": 52, "label": "4"},
	{"physical_keycode": 53, "label": "5"},
	{"physical_keycode": 54, "label": "6"},
	{"physical_keycode": 55, "label": "7"},
	{"physical_keycode": 56, "label": "8"},
	{"physical_keycode": 57, "label": "9"},
	{"physical_keycode": 48, "label": "0"},
]
# Legacy arrays for backwards compatibility — populated from ALL_DEFAULT_KEYS
const WEAPON_DEFAULT_KEYS: Array = [
	{"physical_keycode": 49, "label": "1"},
	{"physical_keycode": 50, "label": "2"},
	{"physical_keycode": 51, "label": "3"},
	{"physical_keycode": 52, "label": "4"},
	{"physical_keycode": 53, "label": "5"},
	{"physical_keycode": 54, "label": "6"},
]
const CORE_DEFAULT_KEYS: Array = [
	{"physical_keycode": 55, "label": "7"},
	{"physical_keycode": 56, "label": "8"},
]
const FIELD_DEFAULT_KEYS: Array = [
	{"physical_keycode": 57, "label": "9"},
	{"physical_keycode": 48, "label": "0"},
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



func _ready() -> void:
	load_bindings()
	apply_to_input_map()


func get_binding(slot_key: String) -> Dictionary:
	## Returns the current binding for a slot key, or the default if not set.
	if _bindings.has(slot_key):
		return _bindings[slot_key]
	return get_default_binding(slot_key)


func get_slot_action(slot_key: String) -> String:
	## Returns the InputMap action name for a slot key (e.g. "weapon_0" -> "slot_weapon_0").
	return "slot_" + slot_key


func get_default_binding(slot_key: String) -> Dictionary:
	## Returns the default key binding for a given slot key.
	## Sequential numbering: weapons 0-5 get keys 1-6, cores get 7-8, fields get 9-0.
	## Uses fixed offsets so it doesn't depend on GameState slot counts (which may not be set yet).
	var global_idx: int = -1
	if slot_key.begins_with("weapon_"):
		global_idx = int(slot_key.replace("weapon_", ""))  # 0-5 → keys 1-6
	elif slot_key.begins_with("core_"):
		global_idx = 6 + int(slot_key.replace("core_", ""))  # 6-7 → keys 7-8
	elif slot_key.begins_with("field_"):
		global_idx = 8 + int(slot_key.replace("field_", ""))  # 8-9 → keys 9-0
	elif slot_key.begins_with("particle_"):
		global_idx = 12 + int(slot_key.replace("particle_", ""))
	if global_idx >= 0 and global_idx < ALL_DEFAULT_KEYS.size():
		return ALL_DEFAULT_KEYS[global_idx]
	return {"physical_keycode": 0, "label": "?"}


func _build_default_bindings() -> Dictionary:
	## Build defaults for all possible slots — generous max counts.
	## Actual sequential key assignment happens in get_default_binding().
	var defaults: Dictionary = {}
	for i in 6:  # Up to 6 weapon slots
		var sk: String = "weapon_" + str(i)
		defaults[sk] = get_default_binding(sk)
	for i in 3:  # Up to 3 core slots
		var sk: String = "core_" + str(i)
		defaults[sk] = get_default_binding(sk)
	for i in 4:  # Up to 4 field slots
		var sk: String = "field_" + str(i)
		defaults[sk] = get_default_binding(sk)
	for i in 2:  # Up to 2 particle slots
		var sk: String = "particle_" + str(i)
		defaults[sk] = get_default_binding(sk)
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

	# Check binding version — skip saved key bindings if outdated (keep combo presets)
	var saved_version: int = int(data.get("bindings_version", 1))
	var skip_bindings: bool = saved_version < BINDINGS_VERSION

	# Load slot bindings — migrate old ext_/int_/dev_ keys to typed keys
	var saved_bindings: Dictionary = data.get("bindings", {}) as Dictionary if data.get("bindings") is Dictionary else {}
	if skip_bindings:
		saved_bindings = {}  # Discard old bindings — use fresh defaults
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
		"bindings_version": BINDINGS_VERSION,
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


func reassign_sequential_keys() -> void:
	## Reassign key bindings to sequential number keys for EQUIPPED slots only.
	## Skips empty slots so keys are contiguous (1-2-3 not 1-2-3-_-5).
	var slot_keys: Array[String] = []
	# Only include slots that have something equipped
	for i in GameState.get_weapon_slot_count():
		var sk: String = "weapon_" + str(i)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		if str(sd.get("weapon_id", "")) != "":
			slot_keys.append(sk)
	for i in GameState.get_core_slot_count():
		var sk: String = "core_" + str(i)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		if str(sd.get("device_id", "")) != "":
			slot_keys.append(sk)
	for i in GameState.get_field_slot_count():
		var sk: String = "field_" + str(i)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		if str(sd.get("device_id", "")) != "":
			slot_keys.append(sk)
	for i in GameState.get_particle_slot_count():
		var sk: String = "particle_" + str(i)
		var sd: Dictionary = GameState.slot_config.get(sk, {})
		if str(sd.get("device_id", "")) != "":
			slot_keys.append(sk)
	for i in slot_keys.size():
		if i < ALL_DEFAULT_KEYS.size():
			_bindings[slot_keys[i]] = ALL_DEFAULT_KEYS[i].duplicate()
	print("[KEYBIND] reassign: %d slots, weapons=%d cores=%d fields=%d" % [
		slot_keys.size(), GameState.get_weapon_slot_count(), GameState.get_core_slot_count(), GameState.get_field_slot_count()])
	for sk in slot_keys:
		print("[KEYBIND]   %s -> key %s" % [sk, str(_bindings[sk].get("label", "?"))])
	apply_to_input_map()


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


func get_slot_for_keycode(pkc: int) -> String:
	## Returns the slot_key bound to the given physical keycode, or "" if none.
	## Searches ALL bindings including phantom slots (e.g. core_1 when no ship has 2 cores).
	for slot_key in _bindings:
		var binding: Dictionary = _bindings[slot_key]
		if int(binding["physical_keycode"]) == pkc:
			return str(slot_key)
	return ""


func get_slot_for_keycode_filtered(pkc: int, valid_slots: Dictionary) -> String:
	## Returns the slot_key bound to the given physical keycode, only if it exists in valid_slots.
	## Use this to avoid phantom bindings (e.g. core_1) blocking real slot keys.
	for slot_key in _bindings:
		if not valid_slots.has(slot_key):
			continue
		var binding: Dictionary = _bindings[slot_key]
		if int(binding["physical_keycode"]) == pkc:
			return str(slot_key)
	return ""


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


func update_combo_preset_pattern(index: int, pattern: Dictionary) -> void:
	if index < 0 or index >= _combo_presets.size():
		return
	_combo_presets[index]["pattern"] = pattern
	_combo_presets[index]["label"] = generate_combo_label(pattern)
	save_bindings()


func generate_combo_label(pattern: Dictionary) -> String:
	var weapon_count: int = 0
	var core_count: int = 0
	var field_count: int = 0
	for slot_key in pattern:
		if not bool(pattern[slot_key]):
			continue
		if str(slot_key).begins_with("weapon_"):
			weapon_count += 1
		elif str(slot_key).begins_with("core_"):
			core_count += 1
		elif str(slot_key).begins_with("field_"):
			field_count += 1
	var parts: Array[String] = []
	if weapon_count > 0:
		parts.append(str(weapon_count) + "W")
	if core_count > 0:
		parts.append(str(core_count) + "C")
	if field_count > 0:
		parts.append(str(field_count) + "F")
	if parts.is_empty():
		return "EMPTY"
	return "+".join(parts)


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
