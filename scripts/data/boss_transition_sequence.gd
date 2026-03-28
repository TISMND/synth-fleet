class_name BossTransitionSequence
extends RefCounted
## Single source of truth for the boss transition event — timeline, text, phases, SFX cues.
## The boss's presence destabilizes the player's frequency lock. Music degrades, weapons go
## offline, the ship must remodulate to a new key/tempo before the fight begins.

# ── Phase timeline (seconds from T=0) ──────────────────────────────────────────

# Phase 1 — DISRUPTION: Music breaks down, enemies silenced, weapons deactivate
const WAVE_SWEEP: float = 0.0        # Energy wave visual sweeps top to bottom
const WAVE_HIT: float = 0.5          # Wave passes player — drift begins
const MUSIC_DEGRADE_START: float = 0.6  # Loops begin pitch-wobble + volume decay
const MUSIC_DEGRADE_END: float = 2.0    # All loops fully muted — silence
const WEAPONS_OFFLINE: float = 0.8      # Weapons deactivate (hardpoints locked)

# Phase 2 — SILENCE + overlapping cues (everything stacks tight)
const SILENCE_START: float = 2.0
const BOSS_MUSIC_BLEED: float = 2.1   # Boss weapon loops begin unmuting (quiet, ominous)
const WARNING_APPEAR: float = 2.3     # Warning box + boss name

# Phase 3 — DIAGNOSTIC: Typing sequence on screen — ship analyzes the disruption
const TYPING_START: float = 2.8       # First line of diagnostic text begins

# Phase 4 — REMODULATE: Ship locks onto new frequency
# (REMODULATE_TIME is computed from typing duration — see get_remodulate_time())

# Phase 5 — WEAPONS HOT: Player regains control
# (CONTROL_RESTORED and TRANSITION_END computed from remodulate time)

const CONTROL_RESTORE_DELAY: float = 1.0  # Seconds after typing finishes before control returns
const TRANSITION_END_DELAY: float = 1.8   # Seconds after typing finishes before overlay fades

# ── Typing ──────────────────────────────────────────────────────────────────────

const TYPEOUT_CHAR_SPEED: float = 0.018   # Seconds per character
const TYPEOUT_LINE_PAUSE: float = 0.15    # Pause between lines
const TYPEOUT_HEADER_PAUSE: float = 0.3   # Pause after ALL-CAPS headers
const TYPEOUT_PARAGRAPH_PAUSE: float = 0.25  # Pause on empty lines

# Lines prefixed ">" are in the fast phase (TYPEOUT_CHAR_FAST speed).
const TYPEOUT_CHAR_FAST: float = 0.008

const DIAGNOSTIC_LINES: Array[String] = [
	"FREQUENCY LOCK LOST",
	"",
	">Scanning for stable carrier...",
	">Carrier locked — shifting down 2 semitones",
	">Tempo sync: +10 BPM",
	">Weapons: ONLINE",
	"",
	"REMODULATION COMPLETE",
]

# ── SFX cue IDs ────────────────────────────────────────────────────────────────
# These map to events in SfxConfig — user assigns actual WAV files in the SFX editor.

const CUE_DISPLAY_LABELS: Dictionary = {
	"boss_wave_sweep": "DISRUPTION WAVE",
	"boss_wave_hit": "WAVE IMPACT",
	"boss_music_degrade": "FREQUENCY DESTABILIZING",
	"boss_silence": "SIGNAL LOST",
	"boss_music_bleed": "INCOMING SIGNAL",
	"boss_warning": "THREAT DETECTED",
	"boss_typing_thunk": "",  # Looping typing sound — no display label
	"boss_remodulate": "REMODULATING",
	"boss_weapons_online": "WEAPONS HOT",
	"boss_control_restored": "CONTROL RESTORED",
	"boss_transition_end": "TRANSITION COMPLETE",
}

# ── Computed helpers ────────────────────────────────────────────────────────────

