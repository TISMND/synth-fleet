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
var _bottom_icon_entries: Array = []  # icon dicts from build_bottom_panel

# Star field layers
var _star_layers: Array = []  # Array of {control, phase_offset}

# Pulse tweens for highlighted bars and arrows
var _pulse_tweens: Array = []
var _arrow_labels: Array = []  # Arrow Label nodes to clean up per slide

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
		# ── WELCOME ──
		{"title": "WELCOME TO THE BEST DAY OF YOUR LIFE",
			"body": "Here's how the game works.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},

		# ── MOVEMENT ──
		{"title": "MOVEMENT",
			"body": "Move your ship using the mouse, or WASD.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},
		{"title": "MOVEMENT",
			"body": "Change mouse sensitivity in the options menu.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},

		# ── SHIP COMPONENTS ──
		{"title": "SHIP COMPONENTS",
			"body": "Your ship has seven components.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": [], "highlight_bottom": true},
		{"title": "SHIP COMPONENTS",
			"body": "4 weapons. 2 power cores. 1 field emitter (aka special).",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": [], "highlight_bottom": true},
		{"title": "SHIP COMPONENTS",
			"body": "Turn these on and off using number keys.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": [], "highlight_bottom": true},

		# ── FIRE GROUPS ──
		{"title": "FIRE GROUPS",
			"body": "Fire groups are much easier than managing individual components.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},
		{"title": "FIRE GROUPS",
			"body": "Make preset combinations of components for easy switching.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},
		{"title": "FIRE GROUPS",
			"body": "This is done in the ship loadout screen.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},

		# ── ENERGY ──
		{"title": "ENERGY",
			"body": "You need energy fast.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 0.8},
			"highlight": ["ELECTRIC"]},
		{"title": "ENERGY",
			"body": "Almost all weapons and field emitters consume energy.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 0.5},
			"highlight": ["ELECTRIC"]},
		{"title": "ENERGY",
			"body": "When energy is gone, components pull power from shields and engines.",
			"ratios": {"SHIELD": 0.4, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 0.0},
			"highlight": ["ELECTRIC", "SHIELD"]},
		{"title": "ENERGY",
			"body": "Once those are depleted, a bad thing happens.",
			"ratios": {"SHIELD": 0.0, "HULL": 0.4, "THERMAL": 0.0, "ELECTRIC": 0.0},
			"highlight": ["SHIELD", "HULL"]},
		{"title": "ENERGY",
			"body": "Power Cores generate... power. Most also regenerate shields a little.",
			"ratios": {"SHIELD": 0.7, "HULL": 0.4, "THERMAL": 0.0, "ELECTRIC": 0.8},
			"highlight": ["ELECTRIC", "SHIELD"]},

		# ── HEAT ──
		{"title": "HEAT",
			"body": "Power cores, field emitters, and a few weapons generate heat.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.5, "ELECTRIC": 0.8},
			"highlight": ["THERMAL"]},
		{"title": "HEAT",
			"body": "When you overheat, your hull takes damage.",
			"ratios": {"SHIELD": 1.0, "HULL": 0.6, "THERMAL": 1.0, "ELECTRIC": 0.8},
			"highlight": ["THERMAL", "HULL"]},
		{"title": "HEAT",
			"body": "Your ship will not cool off until all heat-generating components are off.",
			"ratios": {"SHIELD": 1.0, "HULL": 0.6, "THERMAL": 0.3, "ELECTRIC": 0.6},
			"highlight": ["THERMAL"]},
		{"title": "HEAT",
			"body": "You can do an emergency heat flush by pressing [%s]." % purge_key,
			"ratios": {"SHIELD": 1.0, "HULL": 0.6, "THERMAL": 0.0, "ELECTRIC": 0.6},
			"highlight": ["THERMAL"]},
		{"title": "HEAT",
			"body": "Emergency heat flush is faster, but it briefly kills your shields and engines.",
			"ratios": {"SHIELD": 0.0, "HULL": 0.6, "THERMAL": 0.0, "ELECTRIC": 0.6},
			"highlight": ["SHIELD"]},
		{"title": "HEAT",
			"body": "You can change key bindings in the options menu.",
			"ratios": {"SHIELD": 0.6, "HULL": 0.6, "THERMAL": 0.0, "ELECTRIC": 0.6},
			"highlight": []},

		# ── SHIELDS AND HULL ──
		{"title": "SHIELDS AND HULL",
			"body": "What computer-operating human on Earth in 2026 needs shields and hull explained to them?",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": ["SHIELD", "HULL"]},
		{"title": "SHIELDS AND HULL",
			"body": "You don't. You're a captain now.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},

		# ── WHAT'S NEXT ──
		{"title": "WHAT'S NEXT?",
			"body": "Head to the ship loadout screen to equip components and simulate your build.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},
		{"title": "WHAT'S NEXT?",
			"body": "GOOD LUCK.",
			"ratios": {"SHIELD": 1.0, "HULL": 1.0, "THERMAL": 0.0, "ELECTRIC": 1.0},
			"highlight": []},
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

	# Small gap before buttons
	var btn_gap := Control.new()
	btn_gap.custom_minimum_size = Vector2(0, 24)
	outer.add_child(btn_gap)

	# Nav bar right below text
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

	# Bottom spacer to keep the cluster centered
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(bottom_spacer)


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

	# Build side panels in "game" mode so bottom margin pushes bars up to match
	var left_data: Dictionary = HudBuilder.build_side_panel("game", ["SHIELD", "HULL"], {}, screen_h)
	var right_data: Dictionary = HudBuilder.build_side_panel("game", ["THERMAL", "ELECTRIC"], {}, screen_h)

	# Build bottom panel with fake equipped components:
	# 4 weapons, 2 cores, 1 field emitter — all inactive (tutorial, nothing firing)
	var weapon_color: Color = Color.CYAN
	var core_color: Color = Color(0.6, 0.4, 1.0)
	var field_color: Color = Color(0.0, 0.8, 1.0)
	var icon_data: Array = []
	for i in 4:
		icon_data.append({"number": i + 1, "active": false, "color": weapon_color, "type": "weapon"})
	for i in 2:
		icon_data.append({"number": 5 + i, "active": false, "color": core_color, "type": "core"})
	icon_data.append({"number": 7, "active": false, "color": field_color, "type": "field"})

	var bottom_data: Dictionary = HudBuilder.build_bottom_panel(
		icon_data, [],
		screen_w, float(HudBuilder.BOTTOM_BAR_HEIGHT),
		{"warning_width": 180, "warning_height": 44, "center_gap": 100}
	)
	_bottom_icon_entries = bottom_data["icon_entries"]
	var bottom_root: Control = bottom_data["root"]
	bottom_root.position = Vector2(0, screen_h - HudBuilder.BOTTOM_BAR_HEIGHT)
	bottom_root.size = Vector2(screen_w, HudBuilder.BOTTOM_BAR_HEIGHT)
	add_child(bottom_root)

	# Left panel (Shield + Hull)
	_left_panel_root = left_data["root"]
	_left_panel_root.position = Vector2(0, 0)
	_left_panel_root.size = Vector2(SIDE_PANEL_WIDTH, screen_h)
	_left_bars = left_data["bars"]
	add_child(_left_panel_root)

	# Right panel (Thermal + Electric)
	_right_panel_root = right_data["root"]
	_right_panel_root.position = Vector2(screen_w - SIDE_PANEL_WIDTH, 0)
	_right_panel_root.size = Vector2(SIDE_PANEL_WIDTH, screen_h)
	_right_bars = right_data["bars"]
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

	# Pulse highlighted bars + arrows
	_stop_pulses()
	var highlights: Array = slide.get("highlight", [])
	for bar_name in highlights:
		_start_pulse(str(bar_name))
		_spawn_arrow(str(bar_name))

	# Flash bottom panel icons if flagged
	if slide.get("highlight_bottom", false):
		_start_bottom_highlight()

	# Update nav — page counter counts unique headers, not individual slides
	_next_btn.visible = _current_slide < _slides.size() - 1
	_skip_btn.visible = _current_slide == _slides.size() - 1
	var section_idx: int = _get_section_index(_current_slide)
	var section_count: int = _get_section_count()
	_page_label.text = "%d / %d" % [section_idx, section_count]

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
	var bright_alpha: float = clampf(base_alpha + 1.6, 0.0, 1.0)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow_rect, "color:a", bright_alpha, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow_rect, "color:a", base_alpha, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tweens.append(tween)


func _spawn_arrow(bar_name: String) -> void:
	var bar_dict: Dictionary = {}
	var is_left: bool = false
	if _left_bars.has(bar_name):
		bar_dict = _left_bars[bar_name]
		is_left = true
	elif _right_bars.has(bar_name):
		bar_dict = _right_bars[bar_name]
	else:
		return

	var bar: ProgressBar = bar_dict["bar"]
	var bar_color: Color = Color.WHITE
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		if str(spec["name"]) == bar_name:
			bar_color = ThemeManager.resolve_bar_color(spec)
			break

	# Arrow label positioned next to the bar, pointing inward
	var arrow := Label.new()
	arrow.text = "<<<" if is_left else ">>>"
	arrow.add_theme_color_override("font_color", bar_color)
	arrow.add_theme_font_size_override("font_size", 20)
	var body_font: Font = ThemeManager.get_font("body")
	if body_font:
		arrow.add_theme_font_override("font", body_font)
	add_child(arrow)
	_arrow_labels.append(arrow)

	# Position: horizontally just outside the panel, vertically centered on the bar
	# Need deferred positioning since bar may not have final layout yet
	var arrow_ref: Label = arrow
	var bar_ref: ProgressBar = bar
	var left: bool = is_left
	(func() -> void:
		if not is_instance_valid(bar_ref) or not is_instance_valid(arrow_ref):
			return
		var bar_center_y: float = bar_ref.global_position.y + bar_ref.size.y * 0.5
		arrow_ref.position.y = bar_center_y - 12.0
		if left:
			arrow_ref.position.x = float(SIDE_PANEL_WIDTH) + 4.0
		else:
			arrow_ref.position.x = get_viewport_rect().size.x - float(SIDE_PANEL_WIDTH) - 52.0
	).call_deferred()

	# Sliding animation — arrow bobs horizontally toward the bar
	var slide_offset: float = 10.0
	var tween: Tween = create_tween()
	tween.set_loops()
	if is_left:
		tween.tween_property(arrow, "position:x", float(SIDE_PANEL_WIDTH) + 4.0 - slide_offset, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(arrow, "position:x", float(SIDE_PANEL_WIDTH) + 4.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		var base_x: float = get_viewport_rect().size.x - float(SIDE_PANEL_WIDTH) - 52.0
		tween.tween_property(arrow, "position:x", base_x + slide_offset, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(arrow, "position:x", base_x, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tweens.append(tween)


func _start_bottom_highlight() -> void:
	var accent: Color = ThemeManager.get_color("accent")
	for entry in _bottom_icon_entries:
		var glow_rect: ColorRect = entry.get("glow_rect") as ColorRect
		if not glow_rect or not is_instance_valid(glow_rect):
			continue
		var icon_color: Color = entry.get("color", Color.CYAN) as Color
		# Flash the glow rect
		glow_rect.color = Color(icon_color.r * 2.0, icon_color.g * 2.0, icon_color.b * 2.0, 0.0)
		var tween: Tween = create_tween()
		tween.set_loops()
		tween.tween_property(glow_rect, "color:a", 0.6, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(glow_rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tweens.append(tween)

	# Single "v" arrow above the center of the icon row, bobbing downward
	if _bottom_icon_entries.is_empty():
		return
	var arrow := Label.new()
	arrow.text = "v  v  v"
	arrow.add_theme_color_override("font_color", accent)
	arrow.add_theme_font_size_override("font_size", 20)
	var body_font: Font = ThemeManager.get_font("body")
	if body_font:
		arrow.add_theme_font_override("font", body_font)
	add_child(arrow)
	_arrow_labels.append(arrow)

	# Position above bottom panel, centered
	var screen_h: float = get_viewport_rect().size.y
	var screen_w: float = get_viewport_rect().size.x
	var base_y: float = screen_h - float(HudBuilder.BOTTOM_BAR_HEIGHT) - 28.0
	(func() -> void:
		if not is_instance_valid(arrow):
			return
		arrow.position.y = base_y
		arrow.position.x = screen_w * 0.5 - arrow.size.x * 0.5
	).call_deferred()

	var atween: Tween = create_tween()
	atween.set_loops()
	atween.tween_property(arrow, "position:y", base_y + 8.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	atween.tween_property(arrow, "position:y", base_y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tweens.append(atween)


func _stop_pulses() -> void:
	for tween in _pulse_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_pulse_tweens.clear()
	for arrow in _arrow_labels:
		if is_instance_valid(arrow):
			arrow.queue_free()
	_arrow_labels.clear()


func _get_section_index(slide_idx: int) -> int:
	## Returns 1-based section number for the given slide index.
	var current_title: String = str(_slides[slide_idx]["title"])
	var section: int = 0
	var last_title: String = ""
	for i in slide_idx + 1:
		var t: String = str(_slides[i]["title"])
		if t != last_title:
			section += 1
			last_title = t
	return section


func _get_section_count() -> int:
	## Returns total number of unique header sections.
	var count: int = 0
	var last_title: String = ""
	for slide in _slides:
		var t: String = str(slide["title"])
		if t != last_title:
			count += 1
			last_title = t
	return count


# ── Navigation ─────────────────────────────────────────────

func _on_back() -> void:
	if _current_slide > 0:
		_show_slide(_current_slide - 1)
	else:
		_on_done()


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
