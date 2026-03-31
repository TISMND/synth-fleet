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
			# cos goes -1..1, abs gives 0..1. Pow flattens the curve so it spends
			# more time thin (near 0) and snaps wide, selling a full rotation.
			var raw: float = abs(cos(_time * 3.0))
			anim_squeeze_x = 0.04 + 0.96 * raw * raw  # squeezes to ~4% width
		"pulse":
			anim_scale = 0.9 + 0.1 * sin(_time * 4.0)
		"shimmer":
			shimmer_phase = fmod(_time * 2.0, 1.0)
		"bob":
			anim_offset_y = sin(_time * 3.0) * s * 0.08

	center.y += anim_offset_y
	s *= anim_scale

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
		"neon_coin":
			_draw_neon_coin(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"glow_coin":
			_draw_glow_coin(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)
		"neon_star":
			_draw_neon_star(center, s, primary, secondary, glow, shimmer_phase)
		"neon_diamond":
			_draw_neon_diamond(center, s, primary, secondary, glow, shimmer_phase)
		"neon_hex":
			_draw_neon_hex(center, s, primary, secondary, glow, shimmer_phase)
		"energy_orb":
			_draw_energy_orb(center, s, primary, secondary, glow, shimmer_phase)
		"data_shard":
			_draw_data_shard(center, s, primary, secondary, glow, shimmer_phase)
		"shard_jagged":
			_draw_shard_jagged(center, s, primary, secondary, glow, shimmer_phase)
		"shard_cleave":
			_draw_shard_cleave(center, s, primary, secondary, glow, shimmer_phase)
		"shard_hook":
			_draw_shard_hook(center, s, primary, secondary, glow, shimmer_phase)
		"shard_splint":
			_draw_shard_splint(center, s, primary, secondary, glow, shimmer_phase)
		"shard_chunk":
			_draw_shard_chunk(center, s, primary, secondary, glow, shimmer_phase)
		"gem_shield":
			_draw_gem_shield(center, s, primary, secondary, glow, shimmer_phase)
		"gem_teardrop":
			_draw_gem_teardrop(center, s, primary, secondary, glow, shimmer_phase)
		"gem_rhombus":
			_draw_gem_rhombus(center, s, primary, secondary, glow, shimmer_phase)
		"gem_crown":
			_draw_gem_crown(center, s, primary, secondary, glow, shimmer_phase)
		"wire_kite":
			_draw_wire_kite(center, s, primary, secondary, glow, shimmer_phase)
		"wire_arrow":
			_draw_wire_arrow(center, s, primary, secondary, glow, shimmer_phase)
		"wire_prism":
			_draw_wire_prism(center, s, primary, secondary, glow, shimmer_phase)
		"wire_fang":
			_draw_wire_fang(center, s, primary, secondary, glow, shimmer_phase)
		"wire_sliver":
			_draw_wire_sliver(center, s, primary, secondary, glow, shimmer_phase)
		"wire_trap":
			_draw_wire_trap(center, s, primary, secondary, glow, shimmer_phase)
		"wire_marquise":
			_draw_wire_marquise(center, s, primary, secondary, glow, shimmer_phase)
		"wire_emerald":
			_draw_wire_emerald(center, s, primary, secondary, glow, shimmer_phase)
		"wire_penta":
			_draw_wire_penta(center, s, primary, secondary, glow, shimmer_phase)
		"wire_wedge":
			_draw_wire_wedge(center, s, primary, secondary, glow, shimmer_phase)
		_:
			_draw_coin(center, s, anim_squeeze_x, primary, secondary, glow, shimmer_phase)

	# Powerup icon overlay
	if _item.icon != "":
		_draw_icon(center, s * 0.4, _item.icon, glow)


# ── Shapes ───────────────────────────────────────────────────────────────

func _draw_coin(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.45
	var rx: float = r * squeeze_x
	var edge_w: float = s * 0.08  # Physical coin thickness (constant)

	# --- Coin edge / rim (always drawn behind face — visible when face is thinner) ---
	_draw_ellipse(center, edge_w, r, 16, secondary.darkened(0.4))
	if rx < edge_w:
		# Bevel lines for 3D cylinder depth on exposed rim
		var bevel_r: float = edge_w * 0.9
		# Right bevel (lighter — "lit" side)
		draw_line(center + Vector2(bevel_r, -r * 0.85), center + Vector2(bevel_r, r * 0.85),
			secondary.darkened(0.1), 1.5)
		# Left bevel (darker — "shadow" side)
		draw_line(center + Vector2(-bevel_r, -r * 0.85), center + Vector2(-bevel_r, r * 0.85),
			secondary.darkened(0.55), 1.0)
		# Center ridge on the rim
		draw_line(center + Vector2(0, -r * 0.8), center + Vector2(0, r * 0.8),
			secondary.darkened(0.25), 1.0)

	# --- Coin face (drawn on top — covers edge when wider) ---
	_draw_ellipse(center, rx + 2, r + 2, 24, secondary.darkened(0.3))
	_draw_ellipse(center, rx, r, 24, primary)

	# Face details only when wide enough to read
	if squeeze_x > 0.3:
		_draw_ellipse_arc(center, rx * 0.7, r * 0.7, 24, secondary)
		_draw_ellipse(center, rx * 0.2, r * 0.2, 12, secondary.lightened(0.2))
		_draw_ellipse_highlight(center - Vector2(0, r * 0.15), rx * 0.55, r * 0.35, glow, shimmer)

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

	# Subtle core glow for bloom (replaces removed outer concentric rings)
	var hdr: float = 2.5
	var core_alpha: float = 0.15 + 0.05 * sin(_time * 3.0)
	draw_circle(center, r * 0.4, Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, core_alpha))

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

	# No sparkles on powerups — icon HDR pulse handles the shimmer


# ── Icons (for powerups) ────────────────────────────────────────────────

func _draw_icon(center: Vector2, icon_size: float, icon_name: String, color: Color) -> void:
	# Pulsing HDR glow on powerup icons
	var pulse: float = 1.5 + 0.8 * sin(_time * 3.0)
	var col := Color(color.r * pulse, color.g * pulse, color.b * pulse, 0.9)
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


func _draw_ellipse_arc(center: Vector2, rx: float, ry: float, segments: int, color: Color, width: float = 1.5) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	for i in range(segments):
		var a1: float = float(i) * TAU / float(segments)
		var a2: float = float(i + 1) * TAU / float(segments)
		draw_line(
			center + Vector2(cos(a1) * rx, sin(a1) * ry),
			center + Vector2(cos(a2) * rx, sin(a2) * ry),
			color, width
		)


func _draw_ellipse_highlight(center: Vector2, rx: float, ry: float, color: Color, shimmer: float) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var alpha: float = 0.2 + 0.15 * sin(shimmer * TAU)
	var col := Color(color.r, color.g, color.b, alpha)
	_draw_ellipse(center, rx, ry, 12, col)


func _draw_sparkles(center: Vector2, radius: float, color: Color, shimmer: float) -> void:
	# Slow occasional twinkles — each sparkle has its own frequency and phase offset
	# so they fire independently rather than pulsing in sync.
	var hdr: float = 2.0
	var sparkle_positions: Array[Vector2] = [
		center + Vector2(radius * 0.6, -radius * 0.5),
		center + Vector2(-radius * 0.4, -radius * 0.7),
		center + Vector2(radius * 0.3, radius * 0.6),
		center + Vector2(-radius * 0.7, radius * 0.2),
	]
	for i in range(sparkle_positions.size()):
		# Staggered slow frequencies (0.25–0.7 Hz) with irrational phase offsets
		var freq: float = 0.25 + float(i) * 0.14
		var phase_offset: float = float(i) * 1.7 + float(i * i) * 0.9
		var raw: float = sin(_time * freq * TAU + phase_offset)
		# Narrow peak: only visible when raw > 0.7 — brief occasional flash
		var alpha: float = maxf(0.0, (raw - 0.7) / 0.3) * 0.8
		if alpha > 0.05:
			var col := Color(color.r * hdr, color.g * hdr, color.b * hdr, alpha)
			var sp: float = 1.5 + alpha * 2.0
			var pos: Vector2 = sparkle_positions[i]
			draw_circle(pos, sp, col)
			# Cross sparkle lines
			var line_col := Color(color.r * hdr, color.g * hdr, color.b * hdr, alpha * 0.5)
			draw_line(pos + Vector2(-sp * 1.5, 0), pos + Vector2(sp * 1.5, 0), line_col, 1.0)
			draw_line(pos + Vector2(0, -sp * 1.5), pos + Vector2(0, sp * 1.5), line_col, 1.0)


# ── Neon / New Shapes ───────────────────────────────────────────────────

func _draw_neon_coin(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.45
	var rx: float = r * squeeze_x
	var edge_w: float = s * 0.08
	var hdr: float = _item.hdr_intensity if _item else 2.5

	var line_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.9)
	var dim_col := Color(primary.r * hdr, primary.g * hdr, primary.b * hdr, 0.35)

	# --- Edge/rim wireframe when coin is near edge-on ---
	if rx < edge_w:
		var bevel_r: float = edge_w * 0.9
		draw_line(center + Vector2(bevel_r, -r * 0.9), center + Vector2(bevel_r, r * 0.9),
			Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.6), 1.5)
		draw_line(center + Vector2(-bevel_r, -r * 0.9), center + Vector2(-bevel_r, r * 0.9),
			Color(primary.r * hdr, primary.g * hdr, primary.b * hdr, 0.3), 1.0)
		draw_line(center + Vector2(0, -r * 0.85), center + Vector2(0, r * 0.85),
			dim_col, 1.0)

	# --- Face wireframe ---
	_draw_ellipse_arc(center, rx, r, 24, line_col, 2.0)

	# Face details when wide enough to read
	if squeeze_x > 0.3:
		_draw_ellipse_arc(center, rx * 0.7, r * 0.7, 20, dim_col, 1.5)
		var core: float = hdr * 1.2
		draw_circle(center, s * 0.05, Color(glow.r * core, glow.g * core, glow.b * core, 0.5))

	_draw_sparkles(center, r, glow, shimmer)


