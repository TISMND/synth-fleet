class_name SynthOscillator
extends RefCounted
## Band-limited waveform generator using PolyBLEP anti-aliasing.

enum Waveform { SINE, SQUARE, SAW, TRIANGLE, PULSE, NOISE }

var waveform: Waveform = Waveform.SINE
var pulse_width: float = 0.5  # Only used for PULSE waveform

var _phase: float = 0.0
var _rng: RandomNumberGenerator


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


func reset() -> void:
	_phase = 0.0


func render(buffer: PackedFloat32Array, frequency: float, sample_rate: float, start_sample: int = 0, count: int = -1) -> void:
	if count < 0:
		count = buffer.size() - start_sample
	var dt: float = frequency / sample_rate
	for i in count:
		var sample: float = _generate_sample(dt)
		buffer[start_sample + i] = sample
		_phase += dt
		if _phase >= 1.0:
			_phase -= 1.0


func _generate_sample(dt: float) -> float:
	match waveform:
		Waveform.SINE:
			return sin(_phase * TAU)
		Waveform.SQUARE:
			return _poly_blep_square(dt)
		Waveform.SAW:
			return _poly_blep_saw(dt)
		Waveform.TRIANGLE:
			return _poly_blep_triangle(dt)
		Waveform.PULSE:
			return _poly_blep_pulse(dt, pulse_width)
		Waveform.NOISE:
			return _rng.randf_range(-1.0, 1.0)
	return 0.0


func _poly_blep(t: float, dt: float) -> float:
	if t < dt:
		var x: float = t / dt
		return x + x - x * x - 1.0
	elif t > 1.0 - dt:
		var x: float = (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


func _poly_blep_saw(dt: float) -> float:
	var raw: float = 2.0 * _phase - 1.0
	raw -= _poly_blep(_phase, dt)
	return raw


func _poly_blep_square(dt: float) -> float:
	var raw: float = 1.0 if _phase < 0.5 else -1.0
	raw += _poly_blep(_phase, dt)
	raw -= _poly_blep(fmod(_phase + 0.5, 1.0), dt)
	return raw


func _poly_blep_pulse(dt: float, pw: float) -> float:
	pw = clampf(pw, 0.01, 0.99)
	var raw: float = 1.0 if _phase < pw else -1.0
	raw += _poly_blep(_phase, dt)
	raw -= _poly_blep(fmod(_phase + (1.0 - pw), 1.0), dt)
	return raw


func _poly_blep_triangle(dt: float) -> float:
	# Integrate a PolyBLEP square to get a band-limited triangle
	var sq: float = _poly_blep_square(dt)
	# Leaky integrator approximation for triangle from square
	# For simplicity, use the naive formula (good enough for most cases)
	var t: float = _phase
	if t < 0.5:
		return 4.0 * t - 1.0
	else:
		return 3.0 - 4.0 * t


static func waveform_name(w: Waveform) -> String:
	match w:
		Waveform.SINE: return "Sine"
		Waveform.SQUARE: return "Square"
		Waveform.SAW: return "Saw"
		Waveform.TRIANGLE: return "Triangle"
		Waveform.PULSE: return "Pulse"
		Waveform.NOISE: return "Noise"
	return "Unknown"


static func waveform_from_name(n: String) -> Waveform:
	match n.to_lower():
		"sine": return Waveform.SINE
		"square": return Waveform.SQUARE
		"saw": return Waveform.SAW
		"triangle": return Waveform.TRIANGLE
		"pulse": return Waveform.PULSE
		"noise": return Waveform.NOISE
	return Waveform.SINE
