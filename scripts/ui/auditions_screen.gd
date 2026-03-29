extends Control
## Auditions screen — tabbed: Warp Out effects workshop + Events.

const CELL_W: int = 350
const CELL_H: int = 270
const SHIP_ID: int = 4  # Stiletto

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button

# Tab state
var _active_tab: int = 0
var _tab_warp_btn: Button
var _tab_events_btn: Button
var _warp_content: ScrollContainer
var _events_content: ScrollContainer
var _event_trigger_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


# ── Build UI ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS"
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_tab_warp_btn = Button.new()
	_tab_warp_btn.text = "WARP OUT"
	_tab_warp_btn.toggle_mode = true
	_tab_warp_btn.button_pressed = true
	_tab_warp_btn.pressed.connect(func(): _switch_to_tab(0))
	header.add_child(_tab_warp_btn)

	_tab_events_btn = Button.new()
	_tab_events_btn.text = "EVENTS"
	_tab_events_btn.toggle_mode = true
	_tab_events_btn.pressed.connect(func(): _switch_to_tab(1))
	header.add_child(_tab_events_btn)

	_warp_content = ScrollContainer.new()
	_warp_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_warp_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warp_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_warp_content)
	_build_warp_grid()

	_events_content = ScrollContainer.new()
	_events_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_events_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_content.visible = false
	main_vbox.add_child(_events_content)
	_build_events_content()

	_setup_vhs_overlay()


func _switch_to_tab(idx: int) -> void:
	if _active_tab == idx:
		match idx:
			0: _tab_warp_btn.button_pressed = true
			1: _tab_events_btn.button_pressed = true
		return
	_active_tab = idx
	_tab_warp_btn.button_pressed = (idx == 0)
	_tab_events_btn.button_pressed = (idx == 1)
	_warp_content.visible = (idx == 0)
	_events_content.visible = (idx == 1)


# ── Warp Out grid ───────────────────────────────────────────────────

func _build_warp_grid() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warp_content.add_child(flow)

	# All cyan, all ~1.3s. Sendoff fires mid-exit (ship is moving but still visible).
	var C: Color = Color(0.3, 0.7, 1.0)
	var variants: Array = [
		["CLEAN", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "none",
		}],
		["FLASH", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "flash",
		}],
		["SOFT FLASH", {
			"dur": 1.3, "charge": 0.35, "glow_max": 3.5,
			"stretch_y": 3.0, "squeeze_x": 0.35, "exit_accel": 3.5,
			"streak_density": 0.45, "trail_size": 1.5,
			"sendoff": "flash_soft",
		}],
		["RING", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "ring",
		}],
		["DOUBLE RING", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "double_ring",
		}],
		["SHOCKWAVE", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "shockwave",
		}],
		["SCATTER", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "scatter",
		}],
		["EMBERS", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "embers",
		}],
		["RING + SCATTER", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "ring_scatter",
		}],
		["FLASH + RING", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "flash_ring",
		}],
		["SHOCKWAVE + EMBERS", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "shockwave_embers",
		}],
		["THE WORKS", {
			"dur": 1.3, "charge": 0.35, "glow_max": 4.0,
			"stretch_y": 3.5, "squeeze_x": 0.3, "exit_accel": 3.5,
			"streak_density": 0.5, "trail_size": 1.2,
			"sendoff": "the_works",
		}],
	]

	for i in variants.size():
		var def: Array = variants[i]
		var cell := _WarpCell.new()
		cell.setup(i, str(def[0]), C, def[1] as Dictionary)
		flow.add_child(cell)


# ── Events tab ──────────────────────────────────────────────────────

