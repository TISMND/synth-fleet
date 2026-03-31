class_name FlightPathData
extends Resource
## Defines a bezier-curve flight path through screen space for enemy encounters.

@export var id: String = ""
@export var display_name: String = ""
@export var waypoints: Array = []  # Array of {pos: [x,y], ctrl_in: [x,y], ctrl_out: [x,y]}
@export var default_speed: float = 200.0
@export var segment_speeds: Dictionary = {}  # "segment_index" -> speed override
@export var enemy_ship_id: String = ""  # Which enemy ship to preview/use on this path


static func from_dict(data: Dictionary) -> FlightPathData:
	var fp := FlightPathData.new()
	fp.id = data.get("id", "")
	fp.display_name = data.get("display_name", "")
	fp.default_speed = float(data.get("default_speed", 200.0))
	fp.segment_speeds = data.get("segment_speeds", {})
	fp.enemy_ship_id = data.get("enemy_ship_id", "")
	var raw_wps: Array = data.get("waypoints", [])
	fp.waypoints = []
	for wp in raw_wps:
		var pos_arr: Array = wp.get("pos", [0, 0])
		var ci_arr: Array = wp.get("ctrl_in", [0, 0])
		var co_arr: Array = wp.get("ctrl_out", [0, 0])
		fp.waypoints.append({
			"pos": [float(pos_arr[0]), float(pos_arr[1])],
			"ctrl_in": [float(ci_arr[0]), float(ci_arr[1])],
			"ctrl_out": [float(co_arr[0]), float(co_arr[1])],
		})
	return fp


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"default_speed": default_speed,
		"segment_speeds": segment_speeds,
		"enemy_ship_id": enemy_ship_id,
		"waypoints": waypoints,
	}


func get_waypoint_pos(index: int) -> Vector2:
	var wp: Dictionary = waypoints[index]
	var pos: Array = wp["pos"]
	return Vector2(float(pos[0]), float(pos[1]))


func get_waypoint_ctrl_in(index: int) -> Vector2:
	var wp: Dictionary = waypoints[index]
	var ci: Array = wp["ctrl_in"]
	return Vector2(float(ci[0]), float(ci[1]))


func get_waypoint_ctrl_out(index: int) -> Vector2:
	var wp: Dictionary = waypoints[index]
	var co: Array = wp["ctrl_out"]
	return Vector2(float(co[0]), float(co[1]))


func set_waypoint_pos(index: int, pos: Vector2) -> void:
	waypoints[index]["pos"] = [pos.x, pos.y]


func set_waypoint_ctrl_in(index: int, ctrl: Vector2) -> void:
	waypoints[index]["ctrl_in"] = [ctrl.x, ctrl.y]


func set_waypoint_ctrl_out(index: int, ctrl: Vector2) -> void:
	waypoints[index]["ctrl_out"] = [ctrl.x, ctrl.y]


func add_waypoint(pos: Vector2) -> void:
	waypoints.append({
		"pos": [pos.x, pos.y],
		"ctrl_in": [0.0, 0.0],
		"ctrl_out": [0.0, 0.0],
	})


func remove_waypoint(index: int) -> void:
	if index >= 0 and index < waypoints.size():
		waypoints.remove_at(index)
		# Clean up any segment speed overrides that reference removed/shifted segments
		var new_speeds: Dictionary = {}
		for key in segment_speeds:
			var seg_idx: int = int(key)
			if seg_idx < index:
				new_speeds[key] = segment_speeds[key]
			elif seg_idx > index and seg_idx > 0:
				new_speeds[str(seg_idx - 1)] = segment_speeds[key]
		segment_speeds = new_speeds


func to_curve2d() -> Curve2D:
	var curve := Curve2D.new()
	for i in range(waypoints.size()):
		var pos: Vector2 = get_waypoint_pos(i)
		var ci: Vector2 = get_waypoint_ctrl_in(i)
		var co: Vector2 = get_waypoint_ctrl_out(i)
		curve.add_point(pos, ci, co)
	return curve


func get_segment_speed_multiplier(index: int) -> float:
	## Returns the speed multiplier for a segment (1.0 = normal, 0.0 = stop, 2.0 = double).
	var key: String = str(index)
	if segment_speeds.has(key):
		return float(segment_speeds[key])
	return 1.0
