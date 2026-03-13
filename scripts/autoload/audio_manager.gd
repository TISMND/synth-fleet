extends Node
## Pooled audio playback. Weapons specify their own sample path and pitch.
## No hardcoded color-to-sample mapping.

const POOL_SIZE := 16

var _player_pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_player_pool.append(player)


func play_weapon_sound(sample_path: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if sample_path == "":
		return
	var sample: AudioStream = load(sample_path) as AudioStream
	if not sample:
		return
	_play(sample, pitch, volume_db)


func play_sample(sample: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not sample:
		return
	_play(sample, pitch, volume_db)


func _play(sample: AudioStream, pitch: float, volume_db: float) -> void:
	var player: AudioStreamPlayer = _player_pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = sample
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
