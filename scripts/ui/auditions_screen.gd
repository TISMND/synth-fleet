extends Control
## Auditions screen — tabbed dev tool for visual auditions.

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button

var _active_tab: int = 0
var _tab_btns: Array[Button] = []
var _tab_contents: Array[MarginContainer] = []


func _ready() -> void:
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


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

	# Tab definitions: [label, script_path]
	var tabs: Array[Array] = [
		["POWERUPS", "res://scripts/ui/auditions_tab.gd"],
		["SHADER BGS", "res://scripts/ui/shader_bg_auditions.gd"],
		["VERSES", "res://scripts/ui/destinations_auditions.gd"],
		["VERSE SELECT", "res://scripts/ui/verse_select_auditions.gd"],
		["GAME TITLE", "res://scripts/ui/game_title_auditions.gd"],
	]

	for i in tabs.size():
		var tab_info: Array = tabs[i]
		var btn := Button.new()
		btn.text = tab_info[0] as String
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		var idx: int = i
		btn.pressed.connect(func() -> void: _switch_to_tab(idx))
		header.add_child(btn)
		_tab_btns.append(btn)

		var script: GDScript = load(tab_info[1] as String) as GDScript
		var content: MarginContainer = script.new() as MarginContainer
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.visible = (i == 0)
		main_vbox.add_child(content)
		_tab_contents.append(content)

	_setup_vhs_overlay()


func _switch_to_tab(idx: int) -> void:
	if _active_tab == idx:
		_tab_btns[idx].button_pressed = true
		return
	_active_tab = idx
	for i in _tab_btns.size():
		_tab_btns[i].button_pressed = (i == idx)
		_tab_contents[i].visible = (i == idx)


# ── Theme ────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	for btn in _tab_btns:
		if btn:
			ThemeManager.apply_button_style(btn)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)


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
