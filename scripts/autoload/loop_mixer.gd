extends Node
## LoopMixer — manages N AudioStreamPlayers, one per loop.
## All play from bar 1 simultaneously. Mute = volume_db = MUTE_DB, unmute = restore volume.
## Never use stream_paused (causes desync).

signal loop_state_changed(loop_id: String, muted: bool)

const MUTE_DB := -80.0

var _loops: Dictionary = {}
# Each entry: {player: AudioStreamPlayer, target_volume: float, muted: bool, duration: float}

var _durations_by_path: Dictionary = {}
# Maps stream_path -> duration_sec (pre-mutation, clean values for EffectRateCalculator)

var _ref_counts: Dictionary = {}
# Per loop_id: how many owners hold a reference (for shared enemy weapon loops)

var _active_tweens: Dictionary = {}
# Per loop_id: active Tween for fade transitions (cancelled when a new fade starts)


func add_loop(loop_id: String, stream_path: String, bus: String = "Weapons", volume_db: float = 0.0, start_muted: bool = true) -> void:
	if _loops.has(loop_id):
		# Bump ref count for shared loops (e.g. multiple enemies with same weapon)
		_ref_counts[loop_id] = int(_ref_counts.get(loop_id, 1)) + 1
		return
	# Apply base volume from LoopConfigManager (additive with caller's volume_db)
	var base_vol: float = LoopConfigManager.get_volume(stream_path)
	volume_db += base_vol
	var stream: AudioStream = load(stream_path) as AudioStream
	if not stream:
		push_warning("LoopMixer: failed to load stream: " + stream_path)
		return
	var duration_sec: float = 0.0
	if stream is AudioStreamWAV:
		# Get duration BEFORE enabling looping (get_length() may return 0 for looping streams)
		duration_sec = stream.get_length()

		# Enable looping
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0

		# Derive loop_end from duration — format-independent, matches get_length()
		if duration_sec > 0.0:
			stream.loop_end = int(duration_sec * float(stream.mix_rate))
		else:
			# Fallback: byte math if get_length() returned 0
			var bytes_per_sample: int = 1
			if stream.format == AudioStreamWAV.FORMAT_16_BITS:
				bytes_per_sample = 2
			var channels: int = 2 if stream.stereo else 1
			duration_sec = float(stream.data.size() / (bytes_per_sample * channels)) / float(stream.mix_rate)
			stream.loop_end = int(duration_sec * float(stream.mix_rate))
		print("LoopMixer: \"%s\" duration=%.3fs loop_end=%d mix_rate=%d data_bytes=%d" % [loop_id, duration_sec, stream.loop_end, stream.mix_rate, stream.data.size()])
	else:
		duration_sec = stream.get_length()
	# Cache clean duration by path for EffectRateCalculator
	_durations_by_path[stream_path] = duration_sec
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = MUTE_DB if start_muted else volume_db
	add_child(player)
	_loops[loop_id] = {
		"player": player,
		"target_volume": volume_db,
		"muted": start_muted,
		"duration": duration_sec,
	}
	_ref_counts[loop_id] = 1


func release_loop(loop_id: String, fade_ms: int = 0) -> void:
	## Decrement ref count. When it hits 0, fade out (if requested) then remove.
	## Use this instead of remove_loop when loops may be shared (e.g. enemy weapons).
	if not _loops.has(loop_id):
		return
	var count: int = int(_ref_counts.get(loop_id, 1)) - 1
	if count > 0:
		_ref_counts[loop_id] = count
		return
	_ref_counts.erase(loop_id)
	if fade_ms > 0:
		# Fade to silence, then remove
		var entry: Dictionary = _loops[loop_id]
		var player: AudioStreamPlayer = entry["player"]
		_cancel_fade(loop_id)
		var duration_sec: float = float(fade_ms) / 1000.0
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(player, "volume_db", MUTE_DB, duration_sec)
		_active_tweens[loop_id] = tween
		tween.finished.connect(func() -> void:
			_active_tweens.erase(loop_id)
			_force_remove_loop(loop_id)
		)
	else:
		_force_remove_loop(loop_id)


func _force_remove_loop(loop_id: String) -> void:
	if not _loops.has(loop_id):
		return
	_cancel_fade(loop_id)
	var entry: Dictionary = _loops[loop_id]
	var player: AudioStreamPlayer = entry["player"]
	player.stop()
	player.queue_free()
	_loops.erase(loop_id)
	_ref_counts.erase(loop_id)


func remove_loop(loop_id: String) -> void:
	## Force-remove regardless of ref count. Use release_loop() for shared loops.
	_ref_counts.erase(loop_id)
	_force_remove_loop(loop_id)


func remove_all_loops() -> void:
	for loop_id in _loops.keys():
		remove_loop(loop_id)


func mute(loop_id: String, fade_ms: int = 0) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	entry["muted"] = true
	var player: AudioStreamPlayer = entry["player"]
	_cancel_fade(loop_id)
	if fade_ms > 0:
		var duration_sec: float = float(fade_ms) / 1000.0
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(player, "volume_db", MUTE_DB, duration_sec)
		_active_tweens[loop_id] = tween
		tween.finished.connect(func() -> void:
			_active_tweens.erase(loop_id)
		)
	else:
		player.volume_db = MUTE_DB
	loop_state_changed.emit(loop_id, true)


