extends MarginContainer
## Engine effect auditions — plasma jet thruster with fine-tuning controls.
## Ship always moves forward through space. Moving down = slowing, engines dim but never off.

var _time: float = 0.0
var _ship_pos := Vector2(960.0, 600.0)
var _ship_vel := Vector2.ZERO
var _bank: float = 0.0
var _display_intensity: float = 0.15  # Smoothed thrust display (lerps toward target)
var _drawers: Array[Node2D] = []
var _vp_size := Vector2i(1920, 1080)

const SCROLL_SPEED: float = 80.0
const SHIP_SPEED: float = 400.0
const SHIP_ACCEL: float = 1200.0
const SHIP_DECEL: float = 800.0

const ENGINE_OFFSETS: Array[Vector2] = [Vector2(-6.0, 20.0), Vector2(6.0, 20.0)]
const SHIP_SCALE: float = 1.4

# Tunable parameters (persisted to user://settings/engine_audition.json)
var cone_hdr: float = 1.8
var length_min: float = 0.3   # Cone length when going backward/idle
var length_max: float = 1.0   # Cone length at full forward thrust
var cone_width: float = 1.0
var flicker_intensity: float = 0.5
var nozzle_hdr: float = 2.5
var splay_amount: float = 0.0
var layer_count: int = 4
var crawl_count: int = 5

const SAVE_PATH: String = "user://settings/engine_audition.json"


func _ready() -> void:
	_load_settings()
	_build_ui()
	ThemeManager.theme_changed.connect(func(): pass)


func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed as Dictionary
		cone_hdr = float(d.get("cone_hdr", cone_hdr))
		length_min = float(d.get("length_min", length_min))
		length_max = float(d.get("length_max", length_max))
		cone_width = float(d.get("cone_width", cone_width))
		flicker_intensity = float(d.get("flicker_intensity", flicker_intensity))
		nozzle_hdr = float(d.get("nozzle_hdr", nozzle_hdr))
		splay_amount = float(d.get("splay_amount", splay_amount))
		layer_count = int(d.get("layer_count", layer_count))
		crawl_count = int(d.get("crawl_count", crawl_count))


func _save_settings() -> void:
	var dir_path: String = SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"cone_hdr": cone_hdr,
			"length_min": length_min,
			"length_max": length_max,
			"cone_width": cone_width,
			"flicker_intensity": flicker_intensity,
			"nozzle_hdr": nozzle_hdr,
			"splay_amount": splay_amount,
			"layer_count": layer_count,
			"crawl_count": crawl_count,
		}, "\t"))
		file.close()


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
	_ship_pos.x = clampf(_ship_pos.x, 40.0, float(_vp_size.x) - 40.0)
	_ship_pos.y = clampf(_ship_pos.y, 40.0, float(_vp_size.y) - 40.0)

	var target_bank: float = clampf(-_ship_vel.x / maxf(SHIP_SPEED, 1.0), -1.0, 1.0)
	_bank = lerpf(_bank, target_bank, minf(delta * 8.0, 1.0))

	# Asymmetric thrust ramp — slow buildup (~2s), faster reduction (2x)
	var target_intensity: float = get_raw_thrust_intensity()
	var ramp_speed: float
	if target_intensity > _display_intensity:
		ramp_speed = 0.8  # Growing — slow swell
	else:
		ramp_speed = 1.6  # Shrinking — twice as fast
	_display_intensity = lerpf(_display_intensity, target_intensity, minf(delta * ramp_speed, 1.0))

	for d in _drawers:
		if is_instance_valid(d):
			d.queue_redraw()


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "PLASMA JET — Move with WASD/Arrows"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	# Row 1 sliders
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 14)
	main.add_child(row1)
	_add_slider(row1, "Cone HDR", 0.5, 4.0, cone_hdr, func(v: float): cone_hdr = v; _save_settings())
	_add_slider(row1, "Min Length", 0.0, 2.0, length_min, func(v: float): length_min = v; _save_settings())
	_add_slider(row1, "Max Length", 0.3, 3.0, length_max, func(v: float): length_max = v; _save_settings())
	_add_slider(row1, "Width", 0.3, 3.0, cone_width, func(v: float): cone_width = v; _save_settings())
	_add_slider(row1, "Flicker", 0.0, 1.0, flicker_intensity, func(v: float): flicker_intensity = v; _save_settings())

	# Row 2 sliders
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	main.add_child(row2)
	_add_slider(row2, "Nozzle HDR", 0.5, 5.0, nozzle_hdr, func(v: float): nozzle_hdr = v; _save_settings())
	_add_slider(row2, "Splay", -3.0, 3.0, splay_amount, func(v: float): splay_amount = v; _save_settings())
	_add_slider(row2, "Layers", 2.0, 8.0, float(layer_count), func(v: float): layer_count = int(v); _save_settings())
	_add_slider(row2, "Crawl Dots", 0.0, 12.0, float(crawl_count), func(v: float): crawl_count = int(v); _save_settings())

	# Single large viewport
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

	var stars := _StarField.new()
	stars.screen = self
	vp.add_child(stars)

	var engine_draw := _EngineDrawer.new()
	engine_draw.screen = self
	engine_draw.z_index = 0
	vp.add_child(engine_draw)
	_drawers.append(engine_draw)

	var ship := ShipRenderer.new()
	ship.ship_id = 4
	ship.render_mode = ShipRenderer.RenderMode.CHROME
	ship.z_index = 1
	vp.add_child(ship)

	var updater := _ShipUpdater.new()
	updater.screen = self
	updater.ship_renderer = ship
	vp.add_child(updater)


