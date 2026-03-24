class_name DoodadRenderer
extends Node2D
## Shared doodad renderer — draws doodad objects using _draw() API.
## Used by both the game runtime (parallax layer) and the level editor preview.
## Follows PREVIEWS MUST = GAME REALITY rule.

var _doodads: Array = []  # Array of doodad dicts from LevelData
var _cull_y_min: float = -INF  # Optional Y culling range (level-space)
var _cull_y_max: float = INF


func setup(doodads: Array) -> void:
	_doodads = doodads
	queue_redraw()


func set_cull_range(y_min: float, y_max: float) -> void:
	_cull_y_min = y_min
	_cull_y_max = y_max
	queue_redraw()


func _draw() -> void:
	for dd in _doodads:
		var dd_type: String = str(dd.get("type", ""))
		var dd_x: float = float(dd.get("x", 0.0))
		var dd_y: float = float(dd.get("y", 0.0))
		var dd_scale: float = float(dd.get("scale", 1.0))
		var dd_rot: float = float(dd.get("rotation_deg", 0.0))

		# Cull off-screen doodads
		if dd_y < _cull_y_min or dd_y > _cull_y_max:
			continue

		# Apply transform: translate to position, then scale and rotate
		var center := Vector2(dd_x, dd_y)
		var base_size: float = 12.0 * dd_scale

		# Draw the appropriate doodad type
		match dd_type:
			"water_tower":
				_draw_water_tower(center, base_size)
			"antenna":
				_draw_antenna(center, base_size)
			"satellite_dish":
				_draw_satellite_dish(center, base_size)
			"ac_cluster":
				_draw_ac_cluster(center, base_size)
			"solar_panels":
				_draw_solar_panels(center, base_size)
			"rooftop_garden":
				_draw_rooftop_garden(center, base_size)
			"crate_stack":
				_draw_crate_stack(center, base_size)
			"vent_pipe":
				_draw_vent_pipe(center, base_size)
			_:
				# Unknown type — draw a placeholder X
				draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), Color.RED, 2.0)
				draw_line(center + Vector2(5, -5), center + Vector2(-5, 5), Color.RED, 2.0)


func _draw_water_tower(center: Vector2, size: float) -> void:
	var r: float = size * 0.5
	var leg_h: float = r * 0.7
	var tank_col := Color(0.18, 0.17, 0.16)
	var leg_col := Color(0.12, 0.11, 0.1)
	# Support legs (X shape)
	draw_line(center + Vector2(-r * 0.6, leg_h), center + Vector2(r * 0.3, -leg_h * 0.2), leg_col, 1.0)
	draw_line(center + Vector2(r * 0.6, leg_h), center + Vector2(-r * 0.3, -leg_h * 0.2), leg_col, 1.0)
	# Tank body
	draw_circle(center - Vector2(0, leg_h * 0.2), r, tank_col)
	# Highlight ring
	draw_arc(center - Vector2(0, leg_h * 0.2), r * 0.65, 0.0, TAU, 12, Color(0.22, 0.21, 0.2), 0.8)


func _draw_antenna(center: Vector2, size: float) -> void:
	var h: float = size
	var pole_col := Color(0.2, 0.18, 0.16)
	var wire_col := Color(0.15, 0.14, 0.13, 0.7)
	# Pole
	draw_line(center + Vector2(0, h * 0.5), center - Vector2(0, h * 0.5), pole_col, 1.5)
	# Cross bars
	for i in range(3):
		var y_off: float = -h * 0.15 + float(i) * h * 0.25
		var bar_w: float = h * 0.3 - float(i) * h * 0.06
		draw_line(center + Vector2(-bar_w, y_off), center + Vector2(bar_w, y_off), wire_col, 0.8)
	# Red light at top
	draw_circle(center - Vector2(0, h * 0.5), 1.5, Color(0.8, 0.1, 0.1, 0.8))


