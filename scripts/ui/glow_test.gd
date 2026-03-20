extends Control
## Glow test scene: compare current shader-based LED glow vs WorldEnvironment HDR bloom.
## Left side: current bars (manual shader glow with overlay padding).
## Right side: HDR bars (simple bright colors, WorldEnvironment bloom does the glow).
## Center: ships + grid to prove normal-brightness content is unaffected.

var world_env: WorldEnvironment
var env: Environment

# Slider references for live tuning
var threshold_slider: HSlider
var intensity_slider: HSlider
var bloom_slider: HSlider
var threshold_label: Label
var intensity_label: Label
var bloom_label: Label
var glow_toggle: CheckButton

# HDR bar references for live updates
var hdr_bars: Array[ColorRect] = []
var hdr_multiplier_slider: HSlider
var hdr_mult_label: Label


func _ready() -> void:
	# Grid background
	var grid_bg := ColorRect.new()
	grid_bg.size = Vector2(1920, 1080)
	grid_bg.z_index = -10
	add_child(grid_bg)
	ThemeManager.apply_grid_background(grid_bg)

	# WorldEnvironment — the whole point of this test
	_setup_world_environment()

	# Layout: three columns
	# Left (x=40): Current LED bars (shader glow)
	# Center (x=400-1100): Ships showcase
	# Right (x=1200): HDR LED bars (WorldEnvironment bloom)
	# Bottom (y=800): Control panel with sliders

	_build_current_bars(40, 60)
	_build_hdr_bars(1200, 60)
	_build_ship_showcase()
	_build_controls()
	_build_labels()


func _setup_world_environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8
	env.set_glow_level(0, true)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	add_child(world_env)


# ── Current LED bars (existing shader approach) ──

