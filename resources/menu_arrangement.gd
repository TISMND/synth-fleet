class_name MenuArrangement
extends Resource
## A named menu music arrangement — multiple layered loops with timing.
## Each arrangement is a variant of menu music; the game can pick one at random
## so players don't hear the same song every session.

@export var id: String = ""
@export var display_name: String = ""
@export var bpm: float = 120.0
@export var duration_bars: int = 16
@export var tracks: Array = []  # Array of track dicts — see MusicTimelineEditor track schema


static func from_dict(data: Dictionary) -> MenuArrangement:
	var a := MenuArrangement.new()
	a.id = str(data.get("id", ""))
	a.display_name = str(data.get("display_name", ""))
	a.bpm = float(data.get("bpm", 120.0))
	a.duration_bars = int(data.get("duration_bars", 16))
	var raw: Array = data.get("tracks", [])
	a.tracks = []
	for tr in raw:
		a.tracks.append({
			"loop_path": str(tr.get("loop_path", "")),
			"label": str(tr.get("label", "")),
			"start_bar": float(tr.get("start_bar", 0.0)),
			"end_bar": float(tr.get("end_bar", 4.0)),
			"fade_in_bars": float(tr.get("fade_in_bars", 0.0)),
			"fade_out_bars": float(tr.get("fade_out_bars", 1.0)),
			"volume_db": float(tr.get("volume_db", 0.0)),
			"infinite_loop": bool(tr.get("infinite_loop", false)),
		})
	return a


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"bpm": bpm,
		"duration_bars": duration_bars,
		"tracks": tracks,
	}