func _build_events_content() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_content.add_child(vbox)

	var desc := Label.new()
	desc.text = "Visual effects (shake, static, lightning, dimming) only render in the game viewport.\nUse LAUNCH to open an empty game level where you can trigger events with number keys."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var launch_btn := Button.new()
	launch_btn.text = "LAUNCH EVENTS SIMULATION"
	launch_btn.pressed.connect(_on_launch_events_sim)
	vbox.add_child(launch_btn)

	vbox.add_child(HSeparator.new())

	var events: Array[GameEventData] = GameEventDataManager.load_all()
	_event_trigger_buttons.clear()
	for event_data in events:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)

		var label := Label.new()
		label.text = event_data.display_name
		label.custom_minimum_size.x = 200
		row.add_child(label)

		var trigger_btn := Button.new()
		trigger_btn.text = "TRIGGER"
		trigger_btn.pressed.connect(_on_trigger_event_preview.bind(event_data.id))
		row.add_child(trigger_btn)
		_event_trigger_buttons[event_data.id] = trigger_btn

	if events.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No game events defined yet. Create them in data/game_events/"
		vbox.add_child(empty_label)


func _on_trigger_event_preview(event_id: String) -> void:
	var event_data: GameEventData = GameEventDataManager.load_by_id(event_id)
	if not event_data:
		return
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 5
	add_child(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)


func _on_launch_events_sim() -> void:
	GameState.return_scene = "res://scenes/ui/auditions_screen.tscn"
	GameState.current_level_id = "level_1"
	GameState.set_meta("events_audition", true)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


# ── Theme ────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _tab_warp_btn:
		ThemeManager.apply_button_style(_tab_warp_btn)
	if _tab_events_btn:
		ThemeManager.apply_button_style(_tab_events_btn)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	for key in _event_trigger_buttons:
		var btn: Button = _event_trigger_buttons[key]
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


# ═══════════════════════════════════════════════════════════════════════
# Light Speed warp cell — sendoff fires AT exit start, not after
# ═══════════════════════════════════════════════════════════════════════

