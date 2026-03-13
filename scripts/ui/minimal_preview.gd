extends PreviewBase
## Variation 4: MINIMAL — Single-pass thin 1px antialiased lines, subtle alpha pulse.


func _draw() -> void:
	var alpha := 0.3 + _pulse_t * 0.08
	var grid_col := Color(0.4, 0.4, 0.5, alpha * 0.4)
	draw_grid(grid_col)

	var line_alpha := 0.6 + _pulse_t * 0.15
	var cyan := Color(0.0, 1.0, 1.0, line_alpha)
	var red := Color(1.0, 0.3, 0.3, line_alpha)
	var white := Color(0.8, 0.8, 0.9, line_alpha)

	# Ship
	draw_polyline(closed_poly(offset_points(SHIP_POINTS, ship_pos)), cyan, 1.0, true)

	# Enemy
	draw_polyline(closed_poly(offset_points(ENEMY_POINTS, enemy_pos)), red, 1.0, true)

	# Projectile
	var pr := PROJECTILE_RECT
	var proj_pts := PackedVector2Array([
		projectile_pos + Vector2(pr.position.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y),
	])
	draw_polyline(proj_pts, white, 1.0, true)
