extends Control
## Visual showcase screen: a hand-drawn synthwave ship with neon glow.
## Tab toggles between NEON and CHROME rendering modes.

const MOVE_ACCEL := 1200.0
const MOVE_DECEL := 800.0
const MAX_SPEED := 400.0
const BANK_LERP := 6.0

var _velocity := 0.0
var _velocity_y := 0.0
var _bank := 0.0
var _ship_draw: Node2D
var _exhaust_draw: Node2D
var _exhaust_particles: Array[Dictionary] = []
var _exhaust_timer := 0.0
var _ship_selector: Node2D
var _selected_ship := 0
var _vhs_overlay: ColorRect


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	ThemeManager.apply_grid_background($Background)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_exhaust_draw = _ExhaustDraw.new()
	_exhaust_draw.viewer = self
	add_child(_exhaust_draw)

	_ship_draw = _ShipDraw.new()
	add_child(_ship_draw)

	_ship_selector = _ShipSelector.new()
	_ship_selector.viewer = self
	add_child(_ship_selector)

	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.5)


func _process(delta: float) -> void:
	var input_dir := 0.0
	if Input.is_action_pressed("move_left"):
		input_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir += 1.0

	var input_dir_y := 0.0
	if Input.is_action_pressed("move_up"):
		input_dir_y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir_y += 1.0

	if input_dir != 0.0:
		_velocity = move_toward(_velocity, input_dir * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity = move_toward(_velocity, 0.0, MOVE_DECEL * delta)

	if input_dir_y != 0.0:
		_velocity_y = move_toward(_velocity_y, input_dir_y * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity_y = move_toward(_velocity_y, 0.0, MOVE_DECEL * delta)

	_ship_draw.position.x += _velocity * delta
	_ship_draw.position.y += _velocity_y * delta
	var vp_size: Vector2 = get_viewport_rect().size
	_ship_draw.position.x = clampf(_ship_draw.position.x, 60.0, vp_size.x - 60.0)
	_ship_draw.position.y = clampf(_ship_draw.position.y, 60.0, vp_size.y - 60.0)

	var target_bank: float = -_velocity / MAX_SPEED
	_bank = lerpf(_bank, target_bank, BANK_LERP * delta)
	_ship_draw.bank = _bank
	_ship_draw.ship_id = _selected_ship
	_ship_draw._time += delta
	_ship_draw.queue_redraw()

	_exhaust_timer += delta
	if _exhaust_timer > 0.016:
		_exhaust_timer = 0.0
		_spawn_exhaust()
	_update_exhaust(delta)
	_exhaust_draw.queue_redraw()


func _spawn_exhaust() -> void:
	var ship_pos: Vector2 = _ship_draw.position
	var s: float = _ShipDraw.get_ship_scale(_selected_ship)
	var x_shift: float = _bank * 2.5 * s
	var engines: Array[Vector2] = _ShipDraw.get_engine_offsets(_selected_ship)
	for eng in engines:
		var ex: float = eng.x
		var ey: float = eng.y
		var side_factor: float = signf(ex) if ex != 0.0 else 0.0
		var banked_x: float = ex * (1.0 + _bank * side_factor * 0.15) * s + x_shift
		var local_pos := Vector2(banked_x, ey * s)
		var world_pos: Vector2 = ship_pos + local_pos
		_exhaust_particles.append({
			"pos": world_pos,
			"vel": Vector2(randf_range(-15.0, 15.0), randf_range(80.0, 160.0)),
			"life": 1.0,
			"max_life": 1.0,
			"size": randf_range(2.0, 4.5),
		})


func _update_exhaust(delta: float) -> void:
	var i := 0
	while i < _exhaust_particles.size():
		var p: Dictionary = _exhaust_particles[i]
		var life: float = p["life"]
		life -= delta * 1.5
		p["life"] = life
		if life <= 0.0:
			_exhaust_particles.remove_at(i)
			continue
		var vel: Vector2 = p["vel"]
		var pos: Vector2 = p["pos"]
		pos += vel * delta
		p["pos"] = pos
		i += 1


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_grid_background($Background)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_TAB:
			if _ship_draw.render_mode == _ShipDraw.RenderMode.NEON:
				_ship_draw.render_mode = _ShipDraw.RenderMode.CHROME
			else:
				_ship_draw.render_mode = _ShipDraw.RenderMode.NEON
			_ship_selector.render_mode = _ship_draw.render_mode
			_ship_draw.queue_redraw()
			_ship_selector.queue_redraw()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var vp_size: Vector2 = get_viewport_rect().size
			var bar_y: float = vp_size.y - _ShipSelector.BAR_HEIGHT
			if mb.position.y >= bar_y:
				var slot: int = _ship_selector.get_slot_at(mb.position.x, vp_size.x)
				if slot >= 0 and slot < _ShipSelector.SHIP_COUNT:
					_selected_ship = slot
					_exhaust_particles.clear()
					_ship_selector.queue_redraw()


# ── Ship Drawing (inner class) ───────────────────────────────

class _ShipDraw extends Node2D:
	enum RenderMode { NEON, CHROME }

	const CHROME_DARK := Color(0.12, 0.13, 0.18)
	const CHROME_MID := Color(0.35, 0.38, 0.45)
	const CHROME_LIGHT := Color(0.65, 0.70, 0.80)
	const CHROME_BRIGHT := Color(0.85, 0.88, 0.95)
	const CHROME_SPEC := Color(1.0, 1.0, 1.0, 0.9)

	var hull_color := Color(0.0, 0.9, 1.0)
	var accent_color := Color(1.0, 0.2, 0.6)
	var engine_color := Color(1.0, 0.5, 0.1)
	var canopy_color := Color(0.4, 0.2, 1.0)
	var detail_color := Color(0.0, 1.0, 0.7)
	var bank := 0.0
	var ship_id := 0
	var render_mode: int = RenderMode.NEON
	var _time := 0.0

	func _bx(x: float, s: float, intensity: float) -> float:
		var sf: float = signf(x) if x != 0.0 else 0.0
		return x * (1.0 + bank * sf * intensity) * s

	func _bp(x: float, y: float, s: float, intensity: float) -> Vector2:
		return Vector2(_bx(x, s, intensity) + bank * 2.5 * s, y * s)

	func _side_color(base: Color, side: float) -> Color:
		var col := base
		col.a = clampf(col.a + bank * side * 0.06, 0.5, 1.0)
		return col

	static func get_ship_scale(id: int) -> float:
		match id:
			0: return 1.2
			6: return 1.7
			7: return 1.9
			8: return 1.8
		return 1.4

	static func get_engine_offsets(id: int) -> Array[Vector2]:
		match id:
			0: return [Vector2(-3.0, 22.0), Vector2(3.0, 22.0)]
			1: return [Vector2(-5.0, 24.0), Vector2(5.0, 24.0)]
			2: return [Vector2(-8.0, 20.0), Vector2(8.0, 20.0)]
			3: return [Vector2(3.0, 24.0), Vector2(-17.0, 22.0)]
			4: return [Vector2(-4.0, 24.0), Vector2(4.0, 24.0)]
			5: return [Vector2(-13.0, 28.0), Vector2(0.0, 28.0), Vector2(13.0, 28.0)]
			6: return [Vector2(-6.0, 22.0), Vector2(0.0, 24.0), Vector2(6.0, 22.0)]
			7: return [Vector2(-14.0, 40.0), Vector2(-10.0, 40.0), Vector2(-6.0, 40.0), Vector2(-2.0, 40.0), Vector2(2.0, 40.0), Vector2(6.0, 40.0), Vector2(10.0, 40.0), Vector2(14.0, 40.0)]
			8: return [Vector2(-12.0, 34.0), Vector2(-4.0, 34.0), Vector2(4.0, 34.0), Vector2(12.0, 34.0)]
		return [Vector2(0.0, 30.0)]

	# ── Dispatch helpers ──

	func _poly(points: PackedVector2Array, color: Color, width: float) -> void:
		if render_mode == RenderMode.CHROME:
			_draw_chrome_polygon(points, color, bank)
		else:
			_draw_neon_polygon(points, color, width)

	func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		if render_mode == RenderMode.CHROME:
			_draw_chrome_line(a, b, color, width)
		else:
			_draw_neon_line(a, b, color, width)

	func _canopy(points: PackedVector2Array) -> void:
		if render_mode == RenderMode.CHROME:
			_draw_chrome_canopy(points, bank)
		else:
			var cf := canopy_color
			cf.a = 0.3
			draw_colored_polygon(points, cf)
			_draw_neon_lines(points, canopy_color, 1.2 * 1.4)

	func _exhaust_line(a: Vector2, b: Vector2, width: float) -> void:
		var exhaust := Color(1.0, 0.8, 0.3, 0.8)
		if render_mode == RenderMode.CHROME:
			_draw_chrome_line(a, b, exhaust, width)
		else:
			_draw_neon_line(a, b, exhaust, width)

	func _draw() -> void:
		match ship_id:
			0: _draw_switchblade()
			1: _draw_phantom()
			2: _draw_mantis()
			3: _draw_corsair()
			4: _draw_stiletto()
			5: _draw_trident()
			6: _draw_orrery()
			7: _draw_dreadnought()
			8: _draw_bastion()

	# ── Chrome drawing helpers ──

	func _draw_chrome_polygon(points: PackedVector2Array, tint_color: Color, bk: float) -> void:
		if points.size() < 3:
			return
		# Dark base fill
		draw_colored_polygon(points, CHROME_DARK)

		# Compute bounding box for horizontal gradient bands
		var min_y := points[0].y
		var max_y := points[0].y
		var min_x := points[0].x
		var max_x := points[0].x
		for pt in points:
			min_y = minf(min_y, pt.y)
			max_y = maxf(max_y, pt.y)
			min_x = minf(min_x, pt.x)
			max_x = maxf(max_x, pt.x)
		var height: float = max_y - min_y
		var width: float = max_x - min_x
		if height < 0.5 or width < 0.5:
			return

		# Horizontal gradient bands — bottom dark, top bright (overhead light)
		var band_colors: Array[Color] = [
			CHROME_DARK.lerp(CHROME_MID, 0.3),
			CHROME_MID,
			CHROME_LIGHT,
			CHROME_BRIGHT,
		]
		var band_count: int = band_colors.size()
		for i in range(band_count):
			var t0: float = float(i) / float(band_count)
			var t1: float = float(i + 1) / float(band_count)
			var y0: float = max_y - t0 * height  # bottom to top
			var y1: float = max_y - t1 * height
			var band_rect := PackedVector2Array([
				Vector2(min_x - 5.0, y0),
				Vector2(max_x + 5.0, y0),
				Vector2(max_x + 5.0, y1),
				Vector2(min_x - 5.0, y1),
			])
			var clipped: Array = Geometry2D.intersect_polygons(points, band_rect)
			for clip_idx in range(clipped.size()):
				var clip_poly: PackedVector2Array = clipped[clip_idx]
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, band_colors[i])

		# Bank-reactive left/right shading — brighten facing side
		var center_x: float = (min_x + max_x) * 0.5
		var left_rect := PackedVector2Array([
			Vector2(min_x - 5.0, min_y - 5.0),
			Vector2(center_x, min_y - 5.0),
			Vector2(center_x, max_y + 5.0),
			Vector2(min_x - 5.0, max_y + 5.0),
		])
		var right_rect := PackedVector2Array([
			Vector2(center_x, min_y - 5.0),
			Vector2(max_x + 5.0, min_y - 5.0),
			Vector2(max_x + 5.0, max_y + 5.0),
			Vector2(center_x, max_y + 5.0),
		])

		# When banking right (bk < 0), left side faces us = brighter
		var left_alpha: float = clampf(-bk * 0.15, -0.08, 0.15)
		var right_alpha: float = clampf(bk * 0.15, -0.08, 0.15)
		if left_alpha > 0.01:
			var left_clips: Array = Geometry2D.intersect_polygons(points, left_rect)
			for clip_idx in range(left_clips.size()):
				var clip_poly: PackedVector2Array = left_clips[clip_idx]
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, left_alpha))
		elif left_alpha < -0.01:
			var left_clips: Array = Geometry2D.intersect_polygons(points, left_rect)
			for clip_idx in range(left_clips.size()):
				var clip_poly: PackedVector2Array = left_clips[clip_idx]
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, Color(0.0, 0.0, 0.0, -left_alpha))
		if right_alpha > 0.01:
			var right_clips: Array = Geometry2D.intersect_polygons(points, right_rect)
			for clip_idx in range(right_clips.size()):
				var clip_poly: PackedVector2Array = right_clips[clip_idx]
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, right_alpha))
		elif right_alpha < -0.01:
			var right_clips: Array = Geometry2D.intersect_polygons(points, right_rect)
			for clip_idx in range(right_clips.size()):
				var clip_poly: PackedVector2Array = right_clips[clip_idx]
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, Color(0.0, 0.0, 0.0, -right_alpha))

		# Specular highlight — soft gradient gleam that slides with bank
		var spec_x: float = center_x + bk * width * 0.4 + sin(_time * 0.8) * width * 0.05
		var spec_brightness: float = 0.9 + sin(_time * 1.2) * 0.1
		# Draw multiple overlapping strips from wide/faint to narrow/bright
		var gleam_layers: Array[Array] = [
			[width * 0.22, 0.06],   # widest, faintest
			[width * 0.14, 0.12],
			[width * 0.08, 0.20],
			[width * 0.03, 0.35],   # narrowest, brightest
		]
		for layer in gleam_layers:
			var half_w: float = layer[0]
			var alpha: float = layer[1] * spec_brightness
			var strip := PackedVector2Array([
				Vector2(spec_x - half_w, min_y - 5.0),
				Vector2(spec_x + half_w, min_y - 5.0),
				Vector2(spec_x + half_w, max_y + 5.0),
				Vector2(spec_x - half_w, max_y + 5.0),
			])
			var strip_clips: Array = Geometry2D.intersect_polygons(points, strip)
			for clip_idx in range(strip_clips.size()):
				var clip_poly: PackedVector2Array = strip_clips[clip_idx]
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, alpha))

		# Subtle color tint overlay from original weapon color
		var tint := tint_color
		tint.a = 0.08
		draw_colored_polygon(points, tint)

		# Chrome edges — hard rim lighting
		_draw_chrome_edges(points, bk)

	func _draw_chrome_edges(points: PackedVector2Array, bk: float) -> void:
		if points.size() < 2:
			return
		var light_dir := Vector2(bk * 0.7, -1.0).normalized()
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			var a: Vector2 = points[i]
			var b: Vector2 = points[ni]
			var edge_dir: Vector2 = (b - a).normalized()
			var edge_normal := Vector2(-edge_dir.y, edge_dir.x)
			var facing: float = edge_normal.dot(light_dir)
			var brightness: float = clampf(facing * 0.5 + 0.5, 0.15, 1.0)
			var edge_col := CHROME_DARK.lerp(CHROME_SPEC, brightness)
			edge_col.a = 0.6 + brightness * 0.4
			draw_line(a, b, edge_col, 1.5, true)

	func _draw_chrome_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		# Shadow offset
		var perp: Vector2 = (b - a).normalized()
		perp = Vector2(-perp.y, perp.x)
		var shadow_off: Vector2 = perp * 1.0
		draw_line(a + shadow_off, b + shadow_off, CHROME_DARK, width * 1.2, true)
		# Bright highlight offset
		draw_line(a - shadow_off, b - shadow_off, CHROME_BRIGHT, width * 0.8, true)
		# Core mid-tone with color tint
		var mid := CHROME_MID.lerp(color, 0.15)
		draw_line(a, b, mid, width, true)
		# Hot specular center
		var spec_brightness: float = 0.9 + sin(_time * 1.2) * 0.1
		var spec := CHROME_SPEC
		spec.a = 0.4 * spec_brightness
		draw_line(a, b, spec, width * 0.3, true)

	func _draw_chrome_canopy(points: PackedVector2Array, bk: float) -> void:
		if points.size() < 3:
			return
		# Dark blue-tinted glass fill
		var glass := Color(0.05, 0.08, 0.2, 0.85)
		draw_colored_polygon(points, glass)
		# Bright rim on canopy edges
		_draw_chrome_edges(points, bk)

	# ── Ship 0: Switchblade — V-scissors opening forward ──
	func _draw_switchblade() -> void:
		var s := 1.2
		var ry: float = -bank * 1.6 * s
		var ly: float = bank * 1.6 * s

		# Right blade — thick geometric slab, sharp angles
		var r_blade := PackedVector2Array([
			_bp(3, 16, s, 0.1),
			_bp(4, 4, s, 0.15) + Vector2(0, ry * 0.1),
			_bp(10, -14, s, 0.22) + Vector2(0, ry * 0.4),
			_bp(16, -32, s, 0.26) + Vector2(0, ry * 0.8),
			_bp(22, -36, s, 0.28) + Vector2(0, ry),
			_bp(20, -24, s, 0.26) + Vector2(0, ry * 0.8),
			_bp(16, -8, s, 0.2) + Vector2(0, ry * 0.4),
			_bp(12, 6, s, 0.15) + Vector2(0, ry * 0.15),
			_bp(8, 16, s, 0.1),
		])
		_poly(r_blade, _side_color(hull_color, 1.0), 1.5 * s)

		# Left blade — mirror
		var l_blade := PackedVector2Array([
			_bp(-3, 16, s, 0.1),
			_bp(-4, 4, s, 0.15) + Vector2(0, ly * 0.1),
			_bp(-10, -14, s, 0.22) + Vector2(0, ly * 0.4),
			_bp(-16, -32, s, 0.26) + Vector2(0, ly * 0.8),
			_bp(-22, -36, s, 0.28) + Vector2(0, ly),
			_bp(-20, -24, s, 0.26) + Vector2(0, ly * 0.8),
			_bp(-16, -8, s, 0.2) + Vector2(0, ly * 0.4),
			_bp(-12, 6, s, 0.15) + Vector2(0, ly * 0.15),
			_bp(-8, 16, s, 0.1),
		])
		_poly(l_blade, _side_color(hull_color, -1.0), 1.5 * s)

		# Central diamond hub at rear
		var hub := PackedVector2Array([
			_bp(0, 2, s, 0.06),
			_bp(7, 14, s, 0.06),
			_bp(0, 24, s, 0.06),
			_bp(-7, 14, s, 0.06),
		])
		_poly(hub, hull_color, 1.8 * s)

		# Diamond canopy in hub
		var cx: float = -bank * 1.0 * s
		var can := PackedVector2Array([
			_bp(0, 6, s, 0.04) + Vector2(cx, 0),
			_bp(4, 12, s, 0.04) + Vector2(cx, 0),
			_bp(0, 18, s, 0.04) + Vector2(cx, 0),
			_bp(-4, 12, s, 0.04) + Vector2(cx, 0),
		])
		_canopy(can)

		# Blade spine accents (center ridge of each blade)
		_line(
			_bp(6, 10, s, 0.12) + Vector2(0, ry * 0.1),
			_bp(18, -28, s, 0.24) + Vector2(0, ry * 0.8),
			detail_color, 0.8 * s)
		_line(
			_bp(-6, 10, s, 0.12) + Vector2(0, ly * 0.1),
			_bp(-18, -28, s, 0.24) + Vector2(0, ly * 0.8),
			detail_color, 0.8 * s)
		# Cross-brace between blades
		_line(
			_bp(8, -4, s, 0.18) + Vector2(0, ry * 0.25),
			_bp(-8, -4, s, 0.18) + Vector2(0, ly * 0.25),
			detail_color, 0.6 * s)

		# Spine through hub
		_line(_bp(0, 6, s, 0.06), _bp(0, 20, s, 0.06), accent_color, 1.0 * s)

		# Twin engines at base of hub
		_exhaust_line(_bp(-3, 22, s, 0.06), _bp(-3, 28, s, 0.06), 2.5 * s)
		_exhaust_line(_bp(3, 22, s, 0.06), _bp(3, 28, s, 0.06), 2.5 * s)

	# ── Ship 1: Phantom — smooth curved stealth fighter ──
	func _draw_phantom() -> void:
		var s := 1.4
		var ry: float = -bank * 1.0 * s
		var ly: float = bank * 1.0 * s

		# Smooth teardrop hull (many vertices for curves)
		var hull := PackedVector2Array([
			_bp(0, -36, s, 0.06), _bp(6, -28, s, 0.06),
			_bp(10, -16, s, 0.08), _bp(14, -4, s, 0.08),
			_bp(16, 8, s, 0.08), _bp(12, 20, s, 0.08),
			_bp(6, 26, s, 0.06), _bp(-6, 26, s, 0.06),
			_bp(-12, 20, s, 0.08), _bp(-16, 8, s, 0.08),
			_bp(-14, -4, s, 0.08), _bp(-10, -16, s, 0.08),
			_bp(-6, -28, s, 0.06),
		])
		_poly(hull, hull_color, 2.0 * s)

		# Subtle blended wing stubs
		var rw := PackedVector2Array([
			_bp(14, -2, s, 0.18) + Vector2(0, ry * 0.4),
			_bp(22, 4, s, 0.18) + Vector2(0, ry),
			_bp(20, 10, s, 0.18) + Vector2(0, ry),
			_bp(14, 8, s, 0.18) + Vector2(0, ry * 0.4),
		])
		_poly(rw, _side_color(hull_color, 1.0), 1.2 * s)
		var lw := PackedVector2Array([
			_bp(-14, -2, s, 0.18) + Vector2(0, ly * 0.4),
			_bp(-22, 4, s, 0.18) + Vector2(0, ly),
			_bp(-20, 10, s, 0.18) + Vector2(0, ly),
			_bp(-14, 8, s, 0.18) + Vector2(0, ly * 0.4),
		])
		_poly(lw, _side_color(hull_color, -1.0), 1.2 * s)

		# Recessed elongated canopy
		var cx: float = -bank * 1.2 * s
		var can := PackedVector2Array([
			_bp(0, -30, s, 0.04) + Vector2(cx, 0),
			_bp(4, -18, s, 0.04) + Vector2(cx, 0),
			_bp(3, -8, s, 0.04) + Vector2(cx, 0),
			_bp(-3, -8, s, 0.04) + Vector2(cx, 0),
			_bp(-4, -18, s, 0.04) + Vector2(cx, 0),
		])
		_canopy(can)

		# Flowing contour lines
		_line(_bp(8, -22, s, 0.06), _bp(14, 2, s, 0.08), detail_color, 0.7 * s)
		_line(_bp(-8, -22, s, 0.06), _bp(-14, 2, s, 0.08), detail_color, 0.7 * s)
		_line(_bp(12, 10, s, 0.08), _bp(6, 22, s, 0.06), detail_color, 0.7 * s)
		_line(_bp(-12, 10, s, 0.08), _bp(-6, 22, s, 0.06), detail_color, 0.7 * s)

		# Spine accent
		_line(_bp(0, -6, s, 0.06), _bp(0, 22, s, 0.06), accent_color, 1.0 * s)

		# Twin buried engines
		_exhaust_line(_bp(-5, 24, s, 0.06), _bp(-5, 32, s, 0.06), 3.0 * s)
		_exhaust_line(_bp(5, 24, s, 0.06), _bp(5, 32, s, 0.06), 3.0 * s)

	# ── Ship 2: Mantis — flying wing ──
	func _draw_mantis() -> void:
		var s := 1.4
		var ry: float = -bank * 1.5 * s
		var ly: float = bank * 1.5 * s

		# Right half of chevron wing
		var r_wing := PackedVector2Array([
			_bp(0, -28, s, 0.08),
			_bp(10, -14, s, 0.25) + Vector2(0, ry),
			_bp(44, 8, s, 0.25) + Vector2(0, ry),
			_bp(40, 14, s, 0.25) + Vector2(0, ry),
			_bp(14, 10, s, 0.2) + Vector2(0, ry * 0.5),
			_bp(8, 18, s, 0.08),
			_bp(0, 18, s, 0.08),
		])
		_poly(r_wing, _side_color(hull_color, 1.0), 1.8 * s)

		# Left half of chevron wing
		var l_wing := PackedVector2Array([
			_bp(0, -28, s, 0.08),
			_bp(-10, -14, s, 0.25) + Vector2(0, ly),
			_bp(-44, 8, s, 0.25) + Vector2(0, ly),
			_bp(-40, 14, s, 0.25) + Vector2(0, ly),
			_bp(-14, 10, s, 0.2) + Vector2(0, ly * 0.5),
			_bp(-8, 18, s, 0.08),
			_bp(0, 18, s, 0.08),
		])
		_poly(l_wing, _side_color(hull_color, -1.0), 1.8 * s)

		# Center spine accent
		_line(_bp(0, -24, s, 0.08), _bp(0, 14, s, 0.08), accent_color, 1.5 * s)

		# Wing edge accents
		_line(
			_bp(12, -10, s, 0.25) + Vector2(0, ry),
			_bp(38, 8, s, 0.25) + Vector2(0, ry),
			detail_color, 0.8 * s)
		_line(
			_bp(-12, -10, s, 0.25) + Vector2(0, ly),
			_bp(-38, 8, s, 0.25) + Vector2(0, ly),
			detail_color, 0.8 * s)

		# Small bubble canopy
		var cx: float = -bank * 1.0 * s
		var can := PackedVector2Array([
			_bp(0, -20, s, 0.05) + Vector2(cx, 0),
			_bp(4, -10, s, 0.05) + Vector2(cx, 0),
			_bp(-4, -10, s, 0.05) + Vector2(cx, 0),
		])
		_canopy(can)

		# Two buried engines
		_exhaust_line(_bp(8, 16, s, 0.1), _bp(8, 24, s, 0.1), 2.5 * s)
		_exhaust_line(_bp(-8, 16, s, 0.1), _bp(-8, 24, s, 0.1), 2.5 * s)

	# ── Ship 3: Corsair — asymmetric: blade-wing + engine pod ──
	func _draw_corsair() -> void:
		var s := 1.4
		var ry: float = -bank * 1.4 * s
		var ly: float = bank * 1.4 * s

		# Main fuselage
		var hull := PackedVector2Array([
			_bp(-2, -34, s, 0.08), _bp(6, -22, s, 0.08),
			_bp(7, -4, s, 0.1), _bp(7, 16, s, 0.1),
			_bp(5, 26, s, 0.08), _bp(-7, 26, s, 0.08),
			_bp(-9, 16, s, 0.1), _bp(-9, -4, s, 0.1),
			_bp(-7, -22, s, 0.08),
		])
		_poly(hull, hull_color, 2.0 * s)

		# Right: thin swept blade-wing with gun
		var r_blade := PackedVector2Array([
			_bp(7, -8, s, 0.22) + Vector2(0, ry * 0.2),
			_bp(16, -16, s, 0.25) + Vector2(0, ry * 0.6),
			_bp(26, -12, s, 0.25) + Vector2(0, ry),
			_bp(24, -4, s, 0.25) + Vector2(0, ry),
			_bp(14, -2, s, 0.22) + Vector2(0, ry * 0.5),
			_bp(7, 2, s, 0.22) + Vector2(0, ry * 0.2),
		])
		_poly(r_blade, _side_color(hull_color, 1.0), 1.5 * s)

		# Gun barrel extending forward from blade tip
		_line(
			_bp(24, -12, s, 0.25) + Vector2(0, ry),
			_bp(26, -24, s, 0.25) + Vector2(0, ry),
			accent_color, 1.2 * s)

		# Blade edge accent
		_line(
			_bp(10, -12, s, 0.22) + Vector2(0, ry * 0.4),
			_bp(24, -8, s, 0.25) + Vector2(0, ry),
			detail_color, 0.7 * s)

		# Left: chunky engine nacelle/pod
		var l_pod := PackedVector2Array([
			_bp(-9, 0, s, 0.16) + Vector2(0, ly * 0.2),
			_bp(-16, -2, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-20, 4, s, 0.18) + Vector2(0, ly),
			_bp(-20, 18, s, 0.18) + Vector2(0, ly),
			_bp(-16, 24, s, 0.18) + Vector2(0, ly * 0.8),
			_bp(-9, 20, s, 0.16) + Vector2(0, ly * 0.2),
		])
		_poly(l_pod, _side_color(hull_color, -1.0), 1.5 * s)

		# Pod armor detail
		_line(
			_bp(-14, 2, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-14, 20, s, 0.18) + Vector2(0, ly * 0.7),
			detail_color, 0.7 * s)
		_line(
			_bp(-18, 8, s, 0.18) + Vector2(0, ly * 0.8),
			_bp(-12, 8, s, 0.18) + Vector2(0, ly * 0.4),
			detail_color, 0.6 * s)

		# Canopy
		var cx: float = -bank * 1.2 * s
		var can := PackedVector2Array([
			_bp(-1, -28, s, 0.04) + Vector2(cx, 0),
			_bp(4, -16, s, 0.04) + Vector2(cx, 0),
			_bp(2, -8, s, 0.04) + Vector2(cx, 0),
			_bp(-4, -8, s, 0.04) + Vector2(cx, 0),
			_bp(-5, -16, s, 0.04) + Vector2(cx, 0),
		])
		_canopy(can)

		# Spine
		_line(_bp(0, -6, s, 0.08), _bp(0, 22, s, 0.08), accent_color, 1.0 * s)

		# Main engine + pod engine (asymmetric exhaust)
		_exhaust_line(_bp(3, 24, s, 0.08), _bp(3, 32, s, 0.08), 3.0 * s)
		_exhaust_line(
			_bp(-17, 22, s, 0.18) + Vector2(0, ly * 0.8),
			_bp(-17, 30, s, 0.18) + Vector2(0, ly * 0.8),
			3.0 * s)

	# ── Ship 4: Stiletto — angular stealth ──
	func _draw_stiletto() -> void:
		var s := 1.4

		# Diamond faceted body
		var hull := PackedVector2Array([
			_bp(0, -35, s, 0.1),
			_bp(14, -12, s, 0.15),
			_bp(28, 4, s, 0.2),
			_bp(22, 14, s, 0.18),
			_bp(10, 24, s, 0.1),
			_bp(-10, 24, s, 0.1),
			_bp(-22, 14, s, 0.18),
			_bp(-28, 4, s, 0.2),
			_bp(-14, -12, s, 0.15),
		])
		_poly(hull, hull_color, 2.0 * s)

		# Facet edge lines
		_line(_bp(0, -32, s, 0.1), _bp(14, -12, s, 0.15), detail_color, 0.8 * s)
		_line(_bp(0, -32, s, 0.1), _bp(-14, -12, s, 0.15), detail_color, 0.8 * s)
		_line(_bp(14, -12, s, 0.15), _bp(10, 24, s, 0.1), detail_color, 0.8 * s)
		_line(_bp(-14, -12, s, 0.15), _bp(-10, 24, s, 0.1), detail_color, 0.8 * s)
		# Cross facet
		_line(_bp(-14, -12, s, 0.15), _bp(14, -12, s, 0.15), detail_color, 0.6 * s)

		# Angular canopy slit
		var cx: float = -bank * 1.2 * s
		var can := PackedVector2Array([
			_bp(0, -28, s, 0.05) + Vector2(cx, 0),
			_bp(7, -14, s, 0.05) + Vector2(cx, 0),
			_bp(5, -6, s, 0.05) + Vector2(cx, 0),
			_bp(-5, -6, s, 0.05) + Vector2(cx, 0),
			_bp(-7, -14, s, 0.05) + Vector2(cx, 0),
		])
		_canopy(can)

		# Spine
		_line(_bp(0, -6, s, 0.1), _bp(0, 20, s, 0.1), accent_color, 1.2 * s)

		# Twin tight engines
		_exhaust_line(_bp(-4, 22, s, 0.08), _bp(-4, 30, s, 0.08), 3.0 * s)
		_exhaust_line(_bp(4, 22, s, 0.08), _bp(4, 30, s, 0.08), 3.0 * s)

	# ── Ship 5: Trident — triple-engine racer ──
	func _draw_trident() -> void:
		var s := 1.4
		var ry: float = -bank * 1.2 * s
		var ly: float = bank * 1.2 * s

		# Slim fuselage
		var hull := PackedVector2Array([
			_bp(0, -40, s, 0.08), _bp(6, -24, s, 0.08),
			_bp(8, -6, s, 0.08), _bp(9, 16, s, 0.08),
			_bp(7, 28, s, 0.08), _bp(-7, 28, s, 0.08),
			_bp(-9, 16, s, 0.08), _bp(-8, -6, s, 0.08),
			_bp(-6, -24, s, 0.08),
		])
		_poly(hull, hull_color, 2.0 * s)

		# Right blade-fin — long swept forward prong
		var rf_main := PackedVector2Array([
			_bp(6, -20, s, 0.15) + Vector2(0, ry * 0.3),
			_bp(14, -26, s, 0.15) + Vector2(0, ry * 0.6),
			_bp(28, -38, s, 0.15) + Vector2(0, ry * 0.9),
			_bp(34, -44, s, 0.15) + Vector2(0, ry),
			_bp(30, -36, s, 0.15) + Vector2(0, ry * 0.9),
			_bp(22, -22, s, 0.15) + Vector2(0, ry * 0.7),
			_bp(18, -12, s, 0.15) + Vector2(0, ry * 0.5),
			_bp(12, -6, s, 0.15) + Vector2(0, ry * 0.4),
			_bp(8, -8, s, 0.15) + Vector2(0, ry * 0.3),
		])
		_poly(rf_main, _side_color(hull_color, 1.0), 1.5 * s)
		# Right fin trailing edge / winglet
		var rf_wing := PackedVector2Array([
			_bp(18, -12, s, 0.15) + Vector2(0, ry * 0.5),
			_bp(26, -10, s, 0.15) + Vector2(0, ry * 0.7),
			_bp(30, -16, s, 0.15) + Vector2(0, ry * 0.8),
			_bp(22, -22, s, 0.15) + Vector2(0, ry * 0.7),
		])
		_poly(rf_wing, _side_color(detail_color, 1.0), 1.0 * s)
		# Right fin structural strut
		_line(_bp(8, -14, s, 0.15) + Vector2(0, ry * 0.3), _bp(30, -38, s, 0.15) + Vector2(0, ry * 0.9), accent_color, 0.8 * s)
		# Right fin tip accent
		_line(_bp(32, -42, s, 0.15) + Vector2(0, ry), _bp(36, -46, s, 0.15) + Vector2(0, ry), accent_color, 1.2 * s)

		# Left blade-fin — mirror
		var lf_main := PackedVector2Array([
			_bp(-6, -20, s, 0.15) + Vector2(0, ly * 0.3),
			_bp(-14, -26, s, 0.15) + Vector2(0, ly * 0.6),
			_bp(-28, -38, s, 0.15) + Vector2(0, ly * 0.9),
			_bp(-34, -44, s, 0.15) + Vector2(0, ly),
			_bp(-30, -36, s, 0.15) + Vector2(0, ly * 0.9),
			_bp(-22, -22, s, 0.15) + Vector2(0, ly * 0.7),
			_bp(-18, -12, s, 0.15) + Vector2(0, ly * 0.5),
			_bp(-12, -6, s, 0.15) + Vector2(0, ly * 0.4),
			_bp(-8, -8, s, 0.15) + Vector2(0, ly * 0.3),
		])
		_poly(lf_main, _side_color(hull_color, -1.0), 1.5 * s)
		# Left fin trailing edge / winglet
		var lf_wing := PackedVector2Array([
			_bp(-18, -12, s, 0.15) + Vector2(0, ly * 0.5),
			_bp(-26, -10, s, 0.15) + Vector2(0, ly * 0.7),
			_bp(-30, -16, s, 0.15) + Vector2(0, ly * 0.8),
			_bp(-22, -22, s, 0.15) + Vector2(0, ly * 0.7),
		])
		_poly(lf_wing, _side_color(detail_color, -1.0), 1.0 * s)
		# Left fin structural strut
		_line(_bp(-8, -14, s, 0.15) + Vector2(0, ly * 0.3), _bp(-30, -38, s, 0.15) + Vector2(0, ly * 0.9), accent_color, 0.8 * s)
		# Left fin tip accent
		_line(_bp(-32, -42, s, 0.15) + Vector2(0, ly), _bp(-36, -46, s, 0.15) + Vector2(0, ly), accent_color, 1.2 * s)

		# Right engine nacelle
		var re := PackedVector2Array([
			_bp(9, 12, s, 0.18) + Vector2(0, ry * 0.3),
			_bp(16, 14, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(18, 28, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(14, 30, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(9, 24, s, 0.18) + Vector2(0, ry * 0.3),
		])
		_poly(re, _side_color(hull_color, 1.0), 1.5 * s)
		# Left engine nacelle
		var le := PackedVector2Array([
			_bp(-9, 12, s, 0.18) + Vector2(0, ly * 0.3),
			_bp(-16, 14, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-18, 28, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-14, 30, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-9, 24, s, 0.18) + Vector2(0, ly * 0.3),
		])
		_poly(le, _side_color(hull_color, -1.0), 1.5 * s)

		# Canopy
		var cx: float = -bank * 1.0 * s
		var can := PackedVector2Array([
			_bp(0, -34, s, 0.05) + Vector2(cx, 0),
			_bp(4, -20, s, 0.05) + Vector2(cx, 0),
			_bp(-4, -20, s, 0.05) + Vector2(cx, 0),
		])
		_canopy(can)

		# Spine
		_line(_bp(0, -20, s, 0.08), _bp(0, 24, s, 0.08), accent_color, 1.0 * s)

		# Three engine exhausts
		_exhaust_line(_bp(0, 26, s, 0.08), _bp(0, 34, s, 0.08), 3.0 * s)
		_exhaust_line(
			_bp(15, 28, s, 0.18) + Vector2(0, ry * 0.5),
			_bp(15, 35, s, 0.18) + Vector2(0, ry * 0.5),
			2.5 * s)
		_exhaust_line(
			_bp(-15, 28, s, 0.18) + Vector2(0, ly * 0.5),
			_bp(-15, 35, s, 0.18) + Vector2(0, ly * 0.5),
			2.5 * s)

	# ── Ship 6: Orrery — circular science vessel ──
	func _draw_orrery() -> void:
		var s := 1.7
		var ry: float = -bank * 1.0 * s
		var ly: float = bank * 1.0 * s

		# Central dodecagonal core (r≈14)
		var core := PackedVector2Array([
			_bp(0, -14, s, 0.04), _bp(7, -12, s, 0.04),
			_bp(12, -7, s, 0.04), _bp(14, 0, s, 0.04),
			_bp(12, 7, s, 0.04), _bp(7, 12, s, 0.04),
			_bp(0, 14, s, 0.04), _bp(-7, 12, s, 0.04),
			_bp(-12, 7, s, 0.04), _bp(-14, 0, s, 0.04),
			_bp(-12, -7, s, 0.04), _bp(-7, -12, s, 0.04),
		])
		_poly(core, hull_color, 2.0 * s)

		# Right outer arc (thick crescent wrapping the right side)
		var r_arc := PackedVector2Array([
			_bp(18, -18, s, 0.1) + Vector2(0, ry * 0.2),
			_bp(22, -20, s, 0.1) + Vector2(0, ry * 0.3),
			_bp(27, -16, s, 0.1) + Vector2(0, ry * 0.4),
			_bp(30, -8, s, 0.1) + Vector2(0, ry * 0.5),
			_bp(32, 0, s, 0.1) + Vector2(0, ry * 0.6),
			_bp(30, 8, s, 0.1) + Vector2(0, ry * 0.5),
			_bp(27, 16, s, 0.1) + Vector2(0, ry * 0.4),
			_bp(22, 20, s, 0.1) + Vector2(0, ry * 0.3),
			_bp(18, 18, s, 0.1) + Vector2(0, ry * 0.2),
			_bp(20, 12, s, 0.1) + Vector2(0, ry * 0.3),
			_bp(24, 0, s, 0.1) + Vector2(0, ry * 0.5),
			_bp(20, -12, s, 0.1) + Vector2(0, ry * 0.3),
		])
		_poly(r_arc, _side_color(hull_color, 1.0), 1.5 * s)

		# Left outer arc (mirror)
		var l_arc := PackedVector2Array([
			_bp(-18, -18, s, 0.1) + Vector2(0, ly * 0.2),
			_bp(-22, -20, s, 0.1) + Vector2(0, ly * 0.3),
			_bp(-27, -16, s, 0.1) + Vector2(0, ly * 0.4),
			_bp(-30, -8, s, 0.1) + Vector2(0, ly * 0.5),
			_bp(-32, 0, s, 0.1) + Vector2(0, ly * 0.6),
			_bp(-30, 8, s, 0.1) + Vector2(0, ly * 0.5),
			_bp(-27, 16, s, 0.1) + Vector2(0, ly * 0.4),
			_bp(-22, 20, s, 0.1) + Vector2(0, ly * 0.3),
			_bp(-18, 18, s, 0.1) + Vector2(0, ly * 0.2),
			_bp(-20, 12, s, 0.1) + Vector2(0, ly * 0.3),
			_bp(-24, 0, s, 0.1) + Vector2(0, ly * 0.5),
			_bp(-20, -12, s, 0.1) + Vector2(0, ly * 0.3),
		])
		_poly(l_arc, _side_color(hull_color, -1.0), 1.5 * s)

		# Scaffolding struts — core to arcs (4 per side)
		_line(_bp(12, -7, s, 0.04), _bp(18, -18, s, 0.1) + Vector2(0, ry * 0.2), detail_color, 0.8 * s)
		_line(_bp(14, 0, s, 0.04), _bp(24, 0, s, 0.1) + Vector2(0, ry * 0.5), detail_color, 0.8 * s)
		_line(_bp(12, 7, s, 0.04), _bp(18, 18, s, 0.1) + Vector2(0, ry * 0.2), detail_color, 0.8 * s)
		_line(_bp(7, 12, s, 0.04), _bp(20, 12, s, 0.1) + Vector2(0, ry * 0.3), detail_color, 0.6 * s)
		_line(_bp(-12, -7, s, 0.04), _bp(-18, -18, s, 0.1) + Vector2(0, ly * 0.2), detail_color, 0.8 * s)
		_line(_bp(-14, 0, s, 0.04), _bp(-24, 0, s, 0.1) + Vector2(0, ly * 0.5), detail_color, 0.8 * s)
		_line(_bp(-12, 7, s, 0.04), _bp(-18, 18, s, 0.1) + Vector2(0, ly * 0.2), detail_color, 0.8 * s)
		_line(_bp(-7, 12, s, 0.04), _bp(-20, 12, s, 0.1) + Vector2(0, ly * 0.3), detail_color, 0.6 * s)

		# Forward sensor boom
		_line(_bp(0, -14, s, 0.04), _bp(0, -22, s, 0.04), accent_color, 1.2 * s)
		# Sensor dish at tip (small triangle)
		var dish := PackedVector2Array([
			_bp(0, -24, s, 0.04),
			_bp(5, -20, s, 0.04),
			_bp(-5, -20, s, 0.04),
		])
		_poly(dish, accent_color, 1.0 * s)

		# Core ring detail — cross lines through center
		_line(_bp(-10, 0, s, 0.04), _bp(10, 0, s, 0.04), detail_color, 0.6 * s)
		_line(_bp(0, -10, s, 0.04), _bp(0, 10, s, 0.04), detail_color, 0.6 * s)

		# Canopy (small window on core top face)
		var cx: float = -bank * 1.0 * s
		var can := PackedVector2Array([
			_bp(-4, -10, s, 0.03) + Vector2(cx, 0),
			_bp(4, -10, s, 0.03) + Vector2(cx, 0),
			_bp(3, -4, s, 0.03) + Vector2(cx, 0),
			_bp(-3, -4, s, 0.03) + Vector2(cx, 0),
		])
		_canopy(can)

		# Rear engine mount (small polygon below core)
		var eng_mount := PackedVector2Array([
			_bp(-8, 14, s, 0.04),
			_bp(8, 14, s, 0.04),
			_bp(10, 20, s, 0.04),
			_bp(6, 26, s, 0.04),
			_bp(-6, 26, s, 0.04),
			_bp(-10, 20, s, 0.04),
		])
		_poly(eng_mount, hull_color, 1.5 * s)

		# Three engines
		_exhaust_line(_bp(-6, 24, s, 0.04), _bp(-6, 32, s, 0.04), 2.5 * s)
		_exhaust_line(_bp(0, 26, s, 0.04), _bp(0, 34, s, 0.04), 2.5 * s)
		_exhaust_line(_bp(6, 24, s, 0.04), _bp(6, 32, s, 0.04), 2.5 * s)

	# ── Ship 7: Dreadnought — massive capital ship ──
	func _draw_dreadnought() -> void:
		var s := 1.9
		var ry: float = -bank * 0.8 * s
		var ly: float = bank * 0.8 * s

		# Elongated rectangular hull
		var hull := PackedVector2Array([
			_bp(-4, -48, s, 0.04), _bp(4, -48, s, 0.04),
			_bp(16, -40, s, 0.04), _bp(20, -26, s, 0.04),
			_bp(20, 26, s, 0.04), _bp(18, 36, s, 0.04),
			_bp(16, 42, s, 0.04), _bp(-16, 42, s, 0.04),
			_bp(-18, 36, s, 0.04), _bp(-20, 26, s, 0.04),
			_bp(-20, -26, s, 0.04), _bp(-16, -40, s, 0.04),
		])
		_poly(hull, hull_color, 2.4 * s)

		# Right hangar bay (recessed panel)
		var rhb := PackedVector2Array([
			_bp(20, -8, s, 0.08) + Vector2(0, ry * 0.2),
			_bp(26, -6, s, 0.08) + Vector2(0, ry * 0.4),
			_bp(26, 8, s, 0.08) + Vector2(0, ry * 0.4),
			_bp(20, 10, s, 0.08) + Vector2(0, ry * 0.2),
		])
		_poly(rhb, _side_color(detail_color, 1.0), 1.0 * s)
		# Left hangar bay
		var lhb := PackedVector2Array([
			_bp(-20, -8, s, 0.08) + Vector2(0, ly * 0.2),
			_bp(-26, -6, s, 0.08) + Vector2(0, ly * 0.4),
			_bp(-26, 8, s, 0.08) + Vector2(0, ly * 0.4),
			_bp(-20, 10, s, 0.08) + Vector2(0, ly * 0.2),
		])
		_poly(lhb, _side_color(detail_color, -1.0), 1.0 * s)

		# Triple turret bumps per side (small lines)
		_line(_bp(20, -22, s, 0.06) + Vector2(0, ry * 0.2), _bp(26, -22, s, 0.06) + Vector2(0, ry * 0.3), accent_color, 1.0 * s)
		_line(_bp(20, -16, s, 0.06) + Vector2(0, ry * 0.2), _bp(26, -16, s, 0.06) + Vector2(0, ry * 0.3), accent_color, 1.0 * s)
		_line(_bp(20, 18, s, 0.06) + Vector2(0, ry * 0.2), _bp(26, 18, s, 0.06) + Vector2(0, ry * 0.3), accent_color, 1.0 * s)
		_line(_bp(-20, -22, s, 0.06) + Vector2(0, ly * 0.2), _bp(-26, -22, s, 0.06) + Vector2(0, ly * 0.3), accent_color, 1.0 * s)
		_line(_bp(-20, -16, s, 0.06) + Vector2(0, ly * 0.2), _bp(-26, -16, s, 0.06) + Vector2(0, ly * 0.3), accent_color, 1.0 * s)
		_line(_bp(-20, 18, s, 0.06) + Vector2(0, ly * 0.2), _bp(-26, 18, s, 0.06) + Vector2(0, ly * 0.3), accent_color, 1.0 * s)

		# Many armor plate lines
		_line(_bp(-18, -20, s, 0.04), _bp(18, -20, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-18, -10, s, 0.04), _bp(18, -10, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-18, 0, s, 0.04), _bp(18, 0, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-18, 12, s, 0.04), _bp(18, 12, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-18, 24, s, 0.04), _bp(18, 24, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-16, 34, s, 0.04), _bp(16, 34, s, 0.04), detail_color, 0.7 * s)

		# Command bridge canopy
		var cx: float = -bank * 1.5 * s
		var can := PackedVector2Array([
			_bp(-8, -42, s, 0.02) + Vector2(cx, 0),
			_bp(8, -42, s, 0.02) + Vector2(cx, 0),
			_bp(10, -32, s, 0.02) + Vector2(cx, 0),
			_bp(-10, -32, s, 0.02) + Vector2(cx, 0),
		])
		_canopy(can)

		# Spine accent
		_line(_bp(0, -30, s, 0.04), _bp(0, 38, s, 0.04), accent_color, 1.2 * s)

		# Eight engines
		_exhaust_line(_bp(-14, 40, s, 0.04), _bp(-14, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(-10, 40, s, 0.04), _bp(-10, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(-6, 40, s, 0.04), _bp(-6, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(-2, 40, s, 0.04), _bp(-2, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(2, 40, s, 0.04), _bp(2, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(6, 40, s, 0.04), _bp(6, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(10, 40, s, 0.04), _bp(10, 48, s, 0.04), 1.8 * s)
		_exhaust_line(_bp(14, 40, s, 0.04), _bp(14, 48, s, 0.04), 1.8 * s)

	# ── Ship 8: Bastion — stepped blocky capital ship (Sears Tower silhouette) ──
	func _draw_bastion() -> void:
		var s := 1.8
		var ry: float = -bank * 0.9 * s
		var ly: float = bank * 0.9 * s

		# TIER 1 (rear/widest) — full-width engine section
		var tier1 := PackedVector2Array([
			_bp(-28, 10, s, 0.04), _bp(28, 10, s, 0.04),
			_bp(28, 44, s, 0.04), _bp(-28, 44, s, 0.04),
		])
		_poly(tier1, hull_color, 2.2 * s)

		# TIER 2 (mid) — steps in from tier 1
		var tier2 := PackedVector2Array([
			_bp(-22, -14, s, 0.04), _bp(22, -14, s, 0.04),
			_bp(22, 12, s, 0.04), _bp(-22, 12, s, 0.04),
		])
		_poly(tier2, hull_color, 2.2 * s)

		# TIER 3 (upper-mid) — narrower still
		var tier3 := PackedVector2Array([
			_bp(-16, -34, s, 0.04), _bp(16, -34, s, 0.04),
			_bp(16, -12, s, 0.04), _bp(-16, -12, s, 0.04),
		])
		_poly(tier3, hull_color, 2.2 * s)

		# TIER 4 (bridge/prow) — blunt narrow top
		var tier4 := PackedVector2Array([
			_bp(-10, -48, s, 0.04), _bp(10, -48, s, 0.04),
			_bp(10, -32, s, 0.04), _bp(-10, -32, s, 0.04),
		])
		_poly(tier4, hull_color, 2.0 * s)

		# Right side blocks — sponson pods on the wide tiers
		# Tier 1 right pod
		var r_pod1 := PackedVector2Array([
			_bp(28, 16, s, 0.06) + Vector2(0, ry * 0.2),
			_bp(36, 16, s, 0.06) + Vector2(0, ry * 0.4),
			_bp(36, 38, s, 0.06) + Vector2(0, ry * 0.4),
			_bp(28, 38, s, 0.06) + Vector2(0, ry * 0.2),
		])
		_poly(r_pod1, _side_color(hull_color, 1.0), 1.8 * s)
		# Tier 2 right pod (shorter)
		var r_pod2 := PackedVector2Array([
			_bp(22, -10, s, 0.06) + Vector2(0, ry * 0.2),
			_bp(28, -10, s, 0.06) + Vector2(0, ry * 0.3),
			_bp(28, 6, s, 0.06) + Vector2(0, ry * 0.3),
			_bp(22, 6, s, 0.06) + Vector2(0, ry * 0.2),
		])
		_poly(r_pod2, _side_color(hull_color, 1.0), 1.5 * s)

		# Left side blocks
		var l_pod1 := PackedVector2Array([
			_bp(-28, 16, s, 0.06) + Vector2(0, ly * 0.2),
			_bp(-36, 16, s, 0.06) + Vector2(0, ly * 0.4),
			_bp(-36, 38, s, 0.06) + Vector2(0, ly * 0.4),
			_bp(-28, 38, s, 0.06) + Vector2(0, ly * 0.2),
		])
		_poly(l_pod1, _side_color(hull_color, -1.0), 1.8 * s)
		var l_pod2 := PackedVector2Array([
			_bp(-22, -10, s, 0.06) + Vector2(0, ly * 0.2),
			_bp(-28, -10, s, 0.06) + Vector2(0, ly * 0.3),
			_bp(-28, 6, s, 0.06) + Vector2(0, ly * 0.3),
			_bp(-22, 6, s, 0.06) + Vector2(0, ly * 0.2),
		])
		_poly(l_pod2, _side_color(hull_color, -1.0), 1.5 * s)

		# Step ledge accents — horizontal lines where tiers step in
		_line(_bp(-28, 10, s, 0.04), _bp(28, 10, s, 0.04), accent_color, 1.0 * s)
		_line(_bp(-22, -14, s, 0.04), _bp(22, -14, s, 0.04), accent_color, 1.0 * s)
		_line(_bp(-16, -34, s, 0.04), _bp(16, -34, s, 0.04), accent_color, 0.9 * s)

		# Vertical step edges (right side silhouette)
		_line(_bp(28, 10, s, 0.04), _bp(22, 10, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(22, -14, s, 0.04), _bp(16, -14, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(16, -34, s, 0.04), _bp(10, -34, s, 0.04), detail_color, 0.7 * s)
		# Left side
		_line(_bp(-28, 10, s, 0.04), _bp(-22, 10, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-22, -14, s, 0.04), _bp(-16, -14, s, 0.04), detail_color, 0.7 * s)
		_line(_bp(-16, -34, s, 0.04), _bp(-10, -34, s, 0.04), detail_color, 0.7 * s)

		# Armor plate lines within tiers
		_line(_bp(-28, 24, s, 0.04), _bp(28, 24, s, 0.04), detail_color, 0.6 * s)
		_line(_bp(-28, 36, s, 0.04), _bp(28, 36, s, 0.04), detail_color, 0.6 * s)
		_line(_bp(-22, -4, s, 0.04), _bp(22, -4, s, 0.04), detail_color, 0.5 * s)
		_line(_bp(-16, -24, s, 0.04), _bp(16, -24, s, 0.04), detail_color, 0.5 * s)

		# Vertical structural ribs down center
		_line(_bp(-5, -46, s, 0.04), _bp(-5, 42, s, 0.04), detail_color, 0.4 * s)
		_line(_bp(5, -46, s, 0.04), _bp(5, 42, s, 0.04), detail_color, 0.4 * s)

		# Spine accent — doubled
		_line(_bp(-2, -44, s, 0.04), _bp(-2, 40, s, 0.04), accent_color, 0.8 * s)
		_line(_bp(2, -44, s, 0.04), _bp(2, 40, s, 0.04), accent_color, 0.8 * s)

		# Bridge canopy on tier 4
		var cx: float = -bank * 1.2 * s
		var can := PackedVector2Array([
			_bp(-5, -46, s, 0.03) + Vector2(cx, 0),
			_bp(5, -46, s, 0.03) + Vector2(cx, 0),
			_bp(6, -38, s, 0.03) + Vector2(cx, 0),
			_bp(-6, -38, s, 0.03) + Vector2(cx, 0),
		])
		_canopy(can)

		# Pod panel seams
		_line(_bp(30, 24, s, 0.06) + Vector2(0, ry * 0.3), _bp(34, 24, s, 0.06) + Vector2(0, ry * 0.4), detail_color, 0.4 * s)
		_line(_bp(30, 30, s, 0.06) + Vector2(0, ry * 0.3), _bp(34, 30, s, 0.06) + Vector2(0, ry * 0.4), detail_color, 0.4 * s)
		_line(_bp(-30, 24, s, 0.06) + Vector2(0, ly * 0.3), _bp(-34, 24, s, 0.06) + Vector2(0, ly * 0.4), detail_color, 0.4 * s)
		_line(_bp(-30, 30, s, 0.06) + Vector2(0, ly * 0.3), _bp(-34, 30, s, 0.06) + Vector2(0, ly * 0.4), detail_color, 0.4 * s)

		# Antenna stubs on tier 2 pods
		_line(_bp(28, -8, s, 0.06) + Vector2(0, ry * 0.3), _bp(30, -14, s, 0.06) + Vector2(0, ry * 0.4), detail_color, 0.5 * s)
		_line(_bp(-28, -8, s, 0.06) + Vector2(0, ly * 0.3), _bp(-30, -14, s, 0.06) + Vector2(0, ly * 0.4), detail_color, 0.5 * s)

		# Vent grates on tier 1 rear
		_line(_bp(-12, 38, s, 0.04), _bp(-8, 38, s, 0.04), detail_color, 0.4 * s)
		_line(_bp(-12, 41, s, 0.04), _bp(-8, 41, s, 0.04), detail_color, 0.4 * s)
		_line(_bp(8, 38, s, 0.04), _bp(12, 38, s, 0.04), detail_color, 0.4 * s)
		_line(_bp(8, 41, s, 0.04), _bp(12, 41, s, 0.04), detail_color, 0.4 * s)

		# Six heavy engines across the wide rear
		_exhaust_line(_bp(-22, 44, s, 0.04), _bp(-22, 52, s, 0.04), 2.8 * s)
		_exhaust_line(_bp(-14, 44, s, 0.04), _bp(-14, 52, s, 0.04), 2.8 * s)
		_exhaust_line(_bp(-6, 44, s, 0.04), _bp(-6, 52, s, 0.04), 2.8 * s)
		_exhaust_line(_bp(6, 44, s, 0.04), _bp(6, 52, s, 0.04), 2.8 * s)
		_exhaust_line(_bp(14, 44, s, 0.04), _bp(14, 52, s, 0.04), 2.8 * s)
		_exhaust_line(_bp(22, 44, s, 0.04), _bp(22, 52, s, 0.04), 2.8 * s)

	# ── Neon drawing helpers ──

	func _draw_neon_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		var gc := color
		gc.a = 0.25
		draw_line(a, b, gc, width * 3.0, true)
		draw_circle(a, width * 1.5, gc)
		draw_circle(b, width * 1.5, gc)
		gc.a = 0.5
		draw_line(a, b, gc, width * 1.8, true)
		draw_circle(a, width * 0.9, gc)
		draw_circle(b, width * 0.9, gc)
		draw_line(a, b, color, width, true)
		draw_circle(a, width * 0.5, color)
		draw_circle(b, width * 0.5, color)
		var w := Color(1, 1, 1, 0.6)
		draw_line(a, b, w, width * 0.4, true)
		draw_circle(a, width * 0.2, w)
		draw_circle(b, width * 0.2, w)

	func _draw_neon_polygon(points: PackedVector2Array, color: Color, width: float) -> void:
		var glow := color
		glow.a = 0.15
		draw_colored_polygon(points, glow)
		_draw_neon_lines(points, color, width)

	func _draw_neon_lines(points: PackedVector2Array, color: Color, width: float) -> void:
		if points.size() < 2:
			return
		var gc := color
		# Outer glow
		gc.a = 0.25
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], gc, width * 3.0, true)
		for pt in points:
			draw_circle(pt, width * 1.5, gc)
		# Mid glow
		gc.a = 0.5
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], gc, width * 1.8, true)
		for pt in points:
			draw_circle(pt, width * 0.9, gc)
		# Bright core
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], color, width, true)
		for pt in points:
			draw_circle(pt, width * 0.5, color)
		# White-hot center
		var white := Color(1, 1, 1, 0.6)
		for i in range(points.size()):
			var ni: int = (i + 1) % points.size()
			draw_line(points[i], points[ni], white, width * 0.4, true)
		for pt in points:
			draw_circle(pt, width * 0.2, white)


# ── Exhaust Drawing (inner class) ────────────────────────────

class _ExhaustDraw extends Node2D:
	var viewer: Control

	func _draw() -> void:
		if not viewer:
			return
		var particles: Array[Dictionary] = viewer._exhaust_particles
		for p in particles:
			var life: float = p["life"]
			var max_life: float = p["max_life"]
			var t: float = life / max_life
			var pos: Vector2 = p["pos"]
			var sz: float = p["size"]
			var col := Color(1.0, 0.4 * t + 0.1, 0.05, t * 0.8)
			draw_circle(pos, sz * t, col)
			var core := Color(1.0, 0.8, 0.3, t * 0.5)
			draw_circle(pos, sz * t * 0.4, core)


# ── Ship Selector Bar (inner class) ─────────────────────────

class _ShipSelector extends Node2D:
	const BAR_HEIGHT := 130.0
	const SLOT_WIDTH := 80.0
	const SHIP_COUNT := 9
	const SHIP_NAMES: Array[String] = [
		"Switchblade", "Phantom", "Mantis", "Corsair", "Stiletto",
		"Trident", "Orrery", "Dreadnought", "Bastion",
	]

	var viewer: Control
	var render_mode: int = _ShipDraw.RenderMode.NEON

	var cyan := Color(0.0, 0.9, 1.0)
	var magenta := Color(1.0, 0.2, 0.6)
	var orange := Color(1.0, 0.5, 0.1)
	var purple := Color(0.4, 0.2, 1.0)
	var teal := Color(0.0, 1.0, 0.7)

	func get_slot_at(mouse_x: float, vp_w: float) -> int:
		var total_w: float = SLOT_WIDTH * SHIP_COUNT
		var start_x: float = (vp_w - total_w) * 0.5
		if mouse_x < start_x or mouse_x > start_x + total_w:
			return -1
		return int((mouse_x - start_x) / SLOT_WIDTH)

	func _draw() -> void:
		if not viewer:
			return
		var vp_size: Vector2 = viewer.get_viewport_rect().size
		var bar_y: float = vp_size.y - BAR_HEIGHT

		var bg := Color(0.0, 0.0, 0.05, 0.85)
		draw_rect(Rect2(0, bar_y, vp_size.x, BAR_HEIGHT), bg)
		draw_line(Vector2(0, bar_y), Vector2(vp_size.x, bar_y), cyan * Color(1, 1, 1, 0.3), 1.0)

		var total_w: float = SLOT_WIDTH * SHIP_COUNT
		var start_x: float = (vp_size.x - total_w) * 0.5
		var center_y: float = bar_y + 48.0

		for i in range(SHIP_COUNT):
			var cx: float = start_x + SLOT_WIDTH * i + SLOT_WIDTH * 0.5
			var selected: bool = (i == viewer._selected_ship)

			if selected:
				var hl := cyan
				hl.a = 0.12
				draw_rect(Rect2(cx - SLOT_WIDTH * 0.5 + 2, bar_y + 2, SLOT_WIDTH - 4, BAR_HEIGHT - 4), hl)
				draw_rect(Rect2(cx - SLOT_WIDTH * 0.5 + 2, bar_y + 2, SLOT_WIDTH - 4, BAR_HEIGHT - 4), Color(cyan.r, cyan.g, cyan.b, 0.4), false, 1.0)

			var origin := Vector2(cx, center_y)
			match i:
				0: _draw_switchblade(origin)
				1: _draw_phantom(origin)
				2: _draw_mantis(origin)
				3: _draw_corsair(origin)
				4: _draw_stiletto(origin)
				5: _draw_trident(origin)
				6: _draw_orrery(origin)
				7: _draw_dreadnought(origin)
				8: _draw_bastion(origin)

			var label_pos := Vector2(cx - 3, bar_y + BAR_HEIGHT - 26)
			var label_col: Color = cyan if selected else Color(0.5, 0.5, 0.6)
			_draw_number(label_pos, i + 1, label_col)

			# Ship name below number
			var font: Font = ThemeDB.fallback_font
			var name_text: String = SHIP_NAMES[i] if i < SHIP_NAMES.size() else ""
			var font_size: int = 12
			var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			var name_pos := Vector2(cx - text_width * 0.5, bar_y + BAR_HEIGHT - 6)
			draw_string(font, name_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_col)

	# ── Thumbnail dispatch helpers ──

	func _mp(points: PackedVector2Array, color: Color, w: float) -> void:
		if render_mode == _ShipDraw.RenderMode.CHROME:
			_mp_chrome(points, w)
		else:
			_mp_neon(points, color, w)

	func _ml(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		if render_mode == _ShipDraw.RenderMode.CHROME:
			_ml_chrome(a, b, w)
		else:
			_ml_neon(a, b, color, w)

	func _mp_neon(points: PackedVector2Array, color: Color, w: float) -> void:
		var fill := color
		fill.a = 0.12
		draw_colored_polygon(points, fill)
		var gc := color
		gc.a = 0.3
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			draw_line(points[j], points[nj], gc, w * 2.0, true)
		for pt in points:
			draw_circle(pt, w, gc)
		for j in range(points.size()):
			var nj: int = (j + 1) % points.size()
			draw_line(points[j], points[nj], color, w, true)
		for pt in points:
			draw_circle(pt, w * 0.5, color)

	func _ml_neon(a: Vector2, b: Vector2, color: Color, w: float) -> void:
		var gc := color
		gc.a = 0.3
		draw_line(a, b, gc, w * 2.0, true)
		draw_circle(a, w, gc)
		draw_circle(b, w, gc)
		draw_line(a, b, color, w, true)
		draw_circle(a, w * 0.5, color)
		draw_circle(b, w * 0.5, color)

	func _mp_chrome(points: PackedVector2Array, w: float) -> void:
		if points.size() < 3:
			return
		# Solid chrome fill — bright top, dark bottom
		draw_colored_polygon(points, _ShipDraw.CHROME_MID)
		# Bright top edge
		var min_y := points[0].y
		var max_y := points[0].y
		for pt in points:
			min_y = minf(min_y, pt.y)
			max_y = maxf(max_y, pt.y)
		var height: float = max_y - min_y
		if height > 1.0:
			for j in range(points.size()):
				var nj: int = (j + 1) % points.size()
				var mid_y: float = (points[j].y + points[nj].y) * 0.5
				var t: float = 1.0 - (mid_y - min_y) / height
				var edge_col: Color = _ShipDraw.CHROME_DARK.lerp(_ShipDraw.CHROME_BRIGHT, t)
				edge_col.a = 0.8
				draw_line(points[j], points[nj], edge_col, w, true)

	func _ml_chrome(a: Vector2, b: Vector2, w: float) -> void:
		draw_line(a, b, _ShipDraw.CHROME_MID, w * 1.2, true)
		draw_line(a, b, _ShipDraw.CHROME_BRIGHT, w * 0.6, true)

	func _draw_number(pos: Vector2, num: int, color: Color) -> void:
		var sw := 3.0
		var h := 4.0
		var p: Vector2 = pos
		var segs: Array[bool] = []
		match num:
			1: segs = [false, true, true, false, false, false, false]
			2: segs = [true, true, false, true, true, false, true]
			3: segs = [true, true, true, true, false, false, true]
			4: segs = [false, true, true, false, false, true, true]
			5: segs = [true, false, true, true, false, true, true]
			6: segs = [true, false, true, true, true, true, true]
			7: segs = [true, true, true, false, false, false, false]
			8: segs = [true, true, true, true, true, true, true]
			9: segs = [true, true, true, true, false, true, true]
		if segs.size() < 7:
			return
		if segs[0]: draw_line(p + Vector2(-sw, -h), p + Vector2(sw, -h), color, 1.0, true)
		if segs[1]: draw_line(p + Vector2(sw, -h), p + Vector2(sw, 0), color, 1.0, true)
		if segs[2]: draw_line(p + Vector2(sw, 0), p + Vector2(sw, h), color, 1.0, true)
		if segs[3]: draw_line(p + Vector2(sw, h), p + Vector2(-sw, h), color, 1.0, true)
		if segs[4]: draw_line(p + Vector2(-sw, h), p + Vector2(-sw, 0), color, 1.0, true)
		if segs[5]: draw_line(p + Vector2(-sw, 0), p + Vector2(-sw, -h), color, 1.0, true)
		if segs[6]: draw_line(p + Vector2(-sw, 0), p + Vector2(sw, 0), color, 1.0, true)

	# ── Mini ship thumbnails ──

	func _draw_switchblade(o: Vector2) -> void:
		var s := 0.36
		# Right blade — thick geometric
		var rb := PackedVector2Array([
			o + Vector2(3, 16) * s, o + Vector2(4, 4) * s,
			o + Vector2(10, -14) * s, o + Vector2(16, -32) * s,
			o + Vector2(22, -36) * s, o + Vector2(20, -24) * s,
			o + Vector2(16, -8) * s, o + Vector2(12, 6) * s,
			o + Vector2(8, 16) * s,
		])
		_mp(rb, cyan, 0.7)
		# Left blade
		var lb := PackedVector2Array([
			o + Vector2(-3, 16) * s, o + Vector2(-4, 4) * s,
			o + Vector2(-10, -14) * s, o + Vector2(-16, -32) * s,
			o + Vector2(-22, -36) * s, o + Vector2(-20, -24) * s,
			o + Vector2(-16, -8) * s, o + Vector2(-12, 6) * s,
			o + Vector2(-8, 16) * s,
		])
		_mp(lb, cyan, 0.7)
		# Diamond hub
		var hub := PackedVector2Array([
			o + Vector2(0, 2) * s, o + Vector2(7, 14) * s,
			o + Vector2(0, 24) * s, o + Vector2(-7, 14) * s,
		])
		_mp(hub, cyan, 0.8)
		_ml(o + Vector2(-3, 22) * s, o + Vector2(-3, 28) * s, orange, 0.8)
		_ml(o + Vector2(3, 22) * s, o + Vector2(3, 28) * s, orange, 0.8)

	func _draw_phantom(o: Vector2) -> void:
		var s := 0.42
		var hull := PackedVector2Array([
			o + Vector2(0, -36) * s, o + Vector2(6, -28) * s,
			o + Vector2(10, -16) * s, o + Vector2(14, -4) * s,
			o + Vector2(16, 8) * s, o + Vector2(12, 20) * s,
			o + Vector2(6, 26) * s, o + Vector2(-6, 26) * s,
			o + Vector2(-12, 20) * s, o + Vector2(-16, 8) * s,
			o + Vector2(-14, -4) * s, o + Vector2(-10, -16) * s,
			o + Vector2(-6, -28) * s,
		])
		_mp(hull, cyan, 0.8)
		var rw := PackedVector2Array([
			o + Vector2(14, -2) * s, o + Vector2(22, 4) * s,
			o + Vector2(20, 10) * s, o + Vector2(14, 8) * s,
		])
		_mp(rw, cyan, 0.6)
		var lw := PackedVector2Array([
			o + Vector2(-14, -2) * s, o + Vector2(-22, 4) * s,
			o + Vector2(-20, 10) * s, o + Vector2(-14, 8) * s,
		])
		_mp(lw, cyan, 0.6)
		_ml(o + Vector2(8, -22) * s, o + Vector2(14, 2) * s, teal, 0.5)
		_ml(o + Vector2(-8, -22) * s, o + Vector2(-14, 2) * s, teal, 0.5)
		_ml(o + Vector2(0, -6) * s, o + Vector2(0, 22) * s, magenta, 0.6)
		_ml(o + Vector2(-5, 24) * s, o + Vector2(-5, 32) * s, orange, 1.2)
		_ml(o + Vector2(5, 24) * s, o + Vector2(5, 32) * s, orange, 1.2)

	func _draw_mantis(o: Vector2) -> void:
		var s := 0.42
		var wing := PackedVector2Array([
			o + Vector2(0, -25) * s, o + Vector2(10, -12) * s,
			o + Vector2(42, 8) * s, o + Vector2(38, 14) * s,
			o + Vector2(14, 10) * s, o + Vector2(8, 18) * s,
			o + Vector2(-8, 18) * s, o + Vector2(-14, 10) * s,
			o + Vector2(-38, 14) * s, o + Vector2(-42, 8) * s,
			o + Vector2(-10, -12) * s,
		])
		_mp(wing, cyan, 1.0)
		_ml(o + Vector2(0, -20) * s, o + Vector2(0, 14) * s, magenta, 0.8)
		var can := PackedVector2Array([
			o + Vector2(0, -18) * s, o + Vector2(4, -8) * s,
			o + Vector2(-4, -8) * s,
		])
		if render_mode == _ShipDraw.RenderMode.CHROME:
			draw_colored_polygon(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.3
			draw_colored_polygon(can, cf)
		_ml(o + Vector2(8, 16) * s, o + Vector2(8, 22) * s, orange, 1.2)
		_ml(o + Vector2(-8, 16) * s, o + Vector2(-8, 22) * s, orange, 1.2)
		_ml(o + Vector2(12, -8) * s, o + Vector2(36, 8) * s, teal, 0.6)
		_ml(o + Vector2(-12, -8) * s, o + Vector2(-36, 8) * s, teal, 0.6)

	func _draw_corsair(o: Vector2) -> void:
		var s := 0.40
		var hull := PackedVector2Array([
			o + Vector2(-2, -34) * s, o + Vector2(6, -22) * s,
			o + Vector2(7, -4) * s, o + Vector2(7, 16) * s,
			o + Vector2(5, 26) * s, o + Vector2(-7, 26) * s,
			o + Vector2(-9, 16) * s, o + Vector2(-9, -4) * s,
			o + Vector2(-7, -22) * s,
		])
		_mp(hull, cyan, 0.8)
		# Right blade-wing
		var rb := PackedVector2Array([
			o + Vector2(7, -8) * s, o + Vector2(16, -16) * s,
			o + Vector2(26, -12) * s, o + Vector2(24, -4) * s,
			o + Vector2(14, -2) * s, o + Vector2(7, 2) * s,
		])
		_mp(rb, cyan, 0.7)
		# Left engine pod
		var lp := PackedVector2Array([
			o + Vector2(-9, 0) * s, o + Vector2(-16, -2) * s,
			o + Vector2(-20, 4) * s, o + Vector2(-20, 18) * s,
			o + Vector2(-16, 24) * s, o + Vector2(-9, 20) * s,
		])
		_mp(lp, teal, 0.6)
		_ml(o + Vector2(24, -12) * s, o + Vector2(26, -22) * s, magenta, 0.7)
		_ml(o + Vector2(0, -6) * s, o + Vector2(0, 22) * s, magenta, 0.5)
		_ml(o + Vector2(3, 24) * s, o + Vector2(3, 32) * s, orange, 1.0)
		_ml(o + Vector2(-17, 22) * s, o + Vector2(-17, 30) * s, orange, 1.0)

	func _draw_stiletto(o: Vector2) -> void:
		var s := 0.5
		var hull := PackedVector2Array([
			o + Vector2(0, -32) * s, o + Vector2(12, -10) * s,
			o + Vector2(26, 4) * s, o + Vector2(20, 12) * s,
			o + Vector2(8, 22) * s, o + Vector2(-8, 22) * s,
			o + Vector2(-20, 12) * s, o + Vector2(-26, 4) * s,
			o + Vector2(-12, -10) * s,
		])
		_mp(hull, cyan, 1.0)
		_ml(o + Vector2(0, -28) * s, o + Vector2(12, -10) * s, teal, 0.6)
		_ml(o + Vector2(0, -28) * s, o + Vector2(-12, -10) * s, teal, 0.6)
		_ml(o + Vector2(12, -10) * s, o + Vector2(8, 22) * s, teal, 0.6)
		_ml(o + Vector2(-12, -10) * s, o + Vector2(-8, 22) * s, teal, 0.6)
		var can := PackedVector2Array([
			o + Vector2(0, -24) * s, o + Vector2(6, -12) * s,
			o + Vector2(4, -6) * s, o + Vector2(-4, -6) * s, o + Vector2(-6, -12) * s,
		])
		if render_mode == _ShipDraw.RenderMode.CHROME:
			draw_colored_polygon(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.25
			draw_colored_polygon(can, cf)
		_ml(o + Vector2(0, -6) * s, o + Vector2(0, 18) * s, magenta, 0.8)
		_ml(o + Vector2(-4, 20) * s, o + Vector2(-4, 27) * s, orange, 1.5)
		_ml(o + Vector2(4, 20) * s, o + Vector2(4, 27) * s, orange, 1.5)

	func _draw_trident(o: Vector2) -> void:
		var s := 0.48
		var hull := PackedVector2Array([
			o + Vector2(0, -36) * s, o + Vector2(5, -22) * s,
			o + Vector2(7, -5) * s, o + Vector2(8, 15) * s,
			o + Vector2(6, 26) * s, o + Vector2(-6, 26) * s,
			o + Vector2(-8, 15) * s, o + Vector2(-7, -5) * s,
			o + Vector2(-5, -22) * s,
		])
		_mp(hull, cyan, 1.0)
		# Right blade-fin
		var rf := PackedVector2Array([
			o + Vector2(5, -18) * s, o + Vector2(12, -24) * s,
			o + Vector2(26, -36) * s, o + Vector2(30, -40) * s,
			o + Vector2(24, -30) * s, o + Vector2(16, -14) * s,
			o + Vector2(10, -6) * s, o + Vector2(6, -8) * s,
		])
		_mp(rf, cyan, 0.7)
		_ml(o + Vector2(16, -14) * s, o + Vector2(22, -10) * s, teal, 0.5)
		_ml(o + Vector2(6, -14) * s, o + Vector2(26, -36) * s, magenta, 0.4)
		# Left blade-fin
		var lf := PackedVector2Array([
			o + Vector2(-5, -18) * s, o + Vector2(-12, -24) * s,
			o + Vector2(-26, -36) * s, o + Vector2(-30, -40) * s,
			o + Vector2(-24, -30) * s, o + Vector2(-16, -14) * s,
			o + Vector2(-10, -6) * s, o + Vector2(-6, -8) * s,
		])
		_mp(lf, cyan, 0.7)
		_ml(o + Vector2(-16, -14) * s, o + Vector2(-22, -10) * s, teal, 0.5)
		_ml(o + Vector2(-6, -14) * s, o + Vector2(-26, -36) * s, magenta, 0.4)
		var re := PackedVector2Array([
			o + Vector2(8, 12) * s, o + Vector2(14, 14) * s,
			o + Vector2(16, 26) * s, o + Vector2(12, 28) * s, o + Vector2(8, 22) * s,
		])
		_mp(re, cyan, 0.7)
		var le := PackedVector2Array([
			o + Vector2(-8, 12) * s, o + Vector2(-14, 14) * s,
			o + Vector2(-16, 26) * s, o + Vector2(-12, 28) * s, o + Vector2(-8, 22) * s,
		])
		_mp(le, cyan, 0.7)
		var can := PackedVector2Array([
			o + Vector2(0, -30) * s, o + Vector2(3, -18) * s,
			o + Vector2(-3, -18) * s,
		])
		if render_mode == _ShipDraw.RenderMode.CHROME:
			draw_colored_polygon(can, Color(0.05, 0.08, 0.2, 0.85))
		else:
			var cf := purple
			cf.a = 0.25
			draw_colored_polygon(can, cf)
		_ml(o + Vector2(0, -18) * s, o + Vector2(0, 22) * s, magenta, 0.7)
		_ml(o + Vector2(0, 24) * s, o + Vector2(0, 32) * s, orange, 1.5)
		_ml(o + Vector2(13, 26) * s, o + Vector2(13, 33) * s, orange, 1.2)
		_ml(o + Vector2(-13, 26) * s, o + Vector2(-13, 33) * s, orange, 1.2)

	func _draw_orrery(o: Vector2) -> void:
		var s := 0.32
		# Central dodecagonal core
		var core := PackedVector2Array([
			o + Vector2(0, -14) * s, o + Vector2(7, -12) * s,
			o + Vector2(12, -7) * s, o + Vector2(14, 0) * s,
			o + Vector2(12, 7) * s, o + Vector2(7, 12) * s,
			o + Vector2(0, 14) * s, o + Vector2(-7, 12) * s,
			o + Vector2(-12, 7) * s, o + Vector2(-14, 0) * s,
			o + Vector2(-12, -7) * s, o + Vector2(-7, -12) * s,
		])
		_mp(core, cyan, 0.8)
		# Right arc (longer sweep)
		var ra := PackedVector2Array([
			o + Vector2(18, -18) * s, o + Vector2(27, -16) * s,
			o + Vector2(32, 0) * s, o + Vector2(27, 16) * s,
			o + Vector2(18, 18) * s, o + Vector2(20, 12) * s,
			o + Vector2(24, 0) * s, o + Vector2(20, -12) * s,
		])
		_mp(ra, cyan, 0.6)
		# Left arc (longer sweep)
		var la := PackedVector2Array([
			o + Vector2(-18, -18) * s, o + Vector2(-27, -16) * s,
			o + Vector2(-32, 0) * s, o + Vector2(-27, 16) * s,
			o + Vector2(-18, 18) * s, o + Vector2(-20, 12) * s,
			o + Vector2(-24, 0) * s, o + Vector2(-20, -12) * s,
		])
		_mp(la, cyan, 0.6)
		# Struts
		_ml(o + Vector2(14, 0) * s, o + Vector2(24, 0) * s, teal, 0.5)
		_ml(o + Vector2(-14, 0) * s, o + Vector2(-24, 0) * s, teal, 0.5)
		_ml(o + Vector2(12, -7) * s, o + Vector2(18, -18) * s, teal, 0.4)
		_ml(o + Vector2(-12, -7) * s, o + Vector2(-18, -18) * s, teal, 0.4)
		# Sensor boom (shorter)
		_ml(o + Vector2(0, -14) * s, o + Vector2(0, -22) * s, magenta, 0.6)
		# Engine mount + engines
		_ml(o + Vector2(-6, 24) * s, o + Vector2(-6, 32) * s, orange, 0.8)
		_ml(o + Vector2(0, 26) * s, o + Vector2(0, 34) * s, orange, 0.8)
		_ml(o + Vector2(6, 24) * s, o + Vector2(6, 32) * s, orange, 0.8)

	func _draw_dreadnought(o: Vector2) -> void:
		var s := 0.28
		var hull := PackedVector2Array([
			o + Vector2(-4, -48) * s, o + Vector2(4, -48) * s,
			o + Vector2(16, -40) * s, o + Vector2(20, -26) * s,
			o + Vector2(20, 26) * s, o + Vector2(18, 36) * s,
			o + Vector2(16, 42) * s, o + Vector2(-16, 42) * s,
			o + Vector2(-18, 36) * s, o + Vector2(-20, 26) * s,
			o + Vector2(-20, -26) * s, o + Vector2(-16, -40) * s,
		])
		_mp(hull, cyan, 0.8)
		# Hangar bays
		var rhb := PackedVector2Array([
			o + Vector2(20, -8) * s, o + Vector2(26, -6) * s,
			o + Vector2(26, 8) * s, o + Vector2(20, 10) * s,
		])
		_mp(rhb, teal, 0.5)
		var lhb := PackedVector2Array([
			o + Vector2(-20, -8) * s, o + Vector2(-26, -6) * s,
			o + Vector2(-26, 8) * s, o + Vector2(-20, 10) * s,
		])
		_mp(lhb, teal, 0.5)
		# Turrets
		_ml(o + Vector2(20, -22) * s, o + Vector2(26, -22) * s, magenta, 0.6)
		_ml(o + Vector2(-20, -22) * s, o + Vector2(-26, -22) * s, magenta, 0.6)
		_ml(o + Vector2(20, 18) * s, o + Vector2(26, 18) * s, magenta, 0.6)
		_ml(o + Vector2(-20, 18) * s, o + Vector2(-26, 18) * s, magenta, 0.6)
		# Armor lines
		_ml(o + Vector2(-18, -10) * s, o + Vector2(18, -10) * s, teal, 0.3)
		_ml(o + Vector2(-18, 0) * s, o + Vector2(18, 0) * s, teal, 0.3)
		_ml(o + Vector2(-18, 12) * s, o + Vector2(18, 12) * s, teal, 0.3)
		_ml(o + Vector2(0, -30) * s, o + Vector2(0, 38) * s, magenta, 0.5)
		# Engines
		_ml(o + Vector2(-12, 40) * s, o + Vector2(-12, 48) * s, orange, 0.6)
		_ml(o + Vector2(-6, 40) * s, o + Vector2(-6, 48) * s, orange, 0.6)
		_ml(o + Vector2(0, 40) * s, o + Vector2(0, 48) * s, orange, 0.6)
		_ml(o + Vector2(6, 40) * s, o + Vector2(6, 48) * s, orange, 0.6)
		_ml(o + Vector2(12, 40) * s, o + Vector2(12, 48) * s, orange, 0.6)

	func _draw_bastion(o: Vector2) -> void:
		var s := 0.30
		# Tier 1 — widest rear block
		var t1 := PackedVector2Array([
			o + Vector2(-28, 10) * s, o + Vector2(28, 10) * s,
			o + Vector2(28, 44) * s, o + Vector2(-28, 44) * s,
		])
		_mp(t1, cyan, 0.8)
		# Tier 2 — mid block
		var t2 := PackedVector2Array([
			o + Vector2(-22, -14) * s, o + Vector2(22, -14) * s,
			o + Vector2(22, 12) * s, o + Vector2(-22, 12) * s,
		])
		_mp(t2, cyan, 0.7)
		# Tier 3 — upper block
		var t3 := PackedVector2Array([
			o + Vector2(-16, -34) * s, o + Vector2(16, -34) * s,
			o + Vector2(16, -12) * s, o + Vector2(-16, -12) * s,
		])
		_mp(t3, cyan, 0.7)
		# Tier 4 — blunt prow
		var t4 := PackedVector2Array([
			o + Vector2(-10, -48) * s, o + Vector2(10, -48) * s,
			o + Vector2(10, -32) * s, o + Vector2(-10, -32) * s,
		])
		_mp(t4, cyan, 0.6)
		# Step ledge accents
		_ml(o + Vector2(-28, 10) * s, o + Vector2(28, 10) * s, magenta, 0.5)
		_ml(o + Vector2(-22, -14) * s, o + Vector2(22, -14) * s, magenta, 0.5)
		_ml(o + Vector2(-16, -34) * s, o + Vector2(16, -34) * s, magenta, 0.4)
		# Armor plate lines
		_ml(o + Vector2(-28, 24) * s, o + Vector2(28, 24) * s, teal, 0.3)
		_ml(o + Vector2(-28, 36) * s, o + Vector2(28, 36) * s, teal, 0.3)
		# Spine
		_ml(o + Vector2(-2, -44) * s, o + Vector2(-2, 40) * s, magenta, 0.3)
		_ml(o + Vector2(2, -44) * s, o + Vector2(2, 40) * s, magenta, 0.3)
		# Engines
		_ml(o + Vector2(-20, 44) * s, o + Vector2(-20, 52) * s, orange, 0.8)
		_ml(o + Vector2(-12, 44) * s, o + Vector2(-12, 52) * s, orange, 0.8)
		_ml(o + Vector2(-4, 44) * s, o + Vector2(-4, 52) * s, orange, 0.8)
		_ml(o + Vector2(4, 44) * s, o + Vector2(4, 52) * s, orange, 0.8)
		_ml(o + Vector2(12, 44) * s, o + Vector2(12, 52) * s, orange, 0.8)
		_ml(o + Vector2(20, 44) * s, o + Vector2(20, 52) * s, orange, 0.8)
