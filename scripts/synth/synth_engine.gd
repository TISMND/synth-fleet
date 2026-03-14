class_name SynthEngine
extends RefCounted
## Composes all DSP components to render a final audio buffer.
## Supports detune/unison (1-5 voices), stereo rendering, analog drift, and effects.

const SAMPLE_RATE: float = 44100.0

# Oscillator settings
var waveform: SynthOscillator.Waveform = SynthOscillator.Waveform.SAW
var pulse_width: float = 0.5

# Amp envelope
var amp_attack: float = 0.01
var amp_decay: float = 0.1
var amp_sustain: float = 0.7
var amp_release: float = 0.2

# Filter
var filter_cutoff: float = 8000.0
var filter_resonance: float = 0.0
var filter_mode: int = SynthFilter.Mode.LOW_PASS
var filter_drive: float = 0.0  # Pre-filter drive

# Filter envelope
var filter_env_attack: float = 0.01
var filter_env_decay: float = 0.2
var filter_env_sustain: float = 0.0
var filter_env_release: float = 0.1
var filter_env_amount: float = 0.0  # Hz

# LFO
var lfo_rate: float = 2.0
var lfo_depth: float = 0.0
var lfo_target: SynthLFO.Target = SynthLFO.Target.PITCH
var lfo_shape: SynthLFO.Shape = SynthLFO.Shape.SINE

# Unison
var unison_voices: int = 1
var unison_detune: float = 0.0  # cents

# Effects
var drive: float = 0.0         # Post-filter saturation 0-1
var analog_drift: float = 0.0  # 0-1, subtle pitch wobble per voice
var stereo_spread: float = 0.5 # 0=mono, 1=full L/R pan
var chorus_rate: float = 0.8
var chorus_depth: float = 3.0
var chorus_mix: float = 0.0


## Renders stereo interleaved buffer [L0, R0, L1, R1, ...]
func render_stereo(frequency: float, duration: float) -> PackedFloat32Array:
	var total_samples: int = int(duration * SAMPLE_RATE)

	var left := PackedFloat32Array()
	left.resize(total_samples)
	left.fill(0.0)
	var right := PackedFloat32Array()
	right.resize(total_samples)
	right.fill(0.0)

	# Amp envelope
	var amp_env := SynthEnvelope.new()
	amp_env.attack = amp_attack
	amp_env.decay = amp_decay
	amp_env.sustain = amp_sustain
	amp_env.release = amp_release
	var note_off: int = int((amp_attack + amp_decay) * SAMPLE_RATE) + int(0.1 * SAMPLE_RATE)
	note_off = mini(note_off, total_samples)
	var amp_curve: PackedFloat32Array = amp_env.render(SAMPLE_RATE, total_samples, note_off)

	# Filter envelope
	var filt_env := SynthEnvelope.new()
	filt_env.attack = filter_env_attack
	filt_env.decay = filter_env_decay
	filt_env.sustain = filter_env_sustain
	filt_env.release = filter_env_release
	var filt_curve: PackedFloat32Array = filt_env.render(SAMPLE_RATE, total_samples, note_off)

	# LFO
	var lfo := SynthLFO.new()
	lfo.rate = lfo_rate
	lfo.depth = lfo_depth
	lfo.target = lfo_target
	lfo.shape = lfo_shape
	var lfo_buf: PackedFloat32Array = lfo.render(SAMPLE_RATE, total_samples)

	# Render unison voices with stereo panning and analog drift
	var voices: int = clampi(unison_voices, 1, 5)
	var detune_spread: float = unison_detune
	var voice_gain: float = 1.0 / float(voices)

	# Pre-compute per-voice drift LFO phases (random offsets)
	var drift_phases: PackedFloat32Array = PackedFloat32Array()
	drift_phases.resize(voices)
	for v in voices:
		drift_phases[v] = randf() * TAU

	for v in voices:
		var detune_cents: float = 0.0
		if voices > 1:
			detune_cents = -detune_spread / 2.0 + detune_spread * float(v) / float(voices - 1)
		var detune_ratio: float = pow(2.0, detune_cents / 1200.0)
		var voice_freq: float = frequency * detune_ratio

		var osc := SynthOscillator.new()
		osc.waveform = waveform
		osc.pulse_width = pulse_width

		var voice_buf := PackedFloat32Array()
		voice_buf.resize(total_samples)
		voice_buf.fill(0.0)

		# Render with analog drift applied to pitch
		if analog_drift > 0.0 or (lfo_target == SynthLFO.Target.PITCH and lfo_depth > 0.0):
			_render_with_drift_and_lfo(osc, voice_buf, voice_freq, lfo_buf, drift_phases[v])
		else:
			osc.render(voice_buf, voice_freq, SAMPLE_RATE)

		# Compute stereo pan for this voice
		var pan: float = 0.0  # -1 left, +1 right
		if voices > 1:
			pan = (-1.0 + 2.0 * float(v) / float(voices - 1)) * stereo_spread
		var gain_l: float = voice_gain * clampf(1.0 - pan, 0.0, 1.0)
		var gain_r: float = voice_gain * clampf(1.0 + pan, 0.0, 1.0)

		# Mix into stereo output
		for i in total_samples:
			left[i] += voice_buf[i] * gain_l
			right[i] += voice_buf[i] * gain_r

	# Apply filter (process L and R separately with independent filter instances)
	if filter_cutoff < SAMPLE_RATE * 0.49:
		# If LFO targets filter, add LFO to filter env
		if lfo_target == SynthLFO.Target.FILTER and lfo_depth > 0.0:
			for i in total_samples:
				filt_curve[i] = filt_curve[i] + lfo_buf[i]

		var filt_l := SynthFilter.new()
		filt_l.cutoff = filter_cutoff
		filt_l.resonance = filter_resonance
		filt_l.mode = filter_mode
		filt_l.drive = filter_drive
		filt_l.env_amount = filter_env_amount
		filt_l.process_buffer(left, SAMPLE_RATE, filt_curve)

		var filt_r := SynthFilter.new()
		filt_r.cutoff = filter_cutoff
		filt_r.resonance = filter_resonance
		filt_r.mode = filter_mode
		filt_r.drive = filter_drive
		filt_r.env_amount = filter_env_amount
		filt_r.process_buffer(right, SAMPLE_RATE, filt_curve)

	# Apply amp envelope + LFO amplitude
	for i in total_samples:
		var amp: float = amp_curve[i]
		if lfo_target == SynthLFO.Target.AMPLITUDE and lfo_depth > 0.0:
			amp *= clampf(1.0 + lfo_buf[i], 0.0, 2.0)
		left[i] *= amp
		right[i] *= amp

	# Post-filter drive (saturation)
	if drive > 0.001:
		var sat_gain: float = 1.0 + drive * 4.0
		for i in total_samples:
			left[i] = tanh(left[i] * sat_gain)
			right[i] = tanh(right[i] * sat_gain)

	# Effects chain (chorus etc.)
	var fx := SynthEffects.new()
	fx.init(SAMPLE_RATE)
	fx.chorus.rate = chorus_rate
	fx.chorus.depth = chorus_depth
	fx.chorus.mix = chorus_mix
	fx.drive = 0.0  # Already applied above
	fx.process_stereo(left, right)

	# Normalize stereo
	_normalize_stereo(left, right)

	# Interleave into [L0, R0, L1, R1, ...]
	var interleaved := PackedFloat32Array()
	interleaved.resize(total_samples * 2)
	for i in total_samples:
		interleaved[i * 2] = left[i]
		interleaved[i * 2 + 1] = right[i]
	return interleaved


