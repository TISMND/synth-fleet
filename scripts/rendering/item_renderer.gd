class_name ItemRenderer
extends Node2D
## Procedural item renderer — draws currency pickups and powerup circles.
## Used by the items tab preview and (eventually) the game runtime.
## Follows PREVIEWS MUST = GAME REALITY rule.

var _item: ItemData = null
var _time: float = 0.0
var _base_size: float = 32.0


func setup(item: ItemData, base_size: float = 32.0) -> void:
	_item = item
	_base_size = base_size
	queue_redraw()


func _process(delta: float) -> void:
	if not _item:
		return
	if _item.animation_style == "static":
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not _item:
		return

	var primary := Color.from_string(_item.primary_color, Color.GOLD)
	var secondary := Color.from_string(_item.secondary_color, Color.DARK_GOLDENROD)
	var glow := Color.from_string(_item.glow_color, Color.YELLOW)
	var s: float = _base_size
	var center := Vector2.ZERO

	# Animation transforms
	var anim_scale: float = 1.0
	var anim_squeeze_x: float = 1.0
	var anim_offset_y: float = 0.0
	var shimmer_phase: float = 0.0

	match _item.animation_style:
		"spin":
			anim_squeeze_x = 0.5 + 0.5 * abs(cos(_time * 3.0))
		"pulse":
			anim_scale = 0.9 + 0.1 * sin(_time * 4.0)
		"shimmer":
			shimmer_phase = fmod(_time * 2.0, 1.0)
		"bob":
			anim_offset_y = sin(_time * 3.0) * s * 0.08

	center.y += anim_offset_y
	s *= anim_scale

	# Outer glow
	var glow_alpha: float = 0.15 + 0.08 * sin(_time * 2.5)
	var glow_col := Color(glow.r, glow.g, glow.b, glow_alpha)
	draw_circle(center, s * 0.9, glow_col)
	draw_circle(center, s * 0.7, Color(glow.r, glow.g, glow.b, glow_alpha * 0.6))

	match _item.visual_shape:
		"coin":
			_draw_coin(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"diamond":
			_draw_diamond(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"gem_round":
			_draw_gem_round(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"gem_oval":
			_draw_gem_oval(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"crystal":
			_draw_crystal(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"bar":
			_draw_bar(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"chip":
			_draw_chip(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"star":
			_draw_star_shape(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"circle":
			_draw_powerup_circle(center, s, primary, secondary, glow, shimmer_phase)
		_:
			_draw_coin(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)

	# Powerup icon overlay
	if _item.icon != "":
		_draw_icon(center, s * 0.4, _item.icon, glow)


# ── Shapes ───────────────────────────────────────────────────────────────

func _draw_coin(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.45
	var rx: float = r * squeeze_x

	# Edge (darker ring)
	_draw_ellipse(center, rx + 2, r + 2, 24, secondary.darkened(0.3))
	# Main body
	_draw_ellipse(center, rx, r, 24, primary)
	# Inner ring
	_draw_ellipse_arc(center, rx * 0.7, r * 0.7, 24, secondary)
	# Center emblem — small circle
	_draw_ellipse(center, rx * 0.2, r * 0.2, 12, secondary.lightened(0.2))
	# Highlight arc (top)
	_draw_ellipse_highlight(center - Vector2(0, r * 0.15), rx * 0.55, r * 0.35, glow, shimmer)
	# Sparkle dots
	_draw_sparkles(center, r, glow, shimmer)


func _draw_diamond(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.35 * squeeze_x
	var h: float = s * 0.5
	var girdle_y: float = -h * 0.15  # Where the widest point is (slightly above center)

	# Diamond outline points: top, right, bottom-right, bottom, bottom-left, left
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h),          # Crown tip
		center + Vector2(w, girdle_y),     # Right girdle
		center + Vector2(w * 0.4, h),      # Bottom right
		center + Vector2(0, h),            # Pavilion point
		center + Vector2(-w * 0.4, h),     # Bottom left
		center + Vector2(-w, girdle_y),    # Left girdle
	])

	# Fill
	draw_colored_polygon(pts, primary)

	# Facet lines from crown to girdle
	draw_line(pts[0], center + Vector2(0, girdle_y), secondary.lightened(0.3), 1.0)
	draw_line(pts[0], pts[1], secondary, 1.0)
	draw_line(pts[0], pts[5], secondary, 1.0)
	# Girdle line
	draw_line(pts[1], pts[5], secondary.lightened(0.1), 1.5)
	# Pavilion facets
	draw_line(pts[3], pts[1], secondary.darkened(0.1), 1.0)
	draw_line(pts[3], pts[5], secondary.darkened(0.1), 1.0)

	# Highlight triangle (upper left facet)
	var highlight_pts: PackedVector2Array = PackedVector2Array([
		pts[0],
		center + Vector2(0, girdle_y),
		pts[5],
	])
	draw_colored_polygon(highlight_pts, Color(glow.r, glow.g, glow.b, 0.2))

	_draw_sparkles(center, s * 0.4, glow, shimmer)


func _draw_gem_round(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.4
	var rx: float = r * squeeze_x

	# Shadow
	_draw_ellipse(center + Vector2(1, 2), rx, r, 20, primary.darkened(0.4))
	# Main gem body
	_draw_ellipse(center, rx, r, 20, primary)
	# Inner facet ring
	_draw_ellipse_arc(center, rx * 0.6, r * 0.6, 16, secondary.lightened(0.2))
	# Bright center
	_draw_ellipse(center - Vector2(rx * 0.15, r * 0.15), rx * 0.25, r * 0.25, 12, glow.lightened(0.3))
	# Top highlight crescent
	_draw_ellipse_highlight(center - Vector2(0, r * 0.2), rx * 0.4, r * 0.2, glow, shimmer)

	_draw_sparkles(center, r, glow, shimmer)


func _draw_gem_oval(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var rx: float = s * 0.45 * squeeze_x
	var ry: float = s * 0.3

	_draw_ellipse(center + Vector2(1, 2), rx, ry, 20, primary.darkened(0.4))
	_draw_ellipse(center, rx, ry, 20, primary)
	# Cross facet lines
	draw_line(center + Vector2(-rx * 0.7, 0), center + Vector2(rx * 0.7, 0), secondary.lightened(0.1), 1.0)
	draw_line(center + Vector2(0, -ry * 0.7), center + Vector2(0, ry * 0.7), secondary.lightened(0.1), 1.0)
	# Bright center
	_draw_ellipse(center - Vector2(rx * 0.1, ry * 0.15), rx * 0.2, ry * 0.2, 10, glow.lightened(0.2))

	_draw_sparkles(center, maxf(rx, ry), glow, shimmer)


func _draw_crystal(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.25 * squeeze_x
	var h: float = s * 0.5

	# Main crystal shard
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, -h * 0.3),
		center + Vector2(w * 0.7, h * 0.5),
		center + Vector2(0, h),
		center + Vector2(-w * 0.7, h * 0.5),
		center + Vector2(-w, -h * 0.3),
	])
	draw_colored_polygon(pts, primary)

	# Left facet (darker)
	var left_facet: PackedVector2Array = PackedVector2Array([pts[0], pts[5], pts[4], pts[3]])
	draw_colored_polygon(left_facet, primary.darkened(0.15))
	# Right facet (lighter)
	var right_facet: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], pts[3]])
	draw_colored_polygon(right_facet, primary.lightened(0.1))

	# Edge lines
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], secondary, 1.0)
	# Center line
	draw_line(pts[0], pts[3], secondary.lightened(0.2), 1.0)

	# Highlight streak
	var streak_alpha: float = 0.3 + 0.15 * sin(shimmer * TAU)
	draw_line(center + Vector2(w * 0.2, -h * 0.7), center + Vector2(w * 0.1, h * 0.2), Color(glow.r, glow.g, glow.b, streak_alpha), 2.0)

	_draw_sparkles(center, h * 0.8, glow, shimmer)


func _draw_bar(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.55 * squeeze_x
	var h: float = s * 0.3

	# Shadow
	draw_rect(Rect2(center + Vector2(-w + 1, -h * 0.4 + 2), Vector2(w * 2, h)), primary.darkened(0.5))
	# Main bar
	draw_rect(Rect2(center + Vector2(-w, -h * 0.4), Vector2(w * 2, h)), primary)
	# Top bevel (lighter)
	draw_rect(Rect2(center + Vector2(-w, -h * 0.4), Vector2(w * 2, h * 0.3)), primary.lightened(0.15))
	# Border
	draw_rect(Rect2(center + Vector2(-w, -h * 0.4), Vector2(w * 2, h)), secondary, false, 1.5)
	# Embossed lines
	for i in range(3):
		var x_off: float = -w * 0.5 + float(i) * w * 0.5
		draw_line(
			center + Vector2(x_off, -h * 0.25),
			center + Vector2(x_off, h * 0.45),
			secondary.darkened(0.15), 1.0
		)

	# Shine streak
	var streak_x: float = lerpf(-w, w, shimmer)
	var streak_col := Color(glow.r, glow.g, glow.b, 0.35)
	draw_line(center + Vector2(streak_x, -h * 0.35), center + Vector2(streak_x + w * 0.2, h * 0.5), streak_col, 3.0)

	_draw_sparkles(center, w, glow, shimmer)


func _draw_chip(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.4 * squeeze_x
	var h: float = s * 0.28

	# Card body
	draw_rect(Rect2(center + Vector2(-w, -h), Vector2(w * 2, h * 2)), primary)
	draw_rect(Rect2(center + Vector2(-w, -h), Vector2(w * 2, h * 2)), secondary, false, 1.5)
	# Chip contact (small gold square)
	var chip_s: float = minf(w, h) * 0.4
	draw_rect(Rect2(center + Vector2(-chip_s * 0.7, -chip_s * 0.5), Vector2(chip_s * 1.4, chip_s)), secondary.lightened(0.3))
	draw_rect(Rect2(center + Vector2(-chip_s * 0.7, -chip_s * 0.5), Vector2(chip_s * 1.4, chip_s)), glow.darkened(0.2), false, 1.0)
	# Circuit lines
	draw_line(center + Vector2(chip_s * 0.7, 0), center + Vector2(w * 0.8, 0), secondary.darkened(0.1), 1.0)
	draw_line(center + Vector2(0, chip_s * 0.5), center + Vector2(0, h * 0.7), secondary.darkened(0.1), 1.0)

	_draw_sparkles(center, maxf(w, h), glow, shimmer)


func _draw_star_shape(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r_outer: float = s * 0.45
	var r_inner: float = r_outer * 0.4
	var points: int = 5
	var pts: PackedVector2Array = PackedVector2Array()

	for i in range(points * 2):
		var angle: float = -PI / 2.0 + float(i) * PI / float(points)
		var r: float = r_outer if (i % 2 == 0) else r_inner
		var px: float = cos(angle) * r * squeeze_x
		var py: float = sin(angle) * r
		pts.append(center + Vector2(px, py))

	# Shadow
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for pt in pts:
		shadow_pts.append(pt + Vector2(1, 2))
	draw_colored_polygon(shadow_pts, primary.darkened(0.4))

	# Main star
	draw_colored_polygon(pts, primary)

	# Edge
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], secondary, 1.0)

	# Center highlight
	_draw_ellipse(center, r_inner * 0.5 * squeeze_x, r_inner * 0.5, 10, glow.lightened(0.2))

	_draw_sparkles(center, r_outer, glow, shimmer)


func _draw_powerup_circle(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.42

	# Outer glow ring
	var ring_alpha: float = 0.4 + 0.15 * sin(_time * 3.0)
	draw_arc(center, r + 4, 0.0, TAU, 32, Color(glow.r, glow.g, glow.b, ring_alpha), 3.0)
	draw_arc(center, r + 7, 0.0, TAU, 32, Color(glow.r, glow.g, glow.b, ring_alpha * 0.4), 2.0)

	# Background circle
	draw_circle(center, r, primary.darkened(0.2))
	# Inner fill with slight gradient (lighter center)
	draw_circle(center, r * 0.85, primary)
	draw_circle(center, r * 0.55, primary.lightened(0.1))

	# Rim highlight (top arc)
	draw_arc(center, r * 0.9, -PI * 0.8, -PI * 0.2, 12, Color(glow.r, glow.g, glow.b, 0.3), 2.0)

	# Edge ring
	draw_arc(center, r, 0.0, TAU, 32, secondary, 2.0)

	# Rotating shimmer arc
	var arc_start: float = shimmer * TAU
	draw_arc(center, r * 0.9, arc_start, arc_start + 0.8, 8, Color(glow.r, glow.g, glow.b, 0.25), 2.5)

	_draw_sparkles(center, r, glow, shimmer)


# ── Icons (for powerups) ────────────────────────────────────────────────

func _draw_icon(center: Vector2, icon_size: float, icon_name: String, color: Color) -> void:
	var col := Color(color.r, color.g, color.b, 0.9)
	var s: float = icon_size

	match icon_name:
		"shield":
			# Shield shape
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -s),
				center + Vector2(s * 0.8, -s * 0.5),
				center + Vector2(s * 0.8, s * 0.2),
				center + Vector2(0, s),
				center + Vector2(-s * 0.8, s * 0.2),
				center + Vector2(-s * 0.8, -s * 0.5),
			])
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.3))
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], col, 2.0)
		"cross":
			# Medical cross
			var t: float = s * 0.25
			draw_rect(Rect2(center + Vector2(-t, -s * 0.7), Vector2(t * 2, s * 1.4)), col)
			draw_rect(Rect2(center + Vector2(-s * 0.7, -t), Vector2(s * 1.4, t * 2)), col)
		"arrow_up":
			# Up arrow (speed)
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -s * 0.8),
				center + Vector2(s * 0.6, s * 0.1),
				center + Vector2(s * 0.25, s * 0.1),
				center + Vector2(s * 0.25, s * 0.8),
				center + Vector2(-s * 0.25, s * 0.8),
				center + Vector2(-s * 0.25, s * 0.1),
				center + Vector2(-s * 0.6, s * 0.1),
			])
			draw_colored_polygon(pts, col)
		"sword":
			# Sword / damage boost
			draw_line(center + Vector2(0, -s * 0.9), center + Vector2(0, s * 0.4), col, 2.5)
			# Blade tip
			draw_line(center + Vector2(-s * 0.15, -s * 0.6), center + Vector2(0, -s * 0.9), col, 2.0)
			draw_line(center + Vector2(s * 0.15, -s * 0.6), center + Vector2(0, -s * 0.9), col, 2.0)
			# Crossguard
			draw_line(center + Vector2(-s * 0.5, s * 0.1), center + Vector2(s * 0.5, s * 0.1), col, 2.5)
			# Pommel
			draw_circle(center + Vector2(0, s * 0.55), s * 0.1, col)
		"snowflake":
			# Snowflake / thermal dump
			for i in range(6):
				var angle: float = float(i) * PI / 3.0
				var dir := Vector2(cos(angle), sin(angle))
				draw_line(center, center + dir * s * 0.7, col, 2.0)
				# Branch tips
				var mid: Vector2 = center + dir * s * 0.45
				var perp := Vector2(-dir.y, dir.x)
				draw_line(mid, mid + (dir + perp) * s * 0.2, col, 1.5)
				draw_line(mid, mid + (dir - perp) * s * 0.2, col, 1.5)
		"bolt":
			# Lightning bolt
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(s * 0.1, -s * 0.9),
				center + Vector2(s * 0.4, -s * 0.9),
				center + Vector2(s * 0.05, -s * 0.1),
				center + Vector2(s * 0.35, -s * 0.1),
				center + Vector2(-s * 0.15, s * 0.9),
				center + Vector2(0, s * 0.1),
				center + Vector2(-s * 0.3, s * 0.1),
			])
			draw_colored_polygon(pts, col)
		"star":
			# Small 4-point star / invincibility
			for i in range(4):
				var angle: float = float(i) * PI / 2.0 - PI / 4.0
				var dir := Vector2(cos(angle), sin(angle))
				var pts: PackedVector2Array = PackedVector2Array([
					center + dir * s * 0.8,
					center + Vector2(-dir.y, dir.x) * s * 0.2,
					center + Vector2(dir.y, -dir.x) * s * 0.2,
				])
				draw_colored_polygon(pts, col)
			draw_circle(center, s * 0.15, col.lightened(0.3))
		"magnet":
			# U-shaped magnet
			draw_arc(center + Vector2(0, s * 0.1), s * 0.45, PI, TAU, 12, col, 3.0)
			draw_line(center + Vector2(-s * 0.45, s * 0.1), center + Vector2(-s * 0.45, -s * 0.5), col, 3.0)
			draw_line(center + Vector2(s * 0.45, s * 0.1), center + Vector2(s * 0.45, -s * 0.5), col, 3.0)
			# Red/blue tips
			draw_line(center + Vector2(-s * 0.45, -s * 0.5), center + Vector2(-s * 0.45, -s * 0.8), Color.RED, 3.0)
			draw_line(center + Vector2(s * 0.45, -s * 0.5), center + Vector2(s * 0.45, -s * 0.8), Color.CORNFLOWER_BLUE, 3.0)