func _draw_glow_coin(center: Vector2, s: float, squeeze_x: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.45
	var rx: float = r * squeeze_x
	var edge_w: float = s * 0.08
	var hdr: float = _item.hdr_intensity if _item else 2.5

	# --- Filled rim when edge-on ---
	if rx < edge_w:
		_draw_ellipse(center, edge_w, r, 16, secondary.darkened(0.35))
		var bevel_r: float = edge_w * 0.9
		var rim_glow := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.5)
		draw_line(center + Vector2(bevel_r, -r * 0.9), center + Vector2(bevel_r, r * 0.9), rim_glow, 1.5)
		draw_line(center + Vector2(-bevel_r, -r * 0.9), center + Vector2(-bevel_r, r * 0.9),
			Color(secondary.r * hdr, secondary.g * hdr, secondary.b * hdr, 0.25), 1.0)

	# --- Filled face ---
	_draw_ellipse(center, rx, r, 24, primary)
	# Lighter center for 3D depth
	_draw_ellipse(center, rx * 0.6, r * 0.6, 16, primary.lightened(0.1))

	# HDR glowing edge arc on top
	var edge_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.7)
	_draw_ellipse_arc(center, rx, r, 24, edge_col, 1.5)

	# Face details when wide enough
	if squeeze_x > 0.3:
		# Dim inner ring
		var dim_col := Color(secondary.r * hdr, secondary.g * hdr, secondary.b * hdr, 0.35)
		_draw_ellipse_arc(center, rx * 0.7, r * 0.7, 20, dim_col, 1.0)
		# Center glow
		var core: float = hdr * 1.2
		draw_circle(center, s * 0.04, Color(glow.r * core, glow.g * core, glow.b * core, 0.4))

	_draw_sparkles(center, r, glow, shimmer)


