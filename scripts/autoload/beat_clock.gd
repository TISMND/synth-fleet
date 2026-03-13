extends Node
## Musical clock. Everything syncs to beat_hit / measure_hit signals.
## BPM loaded from user://settings/beat_clock.json, default 120.

signal beat_hit(beat_index: int)
signal measure_hit(measure_index: int)

const SETTINGS_PATH := "user://settings/beat_clock.json"

@export var bpm: float = 120.0

var beat_index: int = 0
var measure_index: int = 0
var beats_per_measure: int = 4

var _time_since_last_beat: float = 0.0
var _running: bool = false


func _ready() -> void:
	_load_settings()
	set_process(false)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	bpm = float(data.get("bpm", 120.0))


func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({ "bpm": bpm }, "\t"))


func start(new_bpm: float = bpm) -> void:
	bpm = new_bpm
	beat_index = 0
	measure_index = 0
	_time_since_last_beat = 0.0
	_running = true
	set_process(true)


func stop() -> void:
	_running = false
	set_process(false)


func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm


func get_beat_duration() -> float:
	return 60.0 / bpm


func get_subdivision_duration(subdivision: int) -> float:
	## subdivision: 1 = quarter, 2 = eighth, 3 = triplet
	return get_beat_duration() / subdivision


func _process(delta: float) -> void:
	if not _running:
		return

	_time_since_last_beat += delta

	var beat_duration: float = get_beat_duration()
	while _time_since_last_beat >= beat_duration:
		_time_since_last_beat -= beat_duration
		beat_index += 1
		beat_hit.emit(beat_index)

		if beat_index % beats_per_measure == 0:
			measure_index += 1
			measure_hit.emit(measure_index)