## Legacy mono render for backward compatibility
func render(frequency: float, duration: float) -> PackedFloat32Array:
	var stereo: PackedFloat32Array = render_stereo(frequency, duration)
	# Downmix to mono
	var num_samples: int = stereo.size() / 2
	var mono := PackedFloat32Array()
	mono.resize(num_samples)
	for i in num_samples:
		mono[i] = (stereo[i * 2] + stereo[i * 2 + 1]) * 0.5
	return mono


func _render_with_drift_and_lfo(osc: SynthOscillator, buffer: PackedFloat32Array, base_freq: float, lfo_buf: PackedFloat32Array, drift_phase: float) -> void:
	var drift_rate: float = 0.2 + randf() * 0.3  # 0.2-0.5 Hz per voice
	var drift_phase_inc: float = drift_rate / SAMPLE_RATE
	var max_drift_cents: float = analog_drift * 5.0  # Max 5 cents at full drift

	for i in buffer.size():
		var freq: float = base_freq

		# Apply analog drift (slow sine wobble)
		if analog_drift > 0.0:
			var drift_mod: float = sin(drift_phase) * max_drift_cents
			freq *= pow(2.0, drift_mod / 1200.0)
			drift_phase += drift_phase_inc * TAU
			if drift_phase >= TAU:
				drift_phase -= TAU

		# Apply LFO pitch modulation
		if lfo_target == SynthLFO.Target.PITCH and lfo_depth > 0.0:
			var pitch_mod: float = pow(2.0, lfo_buf[i] / 12.0)
			freq *= pitch_mod

		var dt: float = freq / SAMPLE_RATE
		buffer[i] = osc._generate_sample(dt)
		osc._phase += dt
		if osc._phase >= 1.0:
			osc._phase -= 1.0


func _normalize_stereo(left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	var peak: float = 0.0
	for i in left.size():
		var abs_l: float = absf(left[i])
		var abs_r: float = absf(right[i])
		if abs_l > peak:
			peak = abs_l
		if abs_r > peak:
			peak = abs_r
	if peak > 0.001:
		var gain: float = 0.9 / peak
		for i in left.size():
			left[i] *= gain
			right[i] *= gain
