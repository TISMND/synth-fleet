extends Node2D
## Green wireframe technical diagram of the player's ship with subsystem callouts.
## Lives inside a metal-framed viewport on the upgrade screen.
## The green grid, ship, scan line, and containment box are drawn here.
## Arrows extend outside the frame to reach the upgrade panels.

var _time: float = 0.0
var _levels: Dictionary = {}

# HDR channels — set by upgrade_screen
var hdr_ship: float = 1.8
var hdr_arrows: float = 1.4

# Frame bounds — set by upgrade_screen, used to clip grid and scan line
var frame_rect: Rect2 = Rect2(310, 60, 700, 660)
var ship_center: Vector2 = Vector2(660, 390)

# Arrow/highlight colors — from ThemeManager accent in upgrade_screen
var arrow_colors: Dictionary = {
	"WEAPONS": Color(1.0, 0.4, 0.2, 0.6),
	"ARMOR": Color(0.4, 0.9, 0.4, 0.6),
	"ENGINES": Color(1.0, 0.8, 0.1, 0.6),
	"POWER CORE": Color(0.3, 0.5, 1.0, 0.6),
}

# Ship anchor points (pre-scale coords)
const ANCHORS := {
	"WEAPONS": Vector2(12, -25),
	"ARMOR": Vector2(24, -4),
	"ENGINES": Vector2(8, 26),
	"POWER CORE": Vector2(10, 8),
}

# Panel centers relative to SHIP_CENTER (660, 390)
# Panels at (1360, 200+i*140), center = (1360+140, 200+i*140+55)
const PANEL_CENTERS := {
	"WEAPONS": Vector2(1500 - 660, 255 - 390),
	"ARMOR": Vector2(1500 - 660, 395 - 390),
	"ENGINES": Vector2(1500 - 660, 535 - 390),
	"POWER CORE": Vector2(1500 - 660, 675 - 390),
}

const SCALE := 9.0

# Pulse dot speed in pixels/second
const PULSE_SPEED := 250.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func set_levels(levels: Dictionary) -> void:
	_levels = levels


# Frame half-extents relative to this node's position
func _frame_half_w() -> float:
	return frame_rect.size.x * 0.5

func _frame_half_h() -> float:
	return frame_rect.size.y * 0.5

func _frame_left() -> float:
	return frame_rect.position.x - ship_center.x

func _frame_right() -> float:
	return frame_rect.position.x + frame_rect.size.x - ship_center.x

func _frame_top() -> float:
	return frame_rect.position.y - ship_center.y

func _frame_bottom() -> float:
	return frame_rect.position.y + frame_rect.size.y - ship_center.y


func _draw() -> void:
	_draw_frame_fill()
	_draw_grid_underlay()
	_draw_ship_wireframe()
	_draw_subsystem_highlights()
	_draw_scan_line()
	_draw_dimension_marks()
	# Arrows drawn on top — they extend outside the frame
	_draw_connection_arrows()


func _draw_frame_fill() -> void:
	# Black fill inside the frame so the green content has a dark backdrop
	var rect := Rect2(
		Vector2(_frame_left(), _frame_top()),
		frame_rect.size
	)
	draw_rect(rect, Color(0.01, 0.02, 0.01, 1.0))


func _draw_grid_underlay() -> void:
	# Green grid clipped to frame bounds
	var grid_size := 40.0
	var fl: float = _frame_left()
	var fr: float = _frame_right()
	var ft: float = _frame_top()
	var fb: float = _frame_bottom()

	var grid_color := Color(0.0, 0.4, 0.2, 0.15)
	var x_start: int = int(ceil(fl / grid_size))
	var x_end: int = int(floor(fr / grid_size))
	for x_i in range(x_start, x_end + 1):
		var x: float = x_i * grid_size
		draw_line(Vector2(x, ft), Vector2(x, fb), grid_color, 1.0)

	var y_start: int = int(ceil(ft / grid_size))
	var y_end: int = int(floor(fb / grid_size))
	for y_i in range(y_start, y_end + 1):
		var y: float = y_i * grid_size
		draw_line(Vector2(fl, y), Vector2(fr, y), grid_color, 1.0)

	# Center crosshair
	var cross_color := Color(0.0, 0.5, 0.25, 0.3)
	draw_line(Vector2(-20, 0), Vector2(20, 0), cross_color, 1.0)
	draw_line(Vector2(0, -20), Vector2(0, 20), cross_color, 1.0)


