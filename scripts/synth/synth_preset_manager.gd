class_name SynthPresetManager
extends RefCounted
## JSON save/load to user://synth_presets/, plus hardcoded built-in presets.

const DIR_PATH := "user://synth_presets/"

# Built-in presets that ship with the game
const BUILTIN_PRESETS: Dictionary = {
	"80s Bass": {
		"mode": "synth",
		"waveform": "Saw",
		"pulse_width": 0.5,
		"amp_attack": 0.005, "amp_decay": 0.15, "amp_sustain": 0.6, "amp_release": 0.1,
		"filter_cutoff": 800.0, "filter_resonance": 0.4, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.005, "filter_env_decay": 0.2, "filter_env_sustain": 0.1, "filter_env_release": 0.1,
		"filter_env_amount": 3000.0,
		"lfo_rate": 0.0, "lfo_depth": 0.0, "lfo_target": "Pitch", "lfo_shape": "Sine",
		"unison_voices": 1, "unison_detune": 0.0,
		"drive": 0.15, "chorus_rate": 0.8, "chorus_depth": 3.0, "chorus_mix": 0.2,
		"analog_drift": 0.1, "stereo_spread": 0.3,
		"note": "C3", "duration": 0.4,
	},
	"Lead Stab": {
		"mode": "synth",
		"waveform": "Square",
		"pulse_width": 0.5,
		"amp_attack": 0.001, "amp_decay": 0.08, "amp_sustain": 0.5, "amp_release": 0.15,
		"filter_cutoff": 2000.0, "filter_resonance": 0.3, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.001, "filter_env_decay": 0.1, "filter_env_sustain": 0.2, "filter_env_release": 0.1,
		"filter_env_amount": 5000.0,
		"lfo_rate": 0.0, "lfo_depth": 0.0, "lfo_target": "Pitch", "lfo_shape": "Sine",
		"unison_voices": 3, "unison_detune": 15.0,
		"drive": 0.3, "chorus_rate": 0.8, "chorus_depth": 3.0, "chorus_mix": 0.15,
		"analog_drift": 0.05, "stereo_spread": 0.6,
		"note": "C4", "duration": 0.3,
	},
	"Pad Swell": {
		"mode": "synth",
		"waveform": "Saw",
		"pulse_width": 0.5,
		"amp_attack": 0.3, "amp_decay": 0.4, "amp_sustain": 0.8, "amp_release": 0.5,
		"filter_cutoff": 1500.0, "filter_resonance": 0.2, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.4, "filter_env_decay": 0.5, "filter_env_sustain": 0.3, "filter_env_release": 0.3,
		"filter_env_amount": 2000.0,
		"lfo_rate": 0.3, "lfo_depth": 0.2, "lfo_target": "Amplitude", "lfo_shape": "Sine",
		"unison_voices": 5, "unison_detune": 20.0,
		"drive": 0.0, "chorus_rate": 0.8, "chorus_depth": 4.0, "chorus_mix": 0.5,
		"analog_drift": 0.2, "stereo_spread": 0.8,
		"note": "C4", "duration": 1.5,
	},
	"Laser Zap": {
		"mode": "synth",
		"waveform": "Saw",
		"pulse_width": 0.5,
		"amp_attack": 0.001, "amp_decay": 0.05, "amp_sustain": 0.0, "amp_release": 0.05,
		"filter_cutoff": 5000.0, "filter_resonance": 0.6, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.001, "filter_env_decay": 0.08, "filter_env_sustain": 0.0, "filter_env_release": 0.05,
		"filter_env_amount": 8000.0,
		"lfo_rate": 0.0, "lfo_depth": 0.0, "lfo_target": "Pitch", "lfo_shape": "Sine",
		"unison_voices": 1, "unison_detune": 0.0,
		"drive": 0.0, "chorus_rate": 0.8, "chorus_depth": 3.0, "chorus_mix": 0.0,
		"analog_drift": 0.0, "stereo_spread": 0.5,
		"note": "C5", "duration": 0.15,
	},
	"Pulse Lead": {
		"mode": "synth",
		"waveform": "Pulse",
		"pulse_width": 0.3,
		"amp_attack": 0.005, "amp_decay": 0.1, "amp_sustain": 0.7, "amp_release": 0.15,
		"filter_cutoff": 3000.0, "filter_resonance": 0.25, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.005, "filter_env_decay": 0.15, "filter_env_sustain": 0.3, "filter_env_release": 0.1,
		"filter_env_amount": 2500.0,
		"lfo_rate": 5.0, "lfo_depth": 0.3, "lfo_target": "Pitch", "lfo_shape": "Sine",
		"unison_voices": 2, "unison_detune": 10.0,
		"drive": 0.0, "chorus_rate": 0.8, "chorus_depth": 3.0, "chorus_mix": 0.0,
		"analog_drift": 0.0, "stereo_spread": 0.5,
		"note": "C4", "duration": 0.4,
	},
	"Juno Pad": {
		"mode": "synth",
		"waveform": "Saw",
		"pulse_width": 0.5,
		"amp_attack": 0.4, "amp_decay": 0.5, "amp_sustain": 0.85, "amp_release": 0.6,
		"filter_cutoff": 2500.0, "filter_resonance": 0.15, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.3, "filter_env_decay": 0.6, "filter_env_sustain": 0.4, "filter_env_release": 0.4,
		"filter_env_amount": 1500.0,
		"lfo_rate": 0.2, "lfo_depth": 0.15, "lfo_target": "Amplitude", "lfo_shape": "Sine",
		"unison_voices": 5, "unison_detune": 25.0,
		"drive": 0.05, "chorus_rate": 0.6, "chorus_depth": 5.0, "chorus_mix": 0.6,
		"analog_drift": 0.3, "stereo_spread": 0.9,
		"note": "C4", "duration": 2.0,
	},
	"Neon Lead": {
		"mode": "synth",
		"waveform": "Pulse",
		"pulse_width": 0.4,
		"amp_attack": 0.005, "amp_decay": 0.12, "amp_sustain": 0.65, "amp_release": 0.2,
		"filter_cutoff": 1200.0, "filter_resonance": 0.35, "filter_mode": "Low-Pass",
		"filter_env_attack": 0.005, "filter_env_decay": 0.25, "filter_env_sustain": 0.15, "filter_env_release": 0.15,
		"filter_env_amount": 6000.0,
		"lfo_rate": 0.0, "lfo_depth": 0.0, "lfo_target": "Pitch", "lfo_shape": "Sine",
		"unison_voices": 3, "unison_detune": 12.0,
		"drive": 0.4, "chorus_rate": 1.0, "chorus_depth": 3.5, "chorus_mix": 0.25,
		"analog_drift": 0.08, "stereo_spread": 0.6,
		"note": "C4", "duration": 0.5,
	},
	"808 Kick": {
		"mode": "drum",
		"drum_type": "Kick",
		"drum_params": {
			"duration": 0.6, "pitch_start": 150.0, "pitch_end": 35.0,
			"pitch_decay": 0.08, "amp_decay": 0.4, "drive": 0.2, "click": 0.6,
		},
	},
	"Snare Crack": {
		"mode": "drum",
		"drum_type": "Snare",
		"drum_params": {
			"duration": 0.25, "tone_freq": 220.0, "tone_decay": 0.08,
			"noise_decay": 0.12, "tone_mix": 0.4, "snappy": 0.7,
		},
	},
	"Closed Hat": {
		"mode": "drum",
		"drum_type": "Hi-Hat",
		"drum_params": {
			"duration": 0.1, "decay": 0.04, "tone": 0.4, "hp_cutoff": 7000.0,
		},
	},
	"Open Hat": {
		"mode": "drum",
		"drum_type": "Hi-Hat",
		"drum_params": {
			"duration": 0.5, "decay": 0.2, "tone": 0.3, "hp_cutoff": 5000.0,
		},
	},
	"Deep Tom": {
		"mode": "drum",
		"drum_type": "Tom",
		"drum_params": {
			"duration": 0.5, "pitch_start": 180.0, "pitch_end": 80.0,
			"pitch_decay": 0.12, "amp_decay": 0.3,
		},
	},
	"Clap": {
		"mode": "drum",
		"drum_type": "Clap",
		"drum_params": {
			"duration": 0.3, "decay": 0.15, "spread": 0.02, "num_bursts": 4.0,
		},
	},
}


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_PATH)


