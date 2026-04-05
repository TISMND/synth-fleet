class_name LevelData
extends Resource
## Defines a complete level — BPM, scroll speed, length, and encounter placements.

@export var id: String = ""
@export var verse_id: String = ""  # Which verse this level belongs to
@export var display_name: String = ""
@export var bpm: float = 110.0
@export var scroll_speed: float = 80.0
@export var level_length: float = 10000.0
@export var encounters: Array = []  # Array of encounter dicts
@export var background_shader: String = ""  # Path to mid-layer bg shader (empty = default grid)
@export var deep_background: String = ""  # Path to deep bg image (empty = star field only)
@export var doodads: Array = []  # Array of doodad placement dicts
@export var nebula_placements: Array = []  # Array of placement dicts
@export var bg_particles: Array = []  # Array of parallaxed particle layer dicts
@export var events: Array = []  # Array of event dicts (boss transitions, etc.)
@export var intro_tracks: Array = []  # Array of intro music track dicts (loop_path, start_bar, end_bar, fades, volume)
@export var intro_duration_bars: int = 8  # Total length of the intro timeline in bars


static func from_dict(data: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.id = data.get("id", "")
	l.verse_id = str(data.get("verse_id", ""))
	l.display_name = data.get("display_name", "")
	l.bpm = float(data.get("bpm", 110.0))
	l.scroll_speed = float(data.get("scroll_speed", 80.0))
	l.level_length = float(data.get("level_length", 10000.0))
	l.background_shader = str(data.get("background_shader", ""))
	l.deep_background = str(data.get("deep_background", ""))
	var raw_enc: Array = data.get("encounters", [])
	l.encounters = []
	l.events = []
	for enc in raw_enc:
		# Migrate boss_transition encounters to events array
		if str(enc.get("encounter_type", "")) == "boss_transition":
			l.events.append({
				"event_type": "boss_transition",
				"trigger_y": float(enc.get("trigger_y", 0.0)),
				"x_offset": float(enc.get("x_offset", 0.0)),
				"boss_id": str(enc.get("boss_id", "")),
				"key_shift_semitones": int(enc.get("key_shift_semitones", 0)),
				"bpm_shift": float(enc.get("bpm_shift", 0.0)),
			})
			continue
		l.encounters.append({
			"path_id": str(enc.get("path_id", "")),
			"formation_id": str(enc.get("formation_id", "")),
			"ship_id": str(enc.get("ship_id", "enemy_1")),
			"boss_id": str(enc.get("boss_id", "")),
			"speed": float(enc.get("speed", 200.0)),
			"count": int(enc.get("count", 1)),
			"spacing": float(enc.get("spacing", 200.0)),
			"trigger_y": float(enc.get("trigger_y", 0.0)),
			"x_offset": float(enc.get("x_offset", 0.0)),
			"rotate_with_path": bool(enc.get("rotate_with_path", false)),
			"is_melee": bool(enc.get("is_melee", false)),
			"turn_speed": float(enc.get("turn_speed", 90.0)),
			"weapons_active": bool(enc.get("weapons_active", true)),
			"mirror_h": bool(enc.get("mirror_h", false)),
			"mirror_v": bool(enc.get("mirror_v", false)),
			"drop_chance": float(enc.get("drop_chance", 0.0)),
			"drop_table": enc.get("drop_table", []),
		})
	var raw_doodads: Array = data.get("doodads", [])
	l.doodads = []
	for dd in raw_doodads:
		l.doodads.append({
			"type": str(dd.get("type", "water_tower")),
			"x": float(dd.get("x", 0.0)),
			"y": float(dd.get("y", 0.0)),
			"scale": float(dd.get("scale", 1.0)),
			"rotation_deg": float(dd.get("rotation_deg", 0.0)),
		})
	# Parse explicit events array (in addition to any migrated from encounters above)
	var raw_events: Array = data.get("events", [])
	for ev in raw_events:
		l.events.append({
			"event_type": str(ev.get("event_type", "boss_transition")),
			"trigger_y": float(ev.get("trigger_y", 0.0)),
			"x_offset": float(ev.get("x_offset", 0.0)),
			"boss_id": str(ev.get("boss_id", "")),
			"key_shift_semitones": int(ev.get("key_shift_semitones", 0)),
			"bpm_shift": float(ev.get("bpm_shift", 0.0)),
		})
	var raw_particles: Array = data.get("bg_particles", [])
	l.bg_particles = []
	for bp in raw_particles:
		l.bg_particles.append({
			"count": int(bp.get("count", 30)),
			"color_a": str(bp.get("color_a", "#1ae699")),
			"color_b": str(bp.get("color_b", "#cc33e6")),
			"size_min": float(bp.get("size_min", 2.0)),
			"size_max": float(bp.get("size_max", 6.0)),
			"pulse_speed": float(bp.get("pulse_speed", 1.2)),
			"motion_scale": float(bp.get("motion_scale", 0.35)),
			"z_index": int(bp.get("z_index", -9)),
		})
	l.intro_duration_bars = int(data.get("intro_duration_bars", 8))
	var raw_intro: Array = data.get("intro_tracks", [])
	l.intro_tracks = []
	for tr in raw_intro:
		l.intro_tracks.append({
			"loop_path": str(tr.get("loop_path", "")),
			"label": str(tr.get("label", "")),
			"start_bar": float(tr.get("start_bar", 0.0)),
			"end_bar": float(tr.get("end_bar", 4.0)),
			"fade_in_bars": float(tr.get("fade_in_bars", 0.0)),
			"fade_out_bars": float(tr.get("fade_out_bars", 1.0)),
			"volume_db": float(tr.get("volume_db", 0.0)),
		})
	var raw_neb: Array = data.get("nebula_placements", [])
	l.nebula_placements = []
	for neb in raw_neb:
		l.nebula_placements.append({
			"nebula_id": str(neb.get("nebula_id", "")),
			"trigger_y": float(neb.get("trigger_y", 0.0)),
			"x_offset": float(neb.get("x_offset", 0.0)),
			"radius": float(neb.get("radius", 300.0)),
			"seed_offset": float(neb.get("seed_offset", 0.0)),
		})
	return l


func to_dict() -> Dictionary:
	return {
		"id": id,
		"verse_id": verse_id,
		"display_name": display_name,
		"bpm": bpm,
		"scroll_speed": scroll_speed,
		"level_length": level_length,
		"background_shader": background_shader,
		"deep_background": deep_background,
		"encounters": encounters,
		"events": events,
		"doodads": doodads,
		"bg_particles": bg_particles,
		"nebula_placements": nebula_placements,
		"intro_tracks": intro_tracks,
		"intro_duration_bars": intro_duration_bars,
	}


func get_encounter(index: int) -> Dictionary:
	return encounters[index]