class _WarpCell extends VBoxContainer:
	const SHIP_HOME: Vector2 = Vector2(175.0, 160.0)
	const IDLE_DUR: float = 0.7
	const BLANK_DUR: float = 0.9
	const W: int = 350
	const H: int = 270

	var _idx: int = 0
	var _label_name: String = ""
	var _dur: float = 2.0
	var _color: Color = Color.CYAN
	var _charge: float = 0.4
	var _glow_max: float = 3.5
	var _stretch_y: float = 3.0
	var _squeeze_x: float = 0.35
	var _exit_accel: float = 3.0
	var _streak_density: float = 0.4
	var _trail_size: float = 1.5
	var _sendoff: String = "none"

	var _vp: SubViewport
	var _ship: ShipRenderer
	var _fx: _FXLayer
	var _time: float = 0.0
	var _sendoff_fired: bool = false

	func setup(idx: int, ename: String, col: Color, cfg: Dictionary) -> void:
		_idx = idx
		_label_name = ename
		_color = col
		_dur = float(cfg.get("dur", 2.0))
		_charge = float(cfg.get("charge", 0.4))
		_glow_max = float(cfg.get("glow_max", 3.5))
		_stretch_y = float(cfg.get("stretch_y", 3.0))
		_squeeze_x = float(cfg.get("squeeze_x", 0.35))
		_exit_accel = float(cfg.get("exit_accel", 3.0))
		_streak_density = float(cfg.get("streak_density", 0.4))
		_trail_size = float(cfg.get("trail_size", 1.5))
		_sendoff = str(cfg.get("sendoff", "none"))
		_time = float(idx) * 0.3

	func _ready() -> void:
		_build()

	func _build() -> void:
		add_theme_constant_override("separation", 4)

		var vpc := SubViewportContainer.new()
		vpc.stretch = true
		vpc.custom_minimum_size = Vector2(W, H)
		add_child(vpc)

		_vp = SubViewport.new()
		_vp.transparent_bg = false
		_vp.size = Vector2i(W, H)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vpc.add_child(_vp)

		VFXFactory.add_bloom_to_viewport(_vp)

		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.01, 0.03)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vp.add_child(bg)

		var stars := _StarBG.new()
		stars.init_stars(W, H, 35, _idx + 200)
		_vp.add_child(stars)

		_ship = ShipRenderer.new()
		_ship.ship_id = SHIP_ID
		_ship.render_mode = ShipRenderer.RenderMode.CHROME
		_ship.position = SHIP_HOME
		_ship.z_index = 1
		_vp.add_child(_ship)

		_fx = _FXLayer.new()
		_fx.z_index = 2
		var fx_mat := CanvasItemMaterial.new()
		fx_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_fx.material = fx_mat
		_vp.add_child(_fx)

		var label := Label.new()
		label.text = _label_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		ThemeManager.apply_text_glow(label, "body")
		add_child(label)

	func _process(delta: float) -> void:
		_time += delta
		var cycle: float = IDLE_DUR + _dur + BLANK_DUR
		if _time >= cycle:
			_time = fmod(_time, cycle)
			_reset()

		_fx.shapes.clear()
		_tick_particles(delta)

		if _time >= IDLE_DUR and _time < IDLE_DUR + _dur:
			var p: float = (_time - IDLE_DUR) / maxf(_dur, 0.01)
			_run(p, delta)
		elif _time >= IDLE_DUR + _dur:
			_ship.visible = false

		_fx.queue_redraw()

	func _reset() -> void:
		_ship.visible = true
		_ship.position = SHIP_HOME
		_ship.scale = Vector2.ONE
		_ship.modulate = Color.WHITE
		_sendoff_fired = false
		_fx.particles.clear()
		_fx.shapes.clear()

	func _tick_particles(delta: float) -> void:
		var i: int = _fx.particles.size() - 1
		while i >= 0:
			var pt: Dictionary = _fx.particles[i]
			pt["l"] -= delta
			if pt["l"] <= 0.0:
				_fx.particles.remove_at(i)
			else:
				var pos: Vector2 = pt["p"]
				var vel: Vector2 = pt["v"]
				pt["p"] = pos + vel * delta
				# Apply drag if present
				if pt.has("drag"):
					var d: float = float(pt["drag"])
					pt["v"] = vel * (1.0 - d * delta)
			i -= 1

	func _emit(pos: Vector2, vel: Vector2, life: float, col: Color, sz: float) -> void:
		if _fx.particles.size() < 80:
			_fx.particles.append({"p": pos, "v": vel, "l": life, "ml": life, "c": col, "s": sz})

	func _emit_drag(pos: Vector2, vel: Vector2, life: float, col: Color, sz: float, drag: float) -> void:
		if _fx.particles.size() < 80:
			_fx.particles.append({"p": pos, "v": vel, "l": life, "ml": life, "c": col, "s": sz, "drag": drag})

	func _hdr(mult: float, a: float) -> Color:
		return Color(_color.r * mult, _color.g * mult, _color.b * mult, a)

	# ── Main effect: charge → exit (sendoff at ~40% through exit) → linger ──

	func _run(p: float, dt: float) -> void:
		# Phase 1: Charge
		if p < _charge:
			var t: float = p / _charge
			var ease_t: float = t * t
			_ship.scale = Vector2(
				1.0 - ease_t * (1.0 - _squeeze_x),
				1.0 + ease_t * (_stretch_y - 1.0))
			var glow: float = 1.0 + ease_t * (_glow_max - 1.0)
			_ship.modulate = Color(
				lerpf(1.0, _color.r * glow, ease_t),
				lerpf(1.0, _color.g * glow, ease_t),
				lerpf(1.0, _color.b * glow, ease_t))
			# Ambient streaks
			if randf() < t * _streak_density:
				var x_off: float = randf_range(-35.0, 35.0)
				_emit(Vector2(SHIP_HOME.x + x_off, float(H)),
					Vector2(0.0, -randf_range(180.0, 350.0)),
					0.3, _hdr(1.5, 0.4), _trail_size * 0.7)
			return

		# Phase 2: Exit — ship dashes upward
		var exit_frac: float = 0.55
		var exit_end: float = _charge + (1.0 - _charge) * exit_frac
		var sendoff_trigger: float = 0.4  # fire sendoff at 40% through exit

		if p < exit_end:
			var t: float = (p - _charge) / (exit_end - _charge)
			var ease_t: float = pow(t, _exit_accel)

			_ship.scale = Vector2(
				_squeeze_x * (1.0 - t * 0.5),
				_stretch_y + t * (_stretch_y * 0.5))
			_ship.position.y = SHIP_HOME.y - ease_t * 500.0
			_ship.modulate = Color(
				_color.r * _glow_max,
				_color.g * _glow_max,
				_color.b * _glow_max,
				1.0 - t * 0.8)

			# Trail particles
			if randf() < _streak_density + 0.2:
				_emit(Vector2(_ship.position.x + randf_range(-5.0, 5.0), _ship.position.y + 25.0),
					Vector2(randf_range(-8.0, 8.0), randf_range(60.0, 150.0)),
					0.3, _hdr(2.5, 0.6), _trail_size)
			if randf() < 0.4:
				_emit(Vector2(SHIP_HOME.x + randf_range(-3.0, 3.0), _ship.position.y + 40.0),
					Vector2(0.0, 100.0), 0.2, _hdr(1.8, 0.3), _trail_size * 0.6)

			# Sendoff fires once at 40% through exit (ship moving but still on screen)
			if t >= sendoff_trigger and not _sendoff_fired:
				_sendoff_fired = true
				_fire_sendoff()

			# Sendoff shapes (only draw after sendoff has fired)
			if _sendoff_fired:
				var sendoff_t: float = (t - sendoff_trigger) / (1.0 - sendoff_trigger)
				_draw_sendoff_shapes(sendoff_t)

		else:
			# Phase 3: Linger
			_ship.visible = false
			var t: float = (p - exit_end) / (1.0 - exit_end)
			_draw_sendoff_shapes_fade(t)

	# ── Sendoff: one-time particle burst at exit start ───────────────

	func _fire_sendoff() -> void:
		match _sendoff:
			"flash":
				for i in 6:
					var angle: float = randf() * TAU
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(25.0, 55.0),
						0.4, _hdr(4.0, 0.8), 2.5, 2.0)
			"flash_soft":
				for i in 4:
					var angle: float = randf() * TAU
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(15.0, 35.0),
						0.5, _hdr(2.5, 0.6), 2.0, 2.5)
			"ring", "double_ring":
				pass  # drawn as shapes only
			"shockwave", "shockwave_embers":
				for i in 10:
					var angle: float = randf() * TAU
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(40.0, 100.0),
						0.6, _hdr(2.5, 0.6), 1.8, 1.5)
				if _sendoff == "shockwave_embers":
					for i in 6:
						var angle: float = randf_range(0.5, 2.65)
						_emit(SHIP_HOME + Vector2(randf_range(-10.0, 10.0), 0.0),
							Vector2(cos(angle), sin(angle)) * randf_range(12.0, 30.0),
							randf_range(0.9, 1.5), _hdr(2.0, 0.5), randf_range(2.0, 3.0))
			"scatter":
				for i in 12:
					var angle: float = randf_range(0.8, 2.35)
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(60.0, 160.0),
						0.5, _hdr(3.0, 0.7), randf_range(1.5, 2.5), 1.8)
			"embers":
				for i in 8:
					var angle: float = randf_range(0.5, 2.65)
					_emit(SHIP_HOME + Vector2(randf_range(-12.0, 12.0), 0.0),
						Vector2(cos(angle), sin(angle)) * randf_range(15.0, 40.0),
						randf_range(0.8, 1.4), _hdr(2.5, 0.6), randf_range(1.8, 3.0))
			"ring_scatter":
				for i in 10:
					var angle: float = randf_range(0.6, 2.55)
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(50.0, 130.0),
						0.5, _hdr(3.0, 0.7), 2.0, 1.5)
			"flash_ring":
				for i in 5:
					var angle: float = randf() * TAU
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(20.0, 45.0),
						0.4, _hdr(3.5, 0.7), 2.0, 2.0)
			"the_works":
				# Flash particles
				for i in 5:
					var angle: float = randf() * TAU
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(25.0, 50.0),
						0.4, _hdr(4.0, 0.8), 2.5, 2.0)
				# Scatter cone
				for i in 8:
					var angle: float = randf_range(0.7, 2.45)
					_emit_drag(SHIP_HOME,
						Vector2(cos(angle), sin(angle)) * randf_range(50.0, 120.0),
						0.5, _hdr(2.5, 0.6), 1.8, 1.5)
				# Embers
				for i in 5:
					var angle: float = randf_range(0.5, 2.65)
					_emit(SHIP_HOME + Vector2(randf_range(-10.0, 10.0), 0.0),
						Vector2(cos(angle), sin(angle)) * randf_range(12.0, 30.0),
						randf_range(0.9, 1.5), _hdr(2.0, 0.5), randf_range(2.0, 3.0))

	# ── Sendoff: shapes drawn during exit (concurrent with dash) ─────

	func _draw_sendoff_shapes(t: float) -> void:
		# t goes 0→1 from sendoff trigger to end of exit phase
		match _sendoff:
			"flash":
				if t < 0.5:
					var i: float = (0.5 - t) / 0.5
					_fx.shapes.append([0, SHIP_HOME, 25.0 + t * 60.0, _hdr(4.0, i * 0.25)])
					_fx.shapes.append([0, SHIP_HOME, 10.0 + t * 20.0, Color(1.0, 1.0, 1.0, i * 0.15)])
			"flash_soft":
				if t < 0.6:
					var i: float = (0.6 - t) / 0.6
					_fx.shapes.append([0, SHIP_HOME, 20.0 + t * 40.0, _hdr(2.5, i * 0.2)])
			"ring":
				var radius: float = t * 90.0
				var alpha: float = (1.0 - t) * 0.7
				if alpha > 0.01:
					_fx.shapes.append([1, SHIP_HOME, radius, 0.0, TAU, 48, _hdr(3.0, alpha), 2.5])
			"double_ring":
				var r1: float = t * 90.0
				var r2: float = maxf(t - 0.15, 0.0) / 0.85 * 70.0
				var a1: float = (1.0 - t) * 0.7
				var a2: float = (1.0 - minf(t + 0.15, 1.0)) * 0.5
				if a1 > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r1, 0.0, TAU, 48, _hdr(3.0, a1), 2.5])
				if r2 > 1.0 and a2 > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r2, 0.0, TAU, 36, _hdr(2.0, a2), 1.5])
			"shockwave", "shockwave_embers":
				var radius: float = t * 120.0
				var alpha: float = (1.0 - t) * 0.6
				_fx.shapes.append([1, SHIP_HOME, radius, 0.0, TAU, 64, _hdr(3.0, alpha), 3.5])
				_fx.shapes.append([1, SHIP_HOME, radius * 0.8, 0.0, TAU, 48, _hdr(2.0, alpha * 0.3), 1.5])
				if t < 0.2:
					_fx.shapes.append([0, SHIP_HOME, 25.0 + t * 40.0,
						Color(1.0, 1.0, 1.0, (0.2 - t) / 0.2 * 0.15)])
			"ring_scatter":
				var radius: float = t * 80.0
				var alpha: float = (1.0 - t) * 0.6
				if alpha > 0.01:
					_fx.shapes.append([1, SHIP_HOME, radius, 0.0, TAU, 48, _hdr(2.5, alpha), 2.0])
			"flash_ring":
				# Flash
				if t < 0.5:
					var i: float = (0.5 - t) / 0.5
					_fx.shapes.append([0, SHIP_HOME, 20.0 + t * 50.0, _hdr(3.5, i * 0.2)])
				# Ring
				var radius: float = t * 85.0
				var alpha: float = (1.0 - t) * 0.6
				if alpha > 0.01:
					_fx.shapes.append([1, SHIP_HOME, radius, 0.0, TAU, 48, _hdr(2.5, alpha), 2.0])
			"the_works":
				# Flash
				if t < 0.4:
					var i: float = (0.4 - t) / 0.4
					_fx.shapes.append([0, SHIP_HOME, 25.0 + t * 55.0, _hdr(4.0, i * 0.2)])
				# Double ring
				var r1: float = t * 100.0
				var r2: float = maxf(t - 0.12, 0.0) / 0.88 * 75.0
				var a1: float = (1.0 - t) * 0.6
				var a2: float = (1.0 - minf(t + 0.12, 1.0)) * 0.4
				if a1 > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r1, 0.0, TAU, 48, _hdr(3.0, a1), 2.5])
				if r2 > 1.0 and a2 > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r2, 0.0, TAU, 36, _hdr(2.0, a2), 1.5])
			_:
				pass

	# ── Sendoff: lingering shapes after ship is gone ─────────────────

	func _draw_sendoff_shapes_fade(t: float) -> void:
		# t goes 0→1 during linger phase (ship already gone)
		match _sendoff:
			"ring":
				var r: float = 90.0 + t * 30.0
				var a: float = (1.0 - t) * 0.3
				if a > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r, 0.0, TAU, 48, _hdr(2.0, a), 2.0])
			"double_ring":
				var r1: float = 90.0 + t * 25.0
				var r2: float = 70.0 + t * 20.0
				var a: float = (1.0 - t) * 0.25
				if a > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r1, 0.0, TAU, 48, _hdr(2.0, a), 2.0])
					_fx.shapes.append([1, SHIP_HOME, r2, 0.0, TAU, 36, _hdr(1.5, a * 0.6), 1.5])
			"shockwave", "shockwave_embers":
				var r: float = 120.0 + t * 40.0
				var a: float = (1.0 - t) * 0.2
				if a > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r, 0.0, TAU, 64, _hdr(2.0, a), 2.5])
			"ring_scatter":
				var r: float = 80.0 + t * 25.0
				var a: float = (1.0 - t) * 0.2
				if a > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r, 0.0, TAU, 48, _hdr(1.5, a), 1.5])
			"flash_ring":
				var r: float = 85.0 + t * 25.0
				var a: float = (1.0 - t) * 0.25
				if a > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r, 0.0, TAU, 48, _hdr(2.0, a), 2.0])
			"the_works":
				var r1: float = 100.0 + t * 30.0
				var r2: float = 75.0 + t * 20.0
				var a: float = (1.0 - t) * 0.2
				if a > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r1, 0.0, TAU, 48, _hdr(2.0, a), 2.0])
					_fx.shapes.append([1, SHIP_HOME, r2, 0.0, TAU, 36, _hdr(1.5, a * 0.5), 1.5])
			_:
				pass


