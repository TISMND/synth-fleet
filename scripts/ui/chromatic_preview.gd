extends PreviewBase
## Variation 3: CHROMATIC — _draw() with hue-shift shader.

var _shader_mat: ShaderMaterial


func _ready() -> void:
	super._ready()
	var shader := load("res://resources/shaders/chromatic_wireframe.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	material = _shader_mat


func _process(delta: float) -> void:
	super._process(delta)
	_shader_mat.set_shader_parameter("time_offset", _time)
	_shader_mat.set_shader_parameter("pulse", _pulse_t)


func _draw() -> void:
	var grid_col := Color(1.0, 1.0, 1.0, 0.12 + _pulse_t * 0.06)
	draw_grid(grid_col)

	var line_col := Color(1.0, 1.0, 1.0, 0.9 + _pulse_t * 0.1)
	var width := 2.5 + _pulse_t * 1.0

	# Ship
	draw_polyline(closed_poly(offset_points(SHIP_POINTS, ship_pos)), line_col, width, true)

	# Enemy
	draw_polyline(closed_poly(offset_points(ENEMY_POINTS, enemy_pos)), line_col, width, true)

	# Projectile
	var pr := PROJECTILE_RECT
	var proj_pts := PackedVector2Array([
		projectile_pos + Vector2(pr.position.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y),
	])
	draw_polyline(proj_pts, line_col, width, true)