# ── Drawing Helpers ──────────────────────────────────────────────────────

func _draw_ellipse(center: Vector2, rx: float, ry: float, segments: int, color: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = float(i) * TAU / float(segments)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(pts, color)


func _draw_ellipse_arc(center: Vector2, rx: float, ry: float, segments: int, color: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	for i in range(segments):
		var a1: float = float(i) * TAU / float(segments)
		var a2: float = float(i + 1) * TAU / float(segments)
		draw_line(
			center + Vector2(cos(a1) * rx, sin(a1) * ry),
			center + Vector2(cos(a2) * rx, sin(a2) * ry),
			color, 1.5
		)


func _draw_ellipse_highlight(center: Vector2, rx: float, ry: float, color: Color, shimmer: float) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var alpha: float = 0.2 + 0.15 * sin(shimmer * TAU)
	var col := Color(color.r, color.g, color.b, alpha)
	_draw_ellipse(center, rx, ry, 12, col)


func _draw_sparkles(center: Vector2, radius: float, color: Color, shimmer: float) -> void:
	# 3-4 small sparkle dots that twinkle
	var sparkle_positions: Array[Vector2] = [
		center + Vector2(radius * 0.6, -radius * 0.5),
		center + Vector2(-radius * 0.4, -radius * 0.7),
		center + Vector2(radius * 0.3, radius * 0.6),
		center + Vector2(-radius * 0.7, radius * 0.2),
	]
	for i in range(sparkle_positions.size()):
		var phase: float = shimmer + float(i) * 0.25
		var alpha: float = maxf(0.0, sin(phase * TAU)) * 0.8
		if alpha > 0.05:
			var col := Color(color.r, color.g, color.b, alpha)
			var sp: float = 1.5 + alpha * 2.0
			var pos: Vector2 = sparkle_positions[i]
			draw_circle(pos, sp, col)
			# Cross sparkle lines
			draw_line(pos + Vector2(-sp * 1.5, 0), pos + Vector2(sp * 1.5, 0), Color(col.r, col.g, col.b, alpha * 0.5), 1.0)
			draw_line(pos + Vector2(0, -sp * 1.5), pos + Vector2(0, sp * 1.5), Color(col.r, col.g, col.b, alpha * 0.5), 1.0)
