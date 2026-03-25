class_name BossData extends Resource
## Boss composition — a core body + attached segments, each referencing enemy ShipData.

@export var id: String = ""
@export var display_name: String = ""
@export var level: String = "misc"

# Core body
@export var core_ship_id: String = ""             # References ShipData (type="enemy")
@export var core_weapon_overrides: Array = []     # [{hardpoint_index: int, weapon_id: String}]
@export var core_immune_until_segments_dead: bool = false  # Core takes no damage while any segment alive

# Segments — Array of Dictionaries (see _default_segment())
@export var segments: Array = []

# Enrage phase (2-phase: normal → enraged)
@export var enrage_threshold: float = 0.5          # 0.0–1.0, fraction of total HP remaining
@export var enrage_speed_mult: float = 1.5
@export var enrage_core_weapon_overrides: Array = []
@export var enrage_segment_weapon_overrides: Dictionary = {}  # seg_index (String) → Array of overrides
@export var enrage_core_render_mode: String = ""              # "" = no change
@export var enrage_segment_render_modes: Dictionary = {}      # seg_index (String) → render_mode


static func _default_segment() -> Dictionary:
	return {
		"ship_id": "",
		"offset": [0.0, 0.0],
		"weapon_overrides": [],
		"can_detach": false,
		"detach_path_id": "",
		"detach_speed": 200.0,
		"reattach": true,
		"detach_hp_threshold": 0.0,
	}


static func from_dict(data: Dictionary) -> BossData:
	var b := BossData.new()
	b.id = str(data.get("id", ""))
	b.display_name = str(data.get("display_name", ""))
	b.level = str(data.get("level", "misc"))

	# Core
	b.core_ship_id = str(data.get("core_ship_id", ""))
	var raw_core_overrides: Array = data.get("core_weapon_overrides", []) as Array
	b.core_weapon_overrides = []
	for entry in raw_core_overrides:
		var d: Dictionary = entry as Dictionary
		b.core_weapon_overrides.append({
			"hardpoint_index": int(d.get("hardpoint_index", 0)),
			"weapon_id": str(d.get("weapon_id", "")),
		})
	b.core_immune_until_segments_dead = bool(data.get("core_immune_until_segments_dead", false))

	# Segments
	var raw_segments: Array = data.get("segments", []) as Array
	b.segments = []
	for seg in raw_segments:
		var sd: Dictionary = seg as Dictionary
		var offset_arr: Array = sd.get("offset", [0.0, 0.0]) as Array
		var weapon_ovr: Array = sd.get("weapon_overrides", []) as Array
		var parsed_ovr: Array = []
		for wo in weapon_ovr:
			var wd: Dictionary = wo as Dictionary
			parsed_ovr.append({
				"hardpoint_index": int(wd.get("hardpoint_index", 0)),
				"weapon_id": str(wd.get("weapon_id", "")),
			})
		b.segments.append({
			"ship_id": str(sd.get("ship_id", "")),
			"offset": [float(offset_arr[0]) if offset_arr.size() > 0 else 0.0,
					   float(offset_arr[1]) if offset_arr.size() > 1 else 0.0],
			"weapon_overrides": parsed_ovr,
			"can_detach": bool(sd.get("can_detach", false)),
			"detach_path_id": str(sd.get("detach_path_id", "")),
			"detach_speed": float(sd.get("detach_speed", 200.0)),
			"reattach": bool(sd.get("reattach", true)),
			"detach_hp_threshold": float(sd.get("detach_hp_threshold", 0.0)),
		})

	# Enrage
	b.enrage_threshold = float(data.get("enrage_threshold", 0.5))
	b.enrage_speed_mult = float(data.get("enrage_speed_mult", 1.5))
	var raw_enrage_core: Array = data.get("enrage_core_weapon_overrides", []) as Array
	b.enrage_core_weapon_overrides = []
	for entry in raw_enrage_core:
		var d: Dictionary = entry as Dictionary
		b.enrage_core_weapon_overrides.append({
			"hardpoint_index": int(d.get("hardpoint_index", 0)),
			"weapon_id": str(d.get("weapon_id", "")),
		})
	var raw_enrage_seg: Dictionary = data.get("enrage_segment_weapon_overrides", {}) as Dictionary
	b.enrage_segment_weapon_overrides = {}
	for key in raw_enrage_seg:
		var arr: Array = raw_enrage_seg[key] as Array
		var parsed: Array = []
		for entry in arr:
			var d: Dictionary = entry as Dictionary
			parsed.append({
				"hardpoint_index": int(d.get("hardpoint_index", 0)),
				"weapon_id": str(d.get("weapon_id", "")),
			})
		b.enrage_segment_weapon_overrides[str(key)] = parsed
	b.enrage_core_render_mode = str(data.get("enrage_core_render_mode", ""))
	var raw_enrage_modes: Dictionary = data.get("enrage_segment_render_modes", {}) as Dictionary
	b.enrage_segment_render_modes = {}
	for key in raw_enrage_modes:
		b.enrage_segment_render_modes[str(key)] = str(raw_enrage_modes[key])

	return b


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"level": level,
		"core_ship_id": core_ship_id,
		"core_weapon_overrides": core_weapon_overrides,
		"core_immune_until_segments_dead": core_immune_until_segments_dead,
		"segments": segments,
		"enrage_threshold": enrage_threshold,
		"enrage_speed_mult": enrage_speed_mult,
		"enrage_core_weapon_overrides": enrage_core_weapon_overrides,
		"enrage_segment_weapon_overrides": enrage_segment_weapon_overrides,
		"enrage_core_render_mode": enrage_core_render_mode,
		"enrage_segment_render_modes": enrage_segment_render_modes,
	}