func _draw_ship_wireframe() -> void:
	var s: float = SCALE
	var h: float = hdr_ship
	var wire_green := Color(0.0, 0.85 * h, 0.35 * h, 0.9)
	var wire_glow := Color(0.0, 1.0 * h, 0.4 * h, 0.12)
	var wire_bright := Color(0.0, 1.0 * h, 0.45 * h, 1.0)

	_draw_stiletto_outline(s, wire_glow, 10.0)
	_draw_stiletto_outline(s, wire_green, 2.0)
	_draw_stiletto_detail(s, wire_bright, 1.2)


func _draw_stiletto_outline(s: float, color: Color, width: float) -> void:
	var hull := PackedVector2Array([
		Vector2(0, -35) * s, Vector2(14, -12) * s, Vector2(28, 4) * s,
		Vector2(22, 14) * s, Vector2(10, 24) * s, Vector2(-10, 24) * s,
		Vector2(-22, 14) * s, Vector2(-28, 4) * s, Vector2(-14, -12) * s,
	])
	for i in range(hull.size()):
		draw_line(hull[i], hull[(i + 1) % hull.size()], color, width)

	var can := PackedVector2Array([
		Vector2(0, -28) * s, Vector2(7, -14) * s, Vector2(5, -6) * s,
		Vector2(-5, -6) * s, Vector2(-7, -14) * s,
	])
	for i in range(can.size()):
		draw_line(can[i], can[(i + 1) % can.size()], color, width)

	draw_line(Vector2(0, -6) * s, Vector2(0, 20) * s, color, width)
	draw_line(Vector2(-4, 22) * s, Vector2(-4, 30) * s, color, width * 1.5)
	draw_line(Vector2(4, 22) * s, Vector2(4, 30) * s, color, width * 1.5)


func _draw_stiletto_detail(s: float, color: Color, width: float) -> void:
	draw_line(Vector2(0, -32) * s, Vector2(14, -12) * s, color, width)
	draw_line(Vector2(0, -32) * s, Vector2(-14, -12) * s, color, width)
	draw_line(Vector2(14, -12) * s, Vector2(10, 24) * s, color, width)
	draw_line(Vector2(-14, -12) * s, Vector2(-10, 24) * s, color, width)
	draw_line(Vector2(-14, -12) * s, Vector2(14, -12) * s, color, width)

	var h: float = hdr_ship
	var vertex_color := Color(0.0, 1.0 * h, 0.5 * h, 1.0)
	for v in [Vector2(0,-35), Vector2(14,-12), Vector2(28,4), Vector2(22,14),
			Vector2(10,24), Vector2(-10,24), Vector2(-22,14), Vector2(-28,4), Vector2(-14,-12)]:
		draw_circle(v * s, 3.5, vertex_color)


func _draw_subsystem_highlights() -> void:
	var pulse: float = 0.5 + sin(_time * 2.0) * 0.2
	var s: float = SCALE
	var h: float = hdr_arrows

	var zones := {
		"WEAPONS": {"center": Vector2(8, -26), "half": Vector2(14, 12)},
		"ARMOR": {"center": Vector2(22, 2), "half": Vector2(10, 16)},
		"ENGINES": {"center": Vector2(0, 26), "half": Vector2(12, 8)},
		"POWER CORE": {"center": Vector2(6, 5), "half": Vector2(12, 10)},
	}
	for sub_name in zones:
		var z: Dictionary = zones[sub_name]
		var ac: Color = arrow_colors.get(sub_name, Color.WHITE)
		var hl := Color(ac.r * h, ac.g * h, ac.b * h, 0.4) * pulse
		_draw_highlight_zone(z["center"] * s, z["half"] * s, hl)


func _draw_highlight_zone(center: Vector2, half_size: Vector2, color: Color) -> void:
	var tl := center - half_size
	var tr := center + Vector2(half_size.x, -half_size.y)
	var br := center + half_size
	var bl := center + Vector2(-half_size.x, half_size.y)
	var corners := [tl, tr, br, bl]
	var corner_len := 14.0

	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var dir: Vector2 = (b - a).normalized()
		draw_line(a, a + dir * corner_len, color, 2.0)
		draw_line(b, b - dir * corner_len, color, 2.0)


