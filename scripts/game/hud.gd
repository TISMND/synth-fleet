extends CanvasLayer
## In-game HUD — bottom dashboard with health bars, beat indicator, credits, weapon icons.
## Fully themed via ThemeManager with theme_changed reactivity.

const PANEL_HEIGHT: int = 110
const PANEL_PADDING: int = 12
const WEAPON_ICON_SIZE: int = 40
const BEAT_SQUARE_SIZE: int = 18
const BAR_HEIGHT: int = 28
const BAR_LABEL_WIDTH: int = 80

var _credits_label: Label = null
var _menu_hint: Label = null
var _dashboard_bg: ColorRect = null
var _border_line: ColorRect = null
var _dashboard_hbox: HBoxContainer = null
var _weapons_hbox: HBoxContainer = null
var _weapon_icons: Array = []  # Array of dicts: {container, bg_rect, number_label, active, color}
var _beat_indicators: Array = []  # Array of ColorRect
var _bars_grid: GridContainer = null
var _bars: Dictionary = {}  # keyed by spec name -> {"bar": ProgressBar, "label": Label}
var _vhs_overlay: ColorRect = null


func _ready() -> void:
	_build_ui()
	_setup_vhs_overlay()
	_apply_theme()
	BeatClock.beat_hit.connect(_on_beat)
	ThemeManager.theme_changed.connect(_apply_theme)


func _build_ui() -> void:
	# Top-right credits
	_credits_label = Label.new()
	_credits_label.position = Vector2(1700, 20)
	_credits_label.text = "CR: 0"
	add_child(_credits_label)

	# Menu hint
	_menu_hint = Label.new()
	_menu_hint.position = Vector2(1780, 50)
	_menu_hint.text = "ESC: Menu"
	add_child(_menu_hint)

	# Dashboard background panel — bottom-anchored
	_dashboard_bg = ColorRect.new()
	_dashboard_bg.position = Vector2(0, 1080 - PANEL_HEIGHT)
	_dashboard_bg.size = Vector2(1920, PANEL_HEIGHT)
	add_child(_dashboard_bg)

	# Accent border line at top of dashboard
	_border_line = ColorRect.new()
	_border_line.position = Vector2.ZERO
	_border_line.size = Vector2(1920, 2)
	_dashboard_bg.add_child(_border_line)

	# Main dashboard HBox
	_dashboard_hbox = HBoxContainer.new()
	_dashboard_hbox.position = Vector2(PANEL_PADDING, PANEL_PADDING + 4)  # +4 for border
	_dashboard_hbox.size = Vector2(1920 - PANEL_PADDING * 2, PANEL_HEIGHT - PANEL_PADDING * 2 - 4)
	_dashboard_hbox.add_theme_constant_override("separation", 40)
	_dashboard_bg.add_child(_dashboard_hbox)

	# Left — Weapon icons
	_weapons_hbox = HBoxContainer.new()
	_weapons_hbox.custom_minimum_size = Vector2(500, 0)
	_weapons_hbox.add_theme_constant_override("separation", 8)
	_weapons_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_dashboard_hbox.add_child(_weapons_hbox)

	# Center — Beat metronome (4 squares)
	var beat_center := CenterContainer.new()
	beat_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dashboard_hbox.add_child(beat_center)

	var _beat_hbox := HBoxContainer.new()
	_beat_hbox.add_theme_constant_override("separation", 6)
	beat_center.add_child(_beat_hbox)

	for i in 4:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(BEAT_SQUARE_SIZE, BEAT_SQUARE_SIZE)
		_beat_hbox.add_child(rect)
		_beat_indicators.append(rect)

	# Right — Status bars 2x2 grid (right third of HUD)
	_bars_grid = GridContainer.new()
	_bars_grid.columns = 2
	_bars_grid.add_theme_constant_override("h_separation", 40)
	_bars_grid.add_theme_constant_override("v_separation", 8)
	_bars_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bars_grid.custom_minimum_size.x = 640
	_dashboard_hbox.add_child(_bars_grid)

	# Build bars from shared specs — layout order: [0] Shield, [2] Thermal, [1] Hull, [3] Electric
	var specs: Array = ThemeManager.get_status_bar_specs()
	var layout_order: Array[int] = [0, 2, 1, 3]  # Row1: Shield, Thermal — Row2: Hull, Electric
	var initial_values: Dictionary = {"SHIELD": 100, "HULL": 100, "THERMAL": 30, "ELECTRIC": 70}
	for idx in layout_order:
		var spec: Dictionary = specs[idx]
		var bar_name: String = str(spec["name"])
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var init_val: int = int(initial_values.get(bar_name, 100))
		var cell: Dictionary = _create_bar_cell(bar_name, color, init_val, 100)
		_bars_grid.add_child(cell["vbox"])
		_bars[bar_name] = {"bar": cell["bar"], "label": cell["label"]}


