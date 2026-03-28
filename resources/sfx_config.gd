class_name SfxConfig extends Resource
## Configuration for one-shot sound effects mapped to game events.

const EVENT_IDS: Array[String] = [
	"enemy_shield_hit",
	"enemy_hull_hit",
	"player_shield_hit",
	"player_hull_hit",
	"immune_hit",
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
	# Thermal purge cues (4 stages)
	"purge_start",
	"purge_venting",
	"purge_complete",
	"purge_engines_restored",
	# Boss transition cues
	"boss_wave_sweep",
	"boss_wave_hit",
	"boss_music_degrade",
	"boss_silence",
	"boss_music_bleed",
	"boss_warning",
	"boss_typing_thunk",
	"boss_remodulate",
	"boss_weapons_online",
	"boss_control_restored",
	"boss_transition_end",
	# Nebula alarm cues — selectable per-nebula warning sound
	"nebula_alarm_1",
	"nebula_alarm_2",
	"nebula_alarm_3",
	"nebula_alarm_4",
	"nebula_alarm_5",
]

const EVENT_LABELS: Dictionary = {
	"enemy_shield_hit": "ENEMY SHIELD HIT",
	"enemy_hull_hit": "ENEMY HULL HIT",
	"player_shield_hit": "PLAYER SHIELD HIT",
	"player_hull_hit": "PLAYER HULL HIT",
	"immune_hit": "IMMUNE HIT",
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
	# Thermal purge cues
	"purge_start": "1. PURGE START",
	"purge_venting": "2. VENTING (50%)",
	"purge_complete": "3. PURGE COMPLETE",
	"purge_engines_restored": "4. ENGINES RESTORED",
	# Boss transition cues
	"boss_wave_sweep": "BOSS WAVE SWEEP",
	"boss_wave_hit": "BOSS WAVE HIT",
	"boss_music_degrade": "BOSS MUSIC DEGRADE",
	"boss_silence": "BOSS SILENCE",
	"boss_music_bleed": "BOSS MUSIC BLEED",
	"boss_warning": "BOSS WARNING",
	"boss_typing_thunk": "BOSS TYPING THUNK",
	"boss_remodulate": "BOSS REMODULATE",
	"boss_weapons_online": "BOSS WEAPONS ONLINE",
	"boss_control_restored": "BOSS CONTROL RESTORED",
	"boss_transition_end": "BOSS TRANSITION END",
	# Nebula alarms
	"nebula_alarm_1": "NEBULA ALARM 1",
	"nebula_alarm_2": "NEBULA ALARM 2",
	"nebula_alarm_3": "NEBULA ALARM 3",
	"nebula_alarm_4": "NEBULA ALARM 4",
	"nebula_alarm_5": "NEBULA ALARM 5",
}

const EVENT_DESCRIPTIONS: Dictionary = {
	# Hit Sounds
	"enemy_shield_hit": "Player projectile hits an enemy's shield layer",
	"enemy_hull_hit": "Player projectile hits an enemy's hull (no shield remaining)",
	"player_shield_hit": "Enemy projectile or contact hits the player's shield",
	"player_hull_hit": "Enemy projectile or contact hits the player's hull directly",
	"immune_hit": "Projectile hits an immune/invulnerable enemy — deflect feedback",
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
	# Thermal Purge (V key — emergency heat vent)
	"purge_start": "Purge initiated — vents open, hiss/whoosh as emergency cooling begins",
	"purge_venting": "Midpoint — thermal at 50%, active venting sound, steam/gas release",
	"purge_complete": "Thermal cleared — vents close, mechanical clunk, components reactivate",
	"purge_engines_restored": "Engines back to full power — thrust ramp-up, speed restored",
	# Boss transition cues
	"boss_wave_sweep": "Disruption wave sweeps top to bottom — boss presence felt",
	"boss_wave_hit": "Wave passes through player — drift starts, music destabilizes",
	"boss_music_degrade": "Music pitch-wobbles and decays — frequency lock breaking",
	"boss_silence": "All loops fully dead — eerie silence",
	"boss_music_bleed": "Boss weapon loops bleed in quietly — ominous incoming signal",
	"boss_warning": "Warning box appears with boss name — threat identified",
	"boss_typing_thunk": "Looping per-character thunk during diagnostic typing",
	"boss_remodulate": "Ship locks new carrier frequency — key/tempo shift applied",
	"boss_weapons_online": "Weapon bus reconnected — hardpoints hot",
	"boss_control_restored": "Player regains full control — drift ends",
	"boss_transition_end": "Transition overlay fades — boss fight begins",
	# Nebula alarms
	"nebula_alarm_1": "Nebula warning alarm slot 1 — selectable per-nebula in environments editor",
	"nebula_alarm_2": "Nebula warning alarm slot 2 — selectable per-nebula in environments editor",
	"nebula_alarm_3": "Nebula warning alarm slot 3 — selectable per-nebula in environments editor",
	"nebula_alarm_4": "Nebula warning alarm slot 4 — selectable per-nebula in environments editor",
	"nebula_alarm_5": "Nebula warning alarm slot 5 — selectable per-nebula in environments editor",
}

var events: Dictionary = {}


static func _default_event() -> Dictionary:
	return {
		"file_path": "",
		"volume_db": 0.0,
		"clip_end_time": 0.0,
		"fade_in_duration": 0.0,
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
				"fade_in_duration": float(src.get("fade_in_duration", 0.0)),
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
			"fade_in_duration": e["fade_in_duration"],
			"fade_out_duration": e["fade_out_duration"],
		}
	return { "events": ev }
