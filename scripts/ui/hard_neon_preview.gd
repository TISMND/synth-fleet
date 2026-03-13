extends PreviewBase
## Variation 1: HARD NEON — Multi-pass glow polylines with additive blending.

var _additive_mat: CanvasItemMaterial


func _ready() -> void:
	super._ready()
	_additive_mat = CanvasItemMaterial.new()
	_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_mat


func _draw() -> void:
	var grid_col := Color(0.0, 0.3, 0.6, 0.15 + _pulse_t * 0.05)
	draw_grid(grid_col)

	var pulse := _pulse_t
	var base_cyan := Color(0.0, 1.0, 1.0)
	var base_red := Color(1.0, 0.3, 0.3)
	var base_magenta := Color(1.0, 0.0, 0.8)

	# Ship
	_draw_neon_poly(closed_poly(offset_points(SHIP_POINTS, ship_pos)), base_cyan, pulse)

	# Enemy
	_draw_neon_poly(closed_poly(offset_points(ENEMY_POINTS, enemy_pos)), base_red, pulse)

	# Projectile — draw as rect outline
	var pr := PROJECTILE_RECT
	var proj_points := PackedVector2Array([
		projectile_pos + Vector2(pr.position.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y),
	])
	_draw_neon_poly(proj_points, base_magenta, pulse)


## Draw a polyline with multi-pass glow effect.
func _draw_neon_poly(points: PackedVector2Array, color: Color, pulse: float) -> void:
	if points.size() < 2:
		return

	var glow_extra := pulse * 4.0

	# Outer glow passes (wide, low alpha)
	var outer_col := Color(color.r, color.g, color.b, 0.05 + pulse * 0.03)
	draw_polyline(points, outer_col, 16.0 + glow_extra, true)

	outer_col.a = 0.08 + pulse * 0.04
	draw_polyline(points, outer_col, 10.0 + glow_extra * 0.7, true)

	# Mid glow
	var mid_col := Color(color.r, color.g, color.b, 0.15 + pulse * 0.08)
	draw_polyline(points, mid_col, 6.0 + glow_extra * 0.4, true)

	# Core line (bright)
	var core_col := Color(color.r, color.g, color.b, 0.8 + pulse * 0.2)
	draw_polyline(points, core_col, 2.0, true)
