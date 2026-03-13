extends CanvasLayer
## In-game HUD — health bars, beat indicator, credits, game-over overlay.

var _shield_bar: ProgressBar = null
var _hull_bar: ProgressBar = null
var _credits_label: Label = null
var _beat_indicators: Array = []  # Array of ColorRect
var _game_over_label: Label = null
var _menu_hint: Label = null
var _wave_label: Label = null
var _level_label: Label = null
var _intro_label: Label = null
var _hardpoint_hbox: HBoxContainer = null
var _hardpoint_labels: Array = []


func _ready() -> void:
	_build_ui()
	BeatClock.beat_hit.connect(_on_beat)


func _build_ui() -> void:
	# Top-left health bars
	var health_vbox := VBoxContainer.new()
	health_vbox.position = Vector2(20, 20)
	health_vbox.custom_minimum_size = Vector2(200, 0)
	add_child(health_vbox)

	var shield_label := Label.new()
	shield_label.text = "SHIELD"
	shield_label.add_theme_font_size_override("font_size", 12)
	shield_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	health_vbox.add_child(shield_label)

	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(200, 16)
	_shield_bar.max_value = 100
	_shield_bar.value = 100
	_shield_bar.show_percentage = false
	var shield_style := StyleBoxFlat.new()
	shield_style.bg_color = Color(0.0, 0.7, 0.9)
	_shield_bar.add_theme_stylebox_override("fill", shield_style)
	var shield_bg := StyleBoxFlat.new()
	shield_bg.bg_color = Color(0.05, 0.15, 0.2)
	_shield_bar.add_theme_stylebox_override("background", shield_bg)
	health_vbox.add_child(_shield_bar)

	var hull_label := Label.new()
	hull_label.text = "HULL"
	hull_label.add_theme_font_size_override("font_size", 12)
	hull_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	health_vbox.add_child(hull_label)

	_hull_bar = ProgressBar.new()
	_hull_bar.custom_minimum_size = Vector2(200, 16)
	_hull_bar.max_value = 100
	_hull_bar.value = 100
	_hull_bar.show_percentage = false
	var hull_style := StyleBoxFlat.new()
	hull_style.bg_color = Color(1.0, 0.5, 0.1)
	_hull_bar.add_theme_stylebox_override("fill", hull_style)
	var hull_bg := StyleBoxFlat.new()
	hull_bg.bg_color = Color(0.2, 0.1, 0.05)
	_hull_bar.add_theme_stylebox_override("background", hull_bg)
	health_vbox.add_child(_hull_bar)

	# Beat indicator — 4 squares at top-center
	var beat_hbox := HBoxContainer.new()
	beat_hbox.position = Vector2(860, 20)
	beat_hbox.add_theme_constant_override("separation", 8)
	add_child(beat_hbox)

	for i in 4:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(24, 24)
		rect.color = Color(0.15, 0.15, 0.25)
		beat_hbox.add_child(rect)
		_beat_indicators.append(rect)

	# Credits at top-right
	_credits_label = Label.new()
	_credits_label.position = Vector2(1700, 20)
	_credits_label.text = "CR: 0"
	_credits_label.add_theme_font_size_override("font_size", 18)
	_credits_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	add_child(_credits_label)

	# Menu hint
	_menu_hint = Label.new()
	_menu_hint.position = Vector2(1780, 50)
	_menu_hint.text = "M: Menu"
	_menu_hint.add_theme_font_size_override("font_size", 12)
	_menu_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	add_child(_menu_hint)

	# Wave counter — top-right area
	_wave_label = Label.new()
	_wave_label.position = Vector2(1500, 20)
	_wave_label.text = ""
	_wave_label.add_theme_font_size_override("font_size", 16)
	_wave_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	add_child(_wave_label)

	# Level name — center-left
	_level_label = Label.new()
	_level_label.position = Vector2(300, 20)
	_level_label.text = ""
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	add_child(_level_label)

	# Intro/complete/victory overlay label (centered, large)
	_intro_label = Label.new()
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.position = Vector2(600, 400)
	_intro_label.custom_minimum_size = Vector2(720, 0)
	_intro_label.add_theme_font_size_override("font_size", 52)
	_intro_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_intro_label.visible = false
	add_child(_intro_label)

	# Game over label (hidden)
	_game_over_label = Label.new()
	_game_over_label.text = "GAME OVER\nPress any key to return to menu"
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.position = Vector2(700, 450)
	_game_over_label.add_theme_font_size_override("font_size", 48)
	_game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_game_over_label.visible = false
	add_child(_game_over_label)

	# Hardpoint stage indicators — bottom-left
	_hardpoint_hbox = HBoxContainer.new()
	_hardpoint_hbox.position = Vector2(20, 1000)
	_hardpoint_hbox.add_theme_constant_override("separation", 16)
	add_child(_hardpoint_hbox)


func update_health(current_shield: float, max_shield: int, current_hull: int, max_hull: int) -> void:
	_shield_bar.max_value = max_shield
	_shield_bar.value = current_shield
	_hull_bar.max_value = max_hull
	_hull_bar.value = current_hull


func update_credits(amount: int) -> void:
	_credits_label.text = "CR: " + str(amount)


func update_wave(current: int, total: int) -> void:
	_wave_label.text = "WAVE " + str(current) + "/" + str(total)


func update_level(level_name: String, level_number: int) -> void:
	_level_label.text = "LVL " + str(level_number) + " — " + level_name


func show_level_intro(level_name: String, level_number: int) -> void:
	_intro_label.text = "LVL " + str(level_number) + "\n" + level_name
	_intro_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	_intro_label.visible = true


func hide_level_intro() -> void:
	_intro_label.visible = false


func show_level_complete(bonus: int) -> void:
	_intro_label.text = "LEVEL COMPLETE\n+" + str(bonus) + " CR"
	_intro_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_intro_label.visible = true


func show_victory() -> void:
	_intro_label.text = "VICTORY\nPress any key"
	_intro_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_intro_label.visible = true


func show_game_over() -> void:
	_game_over_label.visible = true


func update_hardpoints(data: Array) -> void:
	# Clear existing labels
	for lbl in _hardpoint_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_hardpoint_labels.clear()

	for i in data.size():
		var entry: Dictionary = data[i]
		var stage: int = int(entry.get("stage", -1))
		var max_stage: int = int(entry.get("max_stage", 0))
		var weapon_name: String = str(entry.get("weapon_name", "?"))
		var color: Color = entry.get("color", Color.CYAN) as Color
		var hp_num: int = i + 1

		var lbl := Label.new()
		if stage < 0:
			lbl.text = str(hp_num) + ": OFF"
			lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		else:
			lbl.text = str(hp_num) + ": " + weapon_name + " [" + str(stage + 1) + "]"
			lbl.add_theme_color_override("font_color", color)
		lbl.add_theme_font_size_override("font_size", 14)
		_hardpoint_hbox.add_child(lbl)
		_hardpoint_labels.append(lbl)


func _on_beat(beat_index: int) -> void:
	var active: int = beat_index % 4
	for i in 4:
		if i == active:
			_beat_indicators[i].color = Color(0.3, 0.9, 1.0)
		else:
			_beat_indicators[i].color = Color(0.15, 0.15, 0.25)