func _add_slider(parent: HBoxContainer, label_text: String, min_val: float, max_val: float, initial: float, callback: Callable) -> void:
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.05 if max_val <= 5.0 else 1.0
	slider.value = initial
	slider.custom_minimum_size.x = 80
	parent.add_child(slider)

	var val_label := Label.new()
	val_label.text = str(snapped(initial, 0.05))
	val_label.add_theme_font_size_override("font_size", 11)
	val_label.custom_minimum_size.x = 30
	parent.add_child(val_label)

	slider.value_changed.connect(func(v: float):
		callback.call(v)
		val_label.text = str(snapped(v, 0.05))
	)


func get_raw_thrust_intensity() -> float:
	var forward_vel: float = SCROLL_SPEED - _ship_vel.y
	var intensity: float = forward_vel / SCROLL_SPEED
	return clampf(intensity, 0.15, 2.0)


func get_thrust_intensity() -> float:
	return _display_intensity


func get_engine_world_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	# Banking parallax: engines shift opposite to movement direction
	# When ship banks left (_bank > 0), engines slide slightly right
	var parallax_x: float = _bank * 3.0 * SHIP_SCALE
	for offset in ENGINE_OFFSETS:
		var s: float = SHIP_SCALE
		var bx: float = offset.x * (1.0 + _bank * signf(offset.x) * 0.15) * s
		positions.append(_ship_pos + Vector2(bx + parallax_x, offset.y * s))
	return positions


## Irregular flicker — layered sine waves at irrational frequencies, SYNCED across engines.
## seed_offset varies per-parameter (not per-engine) so both jets pulse together.
func _synced_flicker(t: float, param_seed: float, amount: float) -> float:
	var f1: float = sin(t * 7.3 + param_seed)
	var f2: float = sin(t * 13.1 + param_seed * 2.7)
	var f3: float = sin(t * 23.7 + param_seed * 0.3)
	var raw: float = (f1 * 0.5 + f2 * 0.3 + f3 * 0.2)
	return 1.0 - absf(raw) * amount


class _ShipUpdater extends Node2D:
	var screen: Control
	var ship_renderer: ShipRenderer

	func _process(_delta: float) -> void:
		if screen and ship_renderer:
			ship_renderer.position = screen._ship_pos
			ship_renderer.bank = screen._bank


class _StarField extends Node2D:
	var screen: Control
	var _stars: Array[Dictionary] = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in range(80):
			_stars.append({
				"x": rng.randf() * 1920.0,
				"y": rng.randf() * 1080.0,
				"speed": rng.randf_range(0.3, 1.0),
				"size": rng.randf_range(0.5, 1.5),
				"bright": rng.randf_range(0.1, 0.4),
			})

	func _process(delta: float) -> void:
		if not screen:
			return
		for star in _stars:
			star["y"] += float(star["speed"]) * screen.SCROLL_SPEED * delta
			if float(star["y"]) > 1080.0:
				star["y"] = 0.0
				star["x"] = randf() * 1920.0
		queue_redraw()

	func _draw() -> void:
		for star in _stars:
			var b: float = float(star["bright"])
			draw_circle(Vector2(float(star["x"]), float(star["y"])), float(star["size"]),
				Color(b, b, b * 1.2, 0.6))


