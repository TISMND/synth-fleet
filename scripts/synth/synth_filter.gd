class_name SynthFilter
extends RefCounted
## State-variable filter with resonance, envelope modulation, and selectable mode.

enum Mode { LOW_PASS, HIGH_PASS, BAND_PASS }

var cutoff: float = 8000.0     # Hz
var resonance: float = 0.0     # 0-1
var env_amount: float = 0.0    # How much envelope modulates cutoff (in Hz)
var mode: int = Mode.LOW_PASS
var drive: float = 0.0         # Pre-filter saturation 0-1

# State variables
var _low: float = 0.0
var _band: float = 0.0
var _high: float = 0.0


func reset() -> void:
	_low = 0.0
	_band = 0.0
	_high = 0.0


func process_buffer(buffer: PackedFloat32Array, sample_rate: float, env: PackedFloat32Array) -> void:
	for i in buffer.size():
		# Pre-filter drive (soft saturation)
		if drive > 0.0:
			buffer[i] = tanh(buffer[i] * (1.0 + drive * 4.0))

		var env_val: float = env[i] if i < env.size() else 0.0
		var mod_cutoff: float = clampf(cutoff + env_amount * env_val, 20.0, sample_rate * 0.49)
		var f: float = 2.0 * sin(PI * mod_cutoff / sample_rate)
		f = clampf(f, 0.0, 1.0)
		var q: float = 1.0 - resonance * 0.95  # Prevent self-oscillation blowup
		q = maxf(q, 0.05)

		_high = buffer[i] - _low - q * _band
		_band += f * _high
		_low += f * _band

		match mode:
			Mode.HIGH_PASS:
				buffer[i] = _high
			Mode.BAND_PASS:
				buffer[i] = _band
			_:
				buffer[i] = _low
