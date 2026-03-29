extends Control
## Slideshow tutorial: energy, heat, cooling, consequences.
## Uses real HUD side panels from HudBuilder for authentic bar display.
## Parallax star background, pulsing highlights on key bars.

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _body_label: Label
var _nav_container: HBoxContainer
var _back_btn: Button
var _next_btn: Button
var _skip_btn: Button
var _page_label: Label
var _current_slide: int = 0

# HUD panel state
var _left_panel_root: Control
var _right_panel_root: Control
var _left_bars: Dictionary = {}   # bar_name -> {bar, label, ...}
var _right_bars: Dictionary = {}

# Star field layers
var _star_layers: Array = []  # Array of {control, phase_offset}

# Pulse tweens for highlighted bars
var _pulse_tweens: Array = []

# Slide definitions
var _slides: Array = []

const SIDE_PANEL_WIDTH: int = 60


func _ready() -> void:
	_build_slides_data()
	_build_ui()
	_build_hud_panels()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme()
	_show_slide(0)


func _process(delta: float) -> void:
	# Scroll star layers
	for layer_data in _star_layers:
		var ctrl: Control = layer_data["control"]
		var speed: float = layer_data["speed"]
		ctrl.position.y += speed * delta
		# Wrap when scrolled past screen
		if ctrl.position.y >= ctrl.size.y:
			ctrl.position.y -= ctrl.size.y * 2.0
		ctrl.queue_redraw()


func _build_slides_data() -> void:
	var purge_key: String = KeyBindingManager.get_action_binding("thermal_purge").get("keyboard_label", "V")

	_slides = [
		{
			"title": "WEAPONS EAT ENERGY",
			"body": "Every weapon you fire drains your electric reserves.\nWatch the yellow bar on the right — that's your juice.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 0.4},
			"highlight": ["ELECTRIC"],
		},
		{
			"title": "POWER CORES REFILL ENERGY",
			"body": "Toggle on your power cores to recharge.\nBut cores (and some big weapons) generate heat.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.6, "ELECTRIC": 0.8},
			"highlight": ["THERMAL"],
		},
		{
			"title": "COOLING DOWN",
			"body": "Turn off anything hot and your ship cools naturally.\nOr slam [%s] for an emergency thermal purge —\nbut it briefly kills your shields and engines." % purge_key,
			"ratios": {"SHIELD": 0.0, "HULL": 1.0, "THERMAL": 0.15, "ELECTRIC": 0.7},
			"highlight": ["SHIELD"],
		},
		{
			"title": "WHEN THINGS GO WRONG",
			"body": "Overheat? Extra heat hits your hull directly.\nOut of energy? The ship pulls from shields and engines.\nIf those run dry... don't let those run dry.",
			"ratios": {"SHIELD": 0.1, "HULL": 0.3, "THERMAL": 1.0, "ELECTRIC": 0.0},
			"highlight": ["HULL", "THERMAL", "ELECTRIC"],
		},
		{
			"title": "THAT'S IT",
			"body": "Shoot stuff. Manage your bars. Don't explode.\nGood luck out there.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": [],
		},
	]


func _build_ui() -> void:
	# Dark background behind stars
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.01, 0.01, 0.02)
	add_child(_bg)

	# Star field layers (3 depths)
	_build_star_layers()

	# Center content area (between HUD panels)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SIDE_PANEL_WIDTH + 60)
	margin.add_theme_constant_override("margin_right", SIDE_PANEL_WIDTH + 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	margin.add_child(outer)

	# Top spacer pushes content toward center
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(top_spacer)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_title_label)

	# Gap between title and body
	var title_gap := Control.new()
	title_gap.custom_minimum_size = Vector2(0, 20)
	outer.add_child(title_gap)

	# Body text
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_body_label)

	# Bottom spacer pushes content toward center
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(bottom_spacer)

	# Nav bar at bottom (not pushed by spacers — fixed at bottom)
	_nav_container = HBoxContainer.new()
	_nav_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav_container.add_theme_constant_override("separation", 20)
	outer.add_child(_nav_container)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.custom_minimum_size = Vector2(120, 40)
	_back_btn.pressed.connect(_on_back)
	_nav_container.add_child(_back_btn)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.custom_minimum_size = Vector2(80, 0)
	_nav_container.add_child(_page_label)

	_next_btn = Button.new()
	_next_btn.text = "NEXT"
	_next_btn.custom_minimum_size = Vector2(120, 40)
	_next_btn.pressed.connect(_on_next)
	_nav_container.add_child(_next_btn)

	_skip_btn = Button.new()
	_skip_btn.text = "DONE"
	_skip_btn.custom_minimum_size = Vector2(120, 40)
	_skip_btn.pressed.connect(_on_done)
	_nav_container.add_child(_skip_btn)


