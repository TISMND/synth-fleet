extends Control
## Slideshow tutorial: energy, heat, cooling, consequences.
## Uses real HUD side panels from HudBuilder for authentic bar display.

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

# Slide definitions
var _slides: Array = []

# Layout constants matching HudBuilder
const SIDE_PANEL_WIDTH: int = 60
const PANEL_TOP: float = 60.0
const PANEL_BOTTOM_MARGIN: float = 104.0  # BOTTOM_BAR_HEIGHT + gap


func _ready() -> void:
	_build_slides_data()
	_build_ui()
	_build_hud_panels()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme()
	_show_slide(0)


func _build_slides_data() -> void:
	var purge_key: String = KeyBindingManager.get_action_binding("thermal_purge").get("keyboard_label", "V")

	# Each slide defines bar ratios for all 4 bars. Absent = full (1.0).
	# "highlight" names which bars get an arrow callout.
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
	# Grid background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Center content area (between HUD panels)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SIDE_PANEL_WIDTH + 40)
	margin.add_theme_constant_override("margin_right", SIDE_PANEL_WIDTH + 40)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	outer.add_child(_title_label)

	# Body text (centered, expands)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_body_label)

	# Arrow hint labels (positioned next to panels, built per-slide)

	# Nav bar at bottom
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


func _build_hud_panels() -> void:
	var panel_height: float = get_viewport_rect().size.y - PANEL_TOP - PANEL_BOTTOM_MARGIN
	if panel_height < 200.0:
		panel_height = 600.0

	# Left panel: Shield + Hull
	var left_data: Dictionary = HudBuilder.build_side_panel("preview", ["SHIELD", "HULL"], {}, panel_height)
	_left_panel_root = left_data["root"]
	_left_panel_root.position = Vector2(0, PANEL_TOP)
	_left_panel_root.size = Vector2(SIDE_PANEL_WIDTH, panel_height)
	_left_bars = left_data["bars"]
	add_child(_left_panel_root)

	# Right panel: Thermal + Electric
	var right_data: Dictionary = HudBuilder.build_side_panel("preview", ["THERMAL", "ELECTRIC"], {}, panel_height)
	_right_panel_root = right_data["root"]
	_right_panel_root.position = Vector2(get_viewport_rect().size.x - SIDE_PANEL_WIDTH, PANEL_TOP)
	_right_panel_root.size = Vector2(SIDE_PANEL_WIDTH, panel_height)
	_right_bars = right_data["bars"]
	add_child(_right_panel_root)


func _show_slide(index: int) -> void:
	_current_slide = clampi(index, 0, _slides.size() - 1)
	var slide: Dictionary = _slides[_current_slide]

	# Title
	_title_label.text = str(slide["title"])
	_title_label.add_theme_font_override("font", ThemeManager.get_font("header"))
	_title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_header"))
	ThemeManager.apply_text_glow(_title_label, "header")

	# Body
	_body_label.text = str(slide["body"])
	_body_label.add_theme_font_override("font", ThemeManager.get_font("body"))
	_body_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("body"))
	_body_label.add_theme_color_override("font_color", ThemeManager.get_color("text_body"))

	# Update HUD bar ratios
	var ratios: Dictionary = slide.get("ratios", {})
	_update_bar_ratio("SHIELD", ratios.get("SHIELD", 1.0))
	_update_bar_ratio("HULL", ratios.get("HULL", 1.0))
	_update_bar_ratio("THERMAL", ratios.get("THERMAL", 0.0))
	_update_bar_ratio("ELECTRIC", ratios.get("ELECTRIC", 1.0))

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


func _on_back() -> void:
	if _current_slide > 0:
		_show_slide(_current_slide - 1)


func _on_next() -> void:
	if _current_slide < _slides.size() - 1:
		_show_slide(_current_slide + 1)


func _on_done() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mission_prep_menu.tscn")


func _apply_theme() -> void:
	ThemeManager.apply_grid_background(_bg)
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