func unmute(loop_id: String, fade_ms: int = 0) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	entry["muted"] = false
	var target_vol: float = float(entry["target_volume"])
	var player: AudioStreamPlayer = entry["player"]
	_cancel_fade(loop_id)
	if fade_ms > 0:
		var duration_sec: float = float(fade_ms) / 1000.0
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(player, "volume_db", target_vol, duration_sec)
		_active_tweens[loop_id] = tween
		tween.finished.connect(func() -> void:
			_active_tweens.erase(loop_id)
		)
	else:
		player.volume_db = target_vol
	loop_state_changed.emit(loop_id, false)


func _cancel_fade(loop_id: String) -> void:
	if _active_tweens.has(loop_id):
		var tween: Tween = _active_tweens[loop_id]
		if tween and tween.is_valid():
			tween.kill()
		_active_tweens.erase(loop_id)


func set_volume(loop_id: String, volume_db: float) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	entry["target_volume"] = volume_db
	if not entry["muted"] as bool:
		var player: AudioStreamPlayer = entry["player"]
		player.volume_db = volume_db


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


func start_loop(loop_id: String) -> void:
	## Start a single loop, synced to any already-playing loop's position.
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	var player: AudioStreamPlayer = entry["player"]
	# Find current position from any playing loop to sync
	var sync_pos: float = 0.0
	for other_id in _loops:
		if other_id == loop_id:
			continue
		var other: Dictionary = _loops[other_id]
		var other_player: AudioStreamPlayer = other["player"]
		if other_player.playing:
			sync_pos = other_player.get_playback_position()
			break
	player.play(sync_pos)


func stop_all() -> void:
	for loop_id in _loops:
		var entry: Dictionary = _loops[loop_id]
		var player: AudioStreamPlayer = entry["player"]
		player.stop()


func is_playing() -> bool:
	for loop_id in _loops:
		var entry: Dictionary = _loops[loop_id]
		var player: AudioStreamPlayer = entry["player"]
		if player.playing:
			return true
	return false


func mute_all(fade_ms: int = 0) -> void:
	for loop_id in _loops:
		mute(loop_id, fade_ms)


func unmute_all(fade_ms: int = 0) -> void:
	for loop_id in _loops:
		unmute(loop_id, fade_ms)


func has_loop(loop_id: String) -> bool:
	return _loops.has(loop_id)


func set_all_pitch_scale(scale: float) -> void:
	## Set pitch_scale on ALL loop players. Changes both pitch AND speed together.
	## 0.5 = half speed, one octave down. 1.0 = normal. 2.0 = double speed, one octave up.
	for loop_id in _loops:
		var entry: Dictionary = _loops[loop_id]
		var player: AudioStreamPlayer = entry["player"]
		player.pitch_scale = scale


func set_all_volume_offset(offset_db: float) -> void:
	## Apply a volume offset to ALL loop players (additive to their target volume).
	## Use negative values to quiet them. 0.0 = no offset (restore normal).
	for loop_id in _loops:
		var entry: Dictionary = _loops[loop_id]
		var player: AudioStreamPlayer = entry["player"]
		var target: float = float(entry["target_volume"])
		if bool(entry["muted"]):
			continue  # Don't unmute muted loops
		player.volume_db = target + offset_db


func get_playback_position(loop_id: String) -> float:
	## Returns the player's actual playback position in seconds, or -1.0 if not found/playing.
	if not _loops.has(loop_id):
		return -1.0
	var entry: Dictionary = _loops[loop_id]
	var player: AudioStreamPlayer = entry["player"]
	if not player.playing:
		return -1.0
	return player.get_playback_position()


func seek(loop_id: String, position_sec: float) -> void:
	if not _loops.has(loop_id):
		return
	var entry: Dictionary = _loops[loop_id]
	var player: AudioStreamPlayer = entry["player"]
	if player.playing:
		player.seek(position_sec)


func get_stream_duration(loop_id: String) -> float:
	## Returns the cached pre-loop-mode duration in seconds, or -1.0 if not found.
	## Same source of truth as loop_end — guaranteed consistent.
	if not _loops.has(loop_id):
		return -1.0
	var entry: Dictionary = _loops[loop_id]
	return float(entry["duration"])


func get_cached_duration_by_path(stream_path: String) -> float:
	## Returns the pre-mutation duration for a stream path, or 0.0 if not cached.
	## Used by EffectRateCalculator to avoid resource-cache coupling.
	return float(_durations_by_path.get(stream_path, 0.0))


func set_pitch_shift(semitones: float, fade_sec: float = 0.5) -> void:
	## Apply a pitch shift (in semitones) to loop buses via AudioEffectPitchShift.
	## FFT-based — changes pitch without changing tempo. Pass 0.0 to reset.
	var target_scale: float = pow(2.0, semitones / 12.0)
	for bus_name in AudioBusSetup.PITCH_SHIFT_BUSES:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		if bus_idx < 0:
			continue
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			var fx: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
			if fx is AudioEffectPitchShift:
				var pitch_fx: AudioEffectPitchShift = fx as AudioEffectPitchShift
				if semitones == 0.0:
					pitch_fx.pitch_scale = 1.0
					AudioServer.set_bus_effect_enabled(bus_idx, i, false)
				else:
					AudioServer.set_bus_effect_enabled(bus_idx, i, true)
					if fade_sec > 0.0 and not is_equal_approx(pitch_fx.pitch_scale, target_scale):
						var tween: Tween = get_tree().create_tween()
						tween.set_ease(Tween.EASE_IN_OUT)
						tween.set_trans(Tween.TRANS_SINE)
						tween.tween_property(pitch_fx, "pitch_scale", target_scale, fade_sec)
					else:
						pitch_fx.pitch_scale = target_scale
				break
