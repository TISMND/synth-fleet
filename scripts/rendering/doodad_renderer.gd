class_name DoodadRenderer
extends Node2D
## Shared doodad renderer — draws doodad objects using _draw() API.
## Used by both the game runtime (parallax layer) and the level editor preview.
## Follows PREVIEWS MUST = GAME REALITY rule.

var _doodads: Array = []  # Array of doodad dicts from LevelData
var _cull_y_min: float = -INF  # Optional Y culling range (level-space)
var _cull_y_max: float = INF
var _selected_idx: int = -1  # Highlight selected doodad in editor
var show_editor_markers: bool = false  # Show bright markers around doodads for editor visibility


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

		var center := Vector2(dd_x, dd_y)
		var base_size: float = 40.0 * dd_scale

		# Editor markers: bright ring so doodads are visible against any background
		if show_editor_markers:
			var marker_r: float = base_size * 0.8
			var is_selected: bool = (_doodads.find(dd) == _selected_idx)
			if is_selected:
				draw_arc(center, marker_r + 4, 0.0, TAU, 24, Color(0.2, 1.0, 0.4, 0.8), 2.0)
				draw_arc(center, marker_r + 8, 0.0, TAU, 24, Color(0.2, 1.0, 0.4, 0.3), 1.0)
			else:
				draw_arc(center, marker_r, 0.0, TAU, 20, Color(0.4, 0.8, 0.3, 0.4), 1.0)

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
	var leg_h: float = r * 0.8
	var tank_col := Color(0.3, 0.28, 0.25)
	var leg_col := Color(0.2, 0.18, 0.16)
	# Support legs (X shape)
	draw_line(center + Vector2(-r * 0.7, leg_h), center + Vector2(r * 0.3, -leg_h * 0.2), leg_col, 2.0)
	draw_line(center + Vector2(r * 0.7, leg_h), center + Vector2(-r * 0.3, -leg_h * 0.2), leg_col, 2.0)
	# Tank body
	draw_circle(center - Vector2(0, leg_h * 0.2), r, tank_col)
	# Highlight ring
	draw_arc(center - Vector2(0, leg_h * 0.2), r * 0.7, 0.0, TAU, 16, Color(0.4, 0.37, 0.33), 2.0)
	# Top cap
	draw_circle(center - Vector2(0, leg_h * 0.2), r * 0.3, Color(0.25, 0.23, 0.2))


func _draw_antenna(center: Vector2, size: float) -> void:
	var h: float = size
	var pole_col := Color(0.35, 0.3, 0.28)
	var wire_col := Color(0.25, 0.22, 0.2)
	# Pole
	draw_line(center + Vector2(0, h * 0.5), center - Vector2(0, h * 0.5), pole_col, 2.5)
	# Cross bars
	for i in range(4):
		var y_off: float = -h * 0.2 + float(i) * h * 0.2
		var bar_w: float = h * 0.35 - float(i) * h * 0.06
		draw_line(center + Vector2(-bar_w, y_off), center + Vector2(bar_w, y_off), wire_col, 1.5)
	# Red light at top
	draw_circle(center - Vector2(0, h * 0.5), 3.0, Color(1.0, 0.15, 0.1, 0.9))
	# Guy wires (support cables from top to base)
	draw_line(center - Vector2(0, h * 0.45), center + Vector2(-h * 0.4, h * 0.5), Color(wire_col, 0.4), 1.0)
	draw_line(center - Vector2(0, h * 0.45), center + Vector2(h * 0.4, h * 0.5), Color(wire_col, 0.4), 1.0)


func _draw_satellite_dish(center: Vector2, size: float) -> void:
	var r: float = size * 0.5
	var dish_col := Color(0.35, 0.33, 0.38)
	# Dish body (filled arc approximation)
	draw_circle(center, r, Color(0.2, 0.2, 0.24))
	draw_arc(center, r, -0.3, PI + 0.3, 20, dish_col, 2.5)
	draw_arc(center, r * 0.7, -0.2, PI + 0.2, 16, Color(0.28, 0.27, 0.3), 1.5)
	# Feed arm
	draw_line(center, center + Vector2(r * 0.5, -r * 0.7), Color(0.3, 0.28, 0.25), 2.0)
	# Feed horn
	draw_circle(center + Vector2(r * 0.5, -r * 0.7), r * 0.12, Color(0.4, 0.35, 0.3))
	# Base mount
	draw_circle(center, r * 0.15, Color(0.25, 0.23, 0.22))