func _create_bar_cell(text: String, color: Color, initial: int, max_val: int) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = BAR_LABEL_WIDTH
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = max_val
	bar.value = initial
	bar.show_percentage = false
	hbox.add_child(bar)

	ThemeManager.apply_led_bar(bar, color, float(initial) / maxf(float(max_val), 1.0))

	return {"vbox": hbox, "label": lbl, "bar": bar}


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _apply_theme() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")

	# Dashboard background
	_dashboard_bg.color = ThemeManager.get_color("panel")
	var accent_color: Color = ThemeManager.get_color("accent")
	_border_line.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)

	# Credits
	_credits_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_credits_label.add_theme_color_override("font_color", ThemeManager.get_color("positive"))
	if body_font:
		_credits_label.add_theme_font_override("font", body_font)
	ThemeManager.apply_text_glow(_credits_label, "body")

	# Menu hint
	_menu_hint.add_theme_font_size_override("font_size", body_size)
	_menu_hint.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	if body_font:
		_menu_hint.add_theme_font_override("font", body_font)

	# Bar labels + LED bars from shared specs
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not _bars.has(bar_name):
			continue
		var entry: Dictionary = _bars[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var lbl: Label = entry["label"]
		_apply_bar_label_theme(lbl, color, body_font, body_size)
		var bar: ProgressBar = entry["bar"]
		var ratio: float = bar.value / maxf(bar.max_value, 1.0)
		ThemeManager.apply_led_bar(bar, color, ratio)

	# Beat indicators
	for i in _beat_indicators.size():
		var rect: ColorRect = _beat_indicators[i]
		rect.color = ThemeManager.get_color("panel")

	# Weapon icons
	for icon in _weapon_icons:
		_apply_weapon_icon_theme(icon)


func _apply_bar_label_theme(lbl: Label, color: Color, font: Font, size: int) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if font:
		lbl.add_theme_font_override("font", font)
	ThemeManager.apply_text_glow(lbl, "body")


func _apply_weapon_icon_theme(icon: Dictionary) -> void:
	var active: bool = icon["active"]
	var color: Color = icon["color"]
	if active:
		icon["bg_rect"].color = color
		icon["number_label"].add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	else:
		var dim_color: Color = ThemeManager.get_color("panel").lightened(0.1)
		icon["bg_rect"].color = dim_color
		icon["number_label"].add_theme_color_override("font_color", ThemeManager.get_color("disabled"))


func update_health(current_shield: float, max_shield: int, current_hull: int, max_hull: int) -> void:
	var shield_entry: Dictionary = _bars["SHIELD"]
	var shield_bar: ProgressBar = shield_entry["bar"]
	shield_bar.max_value = max_shield
	shield_bar.value = current_shield
	var shield_ratio: float = current_shield / maxf(float(max_shield), 1.0)
	ThemeManager.apply_led_bar(shield_bar, ThemeManager.get_color("accent"), shield_ratio)

	var hull_entry: Dictionary = _bars["HULL"]
	var hull_bar: ProgressBar = hull_entry["bar"]
	hull_bar.max_value = max_hull
	hull_bar.value = current_hull
	var hull_ratio: float = float(current_hull) / maxf(float(max_hull), 1.0)
	ThemeManager.apply_led_bar(hull_bar, ThemeManager.get_color("warning"), hull_ratio)


func update_credits(amount: int) -> void:
	_credits_label.text = "CR: " + str(amount)


func update_hardpoints(data: Array) -> void:
	# Clear existing icons
	for icon in _weapon_icons:
		if is_instance_valid(icon["container"]):
			icon["container"].queue_free()
	_weapon_icons.clear()

	var body_font: Font = ThemeManager.get_font("font_body")

	for i in data.size():
		var entry: Dictionary = data[i]
		var active: bool = entry.get("active", false) as bool
		var color: Color = entry.get("color", Color.CYAN) as Color
		var hp_num: int = i + 1

		# Container control for fixed size
		var container := Control.new()
		container.custom_minimum_size = Vector2(WEAPON_ICON_SIZE, WEAPON_ICON_SIZE)

		# Background square
		var bg_rect := ColorRect.new()
		bg_rect.position = Vector2.ZERO
		bg_rect.size = Vector2(WEAPON_ICON_SIZE, WEAPON_ICON_SIZE)
		container.add_child(bg_rect)

		# Number label centered
		var number_label := Label.new()
		number_label.text = str(hp_num)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.position = Vector2.ZERO
		number_label.size = Vector2(WEAPON_ICON_SIZE, WEAPON_ICON_SIZE)
		number_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
		if body_font:
			number_label.add_theme_font_override("font", body_font)
		container.add_child(number_label)

		_weapons_hbox.add_child(container)

		var icon_data: Dictionary = {
			"container": container,
			"bg_rect": bg_rect,
			"number_label": number_label,
			"active": active,
			"color": color,
		}
		_weapon_icons.append(icon_data)
		_apply_weapon_icon_theme(icon_data)


func _on_beat(beat_index: int) -> void:
	var active: int = beat_index % 4
	for i in 4:
		if i == active:
			_beat_indicators[i].color = ThemeManager.get_color("accent")
		else:
			_beat_indicators[i].color = ThemeManager.get_color("panel")