static func _compute_typing_timing() -> Dictionary:
	## Walk DIAGNOSTIC_LINES to compute total duration, cues, and typing regions.
	## Returns {duration: float, cues: Array[Dictionary], typing_regions: Array[Dictionary]}
	var time: float = 0.0
	var cues: Array[Dictionary] = []
	var typing_regions: Array[Dictionary] = []
	var fast: bool = false

	for i in DIAGNOSTIC_LINES.size():
		var raw_line: String = DIAGNOSTIC_LINES[i]

		if raw_line.begins_with(">") and not fast:
			fast = true

		var display_line: String = raw_line.lstrip(">")

		# Empty line = paragraph pause
		if display_line == "":
			time += TYPEOUT_PARAGRAPH_PAUSE
			continue

		# Special cues at line start
		if display_line.begins_with("Carrier locked"):
			cues.append({"event_id": "boss_remodulate", "time": time, "phase": "REMODULATE"})
		elif display_line == "Weapons: ONLINE":
			cues.append({"event_id": "boss_weapons_online", "time": time, "phase": "REMODULATE"})
		elif display_line == "REMODULATION COMPLETE":
			cues.append({"event_id": "boss_control_restored", "time": time, "phase": "REMODULATE"})

		var char_speed: float = TYPEOUT_CHAR_FAST if fast else TYPEOUT_CHAR_SPEED
		var typing_start: float = time
		var typing_duration: float = display_line.length() * char_speed
		time += typing_duration
		typing_regions.append({"start": typing_start, "end": time})

		# Line pause
		var is_header: bool = display_line == display_line.to_upper() and display_line.length() > 2
		var pause: float = TYPEOUT_HEADER_PAUSE if is_header else TYPEOUT_LINE_PAUSE
		time += pause

	return {"duration": time, "cues": cues, "typing_regions": typing_regions}


static func get_remodulate_time() -> float:
	## Time (from TYPING_START) when the remodulate cue fires — i.e. the "Carrier locked" line.
	var typing: Dictionary = _compute_typing_timing()
	for cue in typing["cues"]:
		var d: Dictionary = cue as Dictionary
		if str(d["event_id"]) == "boss_remodulate":
			return TYPING_START + float(d["time"])
	# Fallback: 2 seconds before typing ends
	return TYPING_START + float(typing["duration"]) - 2.0


static func get_control_restored_time() -> float:
	return get_remodulate_time() + CONTROL_RESTORE_DELAY


static func get_transition_end_time() -> float:
	return get_remodulate_time() + TRANSITION_END_DELAY


static func get_total_duration() -> float:
	return get_transition_end_time()


static func get_typing_duration() -> float:
	return float(_compute_typing_timing()["duration"])


static func get_phases() -> Array[Dictionary]:
	var remod_time: float = get_remodulate_time()
	var end_time: float = get_transition_end_time()
	return [
		{"name": "DISRUPTION", "start_time": 0.0, "end_time": SILENCE_START, "color": Color(1.0, 0.3, 0.1, 0.3)},
		{"name": "SILENCE", "start_time": SILENCE_START, "end_time": TYPING_START, "color": Color(0.15, 0.1, 0.2, 0.3)},
		{"name": "DIAGNOSTIC", "start_time": TYPING_START, "end_time": remod_time, "color": Color(0.2, 0.7, 0.3, 0.3)},
		{"name": "REMODULATE", "start_time": remod_time, "end_time": end_time, "color": Color(0.3, 0.5, 1.0, 0.3)},
	]


static func get_cues() -> Array[Dictionary]:
	## Returns all SFX cue points sorted by time, with absolute timestamps.
	var cues: Array[Dictionary] = []

	# Disruption phase
	cues.append({"event_id": "boss_wave_sweep", "time": WAVE_SWEEP, "phase": "DISRUPTION"})
	cues.append({"event_id": "boss_wave_hit", "time": WAVE_HIT, "phase": "DISRUPTION"})
	cues.append({"event_id": "boss_music_degrade", "time": MUSIC_DEGRADE_START, "phase": "DISRUPTION"})
	cues.append({"event_id": "boss_silence", "time": MUSIC_DEGRADE_END, "phase": "DISRUPTION"})

	# Silence phase
	cues.append({"event_id": "boss_music_bleed", "time": BOSS_MUSIC_BLEED, "phase": "SILENCE"})
	cues.append({"event_id": "boss_warning", "time": WARNING_APPEAR, "phase": "SILENCE"})

	# Typing/remodulate cues (offset by TYPING_START)
	var typing: Dictionary = _compute_typing_timing()
	var typing_cues: Array = typing["cues"]
	for tc in typing_cues:
		var d: Dictionary = tc as Dictionary
		cues.append({
			"event_id": str(d["event_id"]),
			"time": TYPING_START + float(d["time"]),
			"phase": str(d["phase"]),
		})

	# End
	cues.append({"event_id": "boss_transition_end", "time": get_transition_end_time(), "phase": "REMODULATE"})

	# Add display labels
	for i in cues.size():
		var eid: String = str(cues[i]["event_id"])
		cues[i]["display_label"] = str(CUE_DISPLAY_LABELS.get(eid, ""))

	cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return cues


static func get_typing_regions() -> Array[Dictionary]:
	## Returns typing regions with absolute times (for typing sound looping).
	var typing: Dictionary = _compute_typing_timing()
	var regions: Array[Dictionary] = []
	var raw_regions: Array = typing["typing_regions"]
	for r in raw_regions:
		var d: Dictionary = r as Dictionary
		regions.append({"start": TYPING_START + float(d["start"]), "end": TYPING_START + float(d["end"])})
	return regions
