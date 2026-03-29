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

	# Light Speed variations: [name, cfg dictionary]
	# cfg keys: color, charge_time (0-1 of dur), streak_density, glow_max,
	#           exit_speed, stretch_y, squeeze_x, trail_fade, aftereffect
	var variants: Array = [
		["CLASSIC CYAN", {
			"color": Color(0.3, 0.7, 1.0), "dur": 2.2,
			"charge": 0.45, "glow_max": 3.5, "stretch_y": 3.0, "squeeze_x": 0.35,
			"exit_accel": 3.0, "streak_density": 0.4, "trail_size": 1.5,
			"aftereffect": "none",
		}],
		["HOT WHITE", {
			"color": Color(1.0, 1.0, 1.0), "dur": 1.6,
			"charge": 0.3, "glow_max": 5.0, "stretch_y": 4.0, "squeeze_x": 0.2,
			"exit_accel": 4.0, "streak_density": 0.6, "trail_size": 1.0,
			"aftereffect": "flash",
		}],
		["NEON MAGENTA", {
			"color": Color(1.0, 0.15, 0.7), "dur": 2.4,
			"charge": 0.5, "glow_max": 4.0, "stretch_y": 2.5, "squeeze_x": 0.4,
			"exit_accel": 2.5, "streak_density": 0.35, "trail_size": 2.0,
			"aftereffect": "embers",
		}],
		["SLOW BURN GOLD", {
			"color": Color(1.0, 0.75, 0.15), "dur": 3.2,
			"charge": 0.6, "glow_max": 3.0, "stretch_y": 2.0, "squeeze_x": 0.5,
			"exit_accel": 2.0, "streak_density": 0.25, "trail_size": 2.5,
			"aftereffect": "embers",
		}],
		["INSTANT SNAP", {
			"color": Color(0.6, 0.9, 1.0), "dur": 1.0,
			"charge": 0.15, "glow_max": 6.0, "stretch_y": 5.0, "squeeze_x": 0.1,
			"exit_accel": 6.0, "streak_density": 0.7, "trail_size": 0.8,
			"aftereffect": "flash",
		}],
		["VOID PURPLE", {
			"color": Color(0.5, 0.1, 1.0), "dur": 2.6,
			"charge": 0.5, "glow_max": 3.5, "stretch_y": 3.5, "squeeze_x": 0.3,
			"exit_accel": 3.0, "streak_density": 0.3, "trail_size": 2.0,
			"aftereffect": "ripple",
		}],
		["EMERALD SURGE", {
			"color": Color(0.1, 1.0, 0.5), "dur": 2.0,
			"charge": 0.4, "glow_max": 3.5, "stretch_y": 3.0, "squeeze_x": 0.35,
			"exit_accel": 3.5, "streak_density": 0.45, "trail_size": 1.5,
			"aftereffect": "scatter",
		}],
		["HEAVY WARP", {
			"color": Color(0.4, 0.5, 1.0), "dur": 3.0,
			"charge": 0.55, "glow_max": 2.5, "stretch_y": 2.0, "squeeze_x": 0.55,
			"exit_accel": 1.8, "streak_density": 0.5, "trail_size": 3.0,
			"aftereffect": "shockwave",
		}],
		["SOLAR FLARE", {
			"color": Color(1.0, 0.5, 0.05), "dur": 1.8,
			"charge": 0.35, "glow_max": 5.0, "stretch_y": 4.0, "squeeze_x": 0.25,
			"exit_accel": 4.5, "streak_density": 0.55, "trail_size": 1.2,
			"aftereffect": "embers",
		}],
		["GHOST TRAIL", {
			"color": Color(0.6, 0.8, 0.9), "dur": 2.8,
			"charge": 0.5, "glow_max": 2.0, "stretch_y": 1.8, "squeeze_x": 0.6,
			"exit_accel": 2.0, "streak_density": 0.15, "trail_size": 2.0,
			"aftereffect": "ghosts",
		}],
	]

	for i in variants.size():
		var def: Array = variants[i]
		var cell := _WarpCell.new()
		cell.setup(i, str(def[0]), def[1] as Dictionary)
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
# Light Speed warp cell — parameterized variation with aftereffects
# ═══════════════════════════════════════════════════════════════════════

