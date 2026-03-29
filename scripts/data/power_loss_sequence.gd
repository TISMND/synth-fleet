class_name PowerLossSequence
extends RefCounted
## Single source of truth for power loss event timing, reboot text, and SFX cue mapping.
## Used by both player_ship.gd (game) and power_loss_timeline.gd (editor preview).

# ── Timing constants (moved from player_ship.gd) ────────────────────────────

const DRIFT_TO_BLACKOUT_DELAY: float = 1.0
const BLACKOUT_FADE_SPEED: float = 0.196  # Power drain per second (~5s from 1.0 to 0.02)

const RECOVERY_DURATION: float = 3.5
const RECOVERY_PITCH_DURATION: float = 5.0
const RECOVERY_PITCH_START: float = 0.7
const RECOVERY_VOLUME_START: float = 0.0

const REBOOT_BLINK_DURATION: float = 0.5
const REBOOT_BLINK_RATE: float = 0.5
const REBOOT_CHAR_SLOW: float = 0.04
const REBOOT_CHAR_FAST: float = 0.02
const REBOOT_LINE_PAUSE_SLOW: float = 0.3
const REBOOT_LINE_PAUSE_FAST: float = 0.1
const REBOOT_HEADER_PAUSE: float = 0.6
const REBOOT_PARAGRAPH_PAUSE: float = 0.5
const REBOOT_MAX_VISIBLE_LINES: int = 14

# ── Reboot text lines (moved from player_ship._start_reboot_sequence) ───────
# Lines prefixed with ">" enter the fast/scrolling reboot phase.

const REBOOT_TEXT_LINES: Array[String] = [
	"SYSTEM POWER FAILURE",
	"",
	"SUBSYSTEM DIAGNOSTIC",
	"Main reactor .......... OFFLINE",
	"Backup capacitor ...... 40%",
	"Shield generator ...... OFFLINE",
	"Weapon bus ............ NO SIGNAL",
	"",
	">CORE RESTART SEQUENCE",
	">Bypassing main reactor safety...",
	">Rerouting emergency power...",
	">Shield generator: STANDBY",
	">Weapon bus: LOCKED",
	">Thermal vents: PURGING",
	">Regenerating power core...",
	"",
	"SUCCESS",
]

# ── SFX cue display labels (moved from player_ship.SFX_CUE_DISPLAY) ─────────

const CUE_DISPLAY_LABELS: Dictionary = {
	"electric_sparks": "",
	"powerdown_shields_bleed": "",
	"powerdown_engines_dying": "ENGINE FAILURE",
	"powerdown_drift_start": "GYRO LOCK LOST",
	"power_failure": "CATASTROPHIC FAILURE",
	"powerdown_crt_flicker_start": "DISPLAY CORRUPTION",
	"powerdown_screen_75": "SIGNAL DEGRADING",
	"powerdown_screen_50": "SIGNAL CRITICAL",
	"powerdown_screen_25": "SIGNAL LOST",
	"monitor_static": "STATIC BURST",
	"monitor_shutoff": "DISPLAY OFFLINE",
	"powerdown_final_death": "TOTAL BLACKOUT",
	"powerup_electric_restored": "COLD START INITIATED",
	"powerup_bars_charging": "SUBSYSTEMS CHARGING",
	"powerup_core_regen": "CORE REGENERATING",
	"powerup_screen_on": "DISPLAY ONLINE",
	"powerup_systems_online": "SYSTEMS NOMINAL",
	"powerup_restored": "RESTORATION COMPLETE",
	"reboot_line_beep": "",
}

# ── Phase colors for timeline rendering ──────────────────────────────────────

const PHASE_COLORS: Dictionary = {
	"DRIFT": Color(1.0, 0.6, 0.1, 0.3),
	"BLACKOUT": Color(0.8, 0.15, 0.15, 0.3),
	"REBOOT": Color(0.2, 0.7, 0.3, 0.3),
	"RECOVERY": Color(0.3, 0.5, 1.0, 0.3),
}

# ── Computed helpers ─────────────────────────────────────────────────────────

static func _blackout_time_for_power(power_level: float) -> float:
	## Time from T=0 when blackout_power reaches the given level.
	## blackout_power starts at 1.0 at T=DRIFT_TO_BLACKOUT_DELAY and decreases at BLACKOUT_FADE_SPEED/sec.
	return DRIFT_TO_BLACKOUT_DELAY + (1.0 - power_level) / BLACKOUT_FADE_SPEED


static func _compute_reboot_timing() -> Dictionary:
	## Walk the reboot text lines using the same char/pause logic as player_ship._process_reboot_text.
	## Returns {duration: float, cues: Array[Dictionary], typing_regions: Array[Dictionary]}
	var time: float = REBOOT_BLINK_DURATION  # cursor blink phase
	var cues: Array[Dictionary] = []
	var typing_regions: Array[Dictionary] = []
	var scrolling: bool = false

	for i in REBOOT_TEXT_LINES.size():
		var raw_line: String = REBOOT_TEXT_LINES[i]

		# Check for fast scroll phase transition
		if raw_line.begins_with(">") and not scrolling:
			scrolling = true
			cues.append({"event_id": "powerup_electric_restored", "time": time, "phase": "REBOOT"})

		var display_line: String = raw_line.lstrip(">")

		# Empty line = paragraph pause
		if display_line == "":
			time += REBOOT_PARAGRAPH_PAUSE
			continue

		var char_speed: float = REBOOT_CHAR_FAST if scrolling else REBOOT_CHAR_SLOW

		# Fire line-start cues (at char_index == 0)
		if display_line == "Regenerating power core...":
			cues.append({"event_id": "powerup_core_regen", "time": time, "phase": "REBOOT"})
		elif display_line == "SUCCESS":
			cues.append({"event_id": "powerup_restored", "time": time, "phase": "REBOOT"})

		# Typing region starts here
		var typing_start: float = time
		var typing_duration: float = display_line.length() * char_speed
		time += typing_duration
		typing_regions.append({"start": typing_start, "end": time})

		# Line pause after typing completes
		var is_header: bool = display_line == display_line.to_upper() and display_line.length() > 2
		var pause: float = REBOOT_HEADER_PAUSE if is_header else (REBOOT_LINE_PAUSE_FAST if scrolling else REBOOT_LINE_PAUSE_SLOW)
		time += pause

		# reboot_line_beep fires at end of pause (when line advances)
		if scrolling:
			cues.append({"event_id": "reboot_line_beep", "time": time, "phase": "REBOOT"})

	return {"duration": time, "cues": cues, "typing_regions": typing_regions}


