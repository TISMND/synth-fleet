class_name SynthChorus
extends RefCounted
## Classic 2-voice chorus effect with modulated delay lines.
## Processes stereo (interleaved L/R) buffers.

const MAX_DELAY_MS: float = 20.0  # Max delay buffer in ms

var rate: float = 0.8      # LFO rate in Hz
var depth: float = 3.0     # Modulation depth in ms
var mix: float = 0.0       # Dry/wet 0-1

var _buffer_l: PackedFloat32Array
var _buffer_r: PackedFloat32Array
var _write_pos: int = 0
var _lfo_phase_1: float = 0.0
var _lfo_phase_2: float = 0.0
var _buffer_size: int = 0
var _sample_rate: float = 44100.0

const BASE_DELAY_MS: float = 7.0  # Classic Juno-style base delay


func init(sample_rate: float) -> void:
	_sample_rate = sample_rate
	_buffer_size = int(MAX_DELAY_MS * sample_rate / 1000.0) + 1
	_buffer_l = PackedFloat32Array()
	_buffer_l.resize(_buffer_size)
	_buffer_l.fill(0.0)
	_buffer_r = PackedFloat32Array()
	_buffer_r.resize(_buffer_size)
	_buffer_r.fill(0.0)
	_write_pos = 0
	_lfo_phase_1 = 0.0
	_lfo_phase_2 = 0.37  # Offset for stereo width


func process_stereo(left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	if mix <= 0.001:
		return

	var num_samples: int = left.size()
	var phase_inc: float = rate / _sample_rate

	for i in num_samples:
		# Write dry signal into delay buffers
		_buffer_l[_write_pos] = left[i]
		_buffer_r[_write_pos] = right[i]

		# Voice 1 LFO — biased left
		var lfo1: float = sin(_lfo_phase_1 * TAU)
		var delay1_ms: float = BASE_DELAY_MS + depth * lfo1
		var delay1_samples: float = delay1_ms * _sample_rate / 1000.0
		var wet1_l: float = _read_interpolated(_buffer_l, delay1_samples)
		var wet1_r: float = _read_interpolated(_buffer_r, delay1_samples)

		# Voice 2 LFO — slightly different rate, biased right
		var lfo2: float = sin(_lfo_phase_2 * TAU)
		var delay2_ms: float = BASE_DELAY_MS + depth * lfo2
		var delay2_samples: float = delay2_ms * _sample_rate / 1000.0
		var wet2_l: float = _read_interpolated(_buffer_l, delay2_samples)
		var wet2_r: float = _read_interpolated(_buffer_r, delay2_samples)

		# Mix: voice 1 biased left (0.7L/0.3R), voice 2 biased right (0.3L/0.7R)
		var wet_l: float = wet1_l * 0.7 + wet2_l * 0.3
		var wet_r: float = wet1_r * 0.3 + wet2_r * 0.7

		left[i] = left[i] * (1.0 - mix) + wet_l * mix
		right[i] = right[i] * (1.0 - mix) + wet_r * mix

		# Advance write position and LFO phases
		_write_pos = (_write_pos + 1) % _buffer_size
		_lfo_phase_1 += phase_inc
		if _lfo_phase_1 >= 1.0:
			_lfo_phase_1 -= 1.0
		_lfo_phase_2 += phase_inc * 1.12  # Slightly detuned for richness
		if _lfo_phase_2 >= 1.0:
			_lfo_phase_2 -= 1.0


func _read_interpolated(buf: PackedFloat32Array, delay_samples: float) -> float:
	var read_pos: float = float(_write_pos) - delay_samples
	if read_pos < 0.0:
		read_pos += float(_buffer_size)
	var idx0: int = int(read_pos) % _buffer_size
	var idx1: int = (idx0 + 1) % _buffer_size
	var frac: float = read_pos - floorf(read_pos)
	return buf[idx0] * (1.0 - frac) + buf[idx1] * frac