func _draw_connection_arrows() -> void:
	var s: float = SCALE
	var h: float = hdr_arrows
	for sub_name in ANCHORS:
		var ship_pt: Vector2 = ANCHORS[sub_name] * s
		var panel_center: Vector2 = PANEL_CENTERS[sub_name]
		var base_color: Color = arrow_colors.get(sub_name, Color.WHITE)

		var elbow := Vector2(panel_center.x * 0.35, ship_pt.y)
		var panel_edge := Vector2(panel_center.x * 0.82, panel_center.y)

		_draw_dashed_line(ship_pt, elbow, base_color, 1.5, 8.0, 5.0)
		_draw_dashed_line(elbow, panel_edge, base_color, 1.5, 8.0, 5.0)

		# Anchor dot — HDR
		draw_circle(ship_pt, 5.0, Color(base_color.r * h, base_color.g * h, base_color.b * h, 0.8))

		# Constant-velocity pulse dot
		var seg1_len: float = ship_pt.distance_to(elbow)
		var seg2_len: float = elbow.distance_to(panel_edge)
		var total_len: float = seg1_len + seg2_len
		if total_len < 1.0:
			continue

		var cycle_time: float = total_len / PULSE_SPEED
		var phase: float = float(hash(sub_name) % 1000) / 1000.0
		var dist: float = fmod((_time + phase * cycle_time), cycle_time) / cycle_time * total_len
		dist = total_len - dist  # Reverse: panel → ship

		var pulse_pos: Vector2
		if dist <= seg1_len:
			pulse_pos = ship_pt.lerp(elbow, dist / seg1_len)
		else:
			pulse_pos = elbow.lerp(panel_edge, (dist - seg1_len) / seg2_len)

		draw_circle(pulse_pos, 4.0, Color(base_color.r * h, base_color.g * h, base_color.b * h, 1.0))


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var total: float = from.distance_to(to)
	if total < 0.1:
		return
	var dir: Vector2 = (to - from).normalized()
	var pos: float = 0.0
	while pos < total:
		var seg_end: float = minf(pos + dash, total)
		draw_line(from + dir * pos, from + dir * seg_end, color, width)
		pos = seg_end + gap


func _draw_scan_line() -> void:
	var h: float = hdr_ship
	var fl: float = _frame_left()
	var fr: float = _frame_right()
	var ft: float = _frame_top()
	var fb: float = _frame_bottom()
	var scan_range: float = fb - ft

	var scan_y: float = ft + fmod(_time * 50.0, scan_range)

	# Pulsing HDR
	var pulse: float = 0.6 + 0.4 * sin(_time * 3.5)
	var scan_alpha: float = 0.3 * pulse

	draw_line(Vector2(fl, scan_y), Vector2(fr, scan_y),
		Color(0.0, 1.0 * h, 0.4 * h, scan_alpha), 2.0)
	# Wide glow pass
	draw_line(Vector2(fl, scan_y), Vector2(fr, scan_y),
		Color(0.0, 0.8 * h, 0.35 * h, scan_alpha * 0.3), 8.0)

	for i in range(1, 10):
		var trail_y: float = scan_y - i * 4.0
		if trail_y < ft:
			break
		var trail_alpha: float = scan_alpha * 0.5 * (1.0 - i / 10.0)
		draw_line(Vector2(fl, trail_y), Vector2(fr, trail_y),
			Color(0.0, 0.8 * h, 0.3 * h, trail_alpha), 1.0)


func _draw_dimension_marks() -> void:
	var fl: float = _frame_left() + 10
	var fr: float = _frame_right() - 10
	var ft: float = _frame_top() + 10
	var fb: float = _frame_bottom() - 10
	var dim_color := Color(0.0, 0.6, 0.3, 0.2)

	# Width mark near bottom
	var w_y: float = fb - 15
	draw_line(Vector2(fl, w_y), Vector2(fr, w_y), dim_color, 1.0)
	draw_line(Vector2(fl, w_y - 6), Vector2(fl, w_y + 6), dim_color, 1.0)
	draw_line(Vector2(fr, w_y - 6), Vector2(fr, w_y + 6), dim_color, 1.0)

	# Height mark near right edge
	var h_x: float = fr - 15
	draw_line(Vector2(h_x, ft), Vector2(h_x, fb), dim_color, 1.0)
	draw_line(Vector2(h_x - 6, ft), Vector2(h_x + 6, ft), dim_color, 1.0)
	draw_line(Vector2(h_x - 6, fb), Vector2(h_x + 6, fb), dim_color, 1.0)
