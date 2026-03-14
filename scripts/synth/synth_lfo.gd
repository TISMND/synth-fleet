class_name SynthLFO
extends RefCounted
## LFO generator for modulating pitch, filter, or amplitude.

enum Target { PITCH, FILTER, AMPLITUDE }
enum Shape { SINE, TRIANGLE, SAW, SQUARE }

var rate: float = 2.0    # Hz
var depth: float = 0.0   # Amount (meaning depends on target)
var target: Target = Target.PITCH
var shape: Shape = Shape.SINE

var _phase: float = 0.0


func reset() -> void:
	_phase = 0.0


func render(sample_rate: float, num_samples: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(num_samples)
	var dt: float = rate / sample_rate
	for i in num_samples:
		var val: float = 0.0
		match shape:
			Shape.SINE:
				val = sin(_phase * TAU)
			Shape.TRIANGLE:
				if _phase < 0.5:
					val = 4.0 * _phase - 1.0
				else:
					val = 3.0 - 4.0 * _phase
			Shape.SAW:
				val = 2.0 * _phase - 1.0
			Shape.SQUARE:
				val = 1.0 if _phase < 0.5 else -1.0
		out[i] = val * depth
		_phase += dt
		if _phase >= 1.0:
			_phase -= 1.0
	return out


static func target_name(t: Target) -> String:
	match t:
		Target.PITCH: return "Pitch"
		Target.FILTER: return "Filter"
		Target.AMPLITUDE: return "Amplitude"
	return "Unknown"


static func shape_name(s: Shape) -> String:
	match s:
		Shape.SINE: return "Sine"
		Shape.TRIANGLE: return "Triangle"
		Shape.SAW: return "Saw"
		Shape.SQUARE: return "Square"
	return "Unknown"