func _build_star_layers() -> void:
	# 3 parallax-like depth layers of twinkling specks
	var layer_defs: Array = [
		{"count": 100, "color": Color(0.1, 0.35, 0.45, 0.35), "size_min": 0.6, "size_max": 1.4, "speed": 15.0, "seed": 10},
		{"count": 60,  "color": Color(0.15, 0.6, 0.75, 0.5),  "size_min": 0.8, "size_max": 1.6, "speed": 30.0, "seed": 20},
		{"count": 30,  "color": Color(0.3, 0.85, 1.0, 0.65),  "size_min": 0.8, "size_max": 1.8, "speed": 45.0, "seed": 30},
	]
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.y < 100.0:
		vp_size = Vector2(1920, 1080)

	for def in layer_defs:
		# Two copies stacked vertically for seamless wrapping
		for copy_idx in 2:
			var field := _SpeckField.new()
			field.speck_count = int(def["count"])
			field.speck_color = def["color"]
			field.speck_size_min = float(def["size_min"])
			field.speck_size_max = float(def["size_max"])
			field.speck_seed = int(def["seed"]) + copy_idx * 100
			field.size = Vector2(vp_size.x, vp_size.y)
			field.position = Vector2(0, float(copy_idx) * vp_size.y - vp_size.y)
			field.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(field)
			_star_layers.append({"control": field, "speed": float(def["speed"])})


func _build_hud_panels() -> void:
	var screen_h: float = get_viewport_rect().size.y
	var screen_w: float = get_viewport_rect().size.x
	if screen_h < 100.0:
		screen_h = 1080.0
		screen_w = 1920.0

	# Use build_hud — same as the game, so all positioning matches exactly
	var hud_data: Dictionary = HudBuilder.build_hud("preview", screen_h)

	# Bottom panel
	var bottom_root: Control = hud_data["bottom_panel"]["root"]
	bottom_root.position = Vector2(0, screen_h - HudBuilder.BOTTOM_BAR_HEIGHT)
	bottom_root.size = Vector2(screen_w, HudBuilder.BOTTOM_BAR_HEIGHT)
	add_child(bottom_root)

	# Left panel (Shield + Hull) — full height, matching game HUD
	_left_panel_root = hud_data["left_panel"]["root"]
	_left_panel_root.position = Vector2(0, 0)
	_left_panel_root.size = Vector2(SIDE_PANEL_WIDTH, screen_h)
	_left_bars = hud_data["left_panel"]["bars"]
	add_child(_left_panel_root)

	# Right panel (Thermal + Electric)
	_right_panel_root = hud_data["right_panel"]["root"]
	_right_panel_root.position = Vector2(screen_w - SIDE_PANEL_WIDTH, 0)
	_right_panel_root.size = Vector2(SIDE_PANEL_WIDTH, screen_h)
	_right_bars = hud_data["right_panel"]["bars"]
	add_child(_right_panel_root)


func _show_slide(index: int) -> void:
	_current_slide = clampi(index, 0, _slides.size() - 1)
	var slide: Dictionary = _slides[_current_slide]

	# Title — use the global header style (font, size, color, HDR bloom)
	_title_label.text = str(slide["title"])
	var hdr_font: Font = ThemeManager.get_font("font_header")
	if hdr_font:
		_title_label.add_theme_font_override("font", hdr_font)
	_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	ThemeManager.apply_text_glow(_title_label, "header")

	# Body
	_body_label.text = str(slide["body"])
	_body_label.add_theme_font_override("font", ThemeManager.get_font("body"))
	_body_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	_body_label.add_theme_color_override("font_color", ThemeManager.get_color("text_body"))

	# Update HUD bar ratios
	var ratios: Dictionary = slide.get("ratios", {})
	_update_bar_ratio("SHIELD", ratios.get("SHIELD", 1.0))
	_update_bar_ratio("HULL", ratios.get("HULL", 1.0))
	_update_bar_ratio("THERMAL", ratios.get("THERMAL", 0.0))
	_update_bar_ratio("ELECTRIC", ratios.get("ELECTRIC", 1.0))

	# Pulse highlighted bars
	_stop_pulses()
	var highlights: Array = slide.get("highlight", [])
	for bar_name in highlights:
		_start_pulse(str(bar_name))

	# Update nav
	_back_btn.visible = _current_slide > 0
	_next_btn.visible = _current_slide < _slides.size() - 1
	_skip_btn.visible = _current_slide == _slides.size() - 1
	_page_label.text = "%d / %d" % [_current_slide + 1, _slides.size()]

	_apply_nav_theme()


