extends Node
## SFX playback singleton — loads SfxConfig and plays one-shot sounds for game events.

var _config: SfxConfig = null
var _cache: Dictionary = {}  # event_id -> AudioStream


func _ready() -> void:
	reload()


func reload() -> void:
	_config = SfxConfigManager.load_config()
	_cache.clear()
	for event_id in SfxConfig.EVENT_IDS:
		var ev: Dictionary = _config.get_event(event_id)
		var path: String = str(ev.get("file_path", ""))
		if path == "":
			continue
		if not FileAccess.file_exists(path):
			push_warning("SfxPlayer: missing audio file '%s' for event '%s'" % [path, event_id])
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream:
			_cache[event_id] = stream


func get_cached_stream(event_id: String) -> AudioStream:
	if _cache.has(event_id):
		return _cache[event_id]
	return null


func play(event_id: String) -> void:
	if not _cache.has(event_id):
		return
	var stream: AudioStream = _cache[event_id]
	var ev: Dictionary = _config.get_event(event_id)
	var vol: float = float(ev.get("volume_db", 0.0))
	var fade_in: float = float(ev.get("fade_in_duration", 0.0))
	var fade_out: float = float(ev.get("fade_out_duration", 0.0))
	if fade_in > 0.0 or fade_out > 0.0:
		var clip_end: float = float(ev.get("clip_end_time", 0.0))
		AudioManager.play_sample_faded(stream, 1.0, vol, fade_in, fade_out, clip_end)
	else:
		AudioManager.play_sample(stream, 1.0, vol)


func play_ui(event_id: String) -> void:
	## Play on UI bus — bypasses Master bus effects (low-pass, reverb from blackout).
	## Use for screen/cockpit sounds: typing, monitor static, power failure, reboot.
	if not _cache.has(event_id):
		return
	var stream: AudioStream = _cache[event_id]
	var ev: Dictionary = _config.get_event(event_id)
	var vol: float = float(ev.get("volume_db", 0.0))
	var fade_in: float = float(ev.get("fade_in_duration", 0.0))
	var fade_out: float = float(ev.get("fade_out_duration", 0.0))
	if fade_in > 0.0 or fade_out > 0.0:
		var clip_end: float = float(ev.get("clip_end_time", 0.0))
		AudioManager.play_on_bus_faded(stream, "UI", 1.0, vol, fade_in, fade_out, clip_end)
	else:
		AudioManager.play_on_bus(stream, "UI", 1.0, vol)


func play_random_explosion() -> void:
	var candidates: Array[String] = []
	for eid in ["explosion_1", "explosion_2", "explosion_3"]:
		if _cache.has(eid):
			candidates.append(eid)
	if candidates.size() == 0:
		return
	play(candidates[randi() % candidates.size()])
