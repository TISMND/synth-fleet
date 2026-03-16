extends Node
## LoopMixer — manages N AudioStreamPlayers, one per loop.
## All play from bar 1 simultaneously. Mute = volume_db = -80.0, unmute = restore volume.
## Never use stream_paused (causes desync).

signal loop_state_changed(loop_id: String, muted: bool)

var _loops: Dictionary = {}
# Each entry: {player: AudioStreamPlayer, target_volume: float, muted: bool}


func add_loop(loop_id: String, stream_path: String, bus: String = "Master", volume_db: float = 0.0, start_muted: bool = true) -> void:
	if _loops.has(loop_id):
		return
	var stream: AudioStream = load(stream_path) as AudioStream
	if not stream:
		push_warning("LoopMixer: failed to load stream: " + stream_path)
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# Compute sample frame count so loop_end covers the whole file
		var bytes_per_sample: int = 1
		if stream.format == AudioStreamWAV.FORMAT_16_BITS:
			bytes_per_sample = 2
		elif stream.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			bytes_per_sample = 4
		var channels: int = 2 if stream.stereo else 1
		stream.loop_end = stream.data.size() / (bytes_per_sample * channels)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = -80.0 if start_muted else volume_db
	add_child(player)
	_loops[loop_id] = {
		"player": player,
		"target_volume": volume_db,
		"muted": start_muted,
	}


func remove_loop(loop_id: String) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	var player: AudioStreamPlayer = entry["player"]
	player.stop()
	player.queue_free()
	_loops.erase(loop_id)


func remove_all_loops() -> void:
	for loop_id in _loops.keys():
		remove_loop(loop_id)


func mute(loop_id: String) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	entry["muted"] = true
	var player: AudioStreamPlayer = entry["player"]
	player.volume_db = -80.0
	loop_state_changed.emit(loop_id, true)


func unmute(loop_id: String) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	entry["muted"] = false
	var player: AudioStreamPlayer = entry["player"]
	player.volume_db = float(entry["target_volume"])
	loop_state_changed.emit(loop_id, false)


func is_muted(loop_id: String) -> bool:
	if not _loops.has(loop_id):
		return true
	var entry: Dictionary = _loops[loop_id]
	return entry["muted"] as bool


func start_all() -> void:
	for loop_id in _loops:
		var entry: Dictionary = _loops[loop_id]
		var player: AudioStreamPlayer = entry["player"]
		player.play(0.0)


func has_loop(loop_id: String) -> bool:
	return _loops.has(loop_id)


func get_playback_position(loop_id: String) -> float:
	## Returns the player's actual playback position in seconds, or -1.0 if not found/playing.
	if not _loops.has(loop_id):
		return -1.0
	var entry: Dictionary = _loops[loop_id]
	var player: AudioStreamPlayer = entry["player"]
	if not player.playing:
		return -1.0
	return player.get_playback_position()