func _draw_neon_star(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r_outer: float = s * 0.45
	var r_inner: float = r_outer * 0.4
	var points: int = 5
	var hdr: float = _item.hdr_intensity if _item else 1.5

	# Build star vertices
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(points * 2):
		var angle: float = -PI / 2.0 + float(i) * PI / float(points)
		var r: float = r_outer if (i % 2 == 0) else r_inner
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))

	# Outer lines — bright HDR for bloom
	var line_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.9)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], line_col, 2.0)

	# Inner star (smaller, dimmer) for depth
	var dim_col := Color(primary.r * hdr, primary.g * hdr, primary.b * hdr, 0.35)
	var inner_pts: PackedVector2Array = PackedVector2Array()
	for i in range(points * 2):
		var angle: float = -PI / 2.0 + float(i) * PI / float(points)
		var r: float = (r_outer * 0.65) if (i % 2 == 0) else (r_inner * 0.65)
		inner_pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	for i in range(inner_pts.size()):
		draw_line(inner_pts[i], inner_pts[(i + 1) % inner_pts.size()], dim_col, 1.0)

	# Center glow dot
	var core_s: float = hdr * 1.2
	draw_circle(center, s * 0.07, Color(glow.r * core_s, glow.g * core_s, glow.b * core_s, 0.4))

	_draw_sparkles(center, r_outer, glow, shimmer)


