extends PreviewBase
## Variation 2: SOFT BLOOM — Line2D nodes with gradient resources.

var _line_nodes: Array[Line2D] = []


func _ready() -> void:
	super._ready()
	_create_line2d_shapes()


func _process(delta: float) -> void:
	super._process(delta)
	_update_line_widths()


func _draw() -> void:
	var grid_col := Color(0.0, 0.5, 0.5, 0.12 + _pulse_t * 0.04)
	draw_grid(grid_col)


func _create_line2d_shapes() -> void:
	# Gradient: cyan -> magenta
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 1.0, 1.0))
	grad.add_point(0.5, Color(0.5, 0.0, 1.0))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.0, 0.8))

	# Ship — soft glow layer underneath + crisp layer on top
	_add_bloom_shape(closed_poly(offset_points(SHIP_POINTS, ship_pos)), grad, true)
	# Enemy
	_add_bloom_shape(closed_poly(offset_points(ENEMY_POINTS, enemy_pos)), grad, true)
	# Projectile
	var pr := PROJECTILE_RECT
	var proj_pts := PackedVector2Array([
		projectile_pos + Vector2(pr.position.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y),
	])
	_add_bloom_shape(proj_pts, grad, true)


func _add_bloom_shape(points: PackedVector2Array, grad: Gradient, with_glow: bool) -> void:
	if with_glow:
		# Wide soft glow layer
		var glow_line := Line2D.new()
		glow_line.points = points
		glow_line.width = 12.0
		glow_line.default_color = Color(0.3, 0.8, 1.0, 0.15)
		glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
		glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow_line.material = glow_mat
		add_child(glow_line)
		_line_nodes.append(glow_line)

	# Crisp gradient line on top
	var line := Line2D.new()
	line.points = points
	line.width = 3.0
	line.gradient = grad
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	_line_nodes.append(line)


func _update_line_widths() -> void:
	var pulse := _pulse_t
	for i in range(_line_nodes.size()):
		var line := _line_nodes[i]
		if line.gradient != null:
			# Crisp line — slight width pulse
			line.width = 3.0 + pulse * 2.0
		else:
			# Glow line — wider pulse
			line.width = 12.0 + pulse * 8.0
			line.default_color.a = 0.15 + pulse * 0.1
