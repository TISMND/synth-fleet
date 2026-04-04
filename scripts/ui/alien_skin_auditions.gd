extends MarginContainer
## Alien skin auditions — cycle through neon/alien render modes on enemy ships.

var _time: float = 0.0
var _ship_renderer: ShipRenderer = null
var _current_hdr: float = 1.0
var _current_white: float = 0.0
var _current_width: float = 1.0
var _skin_index: int = 0
var _skin_label: Label = null
var _ship_label: Label = null
var _ship_index: int = 0
var _vp: SubViewport = null
var _vp_size := Vector2i(1920, 1080)

# Enemy ships available for audition: [display_name, visual_id]
const SHIP_LIST: Array[Array] = [
	["BEHEMOTH", "behemoth"],
	["SENTINEL", "sentinel"],
	["SPORE", "spore"],
	["MITE", "mite"],
	["POLYP", "polyp"],
	["JELLYFISH", "jellyfish"],
	["LAMPREY", "lamprey"],
	["ANEMONE", "anemone"],
	["MANTARAY", "mantaray"],
	["NAUTILUS", "nautilus"],
	["MYCELIA", "mycelia"],
]

# Alien skins — neon-based and special effect modes
const SKIN_MODES: Array[int] = [
	ShipRenderer.RenderMode.DEBUG_MATERIALS,
	ShipRenderer.RenderMode.NEON,
	ShipRenderer.RenderMode.VOID,
	ShipRenderer.RenderMode.HIVEMIND,
	ShipRenderer.RenderMode.SPORE,
	ShipRenderer.RenderMode.EMBER,
	ShipRenderer.RenderMode.FROST,
	ShipRenderer.RenderMode.SOLAR,
	ShipRenderer.RenderMode.SPORT,
]
const SKIN_NAMES: Array[String] = [
	"DEBUG: Red=Hull  Blue=Structure  Green=Trim  Yellow=Canopy  Orange=Engine  Magenta=Unknown",
	"NEON",
	"VOID",
	"HIVEMIND",
	"SPORE",
	"EMBER",
	"FROST",
	"SOLAR",
	"SPORT",
]


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	if _ship_renderer:
		_ship_renderer.time = _time


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_Q or ke.keycode == KEY_COMMA:
			_cycle_skin(-1)
		elif ke.keycode == KEY_E or ke.keycode == KEY_PERIOD:
			_cycle_skin(1)
		elif ke.keycode == KEY_1:
			_cycle_ship(-1)
		elif ke.keycode == KEY_2:
			_cycle_ship(1)


func _cycle_skin(dir: int) -> void:
	_skin_index = (_skin_index + dir + SKIN_MODES.size()) % SKIN_MODES.size()
	if _ship_renderer:
		_ship_renderer.render_mode = SKIN_MODES[_skin_index]
	if _skin_label:
		_skin_label.text = SKIN_NAMES[_skin_index]


func _cycle_ship(dir: int) -> void:
	_ship_index = (_ship_index + dir + SHIP_LIST.size()) % SHIP_LIST.size()
	if _ship_label:
		_ship_label.text = SHIP_LIST[_ship_index][0] as String
	_rebuild_ship()


