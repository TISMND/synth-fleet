class_name SfxConfig extends Resource
## Configuration for one-shot sound effects mapped to game events.

const EVENT_IDS: Array[String] = [
	"enemy_shield_hit",
	"enemy_hull_hit",
	"player_shield_hit",
	"player_hull_hit",
	"explosion_1",
	"explosion_2",
	"explosion_3",
	# Damage & Warning
	"electric_alarm",
	"heat_alarm",
	"fire_alarm",
	"shield_critical",
	"hull_critical",
	"power_failure",
	"monitor_shutoff",
	"monitor_static",
	"hull_damage_powerless",
	"reboot_char_thunk",
	"reboot_line_beep",
	"reboot_complete",
	"engine_sputter",
	"electric_sparks",
	"system_warning_beep",
	# Staged power-down cues (in sequence order)
	"powerdown_shields_bleed",
	"powerdown_engines_dying",
	"powerdown_drift_start",
	"powerdown_crt_flicker_start",
	"powerdown_screen_dying",
	"powerdown_final_death",
	# Staged power-up cues (recovery)
	"powerup_electric_restored",
	"powerup_screen_on",
	"powerup_systems_online",
]

const EVENT_LABELS: Dictionary = {
	"enemy_shield_hit": "ENEMY SHIELD HIT",
	"enemy_hull_hit": "ENEMY HULL HIT",
	"player_shield_hit": "PLAYER SHIELD HIT",
	"player_hull_hit": "PLAYER HULL HIT",
	"explosion_1": "EXPLOSION 1",
	"explosion_2": "EXPLOSION 2",
	"explosion_3": "EXPLOSION 3",
	# Damage & Warning
	"electric_alarm": "ELECTRIC ALARM",
	"heat_alarm": "HEAT ALARM",
	"fire_alarm": "FIRE ALARM",
	"shield_critical": "SHIELD CRITICAL",
	"hull_critical": "HULL CRITICAL",
	"power_failure": "POWER FAILURE",
	"monitor_shutoff": "MONITOR SHUT OFF",
	"monitor_static": "MONITOR STATIC",
	"hull_damage_powerless": "HULL HIT (POWERLESS)",
	"reboot_char_thunk": "REBOOT CHAR THUNK",
	"reboot_line_beep": "REBOOT LINE BEEP",
	"reboot_complete": "REBOOT COMPLETE",
	"engine_sputter": "ENGINE SPUTTER",
	"electric_sparks": "ELECTRIC SPARKS",
	"system_warning_beep": "SYSTEM WARNING BEEP",
	# Staged power-down cues
	"powerdown_shields_bleed": "1. SHIELDS BLEEDING",
	"powerdown_engines_dying": "2. ENGINES DYING",
	"powerdown_drift_start": "3. DRIFT BEGINS",
	"powerdown_crt_flicker_start": "4. CRT FLICKER START",
	"powerdown_screen_dying": "5. SCREEN DYING",
	"powerdown_final_death": "6. FINAL DEATH",
	# Staged power-up cues
	"powerup_electric_restored": "7. ELECTRIC RESTORED",
	"powerup_screen_on": "8. SCREEN POWERING ON",
	"powerup_systems_online": "9. SYSTEMS ONLINE",
}

var events: Dictionary = {}


static func _default_event() -> Dictionary:
	return {
		"file_path": "",
		"volume_db": 0.0,
		"clip_end_time": 0.0,
		"fade_out_duration": 0.0,
	}


func get_event(id: String) -> Dictionary:
	if events.has(id):
		return events[id]
	var defaults: Dictionary = _default_event()
	events[id] = defaults
	return defaults


static func from_dict(data: Dictionary) -> SfxConfig:
	var config := SfxConfig.new()
	var ev: Dictionary = data.get("events", {})
	for event_id in EVENT_IDS:
		if ev.has(event_id):
			var src: Dictionary = ev[event_id]
			config.events[event_id] = {
				"file_path": str(src.get("file_path", "")),
				"volume_db": float(src.get("volume_db", 0.0)),
				"clip_end_time": float(src.get("clip_end_time", 0.0)),
				"fade_out_duration": float(src.get("fade_out_duration", 0.0)),
			}
		else:
			config.events[event_id] = _default_event()
	return config


func to_dict() -> Dictionary:
	var ev := {}
	for event_id in EVENT_IDS:
		var e: Dictionary = get_event(event_id)
		ev[event_id] = {
			"file_path": e["file_path"],
			"volume_db": e["volume_db"],
			"clip_end_time": e["clip_end_time"],
			"fade_out_duration": e["fade_out_duration"],
		}
	return { "events": ev }