static func get_phases() -> Array[Dictionary]:
	## Returns phase bands with name, start_time, end_time, color.
	var death_time: float = _blackout_time_for_power(0.03)
	var reboot: Dictionary = _compute_reboot_timing()
	var reboot_end: float = death_time + reboot["duration"]
	return [
		{"name": "DRIFT", "start_time": 0.0, "end_time": DRIFT_TO_BLACKOUT_DELAY, "color": PHASE_COLORS["DRIFT"]},
		{"name": "BLACKOUT", "start_time": DRIFT_TO_BLACKOUT_DELAY, "end_time": death_time, "color": PHASE_COLORS["BLACKOUT"]},
		{"name": "REBOOT", "start_time": death_time, "end_time": reboot_end, "color": PHASE_COLORS["REBOOT"]},
		{"name": "RECOVERY", "start_time": reboot_end, "end_time": reboot_end + RECOVERY_DURATION, "color": PHASE_COLORS["RECOVERY"]},
	]


static func get_cues() -> Array[Dictionary]:
	## Returns all deterministic SFX cue points sorted by time.
	## Each entry: {event_id: String, time: float, phase: String, display_label: String}
	var death_time: float = _blackout_time_for_power(0.03)
	var reboot: Dictionary = _compute_reboot_timing()
	var reboot_end: float = death_time + reboot["duration"]

	var cues: Array[Dictionary] = []

	# Drift phase (T=0)
	cues.append({"event_id": "powerdown_drift_start", "time": 0.0, "phase": "DRIFT"})
	cues.append({"event_id": "powerdown_engines_dying", "time": 0.0, "phase": "DRIFT"})

	# Blackout phase
	cues.append({"event_id": "power_failure", "time": DRIFT_TO_BLACKOUT_DELAY, "phase": "BLACKOUT"})
	cues.append({"event_id": "powerdown_crt_flicker_start", "time": DRIFT_TO_BLACKOUT_DELAY, "phase": "BLACKOUT"})
	cues.append({"event_id": "powerdown_screen_75", "time": _blackout_time_for_power(0.75), "phase": "BLACKOUT"})
	cues.append({"event_id": "powerdown_screen_50", "time": _blackout_time_for_power(0.50), "phase": "BLACKOUT"})
	cues.append({"event_id": "powerdown_screen_25", "time": _blackout_time_for_power(0.25), "phase": "BLACKOUT"})
	cues.append({"event_id": "monitor_shutoff", "time": death_time, "phase": "BLACKOUT"})
	cues.append({"event_id": "powerdown_final_death", "time": death_time, "phase": "BLACKOUT"})

	# Reboot phase — cues from text walk, offset by death_time
	var reboot_cues: Array = reboot["cues"]
	for rc in reboot_cues:
		var d: Dictionary = rc as Dictionary
		cues.append({
			"event_id": str(d["event_id"]),
			"time": death_time + float(d["time"]),
			"phase": str(d["phase"]),
		})

	# Recovery phase — screen fade-in starts simultaneously with bars
	cues.append({"event_id": "powerup_bars_charging", "time": reboot_end, "phase": "RECOVERY"})
	cues.append({"event_id": "powerup_screen_on", "time": reboot_end, "phase": "RECOVERY"})
	cues.append({"event_id": "powerup_systems_online", "time": reboot_end + 0.9 * RECOVERY_DURATION, "phase": "RECOVERY"})

	# Add display labels
	for i in cues.size():
		var eid: String = str(cues[i]["event_id"])
		cues[i]["display_label"] = str(CUE_DISPLAY_LABELS.get(eid, ""))

	# Sort by time
	cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return cues


static func get_typing_regions() -> Array[Dictionary]:
	## Returns typing regions (for reboot_char_thunk looping sound) with absolute times.
	## Each entry: {start: float, end: float}
	var death_time: float = _blackout_time_for_power(0.03)
	var reboot: Dictionary = _compute_reboot_timing()
	var regions: Array[Dictionary] = []
	var raw_regions: Array = reboot["typing_regions"]
	for r in raw_regions:
		var d: Dictionary = r as Dictionary
		regions.append({"start": death_time + float(d["start"]), "end": death_time + float(d["end"])})
	return regions


static func get_static_burst_times() -> Array[float]:
	## Representative times for monitor_static during blackout (intermittent in game).
	## Returns ~3 evenly spaced times in the mid-blackout region.
	var blackout_start: float = DRIFT_TO_BLACKOUT_DELAY + 0.5
	var death_time: float = _blackout_time_for_power(0.03)
	var span: float = death_time - blackout_start - 0.5
	var times: Array[float] = []
	for i in 3:
		times.append(blackout_start + span * (float(i) + 0.5) / 3.0)
	return times


static func get_total_duration() -> float:
	var death_time: float = _blackout_time_for_power(0.03)
	var reboot: Dictionary = _compute_reboot_timing()
	return death_time + reboot["duration"] + RECOVERY_DURATION
