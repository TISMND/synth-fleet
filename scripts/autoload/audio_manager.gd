extends Node
## Manages a pool of AudioStreamPlayer nodes for weapon/SFX playback.
## Quantizes sound playback to BeatClock beats.

const POOL_SIZE := 16

var _player_pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0

# Color → audio sample mapping. Populated when level loads samples.
var color_sample_map: Dictionary = {}


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_player_pool.append(player)
	_load_default_samples()


func _load_default_samples() -> void:
	var base := "res://assets/audio/samples/"
	var defaults := {
		"cyan": base + "017_SEPH_-_Synth_Hit_C3.wav",
		"magenta": base + "011_Synth_Hit_145bpm_A#_-_DOOFPSY_Zenhiser.wav",
		"yellow": base + "049_Synth_Hit_E_-_CATALYST_Zenhiser.wav",
		"green": base + "04_FPH_Synth_Hit_C.wav",
		"orange": base + "030_Synth_Hit_C_-_TECHNOLOGY_Zenhiser.wav",
		"red": base + "141_Synth_Hit_G_-_PSYONESHOTS_Zenhiser.wav",
		"blue": base + "054_SEB_-_Synth_Hit_C3.wav",
		"white": base + "ESM_Notification_3_or_Victory_Hit_Simulation_Notification_Synth_Electronic_Particle_Cute_Cartoon.wav",
	}
	load_color_samples(defaults)


func play_sample(sample: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := _player_pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = sample
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_color(color_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if color_name in color_sample_map:
		play_sample(color_sample_map[color_name], volume_db, pitch_scale)


func load_color_samples(mapping: Dictionary) -> void:
	## mapping: { "cyan": "res://assets/audio/samples/cyan_pulse.wav", ... }
	color_sample_map.clear()
	for color_name in mapping:
		var sample := load(mapping[color_name]) as AudioStream
		if sample:
			color_sample_map[color_name] = sample
