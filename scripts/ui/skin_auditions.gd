extends MarginContainer
## Skin auditions — cycle through render modes on a controllable Stiletto.

var _time: float = 0.0
var _ship_pos := Vector2(960.0, 540.0)
var _ship_vel := Vector2.ZERO
var _bank: float = 0.0
var _ship_renderer: ShipRenderer = null
var _exhaust: EngineExhaust = null
var _skin_index: int = 0
var _skin_label: Label = null
var _vp_size := Vector2i(1920, 1080)

const SHIP_SPEED: float = 400.0
const SHIP_ACCEL: float = 1200.0
const SHIP_DECEL: float = 800.0

# Skins to audition — order matters for cycling
const SKIN_MODES: Array[int] = [
	ShipRenderer.RenderMode.DEBUG_MATERIALS,
	ShipRenderer.RenderMode.CHROME,
	ShipRenderer.RenderMode.STEALTH,
	ShipRenderer.RenderMode.MILITIA,
	ShipRenderer.RenderMode.GUNMETAL,
	ShipRenderer.RenderMode.CAUTION,
]
const SKIN_NAMES: Array[String] = [
	"DEBUG: Red=Hull  Blue=Accent  Green=Detail  Yellow=Canopy  Orange=Engine  Magenta=Unknown",
	"CHROME",
	"STEALTH",
	"MILITIA",
	"GUNMETAL",
	"CAUTION",
]


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

	if _ship_renderer:
		_ship_renderer.position = _ship_pos
		_ship_renderer.bank = _bank
	if _exhaust:
		_exhaust.position = _ship_pos
		_exhaust.update_thrust(_ship_vel.y, _bank, delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_Q or ke.keycode == KEY_COMMA:
			_cycle_skin(-1)
		elif ke.keycode == KEY_E or ke.keycode == KEY_PERIOD:
			_cycle_skin(1)


func _cycle_skin(dir: int) -> void:
	_skin_index = (_skin_index + dir + SKIN_MODES.size()) % SKIN_MODES.size()
	if _ship_renderer:
		_ship_renderer.render_mode = SKIN_MODES[_skin_index]
	if _skin_label:
		_skin_label.text = SKIN_NAMES[_skin_index]


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "SKINS — WASD to move, Q/E to cycle skins"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	# Skin name + arrows
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 12)
	main.add_child(nav_row)

	var prev_btn := Button.new()
	prev_btn.text = "< Q"
	prev_btn.pressed.connect(func(): _cycle_skin(-1))
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
	next_btn.pressed.connect(func(): _cycle_skin(1))
	ThemeManager.apply_button_style(next_btn)
	nav_row.add_child(next_btn)

	# Viewport
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
	vp.add_child(stars)

	# Engine exhaust
	_exhaust = EngineExhaust.new()
	var offsets: Array[Vector2] = ShipRenderer.get_engine_offsets(4)
	var sc: float = ShipRenderer.get_ship_scale(4)
	_exhaust.setup(offsets, sc)
	_exhaust.scroll_speed = 80.0
	vp.add_child(_exhaust)

	# Ship
	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = 4  # Stiletto
	_ship_renderer.render_mode = SKIN_MODES[_skin_index]
	_ship_renderer.z_index = 1
	vp.add_child(_ship_renderer)


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