func _draw_satellite_dish(center: Vector2, size: float) -> void:
	var r: float = size * 0.5
	var dish_col := Color(0.2, 0.2, 0.22)
	# Dish arc
	draw_arc(center, r, -0.3, PI + 0.3, 16, dish_col, 1.5)
	# Feed arm
	draw_line(center, center + Vector2(r * 0.4, -r * 0.6), Color(0.15, 0.15, 0.16), 1.0)
	# Base
	draw_circle(center, r * 0.2, Color(0.13, 0.13, 0.14))


func _draw_ac_cluster(center: Vector2, size: float) -> void:
	var s: float = size * 0.4
	var unit_col := Color(0.16, 0.17, 0.18)
	var vent_col := Color(0.1, 0.1, 0.11)
	for i in range(3):
		var offset := Vector2((float(i) - 1.0) * s * 1.1, 0.0)
		var r := Rect2(center + offset - Vector2(s * 0.45, s * 0.35), Vector2(s * 0.9, s * 0.7))
		draw_rect(r, unit_col)
		draw_circle(center + offset, s * 0.18, vent_col)


func _draw_solar_panels(center: Vector2, size: float) -> void:
	var s: float = size * 0.35
	var panel_col := Color(0.05, 0.07, 0.15)
	var frame_col := Color(0.12, 0.12, 0.14)
	for py in range(3):
		for px in range(2):
			var offset := Vector2(
				(float(px) - 0.5) * (s + 1.5),
				(float(py) - 1.0) * (s * 0.65 + 1.5)
			)
			var r := Rect2(center + offset - Vector2(s * 0.5, s * 0.3), Vector2(s, s * 0.6))
			draw_rect(r, panel_col)
			draw_rect(r, frame_col, false, 0.5)


func _draw_rooftop_garden(center: Vector2, size: float) -> void:
	var s: float = size * 0.5
	var planter_col := Color(0.08, 0.06, 0.04)
	var green_col := Color(0.04, 0.1, 0.04)
	var r := Rect2(center - Vector2(s * 0.8, s * 0.6), Vector2(s * 1.6, s * 1.2))
	draw_rect(r, planter_col)
	var inner := Rect2(r.position + Vector2(1.5, 1.5), r.size - Vector2(3.0, 3.0))
	draw_rect(inner, green_col)
	draw_circle(center + Vector2(-s * 0.3, -s * 0.1), s * 0.2, Color(0.03, 0.12, 0.03))
	draw_circle(center + Vector2(s * 0.25, s * 0.15), s * 0.15, Color(0.04, 0.09, 0.03))


func _draw_crate_stack(center: Vector2, size: float) -> void:
	var s: float = size * 0.4
	var crate_col := Color(0.12, 0.09, 0.05)
	var strap_col := Color(0.15, 0.12, 0.07)
	# Bottom row (2 crates)
	for i in range(2):
		var offset := Vector2((float(i) - 0.5) * s * 1.1, s * 0.3)
		var r := Rect2(center + offset - Vector2(s * 0.45, s * 0.4), Vector2(s * 0.9, s * 0.8))
		draw_rect(r, crate_col)
		# Strap lines
		draw_line(r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, r.size.y), strap_col, 0.5)
	# Top crate (offset)
	var top_r := Rect2(center - Vector2(s * 0.4, s * 0.6), Vector2(s * 0.8, s * 0.7))
	draw_rect(top_r, crate_col * 1.1)
	draw_line(top_r.position + Vector2(top_r.size.x * 0.5, 0), top_r.position + Vector2(top_r.size.x * 0.5, top_r.size.y), strap_col, 0.5)


func _draw_vent_pipe(center: Vector2, size: float) -> void:
	var r: float = size * 0.25
	var pipe_col := Color(0.15, 0.15, 0.17)
	var dark_col := Color(0.06, 0.06, 0.07)
	# Main pipe circle
	draw_circle(center, r, pipe_col)
	# Dark interior
	draw_circle(center, r * 0.6, dark_col)
	# Flange ring
	draw_arc(center, r * 0.9, 0.0, TAU, 12, Color(0.18, 0.18, 0.2), 1.0)
	# Second smaller pipe nearby
	var offset := Vector2(r * 2.2, r * 0.5)
	draw_circle(center + offset, r * 0.7, pipe_col)
	draw_circle(center + offset, r * 0.4, dark_col)
