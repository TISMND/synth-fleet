extends Node
## Maintains the musical clock for the entire game.
## Every weapon, enemy pattern, and visual effect syncs to this.

signal beat_hit(beat_index: int)
signal measure_hit(measure_index: int)

@export var bpm: float = 120.0

var beat_index: int = 0
var measure_index: int = 0
var beats_per_measure: int = 4

var _time_since_last_beat: float = 0.0
var _running: bool = false


func _ready() -> void:
	set_process(false)


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


func get_beat_duration() -> float:
	return 60.0 / bpm


func get_subdivision_duration(subdivision: int) -> float:
	## subdivision: 1 = quarter, 2 = eighth, 3 = triplet
	return get_beat_duration() / subdivision


func _process(delta: float) -> void:
	if not _running:
		return

	# Compensate for audio latency
	var time := AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	_time_since_last_beat += delta

	var beat_duration := get_beat_duration()
	while _time_since_last_beat >= beat_duration:
		_time_since_last_beat -= beat_duration
		beat_index += 1
		beat_hit.emit(beat_index)

		if beat_index % beats_per_measure == 0:
			measure_index += 1
			measure_hit.emit(measure_index)
