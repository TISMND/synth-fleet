extends Control
## Level selection screen — browse available levels, view details, launch game.

var _vhs_overlay: ColorRect
var _title_label: Label
var _level_list: VBoxContainer
var _scroll_container: ScrollContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_bpm: Label
var _detail_encounters: Label
var _detail_length: Label
var _detail_scroll_speed: Label
var _detail_nebulas: Label
var _play_button: Button
var _back_button: Button

var _levels: Array[LevelData] = []
var _selected_index: int = -1
var _level_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_load_levels()
	_apply_theme()


func _build_ui() -> void:
	SynthwaveBgSetup.setup(self)

	# Main layout: MarginContainer > HBoxContainer
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox_root := VBoxContainer.new()
	vbox_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox_root)

	# Title
	_title_label = Label.new()
	_title_label.text = "SELECT LEVEL"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_root.add_child(_title_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox_root.add_child(spacer)

	# Content: HBox with level list on left, details on right
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 30)
	vbox_root.add_child(hbox)

	# Left side: scrollable level list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_stretch_ratio = 1.0
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(_scroll_container)

	_level_list = VBoxContainer.new()
	_level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_list.add_theme_constant_override("separation", 8)
	_scroll_container.add_child(_level_list)

	# Right side: detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 1.2
	# Apply dark style immediately so it doesn't flash white before _apply_theme()
	var init_style := StyleBoxFlat.new()
	init_style.bg_color = Color(0.05, 0.05, 0.12, 0.8)
	init_style.border_color = Color(0.0, 0.8, 1.0, 0.4)
	init_style.set_border_width_all(1)
	init_style.set_corner_radius_all(4)
	_detail_panel.add_theme_stylebox_override("panel", init_style)
	hbox.add_child(_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 20)
	detail_margin.add_theme_constant_override("margin_right", 20)
	detail_margin.add_theme_constant_override("margin_top", 20)
	detail_margin.add_theme_constant_override("margin_bottom", 20)
	_detail_panel.add_child(detail_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 12)
	detail_margin.add_child(detail_vbox)

	_detail_name = Label.new()
	_detail_name.text = "No level selected"
	detail_vbox.add_child(_detail_name)

	_detail_bpm = Label.new()
	_detail_bpm.text = ""
	detail_vbox.add_child(_detail_bpm)

	_detail_encounters = Label.new()
	_detail_encounters.text = ""
	detail_vbox.add_child(_detail_encounters)

	_detail_length = Label.new()
	_detail_length.text = ""
	detail_vbox.add_child(_detail_length)

	_detail_scroll_speed = Label.new()
	_detail_scroll_speed.text = ""
	detail_vbox.add_child(_detail_scroll_speed)

	_detail_nebulas = Label.new()
	_detail_nebulas.text = ""
	detail_vbox.add_child(_detail_nebulas)

	# Spacer to push play button to bottom
	var detail_spacer := Control.new()
	detail_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(detail_spacer)

	_play_button = Button.new()
	_play_button.text = "PLAY"
	_play_button.disabled = true
	_play_button.pressed.connect(_on_play)
	detail_vbox.add_child(_play_button)

	# Bottom: back button
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 16)
	vbox_root.add_child(bottom_spacer)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	vbox_root.add_child(_back_button)


func _load_levels() -> void:
	_levels = LevelDataManager.load_all()

	# Sort by display name
	_levels.sort_custom(func(a: LevelData, b: LevelData) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)

	_rebuild_list()


func _rebuild_list() -> void:
	for child in _level_list.get_children():
		_level_list.remove_child(child)
		child.queue_free()
	_level_buttons.clear()

	if _levels.size() == 0:
		var empty_label := Label.new()
		empty_label.text = "No levels found.\nCreate levels in Dev Studio > Level Editor."
		ThemeManager.apply_text_glow(empty_label, "body")
		_level_list.add_child(empty_label)
		return

	for i in range(_levels.size()):
		var level: LevelData = _levels[i]
		var btn := Button.new()
		var enc_count: int = level.encounters.size()
		btn.text = level.display_name + "  (" + str(enc_count) + " encounters)"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		btn.pressed.connect(_on_level_selected.bind(idx))
		ThemeManager.apply_button_style(btn)
		_level_list.add_child(btn)
		_level_buttons.append(btn)


func _on_level_selected(index: int) -> void:
	_selected_index = index
	_play_button.disabled = false
	_update_detail()


func _update_detail() -> void:
	if _selected_index < 0 or _selected_index >= _levels.size():
		_detail_name.text = "No level selected"
		_detail_bpm.text = ""
		_detail_encounters.text = ""
		_detail_length.text = ""
		_detail_scroll_speed.text = ""
		_detail_nebulas.text = ""
		return

	var level: LevelData = _levels[_selected_index]
	_detail_name.text = level.display_name
	_detail_bpm.text = "BPM: " + str(int(level.bpm))
	_detail_encounters.text = "Encounters: " + str(level.encounters.size())
	_detail_length.text = "Length: " + str(int(level.level_length)) + " px"
	_detail_scroll_speed.text = "Scroll Speed: " + str(int(level.scroll_speed))
	_detail_nebulas.text = "Nebulas: " + str(level.nebula_placements.size())

	# Apply glow to detail labels
	ThemeManager.apply_text_glow(_detail_name, "header")
	ThemeManager.apply_text_glow(_detail_bpm, "body")
	ThemeManager.apply_text_glow(_detail_encounters, "body")
	ThemeManager.apply_text_glow(_detail_length, "body")
	ThemeManager.apply_text_glow(_detail_scroll_speed, "body")
	ThemeManager.apply_text_glow(_detail_nebulas, "body")


func _on_play() -> void:
	if _selected_index < 0 or _selected_index >= _levels.size():
		return
	var level: LevelData = _levels[_selected_index]
	GameState.current_level_id = level.id
	GameState.return_scene = "res://scenes/ui/level_select_screen.tscn"
	SceneLoader.load_scene("res://scenes/game/game.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/play_menu.tscn")


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
	ThemeManager.apply_text_glow(_title_label, "header")
	ThemeManager.apply_button_style(_play_button)
	ThemeManager.apply_button_style(_back_button)

	# Style detail panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeManager.get_color("panel_bg") if ThemeManager.has_method("get_color") else Color(0.05, 0.05, 0.12, 0.8)
	panel_style.border_color = ThemeManager.get_color("accent") if ThemeManager.has_method("get_color") else Color(0.0, 0.8, 1.0, 0.4)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_detail_panel.add_theme_stylebox_override("panel", panel_style)

	# Re-style all level buttons
	for btn in _level_buttons:
		ThemeManager.apply_button_style(btn)

	# Re-apply detail text glow if a level is selected
	if _selected_index >= 0:
		_update_detail()


func _on_theme_changed() -> void:
	_apply_theme()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
