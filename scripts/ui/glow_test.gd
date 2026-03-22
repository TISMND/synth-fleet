extends Control
## ACES Bloom Tuning Scene
## All visual content renders in a SubViewport with ACES bloom — identical pipeline
## to the actual game. Sliders modify the SubViewport's WorldEnvironment live.
## SAVE writes values to ThemeManager so all screens pick them up.

var env: Environment
var _viewport: SubViewport

# Slider references
var _sliders: Dictionary = {}  # key -> HSlider
var _labels: Dictionary = {}   # key -> Label
var _level_toggles: Array[CheckButton] = []

# HDR bar references
var hdr_bars: Array[ColorRect] = []


func _ready() -> void:
	# SubViewport at game resolution with ACES bloom — what you see here = what you get in game
	var svc := SubViewportContainer.new()
	svc.name = "BloomViewport"
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Clicks pass through to controls on root
	add_child(svc)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.use_hdr_2d = true
	svc.add_child(_viewport)

	# Create WorldEnvironment manually so we can tune it live
	var world_env := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Load current saved values
	env.glow_intensity = ThemeManager.get_float("glow_intensity")
	env.glow_bloom = ThemeManager.get_float("glow_bloom")
	env.glow_hdr_threshold = ThemeManager.get_float("glow_hdr_threshold")
	for i in 7:
		var val: float = ThemeManager.get_float("glow_level_%d" % i)
		env.set_glow_level(i, val > 0.5)
	world_env.environment = env
	_viewport.add_child(world_env)

	# Grid background inside viewport
	var grid_bg := ColorRect.new()
	grid_bg.size = Vector2(1920, 1080)
	grid_bg.z_index = -10
	_viewport.add_child(grid_bg)
	ThemeManager.apply_grid_background(grid_bg)

	# Visual content inside viewport
	_build_led_bars(40, 60)
	_build_hdr_bars(1200, 60)
	_build_ships(450, 60)
	_build_brightness_strips(450, 490)

	# Controls on ROOT (above SubViewport) — interactive
	_build_controls()
	_build_nav()


# ── LED bars (shader + led_glow, same as game HUD) ──