func _draw_neon_diamond(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.35
	var h: float = s * 0.5
	var girdle_y: float = -h * 0.15
	var hdr: float = _item.hdr_intensity if _item else 2.5

	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, girdle_y),
		center + Vector2(w * 0.4, h),
		center + Vector2(0, h),
		center + Vector2(-w * 0.4, h),
		center + Vector2(-w, girdle_y),
	])

	# Outline with HDR glow
	var line_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.9)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], line_col, 2.0)

	# Internal facet lines
	var facet_col := Color(primary.r * hdr, primary.g * hdr, primary.b * hdr, 0.35)
	draw_line(pts[0], center + Vector2(0, girdle_y), facet_col, 1.0)
	draw_line(pts[0], pts[3], facet_col, 1.0)
	draw_line(pts[1], pts[5], facet_col, 1.5)
	draw_line(pts[3], pts[1], facet_col, 1.0)
	draw_line(pts[3], pts[5], facet_col, 1.0)

	# Bright core at girdle center
	var core_d: float = hdr * 1.2
	draw_circle(center + Vector2(0, girdle_y * 0.5), s * 0.06, Color(glow.r * core_d, glow.g * core_d, glow.b * core_d, 0.55))

	_draw_sparkles(center, h * 0.8, glow, shimmer)


func _draw_neon_hex(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.42
	var hdr: float = _item.hdr_intensity if _item else 1.5

	# Outer hex
	var outer_pts: PackedVector2Array = _hex_points(center, r)
	var line_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.9)
	for i in range(6):
		draw_line(outer_pts[i], outer_pts[(i + 1) % 6], line_col, 2.5)

	# Inner hex
	var inner_pts: PackedVector2Array = _hex_points(center, r * 0.55)
	var dim_col := Color(primary.r * hdr, primary.g * hdr, primary.b * hdr, 0.4)
	for i in range(6):
		draw_line(inner_pts[i], inner_pts[(i + 1) % 6], dim_col, 1.5)

	# Connecting spokes
	var spoke_col := Color(secondary.r * hdr, secondary.g * hdr, secondary.b * hdr, 0.25)
	for i in range(6):
		draw_line(outer_pts[i], inner_pts[i], spoke_col, 1.0)

	# Corner dots
	for pt in outer_pts:
		draw_circle(pt, 2.0, line_col)

	# Center glow
	var core_h: float = hdr * 1.2
	draw_circle(center, s * 0.08, Color(glow.r * core_h, glow.g * core_h, glow.b * core_h, 0.35))

	_draw_sparkles(center, r, glow, shimmer)


func _draw_energy_orb(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.42
	var hdr: float = _item.hdr_intensity if _item else 2.0

	# Outer sphere — dark rim for 3D depth
	draw_circle(center, r, primary.darkened(0.3))

	# Gradient layers — lighter toward upper-left for 3D sphere illusion
	var offset := Vector2(-r * 0.15, -r * 0.15)
	draw_circle(center + offset * 0.3, r * 0.85, primary)
	draw_circle(center + offset * 0.5, r * 0.65, primary.lightened(0.15))
	draw_circle(center + offset * 0.7, r * 0.4, primary.lightened(0.3))

	# Specular highlight spot (upper left)
	var highlight := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.45)
	draw_circle(center + Vector2(-r * 0.2, -r * 0.25), r * 0.15, highlight)

	# Bright pulsing core
	var core_e: float = hdr * 1.2
	var core_pulse: float = 0.35 + 0.2 * sin(_time * 3.5)
	var core_col := Color(glow.r * core_e, glow.g * core_e, glow.b * core_e, core_pulse)
	draw_circle(center, r * 0.12, core_col)

	# Rim highlight arc (top edge)
	draw_arc(center, r * 0.92, -PI * 0.75, -PI * 0.25, 12, Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.25), 1.5)

	_draw_sparkles(center, r, glow, shimmer)


