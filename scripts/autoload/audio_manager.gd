extends Node
## Pooled audio playback. Weapons specify their own sample path and pitch.
## No hardcoded color-to-sample mapping.

const POOL_SIZE := 16

var _player_pool: Array[AudioStreamPlayer] = []
var _player_tweens: Array[Tween] = []  # One tween slot per player for fade control
var _next_player: int = 0


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_player_pool.append(player)
		_player_tweens.append(null)


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


func play_on_bus(sample: AudioStream, bus: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	## Play a sample on a specific bus (bypasses default SFX bus).
	if not sample:
		return
	var player: AudioStreamPlayer = _player_pool[_next_player]
	_kill_tween(_next_player)
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = sample
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = bus
	player.play()


func _play(sample: AudioStream, pitch: float, volume_db: float) -> void:
	var player: AudioStreamPlayer = _player_pool[_next_player]
	_kill_tween(_next_player)
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = sample
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = "SFX"  # Always reset to default bus
	player.play()


func play_sample_faded(sample: AudioStream, pitch: float, volume_db: float, fade_in_sec: float, fade_out_sec: float, clip_end_time: float = 0.0) -> void:
	if not sample:
		return
	_play_faded(sample, "SFX", pitch, volume_db, fade_in_sec, fade_out_sec, clip_end_time)


func play_on_bus_faded(sample: AudioStream, bus: String, pitch: float, volume_db: float, fade_in_sec: float, fade_out_sec: float, clip_end_time: float = 0.0) -> void:
	if not sample:
		return
	_play_faded(sample, bus, pitch, volume_db, fade_in_sec, fade_out_sec, clip_end_time)


func _play_faded(sample: AudioStream, bus: String, pitch: float, volume_db: float, fade_in_sec: float, fade_out_sec: float, clip_end_time: float) -> void:
	var slot: int = _next_player
	var player: AudioStreamPlayer = _player_pool[slot]
	_kill_tween(slot)
	_next_player = (slot + 1) % POOL_SIZE

	player.stream = sample
	player.pitch_scale = pitch
	player.bus = bus

	# Determine effective playback duration
	var stream_length: float = sample.get_length()
	var effective_end: float = clip_end_time if clip_end_time > 0.0 else stream_length

	var tween: Tween = create_tween()
	_player_tweens[slot] = tween

	if fade_in_sec > 0.0:
		player.volume_db = -80.0
		tween.tween_property(player, "volume_db", volume_db, fade_in_sec)
	else:
		player.volume_db = volume_db

	if fade_out_sec > 0.0 and effective_end > 0.0:
		var fade_start: float = maxf(effective_end - fade_out_sec, 0.0)
		if fade_in_sec > 0.0:
			# Wait after fade-in completes, then delay until fade-out start
			var delay: float = maxf(fade_start - fade_in_sec, 0.0)
			if delay > 0.0:
				tween.tween_interval(delay)
		else:
			if fade_start > 0.0:
				tween.tween_interval(fade_start)
		tween.tween_property(player, "volume_db", -80.0, fade_out_sec)

	player.play()


func _kill_tween(slot: int) -> void:
	var existing: Tween = _player_tweens[slot]
	if existing and existing.is_valid():
		existing.kill()
	_player_tweens[slot] = null
