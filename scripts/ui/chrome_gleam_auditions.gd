extends MarginContainer
## Chrome gleam HDR auditions — compare the specular highlight at different HDR levels.
## Shows a controllable ship with adjustable gleam brightness to test bloom bleed.

var _time: float = 0.0
var _ship_pos := Vector2(960.0, 540.0)
var _ship_vel := Vector2.ZERO
var _bank: float = 0.0
var _drawers: Array[Node2D] = []
var _renderers: Array[ShipRenderer] = []
var _vp_size := Vector2i(1920, 1080)

const SHIP_SPEED: float = 400.0
const SHIP_ACCEL: float = 1200.0
const SHIP_DECEL: float = 800.0

# Tunable
var gleam_hdr: float = 1.0  # 1.0 = current (no bloom), >1.0 = HDR bloom
var edge_hdr: float = 1.0


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		_ship_vel = _ship_vel.move_toward(input_dir * SHIP_SPEED, SHIP_ACCEL * delta)
	else:
		_ship_vel = _ship_vel.move_toward(Vector2.ZERO, SHIP_DECEL * delta)

	_ship_pos += _ship_vel * delta
	_ship_pos.x = clampf(_ship_pos.x, 80.0, float(_vp_size.x) - 80.0)
	_ship_pos.y = clampf(_ship_pos.y, 80.0, float(_vp_size.y) - 80.0)

	var target_bank: float = clampf(-_ship_vel.x / maxf(SHIP_SPEED, 1.0), -1.0, 1.0)
	_bank = lerpf(_bank, target_bank, minf(delta * 8.0, 1.0))

	for r in _renderers:
		if is_instance_valid(r):
			r.position = _ship_pos
			r.bank = _bank
			r.chrome_gleam_hdr = gleam_hdr
			r.chrome_edge_hdr = edge_hdr


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "CHROME GLEAM — Move with WASD/Arrows"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 16)
	main.add_child(slider_row)
	_add_slider(slider_row, "Gleam HDR", 0.5, 4.0, gleam_hdr, func(v: float): gleam_hdr = v)
	_add_slider(slider_row, "Edge HDR", 0.5, 4.0, edge_hdr, func(v: float): edge_hdr = v)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = _vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	# Stars
	var stars := _StarBG.new()
	stars.init_stars(_vp_size.x, _vp_size.y, 60, 99)
	vp.add_child(stars)

	# Engine exhaust behind ship
	var exhaust := EngineExhaust.new()
	var offsets: Array[Vector2] = ShipRenderer.get_engine_offsets(4)
	var sc: float = ShipRenderer.get_ship_scale(4)
	exhaust.setup(offsets, sc)
	exhaust.scroll_speed = 80.0
	vp.add_child(exhaust)
	_drawers.append(exhaust)

	# Ship
	var ship := ShipRenderer.new()
	ship.ship_id = 4
	ship.render_mode = ShipRenderer.RenderMode.CHROME
	ship.z_index = 1
	vp.add_child(ship)
	_renderers.append(ship)

	# Exhaust updater
	var updater := _ExhaustUpdater.new()
	updater.screen = self
	updater.exhaust = exhaust
	vp.add_child(updater)


func _add_slider(parent: HBoxContainer, label_text: String, min_val: float, max_val: float, initial: float, callback: Callable) -> void:
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size.x = 120
	parent.add_child(slider)

	var val_label := Label.new()
	val_label.text = str(snapped(initial, 0.05))
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.custom_minimum_size.x = 35
	parent.add_child(val_label)

	slider.value_changed.connect(func(v: float):
		callback.call(v)
		val_label.text = str(snapped(v, 0.05))
	)


class _ExhaustUpdater extends Node2D:
	var screen: Control
	var exhaust: EngineExhaust

	func _process(delta: float) -> void:
		if screen and exhaust:
			exhaust.position = screen._ship_pos
			exhaust.update_thrust(screen._ship_vel.y, screen._bank, delta)


class _StarBG extends Node2D:
	var _stars: Array = []

	func init_stars(w: int, h: int, count: int, seed_val: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		for i in count:
			_stars.append({
				"pos": Vector2(rng.randf() * float(w), rng.randf() * float(h)),
				"size": rng.randf_range(0.4, 1.4),
				"bright": rng.randf_range(0.15, 0.5),
				"speed": rng.randf_range(0.3, 1.0),
			})

	func _process(delta: float) -> void:
		for s in _stars:
			s["pos"].y += float(s["speed"]) * 80.0 * delta
			if s["pos"].y > 1080.0:
				s["pos"].y = 0.0
				s["pos"].x = randf() * 1920.0
		queue_redraw()

	func _draw() -> void:
		for s in _stars:
			var b: float = float(s["bright"])
			draw_circle(s["pos"] as Vector2, float(s["size"]),
				Color(b, b, b * 1.2, 0.7))