class _WarpCell extends VBoxContainer:
	const SHIP_HOME: Vector2 = Vector2(175.0, 160.0)
	const IDLE_DUR: float = 0.8
	const BLANK_DUR: float = 0.8
	const W: int = 350
	const H: int = 270

	var _idx: int = 0
	var _label_name: String = ""
	var _dur: float = 2.0
	var _color: Color = Color.CYAN
	var _charge: float = 0.45
	var _glow_max: float = 3.5
	var _stretch_y: float = 3.0
	var _squeeze_x: float = 0.35
	var _exit_accel: float = 3.0
	var _streak_density: float = 0.4
	var _trail_size: float = 1.5
	var _aftereffect: String = "none"

	var _vp: SubViewport
	var _ship: ShipRenderer
	var _fx: _FXLayer
	var _time: float = 0.0
	var _phase: int = 0
	# Ghost trail state
	var _ghost_positions: Array = []

	func setup(idx: int, ename: String, cfg: Dictionary) -> void:
		_idx = idx
		_label_name = ename
		_dur = float(cfg.get("dur", 2.0))
		_color = cfg.get("color", Color.CYAN) as Color
		_charge = float(cfg.get("charge", 0.45))
		_glow_max = float(cfg.get("glow_max", 3.5))
		_stretch_y = float(cfg.get("stretch_y", 3.0))
		_squeeze_x = float(cfg.get("squeeze_x", 0.35))
		_exit_accel = float(cfg.get("exit_accel", 3.0))
		_streak_density = float(cfg.get("streak_density", 0.4))
		_trail_size = float(cfg.get("trail_size", 1.5))
		_aftereffect = str(cfg.get("aftereffect", "none"))
		_time = float(idx) * 0.35

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
			_run_light_speed(p, delta)
		elif _time >= IDLE_DUR + _dur:
			_ship.visible = false

		_fx.queue_redraw()

	func _reset() -> void:
		_ship.visible = true
		_ship.position = SHIP_HOME
		_ship.scale = Vector2.ONE
		_ship.modulate = Color.WHITE
		_phase = 0
		_fx.particles.clear()
		_fx.shapes.clear()
		_ghost_positions.clear()

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
			i -= 1

	func _emit(pos: Vector2, vel: Vector2, life: float, col: Color, sz: float) -> void:
		if _fx.particles.size() < 80:
			_fx.particles.append({"p": pos, "v": vel, "l": life, "ml": life, "c": col, "s": sz})

	func _hdr(mult: float) -> Color:
		return Color(_color.r * mult, _color.g * mult, _color.b * mult)

	func _hdr_a(mult: float, a: float) -> Color:
		return Color(_color.r * mult, _color.g * mult, _color.b * mult, a)

	# ── Light Speed core effect with parameterized aftereffects ──────

	func _run_light_speed(p: float, dt: float) -> void:
		# Phase 1: Charge — stretch + squeeze + glow + ambient streaks
		if p < _charge:
			var t: float = p / _charge
			var ease_t: float = t * t
			# Ship deformation
			var sy: float = 1.0 + ease_t * (_stretch_y - 1.0)
			var sx: float = 1.0 - ease_t * (1.0 - _squeeze_x)
			_ship.scale = Vector2(sx, sy)
			# Glow ramp
			var glow: float = 1.0 + ease_t * (_glow_max - 1.0)
			_ship.modulate = Color(
				lerpf(1.0, _color.r * glow, ease_t),
				lerpf(1.0, _color.g * glow, ease_t),
				lerpf(1.0, _color.b * glow, ease_t))
			# Ambient streak lines
			if randf() < t * _streak_density:
				var x_off: float = randf_range(-35.0, 35.0)
				_emit(Vector2(SHIP_HOME.x + x_off, float(H)),
					Vector2(0.0, -randf_range(180.0, 350.0)),
					0.3, _hdr_a(1.5, 0.4), _trail_size * 0.7)
			# Record ghost position for ghost trail aftereffect
			if _aftereffect == "ghosts" and fmod(_time, 0.08) < dt:
				_ghost_positions.append({"pos": Vector2(_ship.position), "scale": Vector2(_ship.scale),
					"alpha": 0.5})

		# Phase 2: Exit — shoot upward
		elif p < _charge + (1.0 - _charge) * 0.6:
			var exit_start: float = _charge
			var exit_end: float = _charge + (1.0 - _charge) * 0.6
			var t: float = (p - exit_start) / (exit_end - exit_start)
			var ease_t: float = pow(t, _exit_accel)
			# Fully deformed
			_ship.scale = Vector2(_squeeze_x * (1.0 - t * 0.5), _stretch_y + t * (_stretch_y * 0.5))
			_ship.position.y = SHIP_HOME.y - ease_t * 500.0
			# Max glow, fading out
			_ship.modulate = Color(
				_color.r * _glow_max, _color.g * _glow_max, _color.b * _glow_max,
				1.0 - t * 0.8)
			# Heavy trail particles
			if randf() < _streak_density + 0.2:
				_emit(Vector2(_ship.position.x + randf_range(-5.0, 5.0), _ship.position.y + 25.0),
					Vector2(randf_range(-8.0, 8.0), randf_range(60.0, 150.0)),
					0.3, _hdr_a(2.5, 0.6), _trail_size)
			# Side streaks
			if randf() < 0.4:
				var x: float = SHIP_HOME.x + randf_range(-3.0, 3.0)
				_emit(Vector2(x, _ship.position.y + 40.0),
					Vector2(0.0, 100.0), 0.2, _hdr_a(1.8, 0.3), _trail_size * 0.6)
			# Record ghost
			if _aftereffect == "ghosts" and fmod(_time, 0.04) < dt:
				_ghost_positions.append({"pos": Vector2(_ship.position), "scale": Vector2(_ship.scale),
					"alpha": 0.4})

		# Phase 3: Aftereffect — ship gone, aftermath plays
		else:
			_ship.visible = false
			var after_start: float = _charge + (1.0 - _charge) * 0.6
			var after_t: float = (p - after_start) / (1.0 - after_start)

			match _aftereffect:
				"flash":
					_after_flash(after_t)
				"embers":
					_after_embers(after_t)
				"ripple":
					_after_ripple(after_t)
				"scatter":
					_after_scatter(after_t)
				"shockwave":
					_after_shockwave(after_t)
				"ghosts":
					_after_ghosts(after_t)
				_:
					pass  # "none" — just lingering particles

	# ── Aftereffect: FLASH — bright whiteout that fades ──────────────

	func _after_flash(t: float) -> void:
		if t < 0.4:
			var intensity: float = (0.4 - t) / 0.4
			_fx.shapes.append([0, SHIP_HOME, 60.0 + t * 100.0,
				Color(_color.r * 4.0, _color.g * 4.0, _color.b * 4.0, intensity * 0.35)])
			_fx.shapes.append([0, SHIP_HOME, 20.0 + t * 30.0,
				Color(1.0, 1.0, 1.0, intensity * 0.2)])

	# ── Aftereffect: EMBERS — warm particles drift upward ────────────

	func _after_embers(t: float) -> void:
		if t < 0.5 and randf() < 0.3:
			var spawn: Vector2 = SHIP_HOME + Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
			var warmth: float = randf()
			var col: Color
			if warmth < 0.4:
				col = Color(_color.r * 2.5, _color.g * 0.8, _color.b * 0.3, 0.7)
			else:
				col = Color(_color.r * 2.0, _color.g * 1.8, _color.b * 0.5, 0.6)
			_emit(spawn, Vector2(randf_range(-12.0, 12.0), randf_range(-50.0, -20.0)),
				randf_range(0.6, 1.2), col, randf_range(1.5, 3.0))

	# ── Aftereffect: RIPPLE — expanding rings from departure point ───

	func _after_ripple(t: float) -> void:
		for i in 3:
			var ring_t: float = t - float(i) * 0.12
			if ring_t < 0.0 or ring_t > 0.7:
				continue
			var norm_t: float = ring_t / 0.7
			var radius: float = norm_t * 100.0
			var alpha: float = (1.0 - norm_t) * 0.5
			_fx.shapes.append([1, SHIP_HOME, radius, 0.0, TAU, 48,
				_hdr_a(2.5, alpha), 2.0])

	# ── Aftereffect: SCATTER — burst of particles in all directions ──

	func _after_scatter(t: float) -> void:
		if _phase == 0:
			_phase = 1
			for i in 16:
				var angle: float = randf() * TAU
				var speed: float = randf_range(60.0, 180.0)
				_emit(SHIP_HOME, Vector2(cos(angle), sin(angle)) * speed,
					0.6, _hdr_a(3.0, 0.8), randf_range(1.5, 3.0))

	# ── Aftereffect: SHOCKWAVE — heavy expanding ring + screen shake particles

	func _after_shockwave(t: float) -> void:
		if t < 0.6:
			var radius: float = t / 0.6 * 140.0
			var alpha: float = (0.6 - t) / 0.6
			_fx.shapes.append([1, SHIP_HOME, radius, 0.0, TAU, 64,
				_hdr_a(3.0, alpha * 0.7), 3.5])
			_fx.shapes.append([1, SHIP_HOME, radius * 0.85, 0.0, TAU, 48,
				_hdr_a(2.0, alpha * 0.3), 1.5])
			# Inner flash
			if t < 0.2:
				var flash_a: float = (0.2 - t) / 0.2
				_fx.shapes.append([0, SHIP_HOME, 30.0 + t * 50.0,
					Color(1.0, 1.0, 1.0, flash_a * 0.15)])
		if _phase == 0:
			_phase = 1
			for i in 12:
				var angle: float = randf() * TAU
				_emit(SHIP_HOME, Vector2(cos(angle), sin(angle)) * randf_range(30.0, 80.0),
					0.5, _hdr_a(2.0, 0.5), 1.5)

	# ── Aftereffect: GHOSTS — fading afterimages along the exit path ─

	func _after_ghosts(t: float) -> void:
		# Draw fading ghost silhouettes from recorded positions
		var fade_base: float = 1.0 - t
		for gi in _ghost_positions.size():
			var ghost: Dictionary = _ghost_positions[gi]
			var pos: Vector2 = ghost["pos"]
			var alpha: float = float(ghost["alpha"]) * fade_base * 0.6
			if alpha < 0.02:
				continue
			# Simple ghost: bright elongated rectangle representing stretched ship
			var gscale: Vector2 = ghost["scale"]
			var ghost_h: float = 20.0 * gscale.y
			var ghost_w: float = 8.0 * gscale.x
			_fx.shapes.append([3,
				Rect2(pos.x - ghost_w * 0.5, pos.y - ghost_h * 0.5, ghost_w, ghost_h),
				_hdr_a(2.0, alpha)])


# ═══════════════════════════════════════════════════════════════════════
# FX drawing layer — renders shapes and particles via _draw()
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