func _draw_ac_cluster(center: Vector2, size: float) -> void:
	var s: float = size * 0.4
	var unit_col := Color(0.28, 0.3, 0.32)
	var vent_col := Color(0.15, 0.15, 0.17)
	var frame_col := Color(0.35, 0.35, 0.38)
	for i in range(3):
		var offset := Vector2((float(i) - 1.0) * s * 1.2, 0.0)
		var r := Rect2(center + offset - Vector2(s * 0.5, s * 0.4), Vector2(s, s * 0.8))
		draw_rect(r, unit_col)
		draw_rect(r, frame_col, false, 1.5)
		draw_circle(center + offset, s * 0.22, vent_col)
		draw_arc(center + offset, s * 0.2, 0, TAU, 8, frame_col, 1.0)


func _draw_solar_panels(center: Vector2, size: float) -> void:
	var s: float = size * 0.4
	var panel_col := Color(0.08, 0.1, 0.25)
	var frame_col := Color(0.2, 0.2, 0.25)
	var glint_col := Color(0.15, 0.18, 0.4)
	for py in range(3):
		for px in range(2):
			var offset := Vector2(
				(float(px) - 0.5) * (s + 2.0),
				(float(py) - 1.0) * (s * 0.7 + 2.0)
			)
			var r := Rect2(center + offset - Vector2(s * 0.5, s * 0.3), Vector2(s, s * 0.6))
			draw_rect(r, panel_col)
			draw_rect(r, frame_col, false, 1.5)
			# Glint line across panel
			draw_line(r.position + Vector2(2, r.size.y * 0.3), r.position + Vector2(r.size.x - 2, r.size.y * 0.3), glint_col, 1.0)


func _draw_rooftop_garden(center: Vector2, size: float) -> void:
	var s: float = size * 0.5
	var planter_col := Color(0.15, 0.1, 0.06)
	var green_col := Color(0.06, 0.18, 0.06)
	var r := Rect2(center - Vector2(s * 0.8, s * 0.6), Vector2(s * 1.6, s * 1.2))
	draw_rect(r, planter_col)
	draw_rect(r, Color(0.2, 0.15, 0.1), false, 1.5)
	var inner := Rect2(r.position + Vector2(2.5, 2.5), r.size - Vector2(5.0, 5.0))
	draw_rect(inner, green_col)
	# Tree canopies
	draw_circle(center + Vector2(-s * 0.3, -s * 0.1), s * 0.25, Color(0.05, 0.2, 0.05))
	draw_circle(center + Vector2(s * 0.25, s * 0.15), s * 0.2, Color(0.07, 0.16, 0.05))
	draw_circle(center + Vector2(s * 0.0, s * 0.3), s * 0.15, Color(0.04, 0.15, 0.04))


func _draw_crate_stack(center: Vector2, size: float) -> void:
	var s: float = size * 0.45
	var crate_col := Color(0.2, 0.15, 0.08)
	var strap_col := Color(0.28, 0.2, 0.12)
	var edge_col := Color(0.25, 0.18, 0.1)
	# Bottom row (2 crates)
	for i in range(2):
		var offset := Vector2((float(i) - 0.5) * s * 1.15, s * 0.35)
		var r := Rect2(center + offset - Vector2(s * 0.5, s * 0.45), Vector2(s, s * 0.9))
		draw_rect(r, crate_col)
		draw_rect(r, edge_col, false, 1.5)
		draw_line(r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, r.size.y), strap_col, 1.5)
	# Top crate (offset)
	var top_r := Rect2(center - Vector2(s * 0.45, s * 0.65), Vector2(s * 0.9, s * 0.8))
	draw_rect(top_r, crate_col * 1.15)
	draw_rect(top_r, edge_col, false, 1.5)
	draw_line(top_r.position + Vector2(top_r.size.x * 0.5, 0), top_r.position + Vector2(top_r.size.x * 0.5, top_r.size.y), strap_col, 1.5)


func _draw_vent_pipe(center: Vector2, size: float) -> void:
	var r: float = size * 0.3
	var pipe_col := Color(0.25, 0.25, 0.28)
	var dark_col := Color(0.08, 0.08, 0.1)
	var rim_col := Color(0.32, 0.32, 0.35)
	# Main pipe circle
	draw_circle(center, r, pipe_col)
	draw_circle(center, r * 0.6, dark_col)
	draw_arc(center, r * 0.95, 0.0, TAU, 16, rim_col, 2.0)
	# Second pipe nearby
	var offset := Vector2(r * 2.5, r * 0.5)
	draw_circle(center + offset, r * 0.75, pipe_col)
	draw_circle(center + offset, r * 0.45, dark_col)
	draw_arc(center + offset, r * 0.7, 0.0, TAU, 12, rim_col, 1.5)
	# Third small pipe
	var offset2 := Vector2(-r * 1.5, r * 1.8)
	draw_circle(center + offset2, r * 0.5, pipe_col)
	draw_circle(center + offset2, r * 0.3, dark_col)
