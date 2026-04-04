extends Control
## Auditions screen — tabbed dev tool for visual auditions.

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button

var _active_tab: int = 0
var _tab_items_btn: Button
var _tab_headsup_btn: Button
var _tab_title_btn: Button
var _items_content: MarginContainer
var _headsup_content: MarginContainer
var _title_content: MarginContainer
var _tab_skins_btn: Button
var _skins_content: MarginContainer
var _tab_paint_btn: Button
var _paint_content: MarginContainer
var _tab_icons_btn: Button
var _icons_content: MarginContainer
var _tab_lv2bg_btn: Button
var _lv2bg_content: MarginContainer


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

	_tab_items_btn = Button.new()
	_tab_items_btn.text = "ITEMS"
	_tab_items_btn.toggle_mode = true
	_tab_items_btn.button_pressed = true
	_tab_items_btn.pressed.connect(func(): _switch_to_tab(0))
	header.add_child(_tab_items_btn)

	_tab_headsup_btn = Button.new()
	_tab_headsup_btn.text = "HEADSUP"
	_tab_headsup_btn.toggle_mode = true
	_tab_headsup_btn.pressed.connect(func(): _switch_to_tab(1))
	header.add_child(_tab_headsup_btn)

	_tab_title_btn = Button.new()
	_tab_title_btn.text = "TITLE"
	_tab_title_btn.toggle_mode = true
	_tab_title_btn.pressed.connect(func(): _switch_to_tab(2))
	header.add_child(_tab_title_btn)

	_tab_skins_btn = Button.new()
	_tab_skins_btn.text = "SKINS"
	_tab_skins_btn.toggle_mode = true
	_tab_skins_btn.pressed.connect(func(): _switch_to_tab(3))
	header.add_child(_tab_skins_btn)

	_tab_paint_btn = Button.new()
	_tab_paint_btn.text = "DETAILS"
	_tab_paint_btn.toggle_mode = true
	_tab_paint_btn.pressed.connect(func(): _switch_to_tab(4))
	header.add_child(_tab_paint_btn)

	_tab_icons_btn = Button.new()
	_tab_icons_btn.text = "ICONS"
	_tab_icons_btn.toggle_mode = true
	_tab_icons_btn.pressed.connect(func(): _switch_to_tab(5))
	header.add_child(_tab_icons_btn)

	_tab_lv2bg_btn = Button.new()
	_tab_lv2bg_btn.text = "LV2 BG"
	_tab_lv2bg_btn.toggle_mode = true
	_tab_lv2bg_btn.pressed.connect(func(): _switch_to_tab(6))
	header.add_child(_tab_lv2bg_btn)

	var ItemsTabScript: GDScript = load("res://scripts/ui/auditions_tab.gd")
	_items_content = ItemsTabScript.new()
	_items_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_items_content)

	var HeadsupTabScript: GDScript = load("res://scripts/ui/headsup_auditions.gd")
	_headsup_content = HeadsupTabScript.new()
	_headsup_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_headsup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_headsup_content.visible = false
	main_vbox.add_child(_headsup_content)

	var TitleTabScript: GDScript = load("res://scripts/ui/title_auditions.gd")
	_title_content = TitleTabScript.new()
	_title_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_content.visible = false
	main_vbox.add_child(_title_content)

	var SkinsScript: GDScript = load("res://scripts/ui/skin_auditions.gd")
	_skins_content = SkinsScript.new()
	_skins_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skins_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skins_content.visible = false
	main_vbox.add_child(_skins_content)

	var PaintScript: GDScript = load("res://scripts/ui/paint_auditions.gd")
	_paint_content = PaintScript.new()
	_paint_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paint_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_content.visible = false
	main_vbox.add_child(_paint_content)

	var IconsScript: GDScript = load("res://scripts/ui/component_icon_auditions.gd")
	_icons_content = IconsScript.new()
	_icons_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_icons_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icons_content.visible = false
	main_vbox.add_child(_icons_content)

	var Lv2BgScript: GDScript = load("res://scripts/ui/lv2_bg_auditions.gd")
	_lv2bg_content = Lv2BgScript.new()
	_lv2bg_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lv2bg_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lv2bg_content.visible = false
	main_vbox.add_child(_lv2bg_content)

	_setup_vhs_overlay()


func _switch_to_tab(idx: int) -> void:
	if _active_tab == idx:
		match idx:
			0: _tab_items_btn.button_pressed = true
			1: _tab_headsup_btn.button_pressed = true
			2: _tab_title_btn.button_pressed = true
			3: _tab_skins_btn.button_pressed = true
			4: _tab_paint_btn.button_pressed = true
			5: _tab_icons_btn.button_pressed = true
			6: _tab_lv2bg_btn.button_pressed = true
		return
	_active_tab = idx
	_tab_items_btn.button_pressed = (idx == 0)
	_tab_headsup_btn.button_pressed = (idx == 1)
	_tab_title_btn.button_pressed = (idx == 2)
	_tab_skins_btn.button_pressed = (idx == 3)
	_tab_paint_btn.button_pressed = (idx == 4)
	_tab_icons_btn.button_pressed = (idx == 5)
	_tab_lv2bg_btn.button_pressed = (idx == 6)
	_items_content.visible = (idx == 0)
	_headsup_content.visible = (idx == 1)
	_title_content.visible = (idx == 2)
	_skins_content.visible = (idx == 3)
	_paint_content.visible = (idx == 4)
	_icons_content.visible = (idx == 5)
	_lv2bg_content.visible = (idx == 6)


# ── Theme ────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	for btn in [_tab_items_btn, _tab_headsup_btn, _tab_title_btn, _tab_skins_btn, _tab_paint_btn, _tab_icons_btn, _tab_lv2bg_btn]:
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
