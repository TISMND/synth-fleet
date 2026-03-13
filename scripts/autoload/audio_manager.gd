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


func play_sample(sample: AudioStream, volume_db: float = 0.0) -> void:
	var player := _player_pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = sample
	player.volume_db = volume_db
	player.play()


func play_color(color_name: String, volume_db: float = 0.0) -> void:
	if color_name in color_sample_map:
		play_sample(color_sample_map[color_name], volume_db)


func load_color_samples(mapping: Dictionary) -> void:
	## mapping: { "cyan": "res://assets/audio/samples/cyan_pulse.wav", ... }
	color_sample_map.clear()
	for color_name in mapping:
		var sample := load(mapping[color_name]) as AudioStream
		if sample:
			color_sample_map[color_name] = sample
