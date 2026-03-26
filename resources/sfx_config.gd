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
	# Warning alarms — loop while condition is active, stop when cleared
	"alarm_heat",
	"alarm_fire",
	"alarm_low_power",
	"alarm_overdraw",
	"alarm_shields_low",
	"alarm_hull_damaged",
	"alarm_hull_critical",
	# Staged power-down cues (in sequence order)
	"powerdown_shields_bleed",
	"powerdown_engines_dying",
	"powerdown_drift_start",
	"powerdown_crt_flicker_start",
	"powerdown_screen_75",
	"powerdown_screen_50",
	"powerdown_screen_25",
	"powerdown_final_death",
	# Staged power-up cues (recovery)
	"powerup_electric_restored",
	"powerup_bars_charging",
	"powerup_core_regen",
	"powerup_screen_on",
	"powerup_systems_online",
	"powerup_restored",
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
	# Warning alarms
	"alarm_heat": "ALARM: HEAT",
	"alarm_fire": "ALARM: FIRE",
	"alarm_low_power": "ALARM: LOW POWER",
	"alarm_overdraw": "ALARM: OVERDRAW",
	"alarm_shields_low": "ALARM: SHIELDS LOW",
	"alarm_hull_damaged": "ALARM: HULL DAMAGED",
	"alarm_hull_critical": "ALARM: HULL CRITICAL",
	# Staged power-down cues
	"powerdown_shields_bleed": "1. SHIELDS BLEEDING",
	"powerdown_engines_dying": "2. ENGINES DYING",
	"powerdown_drift_start": "3. DRIFT BEGINS",
	"powerdown_crt_flicker_start": "4. CRT FLICKER START",
	"powerdown_screen_75": "5a. SCREEN 75%",
	"powerdown_screen_50": "5b. SCREEN 50%",
	"powerdown_screen_25": "5c. SCREEN 25%",
	"powerdown_final_death": "6. FINAL DEATH",
	# Staged power-up cues
	"powerup_electric_restored": "7. COLD START",
	"powerup_bars_charging": "7b. SUBSYSTEMS CHARGING",
	"powerup_core_regen": "7c. CORE REGENERATING",
	"powerup_screen_on": "8. DISPLAY ONLINE",
	"powerup_systems_online": "9. SYSTEMS ONLINE",
	"powerup_restored": "10. FULL RESTORATION",
}

const EVENT_DESCRIPTIONS: Dictionary = {
	# Hit Sounds
	"enemy_shield_hit": "Player projectile hits an enemy's shield layer",
	"enemy_hull_hit": "Player projectile hits an enemy's hull (no shield remaining)",
	"player_shield_hit": "Enemy projectile or contact hits the player's shield",
	"player_hull_hit": "Enemy projectile or contact hits the player's hull directly",
	# Explosions
	"explosion_1": "Small enemy death explosion (drones, small ships)",
	"explosion_2": "Medium enemy death explosion (standard enemies)",
	"explosion_3": "Large enemy death explosion (captains, bosses)",
	# Alarms & Warnings
	"electric_alarm": "Electric bar critically low — arcing/sparking danger",
	"heat_alarm": "Thermal bar critically high — approaching overheat",
	"fire_alarm": "Generic fire/danger alarm (not currently wired)",
	"shield_critical": "Shield bar nearly depleted",
	"hull_critical": "Hull bar nearly depleted — ship close to destruction",
	"system_warning_beep": "General-purpose warning beep for HUD alerts",
	# Warning alarms — loop while condition is active
	"alarm_heat": "Loops while thermal > 90% — rising heat warning",
	"alarm_fire": "Loops while thermal overflow is damaging hull — urgent fire alert",
	"alarm_low_power": "Loops while electric < 10% — low energy warning",
	"alarm_overdraw": "Loops while electric is pulling from shields/engines — critical power drain",
	"alarm_shields_low": "Loops while shields < 10% — shield depletion warning",
	"alarm_hull_damaged": "Plays briefly when hull takes a hit — impact alert",
	"alarm_hull_critical": "Loops while hull < 15% — imminent destruction warning",
	# Power Failure (the moment systems go dark)
	"power_failure": "The instant all power cuts — main power-out sound",
	"monitor_shutoff": "CRT display switching off with a click/thud",
	"monitor_static": "Brief burst of static as the display dies",
	"electric_sparks": "Sparking sounds from failing electrical systems",
	"engine_sputter": "Engines choking and dying, thrust cutting out",
	"hull_damage_powerless": "Taking a hit while power is out — dull metallic impact, no shields",
	# Reboot Sequence (CRT terminal reboot after power recovery)
	"reboot_char_thunk": "Each character appearing on the reboot terminal — mechanical typewriter tick",
	"reboot_line_beep": "End-of-line beep as each diagnostic line completes",
	"reboot_complete": "Final confirmation sound — all systems restored",
	# Power-Down Sequence (gradual failure, events fire in numbered order)
	"powerdown_shields_bleed": "Step 1: Shields start draining passively — energy bleeding away",
	"powerdown_engines_dying": "Step 2: Engines losing power — ship starts slowing",
	"powerdown_drift_start": "Step 3: Ship begins uncontrolled drift — player loses steering",
	"powerdown_crt_flicker_start": "Step 4: CRT overlay starts flickering — visual distortion begins",
	"powerdown_screen_75": "Step 5a: Display degraded to 75% — screen dimming",
	"powerdown_screen_50": "Step 5b: Display degraded to 50% — heavy static",
	"powerdown_screen_25": "Step 5c: Display degraded to 25% — barely visible",
	"powerdown_final_death": "Step 6: Total blackout — screen goes dark, all systems dead",
	# Power-Up Sequence (recovery after power restored, events fire in numbered order)
	"powerup_electric_restored": "Step 7: First spark of power — cold start initiated",
	"powerup_core_regen": "Step 7c: Power core begins regenerating energy",
	"powerup_bars_charging": "Step 7b: System bars (shield/hull/thermal) start refilling",
	"powerup_screen_on": "Step 8: CRT display powers back on — screen flickers to life",
	"powerup_systems_online": "Step 9: Weapons and navigation systems come back online",
	"powerup_restored": "Step 10: Full restoration — ship back to normal operation",
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
