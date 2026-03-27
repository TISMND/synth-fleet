extends Node
## AudioBusSetup — ensures audio buses exist and loads saved volume settings at startup.
## Must be an autoload so settings apply before any scene plays audio.
##
## Bus structure:
##   Master (final output — never put game effects here)
##   ├── GameAudio → Master (all in-game sound; blackout effects go here)
##   │   ├── Weapons    → GameAudio (weapon loops from LoopMixer)
##   │   ├── SFX        → GameAudio (one-shot game SFX: hits, explosions)
##   │   ├── Enemies    → GameAudio (enemy sounds)
##   │   └── Atmosphere → GameAudio (ambient loops)
##   └── UI → Master (menus, reboot typing, monitor sounds — always clean)

const SETTINGS_PATH := "user://settings/audio.json"

## GameAudio is the parent bus for all in-game sound. Blackout effects go here.
const GAME_AUDIO_BUS := "GameAudio"

## Game sub-buses route through GameAudio.
const GAME_SUB_BUSES: Array[String] = ["Weapons", "SFX", "Enemies", "Atmosphere"]

## UI bus routes directly to Master, bypassing GameAudio entirely.
const UI_BUS := "UI"

## When true, enemy weapon loops keep playing after death/despawn (layered music).
## When false, loops fade out on death (default).
var persist_enemy_audio: bool = false


func _ready() -> void:
	_ensure_buses()
	_load_volumes()


## Buses that get an AudioEffectPitchShift (for nebula key-change etc.)
## Pitch shift goes on GameAudio so it affects all game sound uniformly.
const PITCH_SHIFT_BUSES: Array[String] = ["GameAudio"]


func _ensure_buses() -> void:
	# Create GameAudio bus (sends to Master)
	if AudioServer.get_bus_index(GAME_AUDIO_BUS) == -1:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, GAME_AUDIO_BUS)
		AudioServer.set_bus_send(idx, "Master")

	# Create game sub-buses (send to GameAudio)
	for bus_name in GAME_SUB_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, GAME_AUDIO_BUS)

	# Create UI bus (sends to Master, NOT GameAudio)
	if AudioServer.get_bus_index(UI_BUS) == -1:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, UI_BUS)
	AudioServer.set_bus_send(AudioServer.get_bus_index(UI_BUS), "Master")

	# Add pitch-shift effects to designated buses (disabled by default)
	for bus_name in PITCH_SHIFT_BUSES:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		if bus_idx < 0:
			continue
		var already_has: bool = false
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectPitchShift:
				already_has = true
				break
		if not already_has:
			var fx := AudioEffectPitchShift.new()
			fx.pitch_scale = 1.0
			AudioServer.add_bus_effect(bus_idx, fx)
			AudioServer.set_bus_effect_enabled(bus_idx, AudioServer.get_bus_effect_count(bus_idx) - 1, false)


func _load_volumes() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return
	var data: Dictionary = json.data
	persist_enemy_audio = bool(data.get("persist_enemy_audio", false))
	for bus_name_key in data:
		var bus_idx: int = AudioServer.get_bus_index(str(bus_name_key))
		if bus_idx < 0:
			continue
		var val: float = float(data.get(bus_name_key, 100.0))
		var linear: float = val / 100.0
		if linear <= 0.0:
			AudioServer.set_bus_volume_db(bus_idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