func _rebuild_ship() -> void:
	if not _vp:
		return
	if _ship_renderer:
		_ship_renderer.queue_free()
	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = -1
	_ship_renderer.enemy_visual_id = SHIP_LIST[_ship_index][1] as String
	_ship_renderer.render_mode = SKIN_MODES[_skin_index]
	_ship_renderer.neon_hdr = _current_hdr
	_ship_renderer.neon_white = _current_white
	_ship_renderer.neon_width = _current_width
	_ship_renderer.position = Vector2(960.0, 540.0)
	_ship_renderer.z_index = 1
	_vp.add_child(_ship_renderer)


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "ALIEN SKINS — Q/E skins, 1/2 ship"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	# Ship selector + Skin selector row
	var selectors_row := HBoxContainer.new()
	selectors_row.add_theme_constant_override("separation", 30)
	main.add_child(selectors_row)

	# Ship selector
	var ship_row := HBoxContainer.new()
	ship_row.add_theme_constant_override("separation", 12)
	selectors_row.add_child(ship_row)

	var ship_label_prefix := Label.new()
	ship_label_prefix.text = "SHIP:"
	ThemeManager.apply_text_glow(ship_label_prefix, "body")
	ship_row.add_child(ship_label_prefix)

	var prev_ship_btn := Button.new()
	prev_ship_btn.text = "< 1"
	prev_ship_btn.pressed.connect(func() -> void: _cycle_ship(-1))
	ThemeManager.apply_button_style(prev_ship_btn)
	ship_row.add_child(prev_ship_btn)

	_ship_label = Label.new()
	_ship_label.text = SHIP_LIST[_ship_index][0] as String
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_label.custom_minimum_size.x = 160
	ThemeManager.apply_text_glow(_ship_label, "header")
	ship_row.add_child(_ship_label)

	var next_ship_btn := Button.new()
	next_ship_btn.text = "2 >"
	next_ship_btn.pressed.connect(func() -> void: _cycle_ship(1))
	ThemeManager.apply_button_style(next_ship_btn)
	ship_row.add_child(next_ship_btn)

	# Skin name + arrows
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 12)
	selectors_row.add_child(nav_row)

	var prev_btn := Button.new()
	prev_btn.text = "< Q"
	prev_btn.pressed.connect(func() -> void: _cycle_skin(-1))
	ThemeManager.apply_button_style(prev_btn)
	nav_row.add_child(prev_btn)

	_skin_label = Label.new()
	_skin_label.text = SKIN_NAMES[_skin_index]
	_skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_label.custom_minimum_size.x = 200
	ThemeManager.apply_text_glow(_skin_label, "header")
	nav_row.add_child(_skin_label)

	var next_btn := Button.new()
	next_btn.text = "E >"
	next_btn.pressed.connect(func() -> void: _cycle_skin(1))
	ThemeManager.apply_button_style(next_btn)
	nav_row.add_child(next_btn)

	# Control sliders row
	var sliders_row := HBoxContainer.new()
	sliders_row.add_theme_constant_override("separation", 24)
	main.add_child(sliders_row)

	_build_slider(sliders_row, "HDR", 0.0, 4.0, 1.0, 0.01, func(v: float) -> void:
		_current_hdr = v
		if _ship_renderer: _ship_renderer.neon_hdr = v
	)
	_build_slider(sliders_row, "WHITE", 0.0, 1.0, 0.0, 0.01, func(v: float) -> void:
		_current_white = v
		if _ship_renderer: _ship_renderer.neon_white = v
	)
	_build_slider(sliders_row, "WIDTH", 0.01, 0.5, 0.2, 0.005, func(v: float) -> void:
		_current_width = v
		if _ship_renderer: _ship_renderer.neon_width = v
	)

	# Viewport
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(vpc)

	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.size = _vp_size
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_vp)
	VFXFactory.add_bloom_to_viewport(_vp)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(bg)

	# Stars
	var stars := _StarBG.new()
	_vp.add_child(stars)

	# Ship
	_rebuild_ship()


func _build_slider(parent: HBoxContainer, label_text: String, min_val: float, max_val: float,
		default_val: float, step_val: float, on_change: Callable) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	ThemeManager.apply_text_glow(lbl, "body")
	box.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_val
	val_lbl.custom_minimum_size.x = 40
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ThemeManager.apply_text_glow(val_lbl, "body")
	box.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = default_val
	slider.custom_minimum_size = Vector2(280, 20)
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		on_change.call(v)
	)
	box.add_child(slider)


class _StarBG extends Node2D:
	var _stars: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in range(60):
			_stars.append({
				"pos": Vector2(rng.randf() * 1920.0, rng.randf() * 1080.0),
				"size": rng.randf_range(0.4, 1.4),
				"bright": rng.randf_range(0.15, 0.5),
				"speed": rng.randf_range(0.3, 1.0),
			})

	func _process(delta: float) -> void:
		for s in _stars:
			(s["pos"] as Vector2).y += float(s["speed"]) * 80.0 * delta
			if (s["pos"] as Vector2).y > 1080.0:
				s["pos"] = Vector2(randf() * 1920.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		for s in _stars:
			var b: float = float(s["bright"])
			draw_circle(s["pos"] as Vector2, float(s["size"]),
				Color(b, b, b * 1.2, 0.7))
