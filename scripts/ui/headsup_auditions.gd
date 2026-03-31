extends MarginContainer
## Headsup indicator auditions — underlined text with a solid tracking line to a moving target.

var _time: float = 0.0
var _drawers: Array[Node2D] = []
var _hdr_values: Array[float] = [1.8, 1.6, 1.8]  # Per-style HDR

# Two targets moving independently for variety
var _target_a := Vector2(350.0, 80.0)
var _target_b := Vector2(300.0, 70.0)
var _vel_a := Vector2(25.0, 15.0)
var _vel_b := Vector2(-20.0, 18.0)


func _ready() -> void:
	_build_ui()
	ThemeManager.theme_changed.connect(func(): pass)


func _process(delta: float) -> void:
	_time += delta
	# Bounce targets around the viewport area
	_target_a += _vel_a * delta
	_target_b += _vel_b * delta
	_bounce(_target_a, _vel_a, 280.0, 450.0, 50.0, 120.0)
	_bounce(_target_b, _vel_b, 250.0, 420.0, 45.0, 110.0)
	for drawer in _drawers:
		if is_instance_valid(drawer):
			drawer.queue_redraw()


func _bounce(pos: Vector2, vel: Vector2, x_min: float, x_max: float, y_min: float, y_max: float) -> void:
	if pos.x < x_min:
		vel.x = absf(vel.x)
	elif pos.x > x_max:
		vel.x = -absf(vel.x)
	if pos.y < y_min:
		vel.y = absf(vel.y)
	elif pos.y > y_max:
		vel.y = -absf(vel.y)


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	add_child(main)

	var header := Label.new()
	header.text = "ITEM HEADSUP INDICATORS"
	header.name = "HeadsupHeader"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	var grid := VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 16)
	scroll.add_child(grid)

	# HDR slider
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 8)
	grid.add_child(hdr_row)

	var hdr_label := Label.new()
	hdr_label.text = "HDR:"
	ThemeManager.apply_text_glow(hdr_label, "body")
	hdr_row.add_child(hdr_label)

	var hdr_val_label := Label.new()
	hdr_val_label.name = "HdrVal"
	hdr_row.add_child(hdr_val_label)

	var hdr_slider := HSlider.new()
	hdr_slider.min_value = 0.5
	hdr_slider.max_value = 4.0
	hdr_slider.step = 0.1
	hdr_slider.value = 1.8
	hdr_slider.custom_minimum_size.x = 200
	hdr_slider.value_changed.connect(func(v: float) -> void:
		for i in range(_hdr_values.size()):
			_hdr_values[i] = v
		hdr_val_label.text = str(snapped(v, 0.1))
	)
	hdr_row.add_child(hdr_slider)
	hdr_val_label.text = str(snapped(hdr_slider.value, 0.1))

	# Style variations: color, font, text position
	_add_style(grid, "GREEN HDR (Cargo style)", 0)
	_add_style(grid, "AMBER HDR (Bank style)", 1)
	_add_style(grid, "COOL CYAN", 2)


func _add_style(parent: VBoxContainer, title: String, style_id: int) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 12)
	ThemeManager.apply_text_glow(label, "body")
	parent.add_child(label)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(600, 200)
	vpc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(600, 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var drawer := _HeadsupDrawer.new()
	drawer.screen = self
	drawer.style = style_id
	vp.add_child(drawer)
	_drawers.append(drawer)


class _HeadsupDrawer extends Node2D:
	var screen: Control
	var style: int = 0

	func _draw() -> void:
		if not screen:
			return
		var target: Vector2 = screen._target_a if (style != 1) else screen._target_b
		var t: float = screen._time

		# Target placeholder (small ship-like marker)
		draw_circle(target, 6.0, Color(0.3, 0.5, 0.4, 0.4))
		draw_arc(target, 9.0, 0.0, TAU, 16, Color(0.4, 0.8, 0.5, 0.5), 1.5)

		# Style parameters — HDR from slider
		var hdr: float = screen._hdr_values[style] if style < screen._hdr_values.size() else 1.8
		var col: Color
		var font_key: String
		var font_size: int
		var text_pos: Vector2
		var text: String = "CARGO TRANSFER"

		match style:
			0:  # Green HDR — matches cargo counter
				col = Color(0.15 * hdr, 0.9 * hdr, 0.4 * hdr)
				font_key = "font_header"
				font_size = 14
				text_pos = Vector2(20.0, 185.0)
			1:  # Amber HDR — matches bank counter
				col = Color(0.9 * hdr, 0.6 * hdr, 0.15 * hdr)
				font_key = "font_header"
				font_size = 14
				text_pos = Vector2(20.0, 185.0)
			2:  # Cool cyan
				col = Color(0.3 * hdr, 0.7 * hdr, 1.0 * hdr)
				font_key = "font_body"
				font_size = 16
				text_pos = Vector2(20.0, 183.0)
			_:
				col = Color(0.15 * hdr, 0.9 * hdr, 0.4 * hdr)
				font_key = "font_header"
				font_size = 14
				text_pos = Vector2(20.0, 185.0)

		var font: Font = ThemeManager.get_font(font_key)
		if not font:
			return

		# Measure text width for underline
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		# Blinking text
		var blink: float = 0.6 + 0.4 * sin(t * 4.0)
		var text_col := Color(col.r, col.g, col.b, blink)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

		# Underline — extends the full text width
		var underline_y: float = text_pos.y + 4.0
		var underline_start := Vector2(text_pos.x, underline_y)
		var underline_end := Vector2(text_pos.x + text_width, underline_y)
		draw_line(underline_start, underline_end, Color(col.r, col.g, col.b, 0.7), 1.5)

		# Tracking line — continues directly from end of underline to target
		var line_end: Vector2 = target
		var dir: Vector2 = (line_end - underline_end).normalized()
		var arrow_stop: Vector2 = line_end - dir * 14.0
		draw_line(underline_end, arrow_stop, Color(col.r, col.g, col.b, 0.5), 1.5)

		# Arrowhead at target
		var perp := Vector2(-dir.y, dir.x)
		var tip: Vector2 = line_end - dir * 8.0
		var head_pts := PackedVector2Array([
			tip,
			tip - dir * 8.0 + perp * 4.0,
			tip - dir * 8.0 - perp * 4.0,
		])
		draw_colored_polygon(head_pts, Color(col.r, col.g, col.b, 0.7))