class _EngineDrawer extends Node2D:
	var screen: Control

	func _draw() -> void:
		if not screen:
			return
		var positions: Array[Vector2] = screen.get_engine_world_positions()
		var intensity: float = screen.get_thrust_intensity()
		var t: float = screen._time
		var hdr: float = screen.cone_hdr
		# Interpolate length between min and max based on thrust intensity
		var norm_intensity: float = clampf((intensity - 0.15) / (2.0 - 0.15), 0.0, 1.0)
		var len_m: float = lerpf(screen.length_min, screen.length_max, norm_intensity)
		var wid_m: float = screen.cone_width
		var splay: float = screen.splay_amount
		var layers: int = screen.layer_count
		var crawls: int = screen.crawl_count
		var flick_amt: float = screen.flicker_intensity
		var n_hdr_base: float = screen.nozzle_hdr

		# Synced flicker values (same for all engines)
		var flicker: float = screen._synced_flicker(t, 1.0, flick_amt)
		var size_pulse: float = screen._synced_flicker(t * 0.8, 3.5, 0.35)
		var nozzle_flare: float = screen._synced_flicker(t, 13.0, 0.7)

		for ei in range(positions.size()):
			var pos: Vector2 = positions[ei]
			# Mirror splay: left engine splays left, right engine splays right
			var side: float = signf(pos.x - screen._ship_pos.x) if absf(pos.x - screen._ship_pos.x) > 0.5 else 0.0
			var splay_offset: float = side * splay

			var cone_len: float = (10.0 + intensity * 18.0) * len_m * size_pulse
			var base_w: float = (2.8 + intensity * 1.8) * wid_m

			# Layered cones
			for li in range(layers):
				var frac: float = float(li) / float(maxi(layers - 1, 1))
				var w: float = base_w * (1.0 - frac * 0.6)
				var length: float = cone_len * (1.2 - frac * 0.5)
				var alpha: float = lerpf(0.08, 0.5, frac) * intensity * flicker
				var r: float = lerpf(0.2, 0.8, frac) * hdr
				var g: float = lerpf(0.4, 0.9, frac) * hdr
				var b: float = lerpf(0.8, 1.0, frac) * hdr

				# Per-layer wobble (synced but offset by layer)
				var wobble_x: float = (screen._synced_flicker(t * 1.3, float(li) * 2.0, 0.15) - 0.5) * 0.5

				# Splay shifts the tip outward per engine side
				var tip_x: float = wobble_x + splay_offset * frac
				var pts := PackedVector2Array([
					pos + Vector2(-w, 0),
					pos + Vector2(w, 0),
					pos + Vector2(tip_x, length),
				])
				draw_colored_polygon(pts, Color(r, g, b, alpha))

			# Energy crawl dots
			for ci in range(crawls):
				var crawl_phase: float = fmod(t * 3.0 + float(ci) * (1.0 / maxf(float(crawls), 1.0)), 1.0)
				var crawl_y: float = crawl_phase * cone_len * 0.8
				# Crawl dots follow the splay direction
				var crawl_splay: float = splay_offset * crawl_phase
				var crawl_wobble: float = (screen._synced_flicker(t, float(ci) * 4.0, 0.3) - 0.5) * base_w * 0.3
				var crawl_alpha: float = (1.0 - crawl_phase) * intensity * 0.5 * flicker
				if crawl_alpha > 0.02:
					draw_circle(pos + Vector2(crawl_splay + crawl_wobble, crawl_y), 1.0,
						Color(0.8 * hdr, 0.9 * hdr, 1.0 * hdr, crawl_alpha))

			# Nozzle — HDR flicker
			var n_hdr: float = n_hdr_base * nozzle_flare
			draw_circle(pos, 3.5, Color(0.4 * n_hdr, 0.6 * n_hdr, 1.0 * n_hdr, intensity * 0.4))
			draw_circle(pos, 2.0, Color(0.6 * n_hdr, 0.8 * n_hdr, 1.0 * n_hdr, intensity * 0.9))
			draw_circle(pos, 0.8, Color(n_hdr, n_hdr, n_hdr, intensity * 0.7))
