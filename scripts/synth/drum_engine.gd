class_name DrumEngine
extends RefCounted
## Specialized drum synthesis: kick, snare, hi-hat, tom, clap.

enum DrumType { KICK, SNARE, HIHAT, TOM, CLAP }

const SAMPLE_RATE: float = 44100.0


static func render(drum_type: DrumType, params: Dictionary) -> PackedFloat32Array:
	match drum_type:
		DrumType.KICK:
			return _render_kick(params)
		DrumType.SNARE:
			return _render_snare(params)
		DrumType.HIHAT:
			return _render_hihat(params)
		DrumType.TOM:
			return _render_tom(params)
		DrumType.CLAP:
			return _render_clap(params)
	return PackedFloat32Array()


static func _render_kick(p: Dictionary) -> PackedFloat32Array:
	var duration: float = float(p.get("duration", 0.5))
	var pitch_start: float = float(p.get("pitch_start", 150.0))
	var pitch_end: float = float(p.get("pitch_end", 40.0))
	var pitch_decay: float = float(p.get("pitch_decay", 0.08))
	var amp_decay: float = float(p.get("amp_decay", 0.3))
	var drive: float = float(p.get("drive", 0.0))
	var click: float = float(p.get("click", 0.5))

	var samples: int = int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0

	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		# Exponential pitch sweep
		var freq: float = pitch_end + (pitch_start - pitch_end) * exp(-t / pitch_decay)
		phase += freq / SAMPLE_RATE
		if phase >= 1.0:
			phase -= 1.0
		var sample: float = sin(phase * TAU)

		# Click transient
		if t < 0.005:
			sample += click * sin(t * 3000.0 * TAU) * (1.0 - t / 0.005)

		# Drive/saturation
		if drive > 0.0:
			sample = tanh(sample * (1.0 + drive * 4.0))

		# Amp envelope
		sample *= exp(-t / amp_decay)
		buf[i] = sample

	_normalize_static(buf)
	return buf


static func _render_snare(p: Dictionary) -> PackedFloat32Array:
	var duration: float = float(p.get("duration", 0.3))
	var tone_freq: float = float(p.get("tone_freq", 200.0))
	var tone_decay: float = float(p.get("tone_decay", 0.1))
	var noise_decay: float = float(p.get("noise_decay", 0.15))
	var tone_mix: float = float(p.get("tone_mix", 0.5))
	var snappy: float = float(p.get("snappy", 0.5))

	var samples: int = int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var phase: float = 0.0

	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		# Tone component
		phase += tone_freq / SAMPLE_RATE
		if phase >= 1.0:
			phase -= 1.0
		var tone: float = sin(phase * TAU) * exp(-t / tone_decay)

		# Noise component (filtered)
		var noise: float = rng.randf_range(-1.0, 1.0) * exp(-t / noise_decay)

		# Snappy wire buzz (high-frequency noise burst)
		var wire: float = 0.0
		if t < 0.05:
			wire = rng.randf_range(-1.0, 1.0) * snappy * (1.0 - t / 0.05)

		buf[i] = tone * tone_mix + noise * (1.0 - tone_mix) + wire * 0.3

	_normalize_static(buf)
	return buf


static func _render_hihat(p: Dictionary) -> PackedFloat32Array:
	var duration: float = float(p.get("duration", 0.15))
	var decay: float = float(p.get("decay", 0.05))
	var tone: float = float(p.get("tone", 0.3))
	var hp_cutoff: float = float(p.get("hp_cutoff", 6000.0))

	var samples: int = int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Generate noise
	for i in samples:
		buf[i] = rng.randf_range(-1.0, 1.0)

	# Simple high-pass via subtraction of low-passed signal
	var lp: float = 0.0
	var rc: float = 1.0 / (TAU * hp_cutoff)
	var alpha: float = 1.0 / (1.0 + SAMPLE_RATE * rc)
	for i in samples:
		lp += alpha * (buf[i] - lp)
		buf[i] = buf[i] - lp

	# Add metallic tone (multiple detuned square waves)
	if tone > 0.0:
		var freqs: Array[float] = [800.0, 1340.0, 1680.0, 3250.0, 5540.0, 8050.0]
		for i in samples:
			var t: float = float(i) / SAMPLE_RATE
			var metallic: float = 0.0
			for f in freqs:
				metallic += (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0)
			metallic /= float(freqs.size())
			buf[i] += metallic * tone * exp(-t / decay)

	# Amp envelope
	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		buf[i] *= exp(-t / decay)

	_normalize_static(buf)
	return buf


