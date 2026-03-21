class_name KeyChangeData
extends Resource
## Reusable key change preset — defines pitch shift, fade, and enter/exit SFX with offset timing.

@export var id: String = ""
@export var display_name: String = ""
@export var semitones: int = 0  # -6 to +6
@export var fade_duration: float = 0.15  # pitch shift tween time in seconds
@export var enter_sfx_path: String = ""
@export var exit_sfx_path: String = ""
@export var enter_sfx_offset: float = 0.0  # seconds before measure boundary to start SFX
@export var exit_sfx_offset: float = 0.0
@export var enter_sfx_volume_db: float = 0.0
@export var exit_sfx_volume_db: float = 0.0
@export var reverse_exit_sfx: bool = false


static func from_dict(data: Dictionary) -> KeyChangeData:
	var kc := KeyChangeData.new()
	kc.id = str(data.get("id", ""))
	kc.display_name = str(data.get("display_name", ""))
	kc.semitones = int(data.get("semitones", 0))
	kc.fade_duration = float(data.get("fade_duration", 0.15))
	kc.enter_sfx_path = str(data.get("enter_sfx_path", ""))
	kc.exit_sfx_path = str(data.get("exit_sfx_path", ""))
	kc.enter_sfx_offset = float(data.get("enter_sfx_offset", 0.0))
	kc.exit_sfx_offset = float(data.get("exit_sfx_offset", 0.0))
	kc.enter_sfx_volume_db = float(data.get("enter_sfx_volume_db", 0.0))
	kc.exit_sfx_volume_db = float(data.get("exit_sfx_volume_db", 0.0))
	kc.reverse_exit_sfx = bool(data.get("reverse_exit_sfx", false))
	return kc


func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id": id,
		"display_name": display_name,
		"semitones": semitones,
		"fade_duration": fade_duration,
	}
	if enter_sfx_path != "":
		d["enter_sfx_path"] = enter_sfx_path
		d["enter_sfx_offset"] = enter_sfx_offset
		d["enter_sfx_volume_db"] = enter_sfx_volume_db
	if exit_sfx_path != "":
		d["exit_sfx_path"] = exit_sfx_path
		d["exit_sfx_offset"] = exit_sfx_offset
		d["exit_sfx_volume_db"] = exit_sfx_volume_db
	if reverse_exit_sfx:
		d["reverse_exit_sfx"] = true
	return d


static func make_reversed_stream(stream: AudioStreamWAV) -> AudioStreamWAV:
	## Create a reversed copy of an AudioStreamWAV (for exit SFX reverse).
	var rev := AudioStreamWAV.new()
	rev.format = stream.format
	rev.mix_rate = stream.mix_rate
	rev.stereo = stream.stereo
	var src_data: PackedByteArray = stream.data
	var bytes_per_sample: int = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var channels: int = 2 if stream.stereo else 1
	var frame_size: int = bytes_per_sample * channels
	var frame_count: int = src_data.size() / frame_size
	var reversed_data := PackedByteArray()
	reversed_data.resize(src_data.size())
	for i in frame_count:
		var src_offset: int = i * frame_size
		var dst_offset: int = (frame_count - 1 - i) * frame_size
		for b in frame_size:
			reversed_data[dst_offset + b] = src_data[src_offset + b]
	rev.data = reversed_data
	return rev