func _draw_data_shard(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.3
	var h: float = s * 0.5
	var hdr: float = _item.hdr_intensity if _item else 2.0

	# Asymmetric angular shard — 5 vertices
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(-w * 0.2, -h),
		center + Vector2(w, -h * 0.4),
		center + Vector2(w * 0.6, h * 0.7),
		center + Vector2(-w * 0.3, h),
		center + Vector2(-w * 0.8, h * 0.1),
	])

	# Right facet (brightest — "lit" side)
	var right_facet: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], center])
	draw_colored_polygon(right_facet, primary.lightened(0.2))

	# Left facet (darkest — "shadow" side)
	var left_facet: PackedVector2Array = PackedVector2Array([pts[0], pts[4], pts[3], center])
	draw_colored_polygon(left_facet, primary.darkened(0.2))

	# Bottom facet (mid tone)
	var bottom_facet: PackedVector2Array = PackedVector2Array([center, pts[2], pts[3]])
	draw_colored_polygon(bottom_facet, primary.darkened(0.05))

	# Edge lines with HDR for bloom
	var edge_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.7)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], edge_col, 1.5)

	# Internal facet edge from center to top
	draw_line(center, pts[0], Color(secondary.r * hdr, secondary.g * hdr, secondary.b * hdr, 0.35), 1.0)

	# Highlight streak on right facet
	var streak_alpha: float = 0.3 + 0.15 * sin(shimmer * TAU)
	draw_line(
		pts[0] + Vector2(w * 0.3, h * 0.1),
		center + Vector2(w * 0.2, 0),
		Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, streak_alpha), 2.0
	)

	_draw_sparkles(center, h * 0.8, glow, shimmer)


# ── Asymmetric Shard Shapes ─────────────────────────────────────────────

func _draw_shard_jagged(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.42
	var h: float = s * 0.55
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.15, -h),
		center + Vector2(w * 0.7, -h * 0.55),
		center + Vector2(w * 0.4, -h * 0.05),
		center + Vector2(w * 0.85, h * 0.45),
		center + Vector2(-w * 0.1, h * 0.8),
		center + Vector2(-w * 0.7, h * 0.15),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[3]],
		[pts[2], pts[5]],
	], glow, primary, secondary, shimmer)


func _draw_shard_cleave(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.4
	var h: float = s * 0.55
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.5, -h),
		center + Vector2(w * 0.3, -h * 0.7),
		center + Vector2(w * 0.9, -h * 0.1),
		center + Vector2(w * 0.5, h * 0.8),
		center + Vector2(-w * 0.5, h),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[3]],
		[pts[1], pts[4]],
	], glow, primary, secondary, shimmer)


func _draw_shard_hook(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.4
	var h: float = s * 0.55
	var pts := PackedVector2Array([
		center + Vector2(w * 0.2, -h),
		center + Vector2(w * 0.8, -h * 0.4),
		center + Vector2(w * 0.3, h * 0.2),
		center + Vector2(w * 0.6, h * 0.85),
		center + Vector2(-w * 0.5, h * 0.4),
		center + Vector2(-w * 0.3, -h * 0.3),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[3]],
		[pts[2], pts[5]],
	], glow, primary, secondary, shimmer)


func _draw_shard_splint(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.22
	var h: float = s * 0.58
	var pts := PackedVector2Array([
		center + Vector2(w * 0.3, -h),
		center + Vector2(w, -h * 0.2),
		center + Vector2(-w * 0.1, h),
		center + Vector2(-w * 0.8, h * 0.3),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
	], glow, primary, secondary, shimmer)


func _draw_shard_chunk(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.45
	var h: float = s * 0.45
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.3, -h),
		center + Vector2(w * 0.6, -h * 0.7),
		center + Vector2(w * 0.9, h * 0.1),
		center + Vector2(w * 0.2, h * 0.9),
		center + Vector2(-w * 0.7, h * 0.5),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[1], pts[4]],
		[pts[3], center],
	], glow, primary, secondary, shimmer)