func _build_led_bars(x: float, y: float) -> void:
	var header := Label.new()
	header.text = "LED BARS (shader + led_glow)"
	header.position = Vector2(x, y - 30)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_viewport.add_child(header)

	var configs: Array = [
		{"name": "SHIELD", "color": Color(0.2, 0.6, 1.0), "segments": 10, "fill": 0.8},
		{"name": "HULL", "color": Color(0.9, 0.3, 0.2), "segments": 8, "fill": 0.6},
		{"name": "THERMAL", "color": Color(1.0, 0.6, 0.0), "segments": 6, "fill": 0.5},
		{"name": "ELECTRIC", "color": Color(0.3, 1.0, 0.5), "segments": 8, "fill": 1.0},
	]

	for i in configs.size():
		var cfg: Dictionary = configs[i]
		var bar_x: float = x + float(i) * 70.0
		var color: Color = cfg["color"]
		var segs: int = cfg["segments"]
		var fill: float = cfg["fill"]
		var seg_px: float = ThemeManager.get_float("led_segment_width_px")
		var gap_px: float = ThemeManager.get_float("led_segment_gap_px")
		var bar_height: float = float(segs) * seg_px + float(segs - 1) * gap_px

		var bar := ProgressBar.new()
		bar.fill_mode = 3  # FILL_BOTTOM_TO_TOP
		bar.max_value = segs
		bar.value = int(float(segs) * fill)
		bar.show_percentage = false
		bar.position = Vector2(bar_x, y + 500.0 - bar_height)
		bar.size = Vector2(28, bar_height)
		_viewport.add_child(bar)
		ThemeManager.apply_led_bar(bar, color, fill, segs, true)

		var lbl := Label.new()
		lbl.text = str(cfg["name"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(bar_x - 10, y + 510)
		lbl.size = Vector2(50, 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", color)
		_viewport.add_child(lbl)


# ── HDR bars (raw ColorRects > 1.0, pure bloom test) ──

func _build_hdr_bars(x: float, y: float) -> void:
	var header := Label.new()
	header.text = "HDR COLORRECTS (raw bloom)"
	header.position = Vector2(x, y - 30)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_viewport.add_child(header)

	var configs: Array = [
		{"name": "SHIELD", "color": Color(0.2, 0.6, 1.0), "segments": 10, "fill": 0.8},
		{"name": "HULL", "color": Color(0.9, 0.3, 0.2), "segments": 8, "fill": 0.6},
		{"name": "THERMAL", "color": Color(1.0, 0.6, 0.0), "segments": 6, "fill": 0.5},
		{"name": "ELECTRIC", "color": Color(0.3, 1.0, 0.5), "segments": 8, "fill": 1.0},
	]

	var seg_px: float = ThemeManager.get_float("led_segment_width_px")
	var gap_px: float = ThemeManager.get_float("led_segment_gap_px")
	var hdr_mult: float = ThemeManager.get_float("led_hdr_multiplier")

	for i in configs.size():
		var cfg: Dictionary = configs[i]
		var bar_x: float = x + float(i) * 70.0
		var base_color: Color = cfg["color"]
		var segs: int = cfg["segments"]
		var fill: float = cfg["fill"]
		var lit_count: int = int(float(segs) * fill)
		var bar_height: float = float(segs) * seg_px + float(segs - 1) * gap_px

		var container := Control.new()
		container.position = Vector2(bar_x, y + 500.0 - bar_height)
		container.size = Vector2(52, bar_height)
		_viewport.add_child(container)

		for s in segs:
			var seg_y: float = bar_height - float(s + 1) * seg_px - float(s) * gap_px
			var seg_rect := ColorRect.new()
			seg_rect.position = Vector2(0, seg_y)
			seg_rect.size = Vector2(52, seg_px)
			if s < lit_count:
				seg_rect.color = Color(
					base_color.r * hdr_mult,
					base_color.g * hdr_mult,
					base_color.b * hdr_mult,
					1.0
				)
			else:
				seg_rect.color = Color(0.08, 0.08, 0.12)
			container.add_child(seg_rect)

		hdr_bars.append(container)

		var lbl := Label.new()
		lbl.text = str(cfg["name"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(bar_x - 10, y + 510)
		lbl.size = Vector2(70, 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", base_color)
		_viewport.add_child(lbl)


# ── Ships (chrome + neon) ──

func _build_ships(x: float, y: float) -> void:
	var header := Label.new()
	header.text = "Ships (should NOT glow unless neon edges are bright)"
	header.position = Vector2(x, y - 30)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_viewport.add_child(header)

	for i in 5:
		var ship := ShipRenderer.new()
		ship.ship_id = i
		ship.render_mode = ShipRenderer.RenderMode.CHROME
		var s: float = ShipRenderer.get_ship_scale(i)
		ship.scale = Vector2(s, s)
		ship.position = Vector2(x + 30 + float(i) * 140, y + 100)
		ship.animate = true
		_viewport.add_child(ship)

	var enemy_ids: Array = ["sentinel", "dart", "crucible", "prism", "scythe"]
	for i in enemy_ids.size():
		var ship := ShipRenderer.new()
		ship.ship_id = -1
		ship.enemy_visual_id = enemy_ids[i]
		ship.render_mode = ShipRenderer.RenderMode.NEON
		ship.hull_color = Color(0.0, 0.9, 1.0)
		ship.accent_color = Color(1.0, 0.2, 0.6)
		ship.scale = Vector2(1.6, 1.6)
		ship.position = Vector2(x + 30 + float(i) * 140, y + 300)
		ship.animate = true
		_viewport.add_child(ship)


# ── Brightness test strips ──

func _build_brightness_strips(x: float, y: float) -> void:
	var header := Label.new()
	header.text = "Brightness test (0.5x - 3.0x):"
	header.position = Vector2(x, y)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_viewport.add_child(header)

	var brightnesses: Array = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0]
	for i in brightnesses.size():
		var b: float = brightnesses[i]
		var strip := ColorRect.new()
		strip.position = Vector2(x + float(i) * 90, y + 25)
		strip.size = Vector2(75, 30)
		strip.color = Color(0.2 * b, 0.6 * b, 1.0 * b)
		_viewport.add_child(strip)

		var lbl := Label.new()
		lbl.text = "x%.1f" % b
		lbl.position = Vector2(x + float(i) * 90, y + 58)
		lbl.size = Vector2(75, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_viewport.add_child(lbl)


# ── Control panel (on ROOT, overlays SubViewport) ──

func _build_controls() -> void:
	# Panel background
	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2(40, 680)
	panel_bg.size = Vector2(860, 380)
	panel_bg.color = Color(0.04, 0.04, 0.08, 0.92)
	add_child(panel_bg)

	var title := Label.new()
	title.text = "ACES BLOOM TUNING — changes apply to all SubViewports"
	title.position = Vector2(60, 690)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(title)

	var y_start: float = 720.0

	# Glow toggle
	var glow_toggle := CheckButton.new()
	glow_toggle.text = "Glow Enabled"
	glow_toggle.button_pressed = true
	glow_toggle.position = Vector2(60, y_start)
	glow_toggle.add_theme_font_size_override("font_size", 14)
	glow_toggle.toggled.connect(func(on: bool): env.glow_enabled = on)
	add_child(glow_toggle)

	y_start += 35.0

	# Sliders — initialized from ThemeManager's saved values
	_add_slider("glow_hdr_threshold", "HDR Threshold", 60, y_start,
		0.0, 2.0, ThemeManager.get_float("glow_hdr_threshold"),
		func(v: float): env.glow_hdr_threshold = v)

	_add_slider("glow_intensity", "Glow Intensity", 60, y_start + 40,
		0.0, 5.0, ThemeManager.get_float("glow_intensity"),
		func(v: float): env.glow_intensity = v)

	_add_slider("glow_bloom", "Bloom Mix", 60, y_start + 80,
		0.0, 1.0, ThemeManager.get_float("glow_bloom"),
		func(v: float): env.glow_bloom = v)

	_add_slider("led_hdr_multiplier", "LED HDR Multiplier", 60, y_start + 120,
		0.5, 6.0, ThemeManager.get_float("led_hdr_multiplier"),
		func(v: float): _update_hdr_bar_brightness(v))

	# Glow levels — 7 blur passes
	var levels_lbl := Label.new()
	levels_lbl.text = "Glow Levels (blur radius: 0=tight ... 6=wide):"
	levels_lbl.position = Vector2(60, y_start + 170)
	levels_lbl.add_theme_font_size_override("font_size", 13)
	levels_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(levels_lbl)

	for lvl in 7:
		var cb := CheckButton.new()
		cb.text = str(lvl)
		var current_on: bool = ThemeManager.get_float("glow_level_%d" % lvl) > 0.5
		cb.button_pressed = current_on
		cb.position = Vector2(60 + float(lvl) * 100, y_start + 195)
		cb.add_theme_font_size_override("font_size", 13)
		var level_idx: int = lvl
		cb.toggled.connect(func(on: bool): env.set_glow_level(level_idx, on))
		add_child(cb)
		_level_toggles.append(cb)

	# SAVE button
	var save_btn := Button.new()
	save_btn.text = "SAVE TO ALL SCREENS"
	save_btn.position = Vector2(60, y_start + 240)
	save_btn.size = Vector2(280, 44)
	save_btn.pressed.connect(_save_settings)
	add_child(save_btn)
	ThemeManager.apply_button_style(save_btn)

	# Status label
	var status := Label.new()
	status.name = "SaveStatus"
	status.text = ""
	status.position = Vector2(360, y_start + 250)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	add_child(status)


func _add_slider(key: String, display_name: String, x: float, y: float,
		min_val: float, max_val: float, current: float, callback: Callable) -> void:
	var lbl := Label.new()
	lbl.text = display_name + ":"
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(180, 30)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = current
	slider.step = 0.01
	slider.position = Vector2(x + 190, y + 4)
	slider.size = Vector2(340, 20)
	add_child(slider)
	_sliders[key] = slider

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % current
	val_lbl.position = Vector2(x + 545, y)
	val_lbl.size = Vector2(80, 30)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	add_child(val_lbl)
	_labels[key] = val_lbl

	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%.2f" % v
		callback.call(v)
	)


func _build_nav() -> void:
	# Info panel
	var info_bg := ColorRect.new()
	info_bg.position = Vector2(920, 680)
	info_bg.size = Vector2(960, 380)
	info_bg.color = Color(0.04, 0.04, 0.08, 0.92)
	add_child(info_bg)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.position = Vector2(940, 695)
	info.size = Vector2(920, 340)
	info.add_theme_font_size_override("normal_font_size", 13)
	info.add_theme_color_override("default_color", Color(0.6, 0.65, 0.7))
	info.text = """[b]ACES BLOOM TUNING[/b]

This SubViewport uses the [color=#edc]exact same ACES bloom pipeline[/color] as the game,
hangar, and all previews. What you see here = what you get everywhere.

[color=#aab]LEFT:[/color] LED bars — shader segments + led_glow ColorRect (HDR bloom source).
  These are the actual game HUD bars rendered with apply_led_bar().

[color=#aab]RIGHT:[/color] Raw HDR ColorRects — pure brightness > 1.0.
  Shows where the bloom threshold kicks in.

[color=#aab]HDR Threshold:[/color] Only pixels brighter than this value bloom.
  Lower = more bloom. 0 = everything glows.

[color=#aab]Glow Intensity:[/color] How bright the bloom halo is.

[color=#aab]Bloom Mix:[/color] Applies bloom to ALL pixels — use sparingly (fog).

[color=#aab]Glow Levels:[/color] Each level is a blur pass at increasing radius.
  0 = tight aura, 6 = huge soft halo. Stack multiple for layered bloom.

[color=#aab]LED HDR Multiplier:[/color] How much > 1.0 the led_glow rects are.
  Higher = brighter bloom source for bars.

[color=#ff8]SAVE[/color] writes values to ThemeManager settings — they persist and apply
to all screens on next SubViewport creation."""
	add_child(info)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(1790, 20)
	back_btn.size = Vector2(100, 36)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)
	ThemeManager.apply_button_style(back_btn)


# ── Save ──

func _save_settings() -> void:
	# Write current slider values to ThemeManager (persists to settings file)
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		ThemeManager.set_float(key, slider.value)

	# Write glow levels
	for lvl in 7:
		var on: bool = _level_toggles[lvl].button_pressed
		ThemeManager.set_float("glow_level_%d" % lvl, 1.0 if on else 0.0)

	ThemeManager.save_settings()

	var status: Label = get_node("SaveStatus") as Label
	if status:
		status.text = "Saved! Restart screens to see changes."


# ── HDR bar brightness update ──

func _update_hdr_bar_brightness(multiplier: float) -> void:
	var colors: Array = [
		Color(0.2, 0.6, 1.0), Color(0.9, 0.3, 0.2),
		Color(1.0, 0.6, 0.0), Color(0.3, 1.0, 0.5),
	]
	var fills: Array = [0.8, 0.6, 0.5, 1.0]
	var seg_counts: Array = [10, 8, 6, 8]

	for i in hdr_bars.size():
		var container: Control = hdr_bars[i]
		var base_color: Color = colors[i]
		var lit: int = int(float(seg_counts[i]) * fills[i])
		for s in container.get_child_count():
			var rect: ColorRect = container.get_child(s) as ColorRect
			if s < lit:
				rect.color = Color(
					base_color.r * multiplier,
					base_color.g * multiplier,
					base_color.b * multiplier,
					1.0
				)
			else:
				rect.color = Color(0.08, 0.08, 0.12)