static func _render_tom(p: Dictionary) -> PackedFloat32Array:
	var duration: float = float(p.get("duration", 0.4))
	var pitch_start: float = float(p.get("pitch_start", 200.0))
	var pitch_end: float = float(p.get("pitch_end", 100.0))
	var pitch_decay: float = float(p.get("pitch_decay", 0.1))
	var amp_decay: float = float(p.get("amp_decay", 0.25))

	var samples: int = int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0

	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		var freq: float = pitch_end + (pitch_start - pitch_end) * exp(-t / pitch_decay)
		phase += freq / SAMPLE_RATE
		if phase >= 1.0:
			phase -= 1.0
		buf[i] = sin(phase * TAU) * exp(-t / amp_decay)

	_normalize_static(buf)
	return buf


static func _render_clap(p: Dictionary) -> PackedFloat32Array:
	var duration: float = float(p.get("duration", 0.3))
	var decay: float = float(p.get("decay", 0.15))
	var spread: float = float(p.get("spread", 0.02))
	var num_bursts: int = int(p.get("num_bursts", 4))

	var samples: int = int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Layered noise bursts
	var burst_spacing: float = spread / float(num_bursts)
	for b in num_bursts:
		var burst_start: int = int(float(b) * burst_spacing * SAMPLE_RATE)
		var burst_len: int = int(0.008 * SAMPLE_RATE)
		for i in burst_len:
			var idx: int = burst_start + i
			if idx < samples:
				var env_val: float = 1.0 - float(i) / float(burst_len)
				buf[idx] += rng.randf_range(-1.0, 1.0) * env_val

	# Apply overall decay
	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		buf[i] *= exp(-t / decay)

	# Bandpass-ish filter (simple LP)
	var lp: float = 0.0
	var f: float = 2.0 * sin(PI * 2500.0 / SAMPLE_RATE)
	for i in samples:
		lp += f * (buf[i] - lp)
		buf[i] = lp

	_normalize_static(buf)
	return buf


static func _normalize_static(buffer: PackedFloat32Array) -> void:
	var peak: float = 0.0
	for i in buffer.size():
		var abs_val: float = absf(buffer[i])
		if abs_val > peak:
			peak = abs_val
	if peak > 0.001:
		var gain: float = 0.9 / peak
		for i in buffer.size():
			buffer[i] *= gain


static func type_name(t: DrumType) -> String:
	match t:
		DrumType.KICK: return "Kick"
		DrumType.SNARE: return "Snare"
		DrumType.HIHAT: return "Hi-Hat"
		DrumType.TOM: return "Tom"
		DrumType.CLAP: return "Clap"
	return "Unknown"


static func type_from_name(n: String) -> DrumType:
	match n.to_lower():
		"kick": return DrumType.KICK
		"snare": return DrumType.SNARE
		"hi-hat", "hihat": return DrumType.HIHAT
		"tom": return DrumType.TOM
		"clap": return DrumType.CLAP
	return DrumType.KICK


## Returns parameter definitions for each drum type: {name: [min, max, default, step]}
static func get_param_defs(drum_type: DrumType) -> Dictionary:
	match drum_type:
		DrumType.KICK:
			return {
				"duration": [0.1, 1.5, 0.5, 0.01],
				"pitch_start": [50.0, 500.0, 150.0, 1.0],
				"pitch_end": [20.0, 150.0, 40.0, 1.0],
				"pitch_decay": [0.01, 0.5, 0.08, 0.01],
				"amp_decay": [0.05, 1.0, 0.3, 0.01],
				"drive": [0.0, 1.0, 0.0, 0.01],
				"click": [0.0, 1.0, 0.5, 0.01],
			}
		DrumType.SNARE:
			return {
				"duration": [0.1, 1.0, 0.3, 0.01],
				"tone_freq": [100.0, 400.0, 200.0, 1.0],
				"tone_decay": [0.02, 0.3, 0.1, 0.01],
				"noise_decay": [0.02, 0.5, 0.15, 0.01],
				"tone_mix": [0.0, 1.0, 0.5, 0.01],
				"snappy": [0.0, 1.0, 0.5, 0.01],
			}
		DrumType.HIHAT:
			return {
				"duration": [0.05, 1.0, 0.15, 0.01],
				"decay": [0.01, 0.5, 0.05, 0.01],
				"tone": [0.0, 1.0, 0.3, 0.01],
				"hp_cutoff": [2000.0, 15000.0, 6000.0, 100.0],
			}
		DrumType.TOM:
			return {
				"duration": [0.1, 1.0, 0.4, 0.01],
				"pitch_start": [80.0, 500.0, 200.0, 1.0],
				"pitch_end": [40.0, 300.0, 100.0, 1.0],
				"pitch_decay": [0.02, 0.3, 0.1, 0.01],
				"amp_decay": [0.05, 0.8, 0.25, 0.01],
			}
		DrumType.CLAP:
			return {
				"duration": [0.1, 0.8, 0.3, 0.01],
				"decay": [0.03, 0.5, 0.15, 0.01],
				"spread": [0.005, 0.08, 0.02, 0.001],
				"num_bursts": [2.0, 8.0, 4.0, 1.0],
			}
	return {}