func _update_bar_ratio(bar_name: String, ratio: float) -> void:
	var bar_dict: Dictionary = {}
	if _left_bars.has(bar_name):
		bar_dict = _left_bars[bar_name]
	elif _right_bars.has(bar_name):
		bar_dict = _right_bars[bar_name]
	else:
		return

	var bar: ProgressBar = bar_dict["bar"]
	var specs: Array = ThemeManager.get_status_bar_specs()
	var color: Color = Color.WHITE
	for spec in specs:
		if str(spec["name"]) == bar_name:
			color = ThemeManager.resolve_bar_color(spec)
			break

	var seg: int = int(bar.max_value)
	ThemeManager.apply_led_bar(bar, color, ratio, seg, true)


# ── LED pulse animation ────────────────────────────────────

func _start_pulse(bar_name: String) -> void:
	var bar_dict: Dictionary = {}
	if _left_bars.has(bar_name):
		bar_dict = _left_bars[bar_name]
	elif _right_bars.has(bar_name):
		bar_dict = _right_bars[bar_name]
	else:
		return

	var bar: ProgressBar = bar_dict["bar"]
	# Find the led_glow child that apply_led_bar creates
	var glow_rect: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
	if not glow_rect:
		return

	var base_alpha: float = glow_rect.color.a
	var bright_alpha: float = clampf(base_alpha + 0.8, 0.0, 1.0)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow_rect, "color:a", bright_alpha, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow_rect, "color:a", base_alpha, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tweens.append(tween)


func _stop_pulses() -> void:
	for tween in _pulse_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_pulse_tweens.clear()


# ── Navigation ─────────────────────────────────────────────

func _on_back() -> void:
	if _current_slide > 0:
		_show_slide(_current_slide - 1)


func _on_next() -> void:
	if _current_slide < _slides.size() - 1:
		_show_slide(_current_slide + 1)


func _on_done() -> void:
	_stop_pulses()
	get_tree().change_scene_to_file("res://scenes/ui/mission_prep_menu.tscn")


# ── Theming ────────────────────────────────────────────────

func _apply_theme() -> void:
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_nav_theme()


func _apply_nav_theme() -> void:
	ThemeManager.apply_button_style(_back_btn)
	ThemeManager.apply_button_style(_next_btn)
	ThemeManager.apply_button_style(_skip_btn)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	_apply_theme()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_done()
	elif event.is_action_pressed("ui_accept"):
		if _current_slide < _slides.size() - 1:
			_on_next()
		else:
			_on_done()


# ── Star field drawing ─────────────────────────────────────

class _SpeckField extends Control:
	var speck_count: int = 60
	var speck_color: Color = Color(0.5, 0.5, 0.8, 0.6)
	var speck_size_min: float = 1.0
	var speck_size_max: float = 2.5
	var speck_seed: int = 1

	var _positions: Array = []
	var _sizes: Array = []
	var _phases: Array = []
	var _speeds: Array = []
	var _time: float = 0.0
	var _initialized: bool = false

	func _process(delta: float) -> void:
		_time += delta

	func _draw() -> void:
		if not _initialized:
			_init_specks()
		for i in _positions.size():
			var twinkle: float = 0.6 + 0.4 * sin(_time * _speeds[i] + _phases[i])
			var col := Color(speck_color.r, speck_color.g, speck_color.b, speck_color.a * twinkle)
			var r: float = _sizes[i] * (0.85 + 0.15 * twinkle)
			draw_circle(_positions[i], r, col)

	func _init_specks() -> void:
		_initialized = true
		var rng := RandomNumberGenerator.new()
		rng.seed = speck_seed
		for i in speck_count:
			_positions.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
			_sizes.append(rng.randf_range(speck_size_min, speck_size_max))
			_phases.append(rng.randf() * TAU)
			_speeds.append(rng.randf_range(1.0, 3.0))