func _build_current_bars(x: float, y: float) -> void:
	var header := Label.new()
	header.text = "CURRENT (Shader Glow)"
	header.position = Vector2(x, y - 30)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(header)

	var bar_configs: Array = [
		{"name": "SHIELD", "color": Color(0.2, 0.6, 1.0), "segments": 10, "fill": 0.8},
		{"name": "HULL", "color": Color(0.9, 0.3, 0.2), "segments": 8, "fill": 0.6},
		{"name": "THERMAL", "color": Color(1.0, 0.6, 0.0), "segments": 6, "fill": 0.5},
		{"name": "ELECTRIC", "color": Color(0.3, 1.0, 0.5), "segments": 8, "fill": 1.0},
	]

	for i in bar_configs.size():
		var cfg: Dictionary = bar_configs[i]
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
		add_child(bar)
		ThemeManager.apply_led_bar(bar, color, fill, segs, true)

		var lbl := Label.new()
		lbl.text = str(cfg["name"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(bar_x - 10, y + 510)
		lbl.size = Vector2(50, 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", color)
		add_child(lbl)


# ── HDR LED bars (WorldEnvironment bloom approach) ──

func _build_hdr_bars(x: float, y: float) -> void:
	var header := Label.new()
	header.text = "HDR (WorldEnvironment Bloom)"
	header.position = Vector2(x, y - 30)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(header)

	var bar_configs: Array = [
		{"name": "SHIELD", "color": Color(0.2, 0.6, 1.0), "segments": 10, "fill": 0.8},
		{"name": "HULL", "color": Color(0.9, 0.3, 0.2), "segments": 8, "fill": 0.6},
		{"name": "THERMAL", "color": Color(1.0, 0.6, 0.0), "segments": 6, "fill": 0.5},
		{"name": "ELECTRIC", "color": Color(0.3, 1.0, 0.5), "segments": 8, "fill": 1.0},
	]

	var seg_px: float = ThemeManager.get_float("led_segment_width_px")
	var gap_px: float = ThemeManager.get_float("led_segment_gap_px")

	for i in bar_configs.size():
		var cfg: Dictionary = bar_configs[i]
		var bar_x: float = x + float(i) * 70.0
		var base_color: Color = cfg["color"]
		var segs: int = cfg["segments"]
		var fill: float = cfg["fill"]
		var lit_count: int = int(float(segs) * fill)
		var bar_height: float = float(segs) * seg_px + float(segs - 1) * gap_px

		# Container for all segments
		var container := Control.new()
		container.position = Vector2(bar_x, y + 500.0 - bar_height)
		container.size = Vector2(52, bar_height)
		add_child(container)

		# Draw segments as individual ColorRects — bottom to top
		for s in segs:
			var seg_y: float = bar_height - float(s + 1) * seg_px - float(s) * gap_px
			var seg_rect := ColorRect.new()
			seg_rect.position = Vector2(0, seg_y)
			seg_rect.size = Vector2(52, seg_px)

			if s < lit_count:
				# HDR bright — this is what WorldEnvironment bloom picks up
				# Multiply color beyond 1.0 to trigger glow
				var hdr_color := Color(
					base_color.r * 1.8,
					base_color.g * 1.8,
					base_color.b * 1.8,
					1.0
				)
				seg_rect.color = hdr_color
			else:
				# Unlit segment — dim, below threshold, no glow
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
		add_child(lbl)


# ── Ship showcase (center) ──

func _build_ship_showcase() -> void:
	var header := Label.new()
	header.text = "Ships (normal brightness — should NOT glow)"
	header.position = Vector2(450, 30)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(header)

	# Player ships (chrome)
	var player_ships: Array = [0, 1, 2, 3, 4]
	for i in player_ships.size():
		var ship := ShipRenderer.new()
		ship.ship_id = player_ships[i]
		ship.render_mode = ShipRenderer.RenderMode.CHROME
		var s: float = ShipRenderer.get_ship_scale(player_ships[i])
		ship.scale = Vector2(s, s)
		ship.position = Vector2(480 + float(i) * 140, 180)
		ship.animate = true
		add_child(ship)

	# Enemy ships (neon — these have bright colors, interesting test)
	var enemy_ids: Array = ["sentinel", "dart", "crucible", "prism", "scythe"]
	for i in enemy_ids.size():
		var ship := ShipRenderer.new()
		ship.ship_id = -1
		ship.enemy_visual_id = enemy_ids[i]
		ship.render_mode = ShipRenderer.RenderMode.NEON
		ship.hull_color = Color(0.0, 0.9, 1.0)
		ship.accent_color = Color(1.0, 0.2, 0.6)
		ship.scale = Vector2(1.6, 1.6)
		ship.position = Vector2(480 + float(i) * 140, 380)
		ship.animate = true
		add_child(ship)

	# Neon label
	var neon_note := Label.new()
	neon_note.text = "^ Neon enemies — watch if their bright edges pick up bloom"
	neon_note.position = Vector2(450, 440)
	neon_note.add_theme_font_size_override("font_size", 14)
	neon_note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(neon_note)

	# Some bright test rectangles to show threshold behavior
	var bright_header := Label.new()
	bright_header.text = "Brightness test strips (0.5 → 2.0):"
	bright_header.position = Vector2(450, 490)
	bright_header.add_theme_font_size_override("font_size", 14)
	bright_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(bright_header)

	var test_brightnesses: Array = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0]
	for i in test_brightnesses.size():
		var brightness: float = test_brightnesses[i]
		var strip := ColorRect.new()
		strip.position = Vector2(450 + float(i) * 100, 520)
		strip.size = Vector2(80, 30)
		strip.color = Color(0.2 * brightness, 0.6 * brightness, 1.0 * brightness)
		add_child(strip)

		var val_lbl := Label.new()
		val_lbl.text = "×" + str(brightness)
		val_lbl.position = Vector2(450 + float(i) * 100, 555)
		val_lbl.size = Vector2(80, 20)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		add_child(val_lbl)


# ── Control panel ──

func _build_controls() -> void:
	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2(40, 700)
	panel_bg.size = Vector2(800, 340)
	panel_bg.color = Color(0.06, 0.06, 0.1, 0.85)
	add_child(panel_bg)

	var title := Label.new()
	title.text = "WORLDENVIRONMENT GLOW CONTROLS"
	title.position = Vector2(60, 710)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(title)

	# Toggle glow on/off
	glow_toggle = CheckButton.new()
	glow_toggle.text = "Glow Enabled"
	glow_toggle.button_pressed = true
	glow_toggle.position = Vector2(60, 740)
	glow_toggle.add_theme_font_size_override("font_size", 14)
	glow_toggle.toggled.connect(_on_glow_toggled)
	add_child(glow_toggle)

	# HDR Threshold slider
	var y_start: float = 780.0
	_add_slider_row("HDR Threshold", 60, y_start, 0.0, 2.0, 0.8, _on_threshold_changed)
	threshold_slider = get_node("slider_HDR Threshold") as HSlider
	threshold_label = get_node("value_HDR Threshold") as Label

	_add_slider_row("Glow Intensity", 60, y_start + 50, 0.0, 3.0, 0.8, _on_intensity_changed)
	intensity_slider = get_node("slider_Glow Intensity") as HSlider
	intensity_label = get_node("value_Glow Intensity") as Label

	_add_slider_row("Bloom Mix", 60, y_start + 100, 0.0, 1.0, 0.1, _on_bloom_changed)
	bloom_slider = get_node("slider_Bloom Mix") as HSlider
	bloom_label = get_node("value_Bloom Mix") as Label

	_add_slider_row("HDR Multiplier", 60, y_start + 150, 0.5, 4.0, 1.8, _on_hdr_mult_changed)
	hdr_multiplier_slider = get_node("slider_HDR Multiplier") as HSlider
	hdr_mult_label = get_node("value_HDR Multiplier") as Label

	# Glow level toggles
	var levels_lbl := Label.new()
	levels_lbl.text = "Glow Levels (blur passes):"
	levels_lbl.position = Vector2(60, y_start + 210)
	levels_lbl.add_theme_font_size_override("font_size", 13)
	levels_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(levels_lbl)

	for lvl in 7:
		var cb := CheckButton.new()
		cb.text = str(lvl)
		cb.button_pressed = lvl < 3  # Levels 0-2 on by default
		cb.position = Vector2(60 + float(lvl) * 90, y_start + 235)
		cb.add_theme_font_size_override("font_size", 12)
		cb.toggled.connect(_on_glow_level_toggled.bind(lvl))
		add_child(cb)


func _add_slider_row(label_text: String, x: float, y: float, min_val: float, max_val: float, default_val: float, callback: Callable) -> void:
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(160, 30)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	add_child(lbl)

	var slider := HSlider.new()
	slider.name = "slider_" + label_text
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = 0.01
	slider.position = Vector2(x + 170, y + 4)
	slider.size = Vector2(300, 20)
	slider.value_changed.connect(callback)
	add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = "value_" + label_text
	val_lbl.text = "%.2f" % default_val
	val_lbl.position = Vector2(x + 490, y)
	val_lbl.size = Vector2(80, 30)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	add_child(val_lbl)


func _build_labels() -> void:
	# Back button
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(1750, 20)
	back_btn.size = Vector2(120, 40)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)
	ThemeManager.apply_button_style(back_btn)

	# Explanation panel
	var info_bg := ColorRect.new()
	info_bg.position = Vector2(900, 700)
	info_bg.size = Vector2(960, 340)
	info_bg.color = Color(0.06, 0.06, 0.1, 0.85)
	add_child(info_bg)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.position = Vector2(920, 710)
	info.size = Vector2(920, 310)
	info.add_theme_font_size_override("normal_font_size", 13)
	info.add_theme_color_override("default_color", Color(0.6, 0.65, 0.7))
	info.text = """[b]HOW IT WORKS[/b]

[color=#aab]LEFT:[/color] Current bars — shader computes glow manually via SDF.
  Glow is a child ColorRect with negative offsets. Inflates layout, clips at rect edge.

[color=#aab]RIGHT:[/color] HDR bars — simple ColorRects with brightness > 1.0.
  WorldEnvironment bloom picks them up automatically. No overlay, no layout inflation.

[color=#aab]CENTER:[/color] Ships + brightness test strips.
  Normal colors (< threshold) = no glow. Bright colors (> threshold) = glow.
  Adjust [color=#edc]HDR Threshold[/color] slider to see where the cutoff is.
  Adjust [color=#edc]HDR Multiplier[/color] to change how bright the right-side bars are.

[color=#aab]GLOW LEVELS:[/color] Each level is a blur pass at increasing radius.
  Level 0 = tight glow (aura). Level 6 = huge soft bloom. Mix and match."""
	add_child(info)


# ── Callbacks ──

func _on_glow_toggled(enabled: bool) -> void:
	env.glow_enabled = enabled


func _on_threshold_changed(val: float) -> void:
	env.glow_hdr_threshold = val
	threshold_label.text = "%.2f" % val


func _on_intensity_changed(val: float) -> void:
	env.glow_intensity = val
	intensity_label.text = "%.2f" % val


func _on_bloom_changed(val: float) -> void:
	env.glow_bloom = val
	bloom_label.text = "%.2f" % val


func _on_hdr_mult_changed(val: float) -> void:
	hdr_mult_label.text = "%.2f" % val
	_update_hdr_bar_brightness(val)


func _on_glow_level_toggled(enabled: bool, level: int) -> void:
	env.set_glow_level(level, enabled)


func _update_hdr_bar_brightness(multiplier: float) -> void:
	var bar_colors: Array = [
		Color(0.2, 0.6, 1.0),
		Color(0.9, 0.3, 0.2),
		Color(1.0, 0.6, 0.0),
		Color(0.3, 1.0, 0.5),
	]
	var fills: Array = [0.8, 0.6, 0.5, 1.0]
	var seg_counts: Array = [10, 8, 6, 8]

	for i in hdr_bars.size():
		var container: Control = hdr_bars[i]
		var base_color: Color = bar_colors[i]
		var lit_count: int = int(float(seg_counts[i]) * fills[i])

		for s in container.get_child_count():
			var seg_rect: ColorRect = container.get_child(s) as ColorRect
			if s < lit_count:
				seg_rect.color = Color(
					base_color.r * multiplier,
					base_color.g * multiplier,
					base_color.b * multiplier,
					1.0
				)
			else:
				seg_rect.color = Color(0.08, 0.08, 0.12)
