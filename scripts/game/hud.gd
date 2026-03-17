extends CanvasLayer
## In-game HUD — health bars, beat indicator, credits, hardpoint display.
## Fully themed via ThemeManager with theme_changed reactivity.

var _shield_bar: ProgressBar = null
var _hull_bar: ProgressBar = null
var _credits_label: Label = null
var _beat_indicators: Array = []  # Array of ColorRect
var _menu_hint: Label = null
var _hardpoint_hbox: HBoxContainer = null
var _hardpoint_labels: Array = []
var _shield_text: Label = null
var _hull_text: Label = null
var _vhs_overlay: ColorRect = null


func _ready() -> void:
	_build_ui()
	_setup_vhs_overlay()
	_apply_theme()
	BeatClock.beat_hit.connect(_on_beat)
	ThemeManager.theme_changed.connect(_apply_theme)


func _build_ui() -> void:
	# Top-left health bars
	var health_vbox := VBoxContainer.new()
	health_vbox.position = Vector2(20, 20)
	health_vbox.custom_minimum_size = Vector2(200, 0)
	add_child(health_vbox)

	_shield_text = Label.new()
	_shield_text.text = "SHIELD"
	health_vbox.add_child(_shield_text)

	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(200, 16)
	_shield_bar.max_value = 100
	_shield_bar.value = 100
	_shield_bar.show_percentage = false
	health_vbox.add_child(_shield_bar)

	_hull_text = Label.new()
	_hull_text.text = "HULL"
	health_vbox.add_child(_hull_text)

	_hull_bar = ProgressBar.new()
	_hull_bar.custom_minimum_size = Vector2(200, 16)
	_hull_bar.max_value = 100
	_hull_bar.value = 100
	_hull_bar.show_percentage = false
	health_vbox.add_child(_hull_bar)

	# Beat indicator — 4 squares at top-center
	var beat_hbox := HBoxContainer.new()
	beat_hbox.position = Vector2(860, 20)
	beat_hbox.add_theme_constant_override("separation", 8)
	add_child(beat_hbox)

	for i in 4:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(24, 24)
		beat_hbox.add_child(rect)
		_beat_indicators.append(rect)

	# Credits at top-right
	_credits_label = Label.new()
	_credits_label.position = Vector2(1700, 20)
	_credits_label.text = "CR: 0"
	add_child(_credits_label)

	# Menu hint
	_menu_hint = Label.new()
	_menu_hint.position = Vector2(1780, 50)
	_menu_hint.text = "ESC: Menu"
	add_child(_menu_hint)

	# Hardpoint stage indicators — bottom-left
	_hardpoint_hbox = HBoxContainer.new()
	_hardpoint_hbox.position = Vector2(20, 1000)
	_hardpoint_hbox.add_theme_constant_override("separation", 16)
	add_child(_hardpoint_hbox)


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

	# Shield label
	_shield_text.add_theme_font_size_override("font_size", body_size)
	_shield_text.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	if body_font:
		_shield_text.add_theme_font_override("font", body_font)
	ThemeManager.apply_text_glow(_shield_text, "body")

	# Hull label
	_hull_text.add_theme_font_size_override("font_size", body_size)
	_hull_text.add_theme_color_override("font_color", ThemeManager.get_color("warning"))
	if body_font:
		_hull_text.add_theme_font_override("font", body_font)
	ThemeManager.apply_text_glow(_hull_text, "body")

	# LED bars
	var shield_ratio: float = _shield_bar.value / maxf(_shield_bar.max_value, 1.0)
	ThemeManager.apply_led_bar(_shield_bar, ThemeManager.get_color("accent"), shield_ratio)
	var hull_ratio: float = _hull_bar.value / maxf(_hull_bar.max_value, 1.0)
	ThemeManager.apply_led_bar(_hull_bar, ThemeManager.get_color("warning"), hull_ratio)

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

	# Beat indicators
	for i in _beat_indicators.size():
		var rect: ColorRect = _beat_indicators[i]
		rect.color = ThemeManager.get_color("panel")

	# Hardpoint labels
	for lbl in _hardpoint_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
			if body_font:
				lbl.add_theme_font_override("font", body_font)


func update_health(current_shield: float, max_shield: int, current_hull: int, max_hull: int) -> void:
	_shield_bar.max_value = max_shield
	_shield_bar.value = current_shield
	_hull_bar.max_value = max_hull
	_hull_bar.value = current_hull
	var shield_ratio: float = current_shield / maxf(float(max_shield), 1.0)
	ThemeManager.apply_led_bar(_shield_bar, ThemeManager.get_color("accent"), shield_ratio)
	var hull_ratio: float = float(current_hull) / maxf(float(max_hull), 1.0)
	ThemeManager.apply_led_bar(_hull_bar, ThemeManager.get_color("warning"), hull_ratio)


func update_credits(amount: int) -> void:
	_credits_label.text = "CR: " + str(amount)


func update_hardpoints(data: Array) -> void:
	# Clear existing labels
	for lbl in _hardpoint_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_hardpoint_labels.clear()

	var body_font: Font = ThemeManager.get_font("font_body")

	for i in data.size():
		var entry: Dictionary = data[i]
		var active: bool = entry.get("active", false) as bool
		var weapon_name: String = str(entry.get("weapon_name", "?"))
		var color: Color = entry.get("color", Color.CYAN) as Color
		var hp_num: int = i + 1

		var lbl := Label.new()
		if not active:
			lbl.text = str(hp_num) + ": OFF"
			lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		else:
			lbl.text = str(hp_num) + ": " + weapon_name + " [ON]"
			lbl.add_theme_color_override("font_color", color)
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		_hardpoint_hbox.add_child(lbl)
		_hardpoint_labels.append(lbl)


func _on_beat(beat_index: int) -> void:
	var active: int = beat_index % 4
	for i in 4:
		if i == active:
			_beat_indicators[i].color = ThemeManager.get_color("accent")
		else:
			_beat_indicators[i].color = ThemeManager.get_color("panel")
