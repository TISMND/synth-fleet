extends Node
## Musical clock. Everything syncs to beat_hit / measure_hit signals.
## BPM loaded from user://settings/beat_clock.json, default 120.

signal beat_hit(beat_index: int)
signal measure_hit(measure_index: int)
signal position_updated(beat_pos: float, bar: int)

const SETTINGS_PATH := "user://settings/beat_clock.json"

@export var bpm: float = 120.0

var beat_index: int = 0
var measure_index: int = 0
var beats_per_measure: int = 4

## Fractional position within current measure (0.0 to beats_per_measure), wraps each measure.
var beat_position: float = 0.0
## Monotonically increasing since start.
var total_beat_position: float = 0.0

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
	beat_position = 0.0
	total_beat_position = 0.0
	_running = true
	set_process(true)


func stop() -> void:
	_running = false
	set_process(false)


func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm


func get_beat_duration() -> float:
	return 60.0 / bpm


func get_loop_beat_position(loop_length_beats: float) -> float:
	return fmod(total_beat_position, loop_length_beats)


func _process(delta: float) -> void:
	if not _running:
		return

	var beat_duration: float = get_beat_duration()
	var delta_beats: float = delta / beat_duration

	var prev_beat_position: float = beat_position
	beat_position += delta_beats
	total_beat_position += delta_beats

	# Check for beat crossings
	while beat_position >= 1.0:
		beat_position -= 1.0
		beat_index += 1
		beat_hit.emit(beat_index)

		if beat_index % beats_per_measure == 0:
			measure_index += 1
			measure_hit.emit(measure_index)

	position_updated.emit(beat_position, measure_index)