static func save_preset(preset_name: String, data: Dictionary) -> void:
	_ensure_dir()
	data["preset_name"] = preset_name
	var id: String = _name_to_id(preset_name)
	var file := FileAccess.open(DIR_PATH + id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


static func load_preset(preset_name: String) -> Dictionary:
	# Check built-in first
	if preset_name in BUILTIN_PRESETS:
		var preset: Dictionary = BUILTIN_PRESETS[preset_name].duplicate(true)
		preset["preset_name"] = preset_name
		preset["is_builtin"] = true
		return preset

	# Then user presets
	var id: String = _name_to_id(preset_name)
	var path: String = DIR_PATH + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	return data


static func delete_preset(preset_name: String) -> void:
	if preset_name in BUILTIN_PRESETS:
		return  # Cannot delete built-ins
	var id: String = _name_to_id(preset_name)
	var path: String = DIR_PATH + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func list_all_names() -> Array[String]:
	var names: Array[String] = []
	# Built-in presets first
	for key in BUILTIN_PRESETS:
		names.append(str(key))
	names.sort()

	# User presets
	_ensure_dir()
	var user_names: Array[String] = []
	var dir := DirAccess.open(DIR_PATH)
	if dir:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var file := FileAccess.open(DIR_PATH + fname, FileAccess.READ)
				if file:
					var json := JSON.new()
					if json.parse(file.get_as_text()) == OK:
						var data: Dictionary = json.data
						var pname: String = str(data.get("preset_name", fname.get_basename()))
						if pname not in names:
							user_names.append(pname)
			fname = dir.get_next()
		dir.list_dir_end()
	user_names.sort()
	names.append_array(user_names)
	return names


static func is_builtin(preset_name: String) -> bool:
	return preset_name in BUILTIN_PRESETS


static func _name_to_id(preset_name: String) -> String:
	var id: String = preset_name.strip_edges().to_lower().replace(" ", "_")
	var clean: String = ""
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_-"
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "preset_" + str(randi() % 10000)
	return clean