# ── Symmetrical Gem Shapes ──────────────────────────────────────────────

func _draw_gem_shield(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.4
	var h: float = s * 0.52
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.75, -h * 0.45),
		center + Vector2(w * 0.75, -h * 0.45),
		center + Vector2(w * 0.75, h * 0.15),
		center + Vector2(0, h),
		center + Vector2(-w * 0.75, h * 0.15),
	])
	var mid_top: Vector2 = (pts[0] + pts[1]) * 0.5
	_draw_wire_shape(center, s, pts, [
		[mid_top, pts[3]],
		[pts[4], pts[2]],
	], glow, primary, secondary, shimmer)


func _draw_gem_teardrop(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.38
	var h: float = s * 0.55
	var pts := PackedVector2Array([
		center + Vector2(0, -h * 0.6),
		center + Vector2(w * 0.6, -h * 0.3),
		center + Vector2(w * 0.72, h * 0.05),
		center + Vector2(w * 0.38, h * 0.55),
		center + Vector2(0, h),
		center + Vector2(-w * 0.38, h * 0.55),
		center + Vector2(-w * 0.72, h * 0.05),
		center + Vector2(-w * 0.6, -h * 0.3),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[4]],
		[pts[2], pts[6]],
	], glow, primary, secondary, shimmer)


func _draw_gem_rhombus(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.48
	var h: float = s * 0.35
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, 0),
		center + Vector2(0, h),
		center + Vector2(-w, 0),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[1], pts[3]],
	], glow, primary, secondary, shimmer)


func _draw_gem_crown(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.45
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.85, h * 0.35),
		center + Vector2(-w * 0.55, -h * 0.55),
		center + Vector2(-w * 0.2, -h * 0.05),
		center + Vector2(0, -h),
		center + Vector2(w * 0.2, -h * 0.05),
		center + Vector2(w * 0.55, -h * 0.55),
		center + Vector2(w * 0.85, h * 0.35),
	])
	var base_mid: Vector2 = (pts[0] + pts[6]) * 0.5
	_draw_wire_shape(center, s, pts, [
		[pts[3], base_mid],
		[pts[2], pts[4]],
	], glow, primary, secondary, shimmer)


# ── Wire Gem Shapes ─────────────────────────────────────────────────────

## Shared renderer for all gem shapes — filled facets with HDR glowing edges.
## Each edge-to-center triangle is shaded based on direction for 3D depth:
## upper-right faces are lit, lower-left faces are in shadow.
func _draw_wire_shape(center: Vector2, s: float, outline: PackedVector2Array,
		facets: Array, glow: Color, primary: Color, secondary: Color, shimmer: float) -> void:
	var hdr: float = _item.hdr_intensity if _item else 2.5

	# Filled facets — triangle from center to each edge, shaded for 3D depth
	for i in range(outline.size()):
		var next_i: int = (i + 1) % outline.size()
		var tri := PackedVector2Array([center, outline[i], outline[next_i]])
		var mid: Vector2 = (outline[i] + outline[next_i]) * 0.5
		var to_mid: Vector2 = mid - center
		# Upper-right = lit, lower-left = shadow
		var shade: float = (to_mid.x * 0.5 - to_mid.y * 0.5) / s
		shade = clampf(shade, -0.25, 0.25)
		var col: Color = primary.lightened(shade) if shade > 0.0 else primary.darkened(-shade)
		draw_colored_polygon(tri, col)

	# HDR edge lines (bloom glow)
	var edge_col := Color(glow.r * hdr, glow.g * hdr, glow.b * hdr, 0.7)
	for i in range(outline.size()):
		draw_line(outline[i], outline[(i + 1) % outline.size()], edge_col, 1.5)

	# Internal facet lines (dim)
	var facet_col := Color(secondary.r * hdr, secondary.g * hdr, secondary.b * hdr, 0.35)
	for f in facets:
		draw_line(f[0] as Vector2, f[1] as Vector2, facet_col, 1.0)

	# Center glow dot
	var core: float = hdr * 1.2
	draw_circle(center, s * 0.06, Color(glow.r * core, glow.g * core, glow.b * core, 0.55))

	# Sparkles
	var max_r: float = 0.0
	for pt in outline:
		max_r = maxf(max_r, center.distance_to(pt))
	_draw_sparkles(center, max_r, glow, shimmer)