# ═══════════════════════════════════════════════════════════════════════
# FX drawing layer
# ═══════════════════════════════════════════════════════════════════════

class _FXLayer extends Node2D:
	var shapes: Array = []
	var particles: Array = []

	func _draw() -> void:
		for s in shapes:
			var cmd: int = int(s[0])
			if cmd == 0:
				draw_circle(s[1] as Vector2, s[2] as float, s[3] as Color)
			elif cmd == 1:
				draw_arc(s[1] as Vector2, s[2] as float, s[3] as float,
					s[4] as float, s[5] as int, s[6] as Color, s[7] as float)
			elif cmd == 2:
				draw_line(s[1] as Vector2, s[2] as Vector2, s[3] as Color, s[4] as float)
			elif cmd == 3:
				draw_rect(s[1] as Rect2, s[2] as Color)

		for pt in particles:
			var t: float = float(pt["l"]) / maxf(float(pt["ml"]), 0.001)
			var base_a: float = float(pt["c"].a)
			var a: float = t * base_a
			if a < 0.01:
				continue
			var c: Color = pt["c"] as Color
			var pos: Vector2 = pt["p"] as Vector2
			var sz: float = float(pt["s"])
			draw_circle(pos, sz * 2.5, Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, a * 0.15))
			draw_circle(pos, sz, Color(c.r, c.g, c.b, a))


# ═══════════════════════════════════════════════════════════════════════
# Static star background
# ═══════════════════════════════════════════════════════════════════════

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
			})

	func _draw() -> void:
		for s in _stars:
			var b: float = float(s["bright"])
			draw_circle(s["pos"] as Vector2, float(s["size"]),
				Color(b, b, b * 1.2, 0.7))
