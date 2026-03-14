class_name SynthEnvelope
extends RefCounted
## ADSR envelope generator. Renders a float multiplier array.

var attack: float = 0.01   # seconds
var decay: float = 0.1     # seconds
var sustain: float = 0.7   # 0-1 level
var release: float = 0.2   # seconds


func render(sample_rate: float, total_samples: int, note_off_sample: int = -1) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(total_samples)

	var attack_samples: int = int(attack * sample_rate)
	var decay_samples: int = int(decay * sample_rate)

	if note_off_sample < 0:
		# Auto note-off: after attack + decay + a bit of sustain
		note_off_sample = attack_samples + decay_samples

	var release_samples: int = int(release * sample_rate)
	var release_start_level: float = sustain

	for i in total_samples:
		var level: float = 0.0
		if i < attack_samples:
			# Attack phase
			level = float(i) / maxf(float(attack_samples), 1.0)
		elif i < attack_samples + decay_samples:
			# Decay phase
			var decay_pos: float = float(i - attack_samples) / maxf(float(decay_samples), 1.0)
			level = 1.0 - (1.0 - sustain) * decay_pos
		elif i < note_off_sample:
			# Sustain phase
			level = sustain
		else:
			# Release phase
			var rel_pos: int = i - note_off_sample
			if rel_pos == 0:
				# Capture level at note-off for smooth release
				if i < attack_samples:
					release_start_level = float(i) / maxf(float(attack_samples), 1.0)
				elif i < attack_samples + decay_samples:
					var dp: float = float(i - attack_samples) / maxf(float(decay_samples), 1.0)
					release_start_level = 1.0 - (1.0 - sustain) * dp
				else:
					release_start_level = sustain
			if rel_pos < release_samples:
				var rel_frac: float = float(rel_pos) / maxf(float(release_samples), 1.0)
				level = release_start_level * (1.0 - rel_frac)
			else:
				level = 0.0
		env[i] = level

	return env