func _draw_wire_kite(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.35
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, -h * 0.1),
		center + Vector2(0, h * 0.7),
		center + Vector2(-w, -h * 0.1),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[1], pts[3]],
	], glow, primary, secondary, shimmer)


func _draw_wire_arrow(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.38
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, -h * 0.05),
		center + Vector2(w * 0.35, h * 0.5),
		center + Vector2(-w * 0.35, h * 0.5),
		center + Vector2(-w, -h * 0.05),
	])
	var mid_base: Vector2 = (pts[2] + pts[3]) * 0.5
	_draw_wire_shape(center, s, pts, [
		[pts[0], mid_base],
		[pts[1], pts[4]],
	], glow, primary, secondary, shimmer)


func _draw_wire_prism(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.38
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -h * 0.85),
		center + Vector2(w, h * 0.5),
		center + Vector2(-w, h * 0.5),
	])
	_draw_wire_shape(center, s, pts, [
		[center, pts[0]],
		[center, pts[1]],
		[center, pts[2]],
	], glow, primary, secondary, shimmer)


func _draw_wire_fang(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.35
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(w * 0.1, -h),
		center + Vector2(w * 0.7, -h * 0.15),
		center + Vector2(0, h),
		center + Vector2(-w * 0.5, 0),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[1], pts[3]],
	], glow, primary, secondary, shimmer)


func _draw_wire_sliver(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.2
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w * 0.9, h * 0.85),
		center + Vector2(-w * 0.5, h * 0.55),
	])
	var mid: Vector2 = (pts[1] + pts[2]) * 0.5
	_draw_wire_shape(center, s, pts, [
		[pts[0], mid],
	], glow, primary, secondary, shimmer)


func _draw_wire_trap(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.4
	var h: float = s * 0.4
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.9, -h),
		center + Vector2(w * 0.9, -h),
		center + Vector2(w * 0.4, h),
		center + Vector2(-w * 0.4, h),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[1], pts[3]],
	], glow, primary, secondary, shimmer)


func _draw_wire_marquise(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.38
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w * 0.85, -h * 0.3),
		center + Vector2(w * 0.85, h * 0.3),
		center + Vector2(0, h),
		center + Vector2(-w * 0.85, h * 0.3),
		center + Vector2(-w * 0.85, -h * 0.3),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[3]],
		[pts[1], pts[4]],
		[pts[2], pts[5]],
	], glow, primary, secondary, shimmer)


func _draw_wire_emerald(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.4
	var h: float = s * 0.35
	var clip: float = s * 0.12
	var pts := PackedVector2Array([
		center + Vector2(-w + clip, -h),
		center + Vector2(w - clip, -h),
		center + Vector2(w, -h + clip),
		center + Vector2(w, h - clip),
		center + Vector2(w - clip, h),
		center + Vector2(-w + clip, h),
		center + Vector2(-w, h - clip),
		center + Vector2(-w, -h + clip),
	])
	_draw_wire_shape(center, s, pts, [
		[center + Vector2(0, -h), center + Vector2(0, h)],
		[center + Vector2(-w, 0), center + Vector2(w, 0)],
	], glow, primary, secondary, shimmer)


func _draw_wire_penta(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var r: float = s * 0.42
	var pts := PackedVector2Array()
	for i in range(5):
		var angle: float = -PI / 2.0 + float(i) * TAU / 5.0
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	# Star pattern — connect every other vertex
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[2], pts[4]],
		[pts[4], pts[1]],
		[pts[1], pts[3]],
		[pts[3], pts[0]],
	], glow, primary, secondary, shimmer)


func _draw_wire_wedge(center: Vector2, s: float, primary: Color, secondary: Color, glow: Color, shimmer: float) -> void:
	var w: float = s * 0.35
	var h: float = s * 0.5
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.2, -h),
		center + Vector2(w, h * 0.2),
		center + Vector2(w * 0.2, h),
		center + Vector2(-w * 0.7, h * 0.3),
	])
	_draw_wire_shape(center, s, pts, [
		[pts[0], pts[2]],
		[pts[1], pts[3]],
	], glow, primary, secondary, shimmer)


func _hex_points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var angle: float = -PI / 6.0 + float(i) * TAU / 6.0
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	return pts
